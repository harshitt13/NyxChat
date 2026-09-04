import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/key_manager.dart';
import 'package:nyxchat/core/crypto/nyx_id.dart';
import 'package:nyxchat/core/protocol/inner_message.dart';
import 'package:nyxchat/core/storage/key_value_store.dart';
import 'package:nyxchat/core/storage/outbox.dart';
import 'package:nyxchat/core/storage/trust_store.dart';

Future<(KeyManager, String)> _identity() async {
  final keys = await KeyManager.generateEphemeral();
  final id = await NyxId.derive(
      signingPublicKey: keys.signingPublicKey,
      identityPublicKey: keys.identityPublicKey);
  return (keys, id);
}

void main() {
  group('TrustStore', () {
    test('first contact pins, same keys unchanged, new keys flagged', () async {
      final store = MemoryKeyValueStore();
      final trust = TrustStore(store);
      await trust.load();
      final (k1, id) = await _identity();
      final c1 = await trust.check(
          nyxChatId: id, displayName: 'A',
          identityKey: k1.identityPublicKey, signingKey: k1.signingPublicKey,
          kyberPublicKey: k1.kyberPublicKey);
      expect(c1.decision, TrustDecision.firstContact);
      expect(trust.get(id), isNotNull);

      final c2 = await trust.check(
          nyxChatId: id, displayName: 'A2',
          identityKey: k1.identityPublicKey, signingKey: k1.signingPublicKey,
          kyberPublicKey: k1.kyberPublicKey);
      expect(c2.decision, TrustDecision.unchanged);
      expect(trust.get(id)!.displayName, 'A2');

      final k2 = await KeyManager.generateEphemeral();
      final c3 = await trust.check(
          nyxChatId: id, displayName: 'A',
          identityKey: k2.identityPublicKey, signingKey: k2.signingPublicKey,
          kyberPublicKey: k2.kyberPublicKey);
      expect(c3.isKeyChange, isTrue);
      // Pinned record untouched until accepted.
      expect(trust.get(id)!.identityKeyHex, k1.identityPublicKeyHex);
      await trust.acceptNewKeys(c3.peer);
      expect(trust.get(id)!.identityKeyHex, k2.identityPublicKeyHex);

      // Survives reload.
      final trust2 = TrustStore(store);
      await trust2.load();
      expect(trust2.get(id)!.identityKeyHex, k2.identityPublicKeyHex);
    });

    test('contact card pinning verifies id binding', () async {
      final trust = TrustStore(MemoryKeyValueStore());
      final (k, id) = await _identity();
      final card = {
        'nyx': 3, 'id': id, 'name': 'Zed',
        'ik': k.identityPublicKeyHex, 'sk': k.signingPublicKeyHex,
        'kpk': k.kyberPublicKeyHex,
      };
      final p = await trust.pinFromContactCard(
          jsonDecode(jsonEncode(card)) as Map<String, dynamic>);
      expect(p.verified, isTrue);
      final other = await KeyManager.generateEphemeral();
      card['ik'] = other.identityPublicKeyHex;
      await expectLater(trust.pinFromContactCard(card), throwsFormatException);
    });
  });

  group('Outbox', () {
    test('enqueue, backoff, persistence and expiry', () async {
      final store = MemoryKeyValueStore();
      final outbox = Outbox(store);
      await outbox.load();
      final item = OutboxItem.inner(
          peerId: 'peer', message: InnerMessage.text(id: 'm1', text: 'x'));
      await outbox.enqueue(item);
      expect(outbox.dueForPeer('peer').length, 1);
      await outbox.markAttempt(item.id);
      expect(outbox.dueForPeer('peer'), isEmpty);
      await outbox.resetBackoff('peer');
      expect(outbox.dueForPeer('peer').length, 1);

      final reloaded = Outbox(store);
      await reloaded.load();
      expect(reloaded.length, 1);
      expect(reloaded.forPeer('peer').first.innerMessage.text, 'x');

      final old = OutboxItem(
        id: 'old', peerId: 'peer', kind: OutboxItem.kindInner,
        payload: InnerMessage.text(id: 'o', text: 'o').toJson(),
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
      );
      await reloaded.enqueue(old);
      final again = Outbox(store);
      await again.load();
      expect(again.contains('old'), isFalse);
      expect(again.length, 1);
    });
  });

  group('fingerprint formatting', () {
    test('formats 32 bytes as 8 groups', () {
      final fp = CryptoUtils.randomBytes(32);
      final s = NyxId.formatFingerprint(fp);
      expect(s.split(' ').length, 8);
    });
  });
}