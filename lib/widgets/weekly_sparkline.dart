import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../data/models/models.dart';
import 'risk_badge.dart';

/// Compact 7-day activity sparkline used on the child detail screen.
///
/// Buckets every assessment in [assessments] by day for the trailing
/// seven days. Each bar's height encodes the number of assessments
/// recorded that day; its colour encodes the *best* risk level achieved
/// (low > medium > high). The "today" column gets a subtle ring so the
/// child can see at a glance that today's effort is on the chart.
///
/// Pass [now] only from tests so the bucketing is deterministic.
class WeeklySparkline extends StatelessWidget {
  const WeeklySparkline({
    super.key,
    required this.assessments,
    this.now,
  });

  /// Assessment list — order doesn't matter, only `createdAt` is used.
  final List<Assessment> assessments;

  /// Override the wall clock for tests. Defaults to `DateTime.now()`.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final today = _truncate(now ?? DateTime.now());
    final days = List<DateTime>.generate(
      7,
      (i) => today.subtract(Duration(days: 6 - i)),
    );

    // Bucket per day in O(n).
    final buckets = <DateTime, _DayBucket>{
      for (final d in days) d: _DayBucket(date: d),
    };
    for (final a in assessments) {
      final d = _truncate(a.createdAt);
      final bucket = buckets[d];
      if (bucket == null) continue;
      bucket.count++;
      bucket.bestRisk = _better(bucket.bestRisk, a.overallRisk);
    }

    final maxCount = buckets.values
        .fold<int>(0, (m, b) => b.count > m ? b.count : m);
    final activeDays =
        buckets.values.where((b) => b.count > 0).length;
    final totalAssessments =
        buckets.values.fold<int>(0, (s, b) => s + b.count);

    final hasData = totalAssessments > 0;

    final locale = Localizations.localeOf(context);
    final dayFormat = DateFormat.E(locale.toLanguageTag());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.last7Days,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                hasData
                    ? l.last7DaysActiveDays(activeDays)
                    : l.last7DaysEmpty,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 92,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++) ...[
                Expanded(
                  child: _SparkBar(
                    bucket: buckets[days[i]]!,
                    maxCount: maxCount == 0 ? 1 : maxCount,
                    isToday: days[i] == today,
                    label: _shortDay(dayFormat, days[i]),
                    delay: (i * 60).ms,
                  ),
                ),
                if (i != days.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l.last7DaysAssessments(totalAssessments),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  static DateTime _truncate(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  /// Returns the lower-risk of two API tokens. `null` is treated as the
  /// worst possible value so any real reading replaces it.
  static String? _better(String? a, String? b) {
    int rank(String? r) => switch (r) {
          'low' || 'green' => 3,
          'medium' || 'yellow' => 2,
          'high' || 'red' => 1,
          _ => 0,
        };
    return rank(a) >= rank(b) ? a : b;
  }

  /// One-letter day prefix, capitalised. Falls back to "·" if the locale
  /// formatter returns an empty string (defensive — the intl package
  /// always returns at least 3 chars but iOS test stubs occasionally
  /// behave oddly).
  static String _shortDay(DateFormat fmt, DateTime d) {
    final s = fmt.format(d);
    if (s.isEmpty) return '·';
    return s.characters.first.toUpperCase();
  }
}

class _DayBucket {
  _DayBucket({required this.date});
  final DateTime date;
  int count = 0;
  String? bestRisk;
}

class _SparkBar extends StatelessWidget {
  const _SparkBar({
    required this.bucket,
    required this.maxCount,
    required this.isToday,
    required this.label,
    required this.delay,
  });

  final _DayBucket bucket;
  final int maxCount;
  final bool isToday;
  final String label;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final fraction = bucket.count == 0
        ? 0.0
        : (bucket.count / maxCount).clamp(0.0, 1.0);
    final risk = RiskLevel.fromApi(bucket.bestRisk);
    final filled = bucket.count > 0;
    final color = filled ? risk.color : AppColors.surfaceMuted;
    final labelColor = isToday
        ? AppColors.primary
        : AppColors.textSecondary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              // Always reserve a 4px floor so empty days are still
              // visible as a faint pill instead of disappearing.
              const minHeight = 6.0;
              final height = filled
                  ? (minHeight + (c.maxHeight - minHeight - 14) * fraction)
                  : minHeight;
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Track
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      height: c.maxHeight - 14,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                  // Fill
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: height),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (_, h, __) => Container(
                      width: double.infinity,
                      height: h,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            color,
                            color.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                        boxShadow: filled
                            ? AppShadow.soft(color, opacity: 0.22)
                            : null,
                      ),
                    ),
                  ),
                  // Day label
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: isToday
                          ? BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            )
                          : null,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ).animate(delay: delay).fadeIn(duration: 240.ms).slideY(begin: 0.15);
  }
}
