import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../features/assignments/assignments_screen.dart' show AssignmentTile;
import '../providers/providers.dart';
import 'parrot_mascot.dart';
import 'premium_card.dart';
import 'shimmer_loaders.dart';

/// Premium "Therapist's homework" section, scoped to a single child.
///
/// Lives between the speech profile entry and recent-assessments list
/// on the child detail screen. Surfaces up to [_visibleLimit] actionable
/// assignments (pending / in_progress) for the supplied child via
/// [childAssignmentsProvider]. When more than [_visibleLimit] are open
/// or any completed assignments exist, a "See all" link routes to the
/// dedicated assignments screen so the parent can review history.
///
/// Render rules — kept defensive so the section never breaks the page:
///
///   * **Loading** — three stacked shimmer cards (no Material default
///     spinner) so the surrounding column doesn't reflow.
///   * **Error** — silently hides the section. The screen-level offline
///     banner already informs the parent that data may be stale; we
///     don't want to surface a second error UI on top of it.
///   * **Empty (no actionable assignments)** — compact friendly empty
///     state with the parrot mascot and the "Vazifalar yo'q" copy from
///     the existing localizations. Hidden entirely when the bucket is
///     empty *and* the API didn't return any completed history either,
///     so a brand-new child doesn't see a redundant "no homework" card
///     above the recent-assessments list.
///   * **Loaded** — section header + up to three [AssignmentTile]s
///     (the existing tile reused so the visual language matches the
///     dedicated screen) + optional "See all" link.
class ChildAssignmentsCard extends ConsumerWidget {
  const ChildAssignmentsCard({super.key, required this.childId});

  final String childId;

  /// Maximum number of pending assignment tiles to render inline. The
  /// rest are reachable via the "See all" link. Kept private so callers
  /// can't accidentally explode the embedded list.
  static const int _visibleLimit = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final state = ref.watch(childAssignmentsProvider(childId));

    return state.when(
      loading: () => const _Loading(),
      // Errors silently hide — see class doc for rationale.
      error: (_, __) => const SizedBox.shrink(),
      data: (res) {
        final actionable =
            res.items.where((a) => a.isActionable).toList(growable: false);
        final hasHistory =
            res.items.any((a) => !a.isActionable);

        // Hide entirely when the bucket has nothing to show *and* the API
        // didn't return any completed assignments either. A brand-new
        // child shouldn't see a redundant "no homework" card.
        if (actionable.isEmpty && !hasHistory) {
          return const SizedBox.shrink();
        }

        if (actionable.isEmpty) {
          return _Empty(childId: childId);
        }

        final visible = actionable.take(_visibleLimit).toList(growable: false);
        final overflow = actionable.length - visible.length;

        return Column(
          key: const ValueKey('childAssignments.section'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              label: l.assignmentsOnChildTitle,
              countLabel: actionable.length > 1
                  ? actionable.length.toString()
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final assignment in visible) ...[
              AssignmentTile(
                key: ValueKey(
                  'childAssignments.tile.${assignment.id}',
                ),
                assignment: assignment,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (overflow > 0 || hasHistory) ...[
              const SizedBox(height: 4),
              _SeeAllLink(label: l.assignmentsOnChildSeeAll),
            ],
          ],
        ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.04);
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Semantics(
      label: l.assignmentsLoading,
      child: const Column(
        key: ValueKey('childAssignments.loading'),
        children: [
          ShimmerCard(height: 96),
          SizedBox(height: AppSpacing.sm),
          ShimmerCard(height: 96),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return PremiumCard(
      key: const ValueKey('childAssignments.empty'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: () => context.go('/assignments'),
      child: Row(
        children: [
          const ParrotMascot(mood: ParrotMood.idle, size: 56),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.assignmentsOnChildTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.assignmentsOnChildEmpty,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.label, this.countLabel});
  final String label;
  final String? countLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (countLabel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                countLabel!,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeeAllLink extends StatelessWidget {
  const _SeeAllLink({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton.icon(
        key: const ValueKey('childAssignments.seeAll'),
        onPressed: () => context.go('/assignments'),
        icon: const Icon(
          Icons.arrow_forward_rounded,
          size: 18,
          color: AppColors.primary,
        ),
        label: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
