import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Traffic-analysis countermeasures.
///
/// * Cover traffic: random-sized mesh packets to random addresses at
///   random intervals, so an observer cannot tell whether a device is
///   idle or chatting.
/// * Anti-timing jitter for forwarding decisions.
///
/// Message expiry (disappearing messages) and panic wipe live in
/// ChatService and AppServices respectively.
class PrivacyManager extends ChangeNotifier {
  final Random _random = Random.secure();

  bool _coverTrafficEnabled = false;
  Timer? _coverTimer;
  int _coverPacketsSent = 0;

  bool get isCoverTrafficEnabled => _coverTrafficEnabled;
  int get coverPacketsSent => _coverPacketsSent;

  /// Invoked with random bytes that should be sent as an opaque mesh
  /// packet to a random recipient hash.
  Future<void> Function(Uint8List payload)? onCoverPacket;

  void setCoverTraffic(bool enabled) {
    _coverTrafficEnabled = enabled;
    _coverTimer?.cancel();
    if (enabled) _scheduleNext();
    notifyListeners();
  }

  void _scheduleNext() {
    if (!_coverTrafficEnabled) return;
    final delay = Duration(seconds: 30 + _random.nextInt(90));
    _coverTimer = Timer(delay, () async {
      final size = 96 + _random.nextInt(320);
      final data = Uint8List(size);
      for (var i = 0; i < size; i++) {
        data[i] = _random.nextInt(256);
      }
      _coverPacketsSent++;
      try {
        await onCoverPacket?.call(data);
      } catch (e) {
        debugPrint('[Privacy] cover packet failed: $e');
      }
      notifyListeners();
      _scheduleNext();
    });
  }

  Duration antiTimingDelay() => Duration(milliseconds: _random.nextInt(2000));

  @override
  void dispose() {
    _coverTimer?.cancel();
    super.dispose();
  }
}