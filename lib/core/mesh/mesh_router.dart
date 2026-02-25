import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'mesh_packet.dart';
import 'mesh_store.dart';

/// Spray-and-Wait mesh router for NyxChat.
///
/// Implements delay-tolerant networking:
/// - **Spray phase**: Send L copies to L distinct peers
/// - **Wait phase**: Those peers deliver only when recipient is adjacent
///
/// Features:
/// - Anonymous addressing (hash-based, no plaintext IDs)
/// - Anti-timing: random delay before forwarding (0-2s)
/// - Deduplication via packet ID tracking
/// - TTL-based hop limiting (default: 7 hops)
/// - Store-and-forward for offline peers
class MeshRouter extends ChangeNotifier {
  final MeshStore _store;
  final int defaultTtl;
  final int sprayCount; // L copies in spray phase
  final Random _random = Random.secure();

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

    // Check if addressed to us
    if (packet.recipientHash == _myIdHash) {
      _totalDelivered++;
      _store.markDelivered(packet.id);
      onPacketForMe?.call(packet);
      debugPrint('[Mesh] Packet ${packet.id.substring(0, 8)} is for me!');
      return;
    }

    // Not for us — store and schedule forwarding
    if (packet.canForward) {
      final stored = _store.store(packet);
      if (stored) {
        // Anti-timing: random delay before forwarding (0-2 seconds)
        final delay = Duration(milliseconds: _random.nextInt(2000));
        Timer(delay, () {
          final forwarded = packet.forward();
          _totalForwarded++;
          onForwardPacket?.call(forwarded);
          debugPrint('[Mesh] Forwarding ${packet.id.substring(0, 8)} after ${delay.inMs}ms delay');
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
    final forwardable = _store.getForwardable();
    // Spray: limit to sprayCount per batch
    if (forwardable.length > sprayCount) {
      forwardable.shuffle(_random);
      return forwardable.sublist(0, sprayCount);
    }
    return forwardable;
  }

  /// Hash a NyxChat ID for anonymous addressing.
  Future<String> _hashId(String id) async {
    final hash = await Sha256().hash(utf8.encode(id));
    return base64Encode(hash.bytes);
  }

  /// Generate a unique packet ID.
  String _generatePacketId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = _random.nextInt(0xFFFFFF);
    return '${timestamp.toRadixString(36)}-${random.toRadixString(36)}';
  }

  /// Clear all mesh state (for panic wipe).
  void clearAll() {
    _store.clear();
    _totalReceived = 0;
    _totalForwarded = 0;
    _totalDelivered = 0;
    notifyListeners();
  }
}

extension on Duration {
  int get inMs => inMilliseconds;
}
