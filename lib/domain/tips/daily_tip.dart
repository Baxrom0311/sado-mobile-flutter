import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';

/// Total number of curated home-practice tips available to the
/// "Tip of the Day" card. Mirrors the `helpTipNTitle / helpTipNBody`
/// ARB entries already used by the Help & Tips center, so we never
/// have to duplicate or re-translate anything.
///
/// If a future tip is added to the ARBs, bump this constant **and**
/// update [DailyTip._titleKey] / [DailyTip._bodyKey].
const int kDailyTipPoolSize = 5;

/// Pure, framework-free selector that maps a calendar date to a
/// stable tip index in `[0, total)`.
///
/// Picking by `dayOfYear % total` (rather than e.g. `now.day`) means:
///   • the tip rotates **daily** (not monthly) so the parent sees a
///     fresh idea every morning,
///   • the rotation is **deterministic** — opening the app three
///     times the same day always shows the same tip,
///   • the rotation **does not depend on local time-of-day**, so the
///     tip never flips mid-session.
///
/// Throws an [ArgumentError] when [total] is non-positive — there has
/// to be at least one tip to pick from.
@visibleForTesting
int pickDailyTipIndex(DateTime now, {int total = kDailyTipPoolSize}) {
  if (total <= 0) {
    throw ArgumentError.value(total, 'total', 'must be > 0');
  }
  // Build a UTC-anchored "day key" so the same wall-clock day rotates
  // the same tip across timezones, then derive a stable day-of-year.
  final utc = DateTime.utc(now.year, now.month, now.day);
  final startOfYear = DateTime.utc(utc.year, 1, 1);
  // Days are guaranteed non-negative because [utc] is in the same year.
  final dayOfYear = utc.difference(startOfYear).inDays;
  return dayOfYear % total;
}

/// Value object exposing the localised copy for today's tip.
///
/// Holds **no** Flutter widgets so it remains trivially testable.
@immutable
class DailyTip {
  const DailyTip._({
    required this.index,
    required this.title,
    required this.body,
  });

  /// 0-based index into the curated tip pool.
  final int index;

  /// Localised tip title (one short headline-style sentence).
  final String title;

  /// Localised tip body (one to two sentences of practical advice).
  final String body;

  /// Resolves today's tip from a [L] localisations bundle.
  ///
  /// [now] defaults to `DateTime.now()` and is overridable from tests
  /// so the rotation can be exercised across calendar dates without
  /// fakeAsync gymnastics.
  factory DailyTip.forDate(L l, {DateTime? now}) {
    final i = pickDailyTipIndex(now ?? DateTime.now());
    return DailyTip._(
      index: i,
      title: _titleKey(l, i),
      body: _bodyKey(l, i),
    );
  }

  static String _titleKey(L l, int i) {
    switch (i) {
      case 0:
        return l.helpTip1Title;
      case 1:
        return l.helpTip2Title;
      case 2:
        return l.helpTip3Title;
      case 3:
        return l.helpTip4Title;
      case 4:
        return l.helpTip5Title;
      default:
        // Defensive fallback — keeps the UI alive if [kDailyTipPoolSize]
        // is bumped without updating this switch.
        return l.helpTip1Title;
    }
  }

  static String _bodyKey(L l, int i) {
    switch (i) {
      case 0:
        return l.helpTip1Body;
      case 1:
        return l.helpTip2Body;
      case 2:
        return l.helpTip3Body;
      case 3:
        return l.helpTip4Body;
      case 4:
        return l.helpTip5Body;
      default:
        return l.helpTip1Body;
    }
  }
}
