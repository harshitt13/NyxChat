// Boots the real service graph (like screens_smoke_test.dart) and pumps the
// app in LIGHT mode with the ARABIC (right-to-left) locale: the chat list and
// Settings must build without exceptions, resolve the light palette, mirror
// the layout and show translated strings. Also covers persistence of the
// appearance settings and display-time localisation of system messages.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/l10n/generated/app_localizations.dart';
import 'package:nyxchat/l10n/system_messages.dart';
import 'package:nyxchat/main.dart';
import 'package:nyxchat/screens/chat_list_screen.dart';
import 'package:nyxchat/screens/settings_screen.dart';
import 'package:nyxchat/services/settings_service.dart';
import 'package:nyxchat/theme/app_theme.dart';

const _stubbedChannels = [
  'nyxchat/window',
  'nyxchat/ble_peripheral',
  'nyxchat/location',
  'dexterous.com/flutter/local_notifications',
  'flutter_blue_plus/methods',
  'nearby_connections',
  'fr.skyost.bonsoir',
  'flutter.baseflow.com/permissions/methods',
  'plugins.flutter.io/path_provider',
  'id.flutter/background_service',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in _stubbedChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (call.method == 'initialize') return true;
        return null;
      });
    }
    tmp = Directory.systemTemp.createTempSync('nyx_theme_locale');
    services = AppServices(port: 0); // ephemeral: runs alongside the smoke test
    await services.storage.init(directory: tmp.path);
    await services.appLock.init();
    await services.identity.init();
    if (!services.identity.hasIdentity) {
      await services.identity.generateIdentity('Tester');
    }
    await services.bringUp();
    expect(services.ready, isTrue);
    // Real timers must be created outside the widget test's fake clock.
    await services.peers.startNetwork(
        nyxChatId: services.identity.nyxChatId,
        displayName: services.identity.displayName);
  });

  tearDownAll(() async {
    try {
      await services.peers.stopNetwork();
    } catch (_) {}
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('light theme + Arabic: chat list and Settings render mirrored',
      (tester) async {
    await services.settings.setThemeMode(ThemeMode.light);
    await services.settings.setLocale(const Locale('ar'));

    await tester.pumpWidget(const NyxChatApp());
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(ChatListScreen), findsOneWidget);

    final ctx = tester.element(find.byType(ChatListScreen));
    expect(Theme.of(ctx).brightness, Brightness.light);
    expect(ctx.nyx.isDark, isFalse);
    expect(Directionality.of(ctx), TextDirection.rtl);
    final l = AppLocalizations.of(ctx);
    expect(l.localeName, 'ar');
    expect(find.text(l.noConversationsYet), findsOneWidget);
    expect(find.text('No conversations yet'), findsNothing);

    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
        nav.push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())));
    await settle(tester);
    expect(tester.takeException(), isNull,
        reason: 'SettingsScreen threw in light/ar');
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text(l.settings), findsOneWidget);
    expect(find.text(l.appearance.toUpperCase()), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget); // language row shows the native name

    // Switching back to dark + system language from the running app.
    await services.settings.setThemeMode(ThemeMode.dark);
    await services.settings.setLocale(null);
    await settle(tester);
    expect(tester.takeException(), isNull);
    final ctx2 = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(ctx2).brightness, Brightness.dark);
    expect(Directionality.of(ctx2), TextDirection.ltr);
    nav.pop();
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  test('theme mode and language persist across a restart', () async {
    await services.settings.setThemeMode(ThemeMode.light);
    await services.settings.setLocale(const Locale('hi'));
    final fresh = SettingsService(services.storage);
    await fresh.loadAppearance();
    expect(fresh.themeMode, ThemeMode.light);
    expect(fresh.locale, const Locale('hi'));
    await services.settings.resetAppearance();
    await fresh.loadAppearance();
    expect(fresh.themeMode, ThemeMode.dark);
    expect(fresh.locale, isNull);
  });

  test('stored English system messages are shown in the UI language', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(localizeSystemMessage(fr, 'Member removed'), fr.sysMemberRemoved);
    expect(localizeSystemMessage(fr, 'Group "Crew" created'),
        fr.sysGroupCreated('Crew'));
    expect(localizeSystemMessage(fr, 'You were added to "Crew" by Ana'),
        fr.sysAddedToGroupBy('Crew', 'Ana'));
    expect(localizeSystemMessage(fr, 'Ana renamed the group to "Team"'),
        fr.sysRenamedGroup('Ana', 'Team'));
    expect(localizeSystemMessage(fr, 'Ana, Bo added'),
        fr.sysMembersAdded('Ana, Bo'));
    expect(localizeSystemMessage(fr, 'hello there'), 'hello there');
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      expect(l.membersCount(2), isNotEmpty, reason: locale.toString());
      expect(l.safetyNumberChangedBody('A', 'B'), contains('A'));
    }
  });
}