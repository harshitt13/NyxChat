import 'dart:convert';

enum MessageStatus { sending, sent, delivered, read, failed }
enum MessageType { text, image, file, reaction, system, voice }

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
  final String? fileDataB64;  // Legacy field (unused in v3)
  final String? thumbnailB64; // Thumbnail for images
  final String? fileId;       // Transfer id (v3)
  final String? fileKeyB64;   // Per-file AES key (v3, needed for retries)
  final String? fileNonceB64; // Per-file nonce prefix (v3)
  final String? sha256Hex;    // Integrity of the plaintext file (v3)
  final int totalChunks;      // Chunks in the transfer (v3)
  final int receivedChunks;   // Progress (v3)

  FileAttachment({
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    this.filePath,
    this.fileDataB64,
    this.thumbnailB64,
    this.fileId,
    this.fileKeyB64,
    this.fileNonceB64,
    this.sha256Hex,
    this.totalChunks = 0,
    this.receivedChunks = 0,
  });

  bool get isComplete => totalChunks == 0 || receivedChunks >= totalChunks;
  double get progress => totalChunks == 0 ? 1.0 : receivedChunks / totalChunks;

  FileAttachment copyWith(
          {String? filePath, int? receivedChunks, String? thumbnailB64}) =>
      FileAttachment(
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileSize,
        filePath: filePath ?? this.filePath,
        fileDataB64: fileDataB64,
        thumbnailB64: thumbnailB64 ?? this.thumbnailB64,
        fileId: fileId,
        fileKeyB64: fileKeyB64,
        fileNonceB64: fileNonceB64,
        sha256Hex: sha256Hex,
        totalChunks: totalChunks,
        receivedChunks: receivedChunks ?? this.receivedChunks,
      );

  bool get isImage =>
      mimeType.startsWith('image/');

  bool get isAudio => mimeType.startsWith('audio/');

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
    'thumbnailB64': thumbnailB64,
    'fileId': fileId,
    'fileKeyB64': fileKeyB64,
    'fileNonceB64': fileNonceB64,
    'sha256Hex': sha256Hex,
    'totalChunks': totalChunks,
    'receivedChunks': receivedChunks,
  };

  factory FileAttachment.fromJson(Map<String, dynamic> json) =>
      FileAttachment(
        fileName: json['fileName'] as String,
        mimeType: json['mimeType'] as String,
        fileSize: json['fileSize'] as int,
        filePath: json['filePath'] as String?,
        thumbnailB64: json['thumbnailB64'] as String?,
        fileId: json['fileId'] as String?,
        fileKeyB64: json['fileKeyB64'] as String?,
        fileNonceB64: json['fileNonceB64'] as String?,
        sha256Hex: json['sha256Hex'] as String?,
        totalChunks: json['totalChunks'] as int? ?? 0,
        receivedChunks: json['receivedChunks'] as int? ?? 0,
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
  final DateTime? expiresAt;      // Disappearing messages
  final List<String> deliveredTo; // Group delivery receipts
  final List<String> readBy;      // Group read receipts
  /// Type-specific extras: `durationMs` and `voice` for voice notes,
  /// `w`/`h` (preview pixel size) for images. Small and JSON-safe; the
  /// image preview itself lives on [attachment].
  final Map<String, dynamic> metadata;

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
    this.expiresAt,
    this.deliveredTo = const [],
    this.readBy = const [],
    this.metadata = const {},
  });

  bool get isVoice => messageType == MessageType.voice;

  /// Length of a voice note as announced by the sender.
  Duration? get voiceDuration {
    final ms = metadata['durationMs'];
    return ms is int && ms >= 0 ? Duration(milliseconds: ms) : null;
  }

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

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
    DateTime? expiresAt,
    List<String>? deliveredTo,
    List<String>? readBy,
    Map<String, dynamic>? metadata,
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
      expiresAt: expiresAt ?? this.expiresAt,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      readBy: readBy ?? this.readBy,
      metadata: metadata ?? this.metadata,
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
    'expiresAt': expiresAt?.toIso8601String(),
    'deliveredTo': deliveredTo,
    'readBy': readBy,
    if (metadata.isNotEmpty) 'metadata': metadata,
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
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.parse(json['expiresAt'] as String),
    deliveredTo: (json['deliveredTo'] as List<dynamic>?)?.cast<String>() ?? const [],
    readBy: (json['readBy'] as List<dynamic>?)?.cast<String>() ?? const [],
    metadata: json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : const {},
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
