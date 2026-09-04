import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/crypto/pair_keys.dart';
import 'core/crypto/prekey_store.dart';
import 'core/crypto/session_manager.dart';
import 'core/mesh/mesh_router.dart';
import 'core/mesh/mesh_store.dart';
import 'core/network/ble_manager.dart';
import 'core/network/connection_manager.dart';
import 'core/network/p2p_client.dart';
import 'core/network/p2p_server.dart';
import 'core/network/prekey_exchange.dart';
import 'core/privacy/privacy_manager.dart';
import 'core/relay/nostr_relay_adapter.dart';
import 'core/relay/nostr_transport.dart';
import 'core/storage/local_storage.dart';
import 'core/storage/outbox.dart';
import 'core/storage/trust_store.dart';
import 'l10n/generated/app_localizations.dart';
import 'screens/chat_list_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/password_screen.dart';
import 'services/app_lock_service.dart';
import 'services/background_service.dart';
import 'services/backup_service.dart';
import 'services/chat_service.dart';
import 'services/identity_service.dart';
import 'services/peer_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'widgets/media_strings.dart';
import 'widgets/message_preview.dart';

/// Composition root. Long-lived objects are created once; the pieces that
/// need the unlocked database and a loaded identity (trust store, ratchet
/// sessions, outbox, chat and peer services) are created by [bringUp].
class AppServices extends ChangeNotifier {
  final LocalStorage storage = LocalStorage();
  final P2PClient client = P2PClient();
  final P2PServer server;

  /// [port] 0 lets the OS pick a free port (tests run several stacks at once).
  AppServices({int port = AppConstants.defaultPort})
      : server = P2PServer(port: port);
  final BleManager ble = BleManager();
  final MeshStore meshStore = MeshStore();
  late final MeshRouter meshRouter = MeshRouter(store: meshStore);
  late final IdentityService identity = IdentityService(storage);
  late final AppLockService appLock = AppLockService(storage);
  late final SettingsService settings = SettingsService(storage);
  late final TrustStore trust = TrustStore(storage.trustStore);
  late final Outbox outbox = Outbox(storage.outboxStore);
  final PrivacyManager privacy = PrivacyManager();
  late final BackupService backup = BackupService(storage, identity.keyManager);

  SessionManager? _sessions;
  PrekeyStore? _prekeys;
  PrekeyExchange? _prekeyExchange;
  PairKeyCache? _pairKeys;
  ConnectionManager? _connections;
  ChatService? _chat;
  PeerService? _peers;
  NostrTransport? _nostr;
  bool _nostrViaTor = false;
  bool _bringingUp = false;

  SessionManager get sessions => _sessions!;
  PrekeyStore? get prekeys => _prekeys;
  PairKeyCache get pairKeys => _pairKeys!;
  ConnectionManager get connections => _connections!;
  ChatService get chat => _chat!;
  PeerService get peers => _peers!;
  NostrTransport? get nostr => _nostr;
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
      _prekeys ??= PrekeyStore(storage.prekeyStore);
      await _prekeys!.load();
      _sessions ??= SessionManager(
        keys: identity.keyManager,
        store: storage.sessionStore,
        myId: id,
        prekeys: _prekeys,
      );
      await _sessions!.load();
      _pairKeys ??= PairKeyCache(identity.keyManager, trust);
      _connections ??= ConnectionManager(
        keys: identity.keyManager,
        client: client,
        server: server,
        trust: trust,
        sessions: _sessions!,
      );
      _prekeyExchange ??= PrekeyExchange(
        keys: identity.keyManager,
        client: client,
        connections: _connections!,
        trust: trust,
        prekeys: _prekeys!,
      )..start(myId: id);
      _chat ??= ChatService(
        storage: storage,
        client: client,
        trust: trust,
        sessions: _sessions!,
        outbox: outbox,
        connections: _connections!,
        pairKeys: _pairKeys!,
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
        pairKeys: _pairKeys!,
      );
      _peers!.isDiscoverableToEveryone = () => settings.discoverableToEveryone;
      _peers!.isAwareEnabled = () => settings.wifiAware;
      _chat!.meshLinkCountProvider = () => _peers!.meshNeighbourCount;
      _chat!.sendReadReceipts = settings.readReceipts;
      await _chat!.init(myId: id, displayName: identity.displayName);
      _wirePrivacy();
      await _applyRelaySetting();
    } finally {
      _bringingUp = false;
    }
    notifyListeners();
  }

  /// Start or stop the Nostr carrier according to settings.
  Future<void> _applyRelaySetting() async {
    final chat = _chat;
    if (chat == null) return;
    final wanted = settings.nostrEnabled;
    final torChanged = _nostr != null && _nostrViaTor != settings.nostrViaTor;
    if (!wanted || torChanged) {
      if (_nostr != null) {
        chat.setRelay(null);
        await _nostr!.stop();
        _nostr!.dispose();
        _nostr = null;
      }
      if (!wanted) return;
    }
    if (_nostr == null) {
      _nostrViaTor = settings.nostrViaTor;
      final t = NostrTransport(useTor: _nostrViaTor);
      _nostr = t;
      chat.setRelay(NostrRelayAdapter(t));
      await t.start();
    }
  }

  void _wirePrivacy() {
    // Cover traffic: opaque packets to a random address over the mesh.
    privacy.onCoverPacket = (payload) async {
      if (ble.linkCount == 0) return;
      await meshRouter.send(
        to: payload.sublist(0, 16),
        replyTo: payload.sublist(16, 32),
        payload: payload.sublist(32),
      );
    };
    privacy.setCoverTraffic(settings.dummyTraffic);
    var discoverable = settings.discoverableToEveryone;
    settings.addListener(() {
      if (privacy.isCoverTrafficEnabled != settings.dummyTraffic) {
        privacy.setCoverTraffic(settings.dummyTraffic);
      }
      if (_chat != null) _chat!.sendReadReceipts = settings.readReceipts;
      if (discoverable != settings.discoverableToEveryone) {
        discoverable = settings.discoverableToEveryone;
        unawaited(_peers?.refreshBeacons() ?? Future.value());
      }
      unawaited(_applyRelaySetting());
    });
  }

  /// Rotate identity keys, notify contacts, then close the app so every
  /// service restarts with the new handle.
  Future<String> rotateIdentity() async {
    final chat = _chat;
    if (chat == null) throw StateError('services not ready');
    final newId = await chat.rotateIdentity(identity.prepareRotation, identity.commitRotation);
    await _sessions?.clearAll(); // sessions belonged to the old handle
    return newId;
  }

  /// Panic wipe: stop networking, destroy data and keys, reset to onboarding.
  Future<void> panicWipe() async {
    try {
      await _peers?.stopNetwork();
    } catch (_) {}
    _chat?.setRelay(null);
    await _nostr?.stop();
    _nostr = null;
    await _chat?.clearAll();
    await _sessions?.clearAll();
    await _prekeys?.clearAll();
    meshRouter.clearAll();
    await appLock.panicWipe();
    await identity.destroy();
    await settings.resetAppearance();
    _chat = null;
    _peers = null;
    _connections = null;
    _sessions = null;
    _prekeyExchange?.dispose();
    _prekeyExchange = null;
    _prekeys = null;
    _pairKeys?.clear();
    _pairKeys = null;
    notifyListeners();
  }
}

