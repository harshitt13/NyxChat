import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto_utils.dart';

/// Header carried with every Double Ratchet message.
class RatchetHeader {
  /// Sender's current ratchet public key (32 bytes).
  final Uint8List dh;

  /// Number of messages in the sender's previous sending chain.
  final int pn;

  /// Message number within the current sending chain.
  final int n;

  RatchetHeader({required this.dh, required this.pn, required this.n});

  Map<String, dynamic> toJson() =>
      {'dh': CryptoUtils.toHex(dh), 'pn': pn, 'n': n};

  factory RatchetHeader.fromJson(Map<String, dynamic> json) {
    final dh = CryptoUtils.decodeKey(
        json['dh'] as String, CryptoUtils.x25519KeyLength, 'ratchet key');
    final pn = json['pn'];
    final n = json['n'];
    if (pn is! int || n is! int || pn < 0 || n < 0 || pn > 1 << 30 ||
        n > 1 << 30) {
      throw const FormatException('invalid ratchet header counters');
    }
    return RatchetHeader(dh: dh, pn: pn, n: n);
  }

  /// Canonical bytes, bound into the AEAD associated data.
  Uint8List toBytes() => CryptoUtils.concat(
      [dh, CryptoUtils.int32be(pn), CryptoUtils.int32be(n)]);
}

class RatchetMessage {
  final RatchetHeader header;
  final Uint8List ciphertext;
  RatchetMessage(this.header, this.ciphertext);
}

class RatchetException implements Exception {
  final String message;
  RatchetException(this.message);
  @override
  String toString() => 'RatchetException: $message';
}

/// Signal Double Ratchet (https://signal.org/docs/specifications/doubleratchet/)
///
/// * KDF_RK  = HKDF-SHA256(salt = rootKey, ikm = DH output)
/// * KDF_CK  = HMAC-SHA256(chainKey, 0x01) -> message key,
///             HMAC-SHA256(chainKey, 0x02) -> next chain key
/// * AEAD    = AES-256-GCM with key and nonce derived from the message key
///
/// State changes are made on a working copy and committed only after the
/// ciphertext authenticates, so a forged or corrupted message can never
/// desynchronise the session.
class DoubleRatchetSession {
  static const int maxSkip = 256;
  static const int maxStoredSkipped = 1024;
  static const String _rootInfo = 'NyxChat-DR-Root-v3';
  static const String _aeadInfo = 'NyxChat-DR-AEAD-v3';

  SimpleKeyPairData _dhs;
  Uint8List _dhsPub;
  Uint8List? _dhr;
  Uint8List _rk;
  Uint8List? _cks;
  Uint8List? _ckr;
  int _ns;
  int _nr;
  int _pn;
  final Map<String, Uint8List> _skipped;

  DoubleRatchetSession._({
    required SimpleKeyPairData dhs,
    required Uint8List? dhr,
    required Uint8List rk,
    required Uint8List? cks,
    required Uint8List? ckr,
    required int ns,
    required int nr,
    required int pn,
    required Map<String, Uint8List> skipped,
  })  : _dhs = dhs,
        _dhsPub = CryptoUtils.publicKeyBytes(dhs),
        _dhr = dhr,
        _rk = rk,
        _cks = cks,
        _ckr = ckr,
        _ns = ns,
        _nr = nr,
        _pn = pn,
        _skipped = skipped;

  /// Initialise as the party that sends first ("Alice").
  static Future<DoubleRatchetSession> initAlice({
    required Uint8List sharedSecret,
    required Uint8List bobRatchetPublicKey,
  }) async {
    final dhs = await CryptoUtils.newX25519KeyPair();
    final dhOut = await CryptoUtils.x25519(dhs, bobRatchetPublicKey);
    final derived = await _kdfRk(sharedSecret, dhOut);
    return DoubleRatchetSession._(
      dhs: dhs,
      dhr: Uint8List.fromList(bobRatchetPublicKey),
      rk: derived.$1,
      cks: derived.$2,
      ckr: null,
      ns: 0,
      nr: 0,
      pn: 0,
      skipped: <String, Uint8List>{},
    );
  }

