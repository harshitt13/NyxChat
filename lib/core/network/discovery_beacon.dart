import 'dart:convert';
import 'dart:typed_data';

import '../crypto/crypto_utils.dart';
import '../crypto/pair_keys.dart';

/// What a device announces about itself over BLE scan responses and mDNS
/// TXT records.
///
/// * public mode: the NyxChat handle in the clear (anyone nearby can find
///   and address you; needed to meet new people)
/// * private mode: a Bloom filter of per-contact presence tokens for the
///   current 15-minute slot. Only a pinned contact can compute the token
///   it expects and test the filter; everyone else sees random bits that
///   change every slot.
class DiscoveryBeacon {
  static const int version = 4;
  static const int modePublic = 1;
  static const int modePrivate = 2;
  static const int bleBloomBits = 128; // 16 bytes, fits a 31-byte scan response
  static const int mdnsBloomBits = 512; // 64 bytes in a TXT record
  static const int hashes = 3;

  final int mode;
  final String? nyxId;
  final Uint8List? bloom;
  final int slot;

  DiscoveryBeacon._({required this.mode, this.nyxId, this.bloom, required this.slot});

  bool get isPublic => mode == modePublic;

  factory DiscoveryBeacon.public(String nyxId, {int? slot}) => DiscoveryBeacon._(
      mode: modePublic, nyxId: nyxId, slot: slot ?? PairKeys.discoverySlot());

  factory DiscoveryBeacon.private(Uint8List bloom, {int? slot}) => DiscoveryBeacon._(
      mode: modePrivate, bloom: bloom, slot: slot ?? PairKeys.discoverySlot());

  // Bloom filter

  static Uint8List buildBloom(Iterable<Uint8List> tokens, {int bits = bleBloomBits}) {
    final filter = Uint8List(bits ~/ 8);
    for (final t in tokens) {
      for (final pos in _positions(t, bits)) {
        filter[pos >> 3] |= 1 << (pos & 7);
      }
    }
    return filter;
  }

  static bool bloomContains(Uint8List filter, Uint8List token) {
    final bits = filter.length * 8;
    for (final pos in _positions(token, bits)) {
      if (filter[pos >> 3] & (1 << (pos & 7)) == 0) return false;
    }
    return true;
  }

  /// Tokens are already pseudo-random: read [hashes] 16-bit positions.
  static List<int> _positions(Uint8List token, int bits) {
    final out = <int>[];
    for (var i = 0; i < hashes; i++) {
      final v = (token[(2 * i) % token.length] << 8) | token[(2 * i + 1) % token.length];
      out.add(v % bits);
    }
    return out;
  }

  // BLE scan-response manufacturer data (max 24 bytes after the company id)

  Uint8List encodeBle() {
    if (isPublic) {
      final id = utf8.encode(nyxId!);
      return Uint8List.fromList([version, modePublic, ...id.take(22)]);
    }
    return Uint8List.fromList([version, modePrivate, slot & 0xff, ...bloom!.take(16)]);
  }

  static DiscoveryBeacon? decodeBle(List<int> data) {
    if (data.length < 3 || data[0] != version) {
      // Legacy v3 beacons carried the raw id; accept them as public.
      if (data.isNotEmpty && data[0] == 0x4E) {
        try {
          return DiscoveryBeacon.public(utf8.decode(data));
        } catch (_) {
          return null;
        }
      }
      return null;
    }
    if (data[1] == modePublic) {
      try {
        final id = utf8.decode(data.sublist(2));
        if (id.isEmpty || id.length > 32) return null;
        return DiscoveryBeacon.public(id);
      } catch (_) {
        return null;
      }
    }
    if (data[1] == modePrivate && data.length >= 3 + 16) {
      return DiscoveryBeacon.private(
        Uint8List.fromList(data.sublist(3, 19)),
        slot: _slotFromLowByte(data[2]),
      );
    }
    return null;
  }

  /// The beacon carries only the low byte of the slot; reconstruct the
  /// nearest full slot to now.
  static int _slotFromLowByte(int low) {
    final now = PairKeys.discoverySlot();
    for (final candidate in [now, now - 1, now + 1]) {
      if (candidate & 0xff == low) return candidate;
    }
    return now;
  }

  // mDNS TXT attributes

  Map<String, String> toTxt({String? displayName}) => isPublic
      ? {
          'v': '$version',
          'm': 'public',
          'id': nyxId!,
          'name': ?displayName,
        }
      : {
          'v': '$version',
          'm': 'private',
          's': '$slot',
          'b': CryptoUtils.toHex(bloom!),
        };

  static DiscoveryBeacon? fromTxt(Map<String, String?> txt) {
    final v = txt['v'];
    if (v == null) {
      // v3 records: nyxChatId/displayName in the clear
      final id = txt['nyxChatId'];
      return id == null ? null : DiscoveryBeacon.public(id);
    }
    if (txt['m'] == 'public' && txt['id'] != null) {
      return DiscoveryBeacon.public(txt['id']!);
    }
    if (txt['m'] == 'private' && txt['b'] != null) {
      try {
        return DiscoveryBeacon.private(
          CryptoUtils.fromHex(txt['b']!),
          slot: int.tryParse(txt['s'] ?? '') ?? PairKeys.discoverySlot(),
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

/// Builds our beacons and recognises contacts' private beacons.
class DiscoveryMatcher {
  final String myId;
  final PairKeyCache pairKeys;

  DiscoveryMatcher({required this.myId, required this.pairKeys});

  /// Bloom filter of the tokens each pinned contact expects from us now.
  Future<Uint8List> buildPrivateBloom({int bits = DiscoveryBeacon.bleBloomBits, int? slot}) async {
    final s = slot ?? PairKeys.discoverySlot();
    final tokens = <Uint8List>[];
    for (final pk in await pairKeys.all()) {
      tokens.add(await pk.discoveryToken(s, myId));
    }
    return DiscoveryBeacon.buildBloom(tokens, bits: bits);
  }

  /// Contacts whose presence token for [slot] (or the adjacent slots) is in
  /// the filter. False positives are possible and harmless: the handshake
  /// decides.
  Future<List<String>> match(Uint8List bloom, int slot) async {
    final out = <String>[];
    for (final pk in await pairKeys.all()) {
      for (final s in [slot, slot - 1, slot + 1]) {
        final token = await pk.discoveryToken(s, pk.peerId);
        if (DiscoveryBeacon.bloomContains(bloom, token)) {
          out.add(pk.peerId);
          break;
        }
      }
    }
    return out;
  }
}