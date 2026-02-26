import 'dart:io';
import 'package:flutter/foundation.dart';

/// Routes internet relay traffic through the Tor Network.
/// Relies on Orbot (or another Tor proxy) running locally on the device.
class TorManager {
  // Toggle this to route all relay WebSocket traffic through Tor
  static bool useTor = true;

  /// Creates an HttpClient configured to route through Orbot's local HTTP proxy.
  /// Orbot exposes an HTTP proxy on port 8118 by default.
  static HttpClient createTorHttpClient() {
    final client = HttpClient();
    
    if (useTor) {
      debugPrint('[TorManager] Proxying connection through Orbot (127.0.0.1:8118)');
      // Route through local Tor HTTP Proxy
      client.findProxy = (uri) {
        return 'PROXY 127.0.0.1:8118';
      };
    } else {
      client.findProxy = (uri) => 'DIRECT';
    }
    
    // Only accept self-signed certs for .onion addresses (Tor hidden services)
    // All other domains must present valid certificates
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      return host.endsWith('.onion');
    };
    
    return client;
  }
}
