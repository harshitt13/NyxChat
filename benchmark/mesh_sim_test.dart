// Mesh delivery simulator.
//
// Drives the real MeshRouter/MeshStore classes with synthetic mobility to
// measure delivery ratio, latency and overhead of the store-and-forward
// mesh under different node densities and routing strategies.
//
// Run:  flutter test benchmark/mesh_sim_test.dart --dart-define=SIM_SEEDS=5 --dart-define=SIM_NODES=10,20,40,80
// Output: build/mesh_sim.csv
//
// The simulation is discrete-time (1 tick = 1 second). Nodes move with a
// random-waypoint model inside a square arena; two nodes are neighbours when
// within BLE range. Each tick every node forwards packets its router emitted
// to current neighbours (spray or learned next hop). Messages are injected
// between random pairs during the first third of the run.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/mesh/mesh_packet.dart';
import 'package:nyxchat/core/mesh/mesh_router.dart';
import 'package:nyxchat/core/mesh/mesh_store.dart';

class SimNode {
  final String id;
  final MeshRouter router;
  final MeshStore store;
  double x, y, tx, ty, speed;
  final List<(MeshPacket, String?)> outbox = [];
  SimNode(this.id, this.router, this.store, this.x, this.y, this.tx, this.ty, this.speed);
}

class Result {
  final String strategy;
  final int nodes;
  final int seed;
  final int sent;
  final int delivered;
  final double meanLatency;
  final double p95Latency;
  final int transmissions;
  final double meanStore;
  Result(this.strategy, this.nodes, this.seed, this.sent, this.delivered,
      this.meanLatency, this.p95Latency, this.transmissions, this.meanStore);
  double get ratio => sent == 0 ? 0 : delivered / sent;
  double get overhead => delivered == 0 ? 0 : transmissions / delivered;
  String csv() =>
      '$strategy,$nodes,$seed,$sent,$delivered,${ratio.toStringAsFixed(4)},'
      '${meanLatency.toStringAsFixed(2)},${p95Latency.toStringAsFixed(2)},'
      '$transmissions,${overhead.toStringAsFixed(2)},${meanStore.toStringAsFixed(1)}';
}

