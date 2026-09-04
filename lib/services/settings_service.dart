import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/storage/local_storage.dart';

/// User preferences stored in the encrypted user box.
class SettingsService extends ChangeNotifier {
  static const MethodChannel _window = MethodChannel('nyxchat/window');

  final LocalStorage _storage;
  bool _blockScreenshots = true;
  bool _readReceipts = true;
  bool _notifications = true;
  bool _notificationPreview = false;
  bool _lockOnBackground = true;
  bool _dummyTraffic = false;
  bool _longRangeBle = false;
  bool _wifiAware = true;
  bool _discoverableToEveryone = true;
  bool _nostrEnabled = false;
  bool _nostrViaTor = false;
  int _defaultDisappearSeconds = 0;

  SettingsService(this._storage);

  bool get blockScreenshots => _blockScreenshots;
  bool get readReceipts => _readReceipts;
  bool get notifications => _notifications;
  bool get notificationPreview => _notificationPreview;
  bool get lockOnBackground => _lockOnBackground;
  bool get dummyTraffic => _dummyTraffic;
  bool get longRangeBle => _longRangeBle;
  bool get wifiAware => _wifiAware;
  bool get discoverableToEveryone => _discoverableToEveryone;
  bool get nostrEnabled => _nostrEnabled;
  bool get nostrViaTor => _nostrViaTor;
  int get defaultDisappearSeconds => _defaultDisappearSeconds;

  Future<void> load() async {
    _blockScreenshots = _storage.getSetting('blockScreenshots') != 'false';
    _readReceipts = _storage.getSetting('readReceipts') != 'false';
    _notifications = _storage.getSetting('notifications') != 'false';
    _notificationPreview = _storage.getSetting('notificationPreview') == 'true';
    _lockOnBackground = _storage.getSetting('lockOnBackground') != 'false';
    _dummyTraffic = _storage.getSetting('dummyTraffic') == 'true';
    _longRangeBle = _storage.getSetting('longRangeBle') == 'true';
    _wifiAware = _storage.getSetting('wifiAware') != 'false';
    _discoverableToEveryone = _storage.getSetting('discoverable') != 'false';
    _nostrEnabled = _storage.getSetting('nostrEnabled') == 'true';
    _nostrViaTor = _storage.getSetting('nostrViaTor') == 'true';
    _defaultDisappearSeconds =
        int.tryParse(_storage.getSetting('defaultDisappear') ?? '0') ?? 0;
    notifyListeners();
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

  Future<void> setWifiAware(bool v) async {
    _wifiAware = v;
    await _set('wifiAware', '$v');
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
}