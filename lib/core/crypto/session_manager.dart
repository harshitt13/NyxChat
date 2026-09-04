import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../protocol/envelope.dart';
import '../protocol/inner_message.dart';
import '../protocol/padding.dart';
import '../storage/key_value_store.dart';
import '../storage/trust_store.dart';
import 'double_ratchet.dart';
import 'handshake.dart';
import 'key_manager.dart';
import 'prekey_store.dart';

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

/// Raised when an asynchronous init names a one-time prekey we no longer
/// hold (already used, expired, or wiped). The message cannot be read; the
/// caller tells the initiator, which restarts with the long-term KEM key.
class UnknownPrekeyException implements Exception {
  final String peerId;
  final String prekeyId;
  final String ephemeralHex;
  UnknownPrekeyException(this.peerId, this.prekeyId, this.ephemeralHex);
  @override
  String toString() =>
      'UnknownPrekeyException: $peerId named prekey $prekeyId, not held';
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

  /// Init ephemerals we deliberately ignored (we won a collision). A
  /// stale message carrying one of them must never replace the session.
  final List<String> ignoredInitEphs;

  /// Our own init ephemeral that we abandoned when we lost a collision and
  /// adopted the peer's session. Announced on every outgoing envelope until
  /// the peer has heard from us, so the peer can blacklist it before a late
  /// copy of the abandoned initiation reaches them.
  String? abandonedInitEph;

  /// 'handshake' or 'async'.
  String origin;

  /// One-time prekey this session consumed: the peer's, if we initiated
  /// asynchronously; ours, if we responded. Null for direct-link sessions
  /// and for asynchronous sessions that fell back to the long-term KEM key
  /// (see [isAsyncFallback]). Diagnostic only; if an initiation loses a
  /// collision the prekey it consumed is simply gone, on both sides.
  String? prekeyId;
  DateTime createdAt;
  DateTime updatedAt;

