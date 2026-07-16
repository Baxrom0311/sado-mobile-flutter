import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../../core/theme.dart';
import '../../../data/models/subscription_plan.dart';
import '../../../widgets/parrot_mascot.dart';
import '../../../widgets/premium_card.dart';
import '../../../widgets/speech_bubble.dart';

/// Premium usage panel rendered on the subscription status surface.
///
/// The card lists every metric the API tracks for the current period
/// and visualises consumption against the plan limit. Unlimited
/// metrics get a friendly "∞" badge instead of a degenerate progress
/// bar, exhausted metrics flip to a danger-tinted bar plus an upgrade
/// hint, and the period boundary is surfaced as a subtle reset chip.
class SubscriptionUsageCard extends StatelessWidget {
  const SubscriptionUsageCard({
    super.key,
    required this.usage,
    required this.locale,
    this.onUpgrade,
    this.heroVariant = false,
  });

  /// Aggregated metrics resolved from `BillingApi.usage()`.
  final SubscriptionUsage usage;

  /// Active locale code (`uz` / `ru`). Drives date / number formatting.
  final String locale;

  /// Tapped when any exhausted-metric upgrade hint is pressed.
  /// `null` hides the CTA so this widget can be reused on screens
  /// where the upgrade entry point lives elsewhere.
  final VoidCallback? onUpgrade;

  /// `true` to render the gradient hero variant used on free users
  /// (mascot + speech bubble + bullet list). `false` (default) renders
  /// the standalone metric panel suitable for paid users.
  final bool heroVariant;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;

    if (usage.isEmpty) {
      return _EmptyUsagePanel(l: l, heroVariant: heroVariant);
    }

    if (heroVariant) {
      return _HeroUsagePanel(
        usage: usage,
        locale: locale,
        l: l,
        onUpgrade: onUpgrade,
      );
    }
    return _StandardUsagePanel(
      usage: usage,
      locale: locale,
      l: l,
      onUpgrade: onUpgrade,
    );
  }
}

// =====================================================================
// Layouts
// =====================================================================

class _StandardUsagePanel extends StatelessWidget {
  const _StandardUsagePanel({
    required this.usage,
    required this.locale,
    required this.l,
    required this.onUpgrade,
  });

