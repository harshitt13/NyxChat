import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../protocol/parse.dart';
import 'crypto_utils.dart';

/// Group messaging with Sender Keys (the scheme used by Signal groups).
///
/// Each member owns, per group, a symmetric chain key and an Ed25519
/// signing key. The pair is distributed to every other member through the
/// pairwise Double Ratchet (so distribution inherits its authentication
/// and forward secrecy). A group message is:
///
///   mk_i   = HMAC(ck_i, 0x01),  ck_{i+1} = HMAC(ck_i, 0x02)
///   ct     = AES-256-GCM(HKDF(mk_i), plaintext, ad)
///   sig    = Ed25519(signKey, "NyxChat-SK-v3" || groupId || i || ct || ad)
///
/// Encryption cost is O(1) per message instead of O(members). Chain keys
/// are rotated whenever membership changes so removed members cannot read
/// later traffic.
class SenderKeyState {
  static const int maxSkip = 512;
  static const int maxStoredSkipped = 1024;

  Uint8List chainKey;
  int iteration;
  final Uint8List signingPublicKey;
  final SimpleKeyPairData? signingKeyPair; // only present for our own keys
  final Map<int, Uint8List> skipped;

  SenderKeyState({
    required this.chainKey,
    required this.iteration,
    required this.signingPublicKey,
    this.signingKeyPair,
    Map<int, Uint8List>? skipped,
  }) : skipped = skipped ?? <int, Uint8List>{};

  bool get isOwn => signingKeyPair != null;

  Map<String, dynamic> toJson() => {
        'ck': CryptoUtils.toHex(chainKey),
        'it': iteration,
        'spk': CryptoUtils.toHex(signingPublicKey),
        if (signingKeyPair != null)
          'ssk': CryptoUtils.toHex(signingKeyPair!.bytes),
        'skipped': skipped.entries
            .map((e) => [e.key, CryptoUtils.toHex(e.value)])
            .toList(),
      };

  factory SenderKeyState.fromJson(Map<String, dynamic> json) => parseOr(() {
        const ctx = 'sender key state';
        final spk = requireHex(json, 'spk',
            length: CryptoUtils.ed25519KeyLength, context: ctx);
        final ssk = optionalHex(json, 'ssk', length: 32, context: ctx);
        final skipped = <int, Uint8List>{};
        final rawSkipped = optionalList(json, 'skipped',
                maxLength: maxStoredSkipped, context: ctx) ??
            const <dynamic>[];
        for (final entry in rawSkipped) {
          if (entry is! List || entry.length != 2) {
            throw const FormatException('sender key state: bad skipped entry');
          }
          final it = entry[0];
          final mk = entry[1];
          if (it is! int || it < 0 || mk is! String) {
            throw const FormatException('sender key state: bad skipped entry');
          }
          skipped[it] = CryptoUtils.decodeKey(mk, 32, 'skipped message key');
        }
        return SenderKeyState(
          chainKey: requireHex(json, 'ck', length: 32, context: ctx),
          iteration: requireInt(json, 'it', min: 0, max: 1 << 30, context: ctx),
          signingPublicKey: spk,
          signingKeyPair: ssk == null
              ? null
              : CryptoUtils.ed25519KeyPairFromBytes(ssk, spk),
          skipped: skipped,
        );
      }, context: 'sender key state');
}

/// What a member sends to the others (inside a ratchet envelope).
class SenderKeyDistribution {
  final String groupId;
  final Uint8List chainKey;
  final int iteration;
  final Uint8List signingPublicKey;

  SenderKeyDistribution({
    required this.groupId,
    required this.chainKey,
    required this.iteration,
    required this.signingPublicKey,
  });

  Map<String, dynamic> toJson() => {
        'g': groupId,
        'ck': CryptoUtils.toHex(chainKey),
        'it': iteration,
        'spk': CryptoUtils.toHex(signingPublicKey),
      };

  factory SenderKeyDistribution.fromJson(Map<String, dynamic> json) =>
      parseOr(() {
        const ctx = 'sender key distribution';
        return SenderKeyDistribution(
          groupId: requireString(json, 'g',
              minLength: 1, maxLength: 64, context: ctx),
          chainKey: requireHex(json, 'ck', length: 32, context: ctx),
          iteration: requireInt(json, 'it', min: 0, max: 1 << 30, context: ctx),
          signingPublicKey: requireHex(json, 'spk',
              length: CryptoUtils.ed25519KeyLength, context: ctx),
        );
      }, context: 'sender key distribution');
}

class SenderKeyMessage {
  final int iteration;
  final Uint8List ciphertext;
  final Uint8List signature;
  SenderKeyMessage(this.iteration, this.ciphertext, this.signature);
}

class SenderKeyException implements Exception {
  final String message;
  SenderKeyException(this.message);
  @override
  String toString() => 'SenderKeyException: $message';
}

class SenderKeyManager {
  static const String _aeadInfo = 'NyxChat-SK-AEAD-v3';
  static const String _sigPrefix = 'NyxChat-SK-v3';

  /// Our own sender keys, by group id.
  final Map<String, SenderKeyState> _own = {};

  /// Other members' sender keys, by "groupId|senderId".
  final Map<String, SenderKeyState> _peers = {};

  static String _peerKey(String groupId, String senderId) =>
      '$groupId|$senderId';

  bool hasOwnKey(String groupId) => _own.containsKey(groupId);
  bool hasPeerKey(String groupId, String senderId) =>
      _peers.containsKey(_peerKey(groupId, senderId));

