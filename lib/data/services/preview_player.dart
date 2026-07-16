import 'package:just_audio/just_audio.dart';

/// Snapshot of preview playback state, narrowed to what the assessment
/// screen actually needs from a player: am I playing, did I just finish,
/// am I idle (= no source loaded yet).
///
/// We keep this deliberately tiny so:
///   * the screen never imports just_audio types directly
///   * widget tests can supply a minimal in-memory fake
class PreviewPlaybackState {
  const PreviewPlaybackState({
    required this.playing,
    required this.completed,
    required this.idle,
  });

  /// True while the player is producing audio.
  final bool playing;

  /// True when playback has reached the end of the loaded clip.
  final bool completed;

  /// True before any source has been loaded (i.e. nothing to play yet).
  final bool idle;

  /// Default state — no source, not playing.
  static const stopped = PreviewPlaybackState(
    playing: false,
    completed: false,
    idle: true,
  );
}

/// Tiny abstraction over a media player used by the assessment screen to
/// preview the user's recording. Implementations:
///   * [JustAudioPreviewPlayer] — production wrapper around just_audio.
///   * test fakes — in-memory, zero platform plugins.
abstract class PreviewPlayer {
  /// Snapshot of the current playback state.
  PreviewPlaybackState get state;

  /// Stream of [PreviewPlaybackState] changes. Must emit the current value
  /// on subscribe so listeners can render synchronously.
  Stream<PreviewPlaybackState> get stateStream;

  /// Loads an audio file from a local path. Safe to call repeatedly.
  Future<void> setFilePath(String path);

  /// Rewinds the loaded clip to the beginning. No-op if idle.
  Future<void> seekToStart();

  /// Starts (or resumes) playback. Implementations are responsible for
  /// loading a source first if needed.
  Future<void> play();

  /// Pauses playback without unloading the source.
  Future<void> pause();

  /// Stops playback and resets to idle.
  Future<void> stop();

  /// Releases all platform resources. Must be safe to call multiple times.
  Future<void> dispose();
}

/// Default production [PreviewPlayer] backed by `just_audio`. Constructing
/// this touches platform channels — keep it out of widget tests.
class JustAudioPreviewPlayer implements PreviewPlayer {
  JustAudioPreviewPlayer() : _inner = AudioPlayer();

  final AudioPlayer _inner;

  PreviewPlaybackState _project(PlayerState s) => PreviewPlaybackState(
        playing: s.playing && s.processingState != ProcessingState.completed,
        completed: s.processingState == ProcessingState.completed,
        idle: s.processingState == ProcessingState.idle,
      );

  @override
  PreviewPlaybackState get state => PreviewPlaybackState(
        playing: _inner.playing &&
            _inner.processingState != ProcessingState.completed,
        completed: _inner.processingState == ProcessingState.completed,
        idle: _inner.processingState == ProcessingState.idle,
      );

  @override
  Stream<PreviewPlaybackState> get stateStream =>
      _inner.playerStateStream.map(_project);

  @override
  Future<void> setFilePath(String path) async {
    await _inner.setFilePath(path);
  }

  @override
  Future<void> seekToStart() => _inner.seek(Duration.zero);

  @override
  Future<void> play() => _inner.play();

  @override
  Future<void> pause() => _inner.pause();

  @override
  Future<void> stop() => _inner.stop();

  @override
  Future<void> dispose() => _inner.dispose();
}
