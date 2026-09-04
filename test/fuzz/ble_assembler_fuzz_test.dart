import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/network/ble_protocol.dart';

import 'fuzz_support.dart';

Uint8List _chunk(int seq, int flags, int payloadLength) {
  final c = Uint8List(BleProtocol.headerSize + payloadLength);
  c[0] = seq & 0xff;
  c[1] = flags;
  return c;
}

void main() {
  final seed = fuzzSeed();

  test('BlePacketAssembler never throws or exceeds the cap on random chunks',
      () {
    printOnFailure('FUZZ_SEED=$seed');
    final f = Fuzzer(seed);
    final asm = BlePacketAssembler();
    var assembled = 0;
    for (var i = 0; i < 5000; i++) {
      final len = f.chance(0.1) ? f.nextInt(3) : 2 + f.nextInt(600);
      final chunk = f.bytes(len);
      if (len >= 2 && f.chance(0.7)) chunk[1] = f.pick(const [0, 1, 2, 3]);
      Uint8List? out;
      try {
        out = asm.addChunk(chunk);
      } catch (e, st) {
        fail('seed=$seed iteration=$i: addChunk threw ${e.runtimeType}: '
            '$e\n$st');
      }
      if (out != null) {
        assembled++;
        expect(out.length,
            lessThanOrEqualTo(BlePacketAssembler.maxAssembledBytes),
            reason: 'seed=$seed iteration=$i');
      }
    }
    printOnFailure('assembled=$assembled');
    // A genuine message still assembles afterwards.
    final data = f.bytes(5000);
    Uint8List? result;
    for (final c in BleProtocol.chunkMessage(data, mtu: 100)) {
      result = asm.addChunk(c);
    }
    expect(result, data);
  });

  test('a stream of middle chunks past the cap is dropped; recovery works',
      () {
    final f = Fuzzer(seed);
    final asm = BlePacketAssembler();
    expect(asm.addChunk(_chunk(0, BleProtocol.flagFirst, 500)), isNull);
    for (var i = 1; i <= 200; i++) {
      // 100 KB of continuation chunks: well past the 64 KB cap.
      expect(asm.addChunk(_chunk(i, 0, 500)), isNull);
    }
    expect(asm.addChunk(_chunk(201, BleProtocol.flagLast, 500)), isNull,
        reason: 'an oversized message must be dropped, not delivered');

    // Exactly the cap fits; one byte more does not.
    final atCap = f.bytes(BlePacketAssembler.maxAssembledBytes);
    Uint8List? result;
    for (final c in BleProtocol.chunkMessage(atCap, mtu: 512)) {
      result = asm.addChunk(c);
    }
    expect(result, atCap);
    result = null;
    final over = f.bytes(BlePacketAssembler.maxAssembledBytes + 1);
    for (final c in BleProtocol.chunkMessage(over, mtu: 512)) {
      result = asm.addChunk(c);
    }
    expect(result, isNull);

    // Short, header-only and stray chunks are ignored, never errors.
    expect(asm.addChunk(Uint8List(0)), isNull);
    expect(asm.addChunk(Uint8List(1)), isNull);
    expect(asm.addChunk(_chunk(7, BleProtocol.flagLast, 8)), isNull,
        reason: 'a stray last chunk must not produce a message');
    expect(asm.addChunk(_chunk(8, 0, 8)), isNull);

    // Single-chunk messages, including an empty one, still work.
    expect(asm.addChunk(_chunk(0, BleProtocol.flagSingle, 3)), hasLength(3));
    expect(asm.addChunk(_chunk(0, BleProtocol.flagSingle, 0)), isEmpty);

    // A new first chunk abandons a partial message.
    asm.addChunk(_chunk(0, BleProtocol.flagFirst, 4));
    final small = f.bytes(30);
    for (final c in BleProtocol.chunkMessage(small, mtu: 20)) {
      result = asm.addChunk(c);
    }
    expect(result, small);
  });
}
