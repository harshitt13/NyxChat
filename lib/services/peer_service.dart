import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:convert/convert.dart';
import '../core/constants.dart';
import '../core/crypto/hybrid_key_exchange.dart';
import '../core/network/message_protocol.dart';
import '../core/network/p2p_client.dart';
import '../core/network/p2p_server.dart';
import '../core/network/peer_discovery.dart';
import '../core/network/dht_node.dart';
import '../core/network/ble_manager.dart';
import '../core/mesh/mesh_router.dart';
import '../core/mesh/mesh_store.dart';
import '../core/mesh/mesh_packet.dart';
import '../core/storage/local_storage.dart';
import '../core/network/wifi_direct_manager.dart';
import '../models/peer.dart';
import 'background_service.dart';

/// Manages peer discovery, connections, and network state.
/// Now includes DHT for global P2P discovery beyond local network.
class PeerService extends ChangeNotifier {
  final LocalStorage _storage;
  final P2PClient _client;
  final P2PServer _server;
  final BleManager _bleManager;
  final FlutterSecureStorage _secureStore = const FlutterSecureStorage();
  static const String _kDHTActive = 'dht_was_active';
  final MeshStore _meshStore = MeshStore();
  late final MeshRouter _meshRouter;
  final WifiDirectManager _wifiDirectManager = WifiDirectManager();

  PeerDiscovery? _discovery;
  DHTNode? _dhtNode;
  final Map<String, Peer> _peers = {};
  bool _isNetworkActive = false;
  bool _isDHTActive = false;
  bool _isBleActive = false;

  PeerService({
    required LocalStorage storage,
    required P2PClient client,
    required P2PServer server,
    required BleManager bleManager,
  })  : _storage = storage,
        _client = client,
        _server = server,
        _bleManager = bleManager {
    _meshRouter = MeshRouter(store: _meshStore);
  }

  Map<String, Peer> get peers => Map.unmodifiable(_peers);
  List<Peer> get peerList => _peers.values.toList();
  bool get isNetworkActive => _isNetworkActive;
  bool get isDHTActive => _isDHTActive;
  bool get isBleActive => _isBleActive;
  bool get isBleSupported => _bleManager.isSupported;
  BleManager get bleManager => _bleManager;
  MeshRouter get meshRouter => _meshRouter;
  MeshStore get meshStore => _meshStore;
  P2PClient get client => _client;
  P2PServer get server => _server;
  DHTNode? get dhtNode => _dhtNode;
  WifiDirectManager get wifiDirectManager => _wifiDirectManager;
  int get nearbyBleCount => _bleManager.nearbyCount;

  /// Get list of connected peers (for group chat member selection)
  List<Peer> get connectedPeers =>
      _peers.values.where((p) => isPeerConnected(p.nyxChatId)).toList();

  // ─── Network Start/Stop ───────────────────────────────────────

  Future<void> startNetwork({
    required String nyxChatId,
    required String displayName,
    required String publicKeyHex,
    required String signingPublicKeyHex,
    String kyberPublicKeyHex = '',
  }) async {
    // Guard: don't start twice
    if (_isNetworkActive) return;
    // Load saved peers
    final savedPeers = await _storage.getPeers();
    for (final peer in savedPeers) {
      _peers[peer.nyxChatId] = peer;
    }

    // Start P2P server
    await _server.start();

    _server.onNewConnection.listen((connection) {
      _handleIncomingConnection(connection, nyxChatId, displayName,
          publicKeyHex, signingPublicKeyHex, kyberPublicKeyHex);
    });

    // Start mDNS peer discovery (local)
    _discovery = PeerDiscovery(
      nyxChatId: nyxChatId,
      displayName: displayName,
      listeningPort: AppConstants.defaultPort,
    );

    await _discovery!.startBroadcasting();
    await _discovery!.startDiscovery();

    _discovery!.onPeerFound.listen((discovered) {
      _handlePeerDiscovered(discovered, nyxChatId, displayName,
          publicKeyHex, signingPublicKeyHex, kyberPublicKeyHex);
    });

    _discovery!.onPeerLost.listen((peerId) {
      _handlePeerLost(peerId);
    });

    _isNetworkActive = true;
    notifyListeners();
    debugPrint('[Network] Local network started');

    // Start High-Bandwidth Wi-Fi Direct Fallback
    await _wifiDirectManager.init(nyxChatId);
    await _wifiDirectManager.startAdvertising();
    await _wifiDirectManager.startDiscovery();
    debugPrint('[Network] Wi-Fi Direct MANET fallback initialized');

    // Start BLE mesh (non-blocking, best-effort)
    _startBle(nyxChatId);
  }

