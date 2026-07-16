import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/local/preferences.dart';
import '../../data/models/subscription_plan.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/shimmer_loaders.dart';
import 'widgets/payment_history_row.dart';

/// Billing history surface — `GET /billing/orders`.
///
/// Renders the user's past payment attempts in reverse-chronological
/// order with paid / pending / cancelled badges and the originating
/// provider (Payme or Click). Empty, loading, error and "feature not
/// deployed yet" states are all handled explicitly so the screen
/// always feels deliberate.
///
/// The screen is reachable from `/subscription/status` (Manage
/// subscription → Billing history). It deliberately does not show
/// receipts or PDFs yet — those depend on a future API surface — but
/// the row layout already leaves room for a "View receipt" trailing
/// affordance to land in a follow-up without restructuring the screen.
class SubscriptionHistoryScreen extends ConsumerWidget {
  const SubscriptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final ordersAsync = ref.watch(paymentOrdersFirstPageProvider);
    final locale = ref.watch(localeProvider).languageCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.subscriptionHistoryTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/subscription/status'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        actions: [
          IconButton(
            key: const Key('history.refresh'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l.subscriptionHistoryRefresh,
            onPressed: () =>
                ref.invalidate(paymentOrdersFirstPageProvider),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(paymentOrdersFirstPageProvider);
            // Wait for the next page to resolve so the spinner stays
            // up until fresh data is available.
            await ref.read(paymentOrdersFirstPageProvider.future);
          },
          color: AppColors.primary,
          child: ordersAsync.when(
            loading: () => const _HistoryLoading(),
            error: (_, __) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ErrorState(
                  title: l.subscriptionHistoryErrorTitle,
                  body: l.subscriptionHistoryErrorBody,
                  retryLabel: l.subscriptionHistoryErrorRetry,
                  onRetry: () =>
                      ref.invalidate(paymentOrdersFirstPageProvider),
                ),
              ],
            ),
            data: (page) {
              if (page.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    EmptyState(
                      key: const Key('history.empty'),
                      title: l.subscriptionHistoryEmptyTitle,
                      body: l.subscriptionHistoryEmptyBody,
                      ctaLabel: l.subscriptionHistoryEmptyCta,
                      ctaIcon: Icons.workspace_premium_rounded,
                      onCta: () => context.go('/subscription'),
                    ),
                  ],
                );
              }
              return _HistoryList(
                key: const Key('history.list'),
                orders: page.items,
                locale: locale,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    super.key,
    required this.orders,
    required this.locale,
  });

  final List<PaymentOrder> orders;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return ListView.builder(
      // +2 to make room for a header tile and bottom padding sentinel
      itemCount: orders.length + 1,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _HistoryHeader(
            key: const Key('history.header'),
            count: orders.length,
            label: l.subscriptionHistorySectionLabel(orders.length),
          );
        }
        final order = orders[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: PaymentHistoryRow(
            key: ValueKey('history.row.${order.id}'),
            order: order,
            locale: locale,
            onTap: () => context.go('/subscription/orders/${order.id}'),
          ),
        );
      },
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({super.key, required this.count, required this.label});
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.heroGradient,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            // Friendly numeric badge — UI mirrors the streak/badges chips.
            NumberFormat.decimalPattern().format(count),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.primary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0);
  }
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: const [
        // Reuses the same shimmer card style every other list screen
        // ships so the loading state feels native to the app rather
        // than a one-off.
        ShimmerCard(height: 88),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 88),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 88),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 88),
        SizedBox(height: AppSpacing.lg),
        // Subtle mascot at the bottom keeps the screen feeling alive
        // even mid-skeleton — matches the timeline / progress loaders.
        Center(child: ParrotMascot(mood: ParrotMood.idle, size: 96)),
      ],
    );
  }
}
