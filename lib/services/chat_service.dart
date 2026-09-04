import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/crypto/double_ratchet.dart';
import '../core/crypto/key_transition.dart';
import '../core/crypto/pair_keys.dart';
import '../core/crypto/sender_keys.dart';
import '../core/crypto/session_manager.dart';
import '../core/mesh/geohash_channel.dart';
import '../core/mesh/mesh_packet.dart';
import '../core/mesh/mesh_router.dart';
import '../core/network/connection_manager.dart';
import '../core/network/file_transfer_manager.dart';
import '../core/network/message_protocol.dart';
import '../core/network/p2p_client.dart';
import '../core/network/p2p_server.dart';
import '../core/protocol/envelope.dart';
import '../core/protocol/inner_message.dart';
import '../core/protocol/padding.dart';
import '../core/relay/relay_transport.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/outbox.dart';
import '../core/storage/trust_store.dart';
import '../models/chat_room.dart';
import '../models/message.dart';
import 'identity_service.dart';

/// How a message left the device.
enum DeliveryPath { direct, mesh, relay, queued, failed }

class _OutgoingFile {
  final File file;
  final FileDescriptor descriptor;
  _OutgoingFile(this.file, this.descriptor);
}

/// Messaging engine (protocol v4).
///
/// Every payload becomes a padded [InnerMessage], is sealed into an
/// [Envelope] (pairwise Double Ratchet, or Sender Keys for groups) and is
/// handed to the first available carrier: an authenticated TCP link, the
/// mesh (sealed for the pair under rotating tokens), an internet relay
/// (same sealing), or the persistent outbox. Inbound traffic from every
/// carrier flows through the same path.
class ChatService extends ChangeNotifier {
  static const String _skStateKey = 'senderkeys';
  static const String _skDistPrefix = 'dist:';
  static const String typeChunkRequest = 'chunkreq';
  static const String typeKeyTransition = 'keytrans';
  static const String _kPendingTransition = 'pendingTransition';
  static const String _kTransitionRecipients = 'transitionRecipients';
  static const int _maxRecentIds = 4000;
  static const int maxMeshFileBytes = 4 * 1024 * 1024;

  final LocalStorage _storage;
  final P2PClient _client;
  final TrustStore _trust;
  final SessionManager _sessions;
  final Outbox _outbox;
  final ConnectionManager _connections;
  final MeshRouter? _mesh;
  final PairKeyCache _pairKeys;
  final SenderKeyManager _senderKeys = SenderKeyManager();
  final FileTransferManager files = FileTransferManager();
  final Uuid _uuid = const Uuid();

  /// Optional internet carrier (set by the composition root when enabled).
  RelayTransport? _relay;
  StreamSubscription? _relaySub;

  /// Where received files are written (injectable for tests).
  Future<String> Function()? filesDirectoryProvider;

  String _myId = '';
  String _myName = '';
  bool _initialized = false;
  bool sendReadReceipts = true;

  /// Set by PeerService: number of live mesh neighbours.
  int Function()? meshLinkCountProvider;

  final Map<String, ChatRoom> _rooms = {};
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, Set<String>> _skDistributed = {};
  final LinkedHashSet<String> _recentInnerIds = LinkedHashSet();
  final Map<String, String> _meshTokenOwner = {};
  final Map<String, String> _relayTokenOwner = {};
  final Set<String> _channelTokens = {};
  GeohashChannel? _emergency;
  final List<EmergencyMessage> emergencyMessages = [];
  final LinkedHashSet<String> _emergencyIds = LinkedHashSet();
  final StreamController<EmergencyMessage> _emergencyStream = StreamController.broadcast();
  final LinkedHashMap<String, String> _packetToMessage = LinkedHashMap();
  final Map<String, _OutgoingFile> _outgoingFiles = {};
  final Map<String, int> _chunkRequestsSent = {};
  final List<StreamSubscription> _subs = [];
  Timer? _expiryTimer;
  Timer? _outboxTimer;
  Timer? _tokenTimer;
  Timer? _chunkTimer;
  int _tokenEpoch = -1;
  int _relayEpoch = -1;

  final StreamController<ChatMessage> _incoming = StreamController.broadcast();
  final StreamController<String> _roomChanged = StreamController.broadcast();

  Stream<ChatMessage> get onIncomingMessage => _incoming.stream;
  Stream<String> get onRoomChanged => _roomChanged.stream;
  Stream<EmergencyMessage> get onEmergencyMessage => _emergencyStream.stream;
  GeohashChannel? get emergencyChannel => _emergency;

  ChatService({
    required LocalStorage storage,
    required P2PClient client,
    required TrustStore trust,
    required SessionManager sessions,
    required Outbox outbox,
    required ConnectionManager connections,
    required PairKeyCache pairKeys,
    MeshRouter? meshRouter,
  })  : _storage = storage,
        _client = client,
        _trust = trust,
        _sessions = sessions,
        _outbox = outbox,
        _connections = connections,
        _pairKeys = pairKeys,
        _mesh = meshRouter;

  String get myId => _myId;
  Outbox get outbox => _outbox;
  TrustStore get trust => _trust;
  RelayTransport? get relay => _relay;

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
    _mesh?.isForMe = (p) => _meshTokenOwner.containsKey(p.toHex) || _channelTokens.contains(p.toHex);
    _mesh?.onPacketForMe = (p) => unawaited(_onMeshPacket(p));
    _mesh?.onAckReceived = _onMeshAck;
    _trust.addListener(_onTrustChanged);
    await refreshTokens();

