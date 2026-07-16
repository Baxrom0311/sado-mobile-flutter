import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/badge_celebration.dart';
import '../../core/gamification.dart';
import '../../core/theme.dart';
import '../../core/utils/haptics.dart';
import '../../data/api/api_client.dart';
import '../../data/api/assessments_api.dart';
import '../../data/models/models.dart';
import '../../data/models/recommendation_synthesizer.dart';
import '../../providers/providers.dart';
import '../../widgets/animated_counter.dart';
import '../../widgets/audio_example_player.dart';
import '../../widgets/confetti_host.dart';
import '../../widgets/fluency_stats_card.dart';
import '../../widgets/loaders.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/phoneme_breakdown_card.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/recommendations_list.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/score_ring.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/transcript_card.dart';
import '../../widgets/voice_quality_card.dart';
import '../../widgets/weak_phonemes_card.dart';

final _assessmentDetailProvider =
    FutureProvider.family<Assessment, String>((ref, id) async {
  final api = AssessmentsApi(ref.watch(dioProvider));
  return api.get(id);
});

class AssessmentResultsScreen extends ConsumerStatefulWidget {
  const AssessmentResultsScreen({super.key, required this.assessmentId});
  final String assessmentId;

  @override
  ConsumerState<AssessmentResultsScreen> createState() =>
      _AssessmentResultsScreenState();
}

