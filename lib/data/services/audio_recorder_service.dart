import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../local/preferences.dart';

/// Result of a permission check before recording.
enum MicPermissionResult { granted, denied, permanentlyDenied }

/// Bitrate / sample-rate tuple that maps an [AudioQuality] tier onto the
/// concrete settings used by the recorder.
class AudioCaptureProfile {
  const AudioCaptureProfile({
    required this.bitRate,
    required this.sampleRate,
  });

  final int bitRate;
  final int sampleRate;

  /// Sensible defaults that balance file size against intelligibility for
  /// child speech assessment.
  factory AudioCaptureProfile.forQuality(AudioQuality quality) {
    switch (quality) {
      case AudioQuality.low:
        return const AudioCaptureProfile(bitRate: 64000, sampleRate: 22050);
      case AudioQuality.standard:
        return const AudioCaptureProfile(bitRate: 128000, sampleRate: 44100);
      case AudioQuality.high:
        return const AudioCaptureProfile(bitRate: 192000, sampleRate: 48000);
    }
  }
}

/// Live amplitude sample emitted while recording.
class AmplitudeSample {
  /// Linear normalized amplitude in 0..1 (loudness from quiet to loud).
  final double normalized;

  /// Raw dBFS value from the platform recorder (negative; 0 = max).
  final double dbfs;

  const AmplitudeSample({required this.normalized, required this.dbfs});

  /// Converts a raw dBFS reading into a 0..1 amplitude value suitable for
  /// driving a waveform visualiser.
  ///
  /// The `record` package emits dBFS where 0.0 = max signal and very
  /// negative values mean silence. We clamp to a reasonable working range
  /// (-60 dBFS = silence, 0 dBFS = max) and linearly project that onto
  /// `[0, 1]`. NaN / non-finite values are treated as silence so a flaky
  /// platform reading cannot blow up the UI.
  static double normalizeDbfs(double dbfs) {
    if (dbfs.isNaN || !dbfs.isFinite) return 0;
    final clamped = dbfs.clamp(-60.0, 0.0);
    return ((clamped + 60.0) / 60.0).clamp(0.0, 1.0);
  }

  /// Convenience constructor that normalizes the dBFS reading on the fly.
  factory AmplitudeSample.fromDbfs(double dbfs) =>
      AmplitudeSample(normalized: normalizeDbfs(dbfs), dbfs: dbfs);
}

/// Wraps the [AudioRecorder] with a friendlier API:
///   - explicit permission check
///   - generates output paths under temp dir
///   - exposes a normalized amplitude stream for waveform visualizers
///   - safe stop / dispose semantics (idempotent)
class AudioRecorderService {
  AudioRecorderService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  StreamSubscription<Amplitude>? _ampSub;
  final _ampController = StreamController<AmplitudeSample>.broadcast();
  String? _activePath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Stream of amplitude samples while recording. The controller is
  /// broadcast and stays open across multiple start/stop cycles.
  Stream<AmplitudeSample> get amplitudeStream => _ampController.stream;

  /// Asks the OS for microphone permission. Returns a tri-state result so
  /// the UI can decide between a rationale dialog and a "open settings"
  /// fallback.
  Future<MicPermissionResult> ensurePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return MicPermissionResult.granted;
    if (status.isPermanentlyDenied) return MicPermissionResult.permanentlyDenied;
    return MicPermissionResult.denied;
  }

  /// Starts recording to an `.m4a` file under the temporary directory.
  /// Returns the absolute path the recording is being written to so the
  /// caller can persist or upload it later.
  Future<String> start({
    Duration amplitudeInterval = const Duration(milliseconds: 80),
    AudioQuality quality = AudioQuality.standard,
  }) async {
    if (_isRecording) {
      throw StateError('AudioRecorderService.start: already recording');
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/sado_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final profile = AudioCaptureProfile.forQuality(quality);
    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: profile.bitRate,
        sampleRate: profile.sampleRate,
        numChannels: 1,
      ),
      path: path,
    );

    _activePath = path;
    _isRecording = true;

    _ampSub = _recorder.onAmplitudeChanged(amplitudeInterval).listen(
      (a) {
        if (!_ampController.isClosed) {
          _ampController.add(AmplitudeSample.fromDbfs(a.current));
        }
      },
      onError: (_) {
        // Swallow amplitude errors — they shouldn't kill the recording.
      },
    );
    return path;
  }

  /// Stops the current recording. Returns the file path if a recording was
  /// in progress, otherwise null. Safe to call when not recording.
  Future<String?> stop() async {
    if (!_isRecording) return null;
    await _ampSub?.cancel();
    _ampSub = null;
    final path = await _recorder.stop();
    _isRecording = false;
    return path ?? _activePath;
  }

  /// Discards the current recording (stops + deletes the temp file).
  Future<void> discard() async {
    await stop();
    if (_activePath != null) {
      final f = File(_activePath!);
      if (await f.exists()) await f.delete();
      _activePath = null;
    }
  }

  Future<void> dispose() async {
    await _ampSub?.cancel();
    await _recorder.dispose();
    if (!_ampController.isClosed) await _ampController.close();
  }
}
