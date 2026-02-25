import 'package:flutter/foundation.dart';

/// Stealth mode for NyxChat.
///
/// Provides:
/// - Decoy PIN: alternate PIN shows fake empty app
/// - Quick hide: gesture to minimize instantly
/// - App disguise: can change app name/icon to generic (requires rebuild)
class StealthMode extends ChangeNotifier {
  bool _isEnabled = false;
  String? _duressPin;
  bool _isDuressMode = false;

  bool get isEnabled => _isEnabled;
  bool get isDuressMode => _isDuressMode;
  bool get hasDuressPin => _duressPin != null && _duressPin!.isNotEmpty;

  /// Enable/disable stealth mode.
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }

  /// Set the duress PIN. When entered instead of normal PIN,
  /// shows an empty/fake app state.
  void setDuressPin(String pin) {
    _duressPin = pin.isNotEmpty ? pin : null;
    notifyListeners();
  }

  /// Check if a given PIN is the duress PIN.
  bool isDuressPin(String pin) {
    if (_duressPin == null) return false;
    return pin == _duressPin;
  }

  /// Activate duress mode (shows fake empty state).
  void activateDuress() {
    _isDuressMode = true;
    notifyListeners();
    debugPrint('[Stealth] Duress mode ACTIVATED');
  }

  /// Deactivate duress mode.
  void deactivateDuress() {
    _isDuressMode = false;
    notifyListeners();
  }

  /// Clear stealth settings.
  void clear() {
    _isEnabled = false;
    _duressPin = null;
    _isDuressMode = false;
    notifyListeners();
  }
}
