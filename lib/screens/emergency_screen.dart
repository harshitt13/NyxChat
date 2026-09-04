import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/mesh/geohash_channel.dart';
import '../core/network/location_channel.dart';
import '../l10n/l10n_context.dart';
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
      setState(() => _status = context.l10n.noRecentPosition);
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
      if (!mounted) return;
      setState(() => _status = context.l10n.invalidCell('$e'));
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
      _status = carried ? null : context.l10n.noNeighboursKept;
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
          backgroundColor: context.nyx.background,
          appBar: AppBar(
            backgroundColor: context.nyx.background,
            elevation: 0,
            title: Text(context.l10n.emergencyBroadcastTitle, style: TextStyle(color: context.nyx.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          body: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              color: context.nyx.surface,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _cell,
                      style: TextStyle(color: context.nyx.textPrimary, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        labelText: context.l10n.areaCellLabel, labelStyle: TextStyle(color: context.nyx.textMuted),
                        isDense: true, border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _join(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _precision,
                    dropdownColor: context.nyx.surfaceLight,
                    items: [4, 5, 6].map((p) => DropdownMenuItem(value: p, child: Text(GeohashChannel.approximateArea(p), style: TextStyle(color: context.nyx.textPrimary, fontSize: 13)))).toList(),
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
                  IconButton(icon: Icon(Icons.my_location_rounded, color: context.nyx.accentBlue), onPressed: _locate),
                ]),
                const SizedBox(height: 6),
                Text(
                  channel == null
                      ? (_status ?? context.l10n.findingYourArea)
                      : context.l10n.listeningInCell(
                          channel.geohash,
                          GeohashChannel.approximateArea(channel.geohash.length),
                          context.l10n.meshNeighboursCount(peers.meshNeighbourCount),
                          context.l10n.directLinksCount(peers.connectedPeers.length)),
                  style: TextStyle(color: _status != null ? context.nyx.warning : context.nyx.textMuted, fontSize: 12),
                ),
                if (_status != null && channel != null)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(_status!, style: TextStyle(color: context.nyx.warning, fontSize: 12))),
              ]),
            ),
            Expanded(
              child: msgs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          context.l10n.emergencyEmptyHint,
                          textAlign: TextAlign.center, style: TextStyle(color: context.nyx.textMuted.withValues(alpha: 0.9), fontSize: 13, height: 1.4),
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
        decoration: context.nyx.glass(opacity: 0.04, borderRadius: 12, borderColor: context.nyx.error.withValues(alpha: 0.25)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.campaign_rounded, size: 14, color: context.nyx.error),
            const SizedBox(width: 6),
            Text(m.displayName ?? context.l10n.anonymous, style: TextStyle(color: context.nyx.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(DateFormat.MMMd(Localizations.localeOf(context).toString()).add_Hm().format(m.timestamp.toLocal()), style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          Text(m.text, style: TextStyle(color: context.nyx.textPrimary, fontSize: 15, height: 1.3)),
          if (m.lat != null && m.lon != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(context.l10n.positionLabel('${m.lat!.toStringAsFixed(5)}, ${m.lon!.toStringAsFixed(5)}'),
                  style: TextStyle(color: context.nyx.accentBlue, fontSize: 12, fontFamily: 'monospace')),
            ),
        ]),
      );

  Widget _composer(bool ready) => Container(
        padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(color: context.nyx.background, border: Border(top: BorderSide(color: context.nyx.hairline(0.04)))),
        child: Column(children: [
          Row(children: [
            _chip(context.l10n.includeMyName, _includeName, (v) => setState(() => _includeName = v)),
            const SizedBox(width: 8),
            _chip(context.l10n.includeMyPosition, _includePosition, (v) => setState(() => _includePosition = v)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _text, maxLines: 3, minLines: 1, enabled: ready,
                style: TextStyle(color: context.nyx.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: ready ? context.l10n.emergencyComposerHint : context.l10n.joinCellFirst,
                  hintStyle: TextStyle(color: context.nyx.textMuted),
                  filled: true, fillColor: context.nyx.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: ready && !_busy ? () => _send() : null,
                style: ElevatedButton.styleFrom(backgroundColor: context.nyx.error, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text(context.l10n.send.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _preset(ready, context.l10n.presetNeedHelp),
            const SizedBox(width: 6),
            _preset(ready, context.l10n.presetSafe),
            const SizedBox(width: 6),
            _preset(ready, context.l10n.presetMedical),
          ]),
        ]),
      );

  Widget _chip(String label, bool on, ValueChanged<bool> onChanged) => FilterChip(
        label: Text(label, style: TextStyle(color: on ? context.nyx.textPrimary : context.nyx.textMuted, fontSize: 12)),
        selected: on, onSelected: onChanged,
        selectedColor: context.nyx.accentBlue.withValues(alpha: 0.2), backgroundColor: context.nyx.surface,
        checkmarkColor: context.nyx.accentBlue, side: BorderSide(color: context.nyx.hairline(0.06)),
      );

  Widget _preset(bool ready, String text) => Expanded(
        child: OutlinedButton(
          onPressed: ready && !_busy ? () => _send(preset: text) : null,
          style: OutlinedButton.styleFrom(foregroundColor: context.nyx.textSecondary, side: BorderSide(color: context.nyx.hairline(0.1)),
              padding: const EdgeInsets.symmetric(horizontal: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text(text, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
        ),
      );
}