  /// Initialise as the party that receives first ("Bob").
  static Future<DoubleRatchetSession> initBob({
    required Uint8List sharedSecret,
    required SimpleKeyPairData bobRatchetKeyPair,
  }) async {
    return DoubleRatchetSession._(
      dhs: bobRatchetKeyPair,
      dhr: null,
      rk: Uint8List.fromList(sharedSecret),
      cks: null,
      ckr: null,
      ns: 0,
      nr: 0,
      pn: 0,
      skipped: <String, Uint8List>{},
    );
  }

  /// True once a sending chain exists. Bob cannot send before receiving.
  bool get canSend => _cks != null;
  Uint8List get ratchetPublicKey => _dhsPub;
  int get sentCount => _ns;
  int get receivedCount => _nr;
  int get skippedKeyCount => _skipped.length;

  Future<RatchetMessage> encrypt(List<int> plaintext,
      {List<int> associatedData = const <int>[]}) async {
    final cks = _cks;
    if (cks == null) {
      throw RatchetException('session has no sending chain yet');
    }
    final step = await _kdfCk(cks);
    final header = RatchetHeader(dh: _dhsPub, pn: _pn, n: _ns);
    final ad = CryptoUtils.concat([associatedData, header.toBytes()]);
    final ciphertext = await _aeadEncrypt(step.$2, plaintext, ad);
    _cks = step.$1;
    _ns++;
    CryptoUtils.wipe(step.$2);
    return RatchetMessage(header, ciphertext);
  }

  Future<Uint8List> decrypt(RatchetMessage message,
      {List<int> associatedData = const <int>[]}) async {
    final header = message.header;
    final ad = CryptoUtils.concat([associatedData, header.toBytes()]);

    // 1. Out-of-order message whose key was stored earlier?
    final skippedId = _skippedId(header.dh, header.n);
    final storedKey = _skipped[skippedId];
    if (storedKey != null) {
      final plain = await _aeadDecrypt(storedKey, message.ciphertext, ad);
      _skipped.remove(skippedId);
      CryptoUtils.wipe(storedKey);
      return plain;
    }

    // 2. Advance on a copy; commit only if authentication succeeds.
    final work = _clone();
    final dhr = work._dhr;
    if (dhr == null || !CryptoUtils.constantTimeEquals(header.dh, dhr)) {
      await work._skipMessageKeys(header.pn);
      await work._dhRatchet(header.dh);
    }
    await work._skipMessageKeys(header.n);
    final ckr = work._ckr;
    if (ckr == null) {
      throw RatchetException('no receiving chain');
    }
    final step = await _kdfCk(ckr);
    work._ckr = step.$1;
    work._nr++;
    final plain = await _aeadDecrypt(step.$2, message.ciphertext, ad);
    CryptoUtils.wipe(step.$2);
    _commit(work);
    return plain;
  }

  Future<void> _skipMessageKeys(int until) async {
    final ckr = _ckr;
    if (ckr == null) return;
    if (until - _nr > maxSkip) {
      throw RatchetException('too many skipped messages (${until - _nr})');
    }
    var chain = ckr;
    while (_nr < until) {
      final step = await _kdfCk(chain);
      _skipped[_skippedId(_dhr!, _nr)] = step.$2;
      chain = step.$1;
      _nr++;
    }
    _ckr = chain;
    while (_skipped.length > maxStoredSkipped) {
      final oldest = _skipped.keys.first;
      CryptoUtils.wipe(_skipped.remove(oldest)!);
    }
  }

  Future<void> _dhRatchet(Uint8List theirRatchetKey) async {
    _pn = _ns;
    _ns = 0;
    _nr = 0;
    _dhr = Uint8List.fromList(theirRatchetKey);
    final recv = await _kdfRk(_rk, await CryptoUtils.x25519(_dhs, _dhr!));
    _rk = recv.$1;
    _ckr = recv.$2;
    _dhs = await CryptoUtils.newX25519KeyPair();
    _dhsPub = CryptoUtils.publicKeyBytes(_dhs);
    final send = await _kdfRk(_rk, await CryptoUtils.x25519(_dhs, _dhr!));
    _rk = send.$1;
    _cks = send.$2;
  }

  static String _skippedId(Uint8List dh, int n) =>
      '${CryptoUtils.toHex(dh)}:$n';