    _expiryTimer = Timer.periodic(const Duration(seconds: 20), (_) => _sweepExpired());
    _outboxTimer = Timer.periodic(const Duration(seconds: 30), (_) => flushAllOutbox());
    _tokenTimer = Timer.periodic(const Duration(minutes: 5), (_) => refreshTokens());
    _chunkTimer = Timer.periodic(const Duration(seconds: 45), (_) => _requestMissingChunks());
    await _sweepExpired();
    notifyListeners();
  }

  /// Attach (or detach with null) the internet relay carrier.
  void setRelay(RelayTransport? relay) {
    _relaySub?.cancel();
    _relaySub = null;
    _relay = relay;
    if (relay != null) {
      _relaySub = relay.onInbound.listen((m) => unawaited(_onRelayInbound(m)));
      relay.setTokens(_relayTokenOwner.keys.toList());
    }
  }

  void _onTrustChanged() => unawaited(refreshTokens(force: true));

  /// Rebuild the rotating mesh and relay addresses we listen on.
  Future<void> refreshTokens({bool force = false}) async {
    final epoch = PairKeys.meshEpoch();
    final day = PairKeys.nostrEpoch();
    if (!force && epoch == _tokenEpoch && day == _relayEpoch) return;
    final mesh = <String, String>{};
    final relay = <String, String>{};
    for (final pk in await _pairKeys.all()) {
      for (final e in [epoch - 1, epoch, epoch + 1]) {
        mesh[_hex(await pk.meshToken(e, _myId))] = pk.peerId;
      }
      for (final d in [day - 1, day]) {
        relay[await pk.nostrToken(d, _myId)] = pk.peerId;
      }
    }
    _meshTokenOwner
      ..clear()
      ..addAll(mesh);
    _relayTokenOwner
      ..clear()
      ..addAll(relay);
    _tokenEpoch = epoch;
    _relayEpoch = day;
    _relay?.setTokens(relay.keys.toList());
    await _refreshChannelTokens(epoch);
  }

  Future<void> _refreshChannelTokens(int epoch) async {
    _channelTokens.clear();
    final ch = _emergency;
    if (ch == null) return;
    for (final e in [epoch - 1, epoch, epoch + 1]) {
      _channelTokens.add(_hex(await ch.token(e)));
    }
  }

  // Emergency channel (location-scoped anonymous broadcast)

  Future<void> joinEmergencyChannel(String geohash) async {
    _emergency = await GeohashChannel.open(geohash);
    emergencyMessages.clear();
    _emergencyIds.clear();
    await _refreshChannelTokens(PairKeys.meshEpoch());
    notifyListeners();
  }

  void leaveEmergencyChannel() {
    _emergency = null;
    _channelTokens.clear();
    notifyListeners();
  }

  /// Broadcast to everyone in the joined cell. Returns false if no mesh
  /// neighbour or direct link can carry it right now (it is still kept
  /// locally and sprayed to neighbours that appear later).
  Future<bool> sendEmergency(String text, {String? displayName, double? lat, double? lon}) async {
    final ch = _emergency;
    final mesh = _mesh;
    if (ch == null || mesh == null || text.trim().isEmpty) return false;
    final m = EmergencyMessage(
      id: _uuid.v4(), geohash: ch.geohash, text: text.trim(), timestamp: DateTime.now().toUtc(),
      displayName: displayName, lat: lat, lon: lon,
    );
    _recordEmergency(m);
    await mesh.send(
      to: await ch.token(GeohashChannel.currentEpoch()),
      replyTo: MeshPacket.zeroToken,
      payload: await ch.seal(m),
      type: MeshPacket.typeChannel,
      ttl: 10,
    );
    return (meshLinkCountProvider?.call() ?? 0) > 0 || _client.connectedPeerIds.isNotEmpty;
  }

  void _recordEmergency(EmergencyMessage m) {
    if (!_emergencyIds.add(m.id)) return;
    if (_emergencyIds.length > 500) _emergencyIds.remove(_emergencyIds.first);
    emergencyMessages.add(m);
    if (emergencyMessages.length > 200) emergencyMessages.removeAt(0);
    _emergencyStream.add(m);
    notifyListeners();
  }

  static String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

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
        final list = (jsonDecode(store.get(key)!) as List<dynamic>).cast<String>();
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
    if (ev.isNew && ev.isInitiator) await _sendSessionOpen(ev.peerId);
    await _deliverPendingTransition(ev.peerId);
    if (ev.isNew) await _requeueUndelivered(ev.peerId);
    await _outbox.resetBackoff(ev.peerId);
    await flushOutbox(ev.peerId);
  }

  Future<void> _sendSessionOpen(String peerId) async {
    try {
      final env = await _sessions.encrypt(peerId: peerId, message: InnerMessage.sessionOpen(id: _uuid.v4()));
      await _client.sendToPeer(peerId, ProtocolMessage.envelope(env));
    } catch (e) {
      debugPrint('[Chat] session open to $peerId failed: $e');
    }
  }

  /// After a session reset, messages sent but never confirmed delivered are
  /// re-queued so nothing is silently lost.
  Future<void> _requeueUndelivered(String peerId) async {
    final room = _directRoomFor(peerId);
    if (room == null) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 6));
    final candidates = (_messages[room.id] ?? [])
        .where((m) => m.senderId == _myId && m.messageType == MessageType.text &&
            m.status == MessageStatus.sent && m.timestamp.isAfter(cutoff))
        .toList()
        .reversed
        .take(20);
    for (final m in candidates) {
      final inner = InnerMessage.text(
        id: m.id, text: m.content, replyToId: m.replyToId,
        disappearAfterSeconds: room.disappearAfterSeconds > 0 ? room.disappearAfterSeconds : null,
      );
      await _outbox.enqueue(OutboxItem.inner(peerId: peerId, message: inner, messageId: m.id));
    }
  }

  // Identity rotation

  /// Rotate all long-term keys. The signed transition is sent to every
  /// contact that is reachable now over the existing sessions and queued
  /// for the others (delivered on their next direct handshake). Returns
  /// the new handle; the caller must restart the app.
  Future<String> rotateIdentity(Future<PendingRotation> Function() prepare,
      Future<void> Function(PendingRotation) commit) async {
    final r = await prepare();
    final inner = InnerMessage(type: typeKeyTransition, id: _uuid.v4(), body: r.statement.toJson());
    final pending = <String>[];
    for (final p in _trust.all) {
      if (_client.isPeerConnected(p.nyxChatId)) {
        final path = await _deliver(p.nyxChatId, inner, queueOnFailure: false);
        if (path == DeliveryPath.direct) continue;
      }
      pending.add(p.nyxChatId);
    }
    await _storage.putSetting(_kPendingTransition, jsonEncode(r.statement.toJson()));
    await _storage.putSetting(_kTransitionRecipients, jsonEncode(pending));
    await _outbox.clear(); // queued items would carry the old handle
    await commit(r);
    return r.newId;
  }

  Future<void> _deliverPendingTransition(String peerId) async {
    final raw = _storage.getSetting(_kTransitionRecipients);
    final stmtRaw = _storage.getSetting(_kPendingTransition);
    if (raw == null || stmtRaw == null) return;
    final pending = (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
    if (!pending.contains(peerId)) return;
    final inner = InnerMessage(type: typeKeyTransition, id: _uuid.v4(),
        body: jsonDecode(stmtRaw) as Map<String, dynamic>);
    final path = await _deliver(peerId, inner, queueOnFailure: false);
    if (path == DeliveryPath.direct) {
      pending.remove(peerId);
      await _storage.putSetting(_kTransitionRecipients, jsonEncode(pending.toList()));
    }
  }

  /// A contact rotated its keys: verify the statement against what we
  /// have pinned for the old handle and merge the identities.
  Future<void> _onKeyTransition(String from, InnerMessage m) async {
    final KeyTransition t;
    try {
      t = KeyTransition.fromJson(m.body);
    } catch (e) {
      debugPrint('[Chat] bad key transition from $from: $e');
      return;
    }
    if (from != t.oldId && from != t.newId) return;
    final old = _trust.get(t.oldId);
    if (old == null || !await t.verify(pinnedOldSigningKey: old.signingKey)) {
      debugPrint('[Chat] key transition from $from failed verification');
      return;
    }
    final now = DateTime.now().toUtc();
    final merged = PinnedPeer(
      nyxChatId: t.newId, displayName: _trust.get(t.newId)?.displayName ?? old.displayName,
      identityKey: t.newIdentityKey, signingKey: t.newSigningKey, kyberPublicKey: t.newKyberKey,
      verified: old.verified, firstSeen: old.firstSeen, lastSeen: now, keyChangedAt: now,
    );
    await _trust.acceptNewKeys(merged);
    await _trust.remove(t.oldId);
    _pairKeys.invalidate(t.oldId);
    _pairKeys.invalidate(t.newId);
    if (from == t.oldId && !_sessions.hasSession(t.newId)) {
      await _sessions.rename(t.oldId, t.newId);
    } else {
      await _sessions.reset(t.oldId);
    }
    // Move the conversation and group memberships to the new handle.
    for (final room in _rooms.values.toList()) {
      if (!room.isGroup && room.peerId == t.oldId) {
        final existing = _directRoomFor(t.newId);
        if (existing != null && existing.id != room.id) {
          _messages.putIfAbsent(room.id, () => []).addAll(_messages.remove(existing.id) ?? []);
          _messages[room.id]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          await _storage.deleteChatRoom(existing.id);
          _rooms.remove(existing.id);
        }
        await _updateRoom(room.id, (r) => r.copyWith(peerId: t.newId, peerPublicKeyHex: merged.identityKeyHex));
        await _addSystemMessage(room.id, '${merged.displayName} rotated their keys (verified transition)');
      } else if (room.isGroup && room.members.any((x) => x.nyxChatId == t.oldId)) {
        await _updateRoom(room.id, (r) => r.copyWith(members: r.members.map((x) => x.nyxChatId == t.oldId
            ? GroupMember(nyxChatId: t.newId, displayName: x.displayName, publicKeyHex: merged.identityKeyHex,
                signingKeyHex: merged.signingKeyHex, kyberKeyHex: merged.kyberPublicKeyHex, isAdmin: x.isAdmin, joinedAt: x.joinedAt)
            : x).toList()));
      }
    }
    await refreshTokens(force: true);
    notifyListeners();
  }

  // Rooms

  List<ChatRoom> get chatRooms {
    final rooms = _rooms.values.toList();
    rooms.sort((a, b) => (b.lastMessageAt ?? b.createdAt).compareTo(a.lastMessageAt ?? a.createdAt));
    return rooms;
  }

  ChatRoom? room(String roomId) => _rooms[roomId];
  List<ChatMessage> getMessages(String roomId) => List.unmodifiable(_messages[roomId] ?? const []);

  ChatRoom? _directRoomFor(String peerId) {
    for (final r in _rooms.values) {
      if (!r.isGroup && r.peerId == peerId) return r;
    }
    return null;
  }

  Future<ChatRoom> getOrCreateDirectRoom({required String peerId, required String displayName}) async {
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
      id: _uuid.v4(), peerId: peerId,
      peerDisplayName: displayName.isNotEmpty ? displayName : peerId,
      peerPublicKeyHex: pinned?.identityKeyHex ?? '', createdAt: DateTime.now(),
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
          .where((m) => m.senderId != _myId && m.status != MessageStatus.read &&
              (m.messageType == MessageType.text || m.messageType == MessageType.file || m.messageType == MessageType.image))
          .toList();
      final bySender = <String, List<String>>{};
      for (final m in unread) {
        bySender.putIfAbsent(m.senderId, () => []).add(m.id);
        await _updateMessage(roomId, m.id, (x) => x.copyWith(status: MessageStatus.read));
      }
      for (final e in bySender.entries) {
        await _deliver(e.key, InnerMessage.receipt(id: _uuid.v4(), messageIds: e.value, kind: 'read',
            groupId: room.isGroup ? roomId : null), queueOnFailure: false);
      }
    }
    notifyListeners();
  }

  Future<void> setDisappearing(String roomId, int seconds) => _updateRoom(roomId, (r) => r.copyWith(disappearAfterSeconds: seconds));
  Future<void> setMuted(String roomId, bool muted) => _updateRoom(roomId, (r) => r.copyWith(muted: muted));

  Future<void> _updateRoom(String roomId, ChatRoom Function(ChatRoom) fn) async {
    final room = _rooms[roomId];
    if (room == null) return;
    final updated = fn(room);
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

  Future<ChatMessage?> sendText({required String roomId, required String text, String? replyToId}) async {
    final room = _rooms[roomId];
    if (room == null || text.trim().isEmpty) return null;
    final id = _uuid.v4();
    final ttl = room.disappearAfterSeconds;
    final msg = ChatMessage(
      id: id, senderId: _myId, receiverId: room.isGroup ? room.id : room.peerId, content: text,
      timestamp: DateTime.now(), status: MessageStatus.sending, roomId: roomId, replyToId: replyToId,
      expiresAt: ttl > 0 ? DateTime.now().add(Duration(seconds: ttl)) : null,
    );
    await _addMessage(roomId, msg);
    final inner = InnerMessage.text(id: id, text: text, replyToId: replyToId,
        disappearAfterSeconds: ttl > 0 ? ttl : null, groupId: room.isGroup ? room.id : null);
    final path = room.isGroup
        ? await _sendGroupInner(room, inner, messageId: id)
        : await _deliver(room.peerId, inner, messageId: id);
    await _applyPath(roomId, id, path);
    return _find(roomId, id);
  }

  Future<void> _applyPath(String roomId, String messageId, DeliveryPath path) async {
    final status = switch (path) {
      DeliveryPath.direct || DeliveryPath.mesh || DeliveryPath.relay => MessageStatus.sent,
      DeliveryPath.queued => MessageStatus.sending,
      DeliveryPath.failed => MessageStatus.failed,
    };
    await _updateMessage(roomId, messageId, (m) => m.copyWith(status: status));
  }

  /// Send an inner message to one peer: direct link, mesh, relay, else outbox.
  Future<DeliveryPath> _deliver(String peerId, InnerMessage inner, {String? messageId, bool queueOnFailure = true}) async {
    final path = await _tryDeliver(peerId, inner, messageId: messageId);
    if (path == DeliveryPath.failed && queueOnFailure) {
      await _outbox.enqueue(OutboxItem.inner(peerId: peerId, message: inner, messageId: messageId));
      return DeliveryPath.queued;
    }
    return path;
  }

  Future<DeliveryPath> _tryDeliver(String peerId, InnerMessage inner, {String? messageId}) async {
    final pinned = _trust.get(peerId);
    if (_client.isPeerConnected(peerId)) {
      try {
        final env = await _sessions.encrypt(peerId: peerId, message: inner, pinned: pinned);
        await _client.sendToPeer(peerId, ProtocolMessage.envelope(env));
        return DeliveryPath.direct;
      } on SessionNotReadyException {
        return DeliveryPath.failed; // waits for the peer's session-open
      } catch (e) {
        debugPrint('[Chat] direct send to $peerId failed: $e');
      }
    }
    if (pinned == null) return DeliveryPath.failed;
    if (_meshAvailable) {
      try {
        final env = await _sessions.encrypt(peerId: peerId, message: inner, pinned: pinned);
        await _sendViaMesh(peerId, env.toBytes(), messageId: messageId);
        return DeliveryPath.mesh;
      } catch (e) {
        debugPrint('[Chat] mesh send to $peerId failed: $e');
      }
    }
    if (_relay?.isConnected ?? false) {
      try {
        final env = await _sessions.encrypt(peerId: peerId, message: inner, pinned: pinned);
        if (await _sendViaRelay(peerId, env.toBytes())) return DeliveryPath.relay;
      } catch (e) {
        debugPrint('[Chat] relay send to $peerId failed: $e');
      }
    }
    return DeliveryPath.failed;
  }

  bool get _meshAvailable => _mesh != null && (meshLinkCountProvider?.call() ?? 0) > 0;
  // Sealed-sender carriers

  /// Seal [bytes] for the pair and hand them to the mesh under rotating
  /// tokens. Relays learn nothing but a random-looking address.
  Future<MeshPacket> _sendViaMesh(String peerId, List<int> bytes, {String? messageId, int type = MeshPacket.typeMessage}) async {
    final pk = await _pairKeys.forPeer(peerId);
    if (pk == null) throw StateError('no pinned keys for $peerId');
    final epoch = PairKeys.meshEpoch();
    final packet = await _mesh!.send(
      to: await pk.meshToken(epoch, peerId),
      replyTo: await pk.meshToken(epoch, _myId),
      payload: await pk.wrap(bytes),
      type: type,
    );
    if (messageId != null) {
      _packetToMessage[packet.id] = messageId;
      while (_packetToMessage.length > 2000) {
        _packetToMessage.remove(_packetToMessage.keys.first);
      }
    }
    return packet;
  }

  Future<bool> _sendViaRelay(String peerId, List<int> bytes) async {
    final relay = _relay;
    final pk = await _pairKeys.forPeer(peerId);
    if (relay == null || pk == null) return false;
    return relay.publish(
      recipientTokenHex: await pk.nostrToken(PairKeys.nostrEpoch(), peerId),
      payload: await pk.wrap(bytes),
    );
  }

  Future<void> _onMeshPacket(MeshPacket packet) async {
    if (packet.type == MeshPacket.typeChannel) {
      final ch = _emergency;
      if (ch == null || !_channelTokens.contains(packet.toHex)) return;
      final m = await ch.unseal(packet.payload);
      if (m != null) _recordEmergency(m);
      return;
    }
    final peerId = _meshTokenOwner[packet.toHex];
    if (peerId == null) return;
    final pk = await _pairKeys.forPeer(peerId);
    final plain = pk == null ? null : await pk.unwrap(packet.payload);
    if (plain == null) {
      debugPrint('[Chat] mesh packet for our token could not be unsealed');
      return;
    }
    await _mesh?.sendAck(packet);
    switch (packet.type) {
      case MeshPacket.typeMessage:
        try {
          final env = Envelope.fromBytes(plain);
          if (env.from != peerId && env.kind == EnvelopeKind.ratchet) return;
          await _handleEnvelope(env);
        } catch (e) {
          debugPrint('[Chat] bad mesh envelope from $peerId: $e');
        }
        break;
      case MeshPacket.typeChunk:
        try {
          await _handleChunk(jsonDecode(utf8.decode(plain)) as Map<String, dynamic>, peerId);
        } catch (e) {
          debugPrint('[Chat] bad mesh chunk from $peerId: $e');
        }
        break;
      default:
        break;
    }
  }

  void _onMeshAck(String packetId) {
    final mid = _packetToMessage.remove(packetId);
    if (mid == null) return;
    final roomId = _roomIdOfMessage(mid);
    if (roomId == null) return;
    unawaited(_updateMessage(roomId, mid, (m) =>
        m.status == MessageStatus.sending || m.status == MessageStatus.sent ? m.copyWith(status: MessageStatus.delivered) : m));
  }

  Future<void> _onRelayInbound(RelayInbound inbound) async {
    final peerId = _relayTokenOwner[inbound.token];
    if (peerId == null) return;
    final pk = await _pairKeys.forPeer(peerId);
    final plain = pk == null ? null : await pk.unwrap(inbound.payload);
    if (plain == null) return;
    try {
      final env = Envelope.fromBytes(plain);
      if (env.from != peerId && env.kind == EnvelopeKind.ratchet) return;
      await _handleEnvelope(env);
    } catch (e) {
      debugPrint('[Chat] bad relay envelope from $peerId: $e');
    }
  }

  Future<DeliveryPath> _sendRawEnvelope(String peerId, Envelope env) async {
    if (_client.isPeerConnected(peerId)) {
      await _client.sendToPeer(peerId, ProtocolMessage.envelope(env));
      return DeliveryPath.direct;
    }
    if (_trust.get(peerId) == null) return DeliveryPath.failed;
    if (_meshAvailable) {
      try {
        await _sendViaMesh(peerId, env.toBytes());
        return DeliveryPath.mesh;
      } catch (_) {}
    }
    if (_relay?.isConnected ?? false) {
      try {
        if (await _sendViaRelay(peerId, env.toBytes())) return DeliveryPath.relay;
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
          path = await _tryDeliver(peerId, item.innerMessage, messageId: item.messageId);
        } else if (item.kind == OutboxItem.kindEnvelope) {
          path = await _sendRawEnvelope(peerId, Envelope.fromJson(item.payload));
        } else {
          path = DeliveryPath.failed;
        }
      } catch (e) {
        debugPrint('[Chat] outbox item ${item.id} failed: $e');
        path = DeliveryPath.failed;
      }
      if (path == DeliveryPath.direct || path == DeliveryPath.mesh || path == DeliveryPath.relay) {
        await _outbox.remove(item.id);
        final mid = item.messageId;
        if (mid != null) {
          final roomId = _roomIdOfMessage(mid);
          if (roomId != null) {
            await _updateMessage(roomId, mid, (m) => m.status == MessageStatus.sending ? m.copyWith(status: MessageStatus.sent) : m);
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

  GroupMember _memberFromPinned(PinnedPeer p, {bool admin = false}) => GroupMember(
        nyxChatId: p.nyxChatId, displayName: p.displayName, publicKeyHex: p.identityKeyHex,
        signingKeyHex: p.signingKeyHex, kyberKeyHex: p.kyberPublicKeyHex, isAdmin: admin, joinedAt: DateTime.now(),
      );

  GroupMember _selfMember({bool admin = false}) {
    final k = _sessions.keys;
    return GroupMember(
      nyxChatId: _myId, displayName: _myName, publicKeyHex: k.identityPublicKeyHex,
      signingKeyHex: k.signingPublicKeyHex, kyberKeyHex: k.kyberPublicKeyHex, isAdmin: admin, joinedAt: DateTime.now(),
    );
  }

  Future<ChatRoom> createGroup({required String name, required List<PinnedPeer> members, String? description}) async {
    final groupId = _uuid.v4();
    final room = ChatRoom(
      id: groupId, peerId: groupId, peerDisplayName: name, peerPublicKeyHex: '', createdAt: DateTime.now(),
      roomType: ChatRoomType.group, members: [_selfMember(admin: true), ...members.map(_memberFromPinned)],
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
    final updated = room.copyWith(members: [...room.members, ...added.map(_memberFromPinned)]);
    _rooms[roomId] = updated;
    await _storage.saveChatRoom(updated);
    await _addSystemMessage(roomId, '${added.map((p) => p.displayName).join(', ')} added');
    await _broadcastGroupUpdate(updated, 'add');
    notifyListeners();
  }

  Future<void> removeGroupMember(String roomId, String memberId) async {
    final room = _rooms[roomId];
    if (room == null || !room.isGroup) return;
    final updated = room.copyWith(members: room.members.where((m) => m.nyxChatId != memberId).toList());
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
    final remaining = room.copyWith(members: room.members.where((m) => m.nyxChatId != _myId).toList(), left: true);
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
    await _updateRoom(roomId, (r) => r.copyWith(peerDisplayName: name));
    await _broadcastGroupUpdate(_rooms[roomId]!, 'rename');
  }
  InnerMessage _groupUpdateInner(ChatRoom room, String action) => InnerMessage.groupUpdate(
        id: _uuid.v4(), groupId: room.id, action: action, groupName: room.peerDisplayName,
        members: room.members.map((m) => m.toJson()).toList(), description: room.groupDescription,
      );

  Future<void> _broadcastGroupUpdate(ChatRoom room, String action) async {
    final inner = _groupUpdateInner(room, action);
    for (final m in room.members) {
      if (m.nyxChatId != _myId) await _deliver(m.nyxChatId, inner);
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
      await _deliver(m.nyxChatId, InnerMessage.senderKeyDistribution(id: _uuid.v4(), groupId: room.id, distribution: dist.toJson()));
      sent.add(m.nyxChatId);
    }
    await _persistSenderKeys();
  }

  Future<DeliveryPath> _sendGroupInner(ChatRoom room, InnerMessage inner, {String? messageId}) async {
    await _ensureSenderKeyDistributed(room);
    final ad = Envelope.associatedDataFor(_myId, room.id, EnvelopeKind.senderKey);
    final skm = await _senderKeys.encrypt(room.id, Padding.pad(inner.toBytes()), ad);
    await _persistSenderKeys();
    final env = Envelope.senderKey(from: _myId, groupId: room.id, iteration: skm.iteration, ciphertext: skm.ciphertext, signature: skm.signature);
    var anySent = false;
    var anyQueued = false;
    for (final m in room.members) {
      if (m.nyxChatId == _myId) continue;
      final path = await _sendRawEnvelope(m.nyxChatId, env);
      if (path == DeliveryPath.failed) {
        anyQueued = true;
        await _outbox.enqueue(OutboxItem(id: '${m.nyxChatId}_${inner.id}', peerId: m.nyxChatId,
            kind: OutboxItem.kindEnvelope, payload: env.toJson(), messageId: messageId));
      } else {
        anySent = true;
      }
    }
    if (anySent) return DeliveryPath.direct;
    return anyQueued ? DeliveryPath.queued : DeliveryPath.failed;
  }

  // Reactions

  Future<void> toggleReaction({required String roomId, required String messageId, required String emoji}) async {
    final room = _rooms[roomId];
    final msg = _find(roomId, messageId);
    if (room == null || msg == null) return;
    final mine = msg.reactions.where((r) => r.userId == _myId).toList();
    final remove = mine.isNotEmpty && mine.first.emoji == emoji;
    final updated = remove ? msg.removeReaction(_myId)
        : msg.addReaction(MessageReaction(userId: _myId, emoji: emoji, timestamp: DateTime.now()));
    await _replaceMessage(roomId, updated);
    final inner = InnerMessage.reaction(id: _uuid.v4(), targetMessageId: messageId, emoji: emoji, remove: remove,
        groupId: room.isGroup ? room.id : null);
    if (room.isGroup) {
      await _sendGroupInner(room, inner);
    } else {
      await _deliver(room.peerId, inner);
    }
  }

  // Files

  /// True if a file of [size] can currently reach [peerId] (direct link,
  /// or mesh for files up to [maxMeshFileBytes]).
  bool canSendFileTo(String peerId, int size) =>
      _client.isPeerConnected(peerId) || (_meshAvailable && _trust.get(peerId) != null && size <= maxMeshFileBytes);

  Future<ChatMessage?> sendFile({required String roomId, required String filePath}) async {
    final room = _rooms[roomId];
    if (room == null) return null;
    final file = File(filePath);
    if (!await file.exists()) return null;
    final size = await file.length();
    final targets = room.isGroup
        ? room.members.map((m) => m.nyxChatId).where((id) => id != _myId).toList()
        : [room.peerId];
    final reachable = targets.where((t) => canSendFileTo(t, size)).toList();
    if (reachable.isEmpty) {
      debugPrint('[Chat] no carrier can take this file right now');
      return null;
    }
    final fileId = _uuid.v4();
    final mime = _mimeFor(file.path);
    final d = await FileTransferManager.describe(file, fileId: fileId, mimeType: mime);
    _outgoingFiles[fileId] = _OutgoingFile(file, d);
    final msg = ChatMessage(
      id: fileId, senderId: _myId, receiverId: room.isGroup ? room.id : room.peerId, content: d.fileName,
      timestamp: DateTime.now(), status: MessageStatus.sending, roomId: roomId,
      messageType: mime.startsWith('image/') ? MessageType.image : MessageType.file,
      attachment: FileAttachment(
        fileName: d.fileName, mimeType: mime, fileSize: d.fileSize, filePath: filePath, fileId: fileId,
        fileKeyB64: base64Encode(d.key), fileNonceB64: base64Encode(d.noncePrefix), sha256Hex: d.sha256Hex,
        totalChunks: d.totalChunks, receivedChunks: d.totalChunks,
      ),
    );
    await _addMessage(roomId, msg);
    final inner = InnerMessage.file(
      id: fileId, fileId: fileId, fileName: d.fileName, mimeType: mime, fileSize: d.fileSize,
      fileKey: d.key, fileNonce: d.noncePrefix, totalChunks: d.totalChunks, chunkSize: d.chunkSize,
      sha256Hex: d.sha256Hex, groupId: room.isGroup ? room.id : null,
    );
    var sentAny = false;
    for (final peerId in reachable) {
      final path = await _deliver(peerId, inner, messageId: fileId, queueOnFailure: false);
      if (path == DeliveryPath.failed) continue;
      sentAny = true;
      unawaited(_streamChunks(file, d, peerId));
    }
    await _updateMessage(roomId, fileId, (m) => m.copyWith(status: sentAny ? MessageStatus.sent : MessageStatus.failed));
    return _find(roomId, fileId);
  }

  Future<bool> _sendChunk(String peerId, FileChunkFrame frame) async {
    if (_client.isPeerConnected(peerId)) {
      await _client.sendToPeer(peerId, ProtocolMessage.fileChunk(frame.toJson()));
      return true;
    }
    if (_meshAvailable && _trust.get(peerId) != null) {
      try {
        await _sendViaMesh(peerId, utf8.encode(jsonEncode(frame.toJson())), type: MeshPacket.typeChunk);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return true;
      } catch (e) {
        debugPrint('[Chat] mesh chunk failed: $e');
      }
    }
    return false;
  }

  Future<void> _streamChunks(File file, FileDescriptor d, String peerId) async {
    for (var i = 0; i < d.totalChunks; i++) {
      final frame = await FileTransferManager.encryptChunk(file, d, i);
      if (!await _sendChunk(peerId, frame)) return; // receiver will request the rest
      if (i % 8 == 7) await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> _handleChunk(Map<String, dynamic> json, String fromPeer) async {
    try {
      final frame = FileChunkFrame.fromJson(json);
      if (!files.isExpecting(frame.fileId)) return;
      final done = await files.accept(frame);
      final roomId = _roomIdOfMessage(frame.fileId);
      if (roomId == null) return;
      final received = files.incoming[frame.fileId]?.received.length ?? frame.total;
      await _updateMessage(roomId, frame.fileId, (m) => m.copyWith(
            attachment: m.attachment?.copyWith(receivedChunks: received),
            status: done != null ? MessageStatus.delivered : m.status,
          ));
      if (done != null) {
        _chunkRequestsSent.remove(frame.fileId);
        await _deliver(fromPeer, InnerMessage.receipt(id: _uuid.v4(), messageIds: [frame.fileId], kind: 'delivered'), queueOnFailure: false);
      }
    } catch (e) {
      debugPrint('[Chat] chunk error: $e');
    }
  }

  /// Receiver side: ask the sender for chunks that never arrived.
  Future<void> _requestMissingChunks() async {
    for (final t in files.incoming.values.toList()) {
      if (DateTime.now().difference(t.lastUpdate) < const Duration(seconds: 20)) continue;
      final sent = _chunkRequestsSent[t.descriptor.fileId] ?? 0;
      if (sent >= 30) continue;
      final missing = files.missingChunks(t.descriptor.fileId).take(24).toList();
      if (missing.isEmpty) continue;
      final roomId = _roomIdOfMessage(t.descriptor.fileId);
      final msg = roomId == null ? null : _find(roomId, t.descriptor.fileId);
      if (msg == null) continue;
      _chunkRequestsSent[t.descriptor.fileId] = sent + 1;
      await _deliver(msg.senderId,
          InnerMessage(type: typeChunkRequest, id: _uuid.v4(), body: {'fileId': t.descriptor.fileId, 'idx': missing}),
          queueOnFailure: false);
    }
  }

  /// Sender side: re-send requested chunks.
  Future<void> _onChunkRequest(String from, InnerMessage m) async {
    final fileId = m.body['fileId'];
    final idx = (m.body['idx'] as List<dynamic>?)?.whereType<int>().take(24).toList() ?? const [];
    if (fileId is! String || idx.isEmpty) return;
    var out = _outgoingFiles[fileId];
    if (out == null) {
      final roomId = _roomIdOfMessage(fileId);
      final msg = roomId == null ? null : _find(roomId, fileId);
      final a = msg?.attachment;
      if (msg == null || a == null || msg.senderId != _myId || a.filePath == null || a.fileKeyB64 == null) return;
      final file = File(a.filePath!);
      if (!await file.exists()) return;
      out = _OutgoingFile(file, FileDescriptor(
        fileId: fileId, fileName: a.fileName, mimeType: a.mimeType, fileSize: a.fileSize,
        key: base64Decode(a.fileKeyB64!), noncePrefix: base64Decode(a.fileNonceB64!),
        totalChunks: a.totalChunks, chunkSize: FileTransferManager.chunkSize, sha256Hex: a.sha256Hex ?? '',
      ));
      _outgoingFiles[fileId] = out;
    }
    for (final i in idx) {
      if (i < 0 || i >= out.descriptor.totalChunks) continue;
      final frame = await FileTransferManager.encryptChunk(out.file, out.descriptor, i);
      if (!await _sendChunk(from, frame)) return;
    }
  }
  // Inbound

  Future<void> _handleEnvelopeJson(Map<String, dynamic> json, {PeerConnection? via}) async {
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
      final ad = Envelope.associatedDataFor(env.from, env.to, EnvelopeKind.senderKey);
      final plain = await _senderKeys.decrypt(groupId: env.to, senderId: env.from,
          message: SenderKeyMessage(env.iteration!, env.ciphertext, env.signature!), associatedData: ad);
      await _persistSenderKeys();
      await _handleInner(env.from, InnerMessage.fromBytes(Padding.unpad(plain)), groupId: env.to);
    } catch (e) {
      debugPrint('[Chat] group envelope from ${env.from} failed: $e');
    }
  }

  Future<void> _handleInner(String from, InnerMessage m, {String? groupId}) async {
    if (!_recentInnerIds.add('$from:${m.id}')) return;
    if (_recentInnerIds.length > _maxRecentIds) _recentInnerIds.remove(_recentInnerIds.first);
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
      case typeChunkRequest:
        await _onChunkRequest(from, m);
        break;
      case typeKeyTransition:
        await _onKeyTransition(from, m);
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
    return getOrCreateDirectRoom(peerId: from, displayName: _trust.get(from)?.displayName ?? from);
  }

  Future<void> _onText(String from, InnerMessage m, String? gid) async {
    final room = await _roomForInbound(from, gid);
    if (room == null) return;
    if (await _storage.getMessage(m.id) != null) return;
    final ttl = m.body['ttl'];
    final msg = ChatMessage(
      id: m.id, senderId: from, receiverId: gid ?? _myId, content: m.text, timestamp: m.timestamp.toLocal(),
      status: MessageStatus.delivered, roomId: room.id, replyToId: m.body['replyTo'] as String?,
      expiresAt: ttl is int && ttl > 0 ? DateTime.now().add(Duration(seconds: ttl)) : null,
    );
    await _addMessage(room.id, msg, incoming: true);
    await _deliver(from, InnerMessage.receipt(id: _uuid.v4(), messageIds: [m.id], kind: 'delivered', groupId: gid), queueOnFailure: false);
  }

  Future<void> _onFile(String from, InnerMessage m, String? gid) async {
    final room = await _roomForInbound(from, gid);
    if (room == null) return;
    final d = FileDescriptor.fromInnerBody(m.body);
    if (await _storage.getMessage(d.fileId) != null) return;
    final dir = filesDirectoryProvider != null ? await filesDirectoryProvider!() : (await getApplicationDocumentsDirectory()).path;
    final savePath = '$dir/nyxchat_files/${d.fileId}_${d.fileName}';
    await files.begin(d, savePath);
    final msg = ChatMessage(
      id: d.fileId, senderId: from, receiverId: gid ?? _myId, content: d.fileName, timestamp: m.timestamp.toLocal(),
      status: MessageStatus.sent, roomId: room.id,
      messageType: d.mimeType.startsWith('image/') ? MessageType.image : MessageType.file,
      attachment: FileAttachment(fileName: d.fileName, mimeType: d.mimeType, fileSize: d.fileSize, filePath: savePath,
          fileId: d.fileId, sha256Hex: d.sha256Hex, totalChunks: d.totalChunks, receivedChunks: 0),
    );
    await _addMessage(room.id, msg, incoming: true);
  }

  Future<void> _onReaction(String from, InnerMessage m) async {
    final target = m.body['target'] as String?;
    final emoji = m.body['emoji'] as String?;
    if (target == null || emoji == null) return;
    final roomId = _roomIdOfMessage(target);
    final msg = roomId == null ? null : _find(roomId, target);
    if (msg == null) return;
    final updated = (m.body['remove'] == true) ? msg.removeReaction(from)
        : msg.addReaction(MessageReaction(userId: from, emoji: emoji, timestamp: DateTime.now()));
    await _replaceMessage(roomId!, updated);
  }

  Future<void> _onReceipt(String from, InnerMessage m) async {
    final ids = (m.body['ids'] as List<dynamic>?)?.whereType<String>() ?? const <String>[];
    final kind = m.body['kind'] as String?;
    for (final id in ids) {
      final roomId = _roomIdOfMessage(id);
      if (roomId == null) continue;
      await _updateMessage(roomId, id, (msg) {
        if (msg.senderId != _myId) return msg;
        if (kind == 'read') {
          return msg.copyWith(status: MessageStatus.read, readBy: {...msg.readBy, from}.toList(), deliveredTo: {...msg.deliveredTo, from}.toList());
        }
        return msg.copyWith(status: msg.status == MessageStatus.read ? msg.status : MessageStatus.delivered,
            deliveredTo: {...msg.deliveredTo, from}.toList());
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
    _packetToMessage.clear();
    _outgoingFiles.clear();
    _meshTokenOwner.clear();
    _relayTokenOwner.clear();
    await _outbox.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _outboxTimer?.cancel();
    _tokenTimer?.cancel();
    _chunkTimer?.cancel();
    _relaySub?.cancel();
    _trust.removeListener(_onTrustChanged);
    for (final s in _subs) {
      s.cancel();
    }
    _incoming.close();
    _roomChanged.close();
    _emergencyStream.close();
    super.dispose();
  }
}