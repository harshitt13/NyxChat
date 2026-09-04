import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/crypto/double_ratchet.dart';
import '../core/crypto/sender_keys.dart';
import '../core/crypto/session_manager.dart';
import '../core/mesh/mesh_router.dart';
import '../core/network/connection_manager.dart';
import '../core/network/file_transfer_manager.dart';
import '../core/network/message_protocol.dart';
import '../core/network/p2p_client.dart';
import '../core/network/p2p_server.dart';
import '../core/protocol/envelope.dart';
import '../core/protocol/inner_message.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/outbox.dart';
import '../core/storage/trust_store.dart';
import '../models/chat_room.dart';
import '../models/message.dart';

/// How a message left the device.
enum DeliveryPath { direct, mesh, queued, failed }

/// Messaging engine.
///
/// Every payload becomes an [InnerMessage], is sealed into an [Envelope]
/// (pairwise Double Ratchet for direct messages and group control traffic,
/// Sender Keys for group content) and is handed to whichever transport is
/// available: authenticated TCP link, BLE mesh, or the persistent outbox.
/// Inbound traffic from any transport flows through the same path.
class ChatService extends ChangeNotifier {
  static const String _skStateKey = 'senderkeys';
  static const String _skDistPrefix = 'dist:';
  static const int _maxRecentIds = 4000;

  final LocalStorage _storage;
  final P2PClient _client;
  final TrustStore _trust;
  final SessionManager _sessions;
  final Outbox _outbox;
  final ConnectionManager _connections;
  final MeshRouter? _mesh;
  final SenderKeyManager _senderKeys = SenderKeyManager();
  final FileTransferManager files = FileTransferManager();
  final Uuid _uuid = const Uuid();

  String _myId = '';
  String _myName = '';
  bool _initialized = false;
  bool sendReadReceipts = true;

  /// Set by PeerService: number of live BLE links (mesh availability).
  int Function()? meshLinkCountProvider;

  final Map<String, ChatRoom> _rooms = {};
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, Set<String>> _skDistributed = {};
  final LinkedHashSet<String> _recentInnerIds = LinkedHashSet();
  final List<StreamSubscription> _subs = [];
  Timer? _expiryTimer;
  Timer? _outboxTimer;

  final StreamController<ChatMessage> _incoming = StreamController.broadcast();
  final StreamController<String> _roomChanged = StreamController.broadcast();

  Stream<ChatMessage> get onIncomingMessage => _incoming.stream;
  Stream<String> get onRoomChanged => _roomChanged.stream;

  ChatService({
    required LocalStorage storage,
    required P2PClient client,
    required TrustStore trust,
    required SessionManager sessions,
    required Outbox outbox,
    required ConnectionManager connections,
    MeshRouter? meshRouter,
  })  : _storage = storage,
        _client = client,
        _trust = trust,
        _sessions = sessions,
        _outbox = outbox,
        _connections = connections,
        _mesh = meshRouter;

  String get myId => _myId;
  Outbox get outbox => _outbox;
  TrustStore get trust => _trust;

  // Lifecycle

