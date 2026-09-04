import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/ble_manager.dart';
import '../services/peer_service.dart';
import '../theme/app_theme.dart';

/// Live view of the mesh: links, routes, store-and-forward queue, counters.
class MeshMapScreen extends StatelessWidget {
  const MeshMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text('Mesh diagnostics', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Consumer2<PeerService, BleManager>(
        builder: (context, peers, ble, _) {
          final router = peers.meshRouter;
          final store = peers.meshStore;
          return ListenableBuilder(
            listenable: Listenable.merge([router, store]),
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.9,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    _stat('BLE links', '${ble.linkCount}', AppTheme.accentBlue),
                    _stat('Known routes', '${router.knownRoutes}', AppTheme.accentPurple),
                    _stat('Stored packets', '${store.packetCount}', AppTheme.warning),
                    _stat('Delivered to me', '${router.totalDelivered}', AppTheme.accentGreen),
                    _stat('Received', '${router.totalReceived}', AppTheme.textSecondary),
                    _stat('Forwarded', '${router.totalForwarded}', AppTheme.textSecondary),
                    _stat('Duplicates dropped', '${router.totalDuplicates}', AppTheme.textMuted),
                    _stat('Seen ids', '${store.seenCount}', AppTheme.textMuted),
                  ],
                ),
                const SizedBox(height: 24),
                _title('Links'),
                if (ble.links.isEmpty) _hint('No Bluetooth links. Devices within range link automatically while scanning and advertising are on.'),
                ...ble.links.map((l) => _tile(
                      Icons.bluetooth_connected_rounded,
                      l.nyxId ?? l.address,
                      '${l.isCentralRole ? 'we dialled' : 'they dialled'} · MTU ${l.mtu} · ${l.address}',
                      AppTheme.accentBlue,
                    )),
                _tile(Icons.wifi_tethering_rounded, 'Wi-Fi Aware', peers.awareManager.statusText,
                    peers.isAwareActive ? AppTheme.accentGreen : AppTheme.textMuted),
                const SizedBox(height: 20),
                _title('Routing table'),
                if (router.routingTable.isEmpty) _hint('Routes are learned from the path recorded in every packet and from periodic beacons.'),
                ...router.routingTable.entries.map((e) => _tile(
                      Icons.alt_route_rounded,
                      'token ${e.key.substring(0, 12)}...',
                      'via relay ${e.value.nextHopHex}... · ${e.value.hopCount} hops',
                      AppTheme.accentPurple,
                    )),
                const SizedBox(height: 20),
                _title('How it works'),
                _hint('Packets are addressed by SHA-256 hashes and carry an end-to-end encrypted envelope. '
                    'A relay stores each packet, forwards it to the learned next hop or sprays up to '
                    '${router.sprayCount} copies, and drops it after ${router.defaultTtl} hops or 24 hours. '
                    'Relays cannot read, alter or re-address what they carry.'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.glassDecoration(opacity: 0.04, borderRadius: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
      );

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t.toUpperCase(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
      );

  Widget _hint(String t) => Text(t, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4));

  Widget _tile(IconData icon, String title, String subtitle, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.glassDecoration(opacity: 0.03, borderRadius: 12),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: 'monospace')),
            Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ])),
        ]),
      );
}