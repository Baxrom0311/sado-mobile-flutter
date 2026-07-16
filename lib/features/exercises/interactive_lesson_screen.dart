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
import '../../data/models/models.dart';
import '../../data/services/audio_recorder_service.dart';
import '../../data/services/preview_player.dart';
import '../../providers/providers.dart';
import '../../widgets/audio_example_player.dart';
import '../../widgets/confetti_host.dart';
import '../../widgets/loaders.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/recording_button.dart';
import '../../widgets/recording_progress_bar.dart';
import '../../widgets/waveform_visualizer.dart';

/// Step-by-step interactive lesson player.
///
/// Walks the child through the ordered list of [ExerciseStep]s shipped by
/// the API (see PROJECT_BRIEF §3 "Interactive Exercises Redesign"):
///
///   * [InstructionStep] — narrator card with the parrot mascot.
///   * [DemonstrateStep] — therapist audio example + image.
///   * [RecordStep] — the child records their attempt; we keep the file
///     path in [_recordings] keyed by step index so the user can re-record
///     and the latest take always wins.
///   * [FeedbackStep] — celebration card with a "Finish" CTA.
///
/// On the final step (or when the user taps "Finish" on a [FeedbackStep])
/// we submit the most recent [RecordStep] capture as a single assessment
/// — the existing `POST /assessments` endpoint accepts exactly one audio
/// file per assessment, so concatenation/multi-file uploads stay deferred
/// to a follow-up API revision. If the network is down we fall back to
/// the same offline-pending-uploads queue used by [AssessmentGameScreen].
///
/// If the exercise ships no usable steps (`hasInteractiveSteps == false`)
/// the screen renders a localized empty-state with the parrot mascot
/// rather than crashing — callers should still avoid routing here, but
/// the defensive empty-state keeps stale deeplinks safe.
class InteractiveLessonScreen extends ConsumerStatefulWidget {
  const InteractiveLessonScreen({
    super.key,
    required this.childId,
    required this.exerciseId,
  });

  final String childId;
  final String exerciseId;

  @override
  ConsumerState<InteractiveLessonScreen> createState() =>
      _InteractiveLessonScreenState();
}

