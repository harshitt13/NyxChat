import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../crypto/crypto_utils.dart';
import 'mesh_packet.dart';
import 'mesh_store.dart';

class RoutingEntry {
  final Uint8List nextHopRelayId;
  final int hopCount;
  final DateTime lastUpdated;
  RoutingEntry({required this.nextHopRelayId, required this.hopCount})
      : lastUpdated = DateTime.now();
  bool get isStale => DateTime.now().difference(lastUpdated).inMinutes > 30;
  String get nextHopHex => CryptoUtils.toHex(nextHopRelayId);
}

/// Delay-tolerant mesh router (protocol v4).
///
/// * Addresses are rotating pair tokens; the application decides whether a
///   token is ours through [isForMe].
/// * Routes are learned from the reply token of packets we relay ("token T
///   is reachable through the neighbour that handed us this packet") and
///   expire with the epoch.
/// * Unicast to the learned next hop when known, otherwise Spray-and-Wait.
/// * Acknowledgements: the destination answers with an ack packet
///   addressed to the reply token; every relay that sees the ack purges
///   the original from its store.
/// * Our relay id is random per launch, so relays cannot be tracked over
///   time either.
class MeshRouter extends ChangeNotifier {
  final MeshStore _store;
  final Map<String, RoutingEntry> _routes = {};
  final int defaultTtl;
  final int sprayCount;
  final Random _random = Random.secure();
  Timer? _refreshTimer;

  String? _myNyxId;
  Uint8List _relayId = CryptoUtils.randomBytes(MeshPacket.relayIdBytes);

  /// Is this packet addressed to us? (token lookup, set by the application)
  bool Function(MeshPacket packet)? isForMe;

  /// Packet addressed to us (message, chunk or channel).
  void Function(MeshPacket packet)? onPacketForMe;

  /// Ack for a packet we originated.
  void Function(String packetId)? onAckReceived;

  /// Hand a packet to the transports. [nextHopRelayId] is null for spray.
  void Function(MeshPacket packet, Uint8List? nextHopRelayId)? onForwardPacket;
  bool _disposed = false;

  int _totalReceived = 0;
  int _totalForwarded = 0;
  int _totalDelivered = 0;
  int _totalDuplicates = 0;
  int _totalAcked = 0;

  MeshRouter({required MeshStore store, this.defaultTtl = 7, this.sprayCount = 3})
      : _store = store;

  String? get myNyxId => _myNyxId;
  Uint8List get relayId => _relayId;
  String get relayIdHex => CryptoUtils.toHex(_relayId);
  int get totalReceived => _totalReceived;
  int get totalForwarded => _totalForwarded;
  int get totalDelivered => _totalDelivered;
  int get totalDuplicates => _totalDuplicates;
  int get totalAcked => _totalAcked;
  int get storedPackets => _store.packetCount;
  int get knownRoutes => _routes.length;
  Map<String, RoutingEntry> get routingTable => Map.unmodifiable(_routes);

  Future<void> init(String myNyxId) async {
    _myNyxId = myNyxId;
    _relayId = CryptoUtils.randomBytes(MeshPacket.relayIdBytes);
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _cleanAndBeacon());
  }

  void _cleanAndBeacon() {
    _routes.removeWhere((_, e) => e.isStale);
    final beacon = MeshPacket.create(
      type: MeshPacket.typeBeacon,
      to: MeshPacket.zeroToken,
      replyTo: MeshPacket.zeroToken,
      payload: Uint8List(0),
      ttl: 2,
    );
    _store.markSeen(beacon.id);
    onForwardPacket?.call(beacon.forward(_relayId), null);
  }

  /// Originate a packet.
  Future<MeshPacket> send({
    required Uint8List to,
    required Uint8List replyTo,
    required Uint8List payload,
    int type = MeshPacket.typeMessage,
    int? ttl,
  }) async {
    if (payload.length > MeshPacket.maxPayloadBytes) {
      throw ArgumentError('payload exceeds mesh packet limit');
    }
    final packet = MeshPacket.create(
        type: type, to: to, replyTo: replyTo, payload: payload, ttl: ttl ?? defaultTtl);
    _store.store(packet);
    _forward(packet, immediate: true);
    notifyListeners();
    return packet;
  }

  /// Acknowledge a packet that was delivered to us.
  Future<void> sendAck(MeshPacket delivered) async {
    if (!delivered.hasReplyTo) return;
    final ack = MeshPacket.create(
      type: MeshPacket.typeAck,
      to: delivered.replyTo,
      replyTo: MeshPacket.zeroToken,
      payload: delivered.idBytes,
      ttl: defaultTtl,
    );
    _store.markSeen(ack.id);
    _forward(ack, immediate: true);
  }

  Future<void> handlePacket(MeshPacket packet) async {
    if (_disposed) return; // late delivery from a link or a forward timer
    _totalReceived++;
    if (_store.hasSeen(packet.id)) {
      _totalDuplicates++;
      return;
    }
    _store.markSeen(packet.id);

    // Route learning: whoever handed us this packet can reach its origin.
    final prev = packet.previousHop;
    if (packet.hasReplyTo && prev != null) {
      final key = packet.replyToHex;
      final known = _routes[key];
      if (known == null || packet.hops < known.hopCount || known.isStale) {
        _routes[key] = RoutingEntry(nextHopRelayId: prev, hopCount: packet.hops);
      }
    }

    if (packet.type == MeshPacket.typeAck) {
      final originalId = CryptoUtils.toHex(packet.payload.take(16).toList());
      _store.markDelivered(originalId); // purge from our relay store
      if (isForMe?.call(packet) ?? false) {
        _totalAcked++;
        onAckReceived?.call(originalId);
        notifyListeners();
        return;
      }
    } else if (packet.type == MeshPacket.typeChannel) {
      // Channel packets are delivered to every member and still relayed.
      if (isForMe?.call(packet) ?? false) {
        _totalDelivered++;
        onPacketForMe?.call(packet);
      }
    } else if (!packet.isBroadcast && (isForMe?.call(packet) ?? false)) {
      _totalDelivered++;
      _store.markDelivered(packet.id);
      onPacketForMe?.call(packet);
      notifyListeners();
      return;
    }

    if (packet.canForward && !packet.isExpired) {
      // Only content is kept for store-and-forward; acks and beacons are
      // forwarded once and forgotten.
      if (!packet.isBroadcast && packet.type != MeshPacket.typeAck) {
        _store.store(packet);
      }
      _forward(packet);
    }
    notifyListeners();
  }

  void _forward(MeshPacket packet, {bool immediate = false}) {
    final delay = immediate ? Duration.zero : Duration(milliseconds: 200 + _random.nextInt(1800));
    Timer(delay, () {
      if (_disposed) return;
      final forwarded = packet.forward(_relayId);
      _totalForwarded++;
      final route = _routes[packet.toHex];
      final nextHop = (route != null && !route.isStale) ? route.nextHopRelayId : null;
      onForwardPacket?.call(forwarded, nextHop);
    });
  }

  /// Stored packets to offer to a neighbour that just connected.
  List<MeshPacket> getPacketsForNewPeer() {
    final forwardable = _store.getForwardable(_relayId);
    if (forwardable.length > sprayCount) {
      forwardable.shuffle(_random);
      return forwardable.sublist(0, sprayCount);
    }
    return forwardable;
  }

  void clearAll() {
    _store.clear();
    _routes.clear();
    _totalReceived = 0;
    _totalForwarded = 0;
    _totalDelivered = 0;
    _totalDuplicates = 0;
    _totalAcked = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }
}