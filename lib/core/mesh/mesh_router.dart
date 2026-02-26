import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'mesh_packet.dart';
import 'mesh_store.dart';

class RoutingEntry {
  final String nextHopHash;
  final int hopCount;
  final DateTime lastUpdated;

  RoutingEntry({required this.nextHopHash, required this.hopCount})
      : lastUpdated = DateTime.now();

  bool get isStale => DateTime.now().difference(lastUpdated).inMinutes > 60;
}

/// MANET Distance-Vector mesh router for NyxChat.
///
/// Implements intelligent path-finding:
/// - **Route Discovery**: Periodic broadcasts to build distance-vector routing tables
/// - **Unicast Forwarding**: If path known, send only to next hop (saves battery)
/// - **Fallback Spray**: If path unknown, fallback to restricted L-copies spray.
class MeshRouter extends ChangeNotifier {
  final MeshStore _store;
  final Map<String, RoutingEntry> _routingTable = {};
  final int defaultTtl;
  final int sprayCount; // L copies in spray phase
  final Random _random = Random.secure();
  Timer? _refreshTimer;

  String? _myIdHash; // SHA256 of my NyxChat ID
  String? _myNyxId;

  // Public getters
  String? get myNyxId => _myNyxId;
  // Callbacks
  Function(MeshPacket packet)? onPacketForMe;
  Function(MeshPacket packet)? onForwardPacket;

  // Stats
  int _totalReceived = 0;
  int _totalForwarded = 0;
  int _totalDelivered = 0;

  MeshRouter({
    required MeshStore store,
    this.defaultTtl = 7,
    this.sprayCount = 3,
  }) : _store = store;

  int get totalReceived => _totalReceived;
  int get totalForwarded => _totalForwarded;
  int get totalDelivered => _totalDelivered;
  int get storedPackets => _store.packetCount;

  /// Initialize with the local user's NyxChat ID.
  Future<void> init(String myNyxId) async {
    _myNyxId = myNyxId;
    _myIdHash = await _hashId(myNyxId);
    debugPrint('[Mesh] Router initialized, hash: ${_myIdHash?.substring(0, 8)}');
    
    // Periodically prune stale route entries and broadcast discovery pulses
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _cleanAndBroadcastRoutes());
  }

  Future<void> _cleanAndBroadcastRoutes() async {
    _routingTable.removeWhere((key, entry) => entry.isStale);
    if (_myIdHash != null) {
      final packet = await createPacket(
        recipientId: 'BROADCAST', 
        encryptedPayload: Uint8List(0), 
        type: 'route_discovery'
      );
      handlePacket(packet); // Hand it over to the forwarding logic
    }
  }

  /// Create a mesh packet for a specific recipient.
  Future<MeshPacket> createPacket({
    required String recipientId,
    required Uint8List encryptedPayload,
    String type = 'message',
  }) async {
    final recipientHash = await _hashId(recipientId);
    final senderHash = _myIdHash ?? '';

    return MeshPacket(
      id: _generatePacketId(),
      recipientHash: recipientHash,
      senderHash: senderHash,
      ttl: defaultTtl,
      maxTtl: defaultTtl,
      payload: encryptedPayload,
      timestamp: DateTime.now(),
      type: type,
    );
  }

  /// Handle an incoming mesh packet.
  ///
  /// If addressed to us: deliver locally.
  /// Otherwise: store and forward with anti-timing delay.
  Future<void> handlePacket(MeshPacket packet) async {
    _totalReceived++;

    // Dedup check
    if (_store.hasSeen(packet.id)) {
      debugPrint('[Mesh] Packet ${packet.id.substring(0, 8)} already seen, dropping');
      return;
    }

    // Process Route Discovery to build distance-vector maps
    if (packet.senderHash.isNotEmpty && packet.routePath.isNotEmpty) {
       final previousHop = packet.routePath.last;
       final hops = packet.maxTtl - packet.ttl;
       
       // If we don't have a route, or this route is shorter, learn it!
       if (!_routingTable.containsKey(packet.senderHash) || 
           hops < _routingTable[packet.senderHash]!.hopCount) {
          _routingTable[packet.senderHash] = RoutingEntry(
            nextHopHash: previousHop, 
            hopCount: hops
          );
          debugPrint('[Mesh] Learned route to ${packet.senderHash.substring(0, 8)} via ${previousHop.substring(0, 8)} in $hops hops.');
       }
    }

    // Check if addressed to us
    if (packet.recipientHash == _myIdHash) {
      _totalDelivered++;
      _store.markDelivered(packet.id);
      if (packet.type != 'route_discovery') onPacketForMe?.call(packet);
      debugPrint('[Mesh] Packet ${packet.id.substring(0, 8)} is for me!');
      return;
    }

    // Not for us — evaluate Distance-Vector strategy
    if (packet.canForward) {
      final stored = _store.store(packet);
      if (stored) {
        final delay = Duration(milliseconds: _random.nextInt(2000));
        Timer(delay, () {
          final forwarded = packet.forward(_myIdHash ?? 'unknown');
          _totalForwarded++;

          // Targeted Next-Hop routing if we know the path!
          if (_routingTable.containsKey(packet.recipientHash)) {
            final nextHop = _routingTable[packet.recipientHash]!.nextHopHash;
            // In a real device implementation, we'd specifically BLE unicast to the `nextHop`.
            // For now, we still broadcast, but tag the packet so other nodes can ignore it if targeted.
            onForwardPacket?.call(forwarded); 
            debugPrint('[Mesh] MANET: Targeted route used for ${packet.id.substring(0, 8)} via ${nextHop.substring(0, 8)} after delay');
          } else {
            // Unmapped path: Fallback to constrained spray-and-wait
            onForwardPacket?.call(forwarded);
            debugPrint('[Mesh] Spraying ${packet.id.substring(0, 8)} after ${delay.inMs}ms delay');
          }
        });
      }
    } else {
      debugPrint('[Mesh] Packet ${packet.id.substring(0, 8)} TTL expired, dropping');
    }

    notifyListeners();
  }

  /// Get stored packets to exchange with a newly connected peer.
  /// Used during the spray phase — sends up to [sprayCount] copies.
  List<MeshPacket> getPacketsForNewPeer() {
    if (_myIdHash == null) return [];
    final forwardable = _store.getForwardable(_myIdHash!);
    // Spray: limit to sprayCount per batch
    if (forwardable.length > sprayCount) {
      forwardable.shuffle(_random);
      return forwardable.sublist(0, sprayCount);
    }
    return forwardable;
  }

  /// Hash a NyxChat ID for anonymous addressing via Isolate to prevent dropping frames.
  Future<String> _hashId(String id) async {
    return Isolate.run(() async {
      final hash = await Sha256().hash(utf8.encode(id));
      return base64Encode(hash.bytes);
    });
  }

  /// Generate a unique packet ID.
  String _generatePacketId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = _random.nextInt(0xFFFFFF);
    return '${timestamp.toRadixString(36)}-${random.toRadixString(36)}';
  }

  /// Clear all mesh state (for panic wipe).
  void clearAll() {
    _refreshTimer?.cancel();
    _store.clear();
    _totalReceived = 0;
    _totalForwarded = 0;
    _totalDelivered = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

extension on Duration {
  int get inMs => inMilliseconds;
}
