import 'package:flutter/material.dart';

import '../core/gamification.dart';
import '../core/theme.dart';
import 'parrot_mascot.dart';
import 'premium_card.dart';

/// Card surfaced on the Achievements screen that shows the user how close
/// they are to the next badge they don't have yet. Includes the badge
/// emoji, a progress bar, and a localised "x/y" counter.
class NextBadgeCard extends StatelessWidget {
  const NextBadgeCard({
    super.key,
    required this.title,
    required this.goal,
    required this.badgeTitle,
    required this.progressText,
    required this.encourageText,
    this.allUnlockedText,
  });

  /// Heading shown above the badge — e.g. "Next badge".
  final String title;

  /// The goal to render. When `null`, the [allUnlockedText] copy is shown
  /// instead of a progress card.
  final NextBadgeGoal? goal;

  /// Human-readable name for the target badge (already localised).
  final String badgeTitle;

  /// Localised "current/target" line (e.g. "3/5 days in a row").
  final String progressText;

  /// Localised encouragement copy displayed beneath the progress bar.
  final String encourageText;

  /// Localised copy when every built-in badge is already unlocked.
  final String? allUnlockedText;

  @override
  Widget build(BuildContext context) {
    if (goal == null) {
      return PremiumCard(
        gradient: AppColors.heroGradient,
        shadowColor: AppColors.primary,
        child: Row(
          children: [
            const ParrotMascot(mood: ParrotMood.happy, size: 64),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                allUnlockedText ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final emoji = GameBadge.emojiOf(goal!.badgeId);
    final progress = goal!.progress;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BadgeMedal(emoji: emoji),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badgeTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: AppColors.surfaceMuted,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  progressText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            encourageText,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeMedal extends StatelessWidget {
  const _BadgeMedal({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.sunsetGradient),
        shape: BoxShape.circle,
        boxShadow: AppShadow.soft(AppColors.secondary),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 26),
        ),
      ),
    );
  }
}
