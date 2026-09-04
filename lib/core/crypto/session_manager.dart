import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../protocol/envelope.dart';
import '../protocol/inner_message.dart';
import '../storage/key_value_store.dart';
import '../storage/trust_store.dart';
import 'double_ratchet.dart';
import 'handshake.dart';
import 'key_manager.dart';

class NoSessionException implements Exception {
  final String peerId;
  NoSessionException(this.peerId);
  @override
  String toString() =>
      'NoSessionException: no session and no pinned keys for $peerId';
}

/// Raised when we are the responder of a session and the initiator has not
/// sent anything yet (the ratchet has no sending chain).
class SessionNotReadyException implements Exception {
  final String peerId;
  SessionNotReadyException(this.peerId);
  @override
  String toString() => 'SessionNotReadyException: waiting for $peerId to open';
}

/// Raised when a simultaneous async initiation collided and our side wins;
/// the peer will adopt our session once it receives our next message.
class SessionCollisionException implements Exception {
  final String peerId;
  SessionCollisionException(this.peerId);
  @override
  String toString() => 'SessionCollisionException: ignored init from $peerId';
}

/// A persisted pairwise session.
class SessionRecord {
  DoubleRatchetSession ratchet;

  /// Set while we are the asynchronous initiator and have not yet received
  /// anything from the peer. Attached to every outgoing envelope.
  SessionInitBlock? pendingInit;

  /// Hex of the init ephemeral we accepted as responder (de-duplicates
  /// repeated init blocks from the same initiator).
  String? acceptedInitEph;

  /// 'handshake' or 'async'.
  String origin;
  DateTime createdAt;
  DateTime updatedAt;

  SessionRecord({
    required this.ratchet,
    required this.origin,
    this.pendingInit,
    this.acceptedInitEph,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toJson() => {
        'ratchet': ratchet.toJson(),
        if (pendingInit != null) 'pendingInit': pendingInit!.toJson(),
        if (acceptedInitEph != null) 'acceptedInitEph': acceptedInitEph,
        'origin': origin,
        'created': createdAt.toIso8601String(),
        'updated': updatedAt.toIso8601String(),
      };

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        ratchet:
            DoubleRatchetSession.fromJson(j['ratchet'] as Map<String, dynamic>),
        pendingInit: j['pendingInit'] == null
            ? null
            : SessionInitBlock.fromJson(
                j['pendingInit'] as Map<String, dynamic>),
        acceptedInitEph: j['acceptedInitEph'] as String?,
        origin: j['origin'] as String? ?? 'handshake',
        createdAt: DateTime.parse(j['created'] as String),
        updatedAt: DateTime.parse(j['updated'] as String),
      );
}

/// Owns every pairwise Double Ratchet session, decides how sessions are
/// created (interactive handshake vs. asynchronous X3DH-lite), resolves
/// initiation collisions and persists state after each step.
class SessionManager {
  final KeyManager keys;
  final KeyValueStore store;
  final String myId;
  final Map<String, SessionRecord> _sessions = {};

  SessionManager({required this.keys, required this.store, required this.myId});

  Future<void> load() async {
    _sessions.clear();
    for (final key in store.keys) {
      final raw = store.get(key);
      if (raw == null) continue;
      try {
        _sessions[key] =
            SessionRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Session] dropping corrupt session for $key: $e');
        await store.delete(key);
      }
    }
  }

  bool hasSession(String peerId) => _sessions.containsKey(peerId);
  bool canSend(String peerId) => _sessions[peerId]?.ratchet.canSend ?? false;
  SessionRecord? record(String peerId) => _sessions[peerId];
  int get sessionCount => _sessions.length;

  /// Create a session from a completed direct handshake. Existing sessions
  /// are kept unless [force] is set (session-reset flow).
  Future<bool> establishFromHandshake(HandshakeResult result,
      {bool force = false}) async {
    if (!force && _sessions.containsKey(result.peerId)) return false;
    final ratchet = result.isInitiator
        ? await DoubleRatchetSession.initAlice(
            sharedSecret: result.ratchetRoot,
            bobRatchetPublicKey: result.peerEphemeralKey,
          )
        : await DoubleRatchetSession.initBob(
            sharedSecret: result.ratchetRoot,
            bobRatchetKeyPair: result.myEphemeralKeyPair,
          );
    await _save(
        result.peerId, SessionRecord(ratchet: ratchet, origin: 'handshake'));
    return true;
  }