late final AppServices services;

/// The locale the UI runs in: the language chosen in Settings, otherwise the
/// best supported match for the device languages. Used outside widget
/// contexts (notifications, background service).
Locale uiLocale() {
  final chosen = services.settings.locale;
  final preferred = chosen != null
      ? [chosen]
      : WidgetsBinding.instance.platformDispatcher.locales;
  return basicLocaleListResolution(preferred, AppLocalizations.supportedLocales);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  services = AppServices();
  MediaStrings.localeProvider = uiLocale;
  await services.settings.loadAppearance();
  BackgroundManager.languageTag = uiLocale().toLanguageTag();
  await BackgroundManager.initialize(l10n: lookupAppLocalizations(uiLocale()));

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
    services.settings.addListener(_syncBackgroundLocale);
  }

  void _syncBackgroundLocale() {
    final tag = uiLocale().toLanguageTag();
    if (tag == BackgroundManager.languageTag) return;
    BackgroundManager.languageTag = tag;
    BackgroundManager.setLocale(tag);
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
      final l = lookupAppLocalizations(uiLocale());
      final title = room?.peerDisplayName ?? l.appTitle;
      final body = services.settings.notificationPreview
          ? notificationBody(msg)
          : l.notificationNewMessage;
      _notifications.show(
        msg.id.hashCode & 0x7fffffff,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'nyxchat_messages',
            l.notificationChannelMessages,
            channelDescription: l.notificationChannelMessagesDescription,
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
    services.settings.removeListener(_syncBackgroundLocale);
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
      child: Consumer4<AppLockService, IdentityService, AppServices,
          SettingsService>(
        builder: (context, lock, identity, app, settings, _) {
          Widget home;
          if (lock.isLockEnabled && lock.isLocked) {
            home = const PasswordScreen();
          } else if (!identity.hasIdentity) {
            home = const OnboardingScreen();
          } else if (!app.ready) {
            home = const _BootScreen();
          } else {
            home = const ChatListScreen();
          }
          final materialApp = MaterialApp(
            title: 'NyxChat',
            onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            locale: settings.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Status/navigation bar icons follow the resolved theme, also on
            // screens without an AppBar.
            builder: (ctx, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: AppTheme.overlayStyle(ctx.nyx),
              child: child ?? const SizedBox.shrink(),
            ),
            home: home,
          );
          if (!app.ready) return materialApp;
          // The chat, peer and connection services must sit ABOVE the
          // MaterialApp: routes pushed on its Navigator get the Navigator's
          // context, so providers wrapped around `home` alone are invisible
          // to every screen except the home screen (blank screens in release
          // builds, ProviderNotFoundException in debug).
          return MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: app.chat),
              ChangeNotifierProvider.value(value: app.peers),
              ChangeNotifierProvider.value(value: app.connections),
              if (app.prekeys != null)
                ChangeNotifierProvider.value(value: app.prekeys!),
            ],
            child: materialApp,
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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.nyx.background,
        body: Center(
            child: CircularProgressIndicator(color: context.nyx.accentBlue)),
      );
}