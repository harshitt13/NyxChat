// Unit tests for the Dart side of the Wi-Fi Aware transport against a fake
// platform channel: lifecycle, beacon rotation, beacon gating (public and
// private), path events and the unsupported case.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/network/discovery_beacon.dart';
import 'package:nyxchat/core/network/wifi_aware_manager.dart';

const _method = MethodChannel('nyxchat/wifi_aware');
const _events = EventChannel('nyxchat/wifi_aware/events');

/// Stands in for WifiAwareChannel.kt: records calls, answers like the native
/// side and lets a test push events.
class FakeAwareChannel {
  final List<MethodCall> calls = [];
  bool supported = true;
  bool startResult = true;
  MockStreamHandlerEventSink? _sink;

  void install() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_method, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isSupported':
          return supported;
        case 'start':
          if (!supported) throw PlatformException(code: 'unsupported');
          return startResult;
        case 'updateBeacon':
        case 'openPath':
        case 'closePath':
        case 'stop':
          return true;
      }
      return null;
    });
    messenger.setMockStreamHandler(
      _events,
      MockStreamHandler.inline(
        onListen: (_, sink) => _sink = sink,
        onCancel: (_) => _sink = null,
      ),
    );
  }

  void uninstall() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_method, null);
    messenger.setMockStreamHandler(_events, null);
  }

  bool get listening => _sink != null;
  List<String> get methods => calls.map((c) => c.method).toList();
  Iterable<MethodCall> named(String m) => calls.where((c) => c.method == m);

  Future<void> emit(Map<String, Object?> event) async {
    expect(_sink, isNotNull, reason: 'Dart is not listening on the event channel');
    _sink!.success(event);
    await pumpEventQueue();
  }
}