  final SubscriptionUsage usage;
  final String locale;
  final L l;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final periodLine = _periodLine(l, usage, locale);
    final exhausted = usage.metrics.any((m) => m.isExhausted);
    return PremiumCard(
      key: const Key('subscription.usageCard'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l.subscriptionUsageTitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (periodLine != null) ...[
            const SizedBox(height: 4),
            Text(
              periodLine,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final m in usage.metrics)
            Padding(
              key: Key('subscription.usageCard.metric.${m.metric}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _UsageRow(metric: m, l: l, locale: locale),
            ),
          if (exhausted && onUpgrade != null) ...[
            const SizedBox(height: 4),
            _ExhaustedHint(l: l, onUpgrade: onUpgrade!),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.04);
  }
}

class _HeroUsagePanel extends StatelessWidget {
  const _HeroUsagePanel({
    required this.usage,
    required this.locale,
    required this.l,
    required this.onUpgrade,
  });

  final SubscriptionUsage usage;
  final String locale;
  final L l;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final exhausted = usage.metrics.any((m) => m.isExhausted);
    final periodLine = _periodLine(l, usage, locale);
    return Container(
      key: const Key('subscription.usageCard.hero'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ParrotMascot(mood: ParrotMood.happy, size: 64),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.subscriptionUsageTitle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.subscriptionUsageSubtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SpeechBubble(
                      text: l.subscriptionUsageMascotMessage,
                      maxWidth: 260,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (periodLine != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              periodLine,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final m in usage.metrics)
            Padding(
              key: Key('subscription.usageCard.hero.metric.${m.metric}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _UsageRow(metric: m, l: l, locale: locale),
            ),
          if (exhausted && onUpgrade != null) ...[
            const SizedBox(height: 4),
            _ExhaustedHint(l: l, onUpgrade: onUpgrade!),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.04);
  }
}

class _EmptyUsagePanel extends StatelessWidget {
  const _EmptyUsagePanel({required this.l, required this.heroVariant});
  final L l;
  final bool heroVariant;

  @override
  Widget build(BuildContext context) {
    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l.subscriptionUsageEmptyTitle,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l.subscriptionUsageEmptyBody,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
    if (heroVariant) {
      return Container(
        key: const Key('subscription.usageCard.empty'),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: inner,
      );
    }
    return PremiumCard(
      key: const Key('subscription.usageCard.empty'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: inner,
    );
  }
}

// =====================================================================
// Pieces
// =====================================================================

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.metric,
    required this.l,
    required this.locale,
  });

  final UsageMetric metric;
  final L l;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(metric);
    final label = _labelFor(l, metric.metric);
    final trailing = metric.isUnlimited
        ? l.subscriptionUsageUnlimited
        : l.subscriptionUsageUsedOf(metric.used, metric.limit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: metric.isUnlimited
                    ? AppColors.primaryLight
                    : (metric.isExhausted
                        ? AppColors.secondaryLight
                        : AppColors.surfaceMuted),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                trailing,
                style: TextStyle(
                  color: metric.isUnlimited
                      ? AppColors.primary
                      : (metric.isExhausted
                          ? AppColors.danger
                          : AppColors.textPrimary),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (metric.isUnlimited)
          _UnlimitedBar(color: color)
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: metric.progress),
              duration: const Duration(milliseconds: 480),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.surfaceMuted,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        if (!metric.isUnlimited) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.subscriptionUsageRemaining(
                      metric.remaining ?? (metric.limit - metric.used)
                          .clamp(0, metric.limit)),
                  style: TextStyle(
                    color: metric.isExhausted
                        ? AppColors.danger
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              if (metric.periodEnd != null)
                Text(
                  l.subscriptionUsageResetsAt(
                    _formatShortDate(metric.periodEnd!.toLocal(), locale),
                  ),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _labelFor(L l, String token) => switch (token) {
        'assessments_per_day' => l.subscriptionUsageMetricAssessmentsPerDay,
        'exercises_per_day' => l.subscriptionUsageMetricExercisesPerDay,
        'ai_analysis' ||
        'ai_analyses_per_month' =>
          l.subscriptionUsageMetricAi,
        'children_total' || 'max_children' => l.subscriptionUsageMetricChildren,
        'recordings_per_day' || 'recordings' =>
          l.subscriptionUsageMetricRecordings,
        'patients_total' || 'max_patients' =>
          l.subscriptionUsageMetricPatients,
        _ => l.subscriptionUsageMetricUnknown,
      };

  Color _colorFor(UsageMetric m) {
    if (m.isExhausted) return AppColors.danger;
    if (m.progress >= 0.85) return AppColors.warning;
    if (m.progress >= 0.5) return AppColors.secondary;
    return AppColors.primary;
  }
}

class _UnlimitedBar extends StatelessWidget {
  const _UnlimitedBar({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.25),
              color,
              color.withValues(alpha: 0.25),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExhaustedHint extends StatelessWidget {
  const _ExhaustedHint({required this.l, required this.onUpgrade});

  final L l;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.subscriptionUsageExhaustedHint,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          TextButton(
            key: const Key('subscription.usageCard.exhausted.cta'),
            onPressed: onUpgrade,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              l.subscriptionUsageUpgradeCta,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _periodLine(L l, SubscriptionUsage usage, String locale) {
  final start = usage.periodStart;
  final end = usage.periodEnd;
  if (start == null && end == null) return null;
  return l.subscriptionUsagePeriodLabel(
    start == null ? '—' : _formatShortDate(start.toLocal(), locale),
    end == null ? '—' : _formatShortDate(end.toLocal(), locale),
  );
}

String _formatShortDate(DateTime d, String locale) {
  final loc = locale == 'ru' ? 'ru' : 'uz';
  try {
    return DateFormat.MMMd(loc).format(d);
  } catch (_) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm';
  }
}
