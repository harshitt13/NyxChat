// Opens every screen of the app on top of the real service graph (Hive in a
// temp directory, secure storage mocked, platform plugins stubbed) and fails
// if any screen throws while building. This is the test that would have
// caught the 3.0 bug where every pushed route rendered blank because the
// chat/peer/connection providers were scoped below the Navigator.
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
import 'package:nyxchat/screens/contact_verify_screen.dart';
import 'package:nyxchat/screens/create_group_screen.dart';
import 'package:nyxchat/screens/emergency_screen.dart';
import 'package:nyxchat/screens/group_info_screen.dart';
import 'package:nyxchat/screens/mesh_map_screen.dart';
import 'package:nyxchat/screens/onboarding_screen.dart';
import 'package:nyxchat/screens/password_screen.dart';
import 'package:nyxchat/screens/peer_discovery_screen.dart';
import 'package:nyxchat/screens/security_screen.dart';
import 'package:nyxchat/screens/settings_screen.dart';

const _stubbedChannels = [
  'nyxchat/window',
  'nyxchat/ble_peripheral',
  'nyxchat/location',
  'nyxchat/wifi_aware',
  'nyxchat/wifi_aware/events',
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
  late String groupRoomId;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in _stubbedChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        // Plugins that cast the reply need a well-typed answer.
        if (call.method == 'initialize') return true;
        return null;
      });
    }
    tmp = Directory.systemTemp.createTempSync('nyx_smoke');
    services = AppServices();
    await services.storage.init(directory: tmp.path);
    await services.appLock.init();
    await services.identity.init();
    if (!services.identity.hasIdentity) {
      await services.identity.generateIdentity('Tester');
    }
    await services.bringUp();
    expect(services.ready, isTrue);
    // Start networking here, outside the test's fake clock, so the periodic
    // timers the services create are real ones and do not trip the
    // pending-timer check at the end of the widget test.
    await services.peers.startNetwork(
        nyxChatId: services.identity.nyxChatId,
        displayName: services.identity.displayName);

    final other = await KeyManager.generateEphemeral();
    peerId = await NyxId.derive(
        signingPublicKey: other.signingPublicKey,
        identityPublicKey: other.identityPublicKey);
    final pinned = await services.trust.pinFromContactCard({
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
    groupRoomId =
        (await services.chat.createGroup(name: 'Group', members: [pinned])).id;
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

  Future<void> open(WidgetTester tester, Widget screen) async {
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => screen)));
    await settle(tester);
    expect(tester.takeException(), isNull,
        reason: '${screen.runtimeType} threw while building');
    expect(find.byType(screen.runtimeType), findsOneWidget,
        reason: '${screen.runtimeType} did not appear');
    expect(find.descendant(of: find.byType(screen.runtimeType), matching: find.byType(Scaffold)),
        findsWidgets, reason: '${screen.runtimeType} rendered no Scaffold');
    nav.pop();
    await settle(tester);
    expect(tester.takeException(), isNull,
        reason: '${screen.runtimeType} threw while closing');
  }

  testWidgets('home renders and every screen opens without throwing',
      (tester) async {
    await tester.pumpWidget(const NyxChatApp());
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(ChatListScreen), findsOneWidget);

    await open(tester, const SettingsScreen());
    await open(tester, const SecurityScreen());
    await open(tester, const PeerDiscoveryScreen());
    await open(tester, const MeshMapScreen());
    await open(tester, const EmergencyScreen());
    await open(tester, const CreateGroupScreen());
    await open(tester, ContactVerifyScreen(peerId: peerId));
    await open(tester, ChatScreen(roomId: directRoomId));
    await open(tester, ChatScreen(roomId: groupRoomId));
    await open(tester, GroupInfoScreen(roomId: groupRoomId));
    await open(tester, const PasswordScreen());
    await open(tester, const OnboardingScreen());
  });
}