import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../domain/speech_profile/phoneme_mastery.dart';
import '../../providers/providers.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/phoneme_mastery_grid.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/shimmer_loaders.dart';

/// Aggregated AI-derived "Speech Profile" for a single child.
///
/// Tells the parent at a glance:
///   * the child's overall pronunciation accuracy,
///   * which phonemes are mastered,
///   * which phonemes the analyzer is flagging as the next focus,
///   * how many assessments contributed to the snapshot.
///
/// Loading shows shimmer cards (no default `CircularProgressIndicator`).
/// Errors render the branded [ErrorState] with retry. The empty state
/// hosts the parrot mascot and an "open exercises" CTA so a child with
/// no analyses yet has a clear next step.
class SpeechProfileScreen extends ConsumerWidget {
  const SpeechProfileScreen({super.key, required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final state = ref.watch(speechProfileProvider(childId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.speechProfileTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/children/$childId'),
        ),
      ),
      body: state.when(
        loading: () => const _SpeechProfileLoading(),
        error: (e, _) => ErrorState(
          title: l.speechProfileErrorTitle,
          body: l.speechProfileErrorBody,
          retryLabel: l.speechProfileRetry,
          onRetry: () => ref.invalidate(speechProfileProvider(childId)),
        ),
        data: (profile) {
          if (profile.isEmpty) {
            return EmptyState(
              title: l.speechProfileEmptyTitle,
              body: l.speechProfileEmptyBody,
              ctaLabel: l.speechProfileEmptyCta,
              ctaIcon: Icons.play_arrow_rounded,
              onCta: () {
                ref.read(selectedChildIdProvider.notifier).state = childId;
                context.go('/exercises');
              },
            );
          }
          return _SpeechProfileBody(profile: profile, childId: childId);
        },
      ),
    );
  }
}

class _SpeechProfileLoading extends StatelessWidget {
  const _SpeechProfileLoading();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Semantics(
      label: l.speechProfileLoading,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          ShimmerCard(height: 140),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 220),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 160),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 160),
        ],
      ),
    );
  }
}

class _SpeechProfileBody extends StatelessWidget {
  const _SpeechProfileBody({required this.profile, required this.childId});
  final SpeechProfile profile;
  final String childId;

  void _openDrill(BuildContext context, String phoneme) {
    // The route accepts the raw phoneme code; the drill screen
    // re-normalises before fetching to keep behaviour identical
    // regardless of whether callers passed "/r/", "R" or "r".
    context.go('/children/$childId/phonemes/$phoneme');
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ── Overall accuracy hero card ──────────────────────────
        _OverallAccuracyCard(profile: profile)
            .animate()
            .fadeIn(duration: 320.ms)
            .slideY(begin: -0.04),

        const SizedBox(height: AppSpacing.lg),

        // ── Master grid: every tracked phoneme ──────────────────
        Text(
          l.phonemeBreakdownTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: AppSpacing.sm),
        PhonemeMasteryGrid(
          phonemes: profile.phonemes,
          onPhonemeTap: (p) => _openDrill(context, p.phoneme),
        )
            .animate()
            .fadeIn(duration: 320.ms, delay: 80.ms)
            .slideY(begin: 0.04),

        const SizedBox(height: AppSpacing.lg),

        // ── Focus areas (struggling) ────────────────────────────
        if (profile.struggling.isNotEmpty) ...[
          _BucketCard(
            title: l.speechProfileFocusTitle,
            subtitle: l.speechProfileFocusSubtitle,
            hint: l.speechProfileBucketStrugglingHint,
            entries: profile.struggling,
            color: AppColors.danger,
            icon: Icons.priority_high_rounded,
            onPhonemeTap: (p) => _openDrill(context, p.phoneme),
          )
              .animate()
              .fadeIn(duration: 320.ms, delay: 160.ms)
              .slideY(begin: 0.04),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── Developing bucket ───────────────────────────────────
        if (profile.developing.isNotEmpty) ...[
          _BucketCard(
            title: l.speechProfileBucketDeveloping,
            subtitle: l.speechProfileBucketDevelopingHint,
            entries: profile.developing,
            color: AppColors.warning,
            icon: Icons.trending_up_rounded,
            onPhonemeTap: (p) => _openDrill(context, p.phoneme),
          )
              .animate()
              .fadeIn(duration: 320.ms, delay: 240.ms)
              .slideY(begin: 0.04),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── Mastered bucket ─────────────────────────────────────
        if (profile.mastered.isNotEmpty) ...[
          _BucketCard(
            title: l.speechProfileMasteredTitle,
            subtitle: l.speechProfileMasteredSubtitle,
            hint: l.speechProfileBucketMasteredHint,
            entries: profile.mastered,
            color: AppColors.success,
            icon: Icons.check_circle_rounded,
            onPhonemeTap: (p) => _openDrill(context, p.phoneme),
          )
              .animate()
              .fadeIn(duration: 320.ms, delay: 320.ms)
              .slideY(begin: 0.04),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── Footer: how many assessments contributed ────────────
        Text(
          l.speechProfileWindowFooter(
            profile.analysedCount,
            profile.assessmentCount,
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }
}

class _OverallAccuracyCard extends StatelessWidget {
  const _OverallAccuracyCard({required this.profile});
  final SpeechProfile profile;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final percent = profile.overallAccuracyPercent;
    final color = _gradeColor(profile.overallAccuracy);

    return PremiumCard(
      gradient: [color, color.withValues(alpha: 0.78)],
      shadowColor: color,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          // Accuracy ring with the parrot mascot.
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0, end: profile.overallAccuracy),
                  builder: (_, value, __) => SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 6,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                const ParrotMascot(mood: ParrotMood.happy, size: 64),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.speechProfileOverallTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.speechProfileOverallSubtitle(profile.analysedCount),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _gradeColor(double accuracy) {
    if (accuracy >= 0.70) return AppColors.success;
    if (accuracy >= 0.35) return AppColors.warning;
    return AppColors.danger;
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.color,
    required this.icon,
    this.hint,
    this.onPhonemeTap,
  });

  final String title;
  final String subtitle;
  final String? hint;
  final List<PhonemeMastery> entries;
  final Color color;
  final IconData icon;
  final ValueChanged<PhonemeMastery>? onPhonemeTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final p in entries)
                _PhonemeChip(
                  mastery: p,
                  color: color,
                  onTap: onPhonemeTap == null ? null : () => onPhonemeTap!(p),
                ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 18, color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      hint!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.speechProfilePhonemeSamples(_totalSamples()),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  int _totalSamples() {
    var t = 0;
    for (final e in entries) {
      t += e.sampleCount;
    }
    return t;
  }
}

class _PhonemeChip extends StatelessWidget {
  const _PhonemeChip({
    required this.mastery,
    required this.color,
    this.onTap,
  });
  final PhonemeMastery mastery;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mastery.phoneme,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            l.phonemeAccuracyPercent(mastery.accuracyPercent),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: color,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label: l.speechProfilePhonemeTile(
        mastery.phoneme,
        mastery.accuracyPercent,
      ),
      child: onTap == null
          ? chip
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: onTap,
                child: chip,
              ),
            ),
    );
  }
}

/// Inline CTA inserted into [ChildDetailScreen] so parents can open the
/// new screen with a single tap. Kept in this file so the screen and
/// its associated entry-point stay in lockstep.
class SpeechProfileEntryCard extends StatelessWidget {
  const SpeechProfileEntryCard({super.key, required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: () => context.go('/children/$childId/speech-profile'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.tertiary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: AppColors.tertiary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.speechProfileTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.speechProfileSubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
