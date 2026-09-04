import 'package:flutter/services.dart';

/// Last-known device position via a tiny platform channel (no plugin).
class DevicePosition {
  final double lat;
  final double lon;
  final double accuracyMeters;
  final Duration age;
  DevicePosition(this.lat, this.lon, this.accuracyMeters, this.age);
}

class LocationChannel {
  static const MethodChannel _channel = MethodChannel('nyxchat/location');

  static Future<DevicePosition?> lastKnown() async {
    try {
      final m = await _channel.invokeMethod<Map>('lastKnown');
      if (m == null) return null;
      return DevicePosition(
        (m['lat'] as num).toDouble(),
        (m['lon'] as num).toDouble(),
        (m['accuracy'] as num?)?.toDouble() ?? 0,
        Duration(milliseconds: (m['ageMs'] as num?)?.toInt() ?? 0),
      );
    } catch (_) {
      return null;
    }
  }
}