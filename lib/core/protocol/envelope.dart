import 'dart:convert';
import 'dart:typed_data';

import '../crypto/crypto_utils.dart';
import '../crypto/double_ratchet.dart';

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

  factory SessionInitBlock.fromJson(Map<String, dynamic> json) {
    final kct = base64Decode(json['kct'] as String);
    if (kct.length != CryptoUtils.kyber768CiphertextLength) {
      throw const FormatException('bad kyber ciphertext length');
    }
    return SessionInitBlock(
      ephemeralKey: CryptoUtils.decodeKey(
          json['eph'] as String, CryptoUtils.x25519KeyLength, 'init ephemeral'),
      kyberCiphertext: kct,
    );
  }

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
    this.iteration,
    this.signature,
  });

  factory Envelope.ratchet({
    required String from,
    required String to,
    required RatchetMessage message,
    SessionInitBlock? init,
  }) =>
      Envelope._(
        from: from,
        to: to,
        kind: EnvelopeKind.ratchet,
        header: message.header,
        init: init,
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
  Uint8List associatedData() => associatedDataFor(from, to, kind);

  static Uint8List associatedDataFor(String from, String to, EnvelopeKind kind) =>
      CryptoUtils.lengthPrefixed([
        'NyxChat-Envelope-v3'.codeUnits,
        utf8.encode(from),
        utf8.encode(to),
        [kind.index],
      ]);

  Map<String, dynamic> toJson() => {
        'v': version,
        'from': from,
        'to': to,
        'k': kind == EnvelopeKind.ratchet ? 'dr' : 'sk',
        if (header != null) 'h': header!.toJson(),
        if (init != null) 'i': init!.toJson(),
        if (iteration != null) 'it': iteration,
        if (signature != null) 's': CryptoUtils.toHex(signature!),
        'c': base64Encode(ciphertext),
      };

  factory Envelope.fromJson(Map<String, dynamic> json) {
    if (json['v'] != version) {
      throw FormatException('unsupported envelope version ${json['v']}');
    }
    final from = json['from'];
    final to = json['to'];
    final k = json['k'];
    final c = json['c'];
    if (from is! String || from.isEmpty || from.length > 64) {
      throw const FormatException('envelope: bad from');
    }
    if (to is! String || to.isEmpty || to.length > 64) {
      throw const FormatException('envelope: bad to');
    }
    if (c is! String) throw const FormatException('envelope: bad ciphertext');
    final ciphertext = base64Decode(c);
    if (ciphertext.length < CryptoUtils.aesGcmTagLength) {
      throw const FormatException('envelope: ciphertext too short');
    }
    if (k == 'dr') {
      final h = json['h'];
      if (h is! Map<String, dynamic>) {
        throw const FormatException('envelope: missing ratchet header');
      }
      final i = json['i'];
      return Envelope._(
        from: from,
        to: to,
        kind: EnvelopeKind.ratchet,
        header: RatchetHeader.fromJson(h),
        init: i is Map<String, dynamic> ? SessionInitBlock.fromJson(i) : null,
        ciphertext: ciphertext,
      );
    }
    if (k == 'sk') {
      final it = json['it'];
      final s = json['s'];
      if (it is! int || it < 0 || s is! String) {
        throw const FormatException('envelope: bad sender-key fields');
      }
      return Envelope._(
        from: from,
        to: to,
        kind: EnvelopeKind.senderKey,
        iteration: it,
        signature: CryptoUtils.decodeKey(
            s, CryptoUtils.ed25519SignatureLength, 'sender-key signature'),
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
    return Envelope.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(encode()));

  factory Envelope.fromBytes(List<int> bytes) {
    if (bytes.length > maxEncodedBytes) {
      throw const FormatException('envelope too large');
    }
    return Envelope.decode(utf8.decode(bytes));
  }

  @override
  String toString() =>
      'Envelope(${kind.name} $from -> $to, ${ciphertext.length} bytes)';
}