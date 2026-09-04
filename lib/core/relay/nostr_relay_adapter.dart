import 'dart:async';
import 'dart:typed_data';

import 'nostr_transport.dart';
import 'relay_transport.dart';

/// Adapts [NostrTransport] to the [RelayTransport] contract the messaging
/// engine uses. Payloads reaching this layer are already sealed for the
/// pair (see PairKeys.wrap), so relays only ever see rotating tokens and
/// opaque bytes.
class NostrRelayAdapter implements RelayTransport {
  final NostrTransport transport;
  NostrRelayAdapter(this.transport);

  @override
  bool get isConnected => transport.isConnected;

  @override
  void setTokens(List<String> tokensHex) => transport.setTokens(tokensHex);

  @override
  Future<bool> publish({required String recipientTokenHex, required Uint8List payload}) =>
      transport.publish(recipientTokenHex: recipientTokenHex, payload: payload);

  @override
  Stream<RelayInbound> get onInbound => transport.onInbound.map(
        (n) => RelayInbound(token: n.token, payload: n.payload, createdAt: n.createdAt),
      );
}