import 'dart:convert';
import 'dart:typed_data';

import '../crypto/crypto_utils.dart';
import '../crypto/double_ratchet.dart';
import 'parse.dart';

/// How an envelope was encrypted.
enum EnvelopeKind {
  /// Pairwise Double Ratchet (direct messages and group control traffic).
  ratchet,

  /// Group sender key (symmetric chain + Ed25519 signature).
  senderKey,
}

/// Material that lets a peer bootstrap a session asynchronously (X3DH-lite
/// against pinned identity keys). Attached until the initiator has heard
/// back from the recipient.
class SessionInitBlock {
  final Uint8List ephemeralKey;
  final Uint8List kyberCiphertext;

  SessionInitBlock({required this.ephemeralKey, required this.kyberCiphertext});

  Map<String, dynamic> toJson() => {
        'eph': CryptoUtils.toHex(ephemeralKey),
        'kct': base64Encode(kyberCiphertext),
      };

  factory SessionInitBlock.fromJson(Map<String, dynamic> json) => parseOr(() {
        const ctx = 'session init';
        return SessionInitBlock(
          ephemeralKey: requireHex(json, 'eph',
              length: CryptoUtils.x25519KeyLength, context: ctx),
          kyberCiphertext: requireBase64(json, 'kct',
              length: CryptoUtils.kyber768CiphertextLength, context: ctx),
        );
      }, context: 'session init');

  String get ephemeralHex => CryptoUtils.toHex(ephemeralKey);
}

/// Transport-independent end-to-end encrypted unit.
///
/// The same envelope can be delivered over a direct TCP link (inside the
/// link-encrypted frame), over the BLE mesh (as a MeshPacket payload), via
/// Wi-Fi Direct, or via an internet relay. Only [from] and [to] are visible
/// to carriers; over the mesh even those are replaced by hashes.
class Envelope {
  static const int version = 3;
  static const int maxEncodedBytes = 512 * 1024;

  final String from;
  final String to;
  final EnvelopeKind kind;
  final RatchetHeader? header;
  final SessionInitBlock? init;

  /// Hex of an initiation ephemeral the sender abandoned when it adopted
  /// our session after a simultaneous initiation. The receiver records it
  /// so that a late copy of that initiation can never replace the session.
  final String? abandonedInitEph;
  final int? iteration;
  final Uint8List? signature;
  final Uint8List ciphertext;

  Envelope._({
    required this.from,
    required this.to,
    required this.kind,
    required this.ciphertext,
    this.header,
    this.init,
    this.abandonedInitEph,
    this.iteration,
    this.signature,
  });

  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  factory Envelope.ratchet({
    required String from,
    required String to,
    required RatchetMessage message,
    SessionInitBlock? init,
    String? abandonedInitEph,
  }) =>
      Envelope._(
        from: from,
        to: to,
        kind: EnvelopeKind.ratchet,
        header: message.header,
        init: init,
        abandonedInitEph: abandonedInitEph,
        ciphertext: message.ciphertext,
      );

  factory Envelope.senderKey({
    required String from,
    required String groupId,
    required int iteration,
    required Uint8List ciphertext,
    required Uint8List signature,
  }) =>
      Envelope._(
        from: from,
        to: groupId,
        kind: EnvelopeKind.senderKey,
        iteration: iteration,
        signature: signature,
        ciphertext: ciphertext,
      );

  bool get isGroup => kind == EnvelopeKind.senderKey;

  /// Associated data bound into the AEAD so that ciphertext cannot be
  /// re-addressed to a different sender/recipient pair.
  Uint8List associatedData() =>
      associatedDataFor(from, to, kind, abandonedInitEph: abandonedInitEph);

  /// Associated data authenticated by the AEAD: addressing, kind and the
  /// abandoned-ephemeral announcement (presence and value), so a relay can
  /// neither strip nor inject `ab`.
  static Uint8List associatedDataFor(String from, String to, EnvelopeKind kind,
          {String? abandonedInitEph}) =>
      CryptoUtils.lengthPrefixed([
        'NyxChat-Envelope-v3'.codeUnits,
        utf8.encode(from),
        utf8.encode(to),
        [kind.index],
        utf8.encode(abandonedInitEph ?? ''),
      ]);

  Map<String, dynamic> toJson() => {
        'v': version,
        'from': from,
        'to': to,
        'k': kind == EnvelopeKind.ratchet ? 'dr' : 'sk',
        if (header != null) 'h': header!.toJson(),
        if (init != null) 'i': init!.toJson(),
        if (abandonedInitEph != null) 'ab': abandonedInitEph,
        if (iteration != null) 'it': iteration,
        if (signature != null) 's': CryptoUtils.toHex(signature!),
        'c': base64Encode(ciphertext),
      };

  factory Envelope.fromJson(Map<String, dynamic> json) =>
      parseOr(() => Envelope._parse(json), context: 'envelope');

  factory Envelope._parse(Map<String, dynamic> json) {
    const ctx = 'envelope';
    if (json['v'] != version) {
      throw FormatException(
          'unsupported envelope version ${describeValue(json['v'])}');
    }
    final from =
        requireString(json, 'from', minLength: 1, maxLength: 64, context: ctx);
    final to =
        requireString(json, 'to', minLength: 1, maxLength: 64, context: ctx);
    final k = json['k'];
    final ciphertext =
        requireBase64(json, 'c', maxBytes: maxEncodedBytes, context: ctx);
    if (ciphertext.length < CryptoUtils.aesGcmTagLength) {
      throw const FormatException('envelope: ciphertext too short');
    }
    if (k == 'dr') {
      final init = optionalMap(json, 'i', context: ctx);
      final abandoned = optionalString(json, 'ab',
          minLength: 64, maxLength: 64, context: ctx);
      if (abandoned != null && !_hex64.hasMatch(abandoned)) {
        throw const FormatException('envelope: "ab" is not hex');
      }
      return Envelope._(
        from: from,
        to: to,
        kind: EnvelopeKind.ratchet,
        header: RatchetHeader.fromJson(requireMap(json, 'h', context: ctx)),
        init: init == null ? null : SessionInitBlock.fromJson(init),
        abandonedInitEph: abandoned,
        ciphertext: ciphertext,
      );
    }
    if (k == 'sk') {
      return Envelope._(
        from: from,
        to: to,
        kind: EnvelopeKind.senderKey,
        iteration: requireInt(json, 'it', min: 0, max: 1 << 30, context: ctx),
        signature: requireHex(json, 's',
            length: CryptoUtils.ed25519SignatureLength, context: ctx),
        ciphertext: ciphertext,
      );
    }
    throw const FormatException('envelope: unknown kind');
  }

  String encode() => jsonEncode(toJson());

  factory Envelope.decode(String data) {
    if (data.length > maxEncodedBytes) {
      throw const FormatException('envelope too large');
    }
    return Envelope.fromJson(decodeJsonObject(data, context: 'envelope'));
  }

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(encode()));

  factory Envelope.fromBytes(List<int> bytes) {
    if (bytes.length > maxEncodedBytes) {
      throw const FormatException('envelope too large');
    }
    return Envelope.decode(
        parseOr(() => utf8.decode(bytes), context: 'envelope'));
  }

  @override
  String toString() =>
      'Envelope(${kind.name} $from -> $to, ${ciphertext.length} bytes)';
}