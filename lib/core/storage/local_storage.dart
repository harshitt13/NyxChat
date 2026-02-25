import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants.dart';
import '../../models/message.dart';
import '../../models/chat_room.dart';
import '../../models/peer.dart';
import '../../models/user_identity.dart';

/// Local storage using Hive for messages, chat rooms, peers, and user data.
class LocalStorage {
  late Box<String> _messagesBox;
  late Box<String> _chatRoomsBox;
  late Box<String> _peersBox;
  late Box<String> _userBox;

  /// Initialize Hive and open all boxes
  Future<void> init() async {
    await Hive.initFlutter();

    _messagesBox = await Hive.openBox<String>(AppConstants.messagesBox);
    _chatRoomsBox = await Hive.openBox<String>(AppConstants.chatRoomsBox);
    _peersBox = await Hive.openBox<String>(AppConstants.peersBox);
    _userBox = await Hive.openBox<String>(AppConstants.userBox);

    debugPrint('LocalStorage initialized');
  }

  // ─── User Identity ────────────────────────────────────────────

  Future<void> saveUserIdentity(UserIdentity identity) async {
    await _userBox.put('identity', identity.encode());
  }

  Future<UserIdentity?> getUserIdentity() async {
    final data = _userBox.get('identity');
    if (data == null) return null;
    return UserIdentity.decode(data);
  }

  // ─── Messages ─────────────────────────────────────────────────

  Future<void> saveMessage(ChatMessage message) async {
    await _messagesBox.put(message.id, message.encode());
  }

  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status,
  ) async {
    final data = _messagesBox.get(messageId);
    if (data != null) {
      final msg = ChatMessage.decode(data);
      final updated = msg.copyWith(status: status);
      await _messagesBox.put(messageId, updated.encode());
    }
  }

  Future<List<ChatMessage>> getMessagesForRoom(String roomId) async {
    final messages = <ChatMessage>[];
    for (final key in _messagesBox.keys) {
      final data = _messagesBox.get(key);
      if (data != null) {
        final msg = ChatMessage.decode(data);
        if (msg.roomId == roomId) {
          messages.add(msg);
        }
      }
    }
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  // ─── Chat Rooms ───────────────────────────────────────────────

  Future<void> saveChatRoom(ChatRoom room) async {
    await _chatRoomsBox.put(room.id, room.encode());
  }

  Future<List<ChatRoom>> getChatRooms() async {
    final rooms = <ChatRoom>[];
    for (final key in _chatRoomsBox.keys) {
      final data = _chatRoomsBox.get(key);
      if (data != null) {
        rooms.add(ChatRoom.decode(data));
      }
    }
    rooms.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime); // Most recent first
    });
    return rooms;
  }

  Future<ChatRoom?> getChatRoomByPeerId(String peerId) async {
    for (final key in _chatRoomsBox.keys) {
      final data = _chatRoomsBox.get(key);
      if (data != null) {
        final room = ChatRoom.decode(data);
        if (room.peerId == peerId) return room;
      }
    }
    return null;
  }

  // ─── Peers ────────────────────────────────────────────────────

  Future<void> savePeer(Peer peer) async {
    await _peersBox.put(peer.bitChatId, peer.encode());
  }

  Future<List<Peer>> getPeers() async {
    final peers = <Peer>[];
    for (final key in _peersBox.keys) {
      final data = _peersBox.get(key);
      if (data != null) {
        peers.add(Peer.decode(data));
      }
    }
    return peers;
  }

  Future<Peer?> getPeer(String bitChatId) async {
    final data = _peersBox.get(bitChatId);
    if (data == null) return null;
    return Peer.decode(data);
  }

  // ─── Cleanup ──────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _messagesBox.clear();
    await _chatRoomsBox.clear();
    await _peersBox.clear();
    await _userBox.clear();
  }
}
