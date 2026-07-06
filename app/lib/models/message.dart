/// Message model representing an encrypted chat message

enum MessageStatus {
  sending,    // Being sent
  sent,       // Sent to server
  delivered,  // Delivered to peer
  read,       // Read by peer (optional)
  failed,     // Failed to send
}

enum MessageType {
  text,
  image,
  video,
  document,
  file,
  system,
  security_event,
  voice,
}

class EncryptedMessage {
  final String msgId;
  final String ciphertext;
  final String nonce;
  final String senderEphemeralPk;
  final MessageType type;
  final String? originalFilename;
  final int? fileSize;
  final String? encryptedFileId;
  final int timestamp;
  final MessageStatus status;
  final bool isOwn;
  
  /// Decrypted display content (populated after local decryption)
  final String? displayContent;
  
  const EncryptedMessage({
    required this.msgId,
    required this.ciphertext,
    required this.nonce,
    required this.senderEphemeralPk,
    required this.type,
    this.originalFilename,
    this.fileSize,
    this.encryptedFileId,
    required this.timestamp,
    this.status = MessageStatus.sending,
    this.isOwn = false,
    this.displayContent,
  });
  
  factory EncryptedMessage.fromJson(Map<String, dynamic> json) {
    return EncryptedMessage(
      msgId: json['msg_id'] as String? ?? '',
      ciphertext: json['ciphertext'] as String? ?? '',
      nonce: json['nonce'] as String? ?? '',
      senderEphemeralPk: json['sender_ephemeral_pk'] as String? ?? '',
      type: _parseMessageType(json['type'] as String? ?? 'text'),
      originalFilename: json['original_filename'] as String?,
      fileSize: json['file_size'] as int?,
      encryptedFileId: json['encrypted_file_id'] as String?,
      timestamp: json['timestamp'] as int? ?? 0,
      status: _parseStatus(json['delivery_status'] as String? ?? 'sent'),
      isOwn: false,
      displayContent: json['display_content'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'msg_id': msgId,
      'ciphertext': ciphertext,
      'nonce': nonce,
      'sender_ephemeral_pk': senderEphemeralPk,
      'type': type.name,
      if (originalFilename != null) 'original_filename': originalFilename,
      if (fileSize != null) 'file_size': fileSize,
      if (encryptedFileId != null) 'encrypted_file_id': encryptedFileId,
      'timestamp': timestamp,
      'delivery_status': status.name,
    };
  }
  
  static MessageType _parseMessageType(String type) {
    return MessageType.values.firstWhere(
      (m) => m.name == type,
      orElse: () => MessageType.text,
    );
  }
  
  static MessageStatus _parseStatus(String status) {
    return MessageStatus.values.firstWhere(
      (m) => m.name == status,
      orElse: () => MessageStatus.sent,
    );
  }
  
  EncryptedMessage copyWith({
    MessageStatus? status,
    String? displayContent,
    bool? isOwn,
  }) {
    return EncryptedMessage(
      msgId: msgId,
      ciphertext: ciphertext,
      nonce: nonce,
      senderEphemeralPk: senderEphemeralPk,
      type: type,
      originalFilename: originalFilename ?? this.originalFilename,
      fileSize: fileSize ?? this.fileSize,
      encryptedFileId: encryptedFileId ?? this.encryptedFileId,
      timestamp: timestamp,
      status: status ?? this.status,
      isOwn: isOwn ?? this.isOwn,
      displayContent: displayContent ?? this.displayContent,
    );
  }
}
