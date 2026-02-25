import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'core/network/p2p_client.dart';
import 'core/network/p2p_server.dart';
import 'core/storage/local_storage.dart';
import 'services/identity_service.dart';
import 'services/chat_service.dart';
import 'services/peer_service.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/chat_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  final storage = LocalStorage();
  await storage.init();

  // Create network components
  final p2pClient = P2PClient();
  final p2pServer = P2PServer(
    port: AppConstants.defaultPort,
    bitChatId: '',
  );

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
  );

  // Try to load existing identity
  final hasIdentity = await identityService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: identityService),
        ChangeNotifierProvider.value(value: chatService),
        ChangeNotifierProvider.value(value: peerService),
      ],
      child: BitChatApp(hasIdentity: hasIdentity),
    ),
  );
}

class BitChatApp extends StatelessWidget {
  final bool hasIdentity;

  const BitChatApp({super.key, required this.hasIdentity});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NyxChat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: hasIdentity ? const ChatListScreen() : const OnboardingScreen(),
    );
  }
}