class _InteractiveLessonScreenState
    extends ConsumerState<InteractiveLessonScreen> {
  late final AudioRecorderService _recorder;
  late final PreviewPlayer _player;
  final _confetti =
      ConfettiController(duration: const Duration(milliseconds: 1100));

  int _index = 0;
  bool _isRecording = false;
  bool _isPlayingPreview = false;
  bool _submitting = false;
  bool _permissionDenied = false;
  bool _permissionPermanent = false;
  int _seconds = 0;
  double _amplitude = -45;

  /// Recording paths keyed by the step index. The newest take per step
  /// always wins; this keeps "record again" idempotent without growing
  /// the temp-file footprint.
  final Map<int, String> _recordings = <int, String>{};

  Timer? _timer;
  StreamSubscription<AmplitudeSample>? _ampSub;
  StreamSubscription<PreviewPlaybackState>? _playerSub;

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
      if (s.completed) {
        _player.seekToStart();
        _player.pause();
      }
      if (_isPlayingPreview != s.playing) {
        setState(() => _isPlayingPreview = s.playing);
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

  // ---------------------------------------------------------------------
  // Step navigation
  // ---------------------------------------------------------------------

  void _advance(List<ExerciseStep> steps) {
    if (_index >= steps.length - 1) {
      _finish();
      return;
    }
    // Stop any active recording / playback before moving on so the next
    // step starts from a clean state.
    if (_isRecording) _stopRecording();
    if (_player.state.playing) _player.pause();
    setState(() {
      _index += 1;
      _seconds = 0;
      _amplitude = -45;
      _permissionDenied = false;
      _permissionPermanent = false;
    });
  }

  Future<bool> _confirmExit() async {
    final l = L.of(context)!;
    // No work to lose? Just leave.
    if (_recordings.isEmpty && _index == 0) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          l.lessonPlayerExitTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(l.lessonPlayerExitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.lessonPlayerExitCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.lessonPlayerExitConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ---------------------------------------------------------------------
  // Recording lifecycle (RecordStep)
  // ---------------------------------------------------------------------

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

    if (_player.state.playing) {
      await _player.stop();
    }

    String? path;
    try {
      path = await _recorder.start(
        quality: ref.read(audioQualityProvider),
      );
    } catch (_) {
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
      _seconds = 0;
      _amplitude = -45;
      // Discard any previous take for this step — the user explicitly
      // chose to re-record, so the old file is no longer relevant.
      _recordings.remove(_index);
    });

    // Path is captured so the timer-driven auto-stop has somewhere to
    // write the file path back into [_recordings].
    _activePath = path;
  }

  String? _activePath;

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    final finalPath = path ?? _activePath;
    final hasFile =
        finalPath != null && finalPath.isNotEmpty && File(finalPath).existsSync();
    setState(() {
      _isRecording = false;
      _amplitude = -45;
      if (hasFile) _recordings[_index] = finalPath;
    });
    if (hasFile) {
      try {
        await _player.setFilePath(finalPath);
      } catch (_) {/* preview still optional */}
      _confetti.play();
    }
  }

  Future<void> _togglePreview() async {
    final path = _recordings[_index];
    if (path == null) return;
    try {
      if (_isPlayingPreview) {
        await _player.pause();
      } else {
        if (_player.state.idle) {
          await _player.setFilePath(path);
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

  Future<void> _resetRecordingForCurrentStep() async {
    if (_player.state.playing) await _player.stop();
    setState(() {
      _recordings.remove(_index);
      _seconds = 0;
      _isPlayingPreview = false;
    });
  }

  // ---------------------------------------------------------------------
  // Final submission
  // ---------------------------------------------------------------------

  Future<void> _finish() async {
    final l = L.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (_isRecording) await _stopRecording();
    if (_player.state.playing) await _player.stop();

    // Pick the most recent recording (highest step index) as the
    // assessment audio. Falls through to "no audio" when the lesson had
    // only narrator/demo steps — the API still accepts that and we just
    // record the attempt without scoring.
    String? audioPath;
    if (_recordings.isNotEmpty) {
      final highestIndex = _recordings.keys.reduce((a, b) => a > b ? a : b);
      audioPath = _recordings[highestIndex];
    }

    setState(() => _submitting = true);

    try {
      final api = AssessmentsApi(ref.read(dioProvider));
      final result = await api.create(
        childId: widget.childId,
        exerciseId: widget.exerciseId,
        audioPath: audioPath,
      );
      ref.invalidate(assessmentsProvider);
      if (!mounted) return;
      context.go('/assessment/results/${result.id}');
    } catch (_) {
      String message = l.networkError;
      try {
        if (audioPath != null) {
          final stablePath = await _moveAudioToPermanentDir(audioPath);
          final service =
              await ref.read(pendingUploadsServiceProvider.future);
          await service.enqueue(
            id: 'pu_${DateTime.now().microsecondsSinceEpoch}',
            childId: widget.childId,
            exerciseId: widget.exerciseId,
            audioPath: stablePath,
          );
          message = l.uploadQueued;
        }
      } catch (_) {/* fall through to plain network-error message */}

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(message)));
      setState(() => _submitting = false);
      if (message == l.uploadQueued) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) context.go('/');
      }
    }
  }

  Future<String> _moveAudioToPermanentDir(String tempPath) async {
    final docs = await getApplicationDocumentsDirectory();
    final pendingDir = Directory('${docs.path}/sado_pending');
    if (!pendingDir.existsSync()) {
      pendingDir.createSync(recursive: true);
    }
    final fileName = 'lesson_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final dest = '${pendingDir.path}/$fileName';
    final src = File(tempPath);
    if (src.existsSync()) {
      await src.copy(dest);
    }
    return dest;
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final exercises = ref.watch(exercisesProvider);

    return exercises.when(
      data: (res) {
        Exercise? exercise;
        for (final e in res.items) {
          if (e.id == widget.exerciseId) {
            exercise = e;
            break;
          }
        }
        if (exercise == null) {
          return _ExitScaffold(
            title: l.exerciseNotFound,
            child: _CenteredEmpty(
              mood: ParrotMood.sad,
              title: l.exerciseNotFound,
              body: l.exerciseLoadFailed,
            ),
            onClose: () => context.go('/exercises'),
          );
        }

        final steps = exercise.steps ?? const <ExerciseStep>[];
        if (steps.isEmpty) {
          return _ExitScaffold(
            title: exercise.title,
            child: _CenteredEmpty(
              mood: ParrotMood.idle,
              title: l.lessonPlayerEmpty,
              body: l.exerciseNoSteps,
            ),
            onClose: () => context.go('/exercises/${widget.exerciseId}'),
          );
        }

        // Clamp the index defensively so out-of-range values from a
        // re-render race never explode the lesson.
        final safeIndex = _index.clamp(0, steps.length - 1);
        final currentStep = steps[safeIndex];
        final color = AppColors.categoryColor(exercise.category);
        final locale = Localizations.localeOf(context).languageCode;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            // Capture the router before the async gap so the analyzer
            // doesn't (correctly) warn about using a stale context.
            final router = GoRouter.of(context);
            final shouldExit = await _confirmExit();
            if (!shouldExit) return;
            if (mounted) router.go('/exercises/${widget.exerciseId}');
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              title: Text(
                l.lessonPlayerStepCounter(safeIndex + 1, steps.length),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: l.lessonPlayerExitTitle,
                onPressed: () async {
                  final router = GoRouter.of(context);
                  final shouldExit = await _confirmExit();
                  if (!shouldExit) return;
                  if (mounted) {
                    router.go('/exercises/${widget.exerciseId}');
                  }
                },
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(6),
                child: Semantics(
                  label: l.lessonPlayerProgressSemantics(
                      safeIndex + 1, steps.length),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: (safeIndex + 1) / steps.length,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
            ),
            body: ConfettiHost(
              controller: _confetti,
              child: SafeArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey('step-$safeIndex'),
                    child: _StepBody(
                      step: currentStep,
                      stepIndex: safeIndex,
                      totalSteps: steps.length,
                      color: color,
                      locale: locale,
                      isFinalStep: safeIndex == steps.length - 1,
                      isRecording: _isRecording,
                      hasRecording: _recordings.containsKey(safeIndex),
                      isPlayingPreview: _isPlayingPreview,
                      seconds: _seconds,
                      amplitude: _amplitude,
                      submitting: _submitting,
                      permissionDenied: _permissionDenied,
                      permissionPermanent: _permissionPermanent,
                      onAdvance: () => _advance(steps),
                      onFinish: _finish,
                      onToggleRecord: _toggleRecord,
                      onTogglePreview: _togglePreview,
                      onResetRecording: _resetRecordingForCurrentStep,
                      onOpenSettings: openAppSettings,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => _ExitScaffold(
        title: l.lessonPlayerStarting,
        child: MascotLoader(message: l.lessonPlayerStarting),
        onClose: () => context.go('/exercises/${widget.exerciseId}'),
      ),
      error: (_, __) => _ExitScaffold(
        title: l.error,
        child: _CenteredEmpty(
          mood: ParrotMood.sad,
          title: l.error,
          body: l.tryAgainLater,
        ),
        onClose: () => context.go('/exercises/${widget.exerciseId}'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

/// Renders the body for the current lesson step. Stateless so the parent
/// owns all the recording / submission state.
class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.color,
    required this.locale,
    required this.isFinalStep,
    required this.isRecording,
    required this.hasRecording,
    required this.isPlayingPreview,
    required this.seconds,
    required this.amplitude,
    required this.submitting,
    required this.permissionDenied,
    required this.permissionPermanent,
    required this.onAdvance,
    required this.onFinish,
    required this.onToggleRecord,
    required this.onTogglePreview,
    required this.onResetRecording,
    required this.onOpenSettings,
  });

  final ExerciseStep step;
  final int stepIndex;
  final int totalSteps;
  final Color color;
  final String locale;
  final bool isFinalStep;

  final bool isRecording;
  final bool hasRecording;
  final bool isPlayingPreview;
  final int seconds;
  final double amplitude;
  final bool submitting;
  final bool permissionDenied;
  final bool permissionPermanent;

  final VoidCallback onAdvance;
  final VoidCallback onFinish;
  final VoidCallback onToggleRecord;
  final VoidCallback onTogglePreview;
  final VoidCallback onResetRecording;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      InstructionStep() => _InstructionLayout(
          step: step as InstructionStep,
          color: color,
          locale: locale,
          isFinalStep: isFinalStep,
          submitting: submitting,
          onAdvance: onAdvance,
          onFinish: onFinish,
        ),
      DemonstrateStep() => _DemonstrateLayout(
          step: step as DemonstrateStep,
          color: color,
          locale: locale,
          isFinalStep: isFinalStep,
          submitting: submitting,
          onAdvance: onAdvance,
          onFinish: onFinish,
        ),
      RecordStep() => _RecordLayout(
          step: step as RecordStep,
          color: color,
          locale: locale,
          isFinalStep: isFinalStep,
          isRecording: isRecording,
          hasRecording: hasRecording,
          isPlayingPreview: isPlayingPreview,
          seconds: seconds,
          amplitude: amplitude,
          submitting: submitting,
          permissionDenied: permissionDenied,
          permissionPermanent: permissionPermanent,
          onToggleRecord: onToggleRecord,
          onTogglePreview: onTogglePreview,
          onResetRecording: onResetRecording,
          onAdvance: onAdvance,
          onFinish: onFinish,
          onOpenSettings: onOpenSettings,
        ),
      FeedbackStep() => _FeedbackLayout(
          step: step as FeedbackStep,
          color: color,
          locale: locale,
          submitting: submitting,
          onFinish: onFinish,
        ),
      UnknownStep() => _UnknownLayout(
          color: color,
          isFinalStep: isFinalStep,
          submitting: submitting,
          onAdvance: onAdvance,
          onFinish: onFinish,
        ),
    };
  }
}

class _InstructionLayout extends StatelessWidget {
  const _InstructionLayout({
    required this.step,
    required this.color,
    required this.locale,
    required this.isFinalStep,
    required this.submitting,
    required this.onAdvance,
    required this.onFinish,
  });

  final InstructionStep step;
  final Color color;
  final String locale;
  final bool isFinalStep;
  final bool submitting;
  final VoidCallback onAdvance;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final text = step.localizedText(locale).trim().isEmpty
        ? l.lessonStepInstructionFallback
        : step.localizedText(locale);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          ParrotMascot(mood: ParrotMood.talking, size: 160, message: text)
              .animate()
              .fadeIn(duration: 280.ms),
          const SizedBox(height: AppSpacing.lg),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.lessonPlayerInstructionTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _ContinueButton(
            isFinalStep: isFinalStep,
            color: color,
            submitting: submitting,
            onAdvance: onAdvance,
            onFinish: onFinish,
          ),
        ],
      ),
    );
  }
}

