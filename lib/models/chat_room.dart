import 'dart:convert';
import 'message.dart';

enum ChatRoomType { direct, group }

class GroupMember {
  final String bitChatId;
  final String displayName;
  final String publicKeyHex;
  final bool isAdmin;
  final DateTime joinedAt;

  GroupMember({
    required this.bitChatId,
    required this.displayName,
    required this.publicKeyHex,
    this.isAdmin = false,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
    'bitChatId': bitChatId,
    'displayName': displayName,
    'publicKeyHex': publicKeyHex,
    'isAdmin': isAdmin,
    'joinedAt': joinedAt.toIso8601String(),
  };

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
    bitChatId: json['bitChatId'] as String,
    displayName: json['displayName'] as String,
    publicKeyHex: json['publicKeyHex'] as String,
    isAdmin: json['isAdmin'] as bool? ?? false,
    joinedAt: DateTime.parse(json['joinedAt'] as String),
  );
}

class ChatRoom {
  final String id;
  final String peerId;           // For direct chats
  final String peerDisplayName;  // For direct chats OR group name
  final String peerPublicKeyHex; // For direct chats
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final ChatRoomType roomType;
  final List<GroupMember> members; // For group chats
  final String? groupDescription;

  ChatRoom({
    required this.id,
    required this.peerId,
    required this.peerDisplayName,
    required this.peerPublicKeyHex,
    this.messages = const [],
    required this.createdAt,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.roomType = ChatRoomType.direct,
    this.members = const [],
    this.groupDescription,
  });

  bool get isGroup => roomType == ChatRoomType.group;

  ChatMessage? get lastMessage =>
      messages.isNotEmpty ? messages.last : null;

  String get displayInitials {
    final name = peerDisplayName;
    if (name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  // Keep backward compatibility
  String get peerInitials => displayInitials;

  int get memberCount => isGroup ? members.length : 2;

  ChatRoom copyWith({
    String? id,
    String? peerId,
    String? peerDisplayName,
    String? peerPublicKeyHex,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    int? unreadCount,
    ChatRoomType? roomType,
    List<GroupMember>? members,
    String? groupDescription,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      peerDisplayName: peerDisplayName ?? this.peerDisplayName,
      peerPublicKeyHex: peerPublicKeyHex ?? this.peerPublicKeyHex,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      roomType: roomType ?? this.roomType,
      members: members ?? this.members,
      groupDescription: groupDescription ?? this.groupDescription,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'peerId': peerId,
    'peerDisplayName': peerDisplayName,
    'peerPublicKeyHex': peerPublicKeyHex,
    'createdAt': createdAt.toIso8601String(),
    'lastMessageAt': lastMessageAt?.toIso8601String(),
    'unreadCount': unreadCount,
    'roomType': roomType.name,
    'members': members.map((m) => m.toJson()).toList(),
    'groupDescription': groupDescription,
  };

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
    id: json['id'] as String,
    peerId: json['peerId'] as String,
    peerDisplayName: json['peerDisplayName'] as String,
    peerPublicKeyHex: json['peerPublicKeyHex'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastMessageAt: json['lastMessageAt'] != null
        ? DateTime.parse(json['lastMessageAt'] as String)
        : null,
    unreadCount: json['unreadCount'] as int? ?? 0,
    roomType: ChatRoomType.values.firstWhere(
      (e) => e.name == (json['roomType'] ?? 'direct'),
      orElse: () => ChatRoomType.direct,
    ),
    members: (json['members'] as List<dynamic>?)
        ?.map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
        .toList() ?? [],
    groupDescription: json['groupDescription'] as String?,
  );

  String encode() => jsonEncode(toJson());

  factory ChatRoom.decode(String data) =>
      ChatRoom.fromJson(jsonDecode(data) as Map<String, dynamic>);
}
