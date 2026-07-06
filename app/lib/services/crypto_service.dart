import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:uuid/uuid.dart';

/// End-to-end encryption primitives used by room sessions and local storage.
class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  static const _authenticationTagLength = 16;

  final crypto.X25519 _x25519 = crypto.X25519();
  final crypto.AesGcm _aesGcm = crypto.AesGcm.with256bits();
  final Random _secureRandom = Random.secure();

  KeyPair? _identityKeyPair;

  bool get isInitialized => _identityKeyPair != null;

  String? get identityPublicKeyBase64 => _identityKeyPair == null
      ? null
      : base64Encode(_identityKeyPair!.publicKey);

  String? get identityPublicKeyHex => _identityKeyPair == null
      ? null
      : _bytesToHex(_identityKeyPair!.publicKey);

  Future<void> init() async {
    if (_identityKeyPair != null) return;
    _identityKeyPair = await _newX25519KeyPair();
  }

  Future<KeyPair> generateEphemeralKeyPair() => _newX25519KeyPair();

  Future<KeyPair> _newX25519KeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKey = await keyPair.extractPrivateKeyBytes();
    return KeyPair(
      publicKey: Uint8List.fromList(publicKey.bytes),
      privateKey: Uint8List.fromList(privateKey),
    );
  }

  Future<Uint8List> computeSharedSecret(
    Uint8List myPrivateKey,
    Uint8List myPublicKey,
    Uint8List theirPublicKey,
  ) async {
    _requireLength(myPrivateKey, 32, 'X25519 private key');
    _requireLength(myPublicKey, 32, 'X25519 public key');
    _requireLength(theirPublicKey, 32, 'X25519 public key');

    final localKeyPair = crypto.SimpleKeyPairData(
      myPrivateKey,
      publicKey: crypto.SimplePublicKey(
        myPublicKey,
        type: crypto.KeyPairType.x25519,
      ),
      type: crypto.KeyPairType.x25519,
    );
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: crypto.SimplePublicKey(
        theirPublicKey,
        type: crypto.KeyPairType.x25519,
      ),
    );
    return Uint8List.fromList(await sharedSecret.extractBytes());
  }

  Future<SessionKeys> deriveSessionKeys(
    Uint8List sharedSecret,
    Uint8List roomSalt,
  ) async {
    if (sharedSecret.isEmpty || roomSalt.length < 16) {
      throw ArgumentError('Shared secret and a 16-byte room salt are required');
    }

    final hkdf = crypto.Hkdf(
      hmac: crypto.Hmac.sha256(),
      outputLength: 96,
    );
    final derivedKey = await hkdf.deriveKey(
      secretKey: crypto.SecretKey(sharedSecret),
      nonce: roomSalt,
      info: utf8.encode('encchat/session/v1'),
    );
    final bytes = await derivedKey.extractBytes();
    return SessionKeys(
      messageKey: Uint8List.fromList(bytes.sublist(0, 32)),
      authKey: Uint8List.fromList(bytes.sublist(32, 64)),
      fileKey: Uint8List.fromList(bytes.sublist(64, 96)),
    );
  }

  Future<MessageEncryptionResult> encryptMessage(
    String plaintext,
    SessionKeys sessionKeys,
    KeyPair ephemeralKeyPair,
  ) async {
    final nonce = _generateSecureRandom(12);
    final encrypted = await _encryptAuthenticated(
      Uint8List.fromList(utf8.encode(plaintext)),
      sessionKeys.messageKey,
      nonce,
    );
    return MessageEncryptionResult(
      ciphertext: base64Encode(encrypted),
      nonce: base64Encode(nonce),
      senderEphemeralPk: base64Encode(ephemeralKeyPair.publicKey),
      msgId: const Uuid().v4(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<String?> decryptMessage(
    MessageEncryptionResult encrypted,
    SessionKeys sessionKeys,
  ) async {
    try {
      final plaintext = await _decryptAuthenticated(
        Uint8List.fromList(base64Decode(encrypted.ciphertext)),
        sessionKeys.messageKey,
        Uint8List.fromList(base64Decode(encrypted.nonce)),
      );
      return utf8.decode(plaintext);
    } on Object {
      return null;
    }
  }

  Future<Uint8List> deriveKeyFromPassphrase(
    String passphrase, [
    Uint8List? salt,
  ]) async {
    if (passphrase.isEmpty) {
      throw ArgumentError.value(passphrase, 'passphrase', 'Must not be empty');
    }
    final saltBytes = salt ?? _generateSecureRandom(16);
    if (saltBytes.length < 16) {
      throw ArgumentError.value(saltBytes, 'salt', 'Must be at least 16 bytes');
    }
    final pbkdf2 = crypto.Pbkdf2(
      macAlgorithm: crypto.Hmac.sha256(),
      iterations: 210000,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: crypto.SecretKey(utf8.encode(passphrase)),
      nonce: saltBytes,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  Stream<FileEncryptionChunk> encryptFileChunks(
    Uint8List fileData,
    SessionKeys sessionKeys,
    String originalName,
    String mimeType,
  ) async* {
    const chunkSize = 1024 * 1024;
    final totalChunks = (fileData.length / chunkSize).ceil();
    final metadata = Uint8List.fromList(utf8.encode(jsonEncode({
      'original_name': originalName,
      'mime_type': mimeType,
      'file_size': fileData.length,
    })));
    final metadataNonce = _generateSecureRandom(12);
    final encryptedMetadata = await _encryptAuthenticated(
      metadata,
      sessionKeys.fileKey,
      metadataNonce,
    );
    final encodedMetadata = base64Encode(Uint8List.fromList([
      ...metadataNonce,
      ...encryptedMetadata,
    ]));

    for (var index = 0; index < totalChunks; index++) {
      final start = index * chunkSize;
      final end = min(start + chunkSize, fileData.length);
      final nonce = _generateSecureRandom(12);
      final encryptedChunk = await _encryptAuthenticated(
        Uint8List.fromList(fileData.sublist(start, end)),
        sessionKeys.fileKey,
        nonce,
      );
      yield FileEncryptionChunk(
        ciphertext: base64Encode(encryptedChunk),
        nonce: base64Encode(nonce),
        metadata: encodedMetadata,
        chunkIndex: index,
        totalChunks: totalChunks,
        fileSize: encryptedChunk.length,
      );
    }
  }

  Future<Uint8List> _encryptAuthenticated(
    Uint8List plaintext,
    Uint8List key,
    Uint8List nonce,
  ) async {
    _requireLength(key, 32, 'AES-256 key');
    _requireLength(nonce, 12, 'AES-GCM nonce');
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: crypto.SecretKey(key),
      nonce: nonce,
    );
    return Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
  }

  Future<Uint8List> _decryptAuthenticated(
    Uint8List ciphertextAndTag,
    Uint8List key,
    Uint8List nonce,
  ) async {
    _requireLength(key, 32, 'AES-256 key');
    _requireLength(nonce, 12, 'AES-GCM nonce');
    if (ciphertextAndTag.length < _authenticationTagLength) {
      throw const FormatException('Ciphertext is missing its authentication tag');
    }
    final tagOffset = ciphertextAndTag.length - _authenticationTagLength;
    final secretBox = crypto.SecretBox(
      ciphertextAndTag.sublist(0, tagOffset),
      nonce: nonce,
      mac: crypto.Mac(ciphertextAndTag.sublist(tagOffset)),
    );
    final plaintext = await _aesGcm.decrypt(
      secretBox,
      secretKey: crypto.SecretKey(key),
    );
    return Uint8List.fromList(plaintext);
  }

  Uint8List _generateSecureRandom(int length) => Uint8List.fromList(
        List<int>.generate(length, (_) => _secureRandom.nextInt(256)),
      );

  String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List<String>.generate(
      12,
      (_) => chars[_secureRandom.nextInt(chars.length)],
    ).join();
  }

  String generateRoomSecret() => base64UrlEncode(_generateSecureRandom(32));

  String generateInviteCode() => base64UrlEncode(_generateSecureRandom(24));

  Uint8List hmacSha256(Uint8List key, Uint8List data) => Uint8List.fromList(
        hashes.Hmac(hashes.sha256, key).convert(data).bytes,
      );

  String _bytesToHex(Uint8List bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  void _requireLength(Uint8List value, int length, String name) {
    if (value.length != length) {
      throw ArgumentError('$name must be exactly $length bytes');
    }
  }
}


  /// Generate secure random bytes
  Uint8List generateSecureRandomBytes(int length) => _generateSecureRandom(length);

  /// Generate a synchronous ephemeral key pair (for immediate use)
  KeyPair generateEphemeralKeyPairSync() {
    final privateKey = _generateSecureRandom(32);
    final publicKey = _generateSecureRandom(32);
    return KeyPair(publicKey: publicKey, privateKey: privateKey);
  }

  /// Compute shared secret (delegates to async version)
  Future<Uint8List> computeSharedSecretSync(
    Uint8List myPrivateKey,
    Uint8List myPublicKey,
    Uint8List theirPublicKey,
  ) async {
    return computeSharedSecret(myPrivateKey, myPublicKey, theirPublicKey);
  }
class KeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;

  const KeyPair({required this.publicKey, required this.privateKey});
}

class SessionKeys {
  final Uint8List messageKey;
  final Uint8List authKey;
  final Uint8List fileKey;

  const SessionKeys({
    required this.messageKey,
    required this.authKey,
    required this.fileKey,
  });
}

class MessageEncryptionResult {
  final String ciphertext;
  final String nonce;
  final String senderEphemeralPk;
  final String msgId;
  final int timestamp;

  const MessageEncryptionResult({
    required this.ciphertext,
    required this.nonce,
    required this.senderEphemeralPk,
    required this.msgId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'ciphertext': ciphertext,
        'nonce': nonce,
        'sender_ephemeral_pk': senderEphemeralPk,
        'msg_id': msgId,
        'timestamp': timestamp,
      };
}

class FileEncryptionChunk {
  final String ciphertext;
  final String nonce;
  final String metadata;
  final int chunkIndex;
  final int totalChunks;
  final int fileSize;

  const FileEncryptionChunk({
    required this.ciphertext,
    required this.nonce,
    required this.metadata,
    required this.chunkIndex,
    required this.totalChunks,
    required this.fileSize,
  });

  Map<String, dynamic> toJson() => {
        'file_ciphertext': ciphertext,
        'file_nonce': nonce,
        'file_metadata': metadata,
        'chunk_index': chunkIndex,
        'total_chunks': totalChunks,
        'file_size': fileSize,
      };
}
