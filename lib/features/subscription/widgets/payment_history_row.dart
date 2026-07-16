import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../../core/theme.dart';
import '../../../data/models/subscription_plan.dart';
import '../../../data/models/subscription_plan_labels.dart';
import '../../../widgets/premium_card.dart';

/// One row in the billing-history list.
///
/// Layout:
///
///   ┌────────────────────────────────────────────┐
///   │  ┌──┐  Plan name              Amount   ▶   │
///   │  │P │  Provider · Date        State        │
///   │  └──┘                                      │
///   └────────────────────────────────────────────┘
///
/// The leading badge is colour-coded by provider (Payme = teal, Click =
/// blue) so users can scan the list. The trailing state chip uses the
/// SADO design tokens — `success` for paid, `warning` for pending,
/// `danger` for cancelled — matching every other status badge in the
/// app for consistency.
class PaymentHistoryRow extends StatelessWidget {
  const PaymentHistoryRow({
    super.key,
    required this.order,
    required this.locale,
    this.onTap,
  });

  final PaymentOrder order;

  /// `uz` or `ru`. Drives date / number formatting only. Plan names
  /// rely on the subscription catalogue and fall back to the raw plan
  /// code if a localised name isn't yet known.
  final String locale;

  /// Optional tap handler for a future "view receipt" affordance. We
  /// keep the row tappable today (no-op default) so the visual hint —
  /// the trailing chevron — stays meaningful when the affordance lands.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final providerCfg = _providerVisuals(order.provider);
    final stateCfg = _stateVisuals(order.state);
    final dateLine = _dateLine(l);
    final amountLine = l.subscriptionHistoryAmountLabel(
      NumberFormat.decimalPattern(locale).format(order.amountUzs),
    );

    return PremiumCard(
      key: ValueKey('history.card.${order.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: providerCfg.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              providerCfg.icon,
              color: providerCfg.color,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        SubscriptionPlanLabels.name(l, order.planCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      amountLine,
                      key: const Key('history.row.amount'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_providerLabel(l, order.provider)} · $dateLine',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StateChip(
                      label: _stateLabel(l, order.state),
                      color: stateCfg.color,
                      icon: stateCfg.icon,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateLine(L l) {
    final dt = order.displayedAt.toLocal();
    if (dt.millisecondsSinceEpoch == 0) {
      return l.subscriptionHistoryDateUnknown;
    }
    // `yMMMd` produces locale-aware formats: "13 Iyun 2026" in uz,
    // "13 июн. 2026 г." in ru. Falls back to a plain ISO short date
    // if the locale data isn't initialised in the test environment.
    try {
      return DateFormat.yMMMd(locale).format(dt);
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(dt);
    }
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

  _ProviderVisuals _providerVisuals(String provider) {
    return switch (provider) {
      'payme' => const _ProviderVisuals(
          color: Color(0xFF00D7B5),
          icon: Icons.account_balance_wallet_rounded,
        ),
      'click' => const _ProviderVisuals(
          color: Color(0xFF1F8FFF),
          icon: Icons.bolt_rounded,
        ),
      _ => const _ProviderVisuals(
          color: AppColors.textMuted,
          icon: Icons.payment_rounded,
        ),
    };
  }

  _StateVisuals _stateVisuals(String state) {
    return switch (state) {
      'paid' => const _StateVisuals(
          color: AppColors.success,
          icon: Icons.check_circle_rounded,
        ),
      'cancelled' => const _StateVisuals(
          color: AppColors.danger,
          icon: Icons.cancel_rounded,
        ),
      'created' || 'pending' => const _StateVisuals(
          color: AppColors.warning,
          icon: Icons.schedule_rounded,
        ),
      _ => const _StateVisuals(
          color: AppColors.textMuted,
          icon: Icons.help_outline_rounded,
        ),
    };
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
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
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderVisuals {
  const _ProviderVisuals({required this.color, required this.icon});
  final Color color;
  final IconData icon;
}

class _StateVisuals {
  const _StateVisuals({required this.color, required this.icon});
  final Color color;
  final IconData icon;
}
