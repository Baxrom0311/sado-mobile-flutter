import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../parrot_mascot.dart';
import '../premium_button.dart';

/// Shared error-state widget shown when a screen fails to load data.
///
/// Pairs a sad parrot with a friendly title, an optional explanation
/// and a retry button. The default copy is sourced from `app_*.arb`
/// (`errorTitle`, `tryAgainLater`, `retry`) so callers don't have to
/// pass anything for the common case.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title,
    this.body,
    this.retryLabel,
    this.onRetry,
    this.mascotSize = 140,
    this.padding = const EdgeInsets.all(AppSpacing.xxl),
  });

  /// Custom headline. Defaults to `L.of(context).errorTitle`.
  final String? title;

  /// Custom body. Defaults to `L.of(context).tryAgainLater`.
  final String? body;

  /// Retry button label. Defaults to `L.of(context).retry`.
  final String? retryLabel;

  /// Tapping the retry button. When null, the retry button is hidden.
  final VoidCallback? onRetry;

  final double mascotSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final resolvedTitle = title ?? l.errorTitle;
    final resolvedBody = body ?? l.tryAgainLater;
    final resolvedLabel = retryLabel ?? l.retry;

    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ParrotMascot(mood: ParrotMood.sad, size: mascotSize),
            const SizedBox(height: AppSpacing.lg),
            Text(
              resolvedTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              resolvedBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              PremiumButton(
                label: resolvedLabel,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.04, end: 0);
  }
}
