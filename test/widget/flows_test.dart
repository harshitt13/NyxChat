// Drives the main user flows on the real service graph: sending a text,
// toggling every setting, creating a group and joining an emergency
// channel. Complements screens_smoke_test.dart, which only opens screens.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/key_manager.dart';
import 'package:nyxchat/core/crypto/nyx_id.dart';
import 'package:nyxchat/main.dart';
import 'package:nyxchat/screens/chat_list_screen.dart';
import 'package:nyxchat/screens/chat_screen.dart';
import 'package:nyxchat/screens/create_group_screen.dart';
import 'package:nyxchat/screens/emergency_screen.dart';
import 'package:nyxchat/screens/settings_screen.dart';

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
  late String peerId;
  late String directRoomId;

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
    tmp = Directory.systemTemp.createTempSync('nyx_flows');
    services = AppServices();
    await services.storage.init(directory: tmp.path);
    await services.appLock.init();
    await services.identity.init();
    if (!services.identity.hasIdentity) {
      await services.identity.generateIdentity('Tester');
    }
    await services.bringUp();
    await services.peers.startNetwork(
        nyxChatId: services.identity.nyxChatId,
        displayName: services.identity.displayName);
    final other = await KeyManager.generateEphemeral();
    peerId = await NyxId.derive(
        signingPublicKey: other.signingPublicKey,
        identityPublicKey: other.identityPublicKey);
    await services.trust.pinFromContactCard({
      'nyx': 3,
      'id': peerId,
      'name': 'Peer',
      'ik': other.identityPublicKeyHex,
      'sk': other.signingPublicKeyHex,
      'kpk': other.kyberPublicKeyHex,
    });
    directRoomId = (await services.chat
            .getOrCreateDirectRoom(peerId: peerId, displayName: 'Peer'))
        .id;
  });

  tearDownAll(() async {
    try {
      await services.peers.stopNetwork();
    } catch (_) {}
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> settle(WidgetTester tester, [int rounds = 3]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 350));
    }
  }

  NavigatorState nav(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator).first);

  Future<void> push(WidgetTester tester, Widget screen) async {
    unawaited(nav(tester).push(MaterialPageRoute<void>(builder: (_) => screen)));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: '${screen.runtimeType} threw');
  }

  Future<void> pop(WidgetTester tester) async {
    nav(tester).pop();
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  testWidgets('send a text message from the chat screen', (tester) async {
    await tester.pumpWidget(const NyxChatApp());
    await settle(tester);
    expect(find.byType(ChatListScreen), findsOneWidget);
    await push(tester, ChatScreen(roomId: directRoomId));
    final inChat = find.byType(ChatScreen);
    // Sending writes to Hive (real disk I/O), which never completes under
    // the fake clock: drive this part with real async.
    await tester.runAsync(() async {
      await tester.enterText(
          find.descendant(of: inChat, matching: find.byType(TextField)),
          'hello flows');
      await tester.pump();
      await tester.tap(find.descendant(
          of: inChat, matching: find.byIcon(Icons.arrow_upward_rounded)));
      bool stored() => services.chat
          .getMessages(directRoomId)
          .any((m) => m.content == 'hello flows');
      for (var i = 0; i < 200 && !stored(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        await tester.pump();
      }
      expect(stored(), isTrue, reason: 'sendText must store the message');
      await tester.pump();
    });
    expect(tester.takeException(), isNull);
    expect(find.text('hello flows'), findsOneWidget,
        reason: 'the sent message must appear in the list');
    await pop(tester);
  });

  testWidgets('every settings switch toggles without throwing', (tester) async {
    await tester.pumpWidget(const NyxChatApp());
    await settle(tester);
    await push(tester, const SettingsScreen());
    final count = tester.widgetList(find.byType(SwitchListTile)).length;
    expect(count, greaterThan(5));
    // Some toggles restart services that create periodic timers; run them
    // under real timers so the fake clock's pending-timer check stays clean.
    await tester.runAsync(() async {
      for (var i = 0; i < count; i++) {
        final tile = find.byType(SwitchListTile).at(i);
        await tester.ensureVisible(tile);
        await tester.pump();
        await tester.tap(tile, warnIfMissed: false);
        await settle(tester, 2);
        expect(tester.takeException(), isNull, reason: 'switch $i threw');
        await tester.tap(tile, warnIfMissed: false); // and back
        await settle(tester, 2);
        expect(tester.takeException(), isNull,
            reason: 'switch $i threw on revert');
      }
    });
    await pop(tester);
  });

  testWidgets('create a group with a pinned contact', (tester) async {
    await tester.pumpWidget(const NyxChatApp());
    await settle(tester);
    await push(tester, const CreateGroupScreen());
    await tester.enterText(find.byType(TextField).first, 'Flow group');
    await tester.tap(find.text('Peer'));
    await settle(tester, 1);
    await tester.tap(find.byType(TextButton).first);
    await settle(tester, 6);
    expect(tester.takeException(), isNull);
    expect(services.chat.chatRooms.any((r) => r.peerDisplayName == 'Flow group'), isTrue,
        reason: 'group room must exist after Create');
  });

  testWidgets('join an emergency channel by geohash', (tester) async {
    await tester.pumpWidget(const NyxChatApp());
    await settle(tester);
    await push(tester, const EmergencyScreen());
    await tester.enterText(find.byType(TextField).first, 'tdr1w');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 6);
    expect(tester.takeException(), isNull);
    await pop(tester);
    services.chat.leaveEmergencyChannel();
  });
}