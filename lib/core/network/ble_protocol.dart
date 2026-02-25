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
class BlePacketAssembler {
  final List<Uint8List> _chunks = [];
  bool _receiving = false;

  /// Feed a raw chunk. Returns the complete message when all chunks received,
  /// or null if still waiting for more.
  Uint8List? addChunk(Uint8List chunk) {
    if (chunk.length < BleProtocol.headerSize) return null;

    final flags = chunk[1];
    final payload = chunk.sublist(BleProtocol.headerSize);

    if (flags == BleProtocol.flagSingle) {
      // Single chunk message
      _chunks.clear();
      _receiving = false;
      return Uint8List.fromList(payload);
    }

    if (flags & BleProtocol.flagFirst != 0) {
      // Start of multi-chunk message
      _chunks.clear();
      _receiving = true;
    }

    if (_receiving) {
      _chunks.add(payload);
    }

    if (flags & BleProtocol.flagLast != 0) {
      // Last chunk — assemble
      _receiving = false;
      final total =
          _chunks.fold<int>(0, (sum, c) => sum + c.length);
      final assembled = Uint8List(total);
      int offset = 0;
      for (final c in _chunks) {
        assembled.setRange(offset, offset + c.length, c);
        offset += c.length;
      }
      _chunks.clear();
      return assembled;
    }

    return null;
  }

  /// Reset assembler state.
  void reset() {
    _chunks.clear();
    _receiving = false;
  }
}
