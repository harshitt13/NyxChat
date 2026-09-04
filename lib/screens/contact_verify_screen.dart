import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/crypto/nyx_id.dart';
import '../core/storage/trust_store.dart';
import '../l10n/l10n_context.dart';
import '../services/chat_service.dart';
import '../services/identity_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'scan_card_screen.dart';

/// Safety-number verification for one contact.
class ContactVerifyScreen extends StatefulWidget {
  final String peerId;
  const ContactVerifyScreen({super.key, required this.peerId});
  @override
  State<ContactVerifyScreen> createState() => _ContactVerifyScreenState();
}

class _ContactVerifyScreenState extends State<ContactVerifyScreen> {
  String? _safetyNumber;
  String? _theirFingerprint;
  String? _myFingerprint;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  Future<void> _compute() async {
    final identity = context.read<IdentityService>();
    final peer = context.read<TrustStore>().get(widget.peerId);
    if (peer == null) return;
    final mine = await identity.fingerprint();
    final theirs = await peer.fingerprint();
    final sn = await NyxId.safetyNumber(mine, theirs);
    if (!mounted) return;
    setState(() {
      _safetyNumber = sn;
      _myFingerprint = NyxId.formatFingerprint(mine);
      _theirFingerprint = NyxId.formatFingerprint(theirs);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrustStore>(
      builder: (context, trust, _) {
        final peer = trust.get(widget.peerId);
        return Scaffold(
          backgroundColor: context.nyx.background,
          appBar: AppBar(
            backgroundColor: context.nyx.background,
            elevation: 0,
            title: Text(peer?.displayName ?? widget.peerId,
                style: TextStyle(color: context.nyx.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          body: peer == null
              ? Center(child: Text(context.l10n.contactNotPinnedYet, style: TextStyle(color: context.nyx.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _header(peer),
                    const SizedBox(height: 20),
                    _section(context.l10n.safetyNumber),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: context.nyx.glass(opacity: 0.04, borderRadius: 14),
                      child: Column(children: [
                        if (_safetyNumber == null)
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(color: context.nyx.accentBlue),
                          )
                        else
                          _safetyGrid(_safetyNumber!),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.safetyNumberExplanation,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.nyx.textSecondary, fontSize: 12, height: 1.4),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: _button(
                          peer.verified ? context.l10n.verified : context.l10n.markAsVerified,
                          icon: peer.verified ? Icons.verified_rounded : Icons.verified_outlined,
                          color: peer.verified ? context.nyx.accentGreen : context.nyx.accentBlue,
                          onTap: () => trust.setVerified(peer.nyxChatId, !peer.verified),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _button(context.l10n.messageAction, icon: Icons.chat_bubble_outline_rounded,
                            color: context.nyx.textSecondary, onTap: () => _openChat(peer)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    _button(context.l10n.scanTheirQr, icon: Icons.qr_code_scanner_rounded, color: context.nyx.accentPurple, onTap: () async {
                      final scanned = await Navigator.push<PinnedPeer?>(context, MaterialPageRoute(builder: (_) => const ScanCardScreen()));
                      if (scanned != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                            scanned.nyxChatId == peer.nyxChatId ? context.l10n.verifiedKeysMatch : context.l10n.cardBelongsToOther(scanned.displayName))));
                        await _compute();
                      }
                    }),
                    const SizedBox(height: 24),
                    _section(context.l10n.theirFingerprint),
                    _mono(_theirFingerprint ?? '...'),
                    const SizedBox(height: 14),
                    _section(context.l10n.yourFingerprint),
                    _mono(_myFingerprint ?? '...'),
                    const SizedBox(height: 24),
                    _section(context.l10n.showThemYourCard),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: QrImageView(
                          data: _cardJson(context),
                          size: 200,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.contactCardContainsOnlyPublicKeys,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.nyx.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 24),
                    _section(context.l10n.details),
                    _detail(context.l10n.nyxChatId, peer.nyxChatId),
                    _detail(context.l10n.handshake, context.l10n.handshakeValue),
                    _detail(context.l10n.messages, context.l10n.messagesValue),
                    _detail(context.l10n.firstSeen, _when(peer.firstSeen)),
                    if (peer.keyChangedAt != null)
                      _detail(context.l10n.keysChanged, _when(peer.keyChangedAt!)),
                  ],
                ),
        );
      },
    );
  }

  String _cardJson(BuildContext context) {
    final card = context.read<IdentityService>().contactCard();
    // Compact key=value form keeps the QR small.
    return 'nyx3;${card['id']};${card['name']};${card['ik']};${card['sk']};${card['kpk']}';
  }

  String _when(DateTime t) => DateFormat.yMMMd(Localizations.localeOf(context).toString())
      .add_Hm()
      .format(t.toLocal());

  Future<void> _openChat(PinnedPeer peer) async {
    final chat = context.read<ChatService>();
    final room = await chat.getOrCreateDirectRoom(peerId: peer.nyxChatId, displayName: peer.displayName);
    if (!mounted) return;
    await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: room.id)));
  }

  Widget _header(PinnedPeer peer) => Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: context.nyx.surfaceLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.nyx.hairline(0.06)),
          ),
          child: Center(
            child: Icon(peer.verified ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                color: peer.verified ? context.nyx.accentGreen : context.nyx.textSecondary, size: 28),
          ),
        ),
        const SizedBox(height: 10),
        Text(peer.displayName,
            style: TextStyle(color: context.nyx.textPrimary, fontSize: 18, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: peer.nyxChatId));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.idCopied)));
          },
          child: Text(peer.nyxChatId,
              style: TextStyle(color: context.nyx.accentBlue, fontSize: 13, fontFamily: 'monospace')),
        ),
      ]);

  Widget _safetyGrid(String sn) {
    final groups = sn.split(' ');
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: groups
          .map((g) => Center(
                child: Text(g,
                    style: TextStyle(color: context.nyx.textPrimary, fontSize: 16, fontFamily: 'monospace', letterSpacing: 1)),
              ))
          .toList(),
    );
  }

  Widget _section(String t) => Text(t,
      style: TextStyle(color: context.nyx.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1));

  Widget _mono(String t) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(t, style: TextStyle(color: context.nyx.textPrimary, fontSize: 12, fontFamily: 'monospace', height: 1.5)),
      );

  Widget _detail(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: TextStyle(color: context.nyx.textMuted, fontSize: 12))),
          Expanded(child: Text(v, style: TextStyle(color: context.nyx.textSecondary, fontSize: 12))),
        ]),
      );

  Widget _button(String label, {required IconData icon, required Color color, required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}