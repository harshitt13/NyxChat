import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Represents a piece of a fragmented file transfer.
class FileChunk {
  final String fileId;
  final int chunkIndex;
  final int totalChunks;
  final Uint8List data;

  FileChunk({
    required this.fileId,
    required this.chunkIndex,
    required this.totalChunks,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'fileId': fileId,
        'chunkIndex': chunkIndex,
        'totalChunks': totalChunks,
        'dataB64': base64Encode(data),
      };

  factory FileChunk.fromJson(Map<String, dynamic> json) {
    return FileChunk(
      fileId: json['fileId'] as String,
      chunkIndex: json['chunkIndex'] as int,
      totalChunks: json['totalChunks'] as int,
      data: base64Decode(json['dataB64'] as String),
    );
  }
}

/// Tracks the assembly state of an incoming chunked file transfer.
class TransferState {
  final String fileId;
  final int totalChunks;
  final Map<int, Uint8List> receivedChunks = {};
  DateTime lastUpdated = DateTime.now();

  TransferState(this.fileId, this.totalChunks);

  bool get isComplete => receivedChunks.length == totalChunks;
  double get progress => totalChunks == 0 ? 0 : receivedChunks.length / totalChunks;

  Uint8List assemble() {
    if (!isComplete) throw Exception('File not fully received');
    
    // Calculate total size
    int totalSize = 0;
    for (int i = 0; i < totalChunks; i++) {
      totalSize += receivedChunks[i]!.length;
    }

    // Assemble bytes
    final assembled = Uint8List(totalSize);
    int offset = 0;
    for (int i = 0; i < totalChunks; i++) {
      final chunk = receivedChunks[i]!;
      assembled.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return assembled;
  }
}

/// Handles slicing large files into resilient chunks for unstable mesh networks.
/// Allows for partial transfers that can resume when peers reconnect.
class FileTransferManager extends ChangeNotifier {
  // Config
  static const int chunkSize = 50 * 1024; // 50KB per chunk for BLE stability

  // Active incoming transfers tracked by File ID
  final Map<String, TransferState> _incomingTransfers = {};

  // Active outgoing transfers tracked by File ID
  final Map<String, List<FileChunk>> _outgoingTransfers = {};

  /// Convert raw bytes into an outgoing chunk list.
  List<FileChunk> sliceFile(String fileId, Uint8List rawBytes) {
    final int totalChunks = (rawBytes.length / chunkSize).ceil();
    final List<FileChunk> chunks = [];

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < rawBytes.length) ? start + chunkSize : rawBytes.length;
      final chunkData = rawBytes.sublist(start, end);

      chunks.add(FileChunk(
        fileId: fileId,
        chunkIndex: i,
        totalChunks: totalChunks,
        data: chunkData,
      ));
    }

    _outgoingTransfers[fileId] = chunks;
    return chunks;
  }

  /// Process an incoming chunk. Returns assembled bytes if completed, else null.
  Uint8List? receiveChunk(FileChunk chunk) {
    var state = _incomingTransfers[chunk.fileId];
    if (state == null) {
      state = TransferState(chunk.fileId, chunk.totalChunks);
      _incomingTransfers[chunk.fileId] = state;
    }

    state.receivedChunks[chunk.chunkIndex] = chunk.data;
    state.lastUpdated = DateTime.now();
    
    notifyListeners();

    if (state.isComplete) {
      final assembled = state.assemble();
      _incomingTransfers.remove(chunk.fileId); // Cleanup
      return assembled;
    }

    return null;
  }

  /// Check which chunks are missing to request a resume over the mesh.
  List<int> getMissingChunkIndices(String fileId) {
    final state = _incomingTransfers[fileId];
    if (state == null) return [];

    final missing = <int>[];
    for (int i = 0; i < state.totalChunks; i++) {
      if (!state.receivedChunks.containsKey(i)) {
        missing.add(i);
      }
    }
    return missing;
  }

  double getProgress(String fileId) {
    return _incomingTransfers[fileId]?.progress ?? 0.0;
  }

  void cleanupStaleTransfers() {
    final now = DateTime.now();
    _incomingTransfers.removeWhere((key, state) {
      // Drop broken transfers older than 24 hours
      return now.difference(state.lastUpdated).inHours > 24;
    });
    // Also clean up outgoing transfer records
    _outgoingTransfers.removeWhere((key, _) {
      // Remove completed outgoing records (they're only used for slicing)
      return !_incomingTransfers.containsKey(key);
    });
  }
}
