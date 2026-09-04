import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../widgets/media_strings.dart';

/// App-wide voice note playback. Exactly one note plays at a time and the
/// state lives here rather than in a bubble, so playback keeps going while
/// the list scrolls and the bubble is rebuilt or disposed.
///
/// The audio plugin is only touched on the first [toggle], so screens that
/// merely display voice notes build without a platform channel.
class VoicePlayer extends ChangeNotifier {
  VoicePlayer._();

  static final VoicePlayer instance = VoicePlayer._();

  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subs = [];
  String? _currentId;
  String? _currentPath;

  Duration position = Duration.zero;
  Duration? duration;
  bool playing = false;
  bool loading = false;

  /// Last failure, shown next to the note it belongs to; cleared on the
  /// next attempt.
  String? error;

  String? get currentId => _currentId;
  bool isCurrent(String id) => _currentId == id;
  bool isPlaying(String id) => playing && _currentId == id;
  bool isLoading(String id) => loading && _currentId == id;

  /// Playback progress of [id], 0..1 (0 when it is not the current note).
  double progressOf(String id, {Duration? knownDuration}) {
    if (!isCurrent(id)) return 0;
    final d = duration ?? knownDuration;
    if (d == null || d.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);
  }

  AudioPlayer _ensure() {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    _subs.add(p.positionStream.listen((pos) {
      position = pos;
      notifyListeners();
    }));
    _subs.add(p.durationStream.listen((d) {
      if (d != null) duration = d;
      notifyListeners();
    }));
    _subs.add(p.playerStateStream.listen((st) {
      final completed = st.processingState == ProcessingState.completed;
      playing = st.playing && !completed;
      loading = st.processingState == ProcessingState.loading ||
          st.processingState == ProcessingState.buffering;
      if (completed) unawaited(_rewind());
      notifyListeners();
    }));
    _subs.add(p.errorStream.listen((e) {
      debugPrint('[VoicePlayer] ${e.message}');
      _fail(MediaStrings.playbackFailed);
    }));
    _player = p;
    return p;
  }

  Future<void> _rewind() async {
    final p = _player;
    if (p == null) return;
    try {
      await p.pause();
      await p.seek(Duration.zero);
    } catch (_) {}
    position = Duration.zero;
    playing = false;
    notifyListeners();
  }

  /// Plays the note [id] stored at [path]; when it is already the current
  /// note this pauses or resumes instead. Any other note stops.
  Future<void> toggle(String id, String path) async {
    error = null;
    try {
      final p = _ensure();
      if (_currentId == id && _currentPath == path) {
        if (p.playing) {
          await p.pause();
        } else {
          if (p.processingState == ProcessingState.completed) {
            await p.seek(Duration.zero);
          }
          _play(p);
        }
        notifyListeners();
        return;
      }
      await _load(p, id, path);
      _play(p);
      notifyListeners();
    } on MissingPluginException {
      _fail(MediaStrings.playbackUnavailable);
    } catch (e) {
      debugPrint('[VoicePlayer] play failed: $e');
      _fail(MediaStrings.playbackFailed);
    }
  }

  Future<void> _load(AudioPlayer p, String id, String path) async {
    if (p.playing) await p.stop();
    _currentId = id;
    _currentPath = path;
    position = Duration.zero;
    duration = null;
    loading = true;
    notifyListeners();
    duration = await p.setFilePath(path);
    loading = false;
  }

  void _play(AudioPlayer p) {
    // play() only completes when playback ends or pauses; never await it.
    unawaited(p.play().catchError((Object e) {
      debugPrint('[VoicePlayer] $e');
      _fail(MediaStrings.playbackFailed);
    }));
  }

  /// Jumps to [to] in the note [id], loading it first if needed (without
  /// starting playback in that case).
  Future<void> seek(String id, String path, Duration to) async {
    error = null;
    try {
      final p = _ensure();
      if (_currentId != id || _currentPath != path) {
        await _load(p, id, path);
      }
      await p.seek(to);
      position = to;
      notifyListeners();
    } on MissingPluginException {
      _fail(MediaStrings.playbackUnavailable);
    } catch (e) {
      debugPrint('[VoicePlayer] seek failed: $e');
      _fail(MediaStrings.playbackFailed);
    }
  }

  /// Stops whatever is playing.
  Future<void> stop() async {
    final p = _player;
    if (p != null) {
      try {
        await p.stop();
      } catch (_) {}
    }
    _currentId = null;
    _currentPath = null;
    playing = false;
    loading = false;
    position = Duration.zero;
    notifyListeners();
  }

  void _fail(String message) {
    error = message;
    loading = false;
    playing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    final p = _player;
    _player = null;
    if (p != null) unawaited(p.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