  /// Create (or return the existing) sender key for a group and produce
  /// the distribution message for other members.
  Future<SenderKeyDistribution> ownDistribution(String groupId) async {
    var state = _own[groupId];
    state ??= await _freshOwnState();
    _own[groupId] = state;
    return SenderKeyDistribution(
      groupId: groupId,
      chainKey: Uint8List.fromList(state.chainKey),
      iteration: state.iteration,
      signingPublicKey: state.signingPublicKey,
    );
  }

  /// Replace our sender key (membership changed). Returns the new
  /// distribution that must be sent to the remaining members.
  Future<SenderKeyDistribution> rotateOwn(String groupId) async {
    _own[groupId] = await _freshOwnState();
    return ownDistribution(groupId);
  }

  void forgetGroup(String groupId) {
    _own.remove(groupId);
    _peers.removeWhere((k, _) => k.startsWith('$groupId|'));
  }

  void forgetPeer(String groupId, String senderId) =>
      _peers.remove(_peerKey(groupId, senderId));

  void processDistribution(String senderId, SenderKeyDistribution dist) {
    _peers[_peerKey(dist.groupId, senderId)] = SenderKeyState(
      chainKey: Uint8List.fromList(dist.chainKey),
      iteration: dist.iteration,
      signingPublicKey: dist.signingPublicKey,
    );
  }

  Future<SenderKeyMessage> encrypt(
      String groupId, List<int> plaintext, List<int> associatedData) async {
    final state = _own[groupId];
    if (state == null) throw SenderKeyException('no sender key for $groupId');
    final step = await _kdfCk(state.chainKey);
    final iteration = state.iteration;
    final ct = await _aeadEncrypt(step.$2, plaintext, associatedData);
    final sig = await CryptoUtils.ed25519Sign(
        state.signingKeyPair!, _signedBytes(groupId, iteration, ct, associatedData));
    state.chainKey = step.$1;
    state.iteration = iteration + 1;
    CryptoUtils.wipe(step.$2);
    return SenderKeyMessage(iteration, ct, sig);
  }

  Future<Uint8List> decrypt({
    required String groupId,
    required String senderId,
    required SenderKeyMessage message,
    required List<int> associatedData,
  }) async {
    final state = _peers[_peerKey(groupId, senderId)];
    if (state == null) {
      throw SenderKeyException('no sender key for $senderId in $groupId');
    }
    final sigOk = await CryptoUtils.ed25519Verify(
      publicKey: state.signingPublicKey,
      message: _signedBytes(
          groupId, message.iteration, message.ciphertext, associatedData),
      signature: message.signature,
    );
    if (!sigOk) throw SenderKeyException('bad group message signature');

    // Old (skipped) iteration?
    final stored = state.skipped.remove(message.iteration);
    if (stored != null) {
      final plain = await _aeadDecrypt(stored, message.ciphertext, associatedData);
      CryptoUtils.wipe(stored);
      return plain;
    }
    if (message.iteration < state.iteration) {
      throw SenderKeyException('replayed or expired iteration');
    }
    if (message.iteration - state.iteration > SenderKeyState.maxSkip) {
      throw SenderKeyException('too many skipped group messages');
    }
    // Advance on a copy, commit after successful decryption.
    var chain = Uint8List.fromList(state.chainKey);
    final newSkipped = <int, Uint8List>{};
    var it = state.iteration;
    while (it < message.iteration) {
      final step = await _kdfCk(chain);
      newSkipped[it] = step.$2;
      chain = step.$1;
      it++;
    }
    final step = await _kdfCk(chain);
    final plain = await _aeadDecrypt(step.$2, message.ciphertext, associatedData);
    CryptoUtils.wipe(step.$2);
    state.skipped.addAll(newSkipped);
    while (state.skipped.length > SenderKeyState.maxStoredSkipped) {
      state.skipped.remove(state.skipped.keys.first);
    }
    state.chainKey = step.$1;
    state.iteration = it + 1;
    return plain;
  }

  // Persistence

  Map<String, dynamic> toJson() => {
        'own': _own.map((k, v) => MapEntry(k, v.toJson())),
        'peers': _peers.map((k, v) => MapEntry(k, v.toJson())),
      };

  void loadJson(Map<String, dynamic> json) {
    _own.clear();
    _peers.clear();
    (json['own'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
      _own[k] = SenderKeyState.fromJson(v as Map<String, dynamic>);
    });
    (json['peers'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
      _peers[k] = SenderKeyState.fromJson(v as Map<String, dynamic>);
    });
  }

  void clear() {
    _own.clear();
    _peers.clear();
  }

  // Internals

  static Future<SenderKeyState> _freshOwnState() async {
    final signing = await CryptoUtils.newEd25519KeyPair();
    return SenderKeyState(
      chainKey: CryptoUtils.randomBytes(32),
      iteration: 0,
      signingPublicKey: CryptoUtils.publicKeyBytes(signing),
      signingKeyPair: signing,
    );
  }

  static Uint8List _signedBytes(
          String groupId, int iteration, List<int> ct, List<int> ad) =>
      CryptoUtils.lengthPrefixed([
        _sigPrefix.codeUnits,
        utf8.encode(groupId),
        CryptoUtils.int32be(iteration),
        ct,
        ad,
      ]);

  static Future<(Uint8List, Uint8List)> _kdfCk(Uint8List ck) async {
    final mk = await CryptoUtils.hmacSha256(ck, const [0x01]);
    final next = await CryptoUtils.hmacSha256(ck, const [0x02]);
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
      Uint8List mk, List<int> ct, List<int> ad) async {
    final keys = await _aeadKeys(mk);
    try {
      return await CryptoUtils.aesGcmDecrypt(
          key: keys.$1, nonce: keys.$2, ciphertextWithTag: ct, aad: ad);
    } on SecretBoxAuthenticationError {
      throw SenderKeyException('group message authentication failed');
    }
  }
}