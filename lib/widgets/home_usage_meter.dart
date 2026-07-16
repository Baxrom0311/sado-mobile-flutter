import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../data/models/subscription_plan.dart';
import '../providers/subscription_provider.dart';
import 'parrot_mascot.dart';

/// Compact "today's usage" meter rendered on the home screen for free
/// users.
///
/// Surfaces the most relevant capped metric (`assessments_per_day` or
/// `exercises_per_day`) plus an optional secondary metric
/// (`ai_analysis`) so the parent sees how close they are to their
/// daily / monthly cap *before* they hit a 402 wall. The card is
/// intentionally smaller than the full [SubscriptionUsageCard] used on
/// the status surface — home is dense, and we never want a 4-row panel
/// pushing the daily-goal card off the fold.
///
/// Render rules:
///
///  * Hidden silently while [mySubscriptionProvider] is loading or in
///    an error state. Same defensive posture as [HomePremiumCard] —
///    we never want a transient network blip to nag the user.
///  * Hidden for paid users (`!planId == 'free'`).
///  * Hidden when [subscriptionUsageProvider] resolves empty (the
///    /billing/usage endpoint isn't deployed on this environment yet,
///    so we have nothing meaningful to display).
///  * Hidden when none of the candidate metrics is *actually* capped
///    (`limit > 0`). This avoids painting an empty meter for a user
///    whose plan happens to surface only unlimited counters.
///
/// Tap behaviour:
///
///  * Exhausted (≥ 100% on any rendered metric) → routes to
///    `/subscription` so the user lands directly on the upgrade
///    surface.
///  * Otherwise → routes to `/subscription/status` so curious users
///    can see the full breakdown.
class HomeUsageMeter extends ConsumerWidget {
  const HomeUsageMeter({super.key});

  /// Order in which we look up a primary metric. The first match wins.
  /// `assessments_per_day` is the canonical token from the billing
  /// brief; `exercises_per_day` is its legacy alias and is included
  /// so older API revisions keep rendering the same meter.
  @visibleForTesting
  static const List<String> primaryMetricCandidates = <String>[
    'assessments_per_day',
    'exercises_per_day',
  ];

  /// Secondary metric is only rendered when present *and* capped.
  /// Today that's just AI analyses, which is a monthly metric so the
  /// progress bar reads slightly differently — the widget handles
  /// both.
  @visibleForTesting
  static const List<String> secondaryMetricCandidates = <String>[
    'ai_analysis',
    'ai_analyses_per_month',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final subAsync = ref.watch(mySubscriptionProvider);
    final usageAsync = ref.watch(subscriptionUsageProvider);

    // Be conservative: never render during loading / error.
    final isFree = subAsync.maybeWhen(
      data: (sub) => sub.planId == 'free',
      orElse: () => false,
    );
    if (!isFree) return const SizedBox.shrink();

    final usage = usageAsync.maybeWhen(
      data: (u) => u,
      orElse: () => SubscriptionUsage.empty,
    );
    if (usage.isEmpty) return const SizedBox.shrink();

    final primary = _firstCapped(usage, primaryMetricCandidates);
    if (primary == null) return const SizedBox.shrink();
    final secondary = _firstCapped(usage, secondaryMetricCandidates);

    final tone = _toneFor(primary, secondary);

    return _UsageMeterCard(
      key: const ValueKey('home.usageMeter'),
      l: l,
      primary: primary,
      secondary: secondary,
      tone: tone,
      onTap: () {
        // Exhausted users go straight to the upgrade screen so they
        // don't have to chase another tap to convert. Everyone else
        // lands on the status screen which has the full breakdown +
        // a "Manage" affordance.
        context.go(
          tone == _MeterTone.exhausted
              ? '/subscription'
              : '/subscription/status',
        );
      },
    );
  }

  /// Pick the first non-unlimited metric in [candidates] that is
  /// actually capped (`limit > 0`). Unlimited metrics (`limit < 0`)
  /// have nothing to meter; zero-limit metrics are degenerate and
  /// would render an empty bar.
  static UsageMetric? _firstCapped(
    SubscriptionUsage usage,
    List<String> candidates,
  ) {
    for (final token in candidates) {
      final m = usage.metric(token);
      if (m == null) continue;
      if (m.isUnlimited) continue;
      if (m.limit <= 0) continue;
      return m;
    }
    return null;
  }

