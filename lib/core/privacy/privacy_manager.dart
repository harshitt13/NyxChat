import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../storage/local_storage.dart';

/// Privacy manager for NyxChat.
///
/// Handles:
/// - Dummy traffic: periodic encrypted random packets
/// - Disappearing messages: auto-delete after configurable time
/// - Panic wipe: instant destruction of all data
/// - Anti-fingerprinting: random delays for mesh operations
class PrivacyManager extends ChangeNotifier {
  final LocalStorage _storage;
  final Random _random = Random.secure();

  // Dummy traffic
  bool _dummyTrafficEnabled = false;
  Timer? _dummyTimer;
  int _dummyPacketsSent = 0;

  // Disappearing messages
  Duration _defaultDisappearTime = Duration.zero; // 0 = disabled
  Timer? _cleanupTimer;

  // Stats
  bool get isDummyTrafficEnabled => _dummyTrafficEnabled;
  int get dummyPacketsSent => _dummyPacketsSent;
  Duration get defaultDisappearTime => _defaultDisappearTime;
  bool get isDisappearingEnabled => _defaultDisappearTime > Duration.zero;

  // Callbacks
  Function(Uint8List dummyData)? onDummyPacket;
  Function()? onPanicWipe;
  
  /// Called during panic wipe to clear crypto keys
  Future<void> Function()? onClearCryptoKeys;

  PrivacyManager({required LocalStorage storage}) : _storage = storage;

  /// Enable/disable dummy traffic generation.
  void setDummyTraffic(bool enabled) {
    _dummyTrafficEnabled = enabled;
    if (enabled) {
      _startDummyTraffic();
    } else {
      _dummyTimer?.cancel();
    }
    notifyListeners();
  }

  /// Set default disappearing message duration.
  void setDisappearTime(Duration duration) {
    _defaultDisappearTime = duration;
    
    // Start or stop the cleanup timer based on whether disappearing is enabled
    _cleanupTimer?.cancel();
    if (duration > Duration.zero) {
      _cleanupTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _cleanupExpiredMessages(),
      );
    }
    
    notifyListeners();
  }

  /// Remove messages that have exceeded their disappear time.
  Future<void> _cleanupExpiredMessages() async {
    // This is handled externally by the chat service checking shouldDelete()
    // The timer ensures periodic evaluation.
    notifyListeners();
  }

  /// Generate dummy traffic at random intervals.
  void _startDummyTraffic() {
    _dummyTimer?.cancel();
    _scheduleDummyPacket();
  }

  void _scheduleDummyPacket() {
    if (!_dummyTrafficEnabled) return;

    // Random interval: 30-120 seconds
    final delay = Duration(seconds: 30 + _random.nextInt(90));
    _dummyTimer = Timer(delay, () {
      _sendDummyPacket();
      _scheduleDummyPacket(); // Schedule next
    });
  }

  void _sendDummyPacket() {
    // Generate random bytes that are indistinguishable from real E2EE data
    final size = 64 + _random.nextInt(256); // 64-320 bytes
    final data = Uint8List(size);
    for (int i = 0; i < size; i++) {
      data[i] = _random.nextInt(256);
    }
    _dummyPacketsSent++;
    onDummyPacket?.call(data);
    notifyListeners();
  }

  /// PANIC WIPE: Destroy all data immediately.
  ///
  /// This is the nuclear option — irreversible.
  /// Destroys: all messages, identity keys, peer data, mesh store.
  Future<void> panicWipe() async {
    debugPrint('[Privacy] PANIC WIPE initiated');

    // Stop all timers
    _dummyTimer?.cancel();
    _cleanupTimer?.cancel();

    // Clear all storage
    try {
      await _storage.clearAll();
    } catch (e) {
      debugPrint('[Privacy] Storage clear error: $e');
    }

    // Clear cryptographic keys
    try {
      await onClearCryptoKeys?.call();
    } catch (e) {
      debugPrint('[Privacy] Crypto key clear error: $e');
    }

    // Notify callback for additional cleanup
    onPanicWipe?.call();

    _dummyTrafficEnabled = false;
    _defaultDisappearTime = Duration.zero;
    _dummyPacketsSent = 0;

    notifyListeners();
    debugPrint('[Privacy] PANIC WIPE complete');
  }

  /// Get a random anti-fingerprint delay (0-2 seconds).
  Duration getAntiTimingDelay() {
    return Duration(milliseconds: _random.nextInt(2000));
  }

  /// Check if a message should be auto-deleted.
  bool shouldDelete(DateTime sentTime) {
    if (_defaultDisappearTime <= Duration.zero) return false;
    return DateTime.now().difference(sentTime) > _defaultDisappearTime;
  }

  @override
  void dispose() {
    _dummyTimer?.cancel();
    _cleanupTimer?.cancel();
    super.dispose();
  }
}
