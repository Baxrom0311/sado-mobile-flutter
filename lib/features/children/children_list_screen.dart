import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../core/utils/relative_time.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/child_avatar.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/shimmer_loaders.dart';

class ChildrenListScreen extends ConsumerWidget {
  const ChildrenListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final children = ref.watch(childrenProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.children),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/profile'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        onPressed: () => context.go('/children/add'),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.addChild,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: children.when(
        data: (res) => res.items.isEmpty
            ? EmptyState(
                title: l.noChildren,
                body: l.noChildrenBody,
                ctaLabel: l.addChild,
                ctaIcon: Icons.add_rounded,
                onCta: () => context.go('/children/add'),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(childrenProvider);
                  ref.invalidate(assessmentsProvider(null));
                },
                color: AppColors.primary,
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: res.items.length + (res.fromCache ? 1 : 0),
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (_, i) {
                    if (res.fromCache && i == 0) {
                      return OfflineBanner(message: l.offlineCached);
                    }
                    final idx = res.fromCache ? i - 1 : i;
                    return _ChildTile(child: res.items[idx])
                        .animate(delay: (idx * 60).ms)
                        .fadeIn()
                        .slideY(begin: 0.1);
                  },
                ),
              ),
        loading: () => const ShimmerList(),
        error: (e, _) => ErrorState(
          onRetry: () => ref.invalidate(childrenProvider),
        ),
      ),
    );
  }
}

class _ChildTile extends ConsumerWidget {
  const _ChildTile({required this.child});
  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    // Watch the global assessments list (cheap because the provider is
    // already cached and shared across the app) and pick the most recent
    // one matching this child. Avoids issuing N requests for N children.
    final assessmentsAsync = ref.watch(assessmentsProvider(null));
    final latest = assessmentsAsync.maybeWhen<Assessment?>(
      data: (res) => _latestForChild(res.items, child.id),
      orElse: () => null,
    );

    return PremiumCard(
      shadowColor: ChildAvatar.paletteOf(child.name, gender: child.gender).last,
      onTap: () {
        ref.read(selectedChildIdProvider.notifier).state = child.id;
        context.go('/children/${child.id}');
      },
      child: Row(
        children: [
          ChildAvatar(
            name: child.name,
            gender: child.gender,
            size: ChildAvatarSize.md,
            heroTag: 'child-avatar-${child.id}',
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_age(child.birthDate)} ${l.yearsOld} • ${_formatBirth(child.birthDate)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                _LastAssessmentLine(latest: latest),
              ],
            ),
          ),
          IconButton(
            tooltip: l.editChild,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.textSecondary, size: 20),
            onPressed: () => context.go('/children/${child.id}/edit'),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted),
        ],
      ),
    );
  }

  int _age(DateTime birth) {
    final n = DateTime.now();
    int a = n.year - birth.year;
    if (n.month < birth.month ||
        (n.month == birth.month && n.day < birth.day)) {
      a--;
    }
    return a;
  }

  String _formatBirth(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

/// Picks the most recently created assessment for [childId], or null when
/// none exist. Exposed at the top level so it can be unit-tested without
/// constructing the widget tree.
Assessment? _latestForChild(List<Assessment> items, String childId) {
  Assessment? best;
  for (final a in items) {
    if (a.childId != childId) continue;
    if (best == null || a.createdAt.isAfter(best.createdAt)) {
      best = a;
    }
  }
  return best;
}

class _LastAssessmentLine extends StatelessWidget {
  const _LastAssessmentLine({required this.latest});
  final Assessment? latest;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    if (latest == null) {
      return Row(
        children: [
          Icon(Icons.schedule_rounded,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            l.noAssessmentsYetShort,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    final relative = formatRelativeDate(l, latest!.createdAt);
    return Row(
      children: [
        RiskBadge.fromApi(
          risk: latest!.overallRisk,
          size: RiskBadgeSize.small,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            '${l.lastAssessmentLabel} • $relative',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
