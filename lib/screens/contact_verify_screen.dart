import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/crypto/nyx_id.dart';
import '../core/storage/trust_store.dart';
import '../services/chat_service.dart';
import '../services/identity_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

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
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            elevation: 0,
            title: Text(peer?.displayName ?? widget.peerId,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          body: peer == null
              ? const Center(child: Text('Contact not pinned yet', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _header(peer),
                    const SizedBox(height: 20),
                    _section('Safety number'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassDecoration(opacity: 0.04, borderRadius: 14),
                      child: Column(children: [
                        if (_safetyNumber == null)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(color: AppTheme.accentBlue),
                          )
                        else
                          _safetyGrid(_safetyNumber!),
                        const SizedBox(height: 12),
                        const Text(
                          'Both of you see the same number if nobody is intercepting the connection. '
                          'Compare it in person, by phone, or through another channel you trust.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: _button(
                          peer.verified ? 'Verified' : 'Mark as verified',
                          icon: peer.verified ? Icons.verified_rounded : Icons.verified_outlined,
                          color: peer.verified ? AppTheme.accentGreen : AppTheme.accentBlue,
                          onTap: () => trust.setVerified(peer.nyxChatId, !peer.verified),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _button('Message', icon: Icons.chat_bubble_outline_rounded,
                            color: AppTheme.textSecondary, onTap: () => _openChat(peer)),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _section('Their fingerprint'),
                    _mono(_theirFingerprint ?? '...'),
                    const SizedBox(height: 14),
                    _section('Your fingerprint'),
                    _mono(_myFingerprint ?? '...'),
                    const SizedBox(height: 24),
                    _section('Show them your contact card'),
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
                    const Text(
                      'Contains only your public keys. Scanning or pasting it pins your identity on their device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 24),
                    _section('Details'),
                    _detail('NyxChat ID', peer.nyxChatId),
                    _detail('Handshake', 'X25519 + Kyber-768 hybrid, Ed25519 signed'),
                    _detail('Messages', 'Double Ratchet, AES-256-GCM'),
                    _detail('First seen', peer.firstSeen.toLocal().toString().substring(0, 16)),
                    if (peer.keyChangedAt != null)
                      _detail('Keys changed', peer.keyChangedAt!.toLocal().toString().substring(0, 16)),
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
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Center(
            child: Icon(peer.verified ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                color: peer.verified ? AppTheme.accentGreen : AppTheme.textSecondary, size: 28),
          ),
        ),
        const SizedBox(height: 10),
        Text(peer.displayName,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: peer.nyxChatId));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID copied')));
          },
          child: Text(peer.nyxChatId,
              style: const TextStyle(color: AppTheme.accentBlue, fontSize: 13, fontFamily: 'monospace')),
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
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontFamily: 'monospace', letterSpacing: 1)),
              ))
          .toList(),
    );
  }

  Widget _section(String t) => Text(t,
      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1));

  Widget _mono(String t) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(t, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace', height: 1.5)),
      );

  Widget _detail(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
          Expanded(child: Text(v, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
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