class _DemonstrateLayout extends StatelessWidget {
  const _DemonstrateLayout({
    required this.step,
    required this.color,
    required this.locale,
    required this.isFinalStep,
    required this.submitting,
    required this.onAdvance,
    required this.onFinish,
  });

  final DemonstrateStep step;
  final Color color;
  final String locale;
  final bool isFinalStep;
  final bool submitting;
  final VoidCallback onAdvance;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final text = step.localizedText(locale).trim().isEmpty
        ? l.lessonStepDemonstrateFallback
        : step.localizedText(locale);
    final audioUrl = resolveMediaUrl(step.audioUrl);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          ParrotMascot(
            mood: ParrotMood.listening,
            size: 140,
            message: l.lessonPlayerDemonstrateHint,
          ).animate().fadeIn(duration: 280.ms),
          const SizedBox(height: AppSpacing.md),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.lessonPlayerDemonstrateTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (audioUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            AudioExamplePlayer(
              url: audioUrl,
              label: l.listenExample,
              errorLabel: l.audioExampleUnavailable,
              color: color,
            ),
          ],
          const Spacer(),
          _ContinueButton(
            isFinalStep: isFinalStep,
            color: color,
            submitting: submitting,
            onAdvance: onAdvance,
            onFinish: onFinish,
          ),
        ],
      ),
    );
  }
}

