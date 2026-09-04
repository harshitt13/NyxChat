import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../crypto/crypto_utils.dart';
import '../crypto/key_manager.dart';
import '../crypto/nyx_id.dart';
import 'message_protocol.dart';

/// Peer record learned through the DHT.
class DHTEntry {
  final String nodeId;
  final String address;
  final int port;
  final int dhtPort;
  final String identityKeyHex;
  final String signingKeyHex;
  final String kyberKeyHex;
  final String displayName;
  final DateTime lastSeen;

  DHTEntry({
    required this.nodeId,
    required this.address,
    required this.port,
    required this.dhtPort,
    required this.identityKeyHex,
    required this.signingKeyHex,
    required this.kyberKeyHex,
    required this.displayName,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'address': address,
        'port': port,
        'dhtPort': dhtPort,
        'ik': identityKeyHex,
        'sk': signingKeyHex,
        'kpk': kyberKeyHex,
        'displayName': displayName,
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory DHTEntry.fromJson(Map<String, dynamic> j) => DHTEntry(
        nodeId: j['nodeId'] as String,
        address: j['address'] as String,
        port: j['port'] as int,
        dhtPort: j['dhtPort'] as int? ?? (j['port'] as int) + 1,
        identityKeyHex: j['ik'] as String? ?? j['publicKeyHex'] as String? ?? '',
        signingKeyHex: j['sk'] as String? ?? '',
        kyberKeyHex: j['kpk'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
        lastSeen: j['lastSeen'] != null
            ? DateTime.parse(j['lastSeen'] as String)
            : DateTime.now(),
      );
}

/// Simplified Kademlia-style directory for finding peers outside the local
/// network.
///
/// Announcements are signed with the announcer's Ed25519 key and the node
/// id must be bound to the presented keys, so entries cannot be spoofed.
/// Lookup responses are hints only: the real trust decision is the signed
/// handshake with the peer itself.
///
/// Status: experimental. Without a reachable bootstrap node and NAT
/// traversal this only works on networks where peers are directly
/// routable.
class DHTNode extends ChangeNotifier {
  final String nodeId;
  final int port;
  final KeyManager keys;
  final String displayName;

  ServerSocket? _server;
  final Map<String, DHTEntry> _table = {};
  final List<String> _bootstrap;
  final Map<String, Completer<DHTEntry?>> _pending = {};
  Timer? _refresh;
  bool _running = false;

  static const int kBucketSize = 20;
  static const Duration entryTtl = Duration(hours: 1);
  static const Duration announceFreshness = Duration(minutes: 10);
  static const int maxFrameBytes = 64 * 1024;

  DHTNode({
    required this.nodeId,
    required this.port,
    required this.keys,
    required this.displayName,
    List<String>? bootstrapNodes,
  }) : _bootstrap = bootstrapNodes ?? [];

  bool get isRunning => _running;
  int get knownPeersCount => _table.length;
  List<DHTEntry> get knownPeers => _table.values.toList();
  List<String> get bootstrapNodes => List.unmodifiable(_bootstrap);

  Future<void> start() async {
    if (_running) return;
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port + 1);
    _running = true;
    _server!.listen(_handleConnection);
    debugPrint('[DHT] listening on ${port + 1}');
    await announce();
    _refresh?.cancel();
    _refresh = Timer.periodic(const Duration(minutes: 5), (_) {
      _table.removeWhere((_, e) => DateTime.now().difference(e.lastSeen) > entryTtl);
      announce();
    });
    notifyListeners();
  }

  Future<void> stop() async {
    _running = false;
    _refresh?.cancel();
    await _server?.close();
    _server = null;
    notifyListeners();
  }

  void addBootstrapNode(String address) {
    if (!_bootstrap.contains(address)) _bootstrap.add(address);
  }

  Future<ProtocolMessage> _signedAnnounce() async {
    final iat = DateTime.now().toUtc().millisecondsSinceEpoch;
    final sig = await keys.sign(_announceTranscript(
      nodeId: nodeId,
      identityKey: keys.identityPublicKey,
      signingKey: keys.signingPublicKey,
      kyberKey: keys.kyberPublicKey,
      displayName: displayName,
      port: port,
      iat: iat,
    ));
    return ProtocolMessage.dhtAnnounce(
      senderId: nodeId,
      identityKeyHex: keys.identityPublicKeyHex,
      signingKeyHex: keys.signingPublicKeyHex,
      kyberKeyHex: keys.kyberPublicKeyHex,
      displayName: displayName,
      port: port,
      issuedAtMs: iat,
      signatureHex: CryptoUtils.toHex(sig),
    );
  }

  static List<int> _announceTranscript({
    required String nodeId,
    required List<int> identityKey,
    required List<int> signingKey,
    required List<int> kyberKey,
    required String displayName,
    required int port,
    required int iat,
  }) =>
      CryptoUtils.lengthPrefixed([
        'NyxChat-DHT-Announce-v3'.codeUnits,
        utf8.encode(nodeId),
        identityKey,
        signingKey,
        kyberKey,
        utf8.encode(displayName),
        CryptoUtils.int32be(port),
        CryptoUtils.int64be(iat),
      ]);

  Future<void> announce() async {
    if (!_running) return;
    final msg = await _signedAnnounce();
    for (final e in _table.values.toList()) {
      await _send(e.address, e.dhtPort, msg);
    }
    for (final b in _bootstrap) {
      final parts = b.split(':');
      if (parts.length == 2) {
        final p = int.tryParse(parts[1]);
        if (p != null) await _send(parts[0], p, msg);
      }
    }
  }

  Future<DHTEntry?> lookup(String targetId) async {
    if (_table.containsKey(targetId)) return _table[targetId];
    final completer = Completer<DHTEntry?>();
    _pending[targetId] = completer;
    final msg = ProtocolMessage.dhtLookup(senderId: nodeId, targetId: targetId);
    for (final peer in _closest(targetId, kBucketSize)) {
      await _send(peer.address, peer.dhtPort, msg);
    }
    try {
      return await completer.future.timeout(const Duration(seconds: 10),
          onTimeout: () {
        _pending.remove(targetId);
        return null;
      });
    } catch (_) {
      return null;
    }
  }

  void _handleConnection(Socket socket) {
    final remote = socket.remoteAddress.address;
    final buffer = BytesBuilder(copy: false);
    socket.listen((data) {
      buffer.add(data);
      if (buffer.length > maxFrameBytes) {
        socket.destroy();
        return;
      }
      final bytes = buffer.takeBytes();
      var start = 0;
      for (var i = 0; i < bytes.length; i++) {
        if (bytes[i] == 0x0A) {
          if (i > start) {
            _handleLine(utf8.decode(bytes.sublist(start, i)), remote, socket);
          }
          start = i + 1;
        }
      }
      if (start < bytes.length) buffer.add(bytes.sublist(start));
    }, onDone: socket.destroy, onError: (_) => socket.destroy());
  }

  Future<void> _handleLine(String line, String remote, Socket socket) async {
    try {
      final msg = ProtocolMessage.decode(line);
      switch (msg.type) {
        case ProtocolMessageType.dhtAnnounce:
          await _handleAnnounce(msg, remote);
          break;
        case ProtocolMessageType.dhtLookup:
          _handleLookup(msg, socket);
          break;
        case ProtocolMessageType.dhtResponse:
          await _handleResponse(msg);
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('[DHT] bad message from $remote: $e');
    }
  }

  /// Validate an announcement: key lengths, id binding, freshness and
  /// signature. Returns the entry or null.
  static Future<DHTEntry?> validateAnnounce(
      Map<String, dynamic> p, String address) async {
    final id = p['senderId'];
    final port = p['port'];
    final iat = p['iat'];
    final name = p['displayName'];
    if (id is! String || !NyxId.isValidFormat(id)) return null;
    if (port is! int || port < 1 || port > 65535) return null;
    if (iat is! int) return null;
    if (name is! String || name.length > 64) return null;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if ((now - iat).abs() > announceFreshness.inMilliseconds) return null;
    final ik = CryptoUtils.decodeKey(p['ik'] as String, 32, 'ik');
    final sk = CryptoUtils.decodeKey(p['sk'] as String, 32, 'sk');
    final kpk = CryptoUtils.decodeKey(
        p['kpk'] as String, CryptoUtils.kyber768PublicKeyLength, 'kpk');
    final sig = CryptoUtils.decodeKey(p['sig'] as String, 64, 'sig');
    if (!await NyxId.verify(id: id, signingPublicKey: sk, identityPublicKey: ik)) {
      return null;
    }
    final ok = await CryptoUtils.ed25519Verify(
      publicKey: sk,
      message: _announceTranscript(
        nodeId: id,
        identityKey: ik,
        signingKey: sk,
        kyberKey: kpk,
        displayName: name,
        port: port,
        iat: iat,
      ),
      signature: sig,
    );
    if (!ok) return null;
    return DHTEntry(
      nodeId: id,
      address: address,
      port: port,
      dhtPort: port + 1,
      identityKeyHex: CryptoUtils.toHex(ik),
      signingKeyHex: CryptoUtils.toHex(sk),
      kyberKeyHex: CryptoUtils.toHex(kpk),
      displayName: name,
      lastSeen: DateTime.now(),
    );
  }

  Future<void> _handleAnnounce(ProtocolMessage msg, String remote) async {
    final entry = await validateAnnounce(msg.payload, remote);
    if (entry == null) {
      debugPrint('[DHT] rejected announce from $remote');
      return;
    }
    storePeer(entry);
  }

  void storePeer(DHTEntry entry) {
    if (entry.nodeId == nodeId) return;
    if (_table.length >= kBucketSize * 8 && !_table.containsKey(entry.nodeId)) {
      final oldest = _table.values.reduce(
          (a, b) => a.lastSeen.isBefore(b.lastSeen) ? a : b);
      _table.remove(oldest.nodeId);
    }
    _table[entry.nodeId] = entry;
    notifyListeners();
  }

  void _handleLookup(ProtocolMessage msg, Socket socket) {
    final target = msg.payload['targetId'];
    if (target is! String) return;
    final hit = _table[target];
    final peers = hit != null ? [hit] : _closest(target, 3);
    socket.write(ProtocolMessage.dhtResponse(
      senderId: nodeId,
      targetId: target,
      peers: peers.map((p) => p.toJson()).toList(),
    ).encode());
  }

  Future<void> _handleResponse(ProtocolMessage msg) async {
    final target = msg.payload['targetId'];
    final peers = msg.payload['peers'];
    if (target is! String || peers is! List) return;
    // Entries relayed by third parties are unverified hints: keep them but
    // never treat their keys as pinned. The handshake decides.
    for (final p in peers.take(kBucketSize)) {
      try {
        final e = DHTEntry.fromJson(p as Map<String, dynamic>);
        if (NyxId.isValidFormat(e.nodeId)) storePeer(e);
      } catch (_) {}
    }
    final c = _pending.remove(target);
    if (c != null && !c.isCompleted) c.complete(_table[target]);
  }

  Future<void> _send(String address, int port, ProtocolMessage msg) async {
    try {
      final socket = await Socket.connect(address, port,
          timeout: const Duration(seconds: 5));
      socket.write(msg.encode());
      await socket.flush();
      socket.destroy();
    } catch (e) {
      debugPrint('[DHT] send to $address:$port failed: $e');
    }
  }

  List<DHTEntry> _closest(String targetId, int count) {
    final list = _table.values.toList()
      ..sort((a, b) => _distance(a.nodeId, targetId)
          .compareTo(_distance(b.nodeId, targetId)));
    return list.take(count).toList();
  }

  static int _distance(String a, String b) {
    final len = min(a.length, b.length);
    for (var i = 0; i < len; i++) {
      final x = a.codeUnitAt(i) ^ b.codeUnitAt(i);
      if (x != 0) return (len - i) * 256 + x;
    }
    return (a.length - b.length).abs();
  }
}