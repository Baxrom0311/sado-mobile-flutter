import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../providers/subscription_provider.dart';
import 'parrot_mascot.dart';
import 'premium_card.dart';

/// Home-screen upsell card that drives free users into the Premium
/// upgrade surface.
///
/// Renders nothing until the user's subscription has actually resolved —
/// we deliberately avoid flashing an upsell in during the initial
/// loading window because that feels nag-y, and we never want to push
/// Premium to users who are already on a paid tier. The widget falls
/// back to "hidden" silently on any provider error so it never competes
/// with the offline banner or other error states.
class HomePremiumCard extends ConsumerWidget {
  const HomePremiumCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final subAsync = ref.watch(mySubscriptionProvider);

    // Only show for *confirmed* free users — never during loading,
    // never on a hard error (we don't want to nag during a network
    // hiccup either).
    final showCard = subAsync.maybeWhen(
      data: (sub) => sub.planId == 'free',
      orElse: () => false,
    );
    if (!showCard) return const SizedBox.shrink();

    return PremiumCard(
      key: const ValueKey('home.premiumCard'),
      onTap: () => context.go('/subscription'),
      gradient: AppColors.heroGradient,
      shadowColor: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const ParrotMascot(mood: ParrotMood.happy, size: 64),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l.subscriptionMenuRow,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.subscriptionHomeCardTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.subscriptionHomeCardBody,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    ).animate(delay: 240.ms).fadeIn(duration: 320.ms).slideY(begin: 0.08);
  }
}
