import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../crypto/crypto_utils.dart';
import '../crypto/pair_keys.dart';

/// A message on the local emergency channel. Anonymous unless the sender
/// chooses to include a name or position.
class EmergencyMessage {
  final String id;
  final String geohash;
  final String text;
  final DateTime timestamp;
  final String? displayName;
  final double? lat;
  final double? lon;

  EmergencyMessage({
    required this.id,
    required this.geohash,
    required this.text,
    required this.timestamp,
    this.displayName,
    this.lat,
    this.lon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'g': geohash,
        't': text,
        'ts': timestamp.toUtc().toIso8601String(),
        'n': ?displayName,
        'lat': ?lat,
        'lon': ?lon,
      };

  factory EmergencyMessage.fromJson(Map<String, dynamic> j) {
    final text = j['t'];
    if (text is! String || text.isEmpty || text.length > 2000) {
      throw const FormatException('bad emergency text');
    }
    return EmergencyMessage(
      id: j['id'] as String,
      geohash: j['g'] as String,
      text: text,
      timestamp: DateTime.parse(j['ts'] as String),
      displayName: j['n'] as String?,
      lat: (j['lat'] as num?)?.toDouble(),
      lon: (j['lon'] as num?)?.toDouble(),
    );
  }
}

/// Location-scoped broadcast channel.
///
/// Everyone in the same geohash cell derives the same key from the cell
/// name; the device's coordinates are only used locally to compute the
/// cell. Packets are addressed to a rotating channel token so relays
/// cannot tell which cell a packet belongs to, and payloads are
/// AES-256-GCM sealed under the channel key.
///
/// Precision: 4 chars ~ 40 km, 5 chars ~ 5 km, 6 chars ~ 1 km.
class GeohashChannel {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  static const int defaultPrecision = 5;

  final String geohash;
  final Uint8List _key;

  GeohashChannel._(this.geohash, this._key);

  static Future<GeohashChannel> open(String geohash) async {
    final cell = geohash.toLowerCase().trim();
    if (cell.length < 3 || cell.length > 8 || !cell.split('').every(_base32.contains)) {
      throw const FormatException('invalid geohash');
    }
    final key = await CryptoUtils.hkdf(
      ikm: utf8.encode('NyxChat-Geo-v4|$cell'),
      salt: Uint8List(32),
      info: 'NyxChat-Geo-Key-v4',
    );
    return GeohashChannel._(cell, key);
  }

  /// Rotating mesh address for this cell.
  Future<Uint8List> token(int epoch) async {
    final mac = await CryptoUtils.hmacSha256(
        _key, CryptoUtils.lengthPrefixed(['geo'.codeUnits, CryptoUtils.int64be(epoch)]));
    return mac.sublist(0, 16);
  }

  static int currentEpoch() => PairKeys.meshEpoch();

  Future<Uint8List> seal(EmergencyMessage m) async {
    final nonce = CryptoUtils.randomBytes(12);
    final ct = await CryptoUtils.aesGcmEncrypt(
        key: _key, nonce: nonce, plaintext: utf8.encode(jsonEncode(m.toJson())), aad: 'geo'.codeUnits);
    return CryptoUtils.concat([nonce, ct]);
  }

  Future<EmergencyMessage?> unseal(List<int> blob) async {
    if (blob.length < 12 + 16) return null;
    try {
      final plain = await CryptoUtils.aesGcmDecrypt(
          key: _key, nonce: blob.sublist(0, 12), ciphertextWithTag: blob.sublist(12), aad: 'geo'.codeUnits);
      final m = EmergencyMessage.fromJson(jsonDecode(utf8.decode(plain)) as Map<String, dynamic>);
      return m.geohash == geohash ? m : null;
    } on SecretBoxAuthenticationError {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Encode latitude/longitude into a geohash of [precision] characters.
  static String encode(double lat, double lon, [int precision = defaultPrecision]) {
    double minLat = -90, maxLat = 90, minLon = -180, maxLon = 180;
    var isLon = true;
    var bit = 0;
    var ch = 0;
    final out = StringBuffer();
    while (out.length < precision) {
      if (isLon) {
        final mid = (minLon + maxLon) / 2;
        if (lon >= mid) {
          ch |= 1 << (4 - bit);
          minLon = mid;
        } else {
          maxLon = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat >= mid) {
          ch |= 1 << (4 - bit);
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }
      isLon = !isLon;
      if (++bit == 5) {
        out.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }
    return out.toString();
  }

  static String approximateArea(int precision) => switch (precision) {
        <= 3 => '~150 km',
        4 => '~40 km',
        5 => '~5 km',
        6 => '~1 km',
        _ => '~150 m',
      };
}