import 'package:hive/hive.dart';

/// Minimal key-value abstraction so that crypto state stores can be unit
/// tested without Hive and swapped for other backends.
abstract class KeyValueStore {
  String? get(String key);
  Future<void> put(String key, String value);
  Future<void> delete(String key);
  Iterable<String> get keys;
  bool get isOpen;
}

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _data = {};
  @override
  String? get(String key) => _data[key];
  @override
  Future<void> put(String key, String value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
  @override
  Iterable<String> get keys => _data.keys.toList();
  @override
  bool get isOpen => true;
}

/// Hive-backed store. The box is opened with the same AES cipher as the
/// other NyxChat boxes (see LocalStorage).
class HiveKeyValueStore implements KeyValueStore {
  final Box<String> Function() _box;
  HiveKeyValueStore(this._box);

  Box<String>? get _safe {
    try {
      final b = _box();
      return b.isOpen ? b : null;
    } catch (_) {
      return null;
    }
  }

  @override
  String? get(String key) => _safe?.get(key);
  @override
  Future<void> put(String key, String value) async => _safe?.put(key, value);
  @override
  Future<void> delete(String key) async => _safe?.delete(key);
  @override
  Iterable<String> get keys => _safe?.keys.cast<String>().toList() ?? const [];
  @override
  bool get isOpen => _safe != null;
}