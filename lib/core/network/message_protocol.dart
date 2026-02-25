import 'dart:convert';

/// Wire protocol for NyxChat P2P communication.
/// Messages are JSON-encoded with a type field.
enum ProtocolMessageType {
  hello,         // Initial handshake
  message,       // Chat message (text)
  ack,           // Message acknowledgment
  keyExchange,   // Key exchange request/response
  peerList,      // Share known peers
  ping,          // Keep-alive
  pong,          // Keep-alive response
  disconnect,    // Graceful disconnect
  // New message types for advanced features
  groupCreate,   // Create a group chat
  groupInvite,   // Invite peers to a group
  groupMessage,  // Message in a group chat
  groupLeave,    // Leave a group
  fileTransfer,  // File/media transfer
  reaction,      // Message reaction
  keyRotation,   // Session key rotation (forward secrecy)
  dhtAnnounce,   // DHT peer announcement
  dhtLookup,     // DHT peer lookup
  dhtResponse,   // DHT lookup response
}

class ProtocolMessage {
  final ProtocolMessageType type;
  final String senderId;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final String? messageId;

  ProtocolMessage({
    required this.type,
    required this.senderId,
    required this.payload,
    DateTime? timestamp,
    this.messageId,
  }) : timestamp = timestamp ?? DateTime.now();

  // ─── Original factory constructors ─────────────────────────────

  factory ProtocolMessage.hello({
    required String senderId,
    required String displayName,
    required String publicKeyHex,
    required String signingPublicKeyHex,
    required int listeningPort,
  }) {
    return ProtocolMessage(
      type: ProtocolMessageType.hello,
      senderId: senderId,
      payload: {
        'displayName': displayName,
        'publicKeyHex': publicKeyHex,
        'signingPublicKeyHex': signingPublicKeyHex,
        'listeningPort': listeningPort,
        'protocolVersion': '2.0',
      },
    );
  }

  factory ProtocolMessage.chatMessage({
    required String senderId,
    required String receiverId,
    required String encryptedContent,
    required String messageId,
    String? messageType,
  }) {
    return ProtocolMessage(
      type: ProtocolMessageType.message,
      senderId: senderId,
      messageId: messageId,
      payload: {
        'receiverId': receiverId,
        'encryptedContent': encryptedContent,
        'messageType': messageType ?? 'text',
      },
    );
  }

  factory ProtocolMessage.ack({
    required String senderId,
    required String messageId,
  }) {
    return ProtocolMessage(
      type: ProtocolMessageType.ack,
      senderId: senderId,
      messageId: messageId,
      payload: {},
    );
  }

  factory ProtocolMessage.ping({required String senderId}) {
    return ProtocolMessage(
      type: ProtocolMessageType.ping,
      senderId: senderId,
      payload: {},
    );
  }

  factory ProtocolMessage.pong({required String senderId}) {
    return ProtocolMessage(
      type: ProtocolMessageType.pong,
      senderId: senderId,
      payload: {},
    );
  }

  factory ProtocolMessage.disconnect({required String senderId}) {
    return ProtocolMessage(
      type: ProtocolMessageType.disconnect,
      senderId: senderId,
      payload: {},
    );
  }

  // ─── Group chat factories ─────────────────────────────────────

  factory ProtocolMessage.groupCreate({
    required String senderId,
    required String groupId,
    required String groupName,
    required List<String> memberIds,
    String? description,
  }) {
    return ProtocolMessage(
      type: ProtocolMessageType.groupCreate,
      senderId: senderId,
      payload: {
        'groupId': groupId,
        'groupName': groupName,
        'memberIds': memberIds,
        'description': description,
      },
    );
  }

  factory ProtocolMessage.groupInvite({
    required String senderId,
    required String groupId,
    required String groupName,
    required List<Map<String, dynamic>> members,
  }) {
    return ProtocolMessage(
      type: ProtocolMessageType.groupInvite,
      senderId: senderId,
      payload: {
        'groupId': groupId,
        'groupName': groupName,
        'members': members,
      },
    );
  }

