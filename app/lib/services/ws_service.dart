/// WebSocket service for server communication
/// Handles connection, room lifecycle, message sending/receiving

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/message.dart';
import '../models/room.dart';
import 'crypto_service.dart';
import 'storage_service.dart';

class WsService extends ChangeNotifier {
  final CryptoService _crypto;
  final StorageService _storage;
  
  WebSocketChannel? _channel;
  String? _clientId;
  String? _currentRoomId;
  ConnectionState _connectionState = ConnectionState.disconnected;
  
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
    // Load queued messages
    _messageQueue.addAll(await _storage.getQueuedMessages());
    notifyListeners();
  }
  
  /// Connect to the WebSocket server
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
          debugPrint('WebSocket error: $error');
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
      debugPrint('WebSocket connection failed: $e');
      _setConnectionState(ConnectionState.error);
      _scheduleReconnect(serverUrl);
    }
  }
  
  /// Disconnect from server
  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setConnectionState(ConnectionState.disconnected);
    _currentRoomId = null;
  }
  
  /// Create a new room
  void createRoom() {
    _send({'type': 'create_room'});
  }
  
  /// Join an existing room
  void joinRoom(String roomId) {
    _send({'type': 'join_room', 'room_id': roomId});
  }
  
  /// Send an encrypted message
  Future<void> sendMessage(String content, {String? roomId}) async {
    if (_connectionState != ConnectionState.connected) {
      // Queue for later
      _messageQueue.add({
        'type': 'text',
        'content': content,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await _storage.saveQueuedMessages(_messageQueue);
      return;
    }
    
    // TODO: Encrypt message with crypto service
    final msg = {
      'type': 'encrypted_message_send',
      'ciphertext': content, // Placeholder - should be encrypted
      'nonce': '',
      'sender_ephemeral_pk': '',
      'type': 'text',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'msg_id': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    
    _send(msg);
  }
  
  /// Leave current room
  void leaveRoom() {
    if (_currentRoomId != null) {
      _send({'type': 'participant_left'});
      _currentRoomId = null;
    }
  }
  
  /// Request room destruction
  void destroyRoom() {
    if (_currentRoomId != null) {
      _send({'type': 'room_destroy'});
      _currentRoomId = null;
    }
  }
  
  /// Send security event
  void sendSecurityEvent(String eventType) {
    _send({
      'type': eventType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String?;
      
      if (type == null) return;
      
      switch (type) {
        case 'connected':
          _clientId = json['client_id'] as String?;
          _setConnectionState(ConnectionState.connected);
          _reconnectAttempts = 0;
          
          // Process queued messages
          _processQueuedMessages();
          break;
          
        case 'room_created':
          _currentRoomId = json['room_id'] as String?;
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
          
        case 'encrypted_message_receive':
          final msg = EncryptedMessage.fromJson(json);
          onMessageReceived?.call(msg);
          break;
          
        case 'message_sent':
          // Acknowledge to sender
          break;
          
        case 'participant_left':
          onRoomEnded?.call();
          break;
          
        case 'room_destroyed':
          _currentRoomId = null;
          break;
          
        case 'screenshot_detected':
        case 'screen_recording_detected':
        case 'security_warning':
          onSecurityEvent?.call(json['message'] as String? ?? 'Security event');
          break;
          
        case 'file_upload_accepted':
        case 'file_chunk_received':
        case 'file_upload_complete':
          // File upload handling
          break;
          
        case 'error':
          debugPrint('Server error: ${json['message']}');
          break;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling message: $e');
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
    
    final delay = Duration(
      seconds: pow(2, _reconnectAttempts).toInt().clamp(1, 30),
    );
    
    _reconnectTimer = Timer(delay, () {
      connect(serverUrl);
    });
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

// Simple power function
int pow(int base, int exp) {
  int result = 1;
  for (int i = 0; i < exp; i++) {
    result *= base;
  }
  return result;
}
