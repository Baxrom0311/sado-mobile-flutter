import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/local/preferences.dart';
import '../../data/models/subscription_plan.dart';
import '../../data/models/subscription_plan_labels.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/speech_bubble.dart';
import 'widgets/payment_method_sheet.dart';

/// Detail / receipt-style screen for a single [PaymentOrder].
///
/// Reachable from the billing-history screen by tapping any row.
/// Renders the full receipt — amount, plan, provider, state, every
/// known timestamp — and offers a "Resume payment" CTA for orders
/// that are still pending so a user that closed the browser tab
/// before finishing checkout can pick up where they left off without
/// re-entering plan-picker flow.
///
/// State machine the screen needs to handle:
///
///  * `loading`        → branded shimmer skeleton, no Material spinner.
///  * `error`          → [ErrorState] with retry that re-invalidates.
///  * `data == null`   → friendly "no longer available" empty state
///                       that bounces back to the history list.
///  * `data != null`   → full layout with header, fact list and CTA.
///
/// All copy is sourced from `app_*.arb` — there are no hardcoded
/// user-facing strings.
class PaymentOrderDetailScreen extends ConsumerWidget {
  const PaymentOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final orderAsync = ref.watch(paymentOrderProvider(orderId));
    final locale = ref.watch(localeProvider).languageCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.paymentOrderDetailTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/subscription/history'),
        ),
        actions: [
          IconButton(
            key: const Key('order.refresh'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l.subscriptionHistoryRefresh,
            onPressed: () =>
                ref.invalidate(paymentOrderProvider(orderId)),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(paymentOrderProvider(orderId));
            await ref.read(paymentOrderProvider(orderId).future);
          },
          child: orderAsync.when(
            loading: () => const _OrderDetailLoading(),
            error: (_, __) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ErrorState(
                  key: const Key('order.error'),
                  title: l.paymentOrderDetailErrorTitle,
                  body: l.paymentOrderDetailErrorBody,
                  retryLabel: l.paymentOrderDetailErrorRetry,
                  onRetry: () =>
                      ref.invalidate(paymentOrderProvider(orderId)),
                ),
              ],
            ),
            data: (order) {
              if (order == null) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    EmptyState(
                      key: const Key('order.notfound'),
                      title: l.paymentOrderDetailNotFoundTitle,
                      body: l.paymentOrderDetailNotFoundBody,
                      ctaLabel: l.paymentOrderDetailNotFoundCta,
                      ctaIcon: Icons.history_rounded,
                      onCta: () => context.canPop()
                          ? context.pop()
                          : context.go('/subscription/history'),
                    ),
                  ],
                );
              }
              return _OrderDetailBody(
                key: const Key('order.body'),
                order: order,
                locale: locale,
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton — branded shimmer, never a default spinner.
// ---------------------------------------------------------------------------
class _OrderDetailLoading extends StatelessWidget {
  const _OrderDetailLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: const [
        ShimmerCard(height: 168),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 220),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 96),
        SizedBox(height: AppSpacing.lg),
        Center(child: ParrotMascot(mood: ParrotMood.idle, size: 96)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Loaded body — header card, fact list, hint card, CTA section.
// ---------------------------------------------------------------------------
class _OrderDetailBody extends ConsumerWidget {
  const _OrderDetailBody({
    super.key,
    required this.order,
    required this.locale,
  });

  final PaymentOrder order;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: [
        _OrderHeaderCard(
          key: const Key('order.header'),
          order: order,
          locale: locale,
        ),
        const SizedBox(height: AppSpacing.md),
        _OrderFactsCard(
          key: const Key('order.facts'),
          order: order,
          locale: locale,
          dateUnknownLabel: l.subscriptionHistoryDateUnknown,
          onCopyId: () async {
            await Clipboard.setData(ClipboardData(text: order.id));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.paymentOrderDetailCopyId)),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _OrderHintCard(
          key: const Key('order.hint'),
          order: order,
        ),
        const SizedBox(height: AppSpacing.lg),
        _OrderCtaSection(
          key: const Key('order.cta'),
          order: order,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header card — large amount, plan, provider badge, state pill.
// ---------------------------------------------------------------------------
class _OrderHeaderCard extends StatelessWidget {
  const _OrderHeaderCard({
    super.key,
    required this.order,
    required this.locale,
  });

  final PaymentOrder order;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final visuals = _stateVisuals(order.state);
    final headerCopy = _headerCopy(l, order.state);
    final amount = NumberFormat.decimalPattern(locale).format(order.amountUzs);
    final planName = SubscriptionPlanLabels.name(l, order.planCode);
    final providerLabel = _providerLabel(l, order.provider);

    return PremiumCard(
      shadowColor: visuals.color.withValues(alpha: 0.18),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: visuals.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(visuals.icon, color: visuals.color, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  headerCopy,
                  key: const Key('order.header.title'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  l.subscriptionHistoryAmountLabel(amount),
                  key: const Key('order.header.amount'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ProviderBadge(provider: order.provider, label: providerLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            planName,
            key: const Key('order.header.plan'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0);
  }
}

class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge({required this.provider, required this.label});

  final String provider;
  final String label;

  @override
  Widget build(BuildContext context) {
    final visuals = _providerVisuals(provider);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: visuals.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visuals.icon, color: visuals.color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: visuals.color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fact card — receipt-style ordered list of plan / provider / state /
// timestamps / order id.
// ---------------------------------------------------------------------------
class _OrderFactsCard extends StatelessWidget {
  const _OrderFactsCard({
    super.key,
    required this.order,
    required this.locale,
    required this.dateUnknownLabel,
    required this.onCopyId,
  });

  final PaymentOrder order;
  final String locale;
  final String dateUnknownLabel;
  final VoidCallback onCopyId;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final amount = NumberFormat.decimalPattern(locale).format(order.amountUzs);
    final planName = SubscriptionPlanLabels.name(l, order.planCode);
    final providerLabel = _providerLabel(l, order.provider);
    final stateLabel = _stateLabel(l, order.state);
    final stateVisuals = _stateVisuals(order.state);

    final rows = <Widget>[
      _FactRow(
        keyValue: const Key('order.fact.amount'),
        label: l.paymentOrderDetailAmountLabel,
        value: l.subscriptionHistoryAmountLabel(amount),
      ),
      const _FactDivider(),
      _FactRow(
        keyValue: const Key('order.fact.plan'),
        label: l.paymentOrderDetailPlanLabel,
        value: planName,
      ),
      const _FactDivider(),
      _FactRow(
        keyValue: const Key('order.fact.provider'),
        label: l.paymentOrderDetailProviderLabel,
        value: providerLabel,
      ),
      const _FactDivider(),
      _FactRow(
        keyValue: const Key('order.fact.state'),
        label: l.paymentOrderDetailStateLabel,
        valueWidget: _StateChipInline(
          label: stateLabel,
          color: stateVisuals.color,
          icon: stateVisuals.icon,
        ),
      ),
      const _FactDivider(),
      _FactRow(
        keyValue: const Key('order.fact.created'),
        label: l.paymentOrderDetailCreatedAt,
        value: _formatDate(order.createdAt),
      ),
    ];

    if (order.paidAt != null) {
      rows
        ..add(const _FactDivider())
        ..add(_FactRow(
          keyValue: const Key('order.fact.paid'),
          label: l.paymentOrderDetailPaidAt,
          value: _formatDate(order.paidAt!),
        ));
    }
    if (order.cancelledAt != null) {
      rows
        ..add(const _FactDivider())
        ..add(_FactRow(
          keyValue: const Key('order.fact.cancelled'),
          label: l.paymentOrderDetailCancelledAt,
          value: _formatDate(order.cancelledAt!),
        ));
    }
    if (order.updatedAt != null &&
        order.paidAt == null &&
        order.cancelledAt == null) {
      // Surface `updated_at` only when it adds information beyond the
      // creation timestamp — pending rows benefit from it most.
      rows
        ..add(const _FactDivider())
        ..add(_FactRow(
          keyValue: const Key('order.fact.updated'),
          label: l.paymentOrderDetailUpdatedAt,
          value: _formatDate(order.updatedAt!),
        ));
    }

    rows
      ..add(const _FactDivider())
      ..add(_FactRow(
        keyValue: const Key('order.fact.id'),
        label: l.paymentOrderDetailOrderIdLabel,
        value: order.id,
        trailing: IconButton(
          key: const Key('order.fact.id.copy'),
          tooltip: l.paymentOrderDetailCopyId,
          icon: const Icon(
            Icons.copy_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
          onPressed: onCopyId,
        ),
      ));

    return PremiumCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(children: rows),
    );
  }

  String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return dateUnknownLabel;
    final dt = date.toLocal();
    try {
      return DateFormat.yMMMd(locale).add_Hm().format(dt);
    } catch (_) {
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    }
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.trailing,
    this.keyValue,
  }) : assert(value != null || valueWidget != null);

  final String label;
  final String? value;
  final Widget? valueWidget;
  final Widget? trailing;
  final Key? keyValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: keyValue,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: valueWidget ??
                Text(
                  value!,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _FactDivider extends StatelessWidget {
  const _FactDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.border,
    );
  }
}

class _StateChipInline extends StatelessWidget {
  const _StateChipInline({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hint card — friendly mascot + advisory message tied to the order
// state. Helps the user understand what to do next without a wall of
// chrome.
// ---------------------------------------------------------------------------
class _OrderHintCard extends StatelessWidget {
  const _OrderHintCard({super.key, required this.order});

  final PaymentOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final hint = switch (order.state) {
      'paid' => l.paymentOrderDetailReceiptHint,
      'cancelled' => l.paymentOrderDetailCancelledHint,
      'created' || 'pending' => l.paymentOrderDetailPendingHint,
      _ => l.paymentOrderDetailUnknownHint,
    };
    final mood = switch (order.state) {
      'paid' => ParrotMood.happy,
      'cancelled' => ParrotMood.sad,
      'created' || 'pending' => ParrotMood.talking,
      _ => ParrotMood.idle,
    };

    return PremiumCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ParrotMascot(mood: mood, size: 56),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SpeechBubble(text: hint),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CTA section — "Resume payment" for pending orders, otherwise a
// passive "Back to history" button so the screen always closes the
// loop.
// ---------------------------------------------------------------------------
class _OrderCtaSection extends ConsumerWidget {
  const _OrderCtaSection({super.key, required this.order});

  final PaymentOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    if (order.isPending) {
      return PremiumButton(
        key: const Key('order.cta.resume'),
        label: l.paymentOrderDetailResumeCta,
        icon: Icons.replay_rounded,
        onPressed: () async {
          final plan = _planForCode(order.planCode);
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => PaymentMethodSheet(
              plan: plan,
              planDisplayName:
                  SubscriptionPlanLabels.name(l, order.planCode),
            ),
          );
          if (!context.mounted) return;
          ref.invalidate(paymentOrderProvider(order.id));
          ref.invalidate(paymentOrdersFirstPageProvider);
        },
      );
    }
    return PremiumOutlineButton(
      key: const Key('order.cta.history'),
      label: l.paymentOrderDetailHistoryCta,
      icon: Icons.history_rounded,
      onPressed: () => context.canPop()
          ? context.pop()
          : context.go('/subscription/history'),
    );
  }

  /// Look up the catalogue plan that backs an order. Falls back to the
  /// curated static catalogue (synced with the API rollout slugs) when
  /// the live catalog hasn't been fetched yet — this screen needs to
  /// keep working in the offline / pre-fetch case.
  static SubscriptionPlan _planForCode(String code) {
    final norm = SubscriptionPlanLabels.normalise(code);
    for (final p in _fallbackCatalogue) {
      if (p.id == norm || p.id == code) return p;
    }
    // Defensive: synthesise a placeholder so the sheet still opens.
    return SubscriptionPlan(
      id: code,
      nameUz: code,
      nameRu: code,
      priceUzs: 0,
      priceUsd: 0,
      limits: const SubscriptionLimits(),
      features: const [],
    );
  }

  // Mirrors `BillingApi.fallbackPlans`. Duplicated here so the screen
  // doesn't pull a Dio dependency just to resume an order. The two
  // lists must stay in sync — guarded by a unit test.
  static const List<SubscriptionPlan> _fallbackCatalogue = [
    SubscriptionPlan(
      id: 'free',
      nameUz: 'Bepul',
      nameRu: 'Бесплатно',
      priceUzs: 0,
      priceUsd: 0,
      limits: SubscriptionLimits(
        exercisesPerDay: 3,
        aiAnalysesPerMonth: 5,
        maxChildren: 1,
      ),
      features: ['basic_exercises', 'basic_progress'],
      sortOrder: 0,
    ),
    SubscriptionPlan(
      id: 'parent_pro',
      nameUz: 'Premium',
      nameRu: 'Премиум',
      priceUzs: 39000,
      priceUsd: 3,
      limits: SubscriptionLimits(
        exercisesPerDay: -1,
        aiAnalysesPerMonth: -1,
        maxChildren: 5,
      ),
      features: [
        'all_exercises',
        'full_ai_analysis',
        'detailed_progress',
        'recommendations',
        'export_pdf',
      ],
      sortOrder: 10,
    ),
    SubscriptionPlan(
      id: 'logoped_pro',
      nameUz: 'Logoped',
      nameRu: 'Логопед',
      priceUzs: 149000,
      priceUsd: 12,
      limits: SubscriptionLimits(
        exercisesPerDay: -1,
        aiAnalysesPerMonth: -1,
        maxChildren: -1,
        maxPatients: 50,
      ),
      features: [
        'patient_management',
        'assign_exercises',
        'therapy_goals',
        'screening_battery',
        'referral_pdf',
        'analytics',
      ],
      sortOrder: 20,
    ),
    SubscriptionPlan(
      id: 'clinic',
      nameUz: 'Klinika',
      nameRu: 'Клиника',
      priceUzs: 0,
      priceUsd: 0,
      limits: SubscriptionLimits(
        exercisesPerDay: -1,
        aiAnalysesPerMonth: -1,
        maxChildren: -1,
        maxPatients: -1,
        maxUsers: 10,
      ),
      features: [
        'tenant_admin',
        'group_screening',
        'all_logoped_features',
        'reports',
      ],
      sortOrder: 30,
    ),
  ];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _headerCopy(L l, String state) {
  return switch (state) {
    'paid' => l.paymentOrderDetailHeaderPaid,
    'cancelled' => l.paymentOrderDetailHeaderCancelled,
    'pending' => l.paymentOrderDetailHeaderPending,
    'created' => l.paymentOrderDetailHeaderCreated,
    _ => l.paymentOrderDetailHeaderUnknown,
  };
}

String _providerLabel(L l, String provider) {
  return switch (provider) {
    'payme' => l.subscriptionHistoryProviderPayme,
    'click' => l.subscriptionHistoryProviderClick,
    _ => l.subscriptionHistoryProviderUnknown,
  };
}

String _stateLabel(L l, String state) {
  return switch (state) {
    'paid' => l.subscriptionHistoryStatePaid,
    'pending' => l.subscriptionHistoryStatePending,
    'created' => l.subscriptionHistoryStateCreated,
    'cancelled' => l.subscriptionHistoryStateCancelled,
    _ => l.subscriptionHistoryStateUnknown,
  };
}

class _Visuals {
  const _Visuals({required this.color, required this.icon});
  final Color color;
  final IconData icon;
}

_Visuals _stateVisuals(String state) {
  return switch (state) {
    'paid' => const _Visuals(
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
      ),
    'cancelled' => const _Visuals(
        color: AppColors.danger,
        icon: Icons.cancel_rounded,
      ),
    'created' || 'pending' => const _Visuals(
        color: AppColors.warning,
        icon: Icons.schedule_rounded,
      ),
    _ => const _Visuals(
        color: AppColors.textMuted,
        icon: Icons.help_outline_rounded,
      ),
  };
}

_Visuals _providerVisuals(String provider) {
  return switch (provider) {
    'payme' => const _Visuals(
        color: Color(0xFF00D7B5),
        icon: Icons.account_balance_wallet_rounded,
      ),
    'click' => const _Visuals(
        color: Color(0xFF1F8FFF),
        icon: Icons.bolt_rounded,
      ),
    _ => const _Visuals(
        color: AppColors.textMuted,
        icon: Icons.payment_rounded,
      ),
  };
}
