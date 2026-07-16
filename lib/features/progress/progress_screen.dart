import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/gamification.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/child_avatar.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/xp_bar.dart';

enum _Period { week, month, all }

final _progressPeriodProvider = StateProvider<_Period>((_) => _Period.week);

/// Currently selected child id on the Progress screen (null = all children).
///
/// Kept screen-local so the rest of the app (e.g. the home screen) doesn't
/// have to think about Progress's filter. The chip row also auto-resets the
/// filter to `null` if the selected child is removed mid-session.
final _progressChildFilterProvider = StateProvider<String?>((_) => null);

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final selectedChildId = ref.watch(_progressChildFilterProvider);
    final assessments = ref.watch(assessmentsProvider(selectedChildId));
    final period = ref.watch(_progressPeriodProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.progress)),
      body: assessments.when(
        data: (res) {
          final filtered = _filterByPeriod(res.items, period);
          if (res.items.isEmpty) return const _Empty();
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.invalidate(assessmentsProvider(selectedChildId)),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Child filter — only renders when there are 2+ children, so
                // single-child households don't see a useless single chip.
                _ChildFilterRow(selected: selectedChildId)
                    .animate()
                    .fadeIn(duration: 220.ms)
                    .slideY(begin: -0.05),
                _PeriodSelector(
                  selected: period,
                  onChanged: (p) =>
                      ref.read(_progressPeriodProvider.notifier).state = p,
                )
                    .animate(delay: 30.ms)
                    .fadeIn(duration: 240.ms)
                    .slideY(begin: -0.05),
                const SizedBox(height: AppSpacing.lg),
                _StatsRow(assessments: filtered)
                    .animate(delay: 60.ms)
                    .fadeIn()
                    .slideY(begin: 0.05),
                const SizedBox(height: AppSpacing.lg),
                _ChartCard(assessments: filtered, period: period)
                    .animate(delay: 120.ms)
                    .fadeIn()
                    .slideY(begin: 0.05),
                const SizedBox(height: AppSpacing.lg),
                _RiskCard(assessments: filtered)
                    .animate(delay: 180.ms)
                    .fadeIn()
                    .slideY(begin: 0.05),
                const SizedBox(height: AppSpacing.lg),
                _StreakCard(assessments: res.items)
                    .animate(delay: 240.ms)
                    .fadeIn()
                    .slideY(begin: 0.05),
                const SizedBox(height: AppSpacing.lg),
                const _LevelCard()
                    .animate(delay: 270.ms)
                    .fadeIn()
                    .slideY(begin: 0.05),
                const SizedBox(height: AppSpacing.lg),
                _CategoryCard(assessments: filtered)
                    .animate(delay: 300.ms)
                    .fadeIn()
                    .slideY(begin: 0.05),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l.recentAssessments,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (filtered.isEmpty)
                  PremiumCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        l.noAssessments,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  for (int i = 0; i < filtered.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _AssessmentRow(assessment: filtered[i])
                          .animate(delay: (i * 50).ms)
                          .fadeIn(),
                    ),
                const SizedBox(height: AppSpacing.huge),
              ],
            ),
          );
        },
        loading: () => const ShimmerList(),
        error: (e, _) => const _Empty(),
      ),
    );
  }

  List<Assessment> _filterByPeriod(
      List<Assessment> assessments, _Period period) {
    if (period == _Period.all) return assessments;
    final now = DateTime.now();
    final cutoff = period == _Period.week
        ? now.subtract(const Duration(days: 7))
        : now.subtract(const Duration(days: 30));
    return assessments.where((a) => a.createdAt.isAfter(cutoff)).toList();
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ParrotMascot(mood: ParrotMood.idle, size: 150),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.noAssessments,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              l.noAssessmentsBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal pill row that lets parents narrow Progress to a single child.
///
/// - Hides itself entirely if there are fewer than 2 children — a single
///   chip would be redundant and just take up vertical space.
/// - "All" chip sits first so the default filter (`null`) is always one tap
///   away from any child-specific selection.
/// - Per-child chips render the brand `ChildAvatar` so the filter is
///   instantly recognisable next to the rest of the app's child UI.
/// - Resets the filter to "all" if the currently selected child is removed
///   between rebuilds (e.g. parent deletes a child while on this screen).
class _ChildFilterRow extends ConsumerWidget {
  const _ChildFilterRow({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final children = ref.watch(childrenProvider).maybeWhen(
          data: (r) => r.items,
          orElse: () => const <Child>[],
        );

    if (children.length < 2) {
      return const SizedBox.shrink();
    }

    // If the previously-selected child has been removed (e.g. user deleted a
    // child mid-session), fall back to "all" instead of leaving the filter
    // pointing at a stale id.
    final stillExists =
        selected == null || children.any((c) => c.id == selected);
    if (!stillExists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(_progressChildFilterProvider.notifier).state = null;
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
            child: Text(
              l.filterByChild,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              // +1 for the leading "all" chip.
              itemCount: children.length + 1,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.xs),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _ChildFilterChip(
                    key: const ValueKey('progress.childFilter.all'),
                    label: l.allChildren,
                    isSelected: selected == null,
                    onTap: () => ref
                        .read(_progressChildFilterProvider.notifier)
                        .state = null,
                  );
                }
                final child = children[i - 1];
                return _ChildFilterChip(
                  key: ValueKey('progress.childFilter.${child.id}'),
                  label: child.name,
                  avatar: ChildAvatar(
                    name: child.name,
                    size: ChildAvatarSize.sm,
                  ),
                  isSelected: selected == child.id,
                  onTap: () => ref
                      .read(_progressChildFilterProvider.notifier)
                      .state = child.id,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildFilterChip extends StatelessWidget {
  const _ChildFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.avatar,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: avatar == null ? AppSpacing.md : AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: isSelected
              ? AppShadow.soft(AppColors.primary)
              : AppShadow.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null) ...[
              avatar!,
              const SizedBox(width: AppSpacing.xs),
            ],
            Padding(
              padding: EdgeInsets.only(
                right: avatar == null ? 0 : AppSpacing.xs,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});

  final _Period selected;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final entries = <(_Period, String)>[
      (_Period.week, l.periodWeek),
      (_Period.month, l.periodMonth),
      (_Period.all, l.periodAll),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          for (final e in entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(e.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: e.$1 == selected
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: e.$1 == selected
                        ? AppShadow.soft(AppColors.primary)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    e.$2,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: e.$1 == selected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.assessments});
  final List<Assessment> assessments;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final completed =
        assessments.where((a) => a.status == 'completed').length;
    final scored = assessments.where((a) => a.score != null).toList();
    final avg = scored.isEmpty
        ? 0.0
        : scored.fold<double>(0, (s, a) => s + (a.score ?? 0)) /
            scored.length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '${assessments.length}',
            label: l.total,
            color: AppColors.primary,
            icon: Icons.assignment_turned_in_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            value: '$completed',
            label: l.completed,
            color: AppColors.success,
            icon: Icons.check_circle_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            value: '${(avg * 100).round()}%',
            label: l.average,
            color: AppColors.secondary,
            icon: Icons.bolt_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String value;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      shadowColor: color,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              )),
          Text(label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.assessments, required this.period});
  final List<Assessment> assessments;
  final _Period period;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final now = DateTime.now();
    final spots = <FlSpot>[];
    final labels = <String>[];

    final weekLabels = [
      l.weekMon,
      l.weekTue,
      l.weekWed,
      l.weekThu,
      l.weekFri,
      l.weekSat,
      l.weekSun,
    ];

    final dayCount = period == _Period.month ? 30 : 7;
    double maxY = 1;

    for (int i = dayCount - 1; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final c = assessments.where((a) =>
          a.createdAt.year == day.year &&
          a.createdAt.month == day.month &&
          a.createdAt.day == day.day).length;
      spots.add(FlSpot((dayCount - 1 - i).toDouble(), c.toDouble()));
      // Label every day for week, every 5th day for month.
      if (period == _Period.week) {
        labels.add(weekLabels[(day.weekday - 1) % 7]);
      } else {
        labels.add(i % 5 == 0 ? '${day.day}' : '');
      }
      if (c > maxY) maxY = c.toDouble();
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.weeklyProgress,
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY + 1,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[i],
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.primary,
                    barWidth: 4,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (s, _, __, ___) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.primary,
                          strokeColor: Colors.white,
                          strokeWidth: 2,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.25),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.assessments});
  final List<Assessment> assessments;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    int low = 0, med = 0, high = 0;
    for (final a in assessments) {
      switch (a.overallRisk) {
        case 'green':
        case 'low':
          low++;
        case 'yellow':
        case 'medium':
          med++;
        case 'red':
        case 'high':
          high++;
      }
    }
    final classified = low + med + high;
    if (classified == 0) {
      return PremiumCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.pie_chart_rounded,
                  color: AppColors.textMuted),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.riskDistribution,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.noRiskData,
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
      );
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.riskDistribution,
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 38,
                    sections: [
                      if (low > 0)
                        PieChartSectionData(
                          value: low.toDouble(),
                          color: AppColors.success,
                          title: '$low',
                          radius: 28,
                          titleStyle: _slice(),
                        ),
                      if (med > 0)
                        PieChartSectionData(
                          value: med.toDouble(),
                          color: AppColors.warning,
                          title: '$med',
                          radius: 28,
                          titleStyle: _slice(),
                        ),
                      if (high > 0)
                        PieChartSectionData(
                          value: high.toDouble(),
                          color: AppColors.danger,
                          title: '$high',
                          radius: 28,
                          titleStyle: _slice(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  children: [
                    _LegendRow(
                      color: AppColors.success,
                      label: l.riskLow,
                      value: low,
                      total: classified,
                    ),
                    const SizedBox(height: 6),
                    _LegendRow(
                      color: AppColors.warning,
                      label: l.riskMedium,
                      value: med,
                      total: classified,
                    ),
                    const SizedBox(height: 6),
                    _LegendRow(
                      color: AppColors.danger,
                      label: l.riskHigh,
                      value: high,
                      total: classified,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _slice() => const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.total,
  });

  final Color color;
  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : (100 * value / total).round();
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          '$percent%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.assessments});
  final List<Assessment> assessments;

  static const _columns = 12;
  static const _rows = 7;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final now = DateTime.now();
    // Build a count map keyed by yyyy-MM-dd.
    final counts = <String, int>{};
    for (final a in assessments) {
      final d = a.createdAt;
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      counts[key] = (counts[key] ?? 0) + 1;
    }

    int maxCount = 0;
    counts.forEach((_, v) {
      if (v > maxCount) maxCount = v;
    });

    // Anchor grid so that the latest column ends today.
    // Last column corresponds to the week containing today.
    final totalCells = _columns * _rows;
    final lastColumnEnd = now;
    final cells = <DateTime>[];
    for (int i = totalCells - 1; i >= 0; i--) {
      cells.add(lastColumnEnd.subtract(Duration(days: i)));
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.streakHeatmap,
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 4.0;
              final cellSize =
                  (constraints.maxWidth - spacing * (_columns - 1)) /
                      _columns;
              return Column(
                children: List.generate(_rows, (row) {
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: row == _rows - 1 ? 0 : spacing),
                    child: Row(
                      children: List.generate(_columns, (col) {
                        final idx = col * _rows + row;
                        if (idx >= cells.length) {
                          return SizedBox(width: cellSize, height: cellSize);
                        }
                        final d = cells[idx];
                        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                        final c = counts[key] ?? 0;
                        final color = _heatColor(c, maxCount);
                        final marginRight = col == _columns - 1 ? 0.0 : spacing;
                        return Container(
                          margin: EdgeInsets.only(right: marginRight),
                          width: cellSize,
                          height: cellSize,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                '${l.total}: ${counts.values.fold<int>(0, (s, v) => s + v)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              for (int i = 0; i < 4; i++) ...[
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: _heatColorAtLevel(i),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _heatColorAtLevel(int level) {
    switch (level) {
      case 0:
        return AppColors.surfaceMuted;
      case 1:
        return AppColors.primary.withValues(alpha: 0.30);
      case 2:
        return AppColors.primary.withValues(alpha: 0.60);
      default:
        return AppColors.primary;
    }
  }

  Color _heatColor(int count, int maxCount) {
    if (count == 0) return _heatColorAtLevel(0);
    if (maxCount <= 1) return _heatColorAtLevel(3);
    final ratio = count / maxCount;
    if (ratio < 0.34) return _heatColorAtLevel(1);
    if (ratio < 0.67) return _heatColorAtLevel(2);
    return _heatColorAtLevel(3);
  }
}

class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({required this.assessments});
  final List<Assessment> assessments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final exercises = ref.watch(exercisesProvider).maybeWhen(
          data: (r) => r.items,
          orElse: () => const <Exercise>[],
        );
    final byId = {for (final e in exercises) e.id: e.category};

    final counts = <String, int>{};
    for (final a in assessments) {
      final cat = byId[a.exerciseId];
      if (cat == null) continue;
      counts[cat] = (counts[cat] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      return PremiumCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  color: AppColors.textMuted),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.categoryBreakdown,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.noAssessmentsBody,
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
      );
    }

    final total = counts.values.fold<int>(0, (s, v) => s + v);
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.categoryBreakdown,
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _CategoryBar(
                category: e.key,
                value: e.value,
                total: total,
                label: _localizedCategory(l, e.key),
              ),
            ),
        ],
      ),
    );
  }

  String _localizedCategory(L l, String c) => switch (c) {
        'articulation' => l.categoryArticulation,
        'breathing' => l.categoryBreathing,
        'vocabulary' => l.categoryVocabulary,
        'fluency' => l.categoryFluency,
        'listening' => l.categoryListening,
        'phonemic_awareness' => l.categoryPhonemicAwareness,
        _ => c,
      };
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.category,
    required this.value,
    required this.total,
    required this.label,
  });

  final String category;
  final int value;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColor(category);
    final ratio = total == 0 ? 0.0 : value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Stack(
            children: [
              Container(height: 8, color: AppColors.surfaceMuted),
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.02, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [color, color.withValues(alpha: 0.7)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssessmentRow extends StatelessWidget {
  const _AssessmentRow({required this.assessment});
  final Assessment assessment;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final color = AppColors.riskColor(assessment.overallRisk);
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.assessment_rounded, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assessment.status == 'completed'
                      ? l.completed
                      : assessment.status,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${assessment.createdAt.day.toString().padLeft(2, '0')}.'
                  '${assessment.createdAt.month.toString().padLeft(2, '0')}.'
                  '${assessment.createdAt.year}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (assessment.score != null)
            Text('${(assessment.score! * 100).round()}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                )),
        ],
      ),
    );
  }
}


/// Level + XP progress card.
///
/// Surfaces the same XP bar that lives in the home and profile screens, but
/// frames it with a "Level progress" headline and a one-tap shortcut to the
/// full badges grid. Splits the parent's gamification context across the
/// app's three primary surfaces (home glance, progress deep-dive, profile)
/// so the progress that the brief calls out — "Level progress section with
/// XP bar" — is anchored on the analytics screen instead of being only a
/// home-screen flourish.
class _LevelCard extends ConsumerWidget {
  const _LevelCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final game = ref.watch(gameProvider);
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.progressLevelTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${game.badges.length}',
                      style: const TextStyle(
                        color: AppColors.secondaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.workspace_premium_rounded,
                        size: 14, color: AppColors.secondaryDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.progressLevelSubtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          XpBar(state: game),
          const SizedBox(height: AppSpacing.md),
          PremiumButton(
            key: const ValueKey('progress.viewAllBadges'),
            label: l.viewAllBadges,
            icon: Icons.emoji_events_rounded,
            color: AppColors.surfaceMuted,
            foreground: AppColors.textPrimary,
            onPressed: () => context.go('/badges'),
          ),
        ],
      ),
    );
  }
}
