// PeerService wiring for the Wi-Fi Aware transport on the real service graph
// (booted the way the screens smoke test boots it) with the native channel
// faked: the transport starts with our beacon and port, a matched neighbour
// gets a path request, a path event leads to the authenticated handshake
// over the reported address, the peer is tagged 'aware', and the setting and
// stealth mode stop the transport.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/key_manager.dart';
import 'package:nyxchat/core/crypto/nyx_id.dart';
import 'package:nyxchat/core/crypto/session_manager.dart';
import 'package:nyxchat/core/network/connection_manager.dart';
import 'package:nyxchat/core/network/discovery_beacon.dart';
import 'package:nyxchat/core/network/p2p_client.dart';
import 'package:nyxchat/core/network/p2p_server.dart';
import 'package:nyxchat/core/storage/local_storage.dart';
import 'package:nyxchat/core/storage/trust_store.dart';
import 'package:nyxchat/main.dart';
import 'package:nyxchat/models/peer.dart';

const _stubbedChannels = [
  'nyxchat/window',
  'nyxchat/ble_peripheral',
  'nyxchat/location',
  'dexterous.com/flutter/local_notifications',
  'flutter_blue_plus/methods',
  'nearby_connections',
  'fr.skyost.bonsoir',
  'flutter.baseflow.com/permissions/methods',
  'plugins.flutter.io/path_provider',
  'id.flutter/background_service',
];
const _method = MethodChannel('nyxchat/wifi_aware');
const _events = EventChannel('nyxchat/wifi_aware/events');

/// The other phone: a second NyxChat stack listening on loopback.
class OtherNode {
  late KeyManager keys;
  late String id;
  final LocalStorage storage = LocalStorage();
  late final TrustStore trust;
  late final SessionManager sessions;
  final P2PClient client = P2PClient();
  final P2PServer server = P2PServer(port: 0);
  late final ConnectionManager connections;

  static Future<OtherNode> create({required String biggerThan}) async {
    final n = OtherNode();
    // The smaller handle dials: make sure the service under test is it.
    do {
      n.keys = await KeyManager.generateEphemeral();
      n.id = await NyxId.derive(signingPublicKey: n.keys.signingPublicKey, identityPublicKey: n.keys.identityPublicKey);
    } while (n.id.compareTo(biggerThan) <= 0);
    await n.storage.openDatabases(CryptoUtils.randomBytes(32), profileSuffix: '_other');
    n.trust = TrustStore(n.storage.trustStore);
    await n.trust.load();
    n.sessions = SessionManager(keys: n.keys, store: n.storage.sessionStore, myId: n.id);
    await n.sessions.load();
    n.connections = ConnectionManager(keys: n.keys, client: n.client, server: n.server, trust: n.trust, sessions: n.sessions);
    await n.server.start();
    n.connections.configure(nyxChatId: n.id, displayName: 'Other', listeningPort: n.server.boundPort);
    n.connections.start();
    return n;
  }

  Future<void> close() async {
    await connections.stop();
    await client.disconnectAll();
    await server.stop();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  MockStreamHandlerEventSink? sink;
  late Directory tmp;
  late OtherNode other;

  Future<void> emit(Map<String, Object?> event) async {
    expect(sink, isNotNull, reason: 'PeerService is not listening for Aware events');
    sink!.success(event);
    await pumpEventQueue();
  }

  Future<void> waitFor(bool Function() cond, String what, {Duration timeout = const Duration(seconds: 20)}) async {
    final deadline = DateTime.now().add(timeout);
    while (!cond()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in _stubbedChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (call.method == 'initialize') return true;
        return null;
      });
    }
    messenger.setMockMethodCallHandler(_method, (call) async {
      calls.add(call);
      return const {'isSupported', 'start', 'updateBeacon', 'openPath', 'closePath', 'stop'}.contains(call.method);
    });
    messenger.setMockStreamHandler(
      _events,
      MockStreamHandler.inline(onListen: (_, s) => sink = s, onCancel: (_) => sink = null),
    );

    tmp = Directory.systemTemp.createTempSync('nyx_aware');
    services = AppServices(port: 0);
    await services.storage.init(directory: tmp.path);
    await services.appLock.init();
    await services.identity.init();
    if (!services.identity.hasIdentity) {
      await services.identity.generateIdentity('Tester');
    }
    await services.bringUp();
    expect(services.ready, isTrue);
    other = await OtherNode.create(biggerThan: services.identity.nyxChatId);
  });

  tearDownAll(() async {
    try {
      await services.peers.stopNetwork();
    } catch (_) {}
    try {
      await other.close();
    } catch (_) {}
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('starts with our beacon, dials a matched path and tags the peer', () async {
    final peers = services.peers;
    await peers.startNetwork(nyxChatId: services.identity.nyxChatId, displayName: services.identity.displayName);
    await waitFor(() => peers.isAwareActive, 'Aware to start');
    final start = calls.singleWhere((c) => c.method == 'start');
    expect(start.arguments['port'], services.server.boundPort);
    final beacon = DiscoveryBeacon.decodeBle(start.arguments['beacon'] as List<int>);
    expect(beacon, isNotNull);
    expect(beacon!.isPublic, isTrue, reason: 'visible to everyone is the default');
    expect(beacon.nyxId, services.identity.nyxChatId);
    await emit({'type': 'state', 'available': true, 'attached': true});
    expect(peers.awareManager.statusText, startsWith('Active'));

    // Our subscriber hears the other phone's publisher: it is a larger
    // handle, so we ask for the link.
    await emit({'type': 'discovered', 'peer': 1, 'beacon': DiscoveryBeacon.public(other.id).encodeBle(), 'role': 'subscriber'});
    expect(calls.where((c) => c.method == 'openPath').single.arguments['peer'], 1);
    expect(peers.awareManager.nearbyCount, 1);

    // The data path comes up. The "link-local" address is loopback here;
    // the dual-stack server accepts it like a real fe80:: peer.
    await emit({'type': 'path', 'peer': 1, 'address': '::1', 'port': other.server.boundPort, 'iface': 'lo', 'ifaceIndex': 1});
    await waitFor(() => peers.isPeerConnected(other.id), 'handshake over the Aware path');
    await waitFor(() => peers.peers[other.id]?.status == PeerStatus.connected, 'peer record');
    final peer = peers.peers[other.id]!;
    expect(peer.transport, 'aware');
    expect(peer.ipAddress, '::1');
    expect(peer.port, other.server.boundPort);
    expect(peers.awarePathCount, 1);
    expect(peers.awareManager.statusText, contains('1 path'));
    expect(other.sessions.hasSession(services.identity.nyxChatId), isTrue);
  });

  test('the setting and stealth mode stop the transport', () async {
    final peers = services.peers;
    expect(peers.isAwareActive, isTrue);
    await services.settings.setWifiAware(false);
    await peers.applyAwareSetting();
    expect(peers.isAwareActive, isFalse);
    expect(calls.last.method, 'stop');
    expect(peers.awarePathCount, 0);
    await peers.applyAwareSetting();
    expect(peers.isAwareActive, isFalse, reason: 'still switched off');

    await services.settings.setWifiAware(true);
    await peers.applyAwareSetting();
    expect(peers.isAwareActive, isTrue);
    expect(calls.last.method, 'start');

    await peers.setStealth(true);
    expect(peers.isAwareActive, isFalse);
    await peers.setStealth(false);
    await waitFor(() => peers.isAwareActive, 'Aware to restart after stealth');
  });
}