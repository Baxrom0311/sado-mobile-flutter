import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/models/practice_plan.dart';
import '../../providers/practice_plans_provider.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/shimmer_loaders.dart';

/// Parent-facing list of practice plans across every child. Loading
/// uses shimmer cards (never the Material default). Errors render the
/// branded [ErrorState] with retry. Empty data shows the parrot mascot
/// with a friendly CTA pushing the parent to start an assessment so AI
/// can build them a plan.
class PracticePlansScreen extends ConsumerWidget {
  const PracticePlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final state = ref.watch(myPracticePlansProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.practicePlansTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: state.when(
        loading: () => const _PlansLoading(),
        error: (_, __) => ErrorState(
          title: l.practicePlansErrorTitle,
          body: l.practicePlansErrorBody,
          retryLabel: l.practicePlansRetry,
          onRetry: () => ref.invalidate(myPracticePlansProvider),
        ),
        data: (res) {
          if (res.isEmpty) {
            return _PlansEmpty(
              onCta: () => context.go('/children'),
            );
          }
          return _PlansBody(
            plans: res.items,
            fromCache: res.fromCache,
          );
        },
      ),
    );
  }
}

class _PlansLoading extends StatelessWidget {
  const _PlansLoading();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Semantics(
      label: l.practicePlansLoading,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          ShimmerCard(height: 140),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 140),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 140),
        ],
      ),
    );
  }
}

class _PlansEmpty extends StatelessWidget {
  const _PlansEmpty({required this.onCta});
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: EmptyState(
          title: l.practicePlansEmptyTitle,
          body: l.practicePlansEmptyBody,
          ctaLabel: l.practicePlansEmptyCta,
          ctaIcon: Icons.mic_rounded,
          onCta: onCta,
        ),
      ),
    );
  }
}

class _PlansBody extends ConsumerWidget {
  const _PlansBody({required this.plans, required this.fromCache});

  final List<PracticePlan> plans;
  final bool fromCache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final active = plans
        .where((p) => p.status == PracticePlanStatus.active)
        .toList();
    final draft = plans
        .where((p) => p.status == PracticePlanStatus.draft)
        .toList();
    final completed = plans
        .where((p) => p.status == PracticePlanStatus.completed)
        .toList();
    final archived = plans
        .where((p) => p.status == PracticePlanStatus.archived)
        .toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(myPracticePlansProvider),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (fromCache) ...[
            OfflineBanner(message: l.offlineCached),
            const SizedBox(height: AppSpacing.md),
          ],
          if (active.isNotEmpty) ...[
            _SectionHeader(label: l.practicePlansActiveHeader),
            const SizedBox(height: AppSpacing.sm),
            for (final p in active) ...[
              PracticePlanTile(
                key: ValueKey('plan.active.${p.id}'),
                plan: p,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          if (draft.isNotEmpty) ...[
            _SectionHeader(label: l.practicePlansDraftHeader),
            const SizedBox(height: AppSpacing.sm),
            for (final p in draft) ...[
              PracticePlanTile(
                key: ValueKey('plan.draft.${p.id}'),
                plan: p,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          if (completed.isNotEmpty) ...[
            _SectionHeader(label: l.practicePlansCompletedHeader),
            const SizedBox(height: AppSpacing.sm),
            for (final p in completed) ...[
              PracticePlanTile(
                key: ValueKey('plan.done.${p.id}'),
                plan: p,
                muted: true,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          if (archived.isNotEmpty) ...[
            _SectionHeader(label: l.practicePlansArchivedHeader),
            const SizedBox(height: AppSpacing.sm),
            for (final p in archived) ...[
              PracticePlanTile(
                key: ValueKey('plan.archived.${p.id}'),
                plan: p,
                muted: true,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: AppSpacing.sm),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          color: AppColors.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// A single practice-plan card. Surfaces title, status chip, focus
/// areas, the X/Y completed-items progress bar and tap navigation to
/// the detail screen.
class PracticePlanTile extends StatelessWidget {
  const PracticePlanTile({
    super.key,
    required this.plan,
    this.muted = false,
  });

  final PracticePlan plan;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final progress = plan.progress;
    final tone = _toneFor(plan.status);

    return PremiumCard(
      key: ValueKey('plan.tile.${plan.id}'),
      onTap: () => GoRouter.of(context).push('/practice-plans/${plan.id}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Opacity(
        opacity: muted ? 0.78 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.flag_rounded,
                    color: tone,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _StatusChip(
                        status: plan.status,
                        tone: tone,
                      ),
                    ],
                  ),
                ),
                Text(
                  l.practicePlansItemsCount(
                    plan.completedItemCount,
                    plan.itemCount,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (plan.summary != null && plan.summary!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                plan.summary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.surfaceMuted,
                valueColor: AlwaysStoppedAnimation(tone),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.practicePlansItemsLabel(plan.itemCount),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (plan.endDate != null)
                  Text(
                    DateFormat.yMMMd().format(plan.endDate!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 240.ms).slideY(
          begin: 0.05,
          end: 0,
          duration: 240.ms,
          curve: Curves.easeOut,
        );
  }

  Color _toneFor(PracticePlanStatus s) {
    switch (s) {
      case PracticePlanStatus.active:
        return AppColors.primary;
      case PracticePlanStatus.draft:
        return AppColors.sky;
      case PracticePlanStatus.completed:
        return AppColors.tertiary;
      case PracticePlanStatus.archived:
        return AppColors.textSecondary;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.tone});
  final PracticePlanStatus status;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final label = switch (status) {
      PracticePlanStatus.draft => l.practicePlanStatusDraft,
      PracticePlanStatus.active => l.practicePlanStatusActive,
      PracticePlanStatus.completed => l.practicePlanStatusCompleted,
      PracticePlanStatus.archived => l.practicePlanStatusArchived,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: tone,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
