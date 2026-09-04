import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/mesh/geohash_channel.dart';
import '../core/network/location_channel.dart';
import '../services/chat_service.dart';
import '../services/identity_service.dart';
import '../services/peer_service.dart';
import '../theme/app_theme.dart';

/// One-tap local broadcast: everyone with NyxChat within the same ~5 km
/// geohash cell receives it over the mesh, no contacts or internet needed.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});
  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final _text = TextEditingController();
  final _cell = TextEditingController();
  final _scroll = ScrollController();
  bool _includeName = false;
  bool _includePosition = false;
  bool _busy = false;
  DevicePosition? _position;
  String? _status;
  int _precision = GeohashChannel.defaultPrecision;

  @override
  void initState() {
    super.initState();
    unawaited(_locate());
  }

  @override
  void dispose() {
    _text.dispose();
    _cell.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final chat = context.read<ChatService>();
    final existing = chat.emergencyChannel;
    if (existing != null) {
      _cell.text = existing.geohash;
      setState(() {});
      return;
    }
    final p = await LocationChannel.lastKnown();
    if (!mounted) return;
    if (p == null) {
      setState(() => _status = 'No recent position. Enter a geohash cell manually or move outdoors.');
      return;
    }
    _position = p;
    _cell.text = GeohashChannel.encode(p.lat, p.lon, _precision);
    await _join();
  }

  Future<void> _join() async {
    final cell = _cell.text.trim().toLowerCase();
    if (cell.isEmpty) return;
    try {
      await context.read<ChatService>().joinEmergencyChannel(cell);
      setState(() => _status = null);
    } catch (e) {
      setState(() => _status = 'Invalid cell: $e');
    }
  }

  Future<void> _send({String? preset}) async {
    final chat = context.read<ChatService>();
    final text = preset ?? _text.text.trim();
    if (text.isEmpty || chat.emergencyChannel == null) return;
    setState(() => _busy = true);
    final name = _includeName ? context.read<IdentityService>().displayName : null;
    final p = _includePosition ? (_position ?? await LocationChannel.lastKnown()) : null;
    final carried = await chat.sendEmergency(text, displayName: name, lat: p?.lat, lon: p?.lon);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _text.clear();
      _status = carried ? null : 'No neighbours right now. Your message is kept and sent to the first device that appears.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatService, PeerService>(
      builder: (context, chat, peers, _) {
        final channel = chat.emergencyChannel;
        final msgs = chat.emergencyMessages;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            elevation: 0,
            title: const Text('Emergency broadcast', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          body: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              color: AppTheme.surface,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _cell,
                      style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        labelText: 'Area cell (geohash)', labelStyle: TextStyle(color: AppTheme.textMuted),
                        isDense: true, border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _join(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _precision,
                    dropdownColor: AppTheme.surfaceLight,
                    items: [4, 5, 6].map((p) => DropdownMenuItem(value: p, child: Text(GeohashChannel.approximateArea(p), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)))).toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _precision = v);
                      final p = _position;
                      if (p != null) {
                        _cell.text = GeohashChannel.encode(p.lat, p.lon, v);
                        await _join();
                      }
                    },
                  ),
                  IconButton(icon: const Icon(Icons.my_location_rounded, color: AppTheme.accentBlue), onPressed: _locate),
                ]),
                const SizedBox(height: 6),
                Text(
                  channel == null
                      ? (_status ?? 'Finding your area...')
                      : 'Listening in cell ${channel.geohash} (${GeohashChannel.approximateArea(channel.geohash.length)}) · '
                        '${peers.meshNeighbourCount} mesh neighbours, ${peers.connectedPeers.length} direct links',
                  style: TextStyle(color: _status != null ? AppTheme.warning : AppTheme.textMuted, fontSize: 12),
                ),
                if (_status != null && channel != null)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(_status!, style: const TextStyle(color: AppTheme.warning, fontSize: 12))),
              ]),
            ),
            Expanded(
              child: msgs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Messages from anyone running NyxChat in this cell appear here. Your position never leaves the phone unless you include it explicitly.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.9), fontSize: 13, height: 1.4),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(14),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) => _bubble(msgs[i]),
                    ),
            ),
            _composer(channel != null),
          ]),
        );
      },
    );
  }

  Widget _bubble(EmergencyMessage m) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.glassDecoration(opacity: 0.04, borderRadius: 12, borderColor: AppTheme.error.withValues(alpha: 0.25)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.campaign_rounded, size: 14, color: AppTheme.error),
            const SizedBox(width: 6),
            Text(m.displayName ?? 'Anonymous', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(DateFormat('MMM d, HH:mm').format(m.timestamp.toLocal()), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          Text(m.text, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, height: 1.3)),
          if (m.lat != null && m.lon != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Position: ${m.lat!.toStringAsFixed(5)}, ${m.lon!.toStringAsFixed(5)}',
                  style: const TextStyle(color: AppTheme.accentBlue, fontSize: 12, fontFamily: 'monospace')),
            ),
        ]),
      );

  Widget _composer(bool ready) => Container(
        padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(color: AppTheme.background, border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.04)))),
        child: Column(children: [
          Row(children: [
            _chip('Include my name', _includeName, (v) => setState(() => _includeName = v)),
            const SizedBox(width: 8),
            _chip('Include my position', _includePosition, (v) => setState(() => _includePosition = v)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _text, maxLines: 3, minLines: 1, enabled: ready,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: ready ? 'What is happening? Where are you?' : 'Join a cell first',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true, fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: ready && !_busy ? () => _send() : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('SEND', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _preset(ready, 'I need help'),
            const SizedBox(width: 6),
            _preset(ready, 'I am safe'),
            const SizedBox(width: 6),
            _preset(ready, 'Medical emergency'),
          ]),
        ]),
      );

  Widget _chip(String label, bool on, ValueChanged<bool> onChanged) => FilterChip(
        label: Text(label, style: TextStyle(color: on ? AppTheme.textPrimary : AppTheme.textMuted, fontSize: 12)),
        selected: on, onSelected: onChanged,
        selectedColor: AppTheme.accentBlue.withValues(alpha: 0.2), backgroundColor: AppTheme.surface,
        checkmarkColor: AppTheme.accentBlue, side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      );

  Widget _preset(bool ready, String text) => Expanded(
        child: OutlinedButton(
          onPressed: ready && !_busy ? () => _send(preset: text) : null,
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textSecondary, side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              padding: const EdgeInsets.symmetric(horizontal: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text(text, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
        ),
      );
}