import 'dart:convert';
import 'dart:typed_data';

import '../protocol/envelope.dart';
import '../protocol/parse.dart';
import 'crypto_utils.dart';
import 'key_manager.dart';
import 'prekey_store.dart';

/// Public half of a one-time prekey as it travels in a [PrekeyBundle].
class PublicPrekey {
  final String id;
  final Uint8List publicKey;
  PublicPrekey({required this.id, required this.publicKey});

  Map<String, dynamic> toJson() => {'id': id, 'pk': base64Encode(publicKey)};

  factory PublicPrekey.fromJson(Map<String, dynamic> j) => parseOr(() {
        const ctx = 'prekey';
        return PublicPrekey(
          id: PrekeyStore.requireId(j, 'id', context: ctx),
          publicKey: requireBase64(j, 'pk',
              length: CryptoUtils.kyber768PublicKeyLength, context: ctx),
        );
      }, context: 'prekey');
}

/// The current pool of one-time ML-KEM-768 prekeys one device issues to
/// one contact, sent right after every direct-link handshake (frame type
/// `prekeys`, inside the link encryption).
///
/// Signed with the issuer's Ed25519 identity key over a domain-separated,
/// length-prefixed transcript that names the recipient and carries an
/// issue time, as defence in depth on top of the authenticated link: a
/// bundle cannot be re-addressed to another contact, and a receiver keeps
/// the newest issue time it accepted so an older bundle is refused.
///
/// The bundle always carries the issuer's *whole* live pool rather than a
/// delta, so a receiver that lost its store (the case that motivates
/// re-sending) rebuilds it on the next meeting; the receiver replaces what
/// it held and never re-admits an id it already consumed.
class PrekeyBundle {
  static const int version = 1;
  static const String label = 'NyxChat-Prekey-Bundle-v1';
  static const int maxKeys = 16;

  /// Tolerated distance between the issue time and the receiver's clock,
  /// in either direction. Bundles travel over a live link, so this only
  /// guards against grossly wrong clocks and very old captures.
  static const Duration maxClockSkew = Duration(days: 7);

  final String from;
  final String to;
  final int issuedAtMs;
  final List<PublicPrekey> keys;
  final Uint8List signature;

  PrekeyBundle({
    required this.from,
    required this.to,
    required this.issuedAtMs,
    required this.keys,
    required this.signature,
  });

  static Uint8List transcriptFor({
    required String from,
    required String to,
    required int issuedAtMs,
    required List<PublicPrekey> keys,
  }) =>
      CryptoUtils.lengthPrefixed([
        label.codeUnits,
        utf8.encode(from),
        utf8.encode(to),
        CryptoUtils.int64be(issuedAtMs),
        CryptoUtils.int32be(keys.length),
        for (final k in keys) ...[CryptoUtils.fromHex(k.id), k.publicKey],
      ]);

  Uint8List transcript() =>
      transcriptFor(from: from, to: to, issuedAtMs: issuedAtMs, keys: keys);