  SessionRecord({
    required this.ratchet,
    required this.origin,
    this.prekeyId,
    this.pendingInit,
    this.acceptedInitEph,
    List<String>? ignoredInitEphs,
    this.abandonedInitEph,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : ignoredInitEphs = ignoredInitEphs ?? [],
        createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toJson() => {
        'ratchet': ratchet.toJson(),
        if (pendingInit != null) 'pendingInit': pendingInit!.toJson(),
        if (acceptedInitEph != null) 'acceptedInitEph': acceptedInitEph,
        if (ignoredInitEphs.isNotEmpty) 'ignoredInit': ignoredInitEphs,
        if (abandonedInitEph != null) 'abandonedInit': abandonedInitEph,
        if (prekeyId != null) 'prekey': prekeyId,
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
        ignoredInitEphs: (j['ignoredInit'] as List<dynamic>?)?.cast<String>().toList(),
        abandonedInitEph: j['abandonedInit'] as String?,
        prekeyId: j['prekey'] as String?,
        origin: j['origin'] as String? ?? 'handshake',
        createdAt: DateTime.parse(j['created'] as String),
        updatedAt: DateTime.parse(j['updated'] as String),
      );

  /// True for an asynchronous session established with the peer's
  /// long-term KEM key because no one-time prekey was available: its root
  /// gains post-quantum forward secrecy only at the peer's first reply.
  bool get isAsyncFallback => origin == 'async' && prekeyId == null;
}

/// Owns every pairwise Double Ratchet session, decides how sessions are
/// created (interactive handshake vs. asynchronous X3DH-lite), resolves
/// initiation collisions and persists state after each step.
class SessionManager {
  final KeyManager keys;
  final KeyValueStore store;
  final String myId;

  /// One-time prekey pools; null means asynchronous sessions always use
  /// the long-term KEM key (tests, tools).
  final PrekeyStore? prekeys;
  final Map<String, SessionRecord> _sessions = {};

  SessionManager({
    required this.keys,
    required this.store,
    required this.myId,
    this.prekeys,
  });

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
      // Prefer a one-time prekey the peer issued to us (post-quantum
      // forward secrecy from the first message). The long-term KEM key is
      // the last resort and leaves the record flagged (isAsyncFallback).
      final otp = await prekeys?.takePeerPrekey(peerId);
      final init = await Handshake.asyncInitiate(
        keys: keys,
        peerIdentityKey: pinned.identityKey,
        peerKyberPublicKey: pinned.kyberPublicKey,
        prekeyId: otp?.idBytes,
        prekeyPublicKey: otp?.publicKey,
      );
      final ratchet = await DoubleRatchetSession.initAlice(
        sharedSecret: init.ratchetRoot,
        bobRatchetPublicKey: pinned.identityKey,
      );
      rec = SessionRecord(
        ratchet: ratchet,
        origin: 'async',
        prekeyId: otp?.id,
        pendingInit: SessionInitBlock(
          ephemeralKey: init.ephemeralPublicKey,
          kyberCiphertext: init.kyberCiphertext,
          prekeyId: init.prekeyId,
        ),
      );
      _sessions[peerId] = rec;
    }
    if (!rec.ratchet.canSend) throw SessionNotReadyException(peerId);
    final ad = Envelope.associatedDataFor(myId, peerId, EnvelopeKind.ratchet,
        abandonedInitEph: rec.abandonedInitEph);
    final sealed = await rec.ratchet
        .encrypt(Padding.pad(message.toBytes()), associatedData: ad);
    await _save(peerId, rec);
    return Envelope.ratchet(
        from: myId,
        to: peerId,
        message: sealed,
        init: rec.pendingInit,
        abandonedInitEph: rec.abandonedInitEph);
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
    final ad = Envelope.associatedDataFor(peerId, myId, EnvelopeKind.ratchet,
        abandonedInitEph: envelope.abandonedInitEph);
    final ratchetMsg = RatchetMessage(envelope.header!, envelope.ciphertext);
    final existing = _sessions[peerId];
    final init = envelope.init;

    // Fast path: use the existing session.
    if (existing != null &&
        (init == null || existing.acceptedInitEph == init.ephemeralHex)) {
      final plain =
          await existing.ratchet.decrypt(ratchetMsg, associatedData: ad);
      existing.pendingInit = null; // we heard from them: they have our key
      if (init == null) {
        // They stopped sending their init: they have heard from us, so the
        // abandoned-ephemeral announcement has done its job.
        existing.abandonedInitEph = null;
      }
      final abandoned = envelope.abandonedInitEph;
      if (abandoned != null) _remember(existing.ignoredInitEphs, abandoned);
      await _save(peerId, existing);
      return InnerMessage.fromBytes(Padding.unpad(plain));
    }

    if (init == null || pinned == null) {
      throw NoSessionException(peerId);
    }

    // A late message from an initiation we already declined must not be
    // mistaken for the peer having lost its state.
    if (existing != null && existing.ignoredInitEphs.contains(init.ephemeralHex)) {
      throw SessionCollisionException(peerId);
    }

    // Simultaneous async initiation: the lexicographically smaller id wins.
    if (existing != null &&
        existing.pendingInit != null &&
        myId.compareTo(peerId) < 0) {
      _remember(existing.ignoredInitEphs, init.ephemeralHex);
      await _save(peerId, existing);
      throw SessionCollisionException(peerId);
    }

    // An init that names one of our one-time prekeys needs its private
    // half; a missing id (used, expired, wiped) is reported so the
    // initiator can restart with the long-term key. We never guess.
    OwnPrekey? own;
    final prekeyId = init.prekeyIdHex;
    if (prekeyId != null) {
      own = prekeys?.findOwn(peerId, prekeyId);
      if (own == null) {
        throw UnknownPrekeyException(peerId, prekeyId, init.ephemeralHex);
      }
    }

    // Build a responder session from the init block and verify it by
    // decrypting; only then does it replace whatever we had, and only then
    // is the consumed prekey's private half deleted. Repeats of the same
    // init are served by acceptedInitEph above and never need it again.
    final root = await Handshake.asyncRespond(
      keys: keys,
      peerIdentityKey: pinned.identityKey,
      peerEphemeralKey: init.ephemeralKey,
      kyberCiphertext: init.kyberCiphertext,
      prekeyId: init.prekeyId,
      prekeyPrivateKey: own?.privateKey,
    );
    final ratchet = await DoubleRatchetSession.initBob(
      sharedSecret: root,
      bobRatchetKeyPair: keys.identityKeyPair,
    );
    final plain = await ratchet.decrypt(ratchetMsg, associatedData: ad);
    if (own != null) await prekeys!.deleteOwn(peerId, own.id);
    await _save(
      peerId,
      SessionRecord(
        ratchet: ratchet,
        origin: 'async',
        prekeyId: own?.id,
        acceptedInitEph: init.ephemeralHex,
        // If we were mid-initiation ourselves we lost the collision: tell
        // the peer which ephemeral to blacklist. Keep what we already ignore.
        abandonedInitEph: existing?.pendingInit?.ephemeralHex,
        ignoredInitEphs: existing?.ignoredInitEphs,
      ),
    );
    return InnerMessage.fromBytes(Padding.unpad(plain));
  }

  static void _remember(List<String> list, String eph) {
    if (list.contains(eph)) return;
    list.add(eph);
    while (list.length > 8) {
      list.removeAt(0);
    }
  }

  /// A contact rotated its identity: carry the session over to the new id.
  Future<void> rename(String oldPeerId, String newPeerId) async {
    final rec = _sessions.remove(oldPeerId);
    await store.delete(oldPeerId);
    if (rec == null) return;
    await _save(newPeerId, rec);
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