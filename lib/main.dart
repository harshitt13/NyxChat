import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/crypto/session_manager.dart';
import 'core/mesh/mesh_router.dart';
import 'core/mesh/mesh_store.dart';
import 'core/network/ble_manager.dart';
import 'core/network/connection_manager.dart';
import 'core/network/p2p_client.dart';
import 'core/network/p2p_server.dart';
import 'core/privacy/privacy_manager.dart';
import 'core/storage/local_storage.dart';
import 'core/storage/outbox.dart';
import 'core/storage/trust_store.dart';
import 'screens/chat_list_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/password_screen.dart';
import 'services/app_lock_service.dart';
import 'services/background_service.dart';
import 'services/chat_service.dart';
import 'services/identity_service.dart';
import 'services/peer_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

/// Composition root. Long-lived objects are created once; the pieces that
/// need the unlocked database and a loaded identity (trust store, ratchet
/// sessions, outbox, chat and peer services) are created by [bringUp].
class AppServices extends ChangeNotifier {
  final LocalStorage storage = LocalStorage();
  final P2PClient client = P2PClient();
  final P2PServer server = P2PServer(port: AppConstants.defaultPort);
  final BleManager ble = BleManager();
  final MeshStore meshStore = MeshStore();
  late final MeshRouter meshRouter = MeshRouter(store: meshStore);
  late final IdentityService identity = IdentityService(storage);
  late final AppLockService appLock = AppLockService(storage);
  late final SettingsService settings = SettingsService(storage);
  late final TrustStore trust = TrustStore(storage.trustStore);
  late final Outbox outbox = Outbox(storage.outboxStore);
  final PrivacyManager privacy = PrivacyManager();

  SessionManager? _sessions;
  ConnectionManager? _connections;
  ChatService? _chat;
  PeerService? _peers;
  bool _bringingUp = false;

  SessionManager get sessions => _sessions!;
  ConnectionManager get connections => _connections!;
  ChatService get chat => _chat!;
  PeerService get peers => _peers!;
  bool get ready => _chat != null && _peers != null;

  /// Called once the database is open and the identity is loaded.
  Future<void> bringUp() async {
    if (_bringingUp || !identity.hasIdentity || !storage.isDatabasesOpen) {
      return;
    }
    _bringingUp = true;
    try {
      final id = identity.nyxChatId;
      await trust.load();
      await settings.load();
      await settings.applyWindowSecurity();
      _sessions ??= SessionManager(
        keys: identity.keyManager,
        store: storage.sessionStore,
        myId: id,
      );
      await _sessions!.load();
      _connections ??= ConnectionManager(
        keys: identity.keyManager,
        client: client,
        server: server,
        trust: trust,
        sessions: _sessions!,
      );
      _chat ??= ChatService(
        storage: storage,
        client: client,
        trust: trust,
        sessions: _sessions!,
        outbox: outbox,
        connections: _connections!,
        meshRouter: meshRouter,
      );
      _peers ??= PeerService(
        storage: storage,
        client: client,
        server: server,
        bleManager: ble,
        connections: _connections!,
        trust: trust,
        keys: identity.keyManager,
        meshStore: meshStore,
        meshRouter: meshRouter,
      );
      _chat!.meshLinkCountProvider = () => ble.linkCount;
      _chat!.sendReadReceipts = settings.readReceipts;
      await _chat!.init(myId: id, displayName: identity.displayName);
      _wirePrivacy();
    } finally {
      _bringingUp = false;
    }
    notifyListeners();
  }

  void _wirePrivacy() {
    // Cover traffic: opaque packets to a random address over the mesh.
    privacy.onCoverPacket = (payload) async {
      if (ble.linkCount == 0) return;
      final target = 'NC-${payload.sublist(0, 8).map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';
      await meshRouter.send(recipientId: target, payload: payload);
    };
    privacy.setCoverTraffic(settings.dummyTraffic);
    settings.addListener(() {
      if (privacy.isCoverTrafficEnabled != settings.dummyTraffic) {
        privacy.setCoverTraffic(settings.dummyTraffic);
      }
      if (_chat != null) _chat!.sendReadReceipts = settings.readReceipts;
    });
  }

  /// Panic wipe: stop networking, destroy data and keys, reset to onboarding.
  Future<void> panicWipe() async {
    try {
      await _peers?.stopNetwork();
    } catch (_) {}
    await _chat?.clearAll();
    await _sessions?.clearAll();
    meshRouter.clearAll();
    await appLock.panicWipe();
    await identity.destroy();
    _chat = null;
    _peers = null;
    _connections = null;
    _sessions = null;
    notifyListeners();
  }
}

late final AppServices services;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundManager.initialize();

  services = AppServices();
  await services.storage.init();
  await services.appLock.init();
  if (!services.appLock.isLocked) {
    await services.identity.init(decoy: services.appLock.isDecoyProfile);
    await services.bringUp();
  }
  runApp(const NyxChatApp());
}

class NyxChatApp extends StatefulWidget {
  const NyxChatApp({super.key});
  @override
  State<NyxChatApp> createState() => _NyxChatAppState();
}

class _NyxChatAppState extends State<NyxChatApp> with WidgetsBindingObserver {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription? _incomingSub;
  bool _inBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initNotifications());
    _wireIncoming();
    services.addListener(_wireIncoming);
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications
        .initialize(const InitializationSettings(android: android));
  }

  void _wireIncoming() {
    if (!services.ready || _incomingSub != null) return;
    _incomingSub = services.chat.onIncomingMessage.listen((msg) {
      if (!_inBackground || !services.settings.notifications) return;
      final room = services.chat.room(msg.roomId ?? '');
      if (room?.muted == true) return;
      final title = room?.peerDisplayName ?? 'NyxChat';
      final body =
          services.settings.notificationPreview ? msg.content : 'New message';
      _notifications.show(
        msg.id.hashCode & 0x7fffffff,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'nyxchat_messages',
            'Messages',
            channelDescription: 'Incoming NyxChat messages',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingSub?.cancel();
    services.removeListener(_wireIncoming);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inBackground = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    if (state == AppLifecycleState.paused &&
        services.settings.lockOnBackground) {
      services.appLock.lockApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: services),
        ChangeNotifierProvider.value(value: services.appLock),
        ChangeNotifierProvider.value(value: services.identity),
        ChangeNotifierProvider.value(value: services.settings),
        ChangeNotifierProvider.value(value: services.trust),
        ChangeNotifierProvider.value(value: services.ble),
        ChangeNotifierProvider.value(value: services.outbox),
      ],
      child: Consumer3<AppLockService, IdentityService, AppServices>(
        builder: (context, lock, identity, app, _) {
          Widget home;
          if (lock.isLockEnabled && lock.isLocked) {
            home = const PasswordScreen();
          } else if (!identity.hasIdentity) {
            home = const OnboardingScreen();
          } else if (!app.ready) {
            home = const _BootScreen();
          } else {
            home = MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: app.chat),
                ChangeNotifierProvider.value(value: app.peers),
                ChangeNotifierProvider.value(value: app.connections),
              ],
              child: const ChatListScreen(),
            );
          }
          return MaterialApp(
            title: 'NyxChat',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: home,
          );
        },
      ),
    );
  }
}

/// Shown for the brief moment between unlock/onboarding and service bring-up.
class _BootScreen extends StatefulWidget {
  const _BootScreen();
  @override
  State<_BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<_BootScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      await services.bringUp();
    } catch (e) {
      debugPrint('[Boot] failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.accentBlue)),
      );
}