import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_card.dart';

/// Pre-assessment intro that walks a child through "what to do" before the
/// recording begins. Uses a 3‑2‑1 countdown with an entrance animation so it
/// feels like a real "Ready, set, go!" moment.
class AssessmentIntroScreen extends ConsumerStatefulWidget {
  const AssessmentIntroScreen({
    super.key,
    required this.childId,
    required this.exerciseId,
  });

  final String childId;
  final String exerciseId;

  @override
  ConsumerState<AssessmentIntroScreen> createState() =>
      _AssessmentIntroScreenState();
}

class _AssessmentIntroScreenState
    extends ConsumerState<AssessmentIntroScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the 3→2→1 countdown via an [AnimationController] (Ticker-based)
  /// rather than a [Timer.periodic]. This matters in widget tests: the
  /// framework asserts `!timersPending` at teardown and a periodic timer
  /// scheduled mid-test would always trip that invariant. Tickers are
  /// driven by the scheduler and don't show up as pending timers.
  late final AnimationController _countdownCtrl;
  int? _countdown;
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _countdownCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )
      ..addListener(_onCountdownTick)
      ..addStatusListener(_onCountdownStatus);
  }

  @override
  void dispose() {
    _countdownCtrl
      ..removeListener(_onCountdownTick)
      ..removeStatusListener(_onCountdownStatus)
      ..dispose();
    super.dispose();
  }

  void _onCountdownTick() {
    // Linear value 0..1 over 3 seconds → remaining = 3, 2, 1.
    final remaining = (3 - _countdownCtrl.value * 3).ceil().clamp(1, 3);
    if (remaining != _countdown) {
      setState(() => _countdown = remaining);
    }
  }

  void _onCountdownStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_routed && mounted) {
      _routed = true;
      context.go('/assessment/${widget.childId}/${widget.exerciseId}');
    }
  }

  void _startCountdown() {
    if (_countdown != null) return;
    setState(() => _countdown = 3);
    _countdownCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final exercises = ref.watch(exercisesProvider);

    final exercise = exercises.maybeWhen(
      data: (res) {
        for (final e in res.items) {
          if (e.id == widget.exerciseId) return e;
        }
        return null;
      },
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.startAssessment),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/exercises/${widget.exerciseId}'),
        ),
      ),
      body: SafeArea(
        child: _countdown == null
            ? _Intro(
                title: exercise?.title ?? l.startAssessment,
                tips: [l.introTip1, l.introTip2, l.introTip3],
                onStart: _startCountdown,
                getReadyLabel: l.getReady,
                startLabel: l.letsStart,
              )
            : _Countdown(value: _countdown!),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({
    required this.title,
    required this.tips,
    required this.onStart,
    required this.getReadyLabel,
    required this.startLabel,
  });

  final String title;
  final List<String> tips;
  final VoidCallback onStart;
  final String getReadyLabel;
  final String startLabel;

  @override
  Widget build(BuildContext context) {
    // The intro must keep the CTA visible at all times, even on shorter
    // (landscape, foldable, small-phone) viewports where the mascot +
    // header + tip cards would otherwise overflow. We use a Column with a
    // scrollable middle section so the button stays anchored at the bottom
    // and the rest can scroll if the screen is short.
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: ParrotMascot(
                      mood: ParrotMood.happy,
                      size: 160,
                      message: getReadyLabel,
                    )
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .scale(begin: const Offset(0.9, 0.9)),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (var i = 0; i < tips.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: PremiumCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                tips[i],
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate(delay: (i * 70).ms)
                          .fadeIn()
                          .slideY(begin: 0.1),
                    ),
                ],
              ),
            ),
          ),
          PremiumButton(
            label: startLabel,
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ParrotMascot(mood: ParrotMood.listening, size: 160),
          const SizedBox(height: AppSpacing.xxl),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: const TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
