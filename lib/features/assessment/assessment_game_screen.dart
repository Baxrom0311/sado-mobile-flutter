import 'dart:async';
import 'dart:io';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../core/utils/permissions.dart';
import '../../data/api/api_client.dart';
import '../../data/api/assessments_api.dart';
import '../../data/local/preferences.dart';
import '../../data/services/audio_recorder_service.dart';
import '../../data/services/preview_player.dart';
import '../../providers/providers.dart';
import '../../widgets/confetti_host.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/recording_button.dart';
import '../../widgets/recording_progress_bar.dart';
import '../../widgets/waveform_visualizer.dart';

class AssessmentGameScreen extends ConsumerStatefulWidget {
  const AssessmentGameScreen({
    super.key,
    required this.childId,
    required this.exerciseId,
  });
  final String childId;
  final String exerciseId;

  @override
  ConsumerState<AssessmentGameScreen> createState() =>
      _AssessmentGameScreenState();
}

class _AssessmentGameScreenState
    extends ConsumerState<AssessmentGameScreen> {
  late final AudioRecorderService _recorder;
  late final PreviewPlayer _player;
  final _confetti =
      ConfettiController(duration: const Duration(milliseconds: 1200));

  bool _isRecording = false;
  bool _hasRecording = false;
  bool _submitting = false;
  bool _permissionDenied = false;
  bool _permissionPermanent = false;
  bool _isPlaying = false;

  String? _audioPath;
  int _seconds = 0;
  Timer? _timer;
  StreamSubscription<AmplitudeSample>? _ampSub;
  StreamSubscription<PreviewPlaybackState>? _playerSub;
  double _amplitude = 0;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(audioRecorderFactoryProvider)();
    _player = ref.read(previewPlayerFactoryProvider)();
    _ampSub = _recorder.amplitudeStream.listen((sample) {
      if (!mounted) return;
      setState(() => _amplitude = sample.dbfs);
    });
    _playerSub = _player.stateStream.listen((s) {
      if (!mounted) return;
      // When the clip finishes, rewind to the start and pause so the user
      // can replay it from the beginning with another tap.
      if (s.completed) {
        _player.seekToStart();
        _player.pause();
      }
      if (_isPlaying != s.playing) {
        setState(() => _isPlaying = s.playing);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _playerSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final outcome = await MicPermission.ensureMicPermission(context);
    if (!mounted) return;
    if (outcome != MicPermissionOutcome.granted) {
      setState(() {
        _permissionDenied = outcome != MicPermissionOutcome.cancelled;
        _permissionPermanent =
            outcome == MicPermissionOutcome.permanentlyDenied;
      });
      return;
    }
    setState(() {
      _permissionDenied = false;
      _permissionPermanent = false;
    });

    // Stop any active playback before recording.
    if (_player.state.playing) {
      await _player.stop();
    }

    try {
      _audioPath = await _recorder.start(
        quality: ref.read(audioQualityProvider),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context)!.error)),
      );
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= kRecordingMaxSeconds) _stopRecording();
    });

    setState(() {
      _isRecording = true;
      _hasRecording = false;
      _seconds = 0;
      _permissionDenied = false;
      _amplitude = -45;
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _hasRecording = path != null && File(path).existsSync();
      _amplitude = -45;
    });
    if (_hasRecording) {
      _audioPath = path;
      try {
        await _player.setFilePath(path!);
      } catch (_) {/* preview unavailable but recording is still valid */}
      _confetti.play();
    }
  }

  Future<void> _togglePlay() async {
    if (_audioPath == null) return;
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        if (_player.state.idle) {
          await _player.setFilePath(_audioPath!);
        }
        await _player.seekToStart();
        await _player.play();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context)!.error)),
      );
    }
  }

  Future<void> _submit() async {
    if (_audioPath == null) return;
    final l = L.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);

    if (_player.state.playing) await _player.stop();

    try {
      final api = AssessmentsApi(ref.read(dioProvider));
      final result = await api.create(
        childId: widget.childId,
        exerciseId: widget.exerciseId,
        audioPath: _audioPath,
      );
      // Invalidate so new assessment appears in lists/counts immediately.
      ref.invalidate(assessmentsProvider);
      if (mounted) context.go('/assessment/results/${result.id}');
    } catch (_) {
      // Network down (or transient API error). Move the audio to a stable
      // location and queue it for retry instead of losing the user's work.
      String message;
      try {
        final stablePath = await _moveAudioToPermanentDir(_audioPath!);
        final service =
            await ref.read(pendingUploadsServiceProvider.future);
        await service.enqueue(
          id: 'pu_${DateTime.now().microsecondsSinceEpoch}',
          childId: widget.childId,
          exerciseId: widget.exerciseId,
          audioPath: stablePath,
        );
        message = l.uploadQueued;
      } catch (_) {
        message = l.networkError;
      }

      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
        setState(() => _submitting = false);
        // After successful enqueue, hop back home so the user can keep
        // exploring; the queue will retry in the background.
        if (message == l.uploadQueued) {
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) context.go('/');
        }
      }
    }
  }

  Future<String> _moveAudioToPermanentDir(String tempPath) async {
    final docs = await getApplicationDocumentsDirectory();
    final pendingDir = Directory('${docs.path}/sado_pending');
    if (!pendingDir.existsSync()) {
      pendingDir.createSync(recursive: true);
    }
    final fileName = 'queued_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final dest = '${pendingDir.path}/$fileName';
    final src = File(tempPath);
    if (src.existsSync()) {
      await src.copy(dest);
    }
    return dest;
  }

  Future<void> _resetRecording() async {
    if (_player.state.playing) await _player.stop();
    setState(() {
      _hasRecording = false;
      _isPlaying = false;
      _seconds = 0;
      _audioPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;

    final mood = _isRecording
        ? ParrotMood.listening
        : (_hasRecording ? ParrotMood.happy : ParrotMood.talking);
    final message = _permissionDenied
        ? (_permissionPermanent
            ? l.permissionPermanentlyDeniedBody
            : l.microphonePermissionBody)
        : (_isRecording
            ? l.recording
            : (_hasRecording
                ? l.mascotAssessmentDone
                : l.mascotAssessmentReady));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.startAssessment),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/exercises'),
        ),
      ),
      body: ConfettiHost(
        controller: _confetti,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),
                ParrotMascot(mood: mood, size: 160, message: message)
                    .animate()
                    .fadeIn(duration: 350.ms),
                const SizedBox(height: AppSpacing.xl),

                // Timer
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}',
                    key: ValueKey(_seconds ~/ 5),
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: _isRecording
                          ? AppColors.danger
                          : AppColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _isRecording
                      ? l.tapToStop
                      : (_hasRecording ? '' : l.tapToRecord),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Recording-time progress bar — green → orange → red as
                // the 60-second budget is consumed. Renders nothing while
                // idle so the layout stays calm before the user taps record.
                if (_isRecording)
                  RecordingProgressBar(elapsedSeconds: _seconds)
                      .animate()
                      .fadeIn(duration: 220.ms),
                if (_isRecording) const SizedBox(height: AppSpacing.md),

                // Live waveform during recording.
                if (_isRecording)
                  PremiumCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                      horizontal: AppSpacing.lg,
                    ),
                    child: WaveformVisualizer(
                      amplitude: _amplitude,
                      active: true,
                    ),
                  ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.1),

                const Spacer(),

                if (_permissionDenied)
                  PremiumButton(
                    label: _permissionPermanent
                        ? l.openSettings
                        : l.grantPermission,
                    icon: Icons.mic_rounded,
                    onPressed: () async {
                      if (_permissionPermanent) {
                        await openAppSettings();
                      } else {
                        // Re-trigger the rationale + request flow.
                        await _startRecording();
                      }
                    },
                  )
                else if (!_hasRecording)
                  Center(
                    child: RecordingButton(
                      recording: _isRecording,
                      onTap: _toggleRecord,
                    ),
                  )
                else
                  Column(
                    children: [
                      // Playback control card
                      PremiumCard(
                        onTap: _submitting ? null : _togglePlay,
                        shadowColor: AppColors.tertiary,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.tertiary,
                                shape: BoxShape.circle,
                                boxShadow: AppShadow.soft(AppColors.tertiary),
                              ),
                              child: Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isPlaying
                                        ? l.pauseRecording
                                        : l.playRecording,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l.secondsShort(_seconds),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PremiumButton(
                        label: l.submitAssessment,
                        icon: Icons.send_rounded,
                        onPressed: _submitting ? null : _submit,
                        loading: _submitting,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PremiumButton(
                        label: l.recordAgain,
                        icon: Icons.replay_rounded,
                        color: AppColors.surfaceMuted,
                        foreground: AppColors.textPrimary,
                        onPressed: _submitting ? null : _resetRecording,
                      ),
                    ],
                  ),

                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
