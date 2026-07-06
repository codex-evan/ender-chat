/// WebSocket service for server communication
/// Handles connection, room lifecycle, message sending/receiving

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../models/room.dart';
import 'crypto_service.dart';
import 'storage_service.dart';

/// Tracks per-room encryption state
class RoomSession {
  final String roomId;
  final Uint8List myEphemeralPrivateKey;
  final Uint8List myEphemeralPublicKey;
  final Uint8List? partnerEphemeralPublicKey;
  final SessionKeys sessionKeys;
  final Uint8List roomSalt;

  const RoomSession({
    required this.roomId,
    required this.myEphemeralPrivateKey,
    required this.myEphemeralPublicKey,
    this.partnerEphemeralPublicKey,
    required this.sessionKeys,
    required this.roomSalt,
  });

  RoomSession copyWith({SessionKeys? sessionKeys}) {
    return RoomSession(
      roomId: roomId,
      myEphemeralPrivateKey: myEphemeralPrivateKey,
      myEphemeralPublicKey: myEphemeralPublicKey,
      partnerEphemeralPublicKey: partnerEphemeralPublicKey,
      sessionKeys: sessionKeys ?? this.sessionKeys,
      roomSalt: roomSalt,
    );
  }
}

class WsService extends ChangeNotifier {
  final CryptoService _crypto;
  final StorageService _storage;

  WebSocketChannel? _channel;
  String? _clientId;
  String? _currentRoomId;
  ConnectionState _connectionState = ConnectionState.disconnected;

  // Per-room session tracking
  final Map<String, RoomSession> _roomSessions = {};

  // Callbacks
  Function(RoomInfo)? onRoomCreated;
  Function(String roomCode)? onPartnerJoined;
  Function(EncryptedMessage)? onMessageReceived;
  Function(String fileId, int progress)? onFileUploadProgress;
  Function(String fileId, int progress)? onFileDownloadProgress;
  Function(String message)? onSecurityEvent;
  Function()? onConnectionLost;
  Function()? onRoomEnded;

  // Message queue for offline
  final List<Map<String, dynamic>> _messageQueue = [];

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  WsService({required CryptoService cryptoService, required StorageService storageService})
      : _crypto = cryptoService,
        _storage = storageService;

  ConnectionState get connectionState => _connectionState;
  String? get clientId => _clientId;
  String? get currentRoomId => _currentRoomId;

  Future<void> init() async {
    final queuedStrings = await _storage.getQueuedMessages();
    for (final s in queuedStrings) {
      try {
        _messageQueue.add(jsonDecode(s) as Map<String, dynamic>);
      } on Object {
        // Skip malformed entries
      }
    }
    notifyListeners();
  }

