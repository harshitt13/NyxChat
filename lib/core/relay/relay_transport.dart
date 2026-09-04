import 'dart:async';
import 'dart:typed_data';

/// Minimal contract for an internet store-and-forward carrier (e.g. the
/// Nostr relay transport). Payloads are already sealed for the pair; the
/// carrier only sees a rotating recipient token.
class RelayInbound {
  final String token;
  final Uint8List payload;
  final DateTime createdAt;
  RelayInbound({required this.token, required this.payload, required this.createdAt});
}

abstract class RelayTransport {
  bool get isConnected;
  void setTokens(List<String> tokensHex);
  Future<bool> publish({required String recipientTokenHex, required Uint8List payload});
  Stream<RelayInbound> get onInbound;
}