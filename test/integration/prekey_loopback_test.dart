// Two complete stacks: prekey bundles exchanged on a direct link, then an
// asynchronous session through the simulated mesh that consumes a
// one-time prekey, and the recovery when the responder lost its prekeys.
//
// Reuses the Node harness of loopback_test.dart (its main() is not run).

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/prekey_store.dart';
import 'package:nyxchat/models/message.dart';

import 'loopback_test.dart' show Node, waitFor;

/// Take both nodes offline from each other on TCP and give them one
/// simulated BLE link, with no pairwise session left on either side, so
/// the next message has to start an asynchronous session over the mesh.
Future<void> goToMesh(Node a, Node b) async {
  await a.client.disconnectAll();
  await waitFor(() => !b.client.isPeerConnected(a.id), what: 'link down');
  await a.sessions.reset(b.id);
  await b.sessions.reset(a.id);
  await a.chat.refreshTokens(force: true);
  await b.chat.refreshTokens(force: true);
  a.mesh.onForwardPacket = (p, _) => unawaited(b.mesh.handlePacket(p));
  b.mesh.onForwardPacket = (p, _) => unawaited(a.mesh.handlePacket(p));
  a.chat.meshLinkCountProvider = () => 1;
  b.chat.meshLinkCountProvider = () => 1;
}

void main() {
  late Directory root;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('nyx_pk_');
  });

  tearDownAll(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  test('bundles on the link, then a mesh session that consumes a one-time prekey', () async {
    final a = await Node.create('pa1', root, hiveInit: true);
    final b = await Node.create('pb1', root);
    await a.connectTo(b);
    await waitFor(
        () => a.prekeys.peerPrekeyCount(b.id) == PrekeyStore.poolSize &&
            b.prekeys.peerPrekeyCount(a.id) == PrekeyStore.poolSize,
        what: 'full pools on both sides');
    expect(a.prekeys.outstanding(b.id).length, PrekeyStore.poolSize);
    expect(b.prekeys.outstanding(a.id).length, PrekeyStore.poolSize);
    final firstBundleAt = a.prekeys.lastBundleIssuedAt(b.id)!;

    await goToMesh(a, b);
    final room = await a.chat.getOrCreateDirectRoom(peerId: b.id, displayName: 'B');
    final sent = await a.chat.sendText(roomId: room.id, text: 'pq via mesh');
    // The in-process mesh acks instantly, so the ack may already have landed.
    expect(sent!.status, isIn([MessageStatus.sent, MessageStatus.delivered]));
    await waitFor(() => b.received.any((m) => m.content == 'pq via mesh'), what: 'mesh delivery');

    final used = a.sessions.record(b.id)!.prekeyId;
    expect(used, isNotNull, reason: 'initiator consumed a prekey');
    expect(a.sessions.record(b.id)!.isAsyncFallback, isFalse);
    expect(b.sessions.record(a.id)!.prekeyId, used, reason: 'responder recorded the same id');
    expect(b.prekeys.findOwn(a.id, used!), isNull, reason: 'private half deleted on use');
    expect(b.prekeys.outstanding(a.id).length, PrekeyStore.poolSize - 1);
    expect(a.prekeys.peerPrekeyCount(b.id), PrekeyStore.poolSize - 1);

    final bRoom = b.chat.chatRooms.firstWhere((r) => r.peerId == a.id);
    await b.chat.sendText(roomId: bRoom.id, text: 'mesh reply');
    await waitFor(() => a.received.any((m) => m.content == 'mesh reply'), what: 'reply');
    await waitFor(() => a.messageById(room.id, sent.id)?.status == MessageStatus.delivered, what: 'receipt');

    // Meeting again tops both pools back up with a newer bundle.
    await a.connectTo(b);
    await waitFor(
        () => b.prekeys.outstanding(a.id).length == PrekeyStore.poolSize &&
            a.prekeys.peerPrekeyCount(b.id) == PrekeyStore.poolSize,
        what: 'pools topped up');
    expect(a.prekeys.lastBundleIssuedAt(b.id)!, greaterThan(firstBundleAt));
    await a.dispose();
    await b.dispose();
  });

  test('responder lost its prekeys: signed notice, long-term fallback, delivery', () async {
    final a = await Node.create('pa2', root);
    final b = await Node.create('pb2', root);
    await a.connectTo(b);
    await waitFor(() => a.prekeys.peerPrekeyCount(b.id) == PrekeyStore.poolSize, what: 'bundle at A');
    await goToMesh(a, b);
    // B's prekey store is gone (fresh storage); A still holds B's pool.
    await b.prekeys.clearAll();
    expect(b.prekeys.outstanding(a.id), isEmpty);

    final room = await a.chat.getOrCreateDirectRoom(peerId: b.id, displayName: 'B');
    final sent = await a.chat.sendText(roomId: room.id, text: 'after wipe');
    // The in-process mesh acks instantly, so the ack may already have landed.
    expect(sent!.status, isIn([MessageStatus.sent, MessageStatus.delivered]));
    expect(a.sessions.record(b.id)!.prekeyId, isNotNull, reason: 'first attempt used a prekey');
    await waitFor(() => b.received.any((m) => m.content == 'after wipe'),
        timeout: const Duration(seconds: 30), what: 'delivery after fallback');
    final rec = a.sessions.record(b.id)!;
    expect(rec.isAsyncFallback, isTrue, reason: 'restarted with the long-term key');
    expect(a.prekeys.peerPrekeyCount(b.id), 0, reason: 'stale pool discarded');
    expect(b.sessions.record(a.id)!.prekeyId, isNull);
    await waitFor(() => a.messageById(room.id, sent.id)?.status == MessageStatus.delivered,
        timeout: const Duration(seconds: 30), what: 'delivery receipt');

    final bRoom = b.chat.chatRooms.firstWhere((r) => r.peerId == a.id);
    await b.chat.sendText(roomId: bRoom.id, text: 'reply after fallback');
    await waitFor(() => a.received.any((m) => m.content == 'reply after fallback'), what: 'reply');
    // Received exactly once despite the re-queue.
    expect(b.received.where((m) => m.content == 'after wipe').length, 1);
    await a.dispose();
    await b.dispose();
  });
}