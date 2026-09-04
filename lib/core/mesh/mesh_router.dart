import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../crypto/crypto_utils.dart';
import 'mesh_packet.dart';
import 'mesh_store.dart';

class RoutingEntry {
  final String nextHopHash;
  final int hopCount;
  final DateTime lastUpdated;
  RoutingEntry({required this.nextHopHash, required this.hopCount})
      : lastUpdated = DateTime.now();
  bool get isStale => DateTime.now().difference(lastUpdated).inMinutes > 30;
}

/// Delay-tolerant mesh router.
///
/// * Distance-vector route learning from the `routePath` of every packet
///   (and periodic route-discovery beacons).
/// * Unicast to the learned next hop when a route is known, otherwise
///   restricted flooding (Spray-and-Wait with L = [sprayCount]).
/// * Store-and-forward: undelivered packets are kept in [MeshStore] and
///   offered to every newly connected neighbour.
/// * Anti-timing jitter before each forward.
class MeshRouter extends ChangeNotifier {
  final MeshStore _store;
  final Map<String, RoutingEntry> _routingTable = {};
  final int defaultTtl;
  final int sprayCount;
  final Random _random = Random.secure();
  Timer? _refreshTimer;

  String? _myHash;
  String? _myNyxId;

  /// Packet addressed to us (payload is an end-to-end encrypted envelope).
  void Function(MeshPacket packet)? onPacketForMe;

  /// Packet to hand to the transport. [nextHopHash] is null for
  /// spray/broadcast, otherwise the neighbour that should receive it.
  void Function(MeshPacket packet, String? nextHopHash)? onForwardPacket;

  int _totalReceived = 0;
  int _totalForwarded = 0;
  int _totalDelivered = 0;
  int _totalDuplicates = 0;

  MeshRouter({
    required MeshStore store,
    this.defaultTtl = 7,
    this.sprayCount = 3,
  }) : _store = store;

  String? get myNyxId => _myNyxId;
  String? get myHash => _myHash;
  int get totalReceived => _totalReceived;
  int get totalForwarded => _totalForwarded;
  int get totalDelivered => _totalDelivered;
  int get totalDuplicates => _totalDuplicates;
  int get storedPackets => _store.packetCount;
  int get knownRoutes => _routingTable.length;
  Map<String, RoutingEntry> get routingTable => Map.unmodifiable(_routingTable);

  Future<void> init(String myNyxId) async {
    _myNyxId = myNyxId;
    _myHash = await hashId(myNyxId);
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
        const Duration(minutes: 5), (_) => _cleanAndBeacon());
  }

  Future<void> _cleanAndBeacon() async {
    _routingTable.removeWhere((_, e) => e.isStale);
    if (_myHash == null) return;
    final beacon = await createPacket(
      recipientId: 'BROADCAST',
      payload: Uint8List(0),
      type: MeshPacket.typeRouteDiscovery,
      ttl: 3,
    );
    _store.markSeen(beacon.id);
    onForwardPacket?.call(beacon.forward(_myHash!), null);
  }

  Future<MeshPacket> createPacket({
    required String recipientId,
    required Uint8List payload,
    String type = MeshPacket.typeMessage,
    int? ttl,
  }) async {
    return MeshPacket(
      id: _generatePacketId(),
      recipientHash: await hashId(recipientId),
      senderHash: _myHash ?? '',
      ttl: ttl ?? defaultTtl,
      maxTtl: ttl ?? defaultTtl,
      payload: payload,
      timestamp: DateTime.now().toUtc(),
      type: type,
    );
  }

  /// Originate a packet: store it and forward immediately.
  Future<MeshPacket> send({
    required String recipientId,
    required Uint8List payload,
  }) async {
    if (payload.length > MeshPacket.maxPayloadBytes) {
      throw ArgumentError('payload exceeds mesh packet limit');
    }
    final packet = await createPacket(recipientId: recipientId, payload: payload);
    _store.store(packet);
    _forward(packet, immediate: true);
    notifyListeners();
    return packet;
  }

  /// Handle a packet received from a neighbour.
  Future<void> handlePacket(MeshPacket packet) async {
    _totalReceived++;
    if (_store.hasSeen(packet.id)) {
      _totalDuplicates++;
      return;
    }
    _store.markSeen(packet.id);

    if (packet.senderHash.isNotEmpty && packet.routePath.isNotEmpty &&
        packet.senderHash != _myHash) {
      final previousHop = packet.routePath.last;
      final hops = packet.hops;
      final known = _routingTable[packet.senderHash];
      if (known == null || hops < known.hopCount || known.isStale) {
        _routingTable[packet.senderHash] =
            RoutingEntry(nextHopHash: previousHop, hopCount: hops);
      }
    }

    if (packet.recipientHash == _myHash) {
      _totalDelivered++;
      _store.markDelivered(packet.id);
      if (!packet.isBroadcast) onPacketForMe?.call(packet);
      notifyListeners();
      return;
    }

    if (packet.canForward && !packet.isExpired) {
      if (!packet.isBroadcast) _store.store(packet);
      _forward(packet);
    }
    notifyListeners();
  }

  void _forward(MeshPacket packet, {bool immediate = false}) {
    final delay = immediate
        ? Duration.zero
        : Duration(milliseconds: 200 + _random.nextInt(1800));
    Timer(delay, () {
      final forwarded = packet.forward(_myHash ?? '');
      _totalForwarded++;
      final route = _routingTable[packet.recipientHash];
      final nextHop = (route != null && !route.isStale) ? route.nextHopHash : null;
      onForwardPacket?.call(forwarded, nextHop);
    });
  }

  /// Packets to offer to a neighbour that just connected (spray phase).
  List<MeshPacket> getPacketsForNewPeer() {
    if (_myHash == null) return [];
    final forwardable = _store.getForwardable(_myHash!);
    if (forwardable.length > sprayCount) {
      forwardable.shuffle(_random);
      return forwardable.sublist(0, sprayCount);
    }
    return forwardable;
  }

  /// Anonymous address for an id: base64(SHA-256(id)).
  static Future<String> hashId(String id) async =>
      base64Encode(await CryptoUtils.sha256(utf8.encode(id)));

  String _generatePacketId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rnd = CryptoUtils.toHex(CryptoUtils.randomBytes(6));
    return '$ts-$rnd';
  }

  void clearAll() {
    _store.clear();
    _routingTable.clear();
    _totalReceived = 0;
    _totalForwarded = 0;
    _totalDelivered = 0;
    _totalDuplicates = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}