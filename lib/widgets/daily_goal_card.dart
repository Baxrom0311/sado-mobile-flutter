import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../core/utils/haptics.dart';
import 'premium_card.dart';

/// Pure helper: returns `true` when the most recent active date matches
/// today's calendar day.
///
/// `lastActiveDate` is expected in `yyyy-MM-dd` format (the format
/// persisted by [GameState]). Anything else — `null`, malformed,
/// future-dated — counts as "not done yet".
///
/// `now` defaults to [DateTime.now] but can be overridden by tests so
/// "today" is deterministic.
bool isDailyGoalDone(String? lastActiveDate, {DateTime? now}) {
  if (lastActiveDate == null || lastActiveDate.isEmpty) return false;
  final reference = now ?? DateTime.now();
  final today = '${reference.year.toString().padLeft(4, '0')}-'
      '${reference.month.toString().padLeft(2, '0')}-'
      '${reference.day.toString().padLeft(2, '0')}';
  return lastActiveDate == today;
}

/// Premium "did you practice today?" card.
///
/// Drives the daily-engagement loop on the home screen:
///   * **Done** — green gradient, celebratory copy, "Bajarildi" badge.
///   * **Pending** — orange gradient, gentle pulse, friendly nudge with
///     a Start CTA that wires straight to the exercises list.
///
/// The card is keyboard-tappable in either state. Tapping the
/// done-card is a no-op so we don't yank the user out of context after
/// they've already finished — the parrot at the top of the home is the
/// next-action surface.
class DailyGoalCard extends StatelessWidget {
  const DailyGoalCard({
    super.key,
    required this.isDone,
    this.onStart,
  });

  /// Whether the user has practiced today already.
  final bool isDone;

  /// Tapped when the user wants to start today's practice. Wired only in
  /// the pending state — the done state is intentionally non-interactive
  /// so we don't pull the user away from the celebration moment.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Semantics(
      key: const ValueKey('home.dailyGoalCard'),
      label: l.dailyGoalSemantics(
        isDone ? l.dailyGoalDoneBadge : l.dailyGoalPendingTitle,
      ),
      button: !isDone,
      enabled: !isDone,
      child: isDone
          ? const _DoneCard()
          : _PendingCard(onStart: onStart),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return PremiumCard(
      key: const ValueKey('dailyGoal.done'),
      // Use the brand green at a slightly muted opacity so the card
      // looks like a celebration without competing with the hero card
      // immediately above it.
      gradient: const [AppColors.primary, AppColors.primaryDark],
      shadowColor: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
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
                  l.dailyGoalDoneTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.dailyGoalDoneSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              l.dailyGoalDoneBadge,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({this.onStart});
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return PremiumCard(
      key: const ValueKey('dailyGoal.pending'),
      gradient: const [AppColors.secondary, AppColors.secondaryDark],
      shadowColor: AppColors.secondary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onStart == null
          ? null
          : () {
              Haptics.light();
              onStart!();
            },
      child: Row(
        children: [
          // Subtle infinite pulse on the icon to draw the eye without
          // shaking the entire card. Using `flutter_animate`'s
          // `onComplete: restart` keeps the loop alive while the card is
          // mounted; the controller is disposed automatically by the
          // wrapping widget.
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: Colors.white,
              size: 24,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.08, 1.08),
                duration: 900.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.dailyGoalPendingTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.dailyGoalPendingSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (onStart != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.dailyGoalCta,
                    style: const TextStyle(
                      color: AppColors.secondaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.secondaryDark,
                    size: 16,
                  ),
                ],
              ),
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }
}