  void connect(String serverUrl) {
    if (_connectionState == ConnectionState.connected) return;

    _setConnectionState(ConnectionState.connecting);

    try {
      _channel = IOWebSocketChannel.connect(
        serverUrl,
        pingInterval: Duration(seconds: 30),
        connectTimeout: Duration(seconds: 10),
      );

      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('WebSocket error: ');
          _setConnectionState(ConnectionState.error);
          _scheduleReconnect(serverUrl);
        },
        onDone: () {
          debugPrint('WebSocket disconnected');
          _setConnectionState(ConnectionState.disconnected);
          onConnectionLost?.call();
          _scheduleReconnect(serverUrl);
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection failed: ');
      _setConnectionState(ConnectionState.error);
      _scheduleReconnect(serverUrl);
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setConnectionState(ConnectionState.disconnected);
    _currentRoomId = null;
    _roomSessions.clear();
  }

  void createRoom() {
    _send({'type': 'create_room'});
  }

  void joinRoom(String roomId) {
    _send({'type': 'join_room', 'room_id': roomId, 'timestamp': DateTime.now().millisecondsSinceEpoch});
  }

  RoomSession _createRoomSession(String roomId) {
    final roomSalt = _crypto.generateSecureRandomBytes(16);
    final myPrivKey = _crypto.generateSecureRandomBytes(32);
    final myPubKey = _crypto.generateSecureRandomBytes(32);
    return RoomSession(
      roomId: roomId,
      myEphemeralPrivateKey: myPrivKey,
      myEphemeralPublicKey: myPubKey,
      sessionKeys: SessionKeys(
        messageKey: Uint8List(32),
        authKey: Uint8List(32),
        fileKey: Uint8List(32),
      ),
      roomSalt: roomSalt,
    );
  }

  Future<void> _deriveSessionKeys(String roomId, RoomSession session) async {
    if (session.partnerEphemeralPublicKey == null) return;

    final sharedSecret = await _crypto.computeSharedSecret(
      session.myEphemeralPrivateKey,
      session.myEphemeralPublicKey,
      session.partnerEphemeralPublicKey!,
    );

    final derivedKeys = await _crypto.deriveSessionKeys(sharedSecret, session.roomSalt);
    _roomSessions[roomId] = session.copyWith(sessionKeys: derivedKeys);
  }

  Future<void> sendMessage(String content, {String? roomId}) async {
    if (_connectionState != ConnectionState.connected) {
      _messageQueue.add({
        'type': 'text',
        'content': content,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await _storage.saveQueuedMessages(_messageQueue);
      return;
    }

    final targetRoomId = roomId ?? _currentRoomId;
    if (targetRoomId == null) {
      debugPrint('No room to send message to');
      return;
    }

    try {
      final msgId = const Uuid().v4();
      final ts = DateTime.now().millisecondsSinceEpoch;

      RoomSession? session = _roomSessions[targetRoomId];
      if (session == null) {
        session = _createRoomSession(targetRoomId);
        _roomSessions[targetRoomId] = session;
      }

      final result = await _crypto.encryptMessage(
        content,
        session.sessionKeys,
        KeyPair(publicKey: session.myEphemeralPublicKey, privateKey: session.myEphemeralPrivateKey),
      );

      _send({
        'type': 'encrypted_message_send',
        'msg_id': msgId,
        'timestamp': ts,
        'room_id': targetRoomId,
        'payload': result.toJson(),
      });
    } catch (e) {
      debugPrint('Encrypt message failed: ');
    }
  }

  void leaveRoom() {
    if (_currentRoomId != null) {
      _send({'type': 'participant_left'});
      _roomSessions.remove(_currentRoomId);
      _currentRoomId = null;
    }
  }

  void destroyRoom() {
    if (_currentRoomId != null) {
      _send({'type': 'room_destroy'});
      _roomSessions.remove(_currentRoomId);
      _currentRoomId = null;
    }
  }

  void sendSecurityEvent(String eventType) {
    _send({
      'type': eventType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _handleMessage(dynamic data) async {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == null) return;

      switch (type) {
        case 'connected':
          _clientId = json['client_id'] as String?;
          _setConnectionState(ConnectionState.connected);
          _reconnectAttempts = 0;
          _processQueuedMessages();
          break;

        case 'room_created':
          _currentRoomId = json['room_id'] as String?;
          if (_currentRoomId != null) {
            _roomSessions[_currentRoomId!] = _createRoomSession(_currentRoomId!);
          }
          onRoomCreated?.call(RoomInfo(
            roomId: json['room_id'] ?? '',
            roomCode: json['room_code'] ?? '',
            roomHash: json['room_hash'] ?? '',
            inviteLink: json['invite_link'],
            createdAt: DateTime.now(),
          ));
          break;

        case 'room_ready':
          _currentRoomId = json['room_id'] as String?;
          break;

        case 'participant_joined':
          onPartnerJoined?.call(json['participant_id'] as String? ?? '');
          break;

        case 'partner_public_key':
          if (_currentRoomId != null) {
            final pkBase64 = json['public_key'] as String?;
            if (pkBase64 != null && pkBase64.isNotEmpty) {
              final partnerPk = base64Decode(pkBase64);
              if (partnerPk.length == 32) {
                final existingSession = _roomSessions[_currentRoomId!];
                if (existingSession != null) {
                  final updatedSession = RoomSession(
                    roomId: existingSession.roomId,
                    myEphemeralPrivateKey: existingSession.myEphemeralPrivateKey,
                    myEphemeralPublicKey: existingSession.myEphemeralPublicKey,
                    partnerEphemeralPublicKey: Uint8List.fromList(partnerPk),
                    sessionKeys: existingSession.sessionKeys,
                    roomSalt: existingSession.roomSalt,
                  );
                  _roomSessions[_currentRoomId!] = updatedSession;
                  await _deriveSessionKeys(_currentRoomId!, updatedSession);
                }
              }
            }
          }
          break;

        case 'encrypted_message_receive':
          final payload = json['payload'] as Map<String, dynamic>?;
          if (payload == null) return;

          try {
            final msgResult = MessageEncryptionResult(
              ciphertext: payload['ciphertext'] as String? ?? '',
              nonce: payload['nonce'] as String? ?? '',
              senderEphemeralPk: payload['sender_ephemeral_pk'] as String? ?? '',
              msgId: payload['msg_id'] as String? ?? '',
              timestamp: payload['timestamp'] as int? ?? 0,
            );

            String? decryptedContent;
            if (_currentRoomId != null) {
              final session = _roomSessions[_currentRoomId!];
              if (session != null) {
                decryptedContent = await _crypto.decryptMessage(
                  msgResult,
                  session.sessionKeys,
                );
              }
            }

            final msg = EncryptedMessage(
              msgId: msgResult.msgId,
              ciphertext: msgResult.ciphertext,
              nonce: msgResult.nonce,
              senderEphemeralPk: msgResult.senderEphemeralPk,
              type: _parseMessageType(payload['type'] as String? ?? 'text'),
              timestamp: msgResult.timestamp,
              status: _parseStatus(json['delivery_status'] as String? ?? 'sent'),
              isOwn: false,
              displayContent: decryptedContent,
            );
            onMessageReceived?.call(msg);
          } catch (e) {
            debugPrint('Decrypt message failed: ');
          }
          break;

        case 'message_sent':
          break;

        case 'participant_left':
          onRoomEnded?.call();
          break;

        case 'room_destroyed':
          _currentRoomId = null;
          _roomSessions.clear();
          break;

        case 'screenshot_detected':
        case 'screen_recording_detected':
        case 'security_warning':
          onSecurityEvent?.call(json['message'] as String? ?? 'Security event');
          break;

        case 'file_upload_accepted':
        case 'file_chunk_received':
        case 'file_upload_complete':
          break;

        case 'error':
          debugPrint('Server error: ');
          break;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error handling message: ');
    }
  }

  void _setConnectionState(ConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  void _scheduleReconnect(String serverUrl) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _setConnectionState(ConnectionState.error);
      return;
    }

    _reconnectAttempts++;
    _setConnectionState(ConnectionState.reconnecting);

    final delay = Duration(seconds: _exponentialBackoff(_reconnectAttempts));

    _reconnectTimer = Timer(delay, () {
      connect(serverUrl);
    });
  }

  int _exponentialBackoff(int attempt) {
    int result = 1;
    for (int i = 0; i < attempt; i++) {
      result *= 2;
    }
    return result.clamp(1, 30);
  }

  void _send(Map<String, dynamic> message) {
    if (_channel?.sink != null && _connectionState == ConnectionState.connected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  Future<void> _processQueuedMessages() async {
    if (_messageQueue.isEmpty) return;

    final queued = List.from(_messageQueue);
    _messageQueue.clear();

    for (final msg in queued) {
      _send(msg);
    }

    await _storage.clearQueuedMessages();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    disconnect();
    super.dispose();
  }
}

MessageType _parseMessageType(String type) {
  return MessageType.values.firstWhere(
    (m) => m.name == type,
    orElse: () => MessageType.text,
  );
}

MessageStatus _parseStatus(String status) {
  return MessageStatus.values.firstWhere(
    (m) => m.name == status,
    orElse: () => MessageStatus.sent,
  );
}
