import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/gamification.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/next_badge_card.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/xp_bar.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final game = ref.watch(gameProvider);
    final assessmentsAsync = ref.watch(assessmentsProvider(null));

    final assessmentsCount = assessmentsAsync.maybeWhen(
      data: (r) => r.items.length,
      orElse: () => 0,
    );

    final goal = NextBadgeGoal.compute(
      unlockedBadgeIds: game.badges,
      streakDays: game.streakDays,
      level: game.level,
      assessmentsCount: assessmentsCount,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.achievements),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/profile'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          PremiumCard(
            child: XpBar(state: game),
          ),
          const SizedBox(height: AppSpacing.lg),
          NextBadgeCard(
            title: l.nextBadgeTitle,
            goal: goal,
            badgeTitle:
                goal != null ? _badgeTitle(l, goal.badgeId) : '',
            progressText:
                goal != null ? _progressText(l, goal) : '',
            encourageText: l.nextBadgeKeepGoing,
            allUnlockedText: l.nextBadgeAllUnlocked,
          ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.05),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l.badges,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.lg,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.85,
            children: List.generate(GameBadge.all.length, (i) {
              final b = GameBadge.all[i];
              final unlocked = game.badges.contains(b.id);
              final title = _badgeTitle(l, b.id);
              return BadgeTile(
                badge: b,
                unlocked: unlocked,
                label: title,
                onTap: () => showBadgeDetailSheet(
                  context,
                  badgeId: b.id,
                  unlocked: unlocked,
                  title: title,
                  body: _badgeBody(l, b.id),
                  hint: _badgeHint(l, b.id),
                ),
              )
                  .animate(delay: (i * 60).ms)
                  .fadeIn()
                  .scale(
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1, 1));
            }),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Column(
              children: [
                const ParrotMascot(mood: ParrotMood.happy, size: 110),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l.mascotEncourage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  String _progressText(L l, NextBadgeGoal goal) => switch (goal.kind) {
        NextBadgeGoalKind.streak =>
          l.nextBadgeStreakProgress(goal.current, goal.target),
        NextBadgeGoalKind.assessments =>
          l.nextBadgeAssessProgress(goal.current, goal.target),
        NextBadgeGoalKind.level =>
          l.nextBadgeLevelProgress(goal.current, goal.target),
      };

  String _badgeTitle(L l, String id) => switch (id) {
        'first_step' => l.badgeFirstStepTitle,
        'streak_5' => l.badgeStreak5Title,
        'assess_10' => l.badgeAssess10Title,
        'level_5' => l.badgeLevel5Title,
        'level_10' => l.badgeLevel10Title,
        'perfect' => l.badgePerfectTitle,
        _ => l.badges,
      };

  String _badgeBody(L l, String id) => switch (id) {
        'first_step' => l.badgeFirstStepBody,
        'streak_5' => l.badgeStreak5Body,
        'assess_10' => l.badgeAssess10Body,
        'level_5' => l.badgeLevel5Body,
        'level_10' => l.badgeLevel10Body,
        'perfect' => l.badgePerfectBody,
        _ => '',
      };

  String _badgeHint(L l, String id) => switch (id) {
        'first_step' => l.badgeFirstStepHint,
        'streak_5' => l.badgeStreak5Hint,
        'assess_10' => l.badgeAssess10Hint,
        'level_5' => l.badgeLevel5Hint,
        'level_10' => l.badgeLevel10Hint,
        'perfect' => l.badgePerfectHint,
        _ => '',
      };
}