class _RecordLayout extends StatelessWidget {
  const _RecordLayout({
    required this.step,
    required this.color,
    required this.locale,
    required this.isFinalStep,
    required this.isRecording,
    required this.hasRecording,
    required this.isPlayingPreview,
    required this.seconds,
    required this.amplitude,
    required this.submitting,
    required this.permissionDenied,
    required this.permissionPermanent,
    required this.onToggleRecord,
    required this.onTogglePreview,
    required this.onResetRecording,
    required this.onAdvance,
    required this.onFinish,
    required this.onOpenSettings,
  });

  final RecordStep step;
  final Color color;
  final String locale;
  final bool isFinalStep;
  final bool isRecording;
  final bool hasRecording;
  final bool isPlayingPreview;
  final int seconds;
  final double amplitude;
  final bool submitting;
  final bool permissionDenied;
  final bool permissionPermanent;

  final VoidCallback onToggleRecord;
  final VoidCallback onTogglePreview;
  final VoidCallback onResetRecording;
  final VoidCallback onAdvance;
  final VoidCallback onFinish;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final word = step.displayWord(locale);
    final mascotMood = isRecording
        ? ParrotMood.listening
        : (hasRecording ? ParrotMood.happy : ParrotMood.talking);
    final mascotMessage = permissionDenied
        ? (permissionPermanent
            ? l.permissionPermanentlyDeniedBody
            : l.microphonePermissionBody)
        : (isRecording
            ? l.recording
            : (hasRecording
                ? l.lessonPlayerRecordReadyHint
                : l.lessonPlayerRecordHint));

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          ParrotMascot(
            mood: mascotMood,
            size: 140,
            message: mascotMessage,
          ).animate().fadeIn(duration: 280.ms),
          const SizedBox(height: AppSpacing.md),
          if (word.trim().isNotEmpty)
            PremiumCard(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.lg,
                horizontal: AppSpacing.lg,
              ),
              child: Column(
                children: [
                  Text(
                    l.lessonPlayerRecordTitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    word,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (step.targetPhonemes != null &&
                      step.targetPhonemes!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final p in step.targetPhonemes!)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              p,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
              key: ValueKey(seconds ~/ 5),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color:
                    isRecording ? AppColors.danger : AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isRecording) ...[
            RecordingProgressBar(elapsedSeconds: seconds)
                .animate()
                .fadeIn(duration: 220.ms),
            const SizedBox(height: AppSpacing.sm),
            PremiumCard(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.lg,
              ),
              child: WaveformVisualizer(
                amplitude: amplitude,
                active: true,
              ),
            ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.1),
          ],
          const Spacer(),
          if (permissionDenied)
            PremiumButton(
              label: permissionPermanent ? l.openSettings : l.grantPermission,
              icon: Icons.mic_rounded,
              color: color,
              onPressed: () async {
                if (permissionPermanent) {
                  await onOpenSettings();
                } else {
                  onToggleRecord();
                }
              },
            )
          else if (!hasRecording)
            Center(
              child: RecordingButton(
                recording: isRecording,
                onTap: onToggleRecord,
              ),
            )
          else ...[
            PremiumCard(
              onTap: submitting ? null : onTogglePreview,
              shadowColor: AppColors.tertiary,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.tertiary,
                      shape: BoxShape.circle,
                      boxShadow: AppShadow.soft(AppColors.tertiary),
                    ),
                    child: Icon(
                      isPlayingPreview
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPlayingPreview
                              ? l.pauseRecording
                              : l.playRecording,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          l.secondsShort(seconds),
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
            const SizedBox(height: AppSpacing.sm),
            PremiumButton(
              label: l.recordAgain,
              icon: Icons.replay_rounded,
              color: AppColors.surfaceMuted,
              foreground: AppColors.textPrimary,
              onPressed: submitting ? null : onResetRecording,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ContinueButton(
              isFinalStep: isFinalStep,
              color: color,
              submitting: submitting,
              onAdvance: onAdvance,
              onFinish: onFinish,
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackLayout extends StatelessWidget {
  const _FeedbackLayout({
    required this.step,
    required this.color,
    required this.locale,
    required this.submitting,
    required this.onFinish,
  });

  final FeedbackStep step;
  final Color color;
  final String locale;
  final bool submitting;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final encouragement = step.localizedEncouragement(locale).trim().isEmpty
        ? l.lessonPlayerCompleted
        : step.localizedEncouragement(locale);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          ParrotMascot(
            mood: ParrotMood.happy,
            size: 180,
            message: encouragement,
          ).animate().fadeIn(duration: 280.ms),
          const SizedBox(height: AppSpacing.lg),
          PremiumCard(
            gradient: AppColors.sunsetGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.lessonPlayerFeedbackTitle.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  encouragement,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          PremiumButton(
            label: submitting
                ? l.lessonPlayerSubmitting
                : l.lessonPlayerFinish,
            icon: Icons.check_circle_rounded,
            color: color,
            loading: submitting,
            onPressed: submitting ? null : onFinish,
          ),
        ],
      ),
    );
  }
}

class _UnknownLayout extends StatelessWidget {
  const _UnknownLayout({
    required this.color,
    required this.isFinalStep,
    required this.submitting,
    required this.onAdvance,
    required this.onFinish,
  });

  final Color color;
  final bool isFinalStep;
  final bool submitting;
  final VoidCallback onAdvance;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          const ParrotMascot(mood: ParrotMood.idle, size: 140),
          const SizedBox(height: AppSpacing.lg),
          PremiumCard(
            child: Column(
              children: [
                Icon(Icons.skip_next_rounded, color: color, size: 32),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l.lessonStepUnknown,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.lessonStepInstructionFallback,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _ContinueButton(
            isFinalStep: isFinalStep,
            color: color,
            submitting: submitting,
            onAdvance: onAdvance,
            onFinish: onFinish,
          ),
        ],
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.isFinalStep,
    required this.color,
    required this.submitting,
    required this.onAdvance,
    required this.onFinish,
  });

  final bool isFinalStep;
  final Color color;
  final bool submitting;
  final VoidCallback onAdvance;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    if (isFinalStep) {
      return PremiumButton(
        label: submitting ? l.lessonPlayerSubmitting : l.lessonPlayerFinish,
        icon: Icons.check_circle_rounded,
        color: color,
        loading: submitting,
        onPressed: submitting ? null : onFinish,
      );
    }
    return PremiumButton(
      label: l.lessonPlayerNext,
      icon: Icons.arrow_forward_rounded,
      color: color,
      onPressed: submitting ? null : onAdvance,
    );
  }
}

class _ExitScaffold extends StatelessWidget {
  const _ExitScaffold({
    required this.title,
    required this.child,
    required this.onClose,
  });

  final String title;
  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: onClose,
        ),
      ),
      body: SafeArea(child: Center(child: child)),
    );
  }
}

class _CenteredEmpty extends StatelessWidget {
  const _CenteredEmpty({
    required this.mood,
    required this.title,
    required this.body,
  });

  final ParrotMood mood;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ParrotMascot(mood: mood, size: 140),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
