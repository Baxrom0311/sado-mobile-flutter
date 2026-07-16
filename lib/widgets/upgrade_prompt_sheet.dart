import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../data/api/billing_interceptor.dart';
import 'parrot_mascot.dart';
import 'speech_bubble.dart';

/// Friendly bottom sheet shown when the API rejects an action because
/// the caller's free-plan quota is exhausted (HTTP 402).
///
/// Mirrors the look-and-feel of the "coming soon" sheet from
/// `SubscriptionScreen` so the two surfaces feel consistent: parrot
/// mascot up top, mood-appropriate copy in a speech bubble, primary CTA
/// that routes to `/subscription`, and a low-emphasis dismiss action.
class UpgradePromptSheet extends StatelessWidget {
  const UpgradePromptSheet({super.key, required this.notice});

  final PlanLimitNotice notice;

  /// Shows the sheet as a modal. Returns `true` if the user tapped the
  /// upgrade CTA (the caller can use this to record analytics or to
  /// know whether navigation has already happened).
  static Future<bool?> show(
    BuildContext context, {
    required PlanLimitNotice notice,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (ctx) => UpgradePromptSheet(notice: notice),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final body = _bodyFor(l, notice);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Center(
              child: ParrotMascot(mood: ParrotMood.happy, size: 96),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: SpeechBubble(
                key: const ValueKey('planLimit.bubble'),
                text: l.planLimitMascotMessage,
                tailDirection: SpeechBubbleTail.up,
                maxWidth: 300,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.planLimitTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            if (notice.message != null && notice.message!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  notice.message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              key: const Key('planLimit.upgradeCta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                elevation: 0,
              ),
              onPressed: () {
                // Capture the router via the surrounding context BEFORE
                // popping the sheet. The bottom-sheet route's context is
                // deactivated the moment we pop it, so deferring the
                // navigation through it would silently no-op. Calling
                // `go` *after* the pop is fine because GoRouter walks
                // the live shell's element tree, not the dismissed
                // modal.
                final router = GoRouter.of(context);
                Navigator.of(context).pop(true);
                router.go('/subscription');
              },
              child: Text(
                l.planLimitUpgradeCta,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const Key('planLimit.dismiss'),
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: Text(
                l.planLimitDismiss,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.04, end: 0),
      ),
    );
  }

  String _bodyFor(L l, PlanLimitNotice notice) {
    return switch (notice.metric) {
      'exercises_per_day' => l.planLimitExercisesBody,
      'assessments_per_day' => l.planLimitAssessmentsBody,
      'ai_analysis' ||
      'ai_analyses_per_month' =>
        l.planLimitAiBody,
      'children_total' || 'max_children' => l.planLimitChildrenBody,
      _ => l.planLimitGenericBody,
    };
  }
}
