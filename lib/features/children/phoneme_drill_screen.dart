import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../domain/speech_profile/phoneme_mastery.dart';
import '../../providers/providers.dart';
import '../../widgets/difficulty_stars.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/shimmer_loaders.dart';

/// Per-phoneme practice drill screen.
///
/// Reached from any phoneme tile / chip on the speech profile. Combines:
///   * a coloured hero card with the phoneme glyph, current mastery
///     accuracy, sample count and the parrot mascot (mood follows the
///     mastery bucket — happy when mastered, neutral when developing,
///     sad when struggling),
///   * a localised coach line tuned to the bucket,
///   * a list of recommended exercises that target the phoneme, sorted
///     easiest-to-hardest so the suggested starting point is at the top.
///
/// Loading renders shimmer skeletons (no default Material spinner).
/// Errors render the branded [ErrorState] with retry. The empty state
/// (no exercises target this phoneme yet) keeps the parrot mascot, a
/// friendly explanation, and a "browse all exercises" CTA so the user
/// is never trapped on a dead end.
class PhonemeDrillScreen extends ConsumerWidget {
  const PhonemeDrillScreen({
    super.key,
    required this.childId,
    required this.phoneme,
  });

  final String childId;
  final String phoneme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final normalised = PhonemeMasteryAggregator.normalize(phoneme);
    final state = ref.watch(
      phonemeDrillProvider((childId: childId, phoneme: normalised)),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.phonemeDrillTitle(_displayPhoneme(normalised))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/children/$childId/speech-profile'),
        ),
      ),
      body: state.when(
        loading: () => const _PhonemeDrillLoading(),
        error: (_, __) => ErrorState(
          title: l.phonemeDrillErrorTitle,
          body: l.phonemeDrillErrorBody,
          retryLabel: l.phonemeDrillRetry,
          onRetry: () => ref.invalidate(
            phonemeDrillProvider(
              (childId: childId, phoneme: normalised),
            ),
          ),
        ),
        data: (data) => _PhonemeDrillBody(
          data: data,
          childId: childId,
        ),
      ),
    );
  }

  /// Restore a friendly display form (upper-case + slash markers) for the
  /// app-bar title. The provider already lower-cases for grouping so we
  /// only need a thin pretty-printer here.
  String _displayPhoneme(String code) =>
      code.isEmpty ? code : '/${code.toUpperCase()}/';
}

class _PhonemeDrillLoading extends StatelessWidget {
  const _PhonemeDrillLoading();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Semantics(
      label: l.phonemeDrillLoading,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          ShimmerCard(height: 160),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 96),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 96),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 96),
        ],
      ),
    );
  }
}

class _PhonemeDrillBody extends ConsumerWidget {
  const _PhonemeDrillBody({required this.data, required this.childId});

  final PhonemeDrillData data;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final mastery = data.mastery;
    final level = mastery?.level ?? PhonemeMasteryLevel.developing;
    final tone = _ToneForLevel(level);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (data.exercisesFromCache)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: OfflineBanner(message: l.offlineCached),
          ),

        // ── Hero ──────────────────────────────────────────────────
        _HeroCard(
          phoneme: data.phoneme,
          mastery: mastery,
          tone: tone,
        ).animate().fadeIn(duration: 320.ms).slideY(begin: -0.04),

        const SizedBox(height: AppSpacing.lg),

        // ── Coach copy ────────────────────────────────────────────
        _CoachCard(level: level, tone: tone)
            .animate()
            .fadeIn(duration: 320.ms, delay: 80.ms)
            .slideY(begin: 0.03),

        const SizedBox(height: AppSpacing.lg),

        // ── Exercises ─────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                l.phonemeDrillExercisesHeader,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            if (data.exercises.isNotEmpty)
              Text(
                l.phonemeDrillExercisesCount(data.exercises.length),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        if (data.hasNoExercises)
          _NoExercisesCard(onBrowseAll: () => context.go('/exercises'))
              .animate()
              .fadeIn(duration: 320.ms, delay: 160.ms)
        else
          Column(
            children: [
              for (var i = 0; i < data.exercises.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ExerciseTile(exercise: data.exercises[i])
                      .animate()
                      .fadeIn(
                        duration: 280.ms,
                        delay: (160 + i * 40).ms,
                      )
                      .slideY(begin: 0.04),
                ),
              const SizedBox(height: AppSpacing.sm),
              PremiumButton(
                label: l.phonemeDrillStartCta,
                icon: Icons.play_arrow_rounded,
                onPressed: () => _startFirstExercise(context, ref),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => context.go('/exercises'),
                icon: const Icon(Icons.list_alt_rounded),
                label: Text(l.phonemeDrillBrowseAll),
              ),
            ],
          ),

        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }

  void _startFirstExercise(BuildContext context, WidgetRef ref) {
    if (data.exercises.isEmpty) return;
    // Set the active child so /exercises and the assessment intro pre-fill
    // it, then deep-link into the exercise detail — the parent picks up
    // from the same flow used elsewhere in the app.
    ref.read(selectedChildIdProvider.notifier).state = childId;
    final first = data.exercises.first;
    context.go('/exercises/${first.id}');
  }
}