  // ─── BLE Mesh ────────────────────────────────────────────────

  Future<void> _startBle(String nyxChatId) async {
    try {
      await _bleManager.init();
      if (!_bleManager.isSupported) {
        debugPrint('[BLE] Not supported, skipping');
        return;
      }

      // Init mesh router
      await _meshRouter.init(nyxChatId);

      // Forward mesh packets via BLE broadcast
      _meshRouter.onForwardPacket = (packet) {
        _bleManager.broadcast({
          'type': 'mesh_packet',
          'packet': packet.toJson(),
        });
      };

      // Handle incoming BLE messages for mesh routing
      _bleManager.onMessageReceived = (blePeer, message) {
        if (message['type'] == 'mesh_packet' && message['packet'] != null) {
          final packet = MeshPacket.fromJson(
              message['packet'] as Map<String, dynamic>);
          _meshRouter.handlePacket(packet);
        }
      };

      // Register BLE peer events
      _bleManager.onPeerConnected = (blePeer) {
        if (blePeer.nyxId != null) {
          final peer = Peer(
            nyxChatId: blePeer.nyxId!,
            displayName: blePeer.deviceName,
            publicKeyHex: '',
            ipAddress: 'ble://${blePeer.deviceId}',
            port: 0,
            status: PeerStatus.connected,
            lastSeen: DateTime.now(),
            transport: 'ble',
          );
          _peers[peer.nyxChatId] = peer;
          _storage.savePeer(peer);
          notifyListeners();

          // Exchange stored mesh packets with new peer
          final packets = _meshRouter.getPacketsForNewPeer();
          for (final packet in packets) {
            _bleManager.sendMessage(blePeer, {
              'type': 'mesh_packet',
              'packet': packet.toJson(),
            });
          }
        }
      };

      _bleManager.onPeerDisconnected = (blePeer) {
        if (blePeer.nyxId != null && _peers.containsKey(blePeer.nyxId)) {
          _peers[blePeer.nyxId!] = _peers[blePeer.nyxId!]!
              .copyWith(status: PeerStatus.disconnected);
          notifyListeners();
        }
      };

      await _bleManager.start(nyxChatId);
      _isBleActive = true;
      notifyListeners();
      debugPrint('[BLE] Mesh started');
    } catch (e) {
      debugPrint('[BLE] Start error: $e');
    }
  }

  Future<void> stopBle() async {
    await _bleManager.stop();
    _isBleActive = false;
    notifyListeners();
  }

  // ─── DHT Global Network ──────────────────────────────────────

  /// Check if DHT was active in the previous session.
  /// Stored in secure storage (not Hive) so it survives DB resets.
  Future<bool> wasDHTActive() async {
    return (await _secureStore.read(key: _kDHTActive)) == 'true';
  }

  /// Start the DHT node for global P2P discovery
  Future<void> startDHT({
    required String nyxChatId,
    required String publicKeyHex,
    required String displayName,
    List<String>? bootstrapNodes,
  }) async {
    // Guard: don't start twice
    if (_isDHTActive) return;

    try {
      _dhtNode = DHTNode(
        nodeId: nyxChatId,
        port: AppConstants.defaultPort,
        publicKeyHex: publicKeyHex,
        displayName: displayName,
        bootstrapNodes: bootstrapNodes,
      );

      await _dhtNode!.start();
      _isDHTActive = true;

      // Listen for DHT peer updates
      _dhtNode!.addListener(() {
        _updateDHTPeers();
      });

      // Announce ourselves
      await _dhtNode!.announce();
      
      // Persist state in secure storage (survives DB resets)
      await _secureStore.write(key: _kDHTActive, value: 'true');

      // Start the OS-level foreground service so the DHT stays alive
      // even when the user swipes the app away
      await BackgroundManager.startService();

      notifyListeners();
      debugPrint('[DHT] Global network started (foreground service active)');
    } catch (e) {
      debugPrint('[DHT] Failed to start: $e');
    }
  }

