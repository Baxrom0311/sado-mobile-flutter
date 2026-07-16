import 'package:flutter/material.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../data/models/models.dart';
import 'premium_card.dart';

/// Premium per-phoneme accuracy breakdown card.
///
/// Shows one row per phoneme with:
///   * the IPA-like glyph in a coloured chip
///   * a horizontal accuracy bar that animates from 0 → accuracy
///   * the integer percent on the right
///   * a small localized error-type tag when the phoneme was mis-produced
///
/// Caller is responsible for filtering / sorting the list. The widget
/// renders nothing when given an empty list — the results screen owns
/// the "no analysis" empty state, not this widget.
class PhonemeBreakdownCard extends StatelessWidget {
  const PhonemeBreakdownCard({super.key, required this.scores});

  final List<PhonemeScore> scores;

  /// Fraction → bar colour. Mirrors the risk badge palette so green / amber
  /// / red read consistently across the app.
  static Color colorFor(double accuracy) {
    if (accuracy >= 0.75) return AppColors.success;
    if (accuracy >= 0.5) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    if (scores.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Semantics(
        container: true,
        label: l.phonemeListSemantics(scores.length),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.phonemeBreakdownTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.phonemeBreakdownSubtitle,
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
            for (var i = 0; i < scores.length; i++) ...[
              _PhonemeRow(score: scores[i]),
              if (i != scores.length - 1)
                const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhonemeRow extends StatelessWidget {
  const _PhonemeRow({required this.score});
  final PhonemeScore score;

  String? _errorLabel(L l) {
    switch (score.errorType) {
      case null:
        return null;
      case 'substitution':
        return l.phonemeErrorSubstitution;
      case 'omission':
        return l.phonemeErrorOmission;
      case 'distortion':
        return l.phonemeErrorDistortion;
      default:
        return l.phonemeErrorOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final color = PhonemeBreakdownCard.colorFor(score.accuracy);
    final percent = score.accuracyPercent;
    final errorLabel = _errorLabel(l);

    return Semantics(
      label: '${score.phoneme}: ${l.phonemeAccuracyPercent(percent)}'
          '${errorLabel == null ? '' : ', $errorLabel'}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Phoneme glyph chip
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.4,
              ),
            ),
            child: Text(
              score.phoneme,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: score.accuracy),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor:
                          AppColors.surfaceMuted.withValues(alpha: 0.6),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                if (errorLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    errorLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 44,
            child: Text(
              l.phonemeAccuracyPercent(percent),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
