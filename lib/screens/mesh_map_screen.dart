import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/ble_manager.dart';
import '../l10n/l10n_context.dart';
import '../services/peer_service.dart';
import '../theme/app_theme.dart';

/// Live view of the mesh: links, routes, store-and-forward queue, counters.
class MeshMapScreen extends StatelessWidget {
  const MeshMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nyx.background,
      appBar: AppBar(
        backgroundColor: context.nyx.background,
        elevation: 0,
        title: Text(context.l10n.meshDiagnostics, style: TextStyle(color: context.nyx.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
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
                    _stat(context, context.l10n.statBleLinks, '${ble.linkCount}', context.nyx.accentBlue),
                    _stat(context, context.l10n.statKnownRoutes, '${router.knownRoutes}', context.nyx.accentPurple),
                    _stat(context, context.l10n.statStoredPackets, '${store.packetCount}', context.nyx.warning),
                    _stat(context, context.l10n.statDeliveredToMe, '${router.totalDelivered}', context.nyx.accentGreen),
                    _stat(context, context.l10n.statReceived, '${router.totalReceived}', context.nyx.textSecondary),
                    _stat(context, context.l10n.statForwarded, '${router.totalForwarded}', context.nyx.textSecondary),
                    _stat(context, context.l10n.statDuplicatesDropped, '${router.totalDuplicates}', context.nyx.textMuted),
                    _stat(context, context.l10n.statSeenIds, '${store.seenCount}', context.nyx.textMuted),
                  ],
                ),
                const SizedBox(height: 24),
                _title(context, context.l10n.linksHeader),
                if (ble.links.isEmpty) _hint(context, context.l10n.noBluetoothLinksHint),
                ...ble.links.map((l) => _tile(
                      context,
                      Icons.bluetooth_connected_rounded,
                      l.nyxId ?? l.address,
                      context.l10n.linkSubtitle(l.isCentralRole ? context.l10n.weDialled : context.l10n.theyDialled, l.mtu, l.address),
                      context.nyx.accentBlue,
                    )),
                _tile(context, Icons.wifi_tethering_rounded, 'Wi-Fi Aware', peers.awareManager.statusText,
                    peers.isAwareActive ? context.nyx.accentGreen : context.nyx.textMuted),
                const SizedBox(height: 20),
                _title(context, context.l10n.routingTableHeader),
                if (router.routingTable.isEmpty) _hint(context, context.l10n.routingTableHint),
                ...router.routingTable.entries.map((e) => _tile(
                      context,
                      Icons.alt_route_rounded,
                      context.l10n.routeToken(e.key.substring(0, 12)),
                      context.l10n.routeVia(e.value.nextHopHex, e.value.hopCount),
                      context.nyx.accentPurple,
                    )),
                const SizedBox(height: 20),
                _title(context, context.l10n.howItWorksHeader),
                _hint(context, context.l10n.meshExplanation(router.sprayCount, router.defaultTtl)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: context.nyx.glass(opacity: 0.04, borderRadius: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
        ]),
      );

  Widget _title(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t.toUpperCase(), style: TextStyle(color: context.nyx.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
      );

  Widget _hint(BuildContext context, String t) => Text(t, style: TextStyle(color: context.nyx.textMuted, fontSize: 12, height: 1.4));

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: context.nyx.glass(opacity: 0.03, borderRadius: 12),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: context.nyx.textPrimary, fontSize: 13, fontFamily: 'monospace')),
            Text(subtitle, style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
          ])),
        ]),
      );
}