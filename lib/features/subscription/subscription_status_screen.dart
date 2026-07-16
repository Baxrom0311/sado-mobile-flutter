import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/api/billing_api.dart';
import '../../data/local/preferences.dart';
import '../../data/models/subscription_plan.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/speech_bubble.dart';
import 'widgets/usage_card.dart';

/// Subscription status / management surface for both free and paid
/// users. Provides a single, premium-feeling place to:
///
///  * See which plan the user is currently on, when it started, and
///    when it expires.
///  * Toggle auto-renew off (graceful "coming soon" sheet when the
///    cancel endpoint isn't yet deployed on this environment).
///  * Jump to the [/subscription] catalog for an upgrade or
///    plan change.
///  * Cancel / dismiss back to settings.
///
/// Free users see an upsell-styled empty state with the parrot mascot
/// and a primary "Upgrade" CTA so the screen is never blank.
class SubscriptionStatusScreen extends ConsumerWidget {
  const SubscriptionStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final subAsync = ref.watch(mySubscriptionProvider);
    final usageAsync = ref.watch(subscriptionUsageProvider);
    final locale = ref.watch(localeProvider).languageCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.subscriptionStatusTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: subAsync.when(
          loading: () => const _StatusLoading(),
          error: (_, __) => ErrorState(
            title: l.subscriptionStatusErrorTitle,
            body: l.subscriptionStatusErrorBody,
            retryLabel: l.subscriptionStatusErrorRetry,
            onRetry: () => ref.invalidate(mySubscriptionProvider),
          ),
          data: (sub) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(mySubscriptionProvider);
              ref.invalidate(subscriptionUsageProvider);
            },
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.huge,
              ),
              children: sub.isPaid
                  ? _paidLayout(context, l, sub, locale, ref, usageAsync)
                  : _freeLayout(context, l, locale, ref, usageAsync),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Free

  List<Widget> _freeLayout(
    BuildContext context,
    L l,
    String locale,
    WidgetRef ref,
    AsyncValue<SubscriptionUsage> usageAsync,
  ) =>
      [
        _FreeHero(
          title: l.subscriptionStatusFreeHeroTitle,
          subtitle: l.subscriptionStatusFreeHeroBody,
          mascotMessage: l.subscriptionStatusFreeMascotMessage,
        ),
        const SizedBox(height: AppSpacing.xl),
        _OneLineRow(
          icon: Icons.check_circle_rounded,
          color: AppColors.primary,
          text: l.subscriptionStatusFreeBullet1,
        ),
        const SizedBox(height: AppSpacing.sm),
        _OneLineRow(
          icon: Icons.workspace_premium_rounded,
          color: AppColors.warning,
          text: l.subscriptionStatusFreeBullet2,
        ),
        const SizedBox(height: AppSpacing.sm),
        _OneLineRow(
          icon: Icons.shield_outlined,
          color: AppColors.sky,
          text: l.subscriptionStatusFreeBullet3,
        ),
        const SizedBox(height: AppSpacing.xl),
        _UsageSection(
          usageAsync: usageAsync,
          locale: locale,
          ref: ref,
          onUpgrade: () => context.go('/subscription'),
          heroVariant: false,
        ),
        const SizedBox(height: AppSpacing.xl),
        _PrimaryAction(
          key: const Key('subscription.status.upgradeCta'),
          label: l.subscriptionStatusUpgradeCta,
          onPressed: () => context.go('/subscription'),
        ),
        const SizedBox(height: AppSpacing.md),
        _HistoryLink(l: l, onTap: () => context.go('/subscription/history')),
      ];

  // ---------------------------------------------------------------- Paid

  List<Widget> _paidLayout(
    BuildContext context,
    L l,
    UserSubscription sub,
    String locale,
    WidgetRef ref,
    AsyncValue<SubscriptionUsage> usageAsync,
  ) {
    final cancelled =
        sub.status == 'cancelled' || sub.cancelledAt != null;
    final expired = sub.status == 'expired';

    return [
      _PaidHero(
        plan: sub,
        l: l,
      ),
      const SizedBox(height: AppSpacing.lg),
      _StatusBadgeRow(
        status: sub.status,
        autoRenew: sub.autoRenew,
        l: l,
      ),
      const SizedBox(height: AppSpacing.lg),
      _DetailCard(
        items: _buildDetailItems(l, sub, locale),
      ),
      const SizedBox(height: AppSpacing.lg),
      _UsageSection(
        usageAsync: usageAsync,
        locale: locale,
        ref: ref,
        onUpgrade: () => context.go('/subscription'),
        heroVariant: false,
      ),
      if (sub.features.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        _FeaturesCard(features: sub.features, l: l),
      ],
      const SizedBox(height: AppSpacing.lg),
      // Primary action is always "Change plan" — the cancel CTA lives
      // below as a low-emphasis text button for paid+active rows.
      _PrimaryAction(
        key: const Key('subscription.status.changePlanCta'),
        label: l.subscriptionStatusChangePlanCta,
        onPressed: () => context.go('/subscription'),
      ),
      if (!cancelled && !expired && sub.autoRenew) ...[
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          key: const Key('subscription.status.cancelCta'),
          onPressed: () => _confirmCancel(context, l, ref),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.danger,
            padding:
                const EdgeInsets.symmetric(vertical: 10),
          ),
          child: Text(
            l.subscriptionStatusCancelCta,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ],
      if (expired) ...[
        const SizedBox(height: AppSpacing.md),
        _ExpiredHint(l: l),
      ],
      if (cancelled && !expired) ...[
        const SizedBox(height: AppSpacing.md),
        _CancelledHint(l: l, expiresAt: sub.expiresAt, locale: locale),
        const SizedBox(height: AppSpacing.sm),
        ElevatedButton.icon(
          key: const Key('subscription.status.resumeCta'),
          icon: const Icon(Icons.autorenew_rounded, size: 18),
          label: Text(
            l.subscriptionStatusResumeCta,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          onPressed: () => _confirmResume(context, l, ref),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      _HistoryLink(l: l, onTap: () => context.go('/subscription/history')),
    ];
  }

  List<_DetailItem> _buildDetailItems(
    L l,
    UserSubscription sub,
    String locale,
  ) {
    final items = <_DetailItem>[
      _DetailItem(
        icon: Icons.event_available_rounded,
        label: l.subscriptionStatusStartedLabel,
        value: sub.startedAt.millisecondsSinceEpoch == 0
            ? l.subscriptionStatusUnknown
            : _formatDate(sub.startedAt.toLocal(), locale),
      ),
    ];
    if (sub.expiresAt != null) {
      items.add(_DetailItem(
        icon: Icons.event_busy_rounded,
        label: l.subscriptionStatusExpiresLabel,
        value: _formatDate(sub.expiresAt!.toLocal(), locale),
      ));
    }
    if (sub.daysRemaining != null && sub.daysRemaining! >= 0) {
      items.add(_DetailItem(
        icon: Icons.schedule_rounded,
        label: l.subscriptionStatusDaysRemainingLabel,
        value: l.subscriptionStatusDaysRemainingValue(sub.daysRemaining!),
      ));
    }
    items.add(_DetailItem(
      icon: sub.autoRenew
          ? Icons.autorenew_rounded
          : Icons.autorenew_outlined,
      label: l.subscriptionStatusAutoRenewLabel,
      value: sub.autoRenew
          ? l.subscriptionStatusAutoRenewOn
          : l.subscriptionStatusAutoRenewOff,
      valueColor:
          sub.autoRenew ? AppColors.primary : AppColors.textSecondary,
    ));
    return items;
  }

  Future<void> _confirmCancel(
    BuildContext context,
    L l,
    WidgetRef ref,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.subscriptionStatusCancelDialogTitle),
        content: Text(l.subscriptionStatusCancelDialogBody),
        actions: [
          TextButton(
            key: const Key('subscription.status.cancelDialog.dismiss'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.subscriptionStatusCancelDialogKeep),
          ),
          ElevatedButton(
            key: const Key('subscription.status.cancelDialog.confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(l.subscriptionStatusCancelDialogConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _attemptCancel(context, l, ref);
  }

  Future<void> _attemptCancel(
    BuildContext context,
    L l,
    WidgetRef ref,
  ) async {
    final api = ref.read(billingApiProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final updated = await api.cancelAutoRenew();
      // Refresh the cached value so any other listener (settings,
      // home upsell card) sees the new auto-renew state immediately.
      ref.invalidate(mySubscriptionProvider);
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            updated.autoRenew
                ? l.subscriptionStatusCancelFailedSnack
                : l.subscriptionStatusCancelSuccessSnack,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on BillingNotImplemented {
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
        builder: (ctx) => _CancelComingSoonSheet(l: l),
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l.subscriptionStatusCancelFailedSnack),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmResume(
    BuildContext context,
    L l,
    WidgetRef ref,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.subscriptionStatusResumeDialogTitle),
        content: Text(l.subscriptionStatusResumeDialogBody),
        actions: [
          TextButton(
            key: const Key('subscription.status.resumeDialog.dismiss'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.subscriptionStatusResumeDialogKeep),
          ),
          ElevatedButton(
            key: const Key('subscription.status.resumeDialog.confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(l.subscriptionStatusResumeDialogConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _attemptResume(context, l, ref);
  }

  Future<void> _attemptResume(
    BuildContext context,
    L l,
    WidgetRef ref,
  ) async {
    final api = ref.read(billingApiProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final updated = await api.resumeAutoRenew();
      ref.invalidate(mySubscriptionProvider);
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            updated.autoRenew
                ? l.subscriptionStatusResumeSuccessSnack
                : l.subscriptionStatusResumeFailedSnack,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on BillingNotImplemented {
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
        builder: (ctx) => _ResumeComingSoonSheet(l: l),
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l.subscriptionStatusResumeFailedSnack),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// =====================================================================
// Sub-widgets
// =====================================================================

/// Formats [d] as a long human date in the supplied locale, falling
/// back to a manual numeric format when intl date data for the locale
/// isn't loaded (this happens in widget tests and on the very first
/// render before [initializeDateFormatting] runs).
String _formatDate(DateTime d, String locale) {
  final loc = locale == 'ru' ? 'ru' : 'uz';
  try {
    return DateFormat.yMMMMd(loc).format(d);
  } catch (_) {
    // Fallback to a stable, locale-agnostic numeric date.
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }
}

class _FreeHero extends StatelessWidget {
  const _FreeHero({
    required this.title,
    required this.subtitle,
    required this.mascotMessage,
  });

  final String title;
  final String subtitle;
  final String mascotMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('subscription.status.freeHero'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ParrotMascot(mood: ParrotMood.happy, size: 88),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SpeechBubble(text: mascotMessage),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.04);
  }
}

class _PaidHero extends StatelessWidget {
  const _PaidHero({required this.plan, required this.l});

  final UserSubscription plan;
  final L l;

  @override
  Widget build(BuildContext context) {
    final isExpired = plan.status == 'expired';
    final isCancelled = plan.status == 'cancelled';
    final mood = isExpired
        ? ParrotMood.sad
        : (isCancelled ? ParrotMood.listening : ParrotMood.happy);
    final mascotMessage = isExpired
        ? l.subscriptionStatusExpiredMascot
        : (isCancelled
            ? l.subscriptionStatusCancelledMascot
            : l.subscriptionStatusActiveMascot);

    return Container(
      key: const Key('subscription.status.paidHero'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft(AppColors.primary, opacity: 0.22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParrotMascot(mood: mood, size: 96),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    l.subscriptionStatusYourPlanLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _planDisplayName(l, plan.planId),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SpeechBubble(
                  text: mascotMessage,
                  color: Colors.white,
                  textColor: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.04);
  }

  String _planDisplayName(L l, String planId) => switch (planId) {
        'free' => l.subscriptionFreeName,
        'parent_pro' => l.subscriptionProName,
        'logoped' => l.subscriptionLogopedName,
        _ => planId,
      };
}

class _StatusBadgeRow extends StatelessWidget {
  const _StatusBadgeRow({
    required this.status,
    required this.autoRenew,
    required this.l,
  });

  final String status;
  final bool autoRenew;
  final L l;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, icon) = switch (status) {
      'active' => (
          l.subscriptionStatusBadgeActive,
          AppColors.primaryLight,
          AppColors.primary,
          Icons.check_circle_rounded,
        ),
      'cancelled' => (
          l.subscriptionStatusBadgeCancelled,
          AppColors.surfaceMuted,
          AppColors.textSecondary,
          Icons.cancel_outlined,
        ),
      'expired' => (
          l.subscriptionStatusBadgeExpired,
          AppColors.secondaryLight,
          AppColors.danger,
          Icons.event_busy_rounded,
        ),
      'past_due' => (
          l.subscriptionStatusBadgePastDue,
          AppColors.accentLight,
          AppColors.warning,
          Icons.warning_amber_rounded,
        ),
      _ => (
          status,
          AppColors.surfaceMuted,
          AppColors.textSecondary,
          Icons.info_outline_rounded,
        ),
    };
    return Wrap(
      key: const Key('subscription.status.badgeRow'),
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _StatusChip(label: label, bg: bg, fg: fg, icon: icon),
        if (status == 'active')
          _StatusChip(
            label: autoRenew
                ? l.subscriptionStatusAutoRenewOn
                : l.subscriptionStatusAutoRenewOff,
            bg: autoRenew
                ? AppColors.primaryLight
                : AppColors.surfaceMuted,
            fg: autoRenew
                ? AppColors.primary
                : AppColors.textSecondary,
            icon: autoRenew
                ? Icons.autorenew_rounded
                : Icons.autorenew_outlined,
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.items});

  final List<_DetailItem> items;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      key: const Key('subscription.status.detailCard'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _DetailRow(item: items[i]),
            if (i < items.length - 1)
              const Divider(
                height: AppSpacing.lg,
                color: AppColors.borderStrong,
                thickness: 0.4,
              ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.item});

  final _DetailItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(item.icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            item.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          item.value,
          style: TextStyle(
            color: item.valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard({required this.features, required this.l});

  final List<String> features;
  final L l;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      key: const Key('subscription.status.featuresCard'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.subscriptionStatusFeaturesTitle,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _featureLabel(l, f),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _featureLabel(L l, String f) => switch (f) {
        'all_exercises' || 'basic_exercises' =>
          l.subscriptionFeatureBasicExercises,
        'basic_progress' => l.subscriptionFeatureBasicProgress,
        'detailed_progress' => l.subscriptionFeatureDetailedProgress,
        'recommendations' => l.subscriptionFeatureRecommendations,
        'export_pdf' => l.subscriptionFeatureExportPdf,
        'patient_management' => l.subscriptionFeaturePatientManagement,
        'assign_exercises' => l.subscriptionFeatureAssignExercises,
        'therapy_goals' => l.subscriptionFeatureTherapyGoals,
        'screening_battery' => l.subscriptionFeatureScreeningBattery,
        'referral_pdf' => l.subscriptionFeatureReferralPdf,
        'analytics' => l.subscriptionFeatureAnalytics,
        'full_ai_analysis' => l.subscriptionFeatureUnlimitedAi,
        _ => f.replaceAll('_', ' '),
      };
}

class _OneLineRow extends StatelessWidget {
  const _OneLineRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _ExpiredHint extends StatelessWidget {
  const _ExpiredHint({required this.l});
  final L l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.event_busy_rounded,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.subscriptionStatusExpiredHint,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledHint extends StatelessWidget {
  const _CancelledHint({
    required this.l,
    required this.expiresAt,
    required this.locale,
  });

  final L l;
  final DateTime? expiresAt;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final dateText = expiresAt == null
        ? l.subscriptionStatusUnknown
        : _formatDate(expiresAt!.toLocal(), locale);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.subscriptionStatusCancelledHint(dateText),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelComingSoonSheet extends StatelessWidget {
  const _CancelComingSoonSheet({required this.l});
  final L l;

  @override
  Widget build(BuildContext context) {
    return _ComingSoonSheet(
      title: l.subscriptionStatusCancelComingSoonTitle,
      body: l.subscriptionStatusCancelComingSoonBody,
      closeLabel: l.subscriptionStatusCancelComingSoonClose,
      closeKey: const Key('subscription.status.cancelComingSoon.close'),
    );
  }
}

class _ResumeComingSoonSheet extends StatelessWidget {
  const _ResumeComingSoonSheet({required this.l});
  final L l;

  @override
  Widget build(BuildContext context) {
    return _ComingSoonSheet(
      title: l.subscriptionStatusResumeComingSoonTitle,
      body: l.subscriptionStatusResumeComingSoonBody,
      // Re-use the cancel-sheet's localized "Got it" close label so the
      // visual and copy parity stays tight without inventing a duplicate
      // ARB key.
      closeLabel: l.subscriptionStatusCancelComingSoonClose,
      closeKey: const Key('subscription.status.resumeComingSoon.close'),
    );
  }
}

/// Shared layout for the cancel/resume "coming soon" bottom sheets.
/// Keeps the parrot mascot, copy, and dismiss button perfectly aligned
/// across both flows so users feel a consistent calm response when an
/// endpoint isn't deployed yet.
class _ComingSoonSheet extends StatelessWidget {
  const _ComingSoonSheet({
    required this.title,
    required this.body,
    required this.closeLabel,
    required this.closeKey,
  });

  final String title;
  final String body;
  final String closeLabel;
  final Key closeKey;

  @override
  Widget build(BuildContext context) {
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
                  borderRadius:
                      BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Center(
              child: ParrotMascot(
                  mood: ParrotMood.listening, size: 88),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
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
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              key: closeKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppRadius.lg),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                closeLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLoading extends StatelessWidget {
  const _StatusLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        ShimmerCard(height: 140),
        SizedBox(height: AppSpacing.lg),
        ShimmerCard(height: 64),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 220),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 180),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 56),
      ],
    );
  }
}

/// Async wrapper around [SubscriptionUsageCard]. Keeps the layout
/// stable while the usage envelope resolves: a shimmer placeholder on
/// load, a soft error pill on failure (errors here are non-blocking —
/// usage is purely informational), and the real card on success.
class _UsageSection extends StatelessWidget {
  const _UsageSection({
    required this.usageAsync,
    required this.locale,
    required this.ref,
    required this.onUpgrade,
    required this.heroVariant,
  });

  final AsyncValue<SubscriptionUsage> usageAsync;
  final String locale;
  final WidgetRef ref;
  final VoidCallback onUpgrade;
  final bool heroVariant;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return usageAsync.when(
      loading: () => const ShimmerCard(
        key: Key('subscription.usageCard.loading'),
        height: 200,
      ),
      error: (_, __) => _UsageErrorPill(
        l: l,
        onRetry: () => ref.invalidate(subscriptionUsageProvider),
      ),
      data: (usage) => SubscriptionUsageCard(
        usage: usage,
        locale: locale,
        onUpgrade: onUpgrade,
        heroVariant: heroVariant,
      ),
    );
  }
}

class _UsageErrorPill extends StatelessWidget {
  const _UsageErrorPill({required this.l, required this.onRetry});

  final L l;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('subscription.usageCard.errorPill'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.subscriptionUsageErrorBody,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          TextButton(
            key: const Key('subscription.usageCard.errorPill.retry'),
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              l.subscriptionUsageErrorRetry,
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

/// Low-emphasis tappable row that routes to the billing-history
/// surface. Mirrors the visual weight of the cancel button so it
/// sits comfortably below the primary CTA without competing for
/// attention.
class _HistoryLink extends StatelessWidget {
  const _HistoryLink({required this.l, required this.onTap});

  final L l;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('subscription.status.historyLink'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.subscriptionHistoryMenuRow,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.subscriptionHistoryMenuHint,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
