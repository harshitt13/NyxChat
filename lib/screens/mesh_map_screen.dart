import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/peer_service.dart';
import '../theme/app_theme.dart';

class MeshMapScreen extends StatefulWidget {
  const MeshMapScreen({super.key});

  @override
  State<MeshMapScreen> createState() => _MeshMapScreenState();
}

class _MeshMapScreenState extends State<MeshMapScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mesh Topography'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: Consumer<PeerService>(
        builder: (context, peerService, _) {
          final wifiPeersCount = peerService.wifiDirectManager.getConnectedPeersCount();
          final blePeersCount = peerService.nearbyBleCount;
          final totalNodes = wifiPeersCount + blePeersCount;
          
          return Center(
            child: totalNodes == 0
                ? _buildEmptyState()
                : _buildMeshGraph(peerService),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 100 + (_pulseController.value * 20),
              height: 100 + (_pulseController.value * 20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentBlue.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppTheme.accentBlue.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.wifi_tethering_off, size: 40, color: AppTheme.textMuted),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'No Local Nodes Found',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your device is isolated from the mesh.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildMeshGraph(PeerService peerService) {
    // In a real implementation this would draw a complex CustomPaint node graph based on 
    // `peerService.meshRouter.routingTable`. For now we visualize direct connections.
    
    return CustomPaint(
      painter: _MeshGraphPainter(
        pulseValue: _pulseController.value,
        directPeers: peerService.nearbyBleCount + peerService.wifiDirectManager.getConnectedPeersCount(),
      ),
      size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
    );
  }
}

class _MeshGraphPainter extends CustomPainter {
  final double pulseValue;
  final int directPeers;
  final Random _rnd = Random(42);

  _MeshGraphPainter({required this.pulseValue, required this.directPeers});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    final linePaint = Paint()
      ..color = AppTheme.accentGreen.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    final myNodePaint = Paint()
      ..color = AppTheme.accentBlue
      ..style = PaintingStyle.fill;
      
    final peerNodePaint = Paint()
      ..color = AppTheme.accentGreen
      ..style = PaintingStyle.fill;

    // Draw lines to peers
    for (int i = 0; i < directPeers; i++) {
        final angle = (i * (2 * pi / directPeers)) + (pulseValue * 0.1);
        final radius = 100.0 + _rnd.nextInt(50);
        final peerOffset = Offset(
           center.dx + radius * cos(angle),
           center.dy + radius * sin(angle),
        );
        
        canvas.drawLine(center, peerOffset, linePaint);
        canvas.drawCircle(peerOffset, 12, peerNodePaint);
    }
    
    // Draw central node (this device)
    canvas.drawCircle(center, 24 + (pulseValue * 4), myNodePaint);
  }

  @override
  bool shouldRepaint(covariant _MeshGraphPainter oldDelegate) => 
      oldDelegate.pulseValue != pulseValue || oldDelegate.directPeers != directPeers;
}
