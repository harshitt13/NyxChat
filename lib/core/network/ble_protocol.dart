import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE protocol constants and packet framing for NyxChat mesh.
///
/// Uses custom GATT service with two characteristics:
/// - TX: write to send data to a connected peer
/// - RX: subscribe for notifications of incoming data
///
/// Packets are chunked to fit within BLE MTU (~20-512 bytes).
/// Format: [seq:1][flags:1][payload:N]
/// Flags: 0x01 = first chunk, 0x02 = last chunk, 0x03 = single chunk
class BleProtocol {
  // NyxChat BLE Service UUID (custom, deterministic)
  static final Guid serviceUuid =
      Guid('a1b2c3d4-e5f6-7890-abcd-ef0123456789');

  // Characteristic for writing data TO peer
  static final Guid txCharUuid =
      Guid('a1b2c3d4-e5f6-7890-abcd-ef01234567aa');

  // Characteristic for receiving data FROM peer (notifications)
  static final Guid rxCharUuid =
      Guid('a1b2c3d4-e5f6-7890-abcd-ef01234567bb');

  // Advertised manufacturer data prefix (NyxChat identifier)
  static const int manufacturerId = 0x4E58; // "NX" in hex

  // Packet structure
  static const int headerSize = 2; // seq + flags
  static const int defaultMtu = 20;
  static const int maxPacketSize = 65536; // 64KB max message

  /// Upper bound on a reassembled message; larger ones are dropped.
  static const int maxAssembledBytes = 64 * 1024;

  // Flags
  static const int flagFirst = 0x01;
  static const int flagLast = 0x02;
  static const int flagSingle = 0x03; // first + last

  /// Split a message into MTU-sized chunks for BLE transfer.
  static List<Uint8List> chunkMessage(Uint8List data, {int mtu = defaultMtu}) {
    final chunkPayloadSize = mtu - headerSize;
    if (chunkPayloadSize <= 0) return [];

    final chunks = <Uint8List>[];
    int offset = 0;
    int seq = 0;

    while (offset < data.length) {
      final remaining = data.length - offset;
      final payloadSize =
          remaining < chunkPayloadSize ? remaining : chunkPayloadSize;
      final isFirst = offset == 0;
      final isLast = (offset + payloadSize) >= data.length;

      int flags = 0;
      if (isFirst && isLast) {
        flags = flagSingle;
      } else if (isFirst) {
        flags = flagFirst;
      } else if (isLast) {
        flags = flagLast;
      }

      final chunk = Uint8List(headerSize + payloadSize);
      chunk[0] = seq & 0xFF;
      chunk[1] = flags;
      chunk.setRange(headerSize, headerSize + payloadSize,
          data.sublist(offset, offset + payloadSize));

      chunks.add(chunk);
      offset += payloadSize;
      seq++;
    }

    return chunks;
  }

  /// Encode a JSON message to bytes for BLE transmission.
  static Uint8List encodeMessage(Map<String, dynamic> json) {
    final jsonStr = jsonEncode(json);
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  /// Decode bytes received from BLE into a JSON map.
  static Map<String, dynamic>? decodeMessage(Uint8List data) {
    try {
      final jsonStr = utf8.decode(data);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Create the manufacturer data for BLE advertising.
  /// Contains the NyxChat ID hash (first 8 bytes) for discovery.
  static List<int> buildAdvertiseData(String nyxId) {
    final idBytes = utf8.encode(nyxId);
    // Take first 8 bytes of ID as compact identifier
    final compact = idBytes.length > 8 ? idBytes.sublist(0, 8) : idBytes;
    return compact;
  }
}

/// Assembles chunked BLE packets back into complete messages.
///
/// Hostile or corrupt input never throws: chunks shorter than the header
/// are ignored, a message that would grow past [maxAssembledBytes] is
/// dropped (and the assembler reset), and continuation chunks that arrive
/// without a first chunk are discarded.
class BlePacketAssembler {
  /// Largest message this assembler will ever return.
  static const int maxAssembledBytes = BleProtocol.maxAssembledBytes;

  final List<Uint8List> _chunks = [];
  int _size = 0;
  bool _receiving = false;

  /// Feed a raw chunk. Returns the complete message when all chunks have
  /// been received, or null if still waiting (or the chunk was dropped).
  Uint8List? addChunk(Uint8List chunk) {
    if (chunk.length < BleProtocol.headerSize) return null;

    final flags = chunk[1];
    final payloadLength = chunk.length - BleProtocol.headerSize;

    if (flags == BleProtocol.flagSingle) {
      reset();
      if (payloadLength > maxAssembledBytes) return null;
      return chunk.sublist(BleProtocol.headerSize);
    }

    if (flags & BleProtocol.flagFirst != 0) {
      // Start of a multi-chunk message (any partial one is abandoned).
      reset();
      _receiving = true;
    }

    // A continuation without a preceding first chunk is noise.
    if (!_receiving) return null;

    if (_size + payloadLength > maxAssembledBytes) {
      reset();
      return null;
    }
    _chunks.add(chunk.sublist(BleProtocol.headerSize));
    _size += payloadLength;

    if (flags & BleProtocol.flagLast != 0) {
      final assembled = Uint8List(_size);
      var offset = 0;
      for (final c in _chunks) {
        assembled.setRange(offset, offset + c.length, c);
        offset += c.length;
      }
      reset();
      return assembled;
    }

    return null;
  }

  /// Reset assembler state.
  void reset() {
    _chunks.clear();
    _size = 0;
    _receiving = false;
  }
}
