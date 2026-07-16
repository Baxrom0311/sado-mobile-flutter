import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/gamification.dart';

void main() {
  group('NextBadgeGoal.compute', () {
    test('returns null when every built-in badge is unlocked', () {
      final goal = NextBadgeGoal.compute(
        unlockedBadgeIds: GameBadge.all.map((b) => b.id).toList(),
        streakDays: 99,
        level: 99,
        assessmentsCount: 99,
      );
      expect(goal, isNull);
    });

    test(
      'fresh user with everything at zero picks the smallest target '
      '(first_step) so the first reward feels reachable',
      () {
        final goal = NextBadgeGoal.compute(
          unlockedBadgeIds: const [],
          streakDays: 0,
          level: 1,
          assessmentsCount: 0,
        );
        expect(goal, isNotNull);
        expect(goal!.badgeId, GameBadge.firstStep.id);
        expect(goal.target, 1);
        expect(goal.current, 0);
      },
    );

    test('a 4-day streak surfaces the 5-day streak badge as nearest', () {
      final goal = NextBadgeGoal.compute(
        unlockedBadgeIds: const ['first_step'],
        streakDays: 4,
        level: 1,
        assessmentsCount: 0,
      );
      expect(goal, isNotNull);
      expect(goal!.badgeId, GameBadge.fiveDayStreak.id);
      expect(goal.kind, NextBadgeGoalKind.streak);
      expect(goal.current, 4);
      expect(goal.target, 5);
      expect(goal.progress, closeTo(0.8, 1e-9));
    });

    test(
      '8 assessments at level 1 — the assessments badge is closer than '
      'level_5 so it wins the tie-break',
      () {
        final goal = NextBadgeGoal.compute(
          unlockedBadgeIds: const ['first_step', 'streak_5'],
          streakDays: 6,
          level: 1,
          assessmentsCount: 8,
        );
        expect(goal, isNotNull);
        expect(goal!.badgeId, GameBadge.tenAssessments.id);
        expect(goal.progress, closeTo(0.8, 1e-9));
      },
    );

    test('progress is clamped to 1.0 when current exceeds target', () {
      const g = NextBadgeGoal(
        badgeId: 'streak_5',
        kind: NextBadgeGoalKind.streak,
        current: 30,
        target: 5,
      );
      expect(g.progress, 1.0);
      expect(g.isComplete, isTrue);
    });

    test('progress handles zero target without dividing by zero', () {
      const g = NextBadgeGoal(
        badgeId: 'first_step',
        kind: NextBadgeGoalKind.streak,
        current: 0,
        target: 0,
      );
      expect(g.progress, 1.0);
      expect(g.isComplete, isTrue);
    });

    test(
      'when only level badges are unlocked, the screen surfaces the '
      'next level milestone with a level-typed goal',
      () {
        final goal = NextBadgeGoal.compute(
          unlockedBadgeIds: const [
            'first_step',
            'streak_5',
            'assess_10',
            'level_5',
          ],
          streakDays: 7,
          level: 7,
          assessmentsCount: 12,
        );
        expect(goal, isNotNull);
        expect(goal!.badgeId, GameBadge.level10.id);
        expect(goal.kind, NextBadgeGoalKind.level);
        expect(goal.current, 7);
        expect(goal.target, 10);
      },
    );
  });
}
