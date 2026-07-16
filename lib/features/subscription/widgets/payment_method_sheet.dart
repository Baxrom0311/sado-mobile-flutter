import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../../core/theme.dart';
import '../../../data/api/billing_api.dart';
import '../../../data/models/subscription_plan.dart';
import '../../../data/services/external_url_launcher.dart';
import '../../../providers/subscription_provider.dart';
import '../../../widgets/parrot_mascot.dart';
import '../../../widgets/shimmer_loaders.dart';
import '../../../widgets/speech_bubble.dart';

/// Internal state machine for the payment-method sheet.
///
/// We model the four user-visible states explicitly instead of relying
/// on a nullable `CheckoutSession?` so the build method stays a clean
/// pattern match — every state has a single, well-defined visual.
sealed class _CheckoutState {
  const _CheckoutState();
}

class _Picking extends _CheckoutState {
  const _Picking();
}

class _Loading extends _CheckoutState {
  const _Loading(this.provider);
  final String provider;
}

class _Ready extends _CheckoutState {
  const _Ready(this.session);
  final CheckoutSession session;
}

class _Failed extends _CheckoutState {
  const _Failed(this.provider);
  final String provider;
}

/// Bottom sheet that walks the user through choosing a payment provider
/// (Payme or Click), kicking off a `POST /billing/orders` call, and
/// handing the resulting checkout URL to the device's external browser
/// via `url_launcher`. When the launch is unavailable (no browser, OS
/// refusal, malformed URL) we fall back to copying the link to the
/// clipboard so the user is never blocked.
///
/// Why both launch and clipboard?
///
///  * Primary path: a one-tap "Open in browser" CTA that hands the URL
///    to Chrome / Safari / the user's default browser via
///    `url_launcher`. This is the premium experience the upgrade flow
///    needs to feel native.
///  * Fallback: when `launchUrl` returns `false` (no browser present,
///    parental controls, malformed URL) we automatically copy the
///    link to the clipboard and surface the existing
///    `subscriptionCheckoutOpenFailed` snackbar so the user can paste
///    it into any browser they have. The "Copy link" secondary CTA
///    stays visible for users who explicitly want the link on their
///    clipboard (e.g. to message it to themselves on another device).
///
/// Graceful degradation:
///
///  * `BillingNotImplemented` (HTTP 404 / 405 / 501) → we collapse the
///    sheet back to a calm "Coming soon" surface that mirrors the
///    `SubscriptionScreen._ComingSoonSheet`. Free users still see the
///    same friendly mascot UX.
///  * Any other DioException → an inline error state with a Retry
///    button.
///
/// All copy goes through `app_*.arb` — there are no hardcoded
/// user-facing strings here.
class PaymentMethodSheet extends ConsumerStatefulWidget {
  const PaymentMethodSheet({
    super.key,
    required this.plan,
    required this.planDisplayName,
    @visibleForTesting this.checkoutOverride,
    @visibleForTesting this.clipboardOverride,
    @visibleForTesting this.launcherOverride,
  });

  /// Plan the user is upgrading to. Drives the API call and the
  /// "Selected plan: …" caption shown above the provider list.
  final SubscriptionPlan plan;

  /// Localised plan name passed in by the parent so the sheet doesn't
  /// have to re-do the locale-aware lookup itself.
  final String planDisplayName;

  /// Allows widget tests to swap in a deterministic fake without
  /// going through Riverpod overrides for the API. Production code
  /// always passes `null` and falls back to the provider tree.
  @visibleForTesting
  final Future<CheckoutSession> Function(
      {required String planCode, required String provider})? checkoutOverride;

  /// Test seam for clipboard interaction. Defaults to
  /// [Clipboard.setData] in production.
  @visibleForTesting
  final Future<void> Function(String url)? clipboardOverride;

  /// Test seam for browser launch. Defaults to
  /// [ExternalUrlLauncher.production] in production. When the override
  /// returns `false` the sheet falls back to the clipboard path and
  /// surfaces the localized "open failed" snackbar so the user is
  /// never stranded.
  @visibleForTesting
  final Future<bool> Function(String url)? launcherOverride;

