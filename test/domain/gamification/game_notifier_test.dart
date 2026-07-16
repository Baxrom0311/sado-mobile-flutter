import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sado_mobile/core/gamification.dart';

/// Behavioural tests for [GameNotifier]. The notifier persists to a Hive
/// box, so we initialise Hive against a fresh temporary directory for each
/// test. This keeps tests deterministic and isolated.
///
/// These tests focus on **behaviour transitions** (XP → level-up cascade,
/// badge unlocks, idempotent activity tracking) which were previously only
/// verified at the static-helper level.
void main() {
  late Directory tempDir;

  /// Builds a notifier and waits for its async `_load()` to settle before
  /// returning. Without this, a race could let the test's tearDown delete
  /// the Hive directory while the load is still doing file I/O.
  Future<GameNotifier> buildNotifier() async {
    final n = GameNotifier();
    await n.ready;
    return n;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sado_game_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('GameNotifier — XP and level-up', () {
    test('starts at level 1 with 0 XP and no badges', () async {
      final n = await buildNotifier();
      expect(n.state.xp, 0);
      expect(n.state.level, 1);
      expect(n.state.badges, isEmpty);
      expect(n.state.streakDays, 0);
    });

    test('addXp(0) and negative amounts are ignored', () async {
      final n = await buildNotifier();
      final unlocked1 = await n.addXp(0);
      final unlocked2 = await n.addXp(-50);
      expect(unlocked1, isEmpty);
      expect(unlocked2, isEmpty);
      expect(n.state.xp, 0);
      expect(n.state.level, 1);
    });

    test('adding 100 XP promotes to level 2 without unlocking level badges',
        () async {
      final n = await buildNotifier();
      final unlocked = await n.addXp(100);
      expect(n.state.xp, 100);
      expect(n.state.level, 2);
      expect(unlocked, isEmpty,
          reason: 'level 5/10 badges should not unlock at level 2');
    });

    test('reaching level 5 in a single grant unlocks the level-5 badge',
        () async {
      final n = await buildNotifier();
      final unlocked = await n.addXp(GameState.xpForLevel(5));
      expect(n.state.level, 5);
      expect(unlocked, contains(GameBadge.level5.id));
      expect(n.state.badges, contains(GameBadge.level5.id));
    });

    test('jumping straight to level 10 unlocks both level-5 and level-10',
        () async {
      final n = await buildNotifier();
      final unlocked = await n.addXp(GameState.xpForLevel(10));
      expect(n.state.level, 10);
      expect(unlocked, containsAll(<String>[
        GameBadge.level5.id,
        GameBadge.level10.id,
      ]));
    });

    test('a previously-earned level badge is not re-emitted', () async {
      final n = await buildNotifier();
      await n.addXp(GameState.xpForLevel(5));
      // Now bump XP further; level-5 was already unlocked, must not appear.
      final unlocked = await n.addXp(50);
      expect(unlocked, isNot(contains(GameBadge.level5.id)));
    });
  });

  group('GameNotifier — markActiveToday / streaks', () {
    test('first call from default state unlocks firstStep + sets streak=1',
        () async {
      final n = await buildNotifier();
      final unlocked = await n.markActiveToday();
      expect(unlocked, contains(GameBadge.firstStep.id));
      expect(n.state.streakDays, 1);
      expect(n.state.lastActiveDate, isNotNull);
    });

    test('repeated calls on the same day are idempotent (no double-unlock)',
        () async {
      final n = await buildNotifier();
      await n.markActiveToday();
      final second = await n.markActiveToday();
      expect(second, isEmpty);
      expect(n.state.streakDays, 1);
      // firstStep should still be present, just not re-emitted.
      expect(n.state.badges, contains(GameBadge.firstStep.id));
    });

    test('longestStreak grows alongside the current streak', () async {
      final n = await buildNotifier();
      // Day 1
      await n.markActiveToday();
      expect(n.state.streakDays, 1);
      expect(n.state.longestStreak, 1,
          reason: 'longest should at least match the current streak');
    });

    test(
      'longestStreak is preserved across a streak reset',
      () async {
        // Seed a state with a 7-day streak that ended yesterday-of-an-old-week.
        // The notifier doesn't expose a public "force date" hook, so we drive
        // the pure helper directly to assert the algebraic property: when
        // computeStreak resets to 1, the markActiveToday composition still
        // keeps the highest-ever value in longestStreak via the copyWith
        // branch. We verify by hand-rolling state through copyWith and the
        // public markActiveToday flow.
        final today = DateTime.now();
        final old = today.subtract(const Duration(days: 10));
        final yyyyMmDd =
            '${old.year.toString().padLeft(4, '0')}-${old.month.toString().padLeft(2, '0')}-${old.day.toString().padLeft(2, '0')}';
        // Drop directly into Hive; the notifier reloads state on next build.
        await Hive.openBox('sado_game').then((box) async {
          await box.put('state', {
            'xp': 0,
            'level': 1,
            'streakDays': 7,
            'longestStreak': 7,
            'lastActiveDate': yyyyMmDd,
            'badges': <String>[],
          });
          await box.close();
        });

        // Rebuild a fresh notifier to pick up the persisted state.
        final reloaded = await buildNotifier();
        expect(reloaded.state.longestStreak, 7);
        expect(reloaded.state.streakDays, 7);

        // Mark today active — gap > 1 day, so streak resets to 1, but
        // longestStreak must stay at 7.
        await reloaded.markActiveToday();
        expect(reloaded.state.streakDays, 1);
        expect(reloaded.state.longestStreak, 7,
            reason: 'longestStreak is a personal best, never decreases');
      },
    );
  });

  group('GameNotifier — recordAssessment', () {
    test('grants +20 XP and stamps the streak', () async {
      final n = await buildNotifier();
      await n.recordAssessment(totalAssessments: 1, score: 0.5);
      expect(n.state.xp, 20);
      expect(n.state.streakDays, 1);
    });

    test('hitting 10 assessments unlocks the assess_10 badge', () async {
      final n = await buildNotifier();
      final unlocked = await n.recordAssessment(
        totalAssessments: 10,
        score: 0.5,
      );
      expect(unlocked, contains(GameBadge.tenAssessments.id));
      expect(n.state.badges, contains(GameBadge.tenAssessments.id));
    });

    test('a near-perfect score unlocks the perfect badge exactly once',
        () async {
      final n = await buildNotifier();
      final firstRun = await n.recordAssessment(
        totalAssessments: 1,
        score: 0.97,
      );
      expect(firstRun, contains(GameBadge.perfectScore.id));

      final secondRun = await n.recordAssessment(
        totalAssessments: 2,
        score: 0.99,
      );
      expect(secondRun, isNot(contains(GameBadge.perfectScore.id)),
          reason: 'badge should not unlock twice');
    });

    test('null score does not unlock the perfect badge', () async {
      final n = await buildNotifier();
      final unlocked = await n.recordAssessment(totalAssessments: 1);
      expect(unlocked, isNot(contains(GameBadge.perfectScore.id)));
    });

    test('a sub-threshold score does not unlock the perfect badge', () async {
      final n = await buildNotifier();
      final unlocked = await n.recordAssessment(
        totalAssessments: 1,
        score: 0.94,
      );
      expect(unlocked, isNot(contains(GameBadge.perfectScore.id)));
    });
  });

  group('GameNotifier — reset', () {
    test('reset() returns the notifier to a fresh default state', () async {
      final n = await buildNotifier();
      await n.addXp(GameState.xpForLevel(5));
      await n.markActiveToday();
      expect(n.state.level, 5);
      expect(n.state.streakDays, 1);
      expect(n.state.badges, isNotEmpty);

      await n.reset();
      expect(n.state.xp, 0);
      expect(n.state.level, 1);
      expect(n.state.streakDays, 0);
      expect(n.state.badges, isEmpty);
      expect(n.state.lastActiveDate, isNull);
    });
  });

  group('GameBadge.emojiOf — defensive lookup', () {
    test('known ids return their emoji', () async {
      // No notifier needed for static lookups, but Hive is still set up by
      // the surrounding setUp/tearDown for symmetry.
      expect(GameBadge.emojiOf('first_step'), GameBadge.firstStep.emoji);
      expect(GameBadge.emojiOf('streak_5'), GameBadge.fiveDayStreak.emoji);
      expect(GameBadge.emojiOf('level_5'), GameBadge.level5.emoji);
    });

    test('unknown ids fall back to firstStep instead of throwing', () {
      expect(GameBadge.emojiOf('does-not-exist'),
          GameBadge.firstStep.emoji);
    });
  });
}
