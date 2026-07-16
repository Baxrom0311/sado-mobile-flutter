import 'package:flutter/material.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../data/models/models.dart';
import 'premium_card.dart';

/// Three-stat fluency summary: speaking rate, pause ratio, repetitions.
///
/// Renders nothing when [score] is `null` or every metric is missing —
/// this lets the parent screen drop the widget into a column without
/// having to defend against the empty case.
class FluencyStatsCard extends StatelessWidget {
  const FluencyStatsCard({super.key, required this.score});

  final FluencyScore? score;

  @override
  Widget build(BuildContext context) {
    final s = score;
    if (s == null || s.isEmpty) return const SizedBox.shrink();

    final l = L.of(context)!;
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.speed_rounded,
                  color: AppColors.tertiary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.fluencyTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.fluencySubtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              if (s.rate != null)
                Expanded(
                  child: _StatTile(
                    icon: Icons.timer_outlined,
                    label: l.fluencyRateLabel,
                    value: l.fluencyRateValue(s.rate!.toStringAsFixed(1)),
                    color: AppColors.primary,
                  ),
                ),
              if (s.rate != null && s.pauseRatio != null)
                const SizedBox(width: AppSpacing.sm),
              if (s.pauseRatio != null)
                Expanded(
                  child: _StatTile(
                    icon: Icons.pause_circle_outline_rounded,
                    label: l.fluencyPauseLabel,
                    value: l.fluencyPauseValue(
                      (s.pauseRatio! * 100).round(),
                    ),
                    color: AppColors.warning,
                  ),
                ),
              if ((s.rate != null || s.pauseRatio != null) &&
                  s.repetitions != null)
                const SizedBox(width: AppSpacing.sm),
              if (s.repetitions != null)
                Expanded(
                  child: _StatTile(
                    icon: Icons.repeat_rounded,
                    label: l.fluencyRepetitionsLabel,
                    value: l.fluencyRepetitionsValue(s.repetitions!),
                    color: AppColors.tertiary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
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
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: color.withValues(alpha: 0.18),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
