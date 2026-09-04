import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart bridge to the native BLE peripheral (GATT server + advertiser).
/// See android/app/src/main/kotlin/com/nyxchat/nyxchat/BlePeripheral.kt.
class BlePeripheral {
  static const MethodChannel _method = MethodChannel('nyxchat/ble_peripheral');
  static const EventChannel _events =
      EventChannel('nyxchat/ble_peripheral/events');

  StreamSubscription? _sub;
  bool _advertising = false;

  /// A central wrote bytes to our TX characteristic.
  void Function(String address, Uint8List data)? onWrite;

  /// A central subscribed to notifications (it can now receive from us).
  void Function(String address)? onSubscribed;
  void Function(String address)? onDisconnected;
  void Function(String address, int mtu)? onMtu;

  bool get isAdvertising => _advertising;

  Future<bool> isSupported() async {
    try {
      return await _method.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> start(String nyxId) async {
    _sub ??= _events.receiveBroadcastStream().listen(_onEvent, onError: (e) {
      debugPrint('[BLE-P] event error: $e');
    });
    try {
      final ok =
          await _method.invokeMethod<bool>('start', {'nyxId': nyxId}) ?? false;
      _advertising = ok;
      return ok;
    } catch (e) {
      debugPrint('[BLE-P] start failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _method.invokeMethod('stop');
    } catch (_) {}
    _advertising = false;
    await _sub?.cancel();
    _sub = null;
  }

  /// Push bytes to a subscribed central via the RX characteristic.
  Future<bool> notify(String address, Uint8List data) async {
    try {
      return await _method.invokeMethod<bool>(
              'notify', {'address': address, 'data': data}) ??
          false;
    } catch (e) {
      debugPrint('[BLE-P] notify failed: $e');
      return false;
    }
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    final address = event['address'] as String? ?? '';
    switch (type) {
      case 'write':
        final data = event['data'];
        if (data is Uint8List) onWrite?.call(address, data);
        break;
      case 'subscribed':
        onSubscribed?.call(address);
        break;
      case 'disconnected':
      case 'unsubscribed':
        onDisconnected?.call(address);
        break;
      case 'mtu':
        final data = event['data'];
        if (data is Uint8List && data.length >= 2) {
          onMtu?.call(address, (data[0] << 8) | data[1]);
        }
        break;
      case 'advertiseFailed':
        _advertising = false;
        debugPrint('[BLE-P] advertising failed: $address');
        break;
      case 'advertising':
        _advertising = true;
        break;
    }
  }
}