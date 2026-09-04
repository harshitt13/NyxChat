import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/generated/app_localizations.dart';

/// Manages the OS-level Foreground Service to keep the mesh network
/// alive when the app is swiped away or the device goes to sleep.
class BackgroundManager {
  static const String notificationChannelId = 'nyxchat_mesh_channel';
  static const int notificationId = 888;

  /// Language tag of the UI; handed to the service isolate so the
  /// foreground notification is shown in the same language.
  static String? languageTag;

  static Future<void> initialize({required AppLocalizations l10n}) async {
    final service = FlutterBackgroundService();

    // Prepare robust local notifications to satisfy foreground service requirements
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId, // id
      l10n.meshChannelName, // title
      description: l10n.meshChannelDescription,
      importance: Importance.high, 
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (defaultTargetPlatform == TargetPlatform.android) {
       await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // This makes it a sticky foreground service
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: l10n.appTitle,
        initialNotificationContent: l10n.meshNotificationInitial,
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<void> startService() async {
    final service = FlutterBackgroundService();
    await service.startService();
    final tag = languageTag;
    if (tag != null) setLocale(tag);
  }

  /// Switch the language of the running service's notification. A no-op
  /// where the plugin is unavailable (host tests, desktop).
  static void setLocale(String tag) {
    try {
      FlutterBackgroundService().invoke('setLocale', {'tag': tag});
    } catch (e) {
      debugPrint('[Background] setLocale: $e');
    }
  }

  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Strings for the service isolate: the tag sent by the app, else the
/// device language, else English.
AppLocalizations _serviceL10n(String? tag) {
  Locale locale = const Locale('en');
  try {
    locale = tag != null && tag.isNotEmpty
        ? Locale(tag.split('-').first)
        : PlatformDispatcher.instance.locale;
  } catch (_) {}
  return lookupAppLocalizations(
      basicLocaleListResolution([locale], AppLocalizations.supportedLocales));
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  var l10n = _serviceL10n(null);

  service.on('setLocale').listen((event) {
    l10n = _serviceL10n(event?['tag'] as String?);
  });

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Keep alive timer, OS expects the foreground service to be doing something
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        await service.setForegroundNotificationInfo(
          title: l10n.appTitle,
          content: l10n.meshNotificationActive,
        );
      }
    }
  });
}
