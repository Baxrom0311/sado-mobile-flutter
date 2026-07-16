import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/practice_calendar_grid.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/shimmer_loaders.dart';

/// Per-child practice calendar — monthly heat-map of assessment activity.
///
/// Tells the parent at a glance:
///   * which days the child practised this month,
///   * how strong the current and longest streaks are,
///   * how many sessions and the average score for the month,
///   * which exact assessments fell on any given day (via a bottom sheet).
///
/// Sourced from the same `assessmentsProvider(childId)` already used by
/// the child detail screen, so there is no extra API call and the offline
/// snapshot inherits automatically. The calendar is read-only in this
/// iteration — there is no day-level mutation surface yet.
class PracticeCalendarScreen extends ConsumerStatefulWidget {
  const PracticeCalendarScreen({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<PracticeCalendarScreen> createState() =>
      _PracticeCalendarScreenState();
}

class _PracticeCalendarScreenState
    extends ConsumerState<PracticeCalendarScreen> {
  /// Anchor for the currently displayed month. We always store the first
  /// of the month so equality checks across navigation are clean.
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  bool get _atCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final state = ref.watch(assessmentsProvider(widget.childId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.practiceCalendarTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/children/${widget.childId}'),
        ),
      ),
      body: state.when(
        loading: () => const _CalendarSkeleton(),
        error: (_, __) => ErrorState(
          title: l.practiceCalendarErrorTitle,
          body: l.practiceCalendarErrorBody,
          retryLabel: l.retry,
          onRetry: () =>
              ref.invalidate(assessmentsProvider(widget.childId)),
        ),
        data: (res) {
          final all = res.items;
          final monthAssessments = all
              .where((a) =>
                  a.createdAt.year == _month.year &&
                  a.createdAt.month == _month.month)
              .toList(growable: false);

          if (all.isEmpty) {
            return EmptyState(
              key: const Key('practiceCalendar.empty'),
              title: l.practiceCalendarEmptyTitle,
              body: l.practiceCalendarEmptyBody,
              ctaLabel: l.practiceCalendarEmptyCta,
              ctaIcon: Icons.play_arrow_rounded,
              onCta: () {
                ref.read(selectedChildIdProvider.notifier).state =
                    widget.childId;
                context.go('/exercises');
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(assessmentsProvider(widget.childId));
              await ref.read(assessmentsProvider(widget.childId).future);
            },
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (res.fromCache)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: OfflineBanner(message: l.offlineCached),
                  ),
                _StatsCard(
                  monthAssessments: monthAssessments,
                  allAssessments: all,
                ).animate().fadeIn(duration: 240.ms).slideY(begin: -0.04),
                const SizedBox(height: AppSpacing.lg),
                _MonthNav(
                  month: _month,
                  canGoNext: !_atCurrentMonth,
                  onPrev: () => _shiftMonth(-1),
                  onNext: () => _shiftMonth(1),
                ),
                const SizedBox(height: AppSpacing.md),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PracticeCalendarGrid(
                        key: ValueKey(
                            'practiceCalendar.grid.${_month.year}-${_month.month}'),
                        month: _month,
                        assessments: monthAssessments,
                        onDayTap: (day, dayAssessments) =>
                            _openDaySheet(context, day, dayAssessments),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const PracticeCalendarLegend(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openDaySheet(
    BuildContext context,
    DateTime day,
    List<Assessment> dayAssessments,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (sheetCtx) => _DaySheet(
        day: day,
        dayAssessments: dayAssessments,
        onAssessmentTap: (id) {
          Navigator.of(sheetCtx).pop();
          context.go('/assessment/results/$id');
        },
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.monthAssessments,
    required this.allAssessments,
  });

  final List<Assessment> monthAssessments;
  final List<Assessment> allAssessments;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;

    final totalSessions = monthAssessments.length;
    // Unique practice days inside the rendered month.
    final uniqueDays = <DateTime>{};
    var scoreSum = 0.0;
    var scoreCount = 0;
    for (final a in monthAssessments) {
      uniqueDays.add(DateTime(
          a.createdAt.year, a.createdAt.month, a.createdAt.day));
      final s = a.score;
      if (s != null) {
        scoreSum += s;
        scoreCount++;
      }
    }
    final activeDays = uniqueDays.length;
    final avgScoreText = scoreCount == 0
        ? '—'
        : '${(scoreSum / scoreCount * 100).round()}%';

    final streak = _computeCurrentStreak(allAssessments);

    return PremiumCard(
      gradient: const [Color(0xFFE9F9EE), Color(0xFFFAFBFD)],
      shadowColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ParrotMascot(mood: ParrotMood.happy, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.practiceCalendarStatsTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.practiceCalendarStatsSubtitle(streak),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.calendar_month_rounded,
                  label: l.practiceCalendarStatActiveDays,
                  value: '$activeDays',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatTile(
                  icon: Icons.bolt_rounded,
                  label: l.practiceCalendarStatSessions,
                  value: '$totalSessions',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatTile(
                  icon: Icons.star_rounded,
                  label: l.practiceCalendarStatAvgScore,
                  value: avgScoreText,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Number of consecutive days, counting back from today (or yesterday
  /// if today has no activity yet — the latter keeps a 5-day streak that
  /// hasn't been "renewed yet today" from instantly dropping to 0).
  int _computeCurrentStreak(List<Assessment> all) {
    if (all.isEmpty) return 0;
    final daysWithActivity = <DateTime>{
      for (final a in all)
        DateTime(a.createdAt.year, a.createdAt.month, a.createdAt.day),
    };
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!daysWithActivity.contains(cursor)) {
      // Allow the streak to "carry" through today even if the child
      // hasn't recorded yet — but only if yesterday was active.
      cursor = cursor.subtract(const Duration(days: 1));
      if (!daysWithActivity.contains(cursor)) return 0;
    }
    var streak = 0;
    while (daysWithActivity.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.month,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthLabel = DateFormat.yMMMM(locale).format(month);

    return Row(
      children: [
        IconButton(
          key: const Key('practiceCalendar.prev'),
          tooltip: l.practiceCalendarPrevMonth,
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: onPrev,
        ),
        Expanded(
          child: Text(
            monthLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          key: const Key('practiceCalendar.next'),
          tooltip: l.practiceCalendarNextMonth,
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: canGoNext ? onNext : null,
        ),
      ],
    );
  }
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({
    required this.day,
    required this.dayAssessments,
    required this.onAssessmentTap,
  });

  final DateTime day;
  final List<Assessment> dayAssessments;
  final void Function(String assessmentId) onAssessmentTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final headerLabel = DateFormat.yMMMMd(locale).format(day);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              headerLabel,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.practiceCalendarDaySessionsCount(dayAssessments.length),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (dayAssessments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Row(
                  children: [
                    const ParrotMascot(mood: ParrotMood.idle, size: 56),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        l.practiceCalendarDayEmpty,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final a in dayAssessments)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: PremiumCard(
                    onTap: () => onAssessmentTap(a.id),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: RiskLevel.fromApi(a.overallRisk)
                                .color
                                .withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.assessment_rounded,
                            color:
                                RiskLevel.fromApi(a.overallRisk).color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                a.score == null
                                    ? '—'
                                    : '${(a.score! * 100).round()}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              RiskBadge.fromApi(
                                risk: a.overallRisk,
                                size: RiskBadgeSize.small,
                              ),
                              const Spacer(),
                              Text(
                                DateFormat.Hm(locale).format(a.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        ShimmerBox(height: 120, radius: AppRadius.lg),
        SizedBox(height: AppSpacing.lg),
        ShimmerBox(height: 48, radius: AppRadius.md),
        SizedBox(height: AppSpacing.md),
        ShimmerBox(height: 280, radius: AppRadius.lg),
      ],
    );
  }
}

/// Compact entry card placed on the child detail screen that links into
/// [PracticeCalendarScreen]. Owns its own copy so the detail screen
/// stays simple and the card can be reused on a future "weekly summary"
/// surface without duplicating text.
class PracticeCalendarEntryCard extends StatelessWidget {
  const PracticeCalendarEntryCard({super.key, required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return PremiumCard(
      key: const Key('practiceCalendar.entryCard'),
      onTap: () => context.go('/children/$childId/calendar'),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.practiceCalendarEntryTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.practiceCalendarEntrySubtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted),
        ],
      ),
    );
  }
}
