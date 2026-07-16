import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../../core/theme.dart';
import '../../../data/models/subscription_plan.dart';
import '../../../data/services/external_url_launcher.dart';
import '../../../widgets/parrot_mascot.dart';

/// Branded "Contact Sales" bottom sheet shown when a user taps a
/// direct-sales tier (logoped_pro, clinic, …). These plans don't have
/// a self-serve checkout — they're sold through a human conversation,
/// so the sheet surfaces the sales email + phone number with one-tap
/// CTAs (mail composer, dialer) and a copy-to-clipboard fallback.
///
/// Why a dedicated sheet (instead of a generic "coming soon" card)?
///
/// * The B2B / B2B2C tiers are the highest-revenue plans in the
///   business model — surfacing real contact info turns the upgrade
///   tap into a qualified sales lead instead of an empty marketing
///   beat.
/// * The mascot, copy, and CTAs are designed to feel calm and
///   professional rather than gamified — these decisions are made by
///   adults (clinic admins, therapists) and the visual register
///   should match.
class ContactSalesSheet extends StatelessWidget {
  const ContactSalesSheet({
    super.key,
    required this.plan,
    required this.planDisplayName,
    ExternalUrlLauncher? launcher,
  }) : _launcher = launcher;

  final SubscriptionPlan plan;
  final String planDisplayName;
  final ExternalUrlLauncher? _launcher;

  /// Show the sheet as a modal bottom sheet. Returns when the user
  /// dismisses it. The [launcher] override is exposed for widget
  /// tests so they can assert which intent was fired without
  /// bouncing into the platform plugin.
  static Future<void> show(
    BuildContext context, {
    required SubscriptionPlan plan,
    required String planDisplayName,
    ExternalUrlLauncher? launcher,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (ctx) => ContactSalesSheet(
        plan: plan,
        planDisplayName: planDisplayName,
        launcher: launcher,
      ),
    );
  }

  ExternalUrlLauncher get _resolved =>
      _launcher ?? ExternalUrlLauncher.production;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;

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
            // Grabber
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
              child: ParrotMascot(mood: ParrotMood.listening, size: 88),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l.subscriptionContactSalesTitle,
              key: const Key('contactSales.title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.subscriptionContactSalesIntro(planDisplayName),
              key: const Key('contactSales.intro'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ContactRow(
              keyPrefix: 'contactSales.email',
              icon: Icons.mail_outline_rounded,
              label: l.subscriptionContactSalesEmailLabel,
              value: l.subscriptionContactSalesEmail,
              copyTooltip: l.subscriptionContactSalesCopyTooltip,
              copiedSnackText: l.subscriptionContactSalesCopiedSnack,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ContactRow(
              keyPrefix: 'contactSales.phone',
              icon: Icons.call_outlined,
              label: l.subscriptionContactSalesPhoneLabel,
              value: l.subscriptionContactSalesPhone,
              copyTooltip: l.subscriptionContactSalesCopyTooltip,
              copiedSnackText: l.subscriptionContactSalesCopiedSnack,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              key: const Key('contactSales.email.cta'),
              onPressed: () => _onEmailPressed(context, l),
              icon: const Icon(Icons.mail_outline_rounded, size: 20),
              label: Text(
                l.subscriptionContactSalesEmailCta,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('contactSales.phone.cta'),
              onPressed: () => _onPhonePressed(context, l),
              icon: const Icon(Icons.call_outlined, size: 20),
              label: Text(
                l.subscriptionContactSalesPhoneCta,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primaryDark, width: 1.4),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const Key('contactSales.close'),
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                l.subscriptionContactSalesClose,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.04, end: 0);
  }

  Future<void> _onEmailPressed(BuildContext context, L l) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await _resolved.openMailto(
      l.subscriptionContactSalesEmail,
      subject: l.subscriptionContactSalesEmailSubject(planDisplayName),
      body: l.subscriptionContactSalesEmailBody(planDisplayName),
    );
    if (!ok) {
      // Fallback: copy the email so the user can paste it into their
      // own client. Never let the tap silently noop.
      await Clipboard.setData(
        ClipboardData(text: l.subscriptionContactSalesEmail),
      );
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l.subscriptionContactSalesCopiedSnack),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onPhonePressed(BuildContext context, L l) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await _resolved.openTel(l.subscriptionContactSalesPhone);
    if (!ok) {
      await Clipboard.setData(
        ClipboardData(text: l.subscriptionContactSalesPhone),
      );
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l.subscriptionContactSalesCopiedSnack),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Compact label + value row with a trailing copy-to-clipboard
/// button. Used inside [ContactSalesSheet] for both the email and
/// phone entries so the layout stays consistent.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.keyPrefix,
    required this.icon,
    required this.label,
    required this.value,
    required this.copyTooltip,
    required this.copiedSnackText,
  });

  final String keyPrefix;
  final IconData icon;
  final String label;
  final String value;
  final String copyTooltip;
  final String copiedSnackText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  key: Key('$keyPrefix.label'),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  key: Key('$keyPrefix.value'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('$keyPrefix.copy'),
            tooltip: copyTooltip,
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              await Clipboard.setData(ClipboardData(text: value));
              messenger?.showSnackBar(
                SnackBar(
                  content: Text(copiedSnackText),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(
              Icons.copy_rounded,
              color: AppColors.primaryDark,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