  /// Encrypt an inner message for [peerId]. If no session exists and the
  /// peer's keys are pinned, an asynchronous session is started.
  Future<Envelope> encrypt({
    required String peerId,
    required InnerMessage message,
    PinnedPeer? pinned,
  }) async {
    var rec = _sessions[peerId];
    if (rec == null) {
      if (pinned == null) throw NoSessionException(peerId);
      final init = await Handshake.asyncInitiate(
        keys: keys,
        peerIdentityKey: pinned.identityKey,
        peerKyberPublicKey: pinned.kyberPublicKey,
      );
      final ratchet = await DoubleRatchetSession.initAlice(
        sharedSecret: init.ratchetRoot,
        bobRatchetPublicKey: pinned.identityKey,
      );
      rec = SessionRecord(
        ratchet: ratchet,
        origin: 'async',
        pendingInit: SessionInitBlock(
          ephemeralKey: init.ephemeralPublicKey,
          kyberCiphertext: init.kyberCiphertext,
        ),
      );
      _sessions[peerId] = rec;
    }
    if (!rec.ratchet.canSend) throw SessionNotReadyException(peerId);
    final ad = Envelope.associatedDataFor(myId, peerId, EnvelopeKind.ratchet);
    final sealed =
        await rec.ratchet.encrypt(message.toBytes(), associatedData: ad);
    await _save(peerId, rec);
    return Envelope.ratchet(
        from: myId, to: peerId, message: sealed, init: rec.pendingInit);
  }

  /// Decrypt a ratchet envelope addressed to us.
  Future<InnerMessage> decrypt(Envelope envelope, {PinnedPeer? pinned}) async {
    if (envelope.kind != EnvelopeKind.ratchet || envelope.header == null) {
      throw const FormatException('not a ratchet envelope');
    }
    if (envelope.to != myId) {
      throw const FormatException('envelope not addressed to us');
    }
    final peerId = envelope.from;
    final ad = Envelope.associatedDataFor(peerId, myId, EnvelopeKind.ratchet);
    final ratchetMsg = RatchetMessage(envelope.header!, envelope.ciphertext);
    final existing = _sessions[peerId];
    final init = envelope.init;

    // Fast path: use the existing session.
    if (existing != null &&
        (init == null || existing.acceptedInitEph == init.ephemeralHex)) {
      final plain =
          await existing.ratchet.decrypt(ratchetMsg, associatedData: ad);
      existing.pendingInit = null; // we heard from them: they have our key
      await _save(peerId, existing);
      return InnerMessage.fromBytes(plain);
    }

    if (init == null || pinned == null) {
      throw NoSessionException(peerId);
    }

    // Simultaneous async initiation: the lexicographically smaller id wins.
    if (existing != null &&
        existing.pendingInit != null &&
        myId.compareTo(peerId) < 0) {
      throw SessionCollisionException(peerId);
    }

    // Build a responder session from the init block and verify it by
    // decrypting; only then does it replace whatever we had.
    final root = await Handshake.asyncRespond(
      keys: keys,
      peerIdentityKey: pinned.identityKey,
      peerEphemeralKey: init.ephemeralKey,
      kyberCiphertext: init.kyberCiphertext,
    );
    final ratchet = await DoubleRatchetSession.initBob(
      sharedSecret: root,
      bobRatchetKeyPair: keys.identityKeyPair,
    );
    final plain = await ratchet.decrypt(ratchetMsg, associatedData: ad);
    await _save(
      peerId,
      SessionRecord(
        ratchet: ratchet,
        origin: 'async',
        acceptedInitEph: init.ephemeralHex,
      ),
    );
    return InnerMessage.fromBytes(plain);
  }

  Future<void> reset(String peerId) async {
    _sessions.remove(peerId);
    await store.delete(peerId);
  }

  Future<void> clearAll() async {
    for (final k in _sessions.keys.toList()) {
      await store.delete(k);
    }
    _sessions.clear();
  }

  Future<void> _save(String peerId, SessionRecord rec) async {
    rec.updatedAt = DateTime.now().toUtc();
    _sessions[peerId] = rec;
    await store.put(peerId, jsonEncode(rec.toJson()));
  }
}