/// Hero card colours + supporting copy keyed on the mastery bucket.
class _ToneForLevel {
  factory _ToneForLevel(PhonemeMasteryLevel level) {
    switch (level) {
      case PhonemeMasteryLevel.struggling:
        return const _ToneForLevel._(
          colorHex: AppColors.danger,
          mood: ParrotMood.sad,
          icon: Icons.priority_high_rounded,
        );
      case PhonemeMasteryLevel.developing:
        return const _ToneForLevel._(
          colorHex: AppColors.warning,
          mood: ParrotMood.idle,
          icon: Icons.trending_up_rounded,
        );
      case PhonemeMasteryLevel.mastered:
        return const _ToneForLevel._(
          colorHex: AppColors.success,
          mood: ParrotMood.happy,
          icon: Icons.check_circle_rounded,
        );
    }
  }

  const _ToneForLevel._({
    required this.colorHex,
    required this.mood,
    required this.icon,
  });

  final Color colorHex;
  final ParrotMood mood;
  final IconData icon;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.phoneme,
    required this.mastery,
    required this.tone,
  });

  final String phoneme;
  final PhonemeMastery? mastery;
  final _ToneForLevel tone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final percent = mastery?.accuracyPercent ?? 0;
    return PremiumCard(
      gradient: [tone.colorHex, tone.colorHex.withValues(alpha: 0.78)],
      shadowColor: tone.colorHex,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          // Phoneme glyph + animated accuracy ring.
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (mastery != null)
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0, end: mastery!.accuracy),
                    builder: (_, value, __) => SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 6,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ParrotMascot(mood: tone.mood, size: 64),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phoneme.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                if (mastery != null) ...[
                  Text(
                    l.phonemeDrillHeroAccuracy,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.phonemeDrillHeroSamples(mastery!.sampleCount),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ] else
                  Text(
                    l.speechProfileEmptyTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.level, required this.tone});

  final PhonemeMasteryLevel level;
  final _ToneForLevel tone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final body = switch (level) {
      PhonemeMasteryLevel.struggling => l.phonemeDrillCoachStruggling,
      PhonemeMasteryLevel.developing => l.phonemeDrillCoachDeveloping,
      PhonemeMasteryLevel.mastered => l.phonemeDrillCoachMastered,
    };
    final bucketLabel = switch (level) {
      PhonemeMasteryLevel.struggling => l.phonemeDrillBucketStruggling,
      PhonemeMasteryLevel.developing => l.phonemeDrillBucketDeveloping,
      PhonemeMasteryLevel.mastered => l.phonemeDrillBucketMastered,
    };

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tone.colorHex.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(tone.icon, color: tone.colorHex, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bucketLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: tone.colorHex,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.35,
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

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Semantics(
      button: true,
      label: l.phonemeDrillTileSemantics(exercise.title),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: () => context.go('/exercises/${exercise.id}'),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      DifficultyStars(
                        difficulty: exercise.difficulty,
                        showLabel: false,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${exercise.durationMinutes} ${l.minutes}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _NoExercisesCard extends StatelessWidget {
  const _NoExercisesCard({required this.onBrowseAll});
  final VoidCallback onBrowseAll;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return EmptyState(
      title: l.phonemeDrillNoExercisesTitle,
      body: l.phonemeDrillNoExercisesBody,
      ctaLabel: l.phonemeDrillBrowseAll,
      ctaIcon: Icons.list_alt_rounded,
      onCta: onBrowseAll,
    );
  }
}
