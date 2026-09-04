// End-to-end integration tests: two (or three) complete NyxChat stacks in
// one process, talking over loopback TCP and over a simulated mesh link.
//
// Exercises the wiring between ConnectionManager, SessionManager,
// ChatService, Outbox, TrustStore and MeshRouter that unit tests cannot.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/key_manager.dart';
import 'package:nyxchat/core/crypto/nyx_id.dart';
import 'package:nyxchat/core/crypto/pair_keys.dart';
import 'package:nyxchat/core/crypto/session_manager.dart';
import 'package:nyxchat/core/mesh/mesh_router.dart';
import 'package:nyxchat/core/mesh/mesh_store.dart';
import 'package:nyxchat/core/network/connection_manager.dart';
import 'package:nyxchat/core/network/p2p_client.dart';
import 'package:nyxchat/core/network/p2p_server.dart';
import 'package:nyxchat/core/storage/local_storage.dart';
import 'package:nyxchat/core/storage/outbox.dart';
import 'package:nyxchat/core/storage/trust_store.dart';
import 'package:nyxchat/models/message.dart';
import 'package:nyxchat/services/chat_service.dart';

Future<void> waitFor(bool Function() cond, {Duration timeout = const Duration(seconds: 15), String? what}) async {
  final deadline = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for ${what ?? 'condition'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

class Node {
  final String name;
  late final KeyManager keys;
  late final String id;
  final LocalStorage storage = LocalStorage();
  late final TrustStore trust;
  late final Outbox outbox;
  late final SessionManager sessions;
  final P2PClient client = P2PClient();
  final P2PServer server = P2PServer(port: 0);
  late final ConnectionManager connections;
  late final PairKeyCache pairKeys;
  final MeshStore meshStore = MeshStore();
  late final MeshRouter mesh = MeshRouter(store: meshStore);
  late final ChatService chat;
  final List<ChatMessage> received = [];

  Node(this.name);

  static Future<Node> create(String name, Directory root, {bool hiveInit = false}) async {
    final n = Node(name);
    n.keys = await KeyManager.generateEphemeral();
    n.id = await NyxId.derive(signingPublicKey: n.keys.signingPublicKey, identityPublicKey: n.keys.identityPublicKey);
    if (hiveInit) await n.storage.init(directory: root.path);
    await n.storage.openDatabases(CryptoUtils.randomBytes(32), profileSuffix: '_$name');
    n.trust = TrustStore(n.storage.trustStore);
    await n.trust.load();
    n.outbox = Outbox(n.storage.outboxStore);
    n.sessions = SessionManager(keys: n.keys, store: n.storage.sessionStore, myId: n.id);
    await n.sessions.load();
    n.connections = ConnectionManager(keys: n.keys, client: n.client, server: n.server, trust: n.trust, sessions: n.sessions);
    n.pairKeys = PairKeyCache(n.keys, n.trust);
    await n.mesh.init(n.id);
    n.chat = ChatService(
      storage: n.storage, client: n.client, trust: n.trust, sessions: n.sessions, outbox: n.outbox,
      connections: n.connections, pairKeys: n.pairKeys, meshRouter: n.mesh,
    );
    n.chat.filesDirectoryProvider = () async => '${root.path}/files_$name';
    await n.server.start();
    n.connections.configure(nyxChatId: n.id, displayName: name, listeningPort: n.server.boundPort);
    n.connections.start();
    await n.chat.init(myId: n.id, displayName: name);
    n.chat.onIncomingMessage.listen(n.received.add);
    return n;
  }

  int get port => server.boundPort;

  PinnedPeer pinned() => PinnedPeer(
        nyxChatId: id, displayName: name, identityKey: keys.identityPublicKey, signingKey: keys.signingPublicKey,
        kyberPublicKey: keys.kyberPublicKey, verified: true, firstSeen: DateTime.now(), lastSeen: DateTime.now(),
      );

  Future<void> connectTo(Node other) async {
    final conn = await connections.connect('127.0.0.1', other.port);
    expect(conn, isNotNull, reason: '$name could not connect to ${other.name}');
    await waitFor(() => sessions.hasSession(other.id) && other.sessions.hasSession(id), what: 'sessions');
    await waitFor(() => other.sessions.canSend(id), what: 'session open at ${other.name}');
  }

  ChatMessage? messageById(String roomId, String id) {
    for (final m in chat.getMessages(roomId)) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> dispose() async {
    chat.dispose();
    await client.disconnectAll();
    await server.stop();
    mesh.dispose();
    await storage.closeAll();
  }
}

void main() {
  late Directory root;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('nyx_it_');
  });

  tearDownAll(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  test('handshake, session open, message, receipt, reply', () async {
    final a = await Node.create('a1', root, hiveInit: true);
    final b = await Node.create('b1', root);
    await a.connectTo(b);
    expect(a.trust.get(b.id), isNotNull, reason: 'keys pinned on first contact');
    expect(b.trust.get(a.id), isNotNull);

    final room = await a.chat.getOrCreateDirectRoom(peerId: b.id, displayName: 'B');
    final sent = await a.chat.sendText(roomId: room.id, text: 'hello over tcp');
    expect(sent, isNotNull);
    expect(sent!.status, MessageStatus.sent);
    await waitFor(() => b.received.any((m) => m.content == 'hello over tcp'), what: 'B receives');
    await waitFor(() => a.messageById(room.id, sent.id)?.status == MessageStatus.delivered, what: 'delivery receipt');

    final bRoom = b.chat.chatRooms.firstWhere((r) => r.peerId == a.id);
    await b.chat.sendText(roomId: bRoom.id, text: 'reply');
    await waitFor(() => a.received.any((m) => m.content == 'reply'), what: 'A receives reply');

    // Read receipt
    await b.chat.markRoomAsRead(bRoom.id);
    await waitFor(() => a.messageById(room.id, sent.id)?.status == MessageStatus.read, what: 'read receipt');
    await a.dispose();
    await b.dispose();
  });

  test('reconnect keeps the session; reset recovers when a peer lost state', () async {
    final a = await Node.create('a2', root);
    final b = await Node.create('b2', root);
    await a.connectTo(b);
    final created = a.sessions.record(b.id)!.createdAt;
    final room = await a.chat.getOrCreateDirectRoom(peerId: b.id, displayName: 'B');

    await a.client.disconnectAll();
    await waitFor(() => !b.client.isPeerConnected(a.id), what: 'disconnect seen');
    await a.connectTo(b);
    expect(a.sessions.record(b.id)!.createdAt, created, reason: 'session survives reconnect');
    await a.chat.sendText(roomId: room.id, text: 'after reconnect');
    await waitFor(() => b.received.any((m) => m.content == 'after reconnect'));

    // B loses its session state (e.g. database reset) while the link is up.
    await b.sessions.clearAll();
    final m = await a.chat.sendText(roomId: room.id, text: 'after reset');
    expect(m, isNotNull);
    await waitFor(() => b.received.any((x) => x.content == 'after reset'),
        timeout: const Duration(seconds: 30), what: 'message re-delivered after session reset');
    await waitFor(() => a.messageById(room.id, m!.id)?.status == MessageStatus.delivered,
        timeout: const Duration(seconds: 30), what: 'delivered after reset');
    await a.dispose();
    await b.dispose();
  });

  test('mesh delivery with sealed sender, async session and ack', () async {
    final a = await Node.create('a3', root);
    final b = await Node.create('b3', root);
    // Not connected over TCP; they know each other's keys (contact cards).
    await a.trust.acceptNewKeys(b.pinned());
    await b.trust.acceptNewKeys(a.pinned());
    await a.chat.refreshTokens(force: true);
    await b.chat.refreshTokens(force: true);
    // One simulated BLE link between them.
    a.mesh.onForwardPacket = (p, _) => unawaited(b.mesh.handlePacket(p));
    b.mesh.onForwardPacket = (p, _) => unawaited(a.mesh.handlePacket(p));
    a.chat.meshLinkCountProvider = () => 1;
    b.chat.meshLinkCountProvider = () => 1;

    final room = await a.chat.getOrCreateDirectRoom(peerId: b.id, displayName: 'B');
    final sent = await a.chat.sendText(roomId: room.id, text: 'via mesh');
    expect(sent!.status, MessageStatus.sent);
    await waitFor(() => b.received.any((m) => m.content == 'via mesh'), what: 'mesh delivery');
    await waitFor(() => a.messageById(room.id, sent.id)?.status == MessageStatus.delivered, what: 'ack/receipt');
    final bRoom = b.chat.chatRooms.firstWhere((r) => r.peerId == a.id);
    await b.chat.sendText(roomId: bRoom.id, text: 'mesh reply');
    await waitFor(() => a.received.any((m) => m.content == 'mesh reply'), what: 'mesh reply');
    expect(a.mesh.totalAcked, greaterThan(0));
    await a.dispose();
    await b.dispose();
  });

  test('three-party group with sender keys', () async {
    final a = await Node.create('a4', root);
    final b = await Node.create('b4', root);
    final c = await Node.create('c4', root);
    await a.connectTo(b);
    await a.connectTo(c);
    await b.connectTo(c);
    final group = await a.chat.createGroup(name: 'trio', members: [a.trust.get(b.id)!, a.trust.get(c.id)!]);
    await waitFor(() => b.chat.room(group.id) != null && c.chat.room(group.id) != null, what: 'group created at B and C');
    await a.chat.sendText(roomId: group.id, text: 'hello group');
    await waitFor(() => b.received.any((m) => m.content == 'hello group'), what: 'B gets group message');
    await waitFor(() => c.received.any((m) => m.content == 'hello group'), what: 'C gets group message');
    await b.chat.sendText(roomId: group.id, text: 'from b');
    await waitFor(() => a.received.any((m) => m.content == 'from b') && c.received.any((m) => m.content == 'from b'), what: 'B message fans out');
    await a.chat.removeGroupMember(group.id, c.id);
    await waitFor(() => c.chat.room(group.id)?.left == true, what: 'C sees removal');
    await a.chat.sendText(roomId: group.id, text: 'after removal');
    await waitFor(() => b.received.any((m) => m.content == 'after removal'), what: 'B still receives');
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(c.received.any((m) => m.content == 'after removal'), isFalse, reason: 'removed member excluded');
    await a.dispose();
    await b.dispose();
    await c.dispose();
  });
}