  /// Shows the sheet as a modal bottom sheet. Returns the
  /// [CheckoutSession] the user successfully started, or `null` if the
  /// user dismissed the sheet without completing.
  static Future<CheckoutSession?> show(
    BuildContext context, {
    required SubscriptionPlan plan,
    required String planDisplayName,
  }) {
    return showModalBottomSheet<CheckoutSession>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (ctx) => PaymentMethodSheet(
        plan: plan,
        planDisplayName: planDisplayName,
      ),
    );
  }

  @override
  ConsumerState<PaymentMethodSheet> createState() =>
      _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends ConsumerState<PaymentMethodSheet> {
  _CheckoutState _state = const _Picking();
  bool _comingSoon = false;

  Future<void> _select(String provider) async {
    if (!mounted) return;
    setState(() => _state = _Loading(provider));
    try {
      final api = widget.checkoutOverride;
      final CheckoutSession session;
      if (api != null) {
        session = await api(
          planCode: widget.plan.id,
          provider: provider,
        );
      } else {
        session = await ref.read(billingApiProvider).createCheckout(
              planCode: widget.plan.id,
              provider: provider,
            );
      }
      if (!mounted) return;
      setState(() => _state = _Ready(session));
    } on BillingNotImplemented {
      if (!mounted) return;
      setState(() {
        _state = const _Picking();
        _comingSoon = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _Failed(provider));
    }
  }

  Future<void> _copyUrl(BuildContext context, String url) async {
    // Capture the messenger and localizations BEFORE awaiting so we
    // never reach for `context` after the gap. The analyzer flags any
    // post-await context use, which is correct: if the sheet has been
    // dismissed during the await we'd otherwise read stale state.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final copiedMessage = L.of(context)!.subscriptionCheckoutUrlCopied;
    final clip = widget.clipboardOverride;
    if (clip != null) {
      await clip(url);
    } else {
      await Clipboard.setData(ClipboardData(text: url));
    }
    if (!mounted) return;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(copiedMessage),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Primary "Open in browser" path. Hands the URL to the platform
  /// browser; on failure we automatically fall back to the clipboard
  /// path so the user is never blocked from completing checkout.
  ///
  /// Returns the captured fallback message (if any) so callers can
  /// extend behaviour later — currently the snackbar fires inline.
  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = L.of(context)!;
    final openFailedMessage = l.subscriptionCheckoutOpenFailed;
    final copiedMessage = l.subscriptionCheckoutUrlCopied;

    final launch = widget.launcherOverride ??
        (String u) => ExternalUrlLauncher.production.open(u);
    final clip = widget.clipboardOverride;

    final ok = await launch(url);
    if (ok) {
      if (!mounted) return;
      // Brief confirmation so the sheet doesn't feel inert after the
      // browser handoff. We do not auto-dismiss the sheet — Payme/Click
      // checkout completes on the web, then a server webhook flips the
      // subscription record. Closing the sheet on launch would give the
      // illusion of completion before the user has actually paid.
      messenger?.showSnackBar(
        SnackBar(
          content: Text(copiedMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Launch refused (no browser, parental lock, malformed URL).
    // Auto-fallback: copy to clipboard + tell the user we did so.
    if (clip != null) {
      await clip(url);
    } else {
      await Clipboard.setData(ClipboardData(text: url));
    }
    if (!mounted) return;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(openFailedMessage),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return SafeArea(
      top: false,
      child: AnimatedSize(
        duration: 220.ms,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: _comingSoon
              ? _ComingSoonView(
                  key: const Key('payment.comingSoon'),
                  onClose: () => Navigator.of(context).maybePop(),
                )
              : _buildState(context, l),
        ),
      ),
    );
  }

  Widget _buildState(BuildContext context, L l) {
    return switch (_state) {
      _Picking() => _PickerView(
          key: const Key('payment.picker'),
          planName: widget.planDisplayName,
          onPaymeTap: () => _select(PaymentProvider.payme),
          onClickTap: () => _select(PaymentProvider.click),
          onClose: () => Navigator.of(context).maybePop(),
        ),
      _Loading(:final provider) => _LoadingView(
          key: const Key('payment.loading'),
          provider: provider,
        ),
      _Ready(:final session) => _ReadyView(
          key: const Key('payment.ready'),
          session: session,
          planName: widget.planDisplayName,
          onOpen: () => _openUrl(context, session.url),
          onCopy: () => _copyUrl(context, session.url),
          onClose: () =>
              Navigator.of(context).maybePop<CheckoutSession>(session),
        ),
      _Failed(:final provider) => _ErrorView(
          key: const Key('payment.error'),
          onRetry: () => _select(provider),
          onClose: () => Navigator.of(context).maybePop(),
        ),
    };
  }
}

// =====================================================================
// Sub-views
// =====================================================================

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.borderStrong,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}

class _PickerView extends StatelessWidget {
  const _PickerView({
    super.key,
    required this.planName,
    required this.onPaymeTap,
    required this.onClickTap,
    required this.onClose,
  });

  final String planName;
  final VoidCallback onPaymeTap;
  final VoidCallback onClickTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetGrabber(),
        const SizedBox(height: AppSpacing.md),
        const Center(child: ParrotMascot(mood: ParrotMood.happy, size: 88)),
        const SizedBox(height: AppSpacing.md),
        Text(
          l.subscriptionCheckoutMethodTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l.subscriptionCheckoutMethodBody,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            l.subscriptionCheckoutSelectedPlan(planName),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ProviderCard(
          key: const Key('payment.picker.payme'),
          name: l.subscriptionCheckoutPaymeName,
          tagline: l.subscriptionCheckoutPaymeTagline,
          color: const Color(0xFF00D7B5),
          icon: Icons.account_balance_wallet_rounded,
          onTap: onPaymeTap,
        ),
        const SizedBox(height: AppSpacing.sm),
        _ProviderCard(
          key: const Key('payment.picker.click'),
          name: l.subscriptionCheckoutClickName,
          tagline: l.subscriptionCheckoutClickTagline,
          color: const Color(0xFF1F8FFF),
          icon: Icons.bolt_rounded,
          onTap: onClickTap,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textMuted,
              size: 14,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l.subscriptionCheckoutSecureNote,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          key: const Key('payment.picker.close'),
          onPressed: onClose,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            l.subscriptionCheckoutClose,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.04, end: 0);
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    super.key,
    required this.name,
    required this.tagline,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String name;
  final String tagline;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: AppShadow.soft(color, opacity: 0.08),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tagline,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
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

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key, required this.provider});
  final String provider;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetGrabber(),
        const SizedBox(height: AppSpacing.md),
        const Center(
          child: ParrotMascot(mood: ParrotMood.listening, size: 80),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: SpeechBubble(
            text: l.subscriptionCheckoutPreparing,
            tailDirection: SpeechBubbleTail.up,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const ShimmerCard(height: 56),
        const SizedBox(height: AppSpacing.sm),
        const ShimmerCard(height: 56),
        const SizedBox(height: AppSpacing.lg),
        // Make the chosen-provider hint accessible to the test hook.
        Semantics(
          label: 'preparing-$provider',
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    super.key,
    required this.session,
    required this.planName,
    required this.onOpen,
    required this.onCopy,
    required this.onClose,
  });

  final CheckoutSession session;
  final String planName;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetGrabber(),
        const SizedBox(height: AppSpacing.md),
        const Center(child: ParrotMascot(mood: ParrotMood.happy, size: 88)),
        const SizedBox(height: AppSpacing.md),
        Text(
          l.subscriptionCheckoutReadyTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l.subscriptionCheckoutReadyBody,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            l.subscriptionCheckoutSelectedPlan(planName),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.link_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  session.url,
                  key: const Key('payment.ready.url'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton.icon(
          key: const Key('payment.ready.open'),
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(l.subscriptionCheckoutOpenInBrowser),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('payment.ready.copy'),
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: Text(l.subscriptionCheckoutCopyUrl),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          key: const Key('payment.ready.close'),
          onPressed: onClose,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            l.subscriptionCheckoutClose,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.04, end: 0);
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    super.key,
    required this.onRetry,
    required this.onClose,
  });

  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetGrabber(),
        const SizedBox(height: AppSpacing.md),
        const Center(child: ParrotMascot(mood: ParrotMood.sad, size: 88)),
        const SizedBox(height: AppSpacing.md),
        Text(
          l.subscriptionCheckoutErrorTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l.subscriptionCheckoutErrorBody,
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
          key: const Key('payment.error.retry'),
          onPressed: onRetry,
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
            l.subscriptionCheckoutRetry,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          key: const Key('payment.error.close'),
          onPressed: onClose,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            l.subscriptionCheckoutClose,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.04, end: 0);
  }
}

class _ComingSoonView extends StatelessWidget {
  const _ComingSoonView({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetGrabber(),
        const SizedBox(height: AppSpacing.md),
        const Center(
          child: ParrotMascot(mood: ParrotMood.listening, size: 88),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l.subscriptionComingSoonTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l.subscriptionComingSoonBody,
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
          key: const Key('payment.comingSoon.close'),
          onPressed: onClose,
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
            l.subscriptionComingSoonClose,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.04, end: 0);
  }
}
