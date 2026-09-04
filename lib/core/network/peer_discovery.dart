import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../crypto/crypto_utils.dart';
import '../crypto/pair_keys.dart';
import 'discovery_beacon.dart';

/// Peer found on the local network.
class DiscoveredPeer {
  final String nyxChatId;
  final String displayName;
  final String ipAddress;
  final int port;

  /// True when the id came from matching a private beacon (may be a
  /// Bloom false positive; the handshake decides).
  final bool isCandidate;

  DiscoveredPeer({
    required this.nyxChatId,
    required this.displayName,
    required this.ipAddress,
    required this.port,
    this.isCandidate = false,
  });
}

/// mDNS/DNS-SD discovery on the local network with private beacons.
///
/// The service name is random per launch. The TXT record carries either a
/// public beacon (id + name) or a private one (Bloom filter of per-contact
/// tokens for the current 15-minute slot); see [DiscoveryBeacon].
class PeerDiscovery {
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  Timer? _rotateTimer;
  int _broadcastSlot = -1;

  final String nyxChatId;
  final int listeningPort;

  /// Produces the beacon to advertise for the current slot.
  final Future<DiscoveryBeacon> Function() beaconProvider;

  /// Display name shown only in public beacons.
  final String Function() displayNameProvider;

  /// Resolves a private beacon to candidate contact ids.
  final Future<List<String>> Function(Uint8List bloom, int slot)? resolvePrivate;

  final StreamController<DiscoveredPeer> _found = StreamController.broadcast();
  final StreamController<String> _lost = StreamController.broadcast();
  final Map<String, DiscoveredPeer> _peers = {};
  final Map<String, List<String>> _serviceToIds = {};
  bool _broadcasting = false;
  bool _discovering = false;

  Stream<DiscoveredPeer> get onPeerFound => _found.stream;
  Stream<String> get onPeerLost => _lost.stream;
  Map<String, DiscoveredPeer> get discoveredPeers => Map.unmodifiable(_peers);
  bool get isBroadcasting => _broadcasting;
  bool get isDiscovering => _discovering;

  PeerDiscovery({
    required this.nyxChatId,
    required this.listeningPort,
    required this.beaconProvider,
    required this.displayNameProvider,
    this.resolvePrivate,
  });

  Future<void> startBroadcasting() async {
    if (_broadcasting) return;
    await _publish();
    _broadcasting = true;
    _rotateTimer?.cancel();
    _rotateTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (_broadcasting && PairKeys.discoverySlot() != _broadcastSlot) {
        await _publish();
      }
    });
  }

  /// Re-publish the beacon now (visibility changed, contact added, slot
  /// rotated).
  Future<void> refreshBeacon() async {
    if (_broadcasting) await _publish();
  }

  Future<void> _publish() async {
    final beacon = await beaconProvider();
    _broadcastSlot = beacon.slot;
    final txt = beacon.toTxt(displayName: displayNameProvider());
    try {
      await _broadcast?.stop();
    } catch (_) {}
    final service = BonsoirService(
      name: 'nyx-${CryptoUtils.toHex(CryptoUtils.randomBytes(4))}',
      type: AppConstants.serviceType,
      port: listeningPort,
      attributes: txt,
    );
    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.ready;
    await _broadcast!.start();
    debugPrint('[mDNS] broadcasting ${beacon.isPublic ? 'public' : 'private'} beacon (slot ${beacon.slot})');
  }

  Future<void> startDiscovery() async {
    if (_discovering) return;
    _discovery = BonsoirDiscovery(type: AppConstants.serviceType);
    await _discovery!.ready;
    _discovery!.eventStream!.listen((event) {
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound ||
          event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
        final s = event.service;
        if (s is ResolvedBonsoirService) unawaited(_onResolved(s));
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
        _onLost(event.service);
      }
    });
    await _discovery!.start();
    _discovering = true;
  }

  Future<void> _onResolved(ResolvedBonsoirService service) async {
    final beacon = DiscoveryBeacon.fromTxt(service.attributes);
    if (beacon == null) return;
    final host = service.host ?? '';
    if (host.isEmpty) return;
    final ids = <String>[];
    var candidate = false;
    if (beacon.isPublic) {
      if (beacon.nyxId == nyxChatId) return;
      ids.add(beacon.nyxId!);
    } else {
      final matches = await resolvePrivate?.call(beacon.bloom!, beacon.slot) ?? const [];
      ids.addAll(matches);
      candidate = true;
    }
    _serviceToIds[service.name] = ids;
    for (final id in ids) {
      final peer = DiscoveredPeer(
        nyxChatId: id,
        displayName: beacon.isPublic ? (service.attributes['name'] ?? id) : id,
        ipAddress: host,
        port: service.port,
        isCandidate: candidate,
      );
      _peers[id] = peer;
      _found.add(peer);
    }
  }

  void _onLost(BonsoirService? service) {
    if (service == null) return;
    final ids = _serviceToIds.remove(service.name) ?? const [];
    for (final id in ids) {
      _peers.remove(id);
      _lost.add(id);
    }
  }

  Future<void> stop() async {
    _rotateTimer?.cancel();
    if (_broadcasting) {
      try {
        await _broadcast?.stop();
      } catch (_) {}
      _broadcasting = false;
    }
    if (_discovering) {
      try {
        await _discovery?.stop();
      } catch (_) {}
      _discovering = false;
    }
    _peers.clear();
    _serviceToIds.clear();
  }
}