  Future<void> init({required String myId, required String displayName}) async {
    _myId = myId;
    _myName = displayName;
    if (_initialized) return;
    _initialized = true;

    for (final room in await _storage.getChatRooms()) {
      _rooms[room.id] = room;
      _messages[room.id] = await _storage.getMessagesForRoom(room.id);
    }
    _loadSenderKeys();
    await _outbox.load();

    _subs.add(_connections.onPeerReady.listen(_attachConnection));
    _subs.add(_connections.onSessionEstablished.listen(_onSessionEstablished));
    _mesh?.onPacketForMe = (packet) {
      unawaited(_handleEnvelopeBytes(packet.payload, via: null));
    };

    _expiryTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _sweepExpired());
    _outboxTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => flushAllOutbox());
    await _sweepExpired();
    notifyListeners();
  }

  void _loadSenderKeys() {
    final store = _storage.groupKeyStore;
    final raw = store.get(_skStateKey);
    if (raw != null) {
      try {
        _senderKeys.loadJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Chat] sender key state corrupt: $e');
      }
    }
    for (final key in store.keys) {
      if (!key.startsWith(_skDistPrefix)) continue;
      try {
        final list =
            (jsonDecode(store.get(key)!) as List<dynamic>).cast<String>();
        _skDistributed[key.substring(_skDistPrefix.length)] = list.toSet();
      } catch (_) {}
    }
  }

  Future<void> _persistSenderKeys() async {
    final store = _storage.groupKeyStore;
    await store.put(_skStateKey, jsonEncode(_senderKeys.toJson()));
    for (final e in _skDistributed.entries) {
      await store.put('$_skDistPrefix${e.key}', jsonEncode(e.value.toList()));
    }
  }

  void _attachConnection(PeerConnection conn) {
    final peerId = conn.peerId;
    if (peerId == null) return;
    late final StreamSubscription sub;
    sub = conn.onMessage.listen((m) async {
      switch (m.type) {
        case ProtocolMessageType.envelope:
          await _handleEnvelopeJson(m.payload, via: conn);
          break;
        case ProtocolMessageType.fileChunk:
          await _handleChunk(m.payload, peerId);
          break;
        case ProtocolMessageType.sessionReset:
          await _handleSessionReset(conn);
          break;
        case ProtocolMessageType.meshPacket:
          try {
            await _mesh?.handlePacket(m.asMeshPacket());
          } catch (e) {
            debugPrint('[Chat] bad mesh packet over TCP: $e');
          }
          break;
        default:
          break;
      }
    }, onDone: () => sub.cancel());
  }
  Future<void> _onSessionEstablished(SessionEvent ev) async {
    if (ev.isNew && ev.isInitiator) {
      await _sendSessionOpen(ev.peerId);
    }
    if (ev.isNew) await _requeueUndelivered(ev.peerId);
    await _outbox.resetBackoff(ev.peerId);
    await flushOutbox(ev.peerId);
  }

  Future<void> _sendSessionOpen(String peerId) async {
    try {
      final env = await _sessions.encrypt(
          peerId: peerId, message: InnerMessage.sessionOpen(id: _uuid.v4()));
      await _client.sendToPeer(peerId, ProtocolMessage.envelope(env));
    } catch (e) {
      debugPrint('[Chat] session open to $peerId failed: $e');
    }
  }

  /// After a session reset, messages that were sent but never confirmed
  /// delivered are re-queued so nothing is silently lost.
  Future<void> _requeueUndelivered(String peerId) async {
    final room = _directRoomFor(peerId);
    if (room == null) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 6));
    final candidates = (_messages[room.id] ?? [])
        .where((m) =>
            m.senderId == _myId &&
            m.messageType == MessageType.text &&
            m.status == MessageStatus.sent &&
            m.timestamp.isAfter(cutoff))
        .toList()
        .reversed
        .take(20);
    for (final m in candidates) {
      final inner = InnerMessage.text(
        id: m.id,
        text: m.content,
        replyToId: m.replyToId,
        disappearAfterSeconds:
            room.disappearAfterSeconds > 0 ? room.disappearAfterSeconds : null,
      );
      await _outbox.enqueue(
          OutboxItem.inner(peerId: peerId, message: inner, messageId: m.id));
    }
  }

  // Rooms

  List<ChatRoom> get chatRooms {
    final rooms = _rooms.values.toList();
    rooms.sort((a, b) {
      final at = a.lastMessageAt ?? a.createdAt;
      final bt = b.lastMessageAt ?? b.createdAt;
      return bt.compareTo(at);
    });
    return rooms;
  }

  ChatRoom? room(String roomId) => _rooms[roomId];
  List<ChatMessage> getMessages(String roomId) =>
      List.unmodifiable(_messages[roomId] ?? const []);

  ChatRoom? _directRoomFor(String peerId) {
    for (final r in _rooms.values) {
      if (!r.isGroup && r.peerId == peerId) return r;
    }
    return null;
  }

  Future<ChatRoom> getOrCreateDirectRoom(
      {required String peerId, required String displayName}) async {
    final existing = _directRoomFor(peerId);
    if (existing != null) {
      if (existing.peerDisplayName != displayName && displayName.isNotEmpty) {
        final updated = existing.copyWith(peerDisplayName: displayName);
        _rooms[existing.id] = updated;
        await _storage.saveChatRoom(updated);
        notifyListeners();
        return updated;
      }
      return existing;
    }
    final pinned = _trust.get(peerId);
    final room = ChatRoom(
      id: _uuid.v4(),
      peerId: peerId,
      peerDisplayName: displayName.isNotEmpty ? displayName : peerId,
      peerPublicKeyHex: pinned?.identityKeyHex ?? '',
      createdAt: DateTime.now(),
    );
    _rooms[room.id] = room;
    _messages[room.id] = [];
    await _storage.saveChatRoom(room);
    notifyListeners();
    return room;
  }

  Future<void> markRoomAsRead(String roomId) async {
    final room = _rooms[roomId];
    if (room == null) return;
    if (room.unreadCount != 0) {
      final updated = room.copyWith(unreadCount: 0);
      _rooms[roomId] = updated;
      await _storage.saveChatRoom(updated);
    }
    if (sendReadReceipts) {
      final unread = (_messages[roomId] ?? [])
          .where((m) =>
              m.senderId != _myId &&
              m.status != MessageStatus.read &&
              (m.messageType == MessageType.text ||
                  m.messageType == MessageType.file ||
                  m.messageType == MessageType.image))
          .toList();
      final bySender = <String, List<String>>{};
      for (final m in unread) {
        bySender.putIfAbsent(m.senderId, () => []).add(m.id);
        await _updateMessage(
            roomId, m.id, (x) => x.copyWith(status: MessageStatus.read));
      }
      for (final e in bySender.entries) {
        await _deliver(
            e.key,
            InnerMessage.receipt(
                id: _uuid.v4(),
                messageIds: e.value,
                kind: 'read',
                groupId: room.isGroup ? roomId : null),
            queueOnFailure: false);
      }
    }
    notifyListeners();
  }

  Future<void> setDisappearing(String roomId, int seconds) async {
    final room = _rooms[roomId];
    if (room == null) return;
    final updated = room.copyWith(disappearAfterSeconds: seconds);
    _rooms[roomId] = updated;
    await _storage.saveChatRoom(updated);
    notifyListeners();
  }

  Future<void> setMuted(String roomId, bool muted) async {
    final room = _rooms[roomId];
    if (room == null) return;
    final updated = room.copyWith(muted: muted);
    _rooms[roomId] = updated;
    await _storage.saveChatRoom(updated);
    notifyListeners();
  }

  Future<void> deleteRoom(String roomId) async {
    _rooms.remove(roomId);
    _messages.remove(roomId);
    await _storage.deleteMessagesForRoom(roomId);
    await _storage.deleteChatRoom(roomId);
    notifyListeners();
  }

  Future<void> deleteMessage(String roomId, String messageId) async {
    _messages[roomId]?.removeWhere((m) => m.id == messageId);
    await _storage.deleteMessage(messageId);
    await _outbox.removeForMessage(messageId);
    notifyListeners();
  }
  // Sending

  Future<ChatMessage?> sendText({
    required String roomId,
    required String text,
    String? replyToId,
  }) async {
    final room = _rooms[roomId];
    if (room == null || text.trim().isEmpty) return null;
    final id = _uuid.v4();
    final ttl = room.disappearAfterSeconds;
    final msg = ChatMessage(
      id: id,
      senderId: _myId,
      receiverId: room.isGroup ? room.id : room.peerId,
      content: text,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      roomId: roomId,
      replyToId: replyToId,
      expiresAt: ttl > 0 ? DateTime.now().add(Duration(seconds: ttl)) : null,
    );
    await _addMessage(roomId, msg);
    final inner = InnerMessage.text(
      id: id,
      text: text,
      replyToId: replyToId,
      disappearAfterSeconds: ttl > 0 ? ttl : null,
      groupId: room.isGroup ? room.id : null,
    );
    final path = room.isGroup
        ? await _sendGroupInner(room, inner, messageId: id)
        : await _deliver(room.peerId, inner, messageId: id);
    await _applyPath(roomId, id, path);
    return _find(roomId, id);
  }

  Future<void> _applyPath(
      String roomId, String messageId, DeliveryPath path) async {
    final status = switch (path) {
      DeliveryPath.direct || DeliveryPath.mesh => MessageStatus.sent,
      DeliveryPath.queued => MessageStatus.sending,
      DeliveryPath.failed => MessageStatus.failed,
    };
    await _updateMessage(roomId, messageId, (m) => m.copyWith(status: status));
  }

  /// Send an inner message to one peer: direct link, else mesh, else outbox.
  Future<DeliveryPath> _deliver(String peerId, InnerMessage inner,
      {String? messageId, bool queueOnFailure = true}) async {
    final path = await _tryDeliver(peerId, inner);
    if (path == DeliveryPath.failed && queueOnFailure) {
      await _outbox.enqueue(OutboxItem.inner(
          peerId: peerId, message: inner, messageId: messageId));
      return DeliveryPath.queued;
    }
    return path;
  }

  Future<DeliveryPath> _tryDeliver(String peerId, InnerMessage inner) async {
    final pinned = _trust.get(peerId);
    if (_client.isPeerConnected(peerId)) {
      try {
        final env = await _sessions.encrypt(
            peerId: peerId, message: inner, pinned: pinned);
        await _client.sendToPeer(peerId, ProtocolMessage.envelope(env));
        return DeliveryPath.direct;
      } on SessionNotReadyException {
        return DeliveryPath.failed; // waits for the peer's session-open
      } catch (e) {
        debugPrint('[Chat] direct send to $peerId failed: $e');
      }
    }
    if (_meshAvailable && pinned != null) {
      try {
        final env = await _sessions.encrypt(
            peerId: peerId, message: inner, pinned: pinned);
        await _mesh!.send(recipientId: peerId, payload: env.toBytes());
        return DeliveryPath.mesh;
      } catch (e) {
        debugPrint('[Chat] mesh send to $peerId failed: $e');
      }
    }
    return DeliveryPath.failed;
  }

  bool get _meshAvailable =>
      _mesh != null &&
      _mesh.myHash != null &&
      (meshLinkCountProvider?.call() ?? 0) > 0;

  Future<DeliveryPath> _sendRawEnvelope(String peerId, Envelope env) async {
    if (_client.isPeerConnected(peerId)) {
      await _client.sendToPeer(peerId, ProtocolMessage.envelope(env));
      return DeliveryPath.direct;
    }
    if (_meshAvailable) {
      try {
        await _mesh!.send(recipientId: peerId, payload: env.toBytes());
        return DeliveryPath.mesh;
      } catch (_) {}
    }
    return DeliveryPath.failed;
  }

  // Outbox

  Future<void> flushOutbox(String peerId) async {
    for (final item in _outbox.dueForPeer(peerId)) {
      DeliveryPath path;
      try {
        if (item.kind == OutboxItem.kindInner) {
          path = await _tryDeliver(peerId, item.innerMessage);
        } else if (item.kind == OutboxItem.kindEnvelope) {
          path = await _sendRawEnvelope(peerId, Envelope.fromJson(item.payload));
        } else {
          path = DeliveryPath.failed;
        }
      } catch (e) {
        debugPrint('[Chat] outbox item ${item.id} failed: $e');
        path = DeliveryPath.failed;
      }
      if (path == DeliveryPath.direct || path == DeliveryPath.mesh) {
        await _outbox.remove(item.id);
        final mid = item.messageId;
        if (mid != null) {
          final roomId = _roomIdOfMessage(mid);
          if (roomId != null) {
            await _updateMessage(
                roomId,
                mid,
                (m) => m.status == MessageStatus.sending
                    ? m.copyWith(status: MessageStatus.sent)
                    : m);
          }
        }
      } else {
        await _outbox.markAttempt(item.id);
      }
    }
  }

  Future<void> flushAllOutbox() async {
    for (final peerId in _outbox.peersWithPending) {
      await flushOutbox(peerId);
    }
  }

  // Groups

  GroupMember _memberFromPinned(PinnedPeer p, {bool admin = false}) =>
      GroupMember(
        nyxChatId: p.nyxChatId,
        displayName: p.displayName,
        publicKeyHex: p.identityKeyHex,
        signingKeyHex: p.signingKeyHex,
        kyberKeyHex: p.kyberPublicKeyHex,
        isAdmin: admin,
        joinedAt: DateTime.now(),
      );

  GroupMember _selfMember({bool admin = false}) {
    final k = _sessions.keys;
    return GroupMember(
      nyxChatId: _myId,
      displayName: _myName,
      publicKeyHex: k.identityPublicKeyHex,
      signingKeyHex: k.signingPublicKeyHex,
      kyberKeyHex: k.kyberPublicKeyHex,
      isAdmin: admin,
      joinedAt: DateTime.now(),
    );
  }

  Future<ChatRoom> createGroup({
    required String name,
    required List<PinnedPeer> members,
    String? description,
  }) async {
    final groupId = _uuid.v4();
    final all = [_selfMember(admin: true), ...members.map(_memberFromPinned)];
    final room = ChatRoom(
      id: groupId,
      peerId: groupId,
      peerDisplayName: name,
      peerPublicKeyHex: '',
      createdAt: DateTime.now(),
      roomType: ChatRoomType.group,
      members: all,
      groupDescription: description,
    );
    _rooms[groupId] = room;
    _messages[groupId] = [];
    await _storage.saveChatRoom(room);
    await _addSystemMessage(groupId, 'Group "$name" created');
    await _broadcastGroupUpdate(room, 'create');
    notifyListeners();
    return room;
  }

  Future<void> addGroupMembers(String roomId, List<PinnedPeer> newMembers) async {
    final room = _rooms[roomId];
    if (room == null || !room.isGroup) return;
    final ids = room.members.map((m) => m.nyxChatId).toSet();
    final added = newMembers.where((p) => !ids.contains(p.nyxChatId)).toList();
    if (added.isEmpty) return;
    final updated = room.copyWith(
        members: [...room.members, ...added.map(_memberFromPinned)]);
    _rooms[roomId] = updated;
    await _storage.saveChatRoom(updated);
    await _addSystemMessage(
        roomId, '${added.map((p) => p.displayName).join(', ')} added');
    await _broadcastGroupUpdate(updated, 'add');
    notifyListeners();
  }

  Future<void> removeGroupMember(String roomId, String memberId) async {
    final room = _rooms[roomId];
    if (room == null || !room.isGroup) return;
    final updated = room.copyWith(
        members: room.members.where((m) => m.nyxChatId != memberId).toList());
    _rooms[roomId] = updated;
    await _storage.saveChatRoom(updated);
    await _addSystemMessage(roomId, 'Member removed');
    await _deliver(memberId, _groupUpdateInner(updated, 'remove'));
    await _broadcastGroupUpdate(updated, 'remove');
    await _rotateSenderKey(roomId);
    notifyListeners();
  }

  Future<void> leaveGroup(String roomId) async {
    final room = _rooms[roomId];
    if (room == null || !room.isGroup) return;
    final remaining = room.copyWith(
        members: room.members.where((m) => m.nyxChatId != _myId).toList(),
        left: true);
    _rooms[roomId] = remaining;
    await _storage.saveChatRoom(remaining);
    await _broadcastGroupUpdate(remaining, 'leave');
    _senderKeys.forgetGroup(roomId);
    _skDistributed.remove(roomId);
    await _persistSenderKeys();
    await _addSystemMessage(roomId, 'You left the group');
    notifyListeners();
  }

  Future<void> renameGroup(String roomId, String name) async {
    final room = _rooms[roomId];
    if (room == null || !room.isGroup) return;
    final updated = room.copyWith(peerDisplayName: name);
    _rooms[roomId] = updated;
    await _storage.saveChatRoom(updated);
    await _broadcastGroupUpdate(updated, 'rename');
    notifyListeners();
  }

  InnerMessage _groupUpdateInner(ChatRoom room, String action) =>
      InnerMessage.groupUpdate(
        id: _uuid.v4(),
        groupId: room.id,
        action: action,
        groupName: room.peerDisplayName,
        members: room.members.map((m) => m.toJson()).toList(),
        description: room.groupDescription,
      );

  Future<void> _broadcastGroupUpdate(ChatRoom room, String action) async {
    final inner = _groupUpdateInner(room, action);
    for (final m in room.members) {
      if (m.nyxChatId == _myId) continue;
      await _deliver(m.nyxChatId, inner);
    }
  }

  Future<void> _rotateSenderKey(String groupId) async {
    if (!_senderKeys.hasOwnKey(groupId)) return;
    await _senderKeys.rotateOwn(groupId);
    _skDistributed[groupId] = {};
    await _persistSenderKeys();
  }

  Future<void> _ensureSenderKeyDistributed(ChatRoom room) async {
    final dist = await _senderKeys.ownDistribution(room.id);
    final sent = _skDistributed.putIfAbsent(room.id, () => {});
    for (final m in room.members) {
      if (m.nyxChatId == _myId || sent.contains(m.nyxChatId)) continue;
      await _deliver(
          m.nyxChatId,
          InnerMessage.senderKeyDistribution(
              id: _uuid.v4(), groupId: room.id, distribution: dist.toJson()));
      sent.add(m.nyxChatId);
    }
    await _persistSenderKeys();
  }

  Future<DeliveryPath> _sendGroupInner(ChatRoom room, InnerMessage inner,
      {String? messageId}) async {
    await _ensureSenderKeyDistributed(room);
    final ad = Envelope.associatedDataFor(_myId, room.id, EnvelopeKind.senderKey);
    final skm = await _senderKeys.encrypt(room.id, inner.toBytes(), ad);
    await _persistSenderKeys();
    final env = Envelope.senderKey(
      from: _myId,
      groupId: room.id,
      iteration: skm.iteration,
      ciphertext: skm.ciphertext,
      signature: skm.signature,
    );
    var anyDirect = false;
    var anyQueued = false;
    for (final m in room.members) {
      if (m.nyxChatId == _myId) continue;
      final path = await _sendRawEnvelope(m.nyxChatId, env);
      if (path == DeliveryPath.failed) {
        anyQueued = true;
        await _outbox.enqueue(OutboxItem(
          id: '${m.nyxChatId}_${inner.id}',
          peerId: m.nyxChatId,
          kind: OutboxItem.kindEnvelope,
          payload: env.toJson(),
          messageId: messageId,
        ));
      } else {
        anyDirect = true;
      }
    }
    if (anyDirect) return DeliveryPath.direct;
    return anyQueued ? DeliveryPath.queued : DeliveryPath.failed;
  }

  // Reactions

  Future<void> toggleReaction({
    required String roomId,
    required String messageId,
    required String emoji,
  }) async {
    final room = _rooms[roomId];
    final msg = _find(roomId, messageId);
    if (room == null || msg == null) return;
    final mine = msg.reactions.where((r) => r.userId == _myId).toList();
    final remove = mine.isNotEmpty && mine.first.emoji == emoji;
    final updated = remove
        ? msg.removeReaction(_myId)
        : msg.addReaction(MessageReaction(
            userId: _myId, emoji: emoji, timestamp: DateTime.now()));
    await _replaceMessage(roomId, updated);
    final inner = InnerMessage.reaction(
        id: _uuid.v4(),
        targetMessageId: messageId,
        emoji: emoji,
        remove: remove,
        groupId: room.isGroup ? room.id : null);
    if (room.isGroup) {
      await _sendGroupInner(room, inner);
    } else {
      await _deliver(room.peerId, inner);
    }
  }
  // Files

  Future<ChatMessage?> sendFile(
      {required String roomId, required String filePath}) async {
    final room = _rooms[roomId];
    if (room == null) return null;
    final file = File(filePath);
    if (!await file.exists()) return null;
    final targets = room.isGroup
        ? room.members
            .map((m) => m.nyxChatId)
            .where((id) => id != _myId)
            .toList()
        : [room.peerId];
    final online = targets.where(_client.isPeerConnected).toList();
    if (online.isEmpty) {
      debugPrint('[Chat] file transfer needs a direct link');
      return null;
    }
    final fileId = _uuid.v4();
    final mime = _mimeFor(file.path);
    final d = await FileTransferManager.describe(file,
        fileId: fileId, mimeType: mime);
    final msg = ChatMessage(
      id: fileId,
      senderId: _myId,
      receiverId: room.isGroup ? room.id : room.peerId,
      content: d.fileName,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      roomId: roomId,
      messageType:
          mime.startsWith('image/') ? MessageType.image : MessageType.file,
      attachment: FileAttachment(
        fileName: d.fileName,
        mimeType: mime,
        fileSize: d.fileSize,
        filePath: filePath,
        fileId: fileId,
        fileKeyB64: base64Encode(d.key),
        fileNonceB64: base64Encode(d.noncePrefix),
        sha256Hex: d.sha256Hex,
        totalChunks: d.totalChunks,
        receivedChunks: d.totalChunks,
      ),
    );
    await _addMessage(roomId, msg);
    final inner = InnerMessage.file(
      id: fileId,
      fileId: fileId,
      fileName: d.fileName,
      mimeType: mime,
      fileSize: d.fileSize,
      fileKey: d.key,
      fileNonce: d.noncePrefix,
      totalChunks: d.totalChunks,
      chunkSize: d.chunkSize,
      sha256Hex: d.sha256Hex,
      groupId: room.isGroup ? room.id : null,
    );
    var sentAny = false;
    for (final peerId in online) {
      final path = await _deliver(peerId, inner,
          messageId: fileId, queueOnFailure: false);
      if (path != DeliveryPath.direct) continue;
      sentAny = true;
      unawaited(_streamChunks(file, d, peerId));
    }
    await _updateMessage(
        roomId,
        fileId,
        (m) => m.copyWith(
            status: sentAny ? MessageStatus.sent : MessageStatus.failed));
    return _find(roomId, fileId);
  }

  Future<void> _streamChunks(File file, FileDescriptor d, String peerId) async {
    for (var i = 0; i < d.totalChunks; i++) {
      if (!_client.isPeerConnected(peerId)) return;
      final frame = await FileTransferManager.encryptChunk(file, d, i);
      await _client.sendToPeer(
          peerId, ProtocolMessage.fileChunk(frame.toJson()));
      if (i % 8 == 7) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }
  }

  Future<void> _handleChunk(Map<String, dynamic> json, String fromPeer) async {
    try {
      final frame = FileChunkFrame.fromJson(json);
      if (!files.isExpecting(frame.fileId)) return;
      final done = await files.accept(frame);
      final roomId = _roomIdOfMessage(frame.fileId);
      if (roomId == null) return;
      final received =
          files.incoming[frame.fileId]?.received.length ?? frame.total;
      await _updateMessage(
          roomId,
          frame.fileId,
          (m) => m.copyWith(
                attachment: m.attachment?.copyWith(receivedChunks: received),
                status: done != null ? MessageStatus.delivered : m.status,
              ));
      if (done != null) {
        await _deliver(
            fromPeer,
            InnerMessage.receipt(
                id: _uuid.v4(), messageIds: [frame.fileId], kind: 'delivered'),
            queueOnFailure: false);
      }
    } catch (e) {
      debugPrint('[Chat] chunk error: $e');
    }
  }

  // Inbound

  Future<void> _handleEnvelopeBytes(List<int> bytes,
      {PeerConnection? via}) async {
    try {
      await _handleEnvelope(Envelope.fromBytes(bytes), via: via);
    } catch (e) {
      debugPrint('[Chat] bad envelope bytes: $e');
    }
  }

  Future<void> _handleEnvelopeJson(Map<String, dynamic> json,
      {PeerConnection? via}) async {
    try {
      await _handleEnvelope(Envelope.fromJson(json), via: via);
    } catch (e) {
      debugPrint('[Chat] bad envelope: $e');
    }
  }

  Future<void> _handleEnvelope(Envelope env, {PeerConnection? via}) async {
    if (via != null && via.peerId != env.from) {
      debugPrint('[Chat] envelope sender does not match link peer, dropped');
      return;
    }
    if (env.kind == EnvelopeKind.senderKey) {
      await _handleGroupEnvelope(env);
      return;
    }
    if (env.to != _myId) return;
    final pinned = _trust.get(env.from);
    InnerMessage inner;
    try {
      inner = await _sessions.decrypt(env, pinned: pinned);
    } on SessionCollisionException {
      return;
    } on SessionNotReadyException {
      return;
    } on RatchetException catch (e) {
      debugPrint('[Chat] undecryptable envelope from ${env.from}: $e');
      if (via != null) await _requestSessionReset(via);
      return;
    } on NoSessionException {
      if (via != null) await _requestSessionReset(via);
      return;
    } catch (e) {
      debugPrint('[Chat] envelope error from ${env.from}: $e');
      return;
    }
    await _handleInner(env.from, inner);
  }

  Future<void> _requestSessionReset(PeerConnection via) async {
    if (via.resetsSent >= 2) return;
    via.noteResetSent();
    await _connections.resetSession(via);
    await via.send(ProtocolMessage.sessionReset(reason: 'undecryptable'));
  }

  Future<void> _handleSessionReset(PeerConnection via) async {
    debugPrint('[Chat] session reset requested by ${via.peerId}');
    await _connections.resetSession(via);
  }

  Future<void> _handleGroupEnvelope(Envelope env) async {
    final room = _rooms[env.to];
    if (room == null || !room.isGroup || room.left) return;
    if (!room.members.any((m) => m.nyxChatId == env.from)) return;
    if (!_senderKeys.hasPeerKey(env.to, env.from)) {
      debugPrint('[Chat] no sender key for ${env.from} in ${env.to} yet');
      return;
    }
    try {
      final ad =
          Envelope.associatedDataFor(env.from, env.to, EnvelopeKind.senderKey);
      final plain = await _senderKeys.decrypt(
        groupId: env.to,
        senderId: env.from,
        message:
            SenderKeyMessage(env.iteration!, env.ciphertext, env.signature!),
        associatedData: ad,
      );
      await _persistSenderKeys();
      await _handleInner(env.from, InnerMessage.fromBytes(plain),
          groupId: env.to);
    } catch (e) {
      debugPrint('[Chat] group envelope from ${env.from} failed: $e');
    }
  }

  Future<void> _handleInner(String from, InnerMessage m,
      {String? groupId}) async {
    if (!_recentInnerIds.add('$from:${m.id}')) return;
    if (_recentInnerIds.length > _maxRecentIds) {
      _recentInnerIds.remove(_recentInnerIds.first);
    }
    final gid = groupId ?? m.groupId;
    switch (m.type) {
      case InnerMessage.typeText:
        await _onText(from, m, gid);
        break;
      case InnerMessage.typeFile:
        await _onFile(from, m, gid);
        break;
      case InnerMessage.typeReaction:
        await _onReaction(from, m);
        break;
      case InnerMessage.typeReceipt:
        await _onReceipt(from, m);
        break;
      case InnerMessage.typeSenderKey:
        await _onSenderKey(from, m);
        break;
      case InnerMessage.typeGroupUpdate:
        await _onGroupUpdate(from, m);
        break;
      case InnerMessage.typeSessionOpen:
        await _outbox.resetBackoff(from);
        await flushOutbox(from);
        break;
      default:
        break;
    }
  }

  Future<ChatRoom?> _roomForInbound(String from, String? gid) async {
    if (gid != null) {
      final r = _rooms[gid];
      if (r == null || !r.isGroup || r.left) return null;
      if (!r.members.any((m) => m.nyxChatId == from)) return null;
      return r;
    }
    final name = _trust.get(from)?.displayName ?? from;
    return getOrCreateDirectRoom(peerId: from, displayName: name);
  }

  Future<void> _onText(String from, InnerMessage m, String? gid) async {
    final room = await _roomForInbound(from, gid);
    if (room == null) return;
    if (await _storage.getMessage(m.id) != null) return;
    final ttl = m.body['ttl'];
    final msg = ChatMessage(
      id: m.id,
      senderId: from,
      receiverId: gid ?? _myId,
      content: m.text,
      timestamp: m.timestamp.toLocal(),
      status: MessageStatus.delivered,
      roomId: room.id,
      replyToId: m.body['replyTo'] as String?,
      expiresAt: ttl is int && ttl > 0
          ? DateTime.now().add(Duration(seconds: ttl))
          : null,
    );
    await _addMessage(room.id, msg, incoming: true);
    await _deliver(
        from,
        InnerMessage.receipt(
            id: _uuid.v4(), messageIds: [m.id], kind: 'delivered', groupId: gid),
        queueOnFailure: false);
  }

  Future<void> _onFile(String from, InnerMessage m, String? gid) async {
    final room = await _roomForInbound(from, gid);
    if (room == null) return;
    final d = FileDescriptor.fromInnerBody(m.body);
    if (await _storage.getMessage(d.fileId) != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/nyxchat_files/${d.fileId}_${d.fileName}';
    await files.begin(d, savePath);
    final msg = ChatMessage(
      id: d.fileId,
      senderId: from,
      receiverId: gid ?? _myId,
      content: d.fileName,
      timestamp: m.timestamp.toLocal(),
      status: MessageStatus.sent,
      roomId: room.id,
      messageType: d.mimeType.startsWith('image/')
          ? MessageType.image
          : MessageType.file,
      attachment: FileAttachment(
        fileName: d.fileName,
        mimeType: d.mimeType,
        fileSize: d.fileSize,
        filePath: savePath,
        fileId: d.fileId,
        sha256Hex: d.sha256Hex,
        totalChunks: d.totalChunks,
        receivedChunks: 0,
      ),
    );
    await _addMessage(room.id, msg, incoming: true);
  }

  Future<void> _onReaction(String from, InnerMessage m) async {
    final target = m.body['target'] as String?;
    final emoji = m.body['emoji'] as String?;
    if (target == null || emoji == null) return;
    final roomId = _roomIdOfMessage(target);
    if (roomId == null) return;
    final msg = _find(roomId, target);
    if (msg == null) return;
    final updated = (m.body['remove'] == true)
        ? msg.removeReaction(from)
        : msg.addReaction(MessageReaction(
            userId: from, emoji: emoji, timestamp: DateTime.now()));
    await _replaceMessage(roomId, updated);
  }

  Future<void> _onReceipt(String from, InnerMessage m) async {
    final ids = (m.body['ids'] as List<dynamic>?)?.cast<String>() ?? const [];
    final kind = m.body['kind'] as String?;
    for (final id in ids) {
      final roomId = _roomIdOfMessage(id);
      if (roomId == null) continue;
      await _updateMessage(roomId, id, (msg) {
        if (msg.senderId != _myId) return msg;
        if (kind == 'read') {
          return msg.copyWith(
            status: MessageStatus.read,
            readBy: {...msg.readBy, from}.toList(),
            deliveredTo: {...msg.deliveredTo, from}.toList(),
          );
        }
        return msg.copyWith(
          status: msg.status == MessageStatus.read
              ? msg.status
              : MessageStatus.delivered,
          deliveredTo: {...msg.deliveredTo, from}.toList(),
        );
      });
    }
  }

  Future<void> _onSenderKey(String from, InnerMessage m) async {
    final gid = m.body['groupId'] as String?;
    final dist = m.body['dist'];
    if (gid == null || dist is! Map<String, dynamic>) return;
    final room = _rooms[gid];
    if (room == null || !room.members.any((x) => x.nyxChatId == from)) return;
    _senderKeys.processDistribution(from, SenderKeyDistribution.fromJson(dist));
    await _persistSenderKeys();
  }
  Future<void> _onGroupUpdate(String from, InnerMessage m) async {
    final gid = m.body['groupId'] as String?;
    final action = m.body['action'] as String?;
    final name = m.body['name'] as String? ?? 'Group';
    final membersJson = (m.body['members'] as List<dynamic>?) ?? const [];
    if (gid == null || action == null) return;
    final members = <GroupMember>[];
    for (final j in membersJson) {
      try {
        members.add(GroupMember.fromJson(j as Map<String, dynamic>));
      } catch (_) {}
    }
    final existing = _rooms[gid];
    if (existing != null &&
        !existing.members.any((x) => x.nyxChatId == from)) {
      return; // only current members may change the group
    }
    // Pin unknown members (trust-on-first-use via the inviter).
    for (final mem in members) {
      if (mem.nyxChatId == _myId ||
          _trust.get(mem.nyxChatId) != null ||
          !mem.hasFullKeys) {
        continue;
      }
      try {
        await _trust.pinFromContactCard({
          'nyx': 3,
          'id': mem.nyxChatId,
          'name': mem.displayName,
          'ik': mem.publicKeyHex,
          'sk': mem.signingKeyHex,
          'kpk': mem.kyberKeyHex,
        }, verified: false);
      } catch (e) {
        debugPrint('[Chat] could not pin group member ${mem.nyxChatId}: $e');
      }
    }
    final iAmMember = members.any((x) => x.nyxChatId == _myId);
    final room = (existing ??
            ChatRoom(
              id: gid,
              peerId: gid,
              peerDisplayName: name,
              peerPublicKeyHex: '',
              createdAt: DateTime.now(),
              roomType: ChatRoomType.group,
            ))
        .copyWith(
      peerDisplayName: name,
      members: members,
      groupDescription: m.body['description'] as String?,
      left: !iAmMember,
    );
    final isNew = existing == null;
    _rooms[gid] = room;
    _messages.putIfAbsent(gid, () => []);
    await _storage.saveChatRoom(room);
    final who = _trust.get(from)?.displayName ?? from;
    final text = switch (action) {
      'create' => 'You were added to "$name" by $who',
      'add' => '$who updated the members',
      'remove' =>
        iAmMember ? 'A member was removed' : 'You were removed from the group',
      'leave' => '$who left the group',
      'rename' => '$who renamed the group to "$name"',
      _ => 'Group updated',
    };
    await _addSystemMessage(gid, text, from: from);
    if (!isNew && (action == 'remove' || action == 'leave') && iAmMember) {
      await _rotateSenderKey(gid);
    }
    if (action == 'leave' || action == 'remove') {
      final gone = existing?.members
              .where((x) => !members.any((y) => y.nyxChatId == x.nyxChatId))
              .map((x) => x.nyxChatId) ??
          const <String>[];
      for (final g in gone) {
        _senderKeys.forgetPeer(gid, g);
      }
      await _persistSenderKeys();
    }
    notifyListeners();
  }

  // Message bookkeeping

  ChatMessage? _find(String roomId, String id) {
    for (final m in _messages[roomId] ?? const <ChatMessage>[]) {
      if (m.id == id) return m;
    }
    return null;
  }

  String? _roomIdOfMessage(String messageId) {
    for (final e in _messages.entries) {
      if (e.value.any((m) => m.id == messageId)) return e.key;
    }
    return null;
  }

  Future<void> _addMessage(String roomId, ChatMessage msg,
      {bool incoming = false}) async {
    await _storage.saveMessage(msg);
    final list = _messages.putIfAbsent(roomId, () => []);
    list.add(msg);
    final room = _rooms[roomId];
    if (room != null) {
      final updated = room.copyWith(
        lastMessageAt: msg.timestamp,
        unreadCount: incoming ? room.unreadCount + 1 : room.unreadCount,
      );
      _rooms[roomId] = updated;
      await _storage.saveChatRoom(updated);
    }
    if (incoming) _incoming.add(msg);
    _roomChanged.add(roomId);
    notifyListeners();
  }

  Future<void> _addSystemMessage(String roomId, String text,
      {String? from}) async {
    await _addMessage(
        roomId,
        ChatMessage(
          id: _uuid.v4(),
          senderId: from ?? _myId,
          receiverId: roomId,
          content: text,
          timestamp: DateTime.now(),
          status: MessageStatus.delivered,
          roomId: roomId,
          messageType: MessageType.system,
        ));
  }

  Future<void> _replaceMessage(String roomId, ChatMessage updated) async {
    final list = _messages[roomId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == updated.id);
    if (idx == -1) return;
    list[idx] = updated;
    await _storage.saveMessage(updated);
    _roomChanged.add(roomId);
    notifyListeners();
  }

  Future<void> _updateMessage(
      String roomId, String id, ChatMessage Function(ChatMessage) fn) async {
    final m = _find(roomId, id);
    if (m == null) return;
    final updated = fn(m);
    if (identical(updated, m)) return;
    await _replaceMessage(roomId, updated);
  }

  Future<void> _sweepExpired() async {
    var changed = false;
    for (final e in _messages.entries) {
      final expired = e.value.where((m) => m.isExpired).toList();
      for (final m in expired) {
        e.value.remove(m);
        await _storage.deleteMessage(m.id);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  static String _mimeFor(String path) {
    final ext = path.split('.').last.toLowerCase();
    const types = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
      'ogg': 'audio/ogg',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'zip': 'application/zip',
    };
    return types[ext] ?? 'application/octet-stream';
  }

  /// Forget everything in memory (panic wipe).
  Future<void> clearAll() async {
    _rooms.clear();
    _messages.clear();
    _skDistributed.clear();
    _senderKeys.clear();
    _recentInnerIds.clear();
    await _outbox.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _outboxTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _incoming.close();
    _roomChanged.close();
    super.dispose();
  }
}