class _AssessmentResultsScreenState
    extends ConsumerState<AssessmentResultsScreen> {
  final _confetti =
      ConfettiController(duration: const Duration(milliseconds: 1500));
  bool _awarded = false;

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _awardOnce(Assessment a) async {
    if (_awarded) return;
    _awarded = true;
    final assessmentsList = ref.read(assessmentsProvider(null));
    final total = assessmentsList.maybeWhen(
      data: (r) => r.items.length,
      orElse: () => 1,
    );
    final unlocked = await ref.read(gameProvider.notifier).recordAssessment(
          totalAssessments: total,
          score: a.score,
        );
    if ((a.score ?? 0) >= 0.75) {
      _confetti.play();
      // Tactile celebration for the score itself, even if no badge was
      // unlocked. Badge unlocks already pulse Haptics.success() per badge
      // via `celebrateUnlockedBadges`, so we only fire here when the
      // unlocked list is empty to avoid a double-pulse on top of the
      // dialog cascade.
      if (unlocked.isEmpty) Haptics.success();
    }
    if (unlocked.isEmpty || !mounted) return;
    // Let the score-ring counter finish its tween before piling a dialog
    // on top — gives the user a beat to read the headline number first.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await celebrateUnlockedBadges(context, unlocked);
  }

  // Title/body lookup is intentionally kept here for the BadgeTile inside
  // the screen (if added in future). The cascading dialog flow now flows
  // through `celebrateUnlockedBadges`, which owns its own copy lookup.

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final result = ref.watch(_assessmentDetailProvider(widget.assessmentId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.assessmentComplete),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ConfettiHost(
        controller: _confetti,
        child: result.when(
          data: (a) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _awardOnce(a));
            return _Body(assessment: a);
          },
          loading: () => MascotLoader(message: l.loadingResults),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ParrotMascot(mood: ParrotMood.sad, size: 130),
                const SizedBox(height: AppSpacing.lg),
                Text(l.error,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.assessment});
  final Assessment assessment;

  Future<void> _shareResult(BuildContext context) async {
    final l = L.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final risk = RiskLevel.fromApi(assessment.overallRisk);
    final score = assessment.score ?? 0;
    final percent = (score * 100).round();
    final message = l.shareResultMessage(percent, risk.label(l));
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.resultCopied),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final risk = RiskLevel.fromApi(assessment.overallRisk);
    final color = risk.color;
    final score = assessment.score ?? 0;
    final percent = (score * 100).round();
    final greatScore = score >= 0.75;
    final mood =
        greatScore ? ParrotMood.happy : ParrotMood.idle;
    final message = greatScore
        ? l.mascotResultsGreat
        : (score >= 0.4 ? l.mascotResultsOk : l.mascotResultsNeedsWork);

    final icon = risk.icon;
    final label = risk.label(l);

    final analysis = ref.watch(assessmentAnalysisProvider(assessment.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          ParrotMascot(mood: mood, size: 150, message: message)
              .animate()
              .fadeIn(duration: 350.ms)
              .scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1)),
          const SizedBox(height: AppSpacing.xl),
          PremiumCard(
            gradient: [color, color.withValues(alpha: 0.7)],
            shadowColor: color,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Text(
                  l.assessmentComplete,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Premium custom-painted score gauge. Replaces the Material
                // default CircularProgressIndicator so the ring matches the
                // brand language (rounded caps, translucent track, no theme
                // colour bleed).
                ScoreRing(
                  value: score,
                  size: 130,
                  strokeWidth: 10,
                  foregroundColor: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated score counter — counts up from 0 to the
                      // final percentage so the result feels celebratory.
                      AnimatedCounter(
                        value: percent,
                        suffix: '%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                        ),
                      ),
                      Text(
                        l.score,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Animated XP earned card — counts up from 0 to 20 with a scale-in
          // pop so the reward is clearly readable as a celebration.
          PremiumCard(
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: AppColors.secondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: 20),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Text(
                      l.earnedXp(v),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate(delay: 250.ms)
              .fadeIn(duration: 320.ms)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1, 1),
                curve: Curves.easeOutBack,
              ),

          // "Your recording" playback — appears whenever the API returned an
          // audio_path. Lets parents replay what their child just recorded
          // without having to leave the results screen, which is a key
          // premium-feel beat for a speech-therapy app.
          if (resolveMediaUrl(assessment.audioPath) != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 4, bottom: AppSpacing.sm),
                child: Text(
                  l.yourRecordingTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            AudioExamplePlayer(
              key: const ValueKey('results.recordingPlayer'),
              url: resolveMediaUrl(assessment.audioPath)!,
              label: l.playRecording,
              errorLabel: l.audioCouldNotLoad,
              color: AppColors.tertiary,
            )
                .animate(delay: 400.ms)
                .fadeIn(duration: 320.ms)
                .slideY(begin: 0.08),
          ],

          // AI speech-analysis section.
          //
          // Hits the parent-safe `GET /analysis/{id}` endpoint and
          // renders four parent-friendly cards:
          //
          //   1. **Transcript** — what the AI heard, surfaced verbatim.
          //   2. **Phoneme breakdown** — per-phoneme accuracy bars,
          //      shown only when an explicit/therapist endpoint flat-
          //      tens scores into the response. Empty for parents on
          //      the standard endpoint.
          //   3. **Weak phonemes** — chips of the bottom-three phoneme
          //      codes from `feature_summary.weakest_phonemes`. This
          //      is the parent-friendly replacement for the per-phoneme
          //      bars when scores aren't exposed.
          //   4. **Fluency** — derived from `voiced_ratio` and
          //      `transcript_word_count / duration_sec`.
          //   5. **Recommendations** — synthesized client-side from
          //      the weak phonemes when the API doesn't supply any of
          //      its own (the parent endpoint never does today).
          //
          // We render:
          //   * a shimmer-style loader while the analyzer is in flight,
          //   * a friendly placeholder when the API returns an empty
          //     envelope (legacy assessment / pipeline still warming up),
          //   * the cards stacked, each rendering nothing if its own
          //     data slice is empty so the column stays compact.
          //
          // Errors during analysis fetch fall back to the same placeholder
          // — analysis is a *value-add* to the score, not a blocker, so we
          // never surface a red error state here. The score ring above
          // stays the headline.
          const SizedBox(height: AppSpacing.xl),
          analysis.when(
            loading: () => const _AnalysisLoading(),
            error: (_, __) => _AnalysisEmpty(),
            data: (a) {
              if (a.isEmpty) return _AnalysisEmpty();
              // Build the recommendations list: prefer explicit recs
              // from the API; otherwise synthesize them from the
              // weakest phonemes so parents always get something
              // actionable.
              final recs = a.recommendations.isNotEmpty
                  ? a.recommendations
                  : synthesizeRecommendations(l, a.weakestPhonemes);
              return Column(
                key: const ValueKey('results.analysisSection'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((a.transcript ?? '').trim().isNotEmpty) ...[
                    TranscriptCard(text: a.transcript)
                        .animate(delay: 450.ms)
                        .fadeIn(duration: 320.ms)
                        .slideY(begin: 0.08),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (a.phonemeScores.isNotEmpty) ...[
                    PhonemeBreakdownCard(scores: a.phonemeScores)
                        .animate(delay: 500.ms)
                        .fadeIn(duration: 320.ms)
                        .slideY(begin: 0.08),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (a.phonemeScores.isEmpty &&
                      a.weakestPhonemes.isNotEmpty) ...[
                    WeakPhonemesCard(phonemes: a.weakestPhonemes)
                        .animate(delay: 550.ms)
                        .fadeIn(duration: 320.ms)
                        .slideY(begin: 0.08),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (a.fluency != null) ...[
                    FluencyStatsCard(score: a.fluency)
                        .animate(delay: 600.ms)
                        .fadeIn(duration: 320.ms)
                        .slideY(begin: 0.08),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (a.voiceQuality != null) ...[
                    VoiceQualityCard(voiceQuality: a.voiceQuality)
                        .animate(delay: 650.ms)
                        .fadeIn(duration: 320.ms)
                        .slideY(begin: 0.08),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (recs.isNotEmpty)
                    RecommendationsList(
                      recommendations: recs,
                    )
                        .animate(delay: 700.ms)
                        .fadeIn(duration: 320.ms)
                        .slideY(begin: 0.08),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.xl),
          PremiumButton(
            key: const ValueKey('results.tryAnother'),
            label: l.tryAnotherExercise,
            icon: Icons.replay_rounded,
            onPressed: () => context.go('/exercises'),
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumButton(
            key: const ValueKey('results.share'),
            label: l.shareResult,
            icon: Icons.ios_share_rounded,
            color: AppColors.tertiary,
            onPressed: () => _shareResult(context),
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumButton(
            key: const ValueKey('results.home'),
            label: l.home,
            icon: Icons.home_rounded,
            color: AppColors.surfaceMuted,
            foreground: AppColors.textPrimary,
            onPressed: () => context.go('/'),
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumButton(
            key: const ValueKey('results.progress'),
            label: l.progress,
            icon: Icons.trending_up_rounded,
            color: AppColors.surfaceMuted,
            foreground: AppColors.textPrimary,
            onPressed: () => context.go('/progress'),
          ),
        ],
      ),
    );
  }
}


/// Shimmer placeholder for the AI-analysis section while
/// `GET /assessments/{id}/analysis` is in flight.
///
/// Three stacked cards mirror the production layout (phoneme grid,
/// fluency strip, recommendations) so the page doesn't reflow when the
/// real data lands. Avoids using a default [CircularProgressIndicator]
/// per the design-system rules.
class _AnalysisLoading extends StatelessWidget {
  const _AnalysisLoading();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Semantics(
      label: l.analysisLoadingMessage,
      child: Column(
        key: const ValueKey('results.analysisLoading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          ShimmerCard(height: 140),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 96),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 110),
        ],
      ),
    );
  }
}

/// Friendly placeholder shown when the analyzer hasn't produced data yet.
///
/// Surfaces explicitly localized copy so parents understand the score
/// they see is final but the AI insights are still warming up. Uses the
/// idle parrot mascot so the empty state still feels on-brand.
class _AnalysisEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return PremiumCard(
      key: const ValueKey('results.analysisEmpty'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ParrotMascot(mood: ParrotMood.idle, size: 64),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.analysisUnavailableTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.analysisUnavailableBody,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
