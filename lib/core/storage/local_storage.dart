import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants.dart';
import '../../models/message.dart';
import '../../models/chat_room.dart';
import '../../models/peer.dart';
import '../../models/user_identity.dart';
import 'key_value_store.dart';

/// Encrypted local storage (Hive, AES-256-CBC per box, key held in the
/// platform keystore via AppLockService).
///
/// Boxes: messages, chat_rooms, peers, user, trust (pinned keys),
/// sessions (ratchet state), groupkeys (sender keys), outbox (pending
/// deliveries), prekeys (one-time ML-KEM prekeys, ours and our contacts').
/// All boxes are opened with the same master key.
class LocalStorage {
  static const String trustBox = 'trust';
  static const String sessionsBox = 'sessions';
  static const String groupKeysBox = 'groupkeys';
  static const String outboxBox = 'outbox';
  static const String prekeysBox = 'prekeys';

  static const List<String> _allBoxes = [
    AppConstants.messagesBox,
    AppConstants.chatRoomsBox,
    AppConstants.peersBox,
    AppConstants.userBox,
    trustBox,
    sessionsBox,
    groupKeysBox,
    outboxBox,
    prekeysBox,
  ];

  final Map<String, Box<String>> _boxes = {};
  String _suffix = '';

  /// Suffix appended to box names (used for the duress decoy profile).
  String get profileSuffix => _suffix;

  bool get isDatabasesOpen =>
      _allBoxes.every((b) => _boxes[b]?.isOpen ?? false);

  Box<String>? _box(String name) => _boxes[name];
  Box<String>? get _messagesBox => _box(AppConstants.messagesBox);
  Box<String>? get _chatRoomsBox => _box(AppConstants.chatRoomsBox);
  Box<String>? get _peersBox => _box(AppConstants.peersBox);
  Box<String>? get _userBox => _box(AppConstants.userBox);

  KeyValueStore get trustStore =>
      HiveKeyValueStore(() => _boxes[trustBox]!);
  KeyValueStore get sessionStore =>
      HiveKeyValueStore(() => _boxes[sessionsBox]!);
  KeyValueStore get groupKeyStore =>
      HiveKeyValueStore(() => _boxes[groupKeysBox]!);
  KeyValueStore get outboxStore =>
      HiveKeyValueStore(() => _boxes[outboxBox]!);
  KeyValueStore get prekeyStore =>
      HiveKeyValueStore(() => _boxes[prekeysBox]!);

  /// Initialise Hive. [directory] overrides the platform documents
  /// directory (used by tests and tools that run outside Flutter).
  Future<void> init({String? directory}) async {
    if (directory != null) {
      Hive.init(directory);
    } else {
      await Hive.initFlutter();
    }
  }

  /// Open all boxes. If existing files cannot be decrypted the corrupted
  /// files are deleted and recreated so the app is never bricked; identity
  /// keys live in secure storage and are reconstructed by IdentityService.
  Future<void> openDatabases(List<int> encryptionKey,
      {String profileSuffix = ''}) async {
    _suffix = profileSuffix;
    final cipher = HiveAesCipher(encryptionKey);
    try {
      await _openAll(cipher);
    } catch (e) {
      debugPrint('[Storage] failed to open encrypted boxes: $e');
      debugPrint('[Storage] deleting corrupted box files and recreating');
      await _safeCloseAll();
      for (final b in _allBoxes) {
        try {
          await Hive.deleteBoxFromDisk('$b$_suffix');
        } catch (_) {}
      }
      await _openAll(cipher);
    }
    debugPrint('[Storage] boxes open (${_suffix.isEmpty ? 'primary' : 'decoy'})');
  }

  Future<void> _openAll(HiveAesCipher cipher) async {
    for (final b in _allBoxes) {
      _boxes[b] = await Hive.openBox<String>('$b$_suffix', encryptionCipher: cipher);
    }
  }

  Future<void> closeAll() async {
    await _safeCloseAll();
  }

  Future<void> _safeCloseAll() async {
    for (final b in _boxes.values) {
      if (b.isOpen) await b.close();
    }
    _boxes.clear();
  }

  // User identity

  Future<void> saveUserIdentity(UserIdentity identity) async =>
      _userBox?.put('identity', identity.encode());

  Future<UserIdentity?> getUserIdentity() async {
    final data = _userBox?.get('identity');
    return data == null ? null : UserIdentity.decode(data);
  }

  Future<void> putSetting(String key, String value) async =>
      _userBox?.put('setting:$key', value);
  String? getSetting(String key) => _userBox?.get('setting:$key');

  // Messages

  Future<void> saveMessage(ChatMessage message) async =>
      _messagesBox?.put(message.id, message.encode());

  Future<ChatMessage?> getMessage(String id) async {
    final data = _messagesBox?.get(id);
    return data == null ? null : ChatMessage.decode(data);
  }

  Future<void> deleteMessage(String id) async => _messagesBox?.delete(id);