  /// Stop the DHT node
  Future<void> stopDHT() async {
    await _dhtNode?.stop();
    _dhtNode = null;
    _isDHTActive = false;
    await _secureStore.write(key: _kDHTActive, value: 'false');

    // Stop the foreground service since DHT is no longer needed
    await BackgroundManager.stopService();

    notifyListeners();
  }

  /// Look up a peer globally via DHT
  Future<Peer?> lookupGlobalPeer(String targetId) async {
    if (_dhtNode == null) return null;

    final entry = await _dhtNode!.lookup(targetId);
    if (entry != null) {
      final peer = Peer(
        nyxChatId: entry.nodeId,
        displayName: entry.displayName,
        publicKeyHex: entry.publicKeyHex,
        ipAddress: entry.address,
        port: entry.port,
        status: PeerStatus.discovered,
        lastSeen: entry.lastSeen,
        firstSeen: entry.lastSeen,
      );
      _peers[peer.nyxChatId] = peer;
      notifyListeners();
      return peer;
    }
    return null;
  }

  /// Add a DHT bootstrap node
  void addBootstrapNode(String address) {
    _dhtNode?.addBootstrapNode(address);
  }

  void _updateDHTPeers() {
    if (_dhtNode == null) return;
    for (final entry in _dhtNode!.knownPeers) {
      if (!_peers.containsKey(entry.nodeId)) {
        _peers[entry.nodeId] = Peer(
          nyxChatId: entry.nodeId,
          displayName: entry.displayName,
          publicKeyHex: entry.publicKeyHex,
          ipAddress: entry.address,
          port: entry.port,
          status: PeerStatus.discovered,
          lastSeen: entry.lastSeen,
          firstSeen: entry.lastSeen,
        );
      }
    }
    notifyListeners();
  }

  // ─── Connection Handling ──────────────────────────────────────

  void _handleIncomingConnection(
    PeerConnection connection,
    String myNyxChatId,
    String myDisplayName,
    String myPublicKeyHex,
    String mySigningPublicKeyHex,
    String myKyberPublicKeyHex,
  ) {
    late StreamSubscription sub;
    sub = connection.onMessage.listen((msg) async {
      if (msg.type == ProtocolMessageType.hello) {
        // Extract peer's Kyber PK from their hello (if PQC-capable)
        final peerKyberPKHex =
            msg.payload['kyberPublicKeyHex'] as String?;

        // Responder performs KEM encapsulation against initiator's Kyber PK
        String? kyberCiphertextHex;
        if (peerKyberPKHex != null && peerKyberPKHex.isNotEmpty) {
          try {
            final hybridKex = HybridKeyExchange();
            final peerKyberPK =
                Uint8List.fromList(hex.decode(peerKyberPKHex));
            final result = await hybridKex.encapsulate(peerKyberPK);
            kyberCiphertextHex = hex.encode(result.ciphertext);
            // Store the shared secret on the connection for later use
            connection.kyberSharedSecretHex =
                hex.encode(result.sharedSecret);
          } catch (e) {
            debugPrint('[PQC] Kyber encapsulation failed: $e');
          }
        }

        connection.send(ProtocolMessage.hello(
          senderId: myNyxChatId,
          displayName: myDisplayName,
          publicKeyHex: myPublicKeyHex,
          signingPublicKeyHex: mySigningPublicKeyHex,
          listeningPort: AppConstants.defaultPort,
          kyberPublicKeyHex: myKyberPublicKeyHex,
          kyberCiphertextHex: kyberCiphertextHex,
        ));

        _client.registerIncomingConnection(connection);

        final peer = Peer(
          nyxChatId: msg.senderId,
          displayName:
              msg.payload['displayName'] as String? ?? 'Unknown',
          publicKeyHex:
              msg.payload['publicKeyHex'] as String? ?? '',
          kyberPublicKeyHex: peerKyberPKHex ?? '',
          ipAddress: connection.remoteAddress,
          port: msg.payload['listeningPort'] as int? ??
              AppConstants.defaultPort,
          status: PeerStatus.connected,
          lastSeen: DateTime.now(),
          firstSeen: DateTime.now(),
        );

        _peers[peer.nyxChatId] = peer;
        _storage.savePeer(peer);
        notifyListeners();

        sub.cancel();
      }
    });
  }