Uint8List _public(String id) => DiscoveryBeacon.public(id).encodeBle();
Uint8List _private(Uint8List bloom) => DiscoveryBeacon.private(bloom).encodeBle();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAwareChannel fake;
  late WifiAwareManager manager;
  const me = 'NC-0000000000000001';
  const bigger = 'NC-ffffffffffffffff';
  const smaller = 'NC-0000000000000000';
  final beacon = Uint8List.fromList(List.generate(19, (i) => i));

  setUp(() {
    fake = FakeAwareChannel()..install();
    manager = WifiAwareManager();
  });

  tearDown(() async {
    await manager.stop();
    fake.uninstall();
  });

  Future<void> started() async {
    await manager.init();
    expect(await manager.start(me, beacon: beacon, listeningPort: 42420), isTrue);
    await pumpEventQueue();
  }

  group('unsupported platform', () {
    test('init reports unsupported; start, update and stop are clean no-ops', () async {
      fake.supported = false;
      await manager.init();
      expect(manager.isSupported, isFalse);
      expect(manager.statusText, 'Unsupported');
      expect(await manager.start(me, beacon: beacon, listeningPort: 1), isFalse);
      expect(await manager.updateBeacon(beacon), isFalse);
      await manager.stop();
      expect(fake.methods, ['isSupported']);
      expect(manager.isRunning, isFalse);
      expect(fake.listening, isFalse);
    });

    test('a missing plugin is treated as unsupported', () async {
      fake.uninstall();
      await manager.init();
      expect(manager.isSupported, isFalse);
      expect(await manager.start(me, beacon: beacon, listeningPort: 1), isFalse);
    });
  });

  group('lifecycle', () {
    test('start publishes the beacon and port, stop releases', () async {
      await started();
      final start = fake.named('start').single;
      expect(start.arguments['beacon'], beacon);
      expect(start.arguments['port'], 42420);
      expect(manager.isRunning, isTrue);
      expect(fake.listening, isTrue);
      expect(manager.statusText, 'Attaching');
      await manager.stop();
      await pumpEventQueue();
      expect(fake.methods.last, 'stop');
      expect(manager.isRunning, isFalse);
      expect(fake.listening, isFalse);
      expect(manager.statusText, 'Off');
    });

    test('a permission refusal is reported, not thrown', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_method, (call) async {
        if (call.method == 'isSupported') return true;
        throw PlatformException(code: 'permission', message: 'denied');
      });
      await manager.init();
      expect(await manager.start(me, beacon: beacon, listeningPort: 1), isFalse);
      expect(manager.isRunning, isFalse);
      expect(manager.statusText, contains('permission'));
    });

    test('beacon rotation re-publishes', () async {
      await started();
      final next = Uint8List.fromList([4, 2, 9, ...List.filled(16, 0xAB)]);
      expect(await manager.updateBeacon(next), isTrue);
      expect(fake.named('updateBeacon').single.arguments['beacon'], next);
      expect(manager.beacon, next);
    });

    test('state events drive the status line', () async {
      await started();
      await fake.emit({'type': 'state', 'available': false, 'attached': false});
      expect(manager.statusText, 'Wi-Fi off');
      await fake.emit({'type': 'state', 'available': true, 'attached': true});
      expect(manager.statusText, startsWith('Active'));
    });
  });

  group('beacon gating', () {
    test('public beacon of a larger handle: we ask for the path', () async {
      await started();
      await fake.emit({'type': 'discovered', 'peer': 7, 'beacon': _public(bigger), 'role': 'subscriber'});
      expect(fake.named('openPath').single.arguments['peer'], 7);
      expect(manager.nearbyCount, 1);
      expect(manager.discoveredPeers.single.nyxId, bigger);
      expect(manager.discoveredPeers.single.isCandidate, isFalse);
    });

    test('public beacon of a smaller handle: they ask, we wait', () async {
      await started();
      await fake.emit({'type': 'discovered', 'peer': 7, 'beacon': _public(smaller), 'role': 'subscriber'});
      expect(fake.named('openPath'), isEmpty);
      expect(manager.nearbyCount, 1);
    });

    test('a request reaching our publisher is answered whoever is smaller', () async {
      await started();
      await fake.emit({'type': 'discovered', 'peer': 3, 'beacon': _public(smaller), 'role': 'publisher'});
      expect(fake.named('openPath').single.arguments['peer'], 3);
    });

    test('our own beacon and undecodable beacons are ignored', () async {
      await started();
      await fake.emit({'type': 'discovered', 'peer': 1, 'beacon': _public(me), 'role': 'subscriber'});
      await fake.emit({'type': 'discovered', 'peer': 2, 'beacon': Uint8List.fromList([1, 2, 3]), 'role': 'subscriber'});
      expect(fake.named('openPath'), isEmpty);
      expect(manager.nearbyCount, 0);
    });

    test('private beacon: resolved through the callback before any path', () async {
      await started();
      final bloom = Uint8List.fromList(List.generate(16, (i) => 0x80 | i));
      final seen = <(Uint8List, int)>[];
      manager.resolveBeacon = (b, slot) async {
        seen.add((b, slot));
        return [bigger];
      };
      await fake.emit({'type': 'discovered', 'peer': 9, 'beacon': _private(bloom), 'role': 'subscriber'});
      expect(seen.single.$1, bloom);
      expect(seen.single.$2, DiscoveryBeacon.private(bloom).slot);
      expect(fake.named('openPath').single.arguments['peer'], 9);
      expect(manager.discoveredPeers.single.isCandidate, isTrue);
    });

    test('private beacon of a stranger: no path, request refused', () async {
      await started();
      manager.resolveBeacon = (_, _) async => const <String>[];
      final bloom = Uint8List(16);
      await fake.emit({'type': 'discovered', 'peer': 4, 'beacon': _private(bloom), 'role': 'subscriber'});
      await fake.emit({'type': 'discovered', 'peer': 5, 'beacon': _private(bloom), 'role': 'publisher'});
      expect(fake.named('openPath'), isEmpty);
      expect(fake.named('closePath').single.arguments['peer'], 5);
      expect(manager.nearbyCount, 0);
    });

    test('without a resolver private beacons never match', () async {
      await started();
      await fake.emit({'type': 'discovered', 'peer': 4, 'beacon': _private(Uint8List(16)), 'role': 'subscriber'});
      expect(fake.named('openPath'), isEmpty);
    });
  });

  group('paths', () {
    test('a path event becomes a scoped dial address', () async {
      await started();
      final paths = <WifiAwarePath>[];
      manager.onPeerPath.listen(paths.add);
      await fake.emit({'type': 'discovered', 'peer': 7, 'beacon': _public(bigger), 'role': 'subscriber'});
      await fake.emit({
        'type': 'path', 'peer': 7, 'address': 'fe80::1a2b:3c4d:5e6f:7a8b', 'port': 42420,
        'iface': 'aware_data0', 'ifaceIndex': 31,
      });
      final p = paths.single;
      expect(p.nyxId, bigger);
      expect(p.dialAddress, 'fe80::1a2b:3c4d:5e6f:7a8b%31');
      expect(p.port, 42420);
      expect(manager.pathCount, 1);
      expect(manager.pathForNyxId(bigger), same(p));
      expect(manager.isAwareAddress('fe80::1a2b:3c4d:5e6f:7a8b%aware_data0'), isTrue);
      expect(manager.isAwareAddress('FE80::1A2B:3C4D:5E6F:7A8B'), isTrue);
      expect(manager.isAwareAddress('192.168.1.5'), isFalse);
      await fake.emit({'type': 'lost', 'peer': 7});
      expect(manager.pathCount, 0);
      expect(manager.isAwareAddress('fe80::1a2b:3c4d:5e6f:7a8b'), isFalse);
    });

    test('scope falls back to the interface name; none for global addresses', () {
      const byName = WifiAwarePath(
          peer: 1, nyxId: 'x', isCandidate: false, address: 'fe80::1', port: 1, iface: 'wlan0', ifaceIndex: 0);
      expect(byName.dialAddress, 'fe80::1%wlan0');
      const global = WifiAwarePath(
          peer: 1, nyxId: 'x', isCandidate: false, address: '2001:db8::1', port: 1, iface: 'wlan0', ifaceIndex: 3);
      expect(global.dialAddress, '2001:db8::1');
    });

    test('a path for a peer we never accepted is closed', () async {
      await started();
      final paths = <WifiAwarePath>[];
      manager.onPeerPath.listen(paths.add);
      await fake.emit({'type': 'path', 'peer': 99, 'address': 'fe80::9', 'port': 5, 'iface': 'aware_data0', 'ifaceIndex': 2});
      expect(paths, isEmpty);
      expect(fake.named('closePath').single.arguments['peer'], 99);
    });

    test('stop forgets peers and paths', () async {
      await started();
      await fake.emit({'type': 'discovered', 'peer': 7, 'beacon': _public(bigger), 'role': 'subscriber'});
      await fake.emit({'type': 'path', 'peer': 7, 'address': 'fe80::1', 'port': 1, 'iface': 'aware_data0', 'ifaceIndex': 2});
      await manager.stop();
      expect(manager.pathCount, 0);
      expect(manager.nearbyCount, 0);
      expect(manager.isAwareAddress('fe80::1'), isFalse);
    });
  });
}