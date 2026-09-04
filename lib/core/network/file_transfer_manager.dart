import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../crypto/crypto_utils.dart';

/// Description of an outgoing/incoming file transfer. Sent to the
/// recipient inside the Double Ratchet; the chunks themselves travel
/// outside it, each sealed with the per-file key.
class FileDescriptor {
  final String fileId;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final Uint8List key;
  final Uint8List noncePrefix; // 8 bytes; chunk nonce = prefix || index
  final int totalChunks;
  final int chunkSize;
  final String sha256Hex;

  FileDescriptor({
    required this.fileId,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.key,
    required this.noncePrefix,
    required this.totalChunks,
    required this.chunkSize,
    required this.sha256Hex,
  });

  factory FileDescriptor.fromInnerBody(Map<String, dynamic> b) {
    final key = base64Decode(b['key'] as String);
    final nonce = base64Decode(b['nonce'] as String);
    final chunks = b['chunks'];
    final size = b['size'];
    final chunkSize = b['chunkSize'];
    if (key.length != 32 || nonce.length != 8) {
      throw const FormatException('bad file key material');
    }
    if (chunks is! int || chunks < 0 || chunks > 1 << 20 ||
        size is! int || size < 0 || size > FileTransferManager.maxFileBytes ||
        chunkSize is! int || chunkSize <= 0 || chunkSize > FileTransferManager.maxChunkSize) {
      throw const FormatException('bad file descriptor');
    }
    final name = (b['name'] as String).replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
    return FileDescriptor(
      fileId: b['fileId'] as String,
      fileName: name.isEmpty ? 'file' : name,
      mimeType: b['mime'] as String,
      fileSize: size,
      key: key,
      noncePrefix: nonce,
      totalChunks: chunks,
      chunkSize: chunkSize,
      sha256Hex: b['sha256'] as String,
    );
  }
}

class FileChunkFrame {
  final String fileId;
  final int index;
  final int total;
  final Uint8List data; // AES-GCM ciphertext || tag

  FileChunkFrame(this.fileId, this.index, this.total, this.data);

  Map<String, dynamic> toJson() =>
      {'fileId': fileId, 'i': index, 'n': total, 'd': base64Encode(data)};

  factory FileChunkFrame.fromJson(Map<String, dynamic> j) {
    final i = j['i'];
    final n = j['n'];
    if (i is! int || n is! int || i < 0 || n <= 0 || i >= n) {
      throw const FormatException('bad chunk index');
    }
    final d = base64Decode(j['d'] as String);
    if (d.length > FileTransferManager.maxChunkSize + 16) {
      throw const FormatException('chunk too large');
    }
    return FileChunkFrame(j['fileId'] as String, i, n, d);
  }
}

/// State of a file being received.
class IncomingTransfer {
  final FileDescriptor descriptor;
  final String tempPath;
  final String finalPath;
  final Set<int> received = {};
  DateTime lastUpdate = DateTime.now();
  RandomAccessFile? _raf;

  IncomingTransfer(this.descriptor, this.tempPath, this.finalPath);

  bool get isComplete => received.length == descriptor.totalChunks;
  double get progress =>
      descriptor.totalChunks == 0 ? 1 : received.length / descriptor.totalChunks;
}

/// Chunked, per-chunk authenticated file transfer with resume support.
class FileTransferManager extends ChangeNotifier {
  static const int chunkSize = 32 * 1024;
  static const int maxChunkSize = 64 * 1024;
  static const int maxFileBytes = 256 * 1024 * 1024;
  static const Duration staleAfter = Duration(hours: 24);

  final Map<String, IncomingTransfer> _incoming = {};

  Map<String, IncomingTransfer> get incoming => Map.unmodifiable(_incoming);

  static Uint8List chunkNonce(Uint8List prefix, int index) =>
      CryptoUtils.concat([prefix, CryptoUtils.int32be(index)]);

  static Uint8List chunkAad(String fileId, int index, int total) =>
      CryptoUtils.lengthPrefixed([
        'NyxChat-File-v3'.codeUnits,
        utf8.encode(fileId),
        CryptoUtils.int32be(index),
        CryptoUtils.int32be(total),
      ]);

  // Sender side

