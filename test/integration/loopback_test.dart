// End-to-end integration tests: two (or three) complete NyxChat stacks in
// one process, talking over loopback TCP and over a simulated mesh link.
//
// Exercises the wiring between ConnectionManager, SessionManager,
// ChatService, Outbox, TrustStore and MeshRouter that unit tests cannot.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/models/message.dart';

import 'harness.dart';

void main() {
  late Directory root;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('nyx_it_');
  });

  tearDownAll(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  test('handshake, session open, message, receipt, reply', () async {
    final a = await Node.create('a1', root, hiveInit: true);
    final b = await Node.create('b1', root);
    await a.connectTo(b);
    expect(a.trust.get(b.id), isNotNull, reason: 'keys pinned on first contact');
    expect(b.trust.get(a.id), isNotNull);

    final room = await a.chat.getOrCreateDirectRoom(peerId: b.id, displayName: 'B');
    final sent = await a.chat.sendText(roomId: room.id, text: 'hello over tcp');
    expect(sent, isNotNull);
    expect(sent!.status, MessageStatus.sent);
    await waitFor(() => b.received.any((m) => m.content == 'hello over tcp'), what: 'B receives');
    await waitFor(() => a.messageById(room.id, sent.id)?.status == MessageStatus.delivered, what: 'delivery receipt');

    final bRoom = b.chat.chatRooms.firstWhere((r) => r.peerId == a.id);
    await b.chat.sendText(roomId: bRoom.id, text: 'reply');
    await waitFor(() => a.received.any((m) => m.content == 'reply'), what: 'A receives reply');

    // Read receipt
    await b.chat.markRoomAsRead(bRoom.id);
    await waitFor(() => a.messageById(room.id, sent.id)?.status == MessageStatus.read, what: 'read receipt');
    await a.dispose();
    await b.dispose();
  });

  test('reconnect keeps the session; reset recovers when a peer lost state', () async {
    final a = await Node.create('a2', root);
    final b = await Node.create('b2', root);
    await a.connectTo(b);
    final created = a.sessions.record(b.id)!.createdAt;
    final room = await a.chat.getOrCreateDirectRoom(peerId: b.id, displayName: 'B');

    await a.client.disconnectAll();
    await waitFor(() => !b.client.isPeerConnected(a.id), what: 'disconnect seen');
    await a.connectTo(b);
    expect(a.sessions.record(b.id)!.createdAt, created, reason: 'session survives reconnect');
    await a.chat.sendText(roomId: room.id, text: 'after reconnect');
    await waitFor(() => b.received.any((m) => m.content == 'after reconnect'));

    // B loses its session state (e.g. database reset) while the link is up.
    await b.sessions.clearAll();
    final m = await a.chat.sendText(roomId: room.id, text: 'after reset');
    expect(m, isNotNull);
    await waitFor(() => b.received.any((x) => x.content == 'after reset'),
        timeout: const Duration(seconds: 30), what: 'message re-delivered after session reset');
    await waitFor(() => a.messageById(room.id, m!.id)?.status == MessageStatus.delivered,
        timeout: const Duration(seconds: 30), what: 'delivered after reset');
    await a.dispose();
    await b.dispose();
  });

  test('mesh delivery with sealed sender, async session and ack', () async {
    final a = await Node.create('a3', root);
    final b = await Node.create('b3', root);
    // Not connected over TCP; they know each other's keys (contact cards).
    await a.trust.acceptNewKeys(b.pinned());
    await b.trust.acceptNewKeys(a.pinned());
    await a.chat.refreshTokens(force: true);
    await b.chat.refreshTokens(force: true);
    // One simulated BLE link between them.
    a.mesh.onForwardPacket = (p, _) => unawaited(b.mesh.handlePacket(p));
    b.mesh.onForwardPacket = (p, _) => unawaited(a.mesh.handlePacket(p));
    a.chat.meshLinkCountProvider = () => 1;
    b.chat.meshLinkCountProvider = () => 1;

    final room = await a.chat.getOrCreateDirectRoom(peerId: b.id, displayName: 'B');
    final sent = await a.chat.sendText(roomId: room.id, text: 'via mesh');
    // The ack can beat sendText returning on a loaded machine.
    expect(sent!.status, anyOf(MessageStatus.sent, MessageStatus.delivered));
    await waitFor(() => b.received.any((m) => m.content == 'via mesh'), what: 'mesh delivery');
    await waitFor(() => a.messageById(room.id, sent.id)?.status == MessageStatus.delivered, what: 'ack/receipt');
    final bRoom = b.chat.chatRooms.firstWhere((r) => r.peerId == a.id);
    await b.chat.sendText(roomId: bRoom.id, text: 'mesh reply');
    await waitFor(() => a.received.any((m) => m.content == 'mesh reply'), what: 'mesh reply');
    expect(a.mesh.totalAcked, greaterThan(0));
    await a.dispose();
    await b.dispose();
  });

  test('three-party group with sender keys', () async {
    final a = await Node.create('a4', root);
    final b = await Node.create('b4', root);
    final c = await Node.create('c4', root);
    await a.connectTo(b);
    await a.connectTo(c);
    await b.connectTo(c);
    final group = await a.chat.createGroup(name: 'trio', members: [a.trust.get(b.id)!, a.trust.get(c.id)!]);
    await waitFor(() => b.chat.room(group.id) != null && c.chat.room(group.id) != null, what: 'group created at B and C');
    await a.chat.sendText(roomId: group.id, text: 'hello group');
    await waitFor(() => b.received.any((m) => m.content == 'hello group'), what: 'B gets group message');
    await waitFor(() => c.received.any((m) => m.content == 'hello group'), what: 'C gets group message');
    await b.chat.sendText(roomId: group.id, text: 'from b');
    await waitFor(() => a.received.any((m) => m.content == 'from b') && c.received.any((m) => m.content == 'from b'), what: 'B message fans out');
    await a.chat.removeGroupMember(group.id, c.id);
    await waitFor(() => c.chat.room(group.id)?.left == true, what: 'C sees removal');
    await a.chat.sendText(roomId: group.id, text: 'after removal');
    await waitFor(() => b.received.any((m) => m.content == 'after removal'), what: 'B still receives');
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(c.received.any((m) => m.content == 'after removal'), isFalse, reason: 'removed member excluded');
    await a.dispose();
    await b.dispose();
    await c.dispose();
  });
}