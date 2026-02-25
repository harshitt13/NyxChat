import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/identity_service.dart';
import '../services/peer_service.dart';
import '../services/chat_service.dart';
import '../models/peer.dart';
import 'chat_screen.dart';

class PeerDiscoveryScreen extends StatefulWidget {
  const PeerDiscoveryScreen({super.key});

  @override
  State<PeerDiscoveryScreen> createState() => _PeerDiscoveryScreenState();
}

class _PeerDiscoveryScreenState extends State<PeerDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '42420');
  final _dhtBootstrapController = TextEditingController();
  final _dhtLookupController = TextEditingController();
  bool _isDHTStarting = false;
  bool _isLookingUp = false;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _dhtBootstrapController.dispose();
    _dhtLookupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.textPrimary, size: 20),
        ),
        title: const Text('Discover Peers',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScanningSection(),
            const SizedBox(height: 20),
            _buildBleSection(),
            const SizedBox(height: 28),
            _buildDiscoveredPeers(),
            const SizedBox(height: 28),
            _buildManualConnect(),
            const SizedBox(height: 28),
            _buildDHTSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningSection() {
    return Center(
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    ...List.generate(3, (i) {
                      final p = (_scanController.value + i * 0.33) % 1.0;
                      return Container(
                        width: 80 + (p * 40),
                        height: 80 + (p * 40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white
                                .withValues(alpha: 0.06 * (1 - p)),
                            width: 0.5,
                          ),
                        ),
                      );
                    }),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.surface,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Icon(Icons.radar_rounded,
                          color: AppTheme.textMuted, size: 24),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text('Scanning local network',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400)),
          const SizedBox(height: 4),
          Text('Same Wi-Fi required',
              style: TextStyle(
                  color: AppTheme.textMuted.withValues(alpha: 0.6),
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBleSection() {
    return Consumer<PeerService>(
      builder: (context, peerService, _) {
        final bleManager = peerService.bleManager;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: peerService.isBleActive
                  ? AppTheme.accentBlue.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bluetooth_rounded,
                    size: 18,
                    color: peerService.isBleActive
                        ? AppTheme.accentBlue
                        : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  const Text('BLE Mesh',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      )),
                  const Spacer(),
                  if (peerService.isBleActive && bleManager.isScanning)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 10, height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppTheme.accentBlue.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${bleManager.nearbyCount} nearby',
                          style: TextStyle(
                            color: AppTheme.textMuted.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  if (!peerService.isBleSupported)
                    Text('Not available',
                        style: TextStyle(
                          color: AppTheme.textMuted.withValues(alpha: 0.5),
                          fontSize: 12,
                        )),
                ],
              ),
              if (peerService.isBleActive &&
                  bleManager.discoveredPeers.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...bleManager.discoveredPeers.map((blePeer) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: blePeer.isConnected
                                  ? AppTheme.accentGreen
                                  : AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              blePeer.nyxId ?? blePeer.deviceName,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${blePeer.rssi} dBm',
                            style: TextStyle(
                              color: AppTheme.textMuted.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                          if (!blePeer.isConnected) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => bleManager.connectToPeer(blePeer),
                              child: const Icon(Icons.link_rounded,
                                  size: 16, color: AppTheme.accentBlue),
                            ),
                          ],
                        ],
                      ),
                    )),
              ],
              if (!peerService.isBleActive && peerService.isBleSupported) ...[
                const SizedBox(height: 8),
                Text(
                  'BLE mesh starts automatically with the network',
                  style: TextStyle(
                    color: AppTheme.textMuted.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscoveredPeers() {
    return Consumer<PeerService>(
      builder: (context, peerService, _) {
        final peers = peerService.peerList;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Discovered Peers',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${peers.length}',
                    style: const TextStyle(
                        color: AppTheme.accentBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 12),
            if (peers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.glassDecoration(
                    opacity: 0.04, borderRadius: 16),
                child: const Column(children: [
                  Icon(Icons.person_search_rounded,
                      size: 40, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text('No peers found yet',
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                ]),
              )
            else
              ...peers.map((p) => _buildPeerCard(p, peerService)),
          ],
        );
      },
    );
  }

  Widget _buildPeerCard(Peer peer, PeerService peerService) {
    final connected = peerService.isPeerConnected(peer.nyxChatId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected
              ? AppTheme.accentGreen.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Center(
            child: Text(
              peer.displayName.isNotEmpty
                  ? peer.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(peer.displayName,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(peer.nyxChatId,
                  style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      fontFamily: 'monospace')),
            ],
          ),
        ),
        connected
            ? ElevatedButton(
                onPressed: () => _startChat(peer),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppTheme.accentBlue.withValues(alpha: 0.15),
                  foregroundColor: AppTheme.accentBlue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Chat',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Connecting...',
                    style: TextStyle(
                        color: AppTheme.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
      ]),
    );
  }

  Widget _buildManualConnect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Manual Connect',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text("Enter a peer's IP address to connect directly",
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _ipController,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '192.168.1.100',
                labelText: 'IP Address',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: TextField(
              controller: _portController,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Port',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _manualConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceLight,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            icon: const Icon(Icons.link_rounded,
                color: AppTheme.textSecondary, size: 18),
            label: const Text('Connect',
                style: TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Future<void> _startChat(Peer peer) async {
    final chatService = context.read<ChatService>();
    final room = await chatService.getOrCreateRoom(
      peerId: peer.nyxChatId,
      peerDisplayName: peer.displayName,
      peerPublicKeyHex: peer.publicKeyHex,
    );
    if (mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => ChatScreen(room: room)));
    }
  }

  Future<void> _manualConnect() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 42420;
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please enter an IP address'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    final idSvc = context.read<IdentityService>();
    final peerSvc = context.read<PeerService>();
    final pubKey = await idSvc.getPublicKeyHex();
    final signPubKey = await idSvc.getSigningPublicKeyHex();
    final ok = await peerSvc.connectToPeer(
      address: ip, port: port,
      myNyxChatId: idSvc.nyxChatId, myDisplayName: idSvc.displayName,
      myPublicKeyHex: pubKey, mySigningPublicKeyHex: signPubKey,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Connected!' : 'Connection failed'),
        backgroundColor: ok ? AppTheme.accentGreen : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Widget _buildDHTSection() {
    return Consumer<PeerService>(
      builder: (context, peerService, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppTheme.accentPurple, AppTheme.accentPink],
                  ).createShader(bounds),
                  child: const Icon(Icons.language_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 8),
                const Text('Global Network (DHT)',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
                'Connect to peers beyond your local network using DHT',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            const SizedBox(height: 16),

            // DHT Status
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.glassDecoration(
                  opacity: 0.04, borderRadius: 14),
              child: Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: peerService.isDHTActive
                          ? AppTheme.accentGreen
                          : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    peerService.isDHTActive
                        ? 'DHT Active — ${peerService.dhtNode?.knownPeersCount ?? 0} peers'
                        : 'DHT Inactive',
                    style: TextStyle(
                      color: peerService.isDHTActive
                          ? AppTheme.accentGreen
                          : AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isDHTStarting
                        ? null
                        : () => peerService.isDHTActive
                            ? _stopDHT()
                            : _startDHT(),
                    child: _isDHTStarting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.accentBlue))
                        : Text(
                            peerService.isDHTActive ? 'Stop' : 'Start',
                            style: TextStyle(
                              color: peerService.isDHTActive
                                  ? AppTheme.error
                                  : AppTheme.accentBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Bootstrap Node
            TextField(
              controller: _dhtBootstrapController,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '192.168.1.1:42421',
                labelText: 'Bootstrap Node (IP:Port)',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: AppTheme.accentBlue),
                  onPressed: () {
                    final addr = _dhtBootstrapController.text.trim();
                    if (addr.isNotEmpty) {
                      peerService.addBootstrapNode(addr);
                      _dhtBootstrapController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Bootstrap node added'),
                        backgroundColor: AppTheme.accentGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'A bootstrap node is an existing peer in the DHT network '
              'that helps your device discover other peers. Enter the '
              'IP:Port of a known node to join the global network.',
              style: TextStyle(
                color: AppTheme.textMuted.withValues(alpha: 0.6),
                fontSize: 11,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),

            // Peer Lookup
            TextField(
              controller: _dhtLookupController,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Enter Nyx ID (e.g. BC-1A2B...C3D4)',
                labelText: 'Look Up Peer',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: _isLookingUp
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.accentBlue))
                      : const Icon(Icons.search_rounded,
                          color: AppTheme.accentBlue),
                  onPressed: _isLookingUp ? null : _lookupDHTPeer,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Search for a specific peer by their Nyx ID. The DHT '
              'network will query other nodes to find the peer\'s '
              'current IP address and connect you directly.',
              style: TextStyle(
                color: AppTheme.textMuted.withValues(alpha: 0.6),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startDHT() async {
    setState(() => _isDHTStarting = true);
    final idSvc = context.read<IdentityService>();
    final peerSvc = context.read<PeerService>();
    final pubKey = await idSvc.getPublicKeyHex();

    await peerSvc.startDHT(
      nyxChatId: idSvc.nyxChatId,
      publicKeyHex: pubKey,
      displayName: idSvc.displayName,
    );
    if (mounted) setState(() => _isDHTStarting = false);

    // Prompt user to disable battery optimization for background DHT
    if (mounted && Platform.isAndroid) {
      _promptBatteryOptimization();
    }
  }

  Future<void> _promptBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Disable Battery Optimization',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'DHT needs to run in the background to keep you discoverable '
          'by other peers. Please disable battery optimization for NyxChat '
          'so the system does not kill the DHT service when the app is '
          'in the background.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Permission.ignoreBatteryOptimizations.request();
            },
            child: const Text('Disable Optimization',
                style: TextStyle(
                    color: AppTheme.accentBlue,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _stopDHT() async {
    await context.read<PeerService>().stopDHT();
  }

  Future<void> _lookupDHTPeer() async {
    final targetId = _dhtLookupController.text.trim();
    if (targetId.isEmpty) return;

    setState(() => _isLookingUp = true);
    final peerSvc = context.read<PeerService>();
    final peer = await peerSvc.lookupGlobalPeer(targetId);

    if (mounted) {
      setState(() => _isLookingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(peer != null
            ? 'Found: ${peer.displayName} at ${peer.ipAddress}'
            : 'Peer not found in DHT'),
        backgroundColor: peer != null ? AppTheme.accentGreen : AppTheme.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }
}
