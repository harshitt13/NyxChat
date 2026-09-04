import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../protocol/inner_message.dart';
import 'key_value_store.dart';

/// A queued delivery. Plaintext inner messages are stored (the outbox box
/// is encrypted at rest); encryption happens on every attempt so that a
/// session reset never strands ciphertext.
class OutboxItem {
  static const String kindInner = 'inner';
  static const String kindEnvelope = 'envelope';

  final String id;
  final String peerId;
  final String kind;
  final Map<String, dynamic> payload;
  int attempts;
  DateTime createdAt;
  DateTime nextAttemptAt;

  /// Optional: message id shown in the UI (for status updates).
  final String? messageId;

  OutboxItem({
    required this.id,
    required this.peerId,
    required this.kind,
    required this.payload,
    this.messageId,
    this.attempts = 0,
    DateTime? createdAt,
    DateTime? nextAttemptAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        nextAttemptAt = nextAttemptAt ?? DateTime.now().toUtc();

  factory OutboxItem.inner(
          {required String peerId,
          required InnerMessage message,
          String? messageId}) =>
      OutboxItem(
        id: '${peerId}_${message.id}',
        peerId: peerId,
        kind: kindInner,
        payload: message.toJson(),
        messageId: messageId ?? message.id,
      );

  InnerMessage get innerMessage => InnerMessage.fromJson(payload);
  bool get isDue => !DateTime.now().toUtc().isBefore(nextAttemptAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'peerId': peerId,
        'kind': kind,
        'payload': payload,
        'messageId': messageId,
        'attempts': attempts,
        'created': createdAt.toIso8601String(),
        'next': nextAttemptAt.toIso8601String(),
      };

  factory OutboxItem.fromJson(Map<String, dynamic> j) => OutboxItem(
        id: j['id'] as String,
        peerId: j['peerId'] as String,
        kind: j['kind'] as String,
        payload: j['payload'] as Map<String, dynamic>,
        messageId: j['messageId'] as String?,
        attempts: j['attempts'] as int? ?? 0,
        createdAt: DateTime.parse(j['created'] as String),
        nextAttemptAt: DateTime.parse(j['next'] as String),
      );
}

/// Persistent store-and-forward queue for messages we could not deliver
/// yet (peer offline, no session, mesh only). Items expire after [maxAge].
class Outbox extends ChangeNotifier {
  static const Duration maxAge = Duration(days: 7);
  static const Duration minBackoff = Duration(seconds: 5);
  static const Duration maxBackoff = Duration(minutes: 10);

  final KeyValueStore _store;
  final Map<String, OutboxItem> _items = {};

  Outbox(this._store);

  Future<void> load() async {
    _items.clear();
    final now = DateTime.now().toUtc();
    for (final key in _store.keys) {
      final raw = _store.get(key);
      if (raw == null) continue;
      try {
        final item = OutboxItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (now.difference(item.createdAt) > maxAge) {
          await _store.delete(key);
          continue;
        }
        _items[item.id] = item;
      } catch (e) {
        debugPrint('[Outbox] dropping corrupt item $key: $e');
        await _store.delete(key);
      }
    }
    notifyListeners();
  }

  int get length => _items.length;
  List<OutboxItem> get all => _items.values.toList();
  bool contains(String id) => _items.containsKey(id);

  List<OutboxItem> forPeer(String peerId) =>
      _items.values.where((i) => i.peerId == peerId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<OutboxItem> dueForPeer(String peerId) =>
      forPeer(peerId).where((i) => i.isDue).toList();

  Set<String> get peersWithPending => _items.values.map((i) => i.peerId).toSet();

  Future<void> enqueue(OutboxItem item) async {
    _items[item.id] = item;
    await _store.put(item.id, jsonEncode(item.toJson()));
    notifyListeners();
  }

  Future<void> remove(String id) async {
    if (_items.remove(id) != null) {
      await _store.delete(id);
      notifyListeners();
    }
  }

  Future<void> removeForMessage(String messageId) async {
    final ids = _items.values
        .where((i) => i.messageId == messageId)
        .map((i) => i.id)
        .toList();
    for (final id in ids) {
      await remove(id);
    }
  }

  /// Record a failed attempt and schedule the next one with exponential
  /// backoff (5s, 10s, 20s ... capped at 10 minutes).
  Future<void> markAttempt(String id) async {
    final item = _items[id];
    if (item == null) return;
    item.attempts++;
    final backoffMs = min(
      maxBackoff.inMilliseconds,
      minBackoff.inMilliseconds * pow(2, min(item.attempts, 10)).toInt(),
    );
    item.nextAttemptAt =
        DateTime.now().toUtc().add(Duration(milliseconds: backoffMs));
    await _store.put(item.id, jsonEncode(item.toJson()));
    notifyListeners();
  }

  /// Make every item for a peer immediately due (e.g. the peer just came
  /// online or a session was re-established).
  Future<void> resetBackoff(String peerId) async {
    for (final item in forPeer(peerId)) {
      item.nextAttemptAt = DateTime.now().toUtc();
      await _store.put(item.id, jsonEncode(item.toJson()));
    }
  }

  Future<void> clear() async {
    for (final k in _items.keys.toList()) {
      await _store.delete(k);
    }
    _items.clear();
    notifyListeners();
  }
}