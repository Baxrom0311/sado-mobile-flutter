import 'package:flutter/material.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../data/models/models.dart';
import 'premium_card.dart';

/// Bulleted list of localized recommendations from the AI analyzer.
///
/// Sorted by descending priority client-side so urgent items always
/// surface at the top regardless of server order. Renders nothing when
/// [recommendations] is empty.
class RecommendationsList extends StatelessWidget {
  const RecommendationsList({super.key, required this.recommendations});

  final List<AnalysisRecommendation> recommendations;

  /// Stable priority comparator — high (2) before medium (1) before low (0).
  static int _priorityRank(RecommendationPriority p) => switch (p) {
        RecommendationPriority.high => 2,
        RecommendationPriority.medium => 1,
        RecommendationPriority.low => 0,
      };

  static Color _priorityColor(RecommendationPriority p) => switch (p) {
        RecommendationPriority.high => AppColors.danger,
        RecommendationPriority.medium => AppColors.warning,
        RecommendationPriority.low => AppColors.primary,
      };

  String _priorityLabel(L l, RecommendationPriority p) => switch (p) {
        RecommendationPriority.high => l.recommendationPriorityHigh,
        RecommendationPriority.medium => l.recommendationPriorityMedium,
        RecommendationPriority.low => l.recommendationPriorityLow,
      };

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) return const SizedBox.shrink();
    final l = L.of(context)!;

    final sorted = [...recommendations]
      ..sort((a, b) => _priorityRank(b.priority).compareTo(
            _priorityRank(a.priority),
          ));

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
                  color: AppColors.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppColors.secondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.recommendations,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.recommendationsSubtitle,
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
          for (var i = 0; i < sorted.length; i++) ...[
            _RecommendationRow(
              rec: sorted[i],
              priorityLabel: _priorityLabel(l, sorted[i].priority),
              priorityColor: _priorityColor(sorted[i].priority),
            ),
            if (i != sorted.length - 1)
              const Padding(
                padding:
                    EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({
    required this.rec,
    required this.priorityLabel,
    required this.priorityColor,
  });

  final AnalysisRecommendation rec;
  final String priorityLabel;
  final Color priorityColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$priorityLabel: ${rec.message}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: priorityColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: priorityColor.withValues(alpha: 0.35),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    priorityLabel,
                    style: TextStyle(
                      color: priorityColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rec.message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