  static _MeterTone _toneFor(
    UsageMetric primary,
    UsageMetric? secondary,
  ) {
    final maxProgress = secondary == null
        ? primary.progress
        : (primary.progress > secondary.progress
            ? primary.progress
            : secondary.progress);
    final anyExhausted =
        primary.isExhausted || (secondary?.isExhausted ?? false);
    if (anyExhausted) return _MeterTone.exhausted;
    if (maxProgress >= 0.7) return _MeterTone.nearLimit;
    return _MeterTone.calm;
  }
}

enum _MeterTone { calm, nearLimit, exhausted }

class _UsageMeterCard extends StatelessWidget {
  const _UsageMeterCard({
    super.key,
    required this.l,
    required this.primary,
    required this.secondary,
    required this.tone,
    required this.onTap,
  });

  final L l;
  final UsageMetric primary;
  final UsageMetric? secondary;
  final _MeterTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final exhausted = tone == _MeterTone.exhausted;
    final near = tone == _MeterTone.nearLimit;

    final accent = switch (tone) {
      _MeterTone.exhausted => AppColors.danger,
      _MeterTone.nearLimit => AppColors.warning,
      _MeterTone.calm => AppColors.primary,
    };

    final title = switch (tone) {
      _MeterTone.exhausted => l.homeUsageMeterExhaustedTitle,
      _MeterTone.nearLimit => l.homeUsageMeterNearLimitTitle,
      _MeterTone.calm => l.homeUsageMeterTitle,
    };

    final body = switch (tone) {
      _MeterTone.exhausted => l.homeUsageMeterExhaustedBody,
      _MeterTone.nearLimit => l.homeUsageMeterNearLimitBody,
      _MeterTone.calm => l.homeUsageMeterSubtitle,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('home.usageMeter.tap'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: exhausted
                  ? AppColors.danger.withValues(alpha: 0.35)
                  : (near
                      ? AppColors.warning.withValues(alpha: 0.35)
                      : AppColors.border),
              width: 1.2,
            ),
            boxShadow: AppShadow.soft(accent, opacity: 0.12),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (exhausted)
                    const ParrotMascot(
                      mood: ParrotMood.happy,
                      size: 48,
                    )
                  else
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        exhausted
                            ? Icons.lock_clock_rounded
                            : Icons.timelapse_rounded,
                        color: accent,
                        size: 20,
                      ),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _MetricRow(
                key: Key('home.usageMeter.metric.${primary.metric}'),
                metric: primary,
                accent: accent,
                l: l,
              ),
              if (secondary != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _MetricRow(
                  key: Key(
                      'home.usageMeter.metric.${secondary!.metric}'),
                  metric: secondary!,
                  accent: accent,
                  l: l,
                ),
              ],
              if (near || exhausted) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: const Key('home.usageMeter.cta'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                      boxShadow: AppShadow.soft(accent, opacity: 0.3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l.homeUsageMeterCta,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate(delay: 260.ms).fadeIn(duration: 320.ms).slideY(begin: 0.06);
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    super.key,
    required this.metric,
    required this.accent,
    required this.l,
  });

  final UsageMetric metric;
  final Color accent;
  final L l;

  @override
  Widget build(BuildContext context) {
    final label = _labelFor(l, metric.metric);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              l.subscriptionUsageUsedOf(metric.used, metric.limit),
              style: TextStyle(
                color: metric.isExhausted
                    ? AppColors.danger
                    : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: metric.progress),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ),
      ],
    );
  }

  String _labelFor(L l, String token) => switch (token) {
        'assessments_per_day' =>
          l.subscriptionUsageMetricAssessmentsPerDay,
        'exercises_per_day' =>
          l.subscriptionUsageMetricExercisesPerDay,
        'ai_analysis' || 'ai_analyses_per_month' =>
          l.subscriptionUsageMetricAi,
        'children_total' || 'max_children' =>
          l.subscriptionUsageMetricChildren,
        'recordings_per_day' || 'recordings' =>
          l.subscriptionUsageMetricRecordings,
        'patients_total' || 'max_patients' =>
          l.subscriptionUsageMetricPatients,
        _ => l.subscriptionUsageMetricUnknown,
      };
}
