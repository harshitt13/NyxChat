class AppConstants {
  // App Info
  static const String appName = 'NyxChat';
  static const String appVersion = '1.0.0';

  // Networking
  static const String serviceType = '_bitchat._tcp';
  static const String serviceName = 'NyxChat';
  static const int defaultPort = 42420;
  static const int maxMessageSize = 65536; // 64KB
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration discoveryTimeout = Duration(seconds: 30);

  // Crypto
  static const int keyLength = 32; // 256-bit keys
  static const String keyStoragePrefix = 'bitchat_';

  // Storage
  static const String messagesBox = 'messages';
  static const String chatRoomsBox = 'chat_rooms';
  static const String peersBox = 'peers';
  static const String userBox = 'user';

  // Protocol
  static const String protocolVersion = '1.0';

  // UI
  static const double maxChatBubbleWidth = 0.75; // 75% of screen width
}