  factory ProtocolMessage.groupMessage({
    required String senderId,
    required String groupId,
    required String encryptedContent,
    required String messageId,
    String? messageType,
  }) {
    return ProtocolMessage(
      type: ProtocolMessageType.groupMessage,
      senderId: senderId,
      messageId: messageId,
      payload: {
        'groupId': groupId,
        'encryptedContent': encryptedContent,
        'messageType': messageType ?? 'text',
      },
    );
  }

  // ─── File transfer factory ────────────────────────────────────

  factory ProtocolMessage.fileTransfer({
    required String senderId,
    required String receiverId,
    required String messageId,
    required String fileName,
    required String mimeType,
    required int fileSize,
    required String encryptedDataB64,
    String? thumbnailB64,
    String? groupId,
  }) {
    return ProtocolMessage(
      type: ProtocolMessageType.fileTransfer,
      senderId: senderId,
      messageId: messageId,
      payload: {
        'receiverId': receiverId,
        'fileName': fileName,
        'mimeType': mimeType,
        'fileSize': fileSize,
        'encryptedDataB64': encryptedDataB64,
        'thumbnailB64': thumbnailB64,
        'groupId': groupId,
      },
    );
  }

  // ─── Reaction factory ─────────────────────────────────────────

  factory ProtocolMessage.reaction({
    required String senderId,
    required String targetMessageId,
    required String emoji,
    required String roomId,
    bool remove = false,
  }) {
    return ProtocolMessage(
      type: ProtocolMessageType.reaction,
      senderId: senderId,
      messageId: targetMessageId,
      payload: {
        'emoji': emoji,
        'roomId': roomId,
        'remove': remove,
      },
    );
  }

  // ─── Forward secrecy: key rotation ────────────────────────────

  factory ProtocolMessage.keyRotation({
    required String senderId,
    required String newPublicKeyHex,
    required int sessionId,
  }) {
    return ProtocolMessage(
      type: ProtocolMessageType.keyRotation,
      senderId: senderId,
      payload: {
        'newPublicKeyHex': newPublicKeyHex,
        'sessionId': sessionId,
      },
    );
  }

  // ─── DHT factories ───────────────────────────────────────────

  factory ProtocolMessage.dhtAnnounce({
    required String senderId,
    required String publicKeyHex,
    required String displayName,
    required String address,
    required int port,
  }) {
    return ProtocolMessage(
      type: ProtocolMessageType.dhtAnnounce,
      senderId: senderId,
      payload: {
        'publicKeyHex': publicKeyHex,
        'displayName': displayName,
        'address': address,
        'port': port,
      },
    );
  }

  factory ProtocolMessage.dhtLookup({
    required String senderId,
    required String targetId,
  }) {
    return ProtocolMessage(
      type: ProtocolMessageType.dhtLookup,
      senderId: senderId,
      payload: {'targetId': targetId},
    );
  }

  factory ProtocolMessage.dhtResponse({
    required String senderId,
    required String targetId,
    required List<Map<String, dynamic>> peers,
  }) {
    return ProtocolMessage(
      type: ProtocolMessageType.dhtResponse,
      senderId: senderId,
      payload: {
        'targetId': targetId,
        'peers': peers,
      },
    );
  }

  // ─── Serialization ─────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'senderId': senderId,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
    'messageId': messageId,
  };

  factory ProtocolMessage.fromJson(Map<String, dynamic> json) {
    return ProtocolMessage(
      type: ProtocolMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ProtocolMessageType.message,
      ),
      senderId: json['senderId'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      messageId: json['messageId'] as String?,
    );
  }

  String encode() => '${jsonEncode(toJson())}\n';

  factory ProtocolMessage.decode(String data) =>
      ProtocolMessage.fromJson(jsonDecode(data.trim()) as Map<String, dynamic>);

  @override
  String toString() =>
      'ProtocolMessage(${type.name}, from: $senderId, id: $messageId)';
}
