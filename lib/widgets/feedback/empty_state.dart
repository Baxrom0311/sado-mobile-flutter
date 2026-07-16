import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme.dart';
import '../parrot_mascot.dart';
import '../premium_button.dart';

/// Shared empty-state widget used across list/detail screens.
///
/// Renders the SADO parrot mascot, a localized title, an optional
/// supporting body line and an optional primary CTA. All copy must be
/// passed in already-localized — this widget intentionally has no
/// access to `L.of(context)` so it can be exercised in isolation.
///
/// Use [ParrotMood.idle] for friendly "nothing here yet" states and
/// [ParrotMood.sad] for "we couldn't find anything" states. Errors should
/// use [ErrorState] instead.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.body,
    this.mood = ParrotMood.idle,
    this.mascotSize = 140,
    this.ctaLabel,
    this.ctaIcon,
    this.onCta,
    this.padding = const EdgeInsets.all(AppSpacing.xxl),
    this.compact = false,
  });

  /// Headline shown under the mascot.
  final String title;

  /// Optional supporting copy under the title.
  final String? body;

  /// Mascot mood. Idle for empty content, sad for "no match found".
  final ParrotMood mood;

  /// Size of the mascot. Use a smaller value when embedded in narrow
  /// spaces (e.g. 96 inside a card).
  final double mascotSize;

  /// Label for the primary CTA. The CTA renders only when both
  /// [ctaLabel] and [onCta] are provided.
  final String? ctaLabel;
  final IconData? ctaIcon;
  final VoidCallback? onCta;

  /// Outer padding. Override when embedding in tighter layouts.
  final EdgeInsetsGeometry padding;

  /// Tighter spacing for inline placements (cards, sheets).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasCta = ctaLabel != null && onCta != null;
    final spacingLg = compact ? AppSpacing.md : AppSpacing.lg;
    final spacingXl = compact ? AppSpacing.lg : AppSpacing.xl;

    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ParrotMascot(mood: mood, size: mascotSize),
            SizedBox(height: spacingLg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (hasCta) ...[
              SizedBox(height: spacingXl),
              PremiumButton(
                label: ctaLabel!,
                icon: ctaIcon,
                onPressed: onCta,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.04, end: 0);
  }
}