Future<Result> run({
  required String strategy, // 'spray' | 'epidemic' | 'direct'
  required int nodeCount,
  required int seed,
  int ticks = 1800,
  double arena = 600,
  double range = 40,
  int messages = 60,
}) async {
  final rng = Random(seed);
  final nodes = <SimNode>[];
  for (var i = 0; i < nodeCount; i++) {
    final store = MeshStore(maxPackets: 500);
    final router = MeshRouter(
      store: store,
      defaultTtl: strategy == 'direct' ? 1 : 7,
      sprayCount: strategy == 'epidemic' ? 1 << 20 : 3,
    );
    final id = 'NC-${i.toRadixString(16).padLeft(16, '0').toUpperCase()}';
    await router.init(id);
    final n = SimNode(id, router, store, rng.nextDouble() * arena,
        rng.nextDouble() * arena, rng.nextDouble() * arena,
        rng.nextDouble() * arena, 0.5 + rng.nextDouble() * 1.5);
    router.onForwardPacket = (p, next) => n.outbox.add((p, next));
    nodes.add(n);
  }
  final byHash = <String, SimNode>{};
  for (final n in nodes) {
    byHash[n.router.myHash!] = n;
  }

  final sentAt = <String, int>{};
  final deliveredAt = <String, int>{};
  var transmissions = 0;
  var storeSamples = 0.0;
  var storeCount = 0;

  for (final n in nodes) {
    n.router.onPacketForMe = (p) {
      final key = utf8.decode(p.payload);
      deliveredAt.putIfAbsent(key, () => currentTick);
    };
  }

  for (currentTick = 0; currentTick < ticks; currentTick++) {
    // Mobility
    for (final n in nodes) {
      final dx = n.tx - n.x, dy = n.ty - n.y;
      final d = sqrt(dx * dx + dy * dy);
      if (d < n.speed) {
        n.tx = rng.nextDouble() * arena;
        n.ty = rng.nextDouble() * arena;
      } else {
        n.x += dx / d * n.speed;
        n.y += dy / d * n.speed;
      }
    }
    // Inject traffic in the first third of the run.
    if (currentTick < ticks ~/ 3 && sentAt.length < messages &&
        currentTick % max(1, (ticks ~/ 3) ~/ messages) == 0) {
      final a = nodes[rng.nextInt(nodes.length)];
      var b = nodes[rng.nextInt(nodes.length)];
      while (identical(a, b)) {
        b = nodes[rng.nextInt(nodes.length)];
      }
      final key = 'm${sentAt.length}';
      sentAt[key] = currentTick;
      await a.router.send(recipientId: b.id, payload: Uint8List.fromList(utf8.encode(key)));
    }
    // Neighbour exchange: flush outboxes and offer stored packets on contact.
    for (final n in nodes) {
      final neighbours = nodes.where((m) => !identical(n, m) &&
          (n.x - m.x) * (n.x - m.x) + (n.y - m.y) * (n.y - m.y) <= range * range).toList();
      if (neighbours.isEmpty) {
        n.outbox.clear();
        continue;
      }
      final pending = List.of(n.outbox);
      n.outbox.clear();
      for (final (packet, nextHop) in pending) {
        final targets = nextHop != null && byHash[nextHop] != null && neighbours.contains(byHash[nextHop])
            ? [byHash[nextHop]!]
            : (strategy == 'epidemic' ? neighbours : neighbours.take(n.router.sprayCount).toList());
        for (final t in targets) {
          transmissions++;
          await t.router.handlePacket(packet);
        }
      }
      // Spray phase on contact: hand stored packets to neighbours.
      if (currentTick % 5 == 0) {
        for (final packet in n.router.getPacketsForNewPeer()) {
          for (final t in neighbours.take(strategy == 'epidemic' ? neighbours.length : 1)) {
            transmissions++;
            await t.router.handlePacket(packet);
          }
        }
      }
    }
    if (currentTick % 60 == 0) {
      storeSamples += nodes.fold<int>(0, (s, n) => s + n.store.packetCount) / nodes.length;
      storeCount++;
    }
  }

  final latencies = <int>[
    for (final e in deliveredAt.entries) e.value - (sentAt[e.key] ?? 0)
  ]..sort();
  final mean = latencies.isEmpty ? 0.0 : latencies.reduce((a, b) => a + b) / latencies.length;
  final p95 = latencies.isEmpty ? 0.0 : latencies[(latencies.length * 0.95).floor().clamp(0, latencies.length - 1)].toDouble();
  for (final n in nodes) {
    n.router.dispose();
  }
  return Result(strategy, nodeCount, seed, sentAt.length, deliveredAt.length,
      mean, p95, transmissions, storeCount == 0 ? 0 : storeSamples / storeCount);
}

int currentTick = 0;

void main() {
  test('mesh delivery simulation', () async {
    const seedsEnv = String.fromEnvironment('SIM_SEEDS', defaultValue: '3');
    const nodesEnv = String.fromEnvironment('SIM_NODES', defaultValue: '10,20,40');
    final seeds = int.parse(seedsEnv);
    final nodeCounts = nodesEnv.split(',').map(int.parse).toList();
    final lines = <String>[
      'strategy,nodes,seed,sent,delivered,ratio,mean_latency_s,p95_latency_s,transmissions,overhead,mean_store'
    ];
    for (final strategy in const ['direct', 'spray', 'epidemic']) {
      for (final n in nodeCounts) {
        for (var s = 0; s < seeds; s++) {
          final r = await run(strategy: strategy, nodeCount: n, seed: s);
          lines.add(r.csv());
          // ignore: avoid_print
          print(r.csv());
        }
      }
    }
    await Directory('build').create(recursive: true);
    await File('build/mesh_sim.csv')
        .writeAsString('${lines.join('\n')}\n');
    expect(lines.length, greaterThan(1));
  }, timeout: const Timeout(Duration(hours: 2)));
}
