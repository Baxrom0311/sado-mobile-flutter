import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/gamification.dart';

/// Pure unit tests for [GameState.computeStreak]. The function is a small
/// state machine that decides what a user's streak should become given:
/// - the streak they had,
/// - the date they were last active (yyyy-MM-dd or null),
/// - the date that should now be considered "today".
void main() {
  group('computeStreak — first ever activity', () {
    test('null lastActiveDate starts a streak of 1', () {
      final next = GameState.computeStreak(
        currentStreak: 0,
        lastActiveDate: null,
        today: '2026-06-10',
      );
      expect(next, 1);
    });

    test('first activity ignores any pre-existing streak number', () {
      // If someone migrated from an older schema, lastActiveDate==null is the
      // source of truth and the streak resets to 1, not "currentStreak".
      final next = GameState.computeStreak(
        currentStreak: 99,
        lastActiveDate: null,
        today: '2026-06-10',
      );
      expect(next, 1);
    });
  });

  group('computeStreak — same day double-tap', () {
    test('does not increment when last == today', () {
      final next = GameState.computeStreak(
        currentStreak: 4,
        lastActiveDate: '2026-06-10',
        today: '2026-06-10',
      );
      expect(next, 4);
    });

    test('handles multiple same-day calls in a row idempotently', () {
      var streak = 4;
      for (var i = 0; i < 5; i++) {
        streak = GameState.computeStreak(
          currentStreak: streak,
          lastActiveDate: '2026-06-10',
          today: '2026-06-10',
        );
      }
      expect(streak, 4);
    });
  });

  group('computeStreak — consecutive days', () {
    test('one day later increments by exactly 1', () {
      final next = GameState.computeStreak(
        currentStreak: 4,
        lastActiveDate: '2026-06-09',
        today: '2026-06-10',
      );
      expect(next, 5);
    });

    test('day-by-day across a week grows linearly', () {
      var streak = 0;
      String? last;
      for (final day in [
        '2026-06-01',
        '2026-06-02',
        '2026-06-03',
        '2026-06-04',
        '2026-06-05',
        '2026-06-06',
        '2026-06-07',
      ]) {
        streak = GameState.computeStreak(
          currentStreak: streak,
          lastActiveDate: last,
          today: day,
        );
        last = day;
      }
      expect(streak, 7);
    });

    test('crosses a month boundary correctly', () {
      final next = GameState.computeStreak(
        currentStreak: 6,
        lastActiveDate: '2026-05-31',
        today: '2026-06-01',
      );
      expect(next, 7);
    });

    test('crosses a year boundary correctly', () {
      final next = GameState.computeStreak(
        currentStreak: 9,
        lastActiveDate: '2026-12-31',
        today: '2027-01-01',
      );
      expect(next, 10);
    });
  });

  group('computeStreak — gaps reset', () {
    test('two-day gap resets to 1', () {
      final next = GameState.computeStreak(
        currentStreak: 12,
        lastActiveDate: '2026-06-08',
        today: '2026-06-10',
      );
      expect(next, 1);
    });

    test('week-long gap resets to 1', () {
      final next = GameState.computeStreak(
        currentStreak: 30,
        lastActiveDate: '2026-06-01',
        today: '2026-06-10',
      );
      expect(next, 1);
    });
  });

  group('computeStreak — clock skew / past dates', () {
    test('today earlier than last keeps streak unchanged', () {
      // E.g. user travelled across a time zone or device clock drifted
      // backwards. We refuse to grow or shrink the streak in this case.
      final next = GameState.computeStreak(
        currentStreak: 5,
        lastActiveDate: '2026-06-10',
        today: '2026-06-09',
      );
      expect(next, 5);
    });
  });
}
