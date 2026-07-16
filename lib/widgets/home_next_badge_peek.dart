import 'package:flutter/material.dart';

import '../core/gamification.dart';
import '../core/theme.dart';
import 'premium_card.dart';

/// Compact "next badge" peek tuned for the home screen rhythm.
///
/// The full [NextBadgeCard] used on the achievements screen is taller and
/// emphasises the badge artwork — that's perfect for a dedicated screen
/// but on the home feed we want a single-row card that fits between the
/// XP bar and the daily-goal nudge without dominating the layout.
///
/// Layout (left → right):
///   [emoji medal] [title • progress text]                          [chevron]
///   [— — — — — — — — — — animated progress bar — — — — — — — — — — — — —]
///
/// Returns `null`-equivalent (a [SizedBox.shrink]) when [goal] is null —
/// callers can hand back `NextBadgeGoal.compute(...)` directly without
/// guarding the call site.
class HomeNextBadgePeek extends StatelessWidget {
  const HomeNextBadgePeek({
    super.key,
    required this.goal,
    required this.label,
    required this.badgeTitle,
    required this.progressText,
    this.onTap,
  });

  /// The goal to render. When `null`, this widget renders nothing — the
  /// home screen already celebrates "all unlocked" via the achievements
  /// screen, so we don't want a competing all-unlocked tile here.
  final NextBadgeGoal? goal;

  /// Localised heading, e.g. "Keyingi nishongacha".
  final String label;

  /// Localised badge title, e.g. "Birinchi qadam".
  final String badgeTitle;

  /// Localised "x/y …" progress copy.
  final String progressText;

  /// Tap target — typically navigates to /badges.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final goal = this.goal;
    if (goal == null) return const SizedBox.shrink();

    final emoji = GameBadge.emojiOf(goal.badgeId);
    final progress = goal.progress;
    final percent = (progress * 100).round();

    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _EmojiMedal(emoji: emoji),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badgeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 22,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: AppColors.surfaceMuted,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  progressText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmojiMedal extends StatelessWidget {
  const _EmojiMedal({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.sunsetGradient),
        shape: BoxShape.circle,
        boxShadow: AppShadow.soft(AppColors.secondary, opacity: 0.22),
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