  Future<void> updateMessageStatus(String id, MessageStatus status) async {
    final msg = await getMessage(id);
    if (msg != null) await saveMessage(msg.copyWith(status: status));
  }

  Future<List<ChatMessage>> getMessagesForRoom(String roomId) async {
    final out = <ChatMessage>[];
    final box = _messagesBox;
    if (box == null || !box.isOpen) return out;
    for (final key in box.keys) {
      final data = box.get(key);
      if (data == null) continue;
      try {
        final msg = ChatMessage.decode(data);
        if (msg.roomId == roomId) out.add(msg);
      } catch (_) {}
    }
    out.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return out;
  }

  Future<List<ChatMessage>> getAllMessages() async {
    final out = <ChatMessage>[];
    final box = _messagesBox;
    if (box == null || !box.isOpen) return out;
    for (final key in box.keys) {
      final data = box.get(key);
      if (data == null) continue;
      try {
        out.add(ChatMessage.decode(data));
      } catch (_) {}
    }
    return out;
  }

  Future<void> deleteMessagesForRoom(String roomId) async {
    final box = _messagesBox;
    if (box == null || !box.isOpen) return;
    final toDelete = <dynamic>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data == null) continue;
      try {
        if (ChatMessage.decode(data).roomId == roomId) toDelete.add(key);
      } catch (_) {
        toDelete.add(key);
      }
    }
    await box.deleteAll(toDelete);
  }

  // Chat rooms

  Future<void> saveChatRoom(ChatRoom room) async =>
      _chatRoomsBox?.put(room.id, room.encode());

  Future<void> deleteChatRoom(String roomId) async =>
      _chatRoomsBox?.delete(roomId);

  Future<List<ChatRoom>> getChatRooms() async {
    final rooms = <ChatRoom>[];
    final box = _chatRoomsBox;
    if (box == null || !box.isOpen) return rooms;
    for (final key in box.keys) {
      final data = box.get(key);
      if (data == null) continue;
      try {
        rooms.add(ChatRoom.decode(data));
      } catch (_) {}
    }
    rooms.sort((a, b) {
      final at = a.lastMessageAt ?? a.createdAt;
      final bt = b.lastMessageAt ?? b.createdAt;
      return bt.compareTo(at);
    });
    return rooms;
  }

  Future<ChatRoom?> getChatRoomByPeerId(String peerId) async {
    for (final room in await getChatRooms()) {
      if (room.peerId == peerId && !room.isGroup) return room;
    }
    return null;
  }

  // Peers

  Future<void> savePeer(Peer peer) async =>
      _peersBox?.put(peer.nyxChatId, peer.encode());

  Future<List<Peer>> getPeers() async {
    final peers = <Peer>[];
    final box = _peersBox;
    if (box == null || !box.isOpen) return peers;
    for (final key in box.keys) {
      final data = box.get(key);
      if (data == null) continue;
      try {
        peers.add(Peer.decode(data));
      } catch (_) {}
    }
    return peers;
  }

  Future<Peer?> getPeer(String nyxChatId) async {
    final data = _peersBox?.get(nyxChatId);
    return data == null ? null : Peer.decode(data);
  }

  Future<void> deletePeer(String nyxChatId) async =>
      _peersBox?.delete(nyxChatId);

  // Backup

  /// Every box as {boxName: {key: value}}.
  Map<String, Map<String, String>> exportAll() {
    final out = <String, Map<String, String>>{};
    for (final e in _boxes.entries) {
      if (!e.value.isOpen) continue;
      final m = <String, String>{};
      for (final k in e.value.keys) {
        final v = e.value.get(k);
        if (v != null) m[k.toString()] = v;
      }
      out[e.key] = m;
    }
    return out;
  }

  /// Replace the contents of every box with [data].
  Future<void> importAll(Map<String, dynamic> data) async {
    for (final e in data.entries) {
      final box = _boxes[e.key];
      final entries = e.value;
      if (box == null || !box.isOpen || entries is! Map) continue;
      await box.clear();
      await box.putAll(entries.map((k, v) => MapEntry(k.toString(), v.toString())));
    }
  }

  // Cleanup

  Future<void> clearAll() async {
    for (final b in _boxes.values) {
      if (b.isOpen) await b.clear();
    }
  }

  /// Delete every box file of the current profile from disk.
  Future<void> panicWipe() async {
    debugPrint('[Storage] panic wipe');
    await _safeCloseAll();
    for (final b in _allBoxes) {
      try {
        await Hive.deleteBoxFromDisk('$b$_suffix');
      } catch (e) {
        debugPrint('[Storage] wipe $b failed: $e');
      }
    }
  }

  /// Delete both the primary and the decoy profile.
  Future<void> wipeAllProfiles() async {
    await _safeCloseAll();
    for (final suffix in const ['', '_decoy']) {
      for (final b in _allBoxes) {
        try {
          await Hive.deleteBoxFromDisk('$b$suffix');
        } catch (_) {}
      }
    }
  }
}