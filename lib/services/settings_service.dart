import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/storage/local_storage.dart';

/// User preferences stored in the encrypted user box.
///
/// Appearance (theme mode and language) is kept in the platform secure
/// storage instead, because it must be known before the database is
/// unlocked (the lock screen is themed and localised too).
class SettingsService extends ChangeNotifier {
  static const MethodChannel _window = MethodChannel('nyxchat/window');
  static const String _kThemeMode = 'appearance_theme_mode';
  static const String _kLocale = 'appearance_locale';

  final LocalStorage _storage;
  final FlutterSecureStorage _secure;
  bool _blockScreenshots = true;
  bool _readReceipts = true;
  bool _notifications = true;
  bool _notificationPreview = false;
  bool _lockOnBackground = true;
  bool _dummyTraffic = false;
  bool _longRangeBle = false;
  bool _discoverableToEveryone = true;
  bool _nostrEnabled = false;
  bool _nostrViaTor = false;
  int _defaultDisappearSeconds = 0;
  ThemeMode _themeMode = ThemeMode.dark;
  Locale? _locale;

  SettingsService(this._storage, {FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  bool get blockScreenshots => _blockScreenshots;
  bool get readReceipts => _readReceipts;
  bool get notifications => _notifications;
  bool get notificationPreview => _notificationPreview;
  bool get lockOnBackground => _lockOnBackground;
  bool get dummyTraffic => _dummyTraffic;
  bool get longRangeBle => _longRangeBle;
  bool get discoverableToEveryone => _discoverableToEveryone;
  bool get nostrEnabled => _nostrEnabled;
  bool get nostrViaTor => _nostrViaTor;
  int get defaultDisappearSeconds => _defaultDisappearSeconds;

  /// Light, dark or follow the system. Defaults to dark.
  ThemeMode get themeMode => _themeMode;

  /// Chosen UI language, or null to follow the system locale.
  Locale? get locale => _locale;

  Future<void> load() async {
    _blockScreenshots = _storage.getSetting('blockScreenshots') != 'false';
    _readReceipts = _storage.getSetting('readReceipts') != 'false';
    _notifications = _storage.getSetting('notifications') != 'false';
    _notificationPreview = _storage.getSetting('notificationPreview') == 'true';
    _lockOnBackground = _storage.getSetting('lockOnBackground') != 'false';
    _dummyTraffic = _storage.getSetting('dummyTraffic') == 'true';
    _longRangeBle = _storage.getSetting('longRangeBle') == 'true';
    _discoverableToEveryone = _storage.getSetting('discoverable') != 'false';
    _nostrEnabled = _storage.getSetting('nostrEnabled') == 'true';
    _nostrViaTor = _storage.getSetting('nostrViaTor') == 'true';
    _defaultDisappearSeconds =
        int.tryParse(_storage.getSetting('defaultDisappear') ?? '0') ?? 0;
    await loadAppearance(notify: false);
    notifyListeners();
  }

  /// Load theme mode and language. Safe to call before the database is
  /// open; called again by [load].
  Future<void> loadAppearance({bool notify = true}) async {
    try {
      _themeMode = _parseThemeMode(await _secure.read(key: _kThemeMode));
      _locale = _parseLocale(await _secure.read(key: _kLocale));
    } catch (e) {
      debugPrint('[Settings] appearance: $e');
    }
    if (notify) notifyListeners();
  }

  static ThemeMode _parseThemeMode(String? v) => switch (v) {
        'system' => ThemeMode.system,
        'light' => ThemeMode.light,
        _ => ThemeMode.dark,
      };

  static Locale? _parseLocale(String? tag) {
    if (tag == null || tag.isEmpty) return null;
    final parts = tag.split('-');
    return parts.length > 1
        ? Locale.fromSubtags(languageCode: parts[0], countryCode: parts.last)
        : Locale(parts[0]);
  }

  Future<void> applyWindowSecurity() async {
    try {
      await _window.invokeMethod('setSecure', {'secure': _blockScreenshots});
    } catch (e) {
      debugPrint('[Settings] window flag: $e');
    }
  }

  Future<void> _set(String key, String value) => _storage.putSetting(key, value);

  Future<void> setBlockScreenshots(bool v) async {
    _blockScreenshots = v;
    await _set('blockScreenshots', '$v');
    await applyWindowSecurity();
    notifyListeners();
  }

  Future<void> setReadReceipts(bool v) async {
    _readReceipts = v;
    await _set('readReceipts', '$v');
    notifyListeners();
  }

  Future<void> setNotifications(bool v) async {
    _notifications = v;
    await _set('notifications', '$v');
    notifyListeners();
  }

  Future<void> setNotificationPreview(bool v) async {
    _notificationPreview = v;
    await _set('notificationPreview', '$v');
    notifyListeners();
  }

  Future<void> setLockOnBackground(bool v) async {
    _lockOnBackground = v;
    await _set('lockOnBackground', '$v');
    notifyListeners();
  }

  Future<void> setDummyTraffic(bool v) async {
    _dummyTraffic = v;
    await _set('dummyTraffic', '$v');
    notifyListeners();
  }

  Future<void> setLongRangeBle(bool v) async {
    _longRangeBle = v;
    await _set('longRangeBle', '$v');
    notifyListeners();
  }

  Future<void> setDiscoverableToEveryone(bool v) async {
    _discoverableToEveryone = v;
    await _set('discoverable', '$v');
    notifyListeners();
  }

  Future<void> setNostrEnabled(bool v) async {
    _nostrEnabled = v;
    await _set('nostrEnabled', '$v');
    notifyListeners();
  }

  Future<void> setNostrViaTor(bool v) async {
    _nostrViaTor = v;
    await _set('nostrViaTor', '$v');
    notifyListeners();
  }

  Future<void> setDefaultDisappear(int seconds) async {
    _defaultDisappearSeconds = seconds;
    await _set('defaultDisappear', '$seconds');
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _secure.write(key: _kThemeMode, value: mode.name);
    notifyListeners();
  }

  /// Pass null to follow the system locale.
  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    if (locale == null) {
      await _secure.delete(key: _kLocale);
    } else {
      await _secure.write(key: _kLocale, value: locale.toLanguageTag());
    }
    notifyListeners();
  }

  /// Back to the defaults (dark theme, system language); used by the
  /// panic wipe so a wiped device looks like a fresh install.
  Future<void> resetAppearance() async {
    _themeMode = ThemeMode.dark;
    _locale = null;
    await _secure.delete(key: _kThemeMode);
    await _secure.delete(key: _kLocale);
    notifyListeners();
  }
}