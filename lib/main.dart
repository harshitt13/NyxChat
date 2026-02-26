import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'core/network/p2p_client.dart';
import 'core/network/p2p_server.dart';
import 'core/network/ble_manager.dart';
import 'core/storage/local_storage.dart';
import 'services/identity_service.dart';
import 'services/chat_service.dart';
import 'services/peer_service.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/chat_list_screen.dart';
import 'services/background_service.dart';
import 'services/app_lock_service.dart';
import 'screens/password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize foreground service
  await BackgroundManager.initialize();

  // Initialize storage
  final storage = LocalStorage();
  await storage.init();

  // Create network components
  final p2pClient = P2PClient();
  final p2pServer = P2PServer(
    port: AppConstants.defaultPort,
    nyxChatId: '',
  );
  final bleManager = BleManager();

  // Create services
  final identityService = IdentityService(storage);
  final chatService = ChatService(
    storage: storage,
    client: p2pClient,
    server: p2pServer,
    keyManager: identityService.keyManager,
  );
  final peerService = PeerService(
    storage: storage,
    client: p2pClient,
    server: p2pServer,
    bleManager: bleManager,
  );

  // App Lock
  final appLockService = AppLockService(storage);
  await appLockService.init();

  // Try to load existing identity — BUT ONLY IF UNLOCKED
  if (!appLockService.isLocked) {
    await identityService.init();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appLockService),
        ChangeNotifierProvider.value(value: identityService),
        ChangeNotifierProvider.value(value: chatService),
        ChangeNotifierProvider.value(value: peerService),
        ChangeNotifierProvider.value(value: bleManager),
      ],
      child: const NyxChatObserver(),
    ),
  );
}

class NyxChatObserver extends StatefulWidget {
  const NyxChatObserver({super.key});

  @override
  State<NyxChatObserver> createState() => _NyxChatObserverState();
}

class _NyxChatObserverState extends State<NyxChatObserver> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Lock the app physically if enabled
      context.read<AppLockService>().lockApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppLockService, IdentityService>(
      builder: (context, lockService, identityService, _) {
        Widget homeScreen;

        // Route logic
        if (lockService.isLockEnabled && lockService.isLocked) {
           homeScreen = const PasswordScreen();
        } else if (!identityService.hasIdentity) {
           homeScreen = const OnboardingScreen();
        } else {
           homeScreen = const ChatListScreen();
        }

        return MaterialApp(
          title: 'NyxChat',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: homeScreen,
        );
      },
    );
  }
}
