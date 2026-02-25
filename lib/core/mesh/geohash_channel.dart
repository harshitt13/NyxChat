import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';

/// Geohash-based anonymous local channels.
///
/// Computes a geohash from device coordinates (locally only, never
/// transmitted). Users in the same geohash cell share a channel key
/// derived from the geohash prefix.
///
/// Precision levels:
/// - 4 chars → ~40km² area
/// - 5 chars → ~5km² area
/// - 6 chars → ~1km² area
class GeohashChannel extends ChangeNotifier {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  String? _currentGeohash;
  int _precision = 5; // Default: ~5km²
  Uint8List? _channelKey;
  final List<GeohashMessage> _messages = [];

  String? get currentGeohash => _currentGeohash;
  int get precision => _precision;
  bool get isActive => _currentGeohash != null;
  List<GeohashMessage> get messages => List.unmodifiable(_messages);

  /// Set precision level.
  void setPrecision(int chars) {
    _precision = chars.clamp(3, 8);
    if (_currentGeohash != null) {
      _currentGeohash = _currentGeohash!.substring(
          0, _precision.clamp(0, _currentGeohash!.length));
      _deriveChannelKey();
    }
    notifyListeners();
  }

  /// Update position and compute geohash.
  /// Location is processed locally and never transmitted.
  Future<void> updatePosition(double lat, double lon) async {
    _currentGeohash = encode(lat, lon, _precision);
    await _deriveChannelKey();
    notifyListeners();
    debugPrint('[Geohash] Position updated: $_currentGeohash');
  }

  /// Derive an AES encryption key from the geohash prefix.
  Future<void> _deriveChannelKey() async {
    if (_currentGeohash == null) return;
    final hash = await Sha256().hash(
        utf8.encode('nyxchat-geo-${_currentGeohash!}'));
    _channelKey = Uint8List.fromList(hash.bytes);
  }

  /// Get the channel key for encrypting/decrypting channel messages.
  Uint8List? get channelKey => _channelKey;

  /// Add a message to the local channel view.
  void addMessage(GeohashMessage msg) {
    _messages.add(msg);
    // Keep last 200 messages
    if (_messages.length > 200) {
      _messages.removeRange(0, _messages.length - 200);
    }
    notifyListeners();
  }

  /// Encode latitude/longitude into geohash string.
  static String encode(double lat, double lon, int precision) {
    double minLat = -90, maxLat = 90;
    double minLon = -180, maxLon = 180;
    bool isLon = true;
    int bit = 0;
    int ch = 0;
    final result = StringBuffer();

    while (result.length < precision) {
      if (isLon) {
        final mid = (minLon + maxLon) / 2;
        if (lon >= mid) {
          ch |= (1 << (4 - bit));
          minLon = mid;
        } else {
          maxLon = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat >= mid) {
          ch |= (1 << (4 - bit));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }

      isLon = !isLon;
      bit++;

      if (bit == 5) {
        result.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return result.toString();
  }

  /// Clear all channel data.
  void clear() {
    _messages.clear();
    _currentGeohash = null;
    _channelKey = null;
    notifyListeners();
  }
}

/// A message in a geohash channel (anonymous).
class GeohashMessage {
  final String id;
  final String senderHash; // Anonymous hash, not plaintext
  final String content;    // Decrypted text
  final DateTime timestamp;

  GeohashMessage({
    required this.id,
    required this.senderHash,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderHash': senderHash,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory GeohashMessage.fromJson(Map<String, dynamic> json) => GeohashMessage(
    id: json['id'] as String,
    senderHash: json['senderHash'] as String,
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
