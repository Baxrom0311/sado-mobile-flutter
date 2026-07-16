import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme.dart';
import '../../../widgets/premium_card.dart';
import 'plan_feature_row.dart';

/// A premium subscription tier card. Three variants drive the visual
/// hierarchy:
///
///  * `current` – the user is already on this plan; CTA disabled, "Joriy"
///    badge in the corner.
///  * `recommended` – upsell tier, rendered with the hero gradient and
///    a "Tavsiya etiladi" badge.
///  * default – a clean white card.
///
/// The card itself is built on top of [PremiumCard] so it inherits the
/// app-wide press animation, soft shadow, and corner radii.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.title,
    required this.tagline,
    required this.priceText,
    required this.priceSubtext,
    required this.features,
    required this.ctaLabel,
    required this.onCtaPressed,
    this.recommended = false,
    this.current = false,
    this.currentBadgeText,
    this.recommendedBadgeText,
    this.entranceDelay = Duration.zero,
  });

  final String title;
  final String tagline;
  final String priceText;
  final String? priceSubtext;
  final List<String> features;
  final String ctaLabel;
  final VoidCallback? onCtaPressed;
  final bool recommended;
  final bool current;
  final String? currentBadgeText;
  final String? recommendedBadgeText;
  final Duration entranceDelay;

  @override
  Widget build(BuildContext context) {
    final highlighted = recommended;
    final titleColor =
        highlighted ? Colors.white : AppColors.textPrimary;
    final taglineColor = highlighted
        ? Colors.white.withValues(alpha: 0.92)
        : AppColors.textSecondary;
    final priceColor =
        highlighted ? Colors.white : AppColors.textPrimary;

    return PremiumCard(
      gradient: highlighted ? AppColors.heroGradient : null,
      shadowColor: highlighted ? AppColors.primary : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tagline,
                      style: TextStyle(
                        color: taglineColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (current && currentBadgeText != null)
                _Badge(
                  label: currentBadgeText!,
                  color: highlighted ? Colors.white : AppColors.primary,
                  onColor:
                      highlighted ? AppColors.primary : Colors.white,
                ),
              if (!current &&
                  recommended &&
                  recommendedBadgeText != null)
                _Badge(
                  label: recommendedBadgeText!,
                  color: Colors.white,
                  onColor: AppColors.primary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priceText,
                style: TextStyle(
                  color: priceColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              if (priceSubtext != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    priceSubtext!,
                    style: TextStyle(
                      color: highlighted
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...features.map(
            (f) => PlanFeatureRow(label: f, highlighted: highlighted),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: _PlanCtaButton(
              label: ctaLabel,
              onPressed: current ? null : onCtaPressed,
              highlighted: highlighted,
            ),
          ),
        ],
      ),
    )
        .animate(delay: entranceDelay)
        .fadeIn(duration: 320.ms)
        .slideY(begin: 0.06, end: 0);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.onColor,
  });

  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: onColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _PlanCtaButton extends StatelessWidget {
  const _PlanCtaButton({
    required this.label,
    required this.onPressed,
    required this.highlighted,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final bgColor = highlighted
        ? Colors.white
        : (disabled ? AppColors.surfaceMuted : AppColors.primary);
    final fgColor = highlighted
        ? AppColors.primary
        : (disabled ? AppColors.textMuted : Colors.white);

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        disabledBackgroundColor: bgColor,
        disabledForegroundColor: fgColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: Text(label),
    );
  }
}