  static Future<(Uint8List, Uint8List)> _kdfRk(
      Uint8List rootKey, Uint8List dhOut) async {
    final out = await CryptoUtils.hkdf(
        ikm: dhOut, salt: rootKey, info: _rootInfo, length: 64);
    return (out.sublist(0, 32), out.sublist(32));
  }

  static Future<(Uint8List, Uint8List)> _kdfCk(Uint8List chainKey) async {
    final mk = await CryptoUtils.hmacSha256(chainKey, const [0x01]);
    final next = await CryptoUtils.hmacSha256(chainKey, const [0x02]);
    return (next, mk);
  }

  static Future<(Uint8List, Uint8List)> _aeadKeys(Uint8List mk) async {
    final out = await CryptoUtils.hkdf(
        ikm: mk, salt: Uint8List(32), info: _aeadInfo, length: 44);
    return (out.sublist(0, 32), out.sublist(32));
  }

  static Future<Uint8List> _aeadEncrypt(
      Uint8List mk, List<int> plaintext, List<int> ad) async {
    final keys = await _aeadKeys(mk);
    return CryptoUtils.aesGcmEncrypt(
        key: keys.$1, nonce: keys.$2, plaintext: plaintext, aad: ad);
  }

  static Future<Uint8List> _aeadDecrypt(
      Uint8List mk, List<int> ciphertext, List<int> ad) async {
    final keys = await _aeadKeys(mk);
    try {
      return await CryptoUtils.aesGcmDecrypt(
          key: keys.$1, nonce: keys.$2, ciphertextWithTag: ciphertext, aad: ad);
    } on SecretBoxAuthenticationError {
      throw RatchetException('message authentication failed');
    }
  }

  DoubleRatchetSession _clone() => DoubleRatchetSession._(
        dhs: _dhs,
        dhr: _dhr == null ? null : Uint8List.fromList(_dhr!),
        rk: Uint8List.fromList(_rk),
        cks: _cks == null ? null : Uint8List.fromList(_cks!),
        ckr: _ckr == null ? null : Uint8List.fromList(_ckr!),
        ns: _ns,
        nr: _nr,
        pn: _pn,
        skipped: Map<String, Uint8List>.of(_skipped),
      );

  void _commit(DoubleRatchetSession work) {
    _dhs = work._dhs;
    _dhsPub = work._dhsPub;
    _dhr = work._dhr;
    _rk = work._rk;
    _cks = work._cks;
    _ckr = work._ckr;
    _ns = work._ns;
    _nr = work._nr;
    _pn = work._pn;
    _skipped
      ..clear()
      ..addAll(work._skipped);
  }

  // Persistence

  Map<String, dynamic> toJson() => {
        'v': 1,
        'dhsPriv': CryptoUtils.toHex(_dhs.bytes),
        'dhsPub': CryptoUtils.toHex(_dhsPub),
        'dhr': _dhr == null ? null : CryptoUtils.toHex(_dhr!),
        'rk': CryptoUtils.toHex(_rk),
        'cks': _cks == null ? null : CryptoUtils.toHex(_cks!),
        'ckr': _ckr == null ? null : CryptoUtils.toHex(_ckr!),
        'ns': _ns,
        'nr': _nr,
        'pn': _pn,
        'skipped': _skipped.entries
            .map((e) => [e.key, CryptoUtils.toHex(e.value)])
            .toList(),
      };

  factory DoubleRatchetSession.fromJson(Map<String, dynamic> json) {
    Uint8List? opt(String key) =>
        json[key] == null ? null : CryptoUtils.fromHex(json[key] as String);
    final skipped = <String, Uint8List>{};
    for (final entry in (json['skipped'] as List<dynamic>? ?? const [])) {
      final pair = entry as List<dynamic>;
      skipped[pair[0] as String] = CryptoUtils.fromHex(pair[1] as String);
    }
    return DoubleRatchetSession._(
      dhs: CryptoUtils.x25519KeyPairFromBytes(
        CryptoUtils.fromHex(json['dhsPriv'] as String),
        CryptoUtils.fromHex(json['dhsPub'] as String),
      ),
      dhr: opt('dhr'),
      rk: CryptoUtils.fromHex(json['rk'] as String),
      cks: opt('cks'),
      ckr: opt('ckr'),
      ns: json['ns'] as int,
      nr: json['nr'] as int,
      pn: json['pn'] as int,
      skipped: skipped,
    );
  }
}