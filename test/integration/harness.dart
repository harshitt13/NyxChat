// Shared harness for the end-to-end integration tests: a complete NyxChat
// stack (storage, trust, sessions, connections, mesh router, chat service)
// in one object, several of which can talk over loopback TCP or a
// simulated mesh link inside one test process.

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
