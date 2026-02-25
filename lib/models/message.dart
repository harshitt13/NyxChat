import 'dart:convert';

enum MessageStatus { sending, sent, delivered, read, failed }
enum MessageType { text, image, file, reaction, system }

class MessageReaction {
  final String userId;
  final String emoji;
  final DateTime timestamp;

  MessageReaction({
    required this.userId,
    required this.emoji,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'emoji': emoji,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MessageReaction.fromJson(Map<String, dynamic> json) =>
      MessageReaction(
        userId: json['userId'] as String,
        emoji: json['emoji'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class FileAttachment {
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String? filePath;     // Local path
  final String? fileDataB64;  // Base64-encoded for transfer
  final String? thumbnailB64; // Thumbnail for images

  FileAttachment({
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    this.filePath,
    this.fileDataB64,
    this.thumbnailB64,
  });

  bool get isImage =>
      mimeType.startsWith('image/');

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1048576) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / 1048576).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'mimeType': mimeType,
    'fileSize': fileSize,
    'filePath': filePath,
    'fileDataB64': fileDataB64,
    'thumbnailB64': thumbnailB64,
  };

  factory FileAttachment.fromJson(Map<String, dynamic> json) =>
      FileAttachment(
        fileName: json['fileName'] as String,
        mimeType: json['mimeType'] as String,
        fileSize: json['fileSize'] as int,
        filePath: json['filePath'] as String?,
        fileDataB64: json['fileDataB64'] as String?,
        thumbnailB64: json['thumbnailB64'] as String?,
      );
}

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final String? roomId;
  final MessageType messageType;
  final FileAttachment? attachment;
  final List<MessageReaction> reactions;
  final String? replyToId;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sending,
    this.roomId,
    this.messageType = MessageType.text,
    this.attachment,
    this.reactions = const [],
    this.replyToId,
  });

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    String? roomId,
    MessageType? messageType,
    FileAttachment? attachment,
    List<MessageReaction>? reactions,
    String? replyToId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      messageType: messageType ?? this.messageType,
      attachment: attachment ?? this.attachment,
      reactions: reactions ?? this.reactions,
      replyToId: replyToId ?? this.replyToId,
    );
  }

  /// Add a reaction to the message
  ChatMessage addReaction(MessageReaction reaction) {
    final updated = List<MessageReaction>.from(reactions);
    // Remove existing reaction from same user
    updated.removeWhere((r) => r.userId == reaction.userId);
    updated.add(reaction);
    return copyWith(reactions: updated);
  }

  /// Remove a reaction
  ChatMessage removeReaction(String userId) {
    final updated = List<MessageReaction>.from(reactions);
    updated.removeWhere((r) => r.userId == userId);
    return copyWith(reactions: updated);
  }

  /// Get reaction counts grouped by emoji
  Map<String, int> get reactionCounts {
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'status': status.name,
    'roomId': roomId,
    'messageType': messageType.name,
    'attachment': attachment?.toJson(),
    'reactions': reactions.map((r) => r.toJson()).toList(),
    'replyToId': replyToId,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    senderId: json['senderId'] as String,
    receiverId: json['receiverId'] as String,
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    status: MessageStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => MessageStatus.sent,
    ),
    roomId: json['roomId'] as String?,
    messageType: MessageType.values.firstWhere(
      (e) => e.name == (json['messageType'] ?? 'text'),
      orElse: () => MessageType.text,
    ),
    attachment: json['attachment'] != null
        ? FileAttachment.fromJson(json['attachment'] as Map<String, dynamic>)
        : null,
    reactions: (json['reactions'] as List<dynamic>?)
        ?.map((r) => MessageReaction.fromJson(r as Map<String, dynamic>))
        .toList() ?? [],
    replyToId: json['replyToId'] as String?,
  );

  String encode() => jsonEncode(toJson());

  factory ChatMessage.decode(String data) =>
      ChatMessage.fromJson(jsonDecode(data) as Map<String, dynamic>);

  @override
  String toString() => 'ChatMessage(id: $id, from: $senderId, type: ${messageType.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
