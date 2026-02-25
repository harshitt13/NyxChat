import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';

/// Discovers peers on the local network using mDNS/DNS-SD.
class PeerDiscovery {
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  final String nyxChatId;
  final String displayName;
  final int listeningPort;

  final StreamController<DiscoveredPeer> _peerFoundController =
      StreamController<DiscoveredPeer>.broadcast();
  final StreamController<String> _peerLostController =
      StreamController<String>.broadcast();
  final Map<String, DiscoveredPeer> _discoveredPeers = {};

  Stream<DiscoveredPeer> get onPeerFound => _peerFoundController.stream;
  Stream<String> get onPeerLost => _peerLostController.stream;
  Map<String, DiscoveredPeer> get discoveredPeers =>
      Map.unmodifiable(_discoveredPeers);

  bool _isBroadcasting = false;
  bool _isDiscovering = false;

  PeerDiscovery({
    required this.nyxChatId,
    required this.displayName,
    required this.listeningPort,
  });

  /// Start broadcasting our service on the network
  Future<void> startBroadcasting() async {
    if (_isBroadcasting) return;

    final service = BonsoirService(
      name: '$displayName-$nyxChatId',
      type: AppConstants.serviceType,
      port: listeningPort,
      attributes: {
        'nyxChatId': nyxChatId,
        'displayName': displayName,
        'version': AppConstants.protocolVersion,
      },
    );

    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.ready;
    await _broadcast!.start();
    _isBroadcasting = true;
    debugPrint('Broadcasting NyxChat service: ${service.name}');
  }

  /// Start discovering peers on the network
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    _discovery = BonsoirDiscovery(type: AppConstants.serviceType);
    await _discovery!.ready;

    _discovery!.eventStream!.listen((event) {
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
        _handleServiceFound(event);
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
        _handleServiceResolved(event);
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
        _handleServiceLost(event);
      }
    });

    await _discovery!.start();
    _isDiscovering = true;
    debugPrint('Started peer discovery');
  }

  void _handleServiceFound(BonsoirDiscoveryEvent event) {
    debugPrint('Service found: ${event.service?.name}');
    // Service needs to be resolved to get IP and port
    if (event.service != null) {
      (event.service as ResolvedBonsoirService?)?.let((resolved) {
        // Already resolved
        _processResolvedService(resolved);
      });
    }
  }

  void _handleServiceResolved(BonsoirDiscoveryEvent event) {
    final resolved = event.service as ResolvedBonsoirService?;
    if (resolved != null) {
      _processResolvedService(resolved);
    }
  }

  void _processResolvedService(ResolvedBonsoirService service) {
    final peerNyxChatId = service.attributes['nyxChatId'];
    final peerName = service.attributes['displayName'] ?? 'Unknown';

    // Don't discover ourselves
    if (peerNyxChatId == null || peerNyxChatId == nyxChatId) return;

    final peer = DiscoveredPeer(
      nyxChatId: peerNyxChatId,
      displayName: peerName,
      ipAddress: service.host ?? '',
      port: service.port,
    );

    _discoveredPeers[peerNyxChatId] = peer;
    _peerFoundController.add(peer);
    debugPrint(
      'Peer discovered: $peerName ($peerNyxChatId) at ${peer.ipAddress}:${peer.port}',
    );
  }

  void _handleServiceLost(BonsoirDiscoveryEvent event) {
    final lostService = event.service;
    if (lostService != null) {
      final peerId = lostService.attributes['nyxChatId'];
      if (peerId != null) {
        _discoveredPeers.remove(peerId);
        _peerLostController.add(peerId);
        debugPrint('Peer lost: $peerId');
      }
    }
  }

  /// Stop broadcasting and discovery
  Future<void> stop() async {
    if (_isBroadcasting) {
      await _broadcast?.stop();
      _isBroadcasting = false;
    }
    if (_isDiscovering) {
      await _discovery?.stop();
      _isDiscovering = false;
    }
    _discoveredPeers.clear();
    debugPrint('Peer discovery stopped');
  }

  bool get isBroadcasting => _isBroadcasting;
  bool get isDiscovering => _isDiscovering;
}

/// Represents a discovered peer on the network
class DiscoveredPeer {
  final String nyxChatId;
  final String displayName;
  final String ipAddress;
  final int port;

  DiscoveredPeer({
    required this.nyxChatId,
    required this.displayName,
    required this.ipAddress,
    required this.port,
  });
}

/// Extension for null-safe let
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
