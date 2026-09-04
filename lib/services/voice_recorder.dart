import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../widgets/media_strings.dart';

/// A finished recording, ready to be sent.
class VoiceRecording {
  final String path;
  final Duration duration;
  final int bytes;

  const VoiceRecording(
      {required this.path, required this.duration, required this.bytes});
}

/// Hold-to-talk recorder: mono AAC-LC at 16 kHz / 32 kbps in an .m4a
/// container (about 240 KB per minute, so a five-minute note is far under
/// the 4 MiB mesh file limit). Exposes the elapsed time and a short
/// history of input levels for the composer HUD.
///
/// The recorder plugin is created lazily on the first press, so widget
/// trees build fine where the platform channel is missing (tests, desktop
/// without an implementation); [start] then returns a message for the
/// user instead of throwing.
class VoiceRecorder extends ChangeNotifier {
  static const Duration maxDuration = Duration(minutes: 5);
  static const Duration minDuration = Duration(milliseconds: 800);
  static const int sampleRate = 16000;
  static const int bitRate = 32000;
  static const int levelHistory = 28;

  static const RecordConfig config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: bitRate,
    sampleRate: sampleRate,
    numChannels: 1,
  );

  AudioRecorder? _rec;
  Timer? _ticker;
  StreamSubscription<Amplitude>? _ampSub;
  DateTime? _startedAt;
  String? _path;
  bool _stopping = false;
  bool _limitFired = false;
  bool _disposed = false;

  /// Time since [start]; updated ten times a second while recording.
  Duration elapsed = Duration.zero;

  /// Current input level, 0..1.
  double level = 0;

  /// The last [levelHistory] levels, oldest first.
  final List<double> levels = [];

  /// Fired once when [maxDuration] is reached; the owner should [stop].
  VoidCallback? onLimitReached;

  bool get isRecording => _startedAt != null && !_stopping;
  Duration get remaining => maxDuration - elapsed;

  /// Starts a new recording into a temp file. Returns null on success or
  /// a short message explaining why nothing was started.
  Future<String?> start() async {
    if (_startedAt != null) return null;
    final PermissionStatus status;
    try {
      status = await Permission.microphone.request();
    } on MissingPluginException {
      return MediaStrings.recordingUnavailable;
    } catch (e) {
      debugPrint('[Voice] permission check failed: $e');
      return MediaStrings.recordingUnavailable;
    }
    if (!status.isGranted) return MediaStrings.microphoneDenied;
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/nyx_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final rec = _rec ??= AudioRecorder();
      await rec.start(config, path: path);
      _path = path;
      _startedAt = DateTime.now();
      _stopping = false;
      _limitFired = false;
      elapsed = Duration.zero;
      level = 0;
      levels.clear();
      _ampSub = rec
          .onAmplitudeChanged(const Duration(milliseconds: 80))
          .listen(_onAmplitude, onError: (Object _) {});
      _ticker = Timer.periodic(const Duration(milliseconds: 100), _tick);
      _notify();
      return null;
    } on MissingPluginException {
      await _discard();
      return MediaStrings.recordingUnavailable;
    } catch (e) {
      debugPrint('[Voice] start failed: $e');
      await _discard();
      return MediaStrings.recordingFailed;
    }
  }

  void _onAmplitude(Amplitude a) {
    level = normalizeDbfs(a.current);
    levels.add(level);
    if (levels.length > levelHistory) levels.removeAt(0);
    _notify();
  }

  void _tick(Timer _) {
    final started = _startedAt;
    if (started == null) return;
    elapsed = DateTime.now().difference(started);
    if (elapsed >= maxDuration && !_limitFired) {
      _limitFired = true;
      onLimitReached?.call();
    }
    _notify();
  }

  /// Stops and returns the recording, or null when it was too short to be
  /// worth sending (the file is deleted) or the recorder failed.
  Future<VoiceRecording?> stop() async {
    final started = _startedAt;
    if (started == null || _stopping) return null;
    _stopping = true;
    _stopTimers();
    final fallbackPath = _path;
    String? out;
    try {
      out = await _rec?.stop();
    } catch (e) {
      debugPrint('[Voice] stop failed: $e');
    }
    var duration = DateTime.now().difference(started);
    if (duration > maxDuration) duration = maxDuration;
    _clear();
    final path = out ?? fallbackPath;
    if (path == null) return null;
    final file = File(path);
    int bytes;
    try {
      if (!await file.exists()) return null;
      bytes = await file.length();
    } catch (_) {
      return null;
    }
    if (duration < minDuration || bytes == 0) {
      await _delete(file);
      return null;
    }
    return VoiceRecording(path: path, duration: duration, bytes: bytes);
  }

  /// Stops and throws the recording away.
  Future<void> cancel() async {
    if (_startedAt == null) return;
    await _discard();
  }

  Future<void> _discard() async {
    _stopping = true;
    _stopTimers();
    final path = _path;
    try {
      await _rec?.cancel();
    } catch (_) {}
    _clear();
    if (path != null) await _delete(File(path));
  }

  static Future<void> _delete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  void _stopTimers() {
    _ticker?.cancel();
    _ticker = null;
    _ampSub?.cancel();
    _ampSub = null;
  }

  void _clear() {
    _stopTimers();
    _startedAt = null;
    _path = null;
    _stopping = false;
    _limitFired = false;
    level = 0;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Maps a dBFS reading (-160..0) to a 0..1 meter level; anything quieter
  /// than -50 dBFS shows as silence.
  static double normalizeDbfs(double dbfs) {
    if (dbfs.isNaN || dbfs.isInfinite) return 0;
    return ((dbfs + 50) / 50).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimers();
    final rec = _rec;
    _rec = null;
    if (rec != null) {
      unawaited(rec.dispose().catchError((Object _) {}));
    }
    super.dispose();
  }
}