  static Future<PrekeyBundle> create({
    required KeyManager keys,
    required String from,
    required String to,
    required List<PublicPrekey> prekeys,
    DateTime? issuedAt,
  }) async {
    if (prekeys.length > maxKeys) {
      throw ArgumentError('at most $maxKeys prekeys per bundle');
    }
    final iat = (issuedAt ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    final t = transcriptFor(from: from, to: to, issuedAtMs: iat, keys: prekeys);
    return PrekeyBundle(
      from: from,
      to: to,
      issuedAtMs: iat,
      keys: prekeys,
      signature: await keys.sign(t),
    );
  }

  /// Null when the bundle is acceptable from [fromId] (the authenticated
  /// link peer) for us ([myId]); otherwise a short reason for the log.
  /// [lastIssuedAtMs] is the issue time of the bundle we currently hold
  /// from that contact; anything not strictly newer is a replay.
  Future<String?> validate({
    required List<int> pinnedSigningKey,
    required String myId,
    required String fromId,
    int? lastIssuedAtMs,
    DateTime? now,
  }) async {
    if (to != myId) return 'addressed to $to';
    if (from != fromId) return 'names sender $from';
    if (keys.isEmpty) return 'empty';
    final t = (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    if ((issuedAtMs - t).abs() > maxClockSkew.inMilliseconds) {
      return 'issue time too far from now';
    }
    if (lastIssuedAtMs != null && issuedAtMs <= lastIssuedAtMs) {
      return 'not newer than the bundle on file (replay)';
    }
    final seen = <String>{};
    for (final k in keys) {
      if (!seen.add(k.id)) return 'duplicate prekey id';
      if (await PrekeyStore.idHexFor(k.publicKey) != k.id) {
        return 'prekey id does not match its key';
      }
    }
    final ok = await CryptoUtils.ed25519Verify(
        publicKey: pinnedSigningKey, message: transcript(), signature: signature);
    return ok ? null : 'bad signature';
  }

  Map<String, dynamic> toJson() => {
        'v': version,
        'from': from,
        'to': to,
        'iat': issuedAtMs,
        'keys': keys.map((k) => k.toJson()).toList(),
        'sig': CryptoUtils.toHex(signature),
      };

  factory PrekeyBundle.fromJson(Map<String, dynamic> j) => parseOr(() {
        const ctx = 'prekey bundle';
        if (j['v'] != version) {
          throw FormatException(
              '$ctx: unsupported version ${describeValue(j['v'])}');
        }
        return PrekeyBundle(
          from: requireString(j, 'from', minLength: 1, maxLength: 64, context: ctx),
          to: requireString(j, 'to', minLength: 1, maxLength: 64, context: ctx),
          issuedAtMs: requireInt(j, 'iat', context: ctx),
          keys: [
            for (final e in requireList(j, 'keys', maxLength: maxKeys, context: ctx))
              PublicPrekey.fromJson(asJsonMap(e, context: ctx))
          ],
          signature: requireHex(j, 'sig',
              length: CryptoUtils.ed25519SignatureLength, context: ctx),
        );
      }, context: 'prekey bundle');
}

/// Signed notice from a responder that received an asynchronous session
/// init naming a one-time prekey it no longer holds (used, expired or
/// wiped). Travels outside any session as a control [Envelope] over the
/// same carrier the init came from (sealed for the pair on mesh and relay
/// paths). The initiator acts on it only while the named ephemeral is its
/// pending init, so a replayed notice is inert, and only after checking
/// the signature against the pinned key, so nobody else can trigger the
/// fallback to the long-term KEM key.
class PrekeyUnknownNotice {
  static const int version = 1;
  static const String label = 'NyxChat-Prekey-Unknown-v1';
  static const String kind = 'prekey-unknown';
  static const Duration maxClockSkew = Duration(days: 30);

  final String from;
  final String to;
  final String ephemeralHex;
  final String prekeyId;
  final int issuedAtMs;
  final Uint8List signature;

  PrekeyUnknownNotice({
    required this.from,
    required this.to,
    required this.ephemeralHex,
    required this.prekeyId,
    required this.issuedAtMs,
    required this.signature,
  });

  static Uint8List transcriptFor({
    required String from,
    required String to,
    required String ephemeralHex,
    required String prekeyId,
    required int issuedAtMs,
  }) =>
      CryptoUtils.lengthPrefixed([
        label.codeUnits,
        utf8.encode(from),
        utf8.encode(to),
        CryptoUtils.fromHex(ephemeralHex),
        CryptoUtils.fromHex(prekeyId),
        CryptoUtils.int64be(issuedAtMs),
      ]);

  Uint8List transcript() => transcriptFor(
      from: from, to: to, ephemeralHex: ephemeralHex, prekeyId: prekeyId,
      issuedAtMs: issuedAtMs);

  static Future<PrekeyUnknownNotice> create({
    required KeyManager keys,
    required String from,
    required String to,
    required String ephemeralHex,
    required String prekeyId,
    DateTime? issuedAt,
  }) async {
    final iat = (issuedAt ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    final t = transcriptFor(from: from, to: to, ephemeralHex: ephemeralHex,
        prekeyId: prekeyId, issuedAtMs: iat);
    return PrekeyUnknownNotice(
      from: from,
      to: to,
      ephemeralHex: ephemeralHex,
      prekeyId: prekeyId,
      issuedAtMs: iat,
      signature: await keys.sign(t),
    );
  }

  /// Null when the notice is genuine and addressed to us; else a reason.
  Future<String?> validate({
    required List<int> pinnedSigningKey,
    required String myId,
    required String fromId,
    DateTime? now,
  }) async {
    if (to != myId) return 'addressed to $to';
    if (from != fromId) return 'names sender $from';
    final t = (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    if ((issuedAtMs - t).abs() > maxClockSkew.inMilliseconds) {
      return 'issue time too far from now';
    }
    final ok = await CryptoUtils.ed25519Verify(
        publicKey: pinnedSigningKey, message: transcript(), signature: signature);
    return ok ? null : 'bad signature';
  }

  Map<String, dynamic> toJson() => {
        'v': version,
        't': kind,
        'from': from,
        'to': to,
        'eph': ephemeralHex,
        'pk': prekeyId,
        'iat': issuedAtMs,
        'sig': CryptoUtils.toHex(signature),
      };

  factory PrekeyUnknownNotice.fromJson(Map<String, dynamic> j) => parseOr(() {
        const ctx = 'prekey notice';
        if (j['v'] != version) {
          throw FormatException(
              '$ctx: unsupported version ${describeValue(j['v'])}');
        }
        if (j['t'] != kind) {
          throw FormatException('$ctx: not a $kind notice');
        }
        final eph = requireHex(j, 'eph',
            length: CryptoUtils.x25519KeyLength, context: ctx);
        return PrekeyUnknownNotice(
          from: requireString(j, 'from', minLength: 1, maxLength: 64, context: ctx),
          to: requireString(j, 'to', minLength: 1, maxLength: 64, context: ctx),
          ephemeralHex: CryptoUtils.toHex(eph),
          prekeyId: PrekeyStore.requireId(j, 'pk', context: ctx),
          issuedAtMs: requireInt(j, 'iat', context: ctx),
          signature: requireHex(j, 'sig',
              length: CryptoUtils.ed25519SignatureLength, context: ctx),
        );
      }, context: 'prekey notice');

  Envelope toEnvelope() => Envelope.control(
      from: from, to: to, body: Uint8List.fromList(utf8.encode(jsonEncode(toJson()))));

  /// Parse a control envelope; the body must agree with the envelope's
  /// addressing so a relay cannot re-route a notice.
  factory PrekeyUnknownNotice.fromEnvelope(Envelope env) {
    if (env.kind != EnvelopeKind.control) {
      throw const FormatException('prekey notice: not a control envelope');
    }
    final n = PrekeyUnknownNotice.fromJson(decodeJsonObject(
        parseOr(() => utf8.decode(env.controlBody), context: 'prekey notice'),
        context: 'prekey notice'));
    if (n.from != env.from || n.to != env.to) {
      throw const FormatException('prekey notice: addressing mismatch');
    }
    return n;
  }
}