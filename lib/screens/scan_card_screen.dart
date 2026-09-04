import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../core/storage/trust_store.dart';
import '../l10n/l10n_context.dart';
import '../theme/app_theme.dart';

/// Parse the compact text form of a contact card.
Map<String, dynamic>? parseContactCard(String raw) {
  final s = raw.trim();
  if (!s.startsWith('nyx3;')) return null;
  final parts = s.split(';');
  if (parts.length != 6) return null;
  return {'nyx': 3, 'id': parts[1], 'name': parts[2], 'ik': parts[3], 'sk': parts[4], 'kpk': parts[5]};
}

/// Camera scanner for contact-card QR codes. Pops with the pinned
/// [PinnedPeer] on success.
class ScanCardScreen extends StatefulWidget {
  const ScanCardScreen({super.key});
  @override
  State<ScanCardScreen> createState() => _ScanCardScreenState();
}

class _ScanCardScreenState extends State<ScanCardScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;
  String? _status;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw == null) continue;
      final card = parseContactCard(raw);
      if (card == null) {
        setState(() => _status = context.l10n.notANyxChatContactCard);
        continue;
      }
      _handled = true;
      try {
        final peer = await context.read<TrustStore>().pinFromContactCard(card, verified: true);
        if (!mounted) return;
        Navigator.pop(context, peer);
      } catch (e) {
        _handled = false;
        if (!mounted) return;
        setState(() => _status = context.l10n.invalidCard('$e'));
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nyx.background,
      appBar: AppBar(
        backgroundColor: context.nyx.background,
        elevation: 0,
        title: Text(context.l10n.scanContactCard, style: TextStyle(color: context.nyx.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: Icon(Icons.flash_on_outlined, color: context.nyx.textSecondary),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),
            Center(
              child: Container(
                width: 240, height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: context.nyx.accentBlue.withValues(alpha: 0.8), width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          color: context.nyx.surface,
          child: Column(children: [
            Text(_status ?? context.l10n.pointCameraHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: _status == null ? context.nyx.textSecondary : context.nyx.warning, fontSize: 13)),
            const SizedBox(height: 6),
            Text(context.l10n.scanningPinsKeys,
                textAlign: TextAlign.center, style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}