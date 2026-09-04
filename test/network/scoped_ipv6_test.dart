// Establishes, on the host running the tests, the addressing facts the
// Wi-Fi Aware transport depends on: Dart parses and dials link-local IPv6
// with a numeric interface scope, which is what WifiAwarePath.dialAddress
// produces from the interface index the native side reports.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('link-local literals with a numeric scope parse', () {
    final a = InternetAddress('fe80::1%12');
    expect(a.type, InternetAddressType.IPv6);
    expect(a.isLinkLocal, isTrue);
    expect(InternetAddress.tryParse('fe80::1'), isNotNull);
    // A name as the scope is resolver-dependent (Linux/Android know it, not
    // every host does): record what this host does without failing on it.
    final byName = InternetAddress.tryParse('fe80::1%wlan0');
    printOnFailure('fe80::1%wlan0 parses on this host: ${byName != null}');
  });

  test('a link-local server is reachable through its scoped address', () async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv6, includeLinkLocal: true);
    final candidates = [
      for (final i in interfaces)
        for (final a in i.addresses)
          if (a.isLinkLocal) (i, a),
    ];
    if (candidates.isEmpty) {
      markTestSkipped('no link-local IPv6 interface on this host');
      return;
    }
    final failures = <String>[];
    var connected = false;
    for (final (iface, addr) in candidates) {
      ServerSocket? server;
      try {
        server = await ServerSocket.bind(addr, 0);
        server.listen((c) {
          c.add([0x4E, 0x58]);
          c.close();
        });
        final scoped = '${addr.address.split('%').first}%${iface.index}';
        final socket = await Socket.connect(scoped, server.port, timeout: const Duration(seconds: 3));
        final bytes = await socket.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
        socket.destroy();
        expect(bytes, [0x4E, 0x58]);
        connected = true;
        break;
      } catch (e) {
        failures.add('${iface.name}#${iface.index}: $e');
      } finally {
        await server?.close();
      }
    }
    expect(connected, isTrue, reason: 'no scoped link-local connect succeeded:\n${failures.join('\n')}');
  });
}