  /// Hash the file and produce a descriptor with fresh key material.
  static Future<FileDescriptor> describe(File file,
      {required String fileId, required String mimeType}) async {
    final size = await file.length();
    if (size > maxFileBytes) throw ArgumentError('file too large');
    final digest = await _sha256File(file);
    final total = size == 0 ? 0 : (size / chunkSize).ceil();
    return FileDescriptor(
      fileId: fileId,
      fileName: file.uri.pathSegments.last,
      mimeType: mimeType,
      fileSize: size,
      key: CryptoUtils.randomBytes(32),
      noncePrefix: CryptoUtils.randomBytes(8),
      totalChunks: total,
      chunkSize: chunkSize,
      sha256Hex: CryptoUtils.toHex(digest),
    );
  }

  /// Read and encrypt one chunk.
  static Future<FileChunkFrame> encryptChunk(
      File file, FileDescriptor d, int index) async {
    final raf = await file.open();
    try {
      await raf.setPosition(index * d.chunkSize);
      final plain = await raf.read(d.chunkSize);
      final ct = await CryptoUtils.aesGcmEncrypt(
        key: d.key,
        nonce: chunkNonce(d.noncePrefix, index),
        plaintext: plain,
        aad: chunkAad(d.fileId, index, d.totalChunks),
      );
      return FileChunkFrame(d.fileId, index, d.totalChunks, ct);
    } finally {
      await raf.close();
    }
  }

  // Receiver side

  Future<void> begin(FileDescriptor d, String finalPath) async {
    if (_incoming.containsKey(d.fileId)) return;
    final tempPath = '$finalPath.part';
    final t = IncomingTransfer(d, tempPath, finalPath);
    await File(tempPath).parent.create(recursive: true);
    t._raf = await File(tempPath).open(mode: FileMode.write);
    await t._raf!.truncate(d.fileSize);
    _incoming[d.fileId] = t;
    notifyListeners();
  }

  bool isExpecting(String fileId) => _incoming.containsKey(fileId);

  /// Decrypt and store one chunk. Returns the transfer when it completes.
  Future<IncomingTransfer?> accept(FileChunkFrame frame) async {
    final t = _incoming[frame.fileId];
    if (t == null) return null;
    final d = t.descriptor;
    if (frame.total != d.totalChunks || frame.index >= d.totalChunks) {
      throw const FormatException('chunk does not match descriptor');
    }
    if (t.received.contains(frame.index)) return null;
    final plain = await CryptoUtils.aesGcmDecrypt(
      key: d.key,
      nonce: chunkNonce(d.noncePrefix, frame.index),
      ciphertextWithTag: frame.data,
      aad: chunkAad(d.fileId, frame.index, d.totalChunks),
    );
    final raf = t._raf!;
    await raf.setPosition(frame.index * d.chunkSize);
    await raf.writeFrom(plain);
    t.received.add(frame.index);
    t.lastUpdate = DateTime.now();
    notifyListeners();
    if (!t.isComplete) return null;

    await raf.flush();
    await raf.close();
    t._raf = null;
    final digest = await _sha256File(File(t.tempPath));
    if (CryptoUtils.toHex(digest) != d.sha256Hex) {
      await File(t.tempPath).delete();
      _incoming.remove(d.fileId);
      throw const FormatException('file hash mismatch');
    }
    await File(t.tempPath).rename(t.finalPath);
    _incoming.remove(d.fileId);
    notifyListeners();
    return t;
  }

  List<int> missingChunks(String fileId) {
    final t = _incoming[fileId];
    if (t == null) return const [];
    return [
      for (var i = 0; i < t.descriptor.totalChunks; i++)
        if (!t.received.contains(i)) i
    ];
  }

  double progress(String fileId) => _incoming[fileId]?.progress ?? 0;

  Future<void> cleanupStale() async {
    final now = DateTime.now();
    final stale = _incoming.entries
        .where((e) => now.difference(e.value.lastUpdate) > staleAfter)
        .toList();
    for (final e in stale) {
      try {
        await e.value._raf?.close();
        await File(e.value.tempPath).delete();
      } catch (_) {}
      _incoming.remove(e.key);
    }
    if (stale.isNotEmpty) notifyListeners();
  }

  static Future<Uint8List> _sha256File(File file) async {
    final bytes = await file.readAsBytes();
    return CryptoUtils.sha256(bytes);
  }
}