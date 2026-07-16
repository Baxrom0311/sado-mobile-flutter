import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/domain/tips/daily_tip.dart';

void main() {
  group('pickDailyTipIndex', () {
    test('returns 0 for January 1st (day-of-year 0)', () {
      expect(pickDailyTipIndex(DateTime(2026, 1, 1)), 0);
      expect(pickDailyTipIndex(DateTime(2026, 1, 1)), 0);
    });

    test('rotates by exactly one each consecutive day', () {
      var prev = pickDailyTipIndex(DateTime(2026, 1, 1));
      for (var d = 2; d <= 14; d++) {
        final next = pickDailyTipIndex(DateTime(2026, 1, d));
        // Rotation modulo pool size — strictly +1 mod total.
        final expected = (prev + 1) % kDailyTipPoolSize;
        expect(next, expected,
            reason: 'day $d should rotate from $prev to $expected');
        prev = next;
      }
    });

    test('always returns an index inside [0, total)', () {
      for (var d = 0; d < 366; d++) {
        final i = pickDailyTipIndex(DateTime(2026, 1, 1).add(Duration(days: d)));
        expect(i, greaterThanOrEqualTo(0));
        expect(i, lessThan(kDailyTipPoolSize));
      }
    });

    test('is deterministic across multiple calls in the same day', () {
      final date = DateTime(2026, 6, 13, 9, 56);
      final morning = pickDailyTipIndex(date);
      final afternoon =
          pickDailyTipIndex(date.add(const Duration(hours: 6)));
      expect(morning, afternoon,
          reason: 'multiple calls within the same day must agree');
    });

    test('time-of-day does not flip the index', () {
      final earlyMorning = DateTime(2026, 6, 13, 0, 5);
      final lateNight = DateTime(2026, 6, 13, 23, 55);
      expect(pickDailyTipIndex(earlyMorning),
          pickDailyTipIndex(lateNight));
    });

    test('explicit total respected', () {
      // With a pool of 1 the index must always be 0.
      for (var d = 0; d < 30; d++) {
        final i = pickDailyTipIndex(
          DateTime(2026, 1, 1).add(Duration(days: d)),
          total: 1,
        );
        expect(i, 0);
      }
    });

    test('total <= 0 is rejected', () {
      expect(
        () => pickDailyTipIndex(DateTime(2026, 1, 1), total: 0),
        throwsArgumentError,
      );
      expect(
        () => pickDailyTipIndex(DateTime(2026, 1, 1), total: -3),
        throwsArgumentError,
      );
    });

    test('rotates a full lap over 5 consecutive days', () {
      // Default pool is 5 — so day 0..4 should produce all 5 indices
      // exactly once.
      final seen = <int>{};
      for (var d = 0; d < kDailyTipPoolSize; d++) {
        seen.add(
          pickDailyTipIndex(
            DateTime(2026, 1, 1).add(Duration(days: d)),
          ),
        );
      }
      expect(seen.length, kDailyTipPoolSize);
      for (var i = 0; i < kDailyTipPoolSize; i++) {
        expect(seen, contains(i));
      }
    });

    test('crossing a year boundary stays in range', () {
      // 2026 has 365 days; 2027 day 1 wraps day-of-year back to 0.
      final dec31 = DateTime(2026, 12, 31);
      final jan1 = DateTime(2027, 1, 1);
      final i31 = pickDailyTipIndex(dec31);
      final i1 = pickDailyTipIndex(jan1);
      expect(i31, greaterThanOrEqualTo(0));
      expect(i31, lessThan(kDailyTipPoolSize));
      expect(i1, 0,
          reason:
              'January 1st of any year is day-of-year 0 → first tip in pool');
    });
  });

  group('kDailyTipPoolSize', () {
    test('is at least 1 — there must be a tip to show', () {
      expect(kDailyTipPoolSize, greaterThanOrEqualTo(1));
    });

    test('matches the number of helpTipNTitle ARB entries (5)', () {
      // If a future contributor adds a 6th helpTip ARB entry they must
      // bump this constant *and* extend [DailyTip._titleKey/_bodyKey].
      // This guards against silent drift.
      expect(kDailyTipPoolSize, 5);
    });
  });
}