  Future<void> _handlePeerDiscovered(
    DiscoveredPeer discovered,
    String myNyxChatId,
    String myDisplayName,
    String myPublicKeyHex,
    String mySigningPublicKeyHex,
    String myKyberPublicKeyHex,
  ) async {
    if (_client.isPeerConnected(discovered.nyxChatId)) return;

    try {
      final hello = ProtocolMessage.hello(
        senderId: myNyxChatId,
        displayName: myDisplayName,
        publicKeyHex: myPublicKeyHex,
        signingPublicKeyHex: mySigningPublicKeyHex,
        listeningPort: AppConstants.defaultPort,
        kyberPublicKeyHex: myKyberPublicKeyHex,
      );

      final connection = await _client.connectToPeer(
        address: discovered.ipAddress,
        port: discovered.port,
        helloMessage: hello,
      );

      final peer = Peer(
        nyxChatId: discovered.nyxChatId,
        displayName:
            connection.peerDisplayName ?? discovered.displayName,
        publicKeyHex: connection.peerPublicKeyHex ?? '',
        kyberPublicKeyHex: connection.peerKyberPublicKeyHex ?? '',
        ipAddress: discovered.ipAddress,
        port: discovered.port,
        status: PeerStatus.connected,
        lastSeen: DateTime.now(),
        firstSeen: DateTime.now(),
      );

      _peers[peer.nyxChatId] = peer;
      await _storage.savePeer(peer);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to connect to discovered peer: $e');

      final peer = Peer(
        nyxChatId: discovered.nyxChatId,
        displayName: discovered.displayName,
        publicKeyHex: '',
        ipAddress: discovered.ipAddress,
        port: discovered.port,
        status: PeerStatus.discovered,
        lastSeen: DateTime.now(),
      );
      _peers[peer.nyxChatId] = peer;
      notifyListeners();
    }
  }

  void _handlePeerLost(String peerId) {
    final peer = _peers[peerId];
    if (peer != null) {
      _peers[peerId] = peer.copyWith(status: PeerStatus.disconnected);
      notifyListeners();
    }
  }

  /// Connect to a specific peer manually
  Future<bool> connectToPeer({
    required String address,
    required int port,
    required String myNyxChatId,
    required String myDisplayName,
    required String myPublicKeyHex,
    required String mySigningPublicKeyHex,
    String myKyberPublicKeyHex = '',
  }) async {
    try {
      final hello = ProtocolMessage.hello(
        senderId: myNyxChatId,
        displayName: myDisplayName,
        publicKeyHex: myPublicKeyHex,
        signingPublicKeyHex: mySigningPublicKeyHex,
        listeningPort: AppConstants.defaultPort,
        kyberPublicKeyHex: myKyberPublicKeyHex,
      );

      await _client.connectToPeer(
        address: address,
        port: port,
        helloMessage: hello,
      );
      return true;
    } catch (e) {
      debugPrint('Manual connection failed: $e');
      return false;
    }
  }

  /// Connect to a DHT-discovered peer
  Future<bool> connectToDHTPeer({
    required String peerId,
    required String myNyxChatId,
    required String myDisplayName,
    required String myPublicKeyHex,
    required String mySigningPublicKeyHex,
    String myKyberPublicKeyHex = '',
  }) async {
    final peer = _peers[peerId];
    if (peer == null) return false;

    return connectToPeer(
      address: peer.ipAddress,
      port: peer.port,
      myNyxChatId: myNyxChatId,
      myDisplayName: myDisplayName,
      myPublicKeyHex: myPublicKeyHex,
      mySigningPublicKeyHex: mySigningPublicKeyHex,
      myKyberPublicKeyHex: myKyberPublicKeyHex,
    );
  }

  bool isPeerConnected(String peerId) => _client.isPeerConnected(peerId);

  PeerConnection? getConnection(String peerId) =>
      _client.getConnection(peerId);

  Future<void> stopNetwork() async {
    await _discovery?.stop();
    await stopDHT();
    await stopBle();
    await _wifiDirectManager.stop();
    await _client.disconnectAll();
    await _server.stop();
    _isNetworkActive = false;

    for (final entry in _peers.entries) {
      _peers[entry.key] =
          entry.value.copyWith(status: PeerStatus.disconnected);
    }

    notifyListeners();
    debugPrint('[Network] All networks stopped');
  }
}
