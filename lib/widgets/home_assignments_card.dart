import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../data/models/models.dart';
import '../providers/providers.dart';
import 'premium_card.dart';

/// Home-screen card surfacing therapist-assigned exercises ("homework").
///
/// Renders nothing when:
///   * the provider is still loading (the rest of the home screen has its
///     own shimmer cards — we don't want to compete with them),
///   * the provider errored (the card should silently disappear, not
///     surface a second error UI on top of the offline banner),
///   * no actionable assignments exist.
///
/// When at least one assignment is actionable, surfaces a punchy callout
/// with the parrot mascot, a localized count copy and a "Open" CTA that
/// pushes onto `/assignments`.
class HomeAssignmentsCard extends ConsumerWidget {
  const HomeAssignmentsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final state = ref.watch(myAssignmentsProvider);
    final actionable = state.maybeWhen<List<ExerciseAssignment>>(
      data: (r) => r.items.where((a) => a.isActionable).toList(),
      orElse: () => const [],
    );
    if (actionable.isEmpty) return const SizedBox.shrink();

    final overdue = actionable.where((a) => a.isOverdue).length;
    final body = actionable.length == 1
        ? l.assignmentsHomeBodyOne
        : l.assignmentsHomeBody(actionable.length);

    return PremiumCard(
      key: const ValueKey('home.assignmentsCard'),
      onTap: () => context.go('/assignments'),
      gradient: AppColors.sunsetGradient,
      shadowColor: AppColors.secondary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.assignment_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.assignmentsHomeTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (overdue > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      l.assignmentsOverdueChip,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    ).animate(delay: 220.ms).fadeIn().slideY(begin: 0.1);
  }
}
