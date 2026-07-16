import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../data/models/models.dart';

/// Per-day activity intensity used by [PracticeCalendarGrid].
///
/// The widget itself is purely presentational — it receives the bucketed
/// per-day counts via [PracticeCalendarGrid.assessments] and figures out
/// which level each day belongs to. Exposed as part of the public surface
/// so screens that want to render the legend or compute their own
/// summary keep using the exact same thresholds.
enum PracticeIntensity {
  /// No assessments that day.
  none,

  /// Exactly one assessment that day.
  low,

  /// 2–3 assessments that day.
  medium,

  /// 4+ assessments — a great practice day.
  high;

  /// Map an integer count to one of the four buckets.
  static PracticeIntensity fromCount(int count) {
    if (count <= 0) return PracticeIntensity.none;
    if (count == 1) return PracticeIntensity.low;
    if (count <= 3) return PracticeIntensity.medium;
    return PracticeIntensity.high;
  }

  /// Background fill for the day cell.
  Color get fill {
    switch (this) {
      case PracticeIntensity.none:
        return AppColors.surfaceMuted;
      case PracticeIntensity.low:
        return AppColors.primaryLight;
      case PracticeIntensity.medium:
        return AppColors.primary.withValues(alpha: 0.55);
      case PracticeIntensity.high:
        return AppColors.primary;
    }
  }

  /// Foreground colour for the day number sitting on top of [fill].
  Color get foreground {
    switch (this) {
      case PracticeIntensity.none:
        return AppColors.textSecondary;
      case PracticeIntensity.low:
        return AppColors.primaryDark;
      case PracticeIntensity.medium:
      case PracticeIntensity.high:
        return Colors.white;
    }
  }
}

/// Pure presentational monthly heat-map.
///
/// Renders a 7-column grid (Mon → Sun) for the month containing [month].
/// Days outside the month are rendered as empty placeholders so the grid
/// keeps a stable 7×N shape. Today is decorated with a subtle ring.
///
/// The widget never fetches anything; the parent screen is responsible
/// for sourcing the [assessments] list and clamping it to whatever
/// window the API returned.
///
/// Pass [now] only from tests so "today" is deterministic.
class PracticeCalendarGrid extends StatelessWidget {
  const PracticeCalendarGrid({
    super.key,
    required this.month,
    required this.assessments,
    this.onDayTap,
    this.now,
  });

  /// Any date inside the month to render. The grid uses
  /// `DateTime(month.year, month.month, 1)` as the anchor.
  final DateTime month;

  /// Source assessments. Order doesn't matter; only `createdAt` is used
  /// and only days that fall inside [month] contribute a bucket.
  final List<Assessment> assessments;

  /// Tap callback. Receives the (truncated) day and the list of
  /// assessments captured that day. Days outside the rendered month or
  /// in the future are not tappable.
  final void Function(DateTime day, List<Assessment> dayAssessments)?
      onDayTap;

  /// Override the wall clock for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final today = _truncate(now ?? DateTime.now());
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    // Dart's DateTime.weekday: 1 = Mon … 7 = Sun.
    final leading = firstOfMonth.weekday - 1;

    // Bucket assessments by truncated day, but only for the rendered
    // month — the calendar never shows values that bleed in from a
    // neighbouring month.
    final buckets = <DateTime, List<Assessment>>{};
    for (final a in assessments) {
      final d = _truncate(a.createdAt);
      if (d.year != month.year || d.month != month.month) continue;
      buckets.putIfAbsent(d, () => <Assessment>[]).add(a);
    }

    final locale = Localizations.localeOf(context);
    // DateFormat.E gives the short weekday name in the active locale.
    // We resolve all 7 names once and reuse across the header row.
    final df = DateFormat.E(locale.toLanguageTag());
    // Mon = 2024-01-01 (a known Monday).
    final headers = List<String>.generate(7, (i) {
      final ref = DateTime(2024, 1, 1).add(Duration(days: i));
      return df.format(ref).toUpperCase();
    });

    return Semantics(
      label: l.practiceCalendarTitle,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final h in headers)
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Text(
                      h,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = AppSpacing.xs;
              final cellWidth =
                  (constraints.maxWidth - spacing * 6) / 7;
              final cellSize = cellWidth.clamp(28.0, 56.0);

              final cells = <Widget>[];
              // Leading blank cells so day-1 lands under the right header.
              for (var i = 0; i < leading; i++) {
                cells.add(SizedBox(width: cellSize, height: cellSize));
              }
              for (var d = 1; d <= daysInMonth; d++) {
                final date = DateTime(month.year, month.month, d);
                final dayAssessments =
                    buckets[date] ?? const <Assessment>[];
                final intensity =
                    PracticeIntensity.fromCount(dayAssessments.length);
                final isToday = date == today;
                final isFuture = date.isAfter(today);
                cells.add(_DayCell(
                  size: cellSize,
                  date: date,
                  intensity: intensity,
                  count: dayAssessments.length,
                  isToday: isToday,
                  isFuture: isFuture,
                  onTap: (isFuture || onDayTap == null)
                      ? null
                      : () => onDayTap!(date, dayAssessments),
                ));
              }
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: cells,
              );
            },
          ),
        ],
      ),
    );
  }

  static DateTime _truncate(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.size,
    required this.date,
    required this.intensity,
    required this.count,
    required this.isToday,
    required this.isFuture,
    this.onTap,
  });

  final double size;
  final DateTime date;
  final PracticeIntensity intensity;
  final int count;
  final bool isToday;
  final bool isFuture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final muted = isFuture;
    final fill = muted
        ? AppColors.surfaceMuted.withValues(alpha: 0.5)
        : intensity.fill;
    final fg = muted ? AppColors.textMuted : intensity.foreground;

    final cell = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: isToday
            ? Border.all(color: AppColors.secondary, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${date.day}',
        style: TextStyle(
          color: fg,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Semantics(
      key: Key('practiceCalendar.cell.${date.toIso8601String()}'),
      label: l.practiceCalendarDayLabel(
        DateFormat.yMMMMd(Localizations.localeOf(context).toLanguageTag())
            .format(date),
        count,
      ),
      button: onTap != null,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: cell,
      ),
    );
  }
}

/// Horizontal legend matching the four [PracticeIntensity] buckets.
///
/// Pulled out of the screen so it can be reused inside the bottom-sheet
/// help text and unit-tested in isolation.
class PracticeCalendarLegend extends StatelessWidget {
  const PracticeCalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Row(
      children: [
        Text(
          l.practiceCalendarLegendTitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        for (final i in PracticeIntensity.values)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: i.fill,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );
  }
}
