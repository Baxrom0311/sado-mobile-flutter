import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/messenger.dart';
import '../../core/theme.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/practice_plan.dart';
import '../../providers/practice_plans_provider.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/speech_bubble.dart';

/// Detail screen for one practice plan. Renders the plan header,
/// progress ring, focus areas, an actionable items list (with +1 rep /
/// finished / skip controls) and a history list of completed items.
class PracticePlanDetailScreen extends ConsumerWidget {
  const PracticePlanDetailScreen({super.key, required this.planId});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final state = ref.watch(practicePlanDetailProvider(planId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.practicePlansTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/practice-plans');
            }
          },
        ),
      ),
      body: state.when(
        loading: () => const _DetailLoading(),
        error: (_, __) => ErrorState(
          title: l.practicePlansErrorTitle,
          body: l.practicePlansErrorBody,
          retryLabel: l.practicePlansRetry,
          onRetry: () => ref.invalidate(practicePlanDetailProvider(planId)),
        ),
        data: (plan) => _DetailBody(plan: plan),
      ),
    );
  }
}

class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        ShimmerCard(height: 180),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 96),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 96),
      ],
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.plan});
  final PracticePlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final pending = plan.pendingItems;
    final history = plan.historyItems;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async =>
          ref.invalidate(practicePlanDetailProvider(plan.id)),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _PlanHeader(plan: plan),
          if (plan.focusAreas != null && plan.focusAreas!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _FocusAreas(areas: plan.focusAreas!),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (pending.isNotEmpty) ...[
            _SectionHeader(label: l.practicePlanItemsHeader),
            const SizedBox(height: AppSpacing.sm),
            for (final item in pending) ...[
              _ItemTile(
                key: ValueKey('plan.item.pending.${item.id}'),
                planId: plan.id,
                item: item,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          _SectionHeader(label: l.practicePlanHistoryHeader),
          const SizedBox(height: AppSpacing.sm),
          if (history.isEmpty)
            PremiumCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const ParrotMascot(mood: ParrotMood.idle, size: 44),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l.practicePlanItemEmptyHistory,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final item in history) ...[
              _ItemTile(
                key: ValueKey('plan.item.done.${item.id}'),
                planId: plan.id,
                item: item,
                muted: true,
              ),
              const SizedBox(height: AppSpacing.sm),
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

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.plan});
  final PracticePlan plan;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final tone = _toneFor(plan.status);

    String? rangeLabel;
    if (plan.startDate != null && plan.endDate != null) {
      rangeLabel = l.practicePlanDateRange(
        DateFormat.yMMMd().format(plan.startDate!),
        DateFormat.yMMMd().format(plan.endDate!),
      );
    } else if (plan.completedAt != null) {
      rangeLabel = l.practicePlanCompletedOn(
        DateFormat.yMMMd().format(plan.completedAt!),
      );
    } else if (plan.startDate != null) {
      rangeLabel = l.practicePlanStartedOn(
        DateFormat.yMMMd().format(plan.startDate!),
      );
    }

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SpeechBubble(
                text: plan.title,
                tailDirection: SpeechBubbleTail.down,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const ParrotMascot(mood: ParrotMood.happy, size: 64),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.practicePlanProgressTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: LinearProgressIndicator(
                        value: plan.progress,
                        minHeight: 12,
                        backgroundColor: AppColors.surfaceMuted,
                        valueColor: AlwaysStoppedAnimation(tone),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.practicePlansItemsCount(
                        plan.completedItemCount,
                        plan.itemCount,
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (plan.summary != null && plan.summary!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              plan.summary!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (rangeLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    rangeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(
          begin: 0.06,
          end: 0,
          duration: 280.ms,
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

class _FocusAreas extends StatelessWidget {
  const _FocusAreas({required this.areas});
  final List<String> areas;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: l.practicePlanFocusHeader),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final code in areas)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tertiary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ItemTile extends ConsumerStatefulWidget {
  const _ItemTile({
    super.key,
    required this.planId,
    required this.item,
    this.muted = false,
  });

  final String planId;
  final PracticePlanItem item;
  final bool muted;

  @override
  ConsumerState<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends ConsumerState<_ItemTile> {
  bool _busy = false;

  Future<void> _record() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await recordPlanItemProgress(
        ref,
        planId: widget.planId,
        itemId: widget.item.id,
        increment: 1,
      );
      if (!mounted) return;
      Haptics.light();
      showAppSnackBar(
        SnackBar(
          content: Text(L.of(context)!.practicePlanItemRecordedToast),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        SnackBar(
          content: Text(L.of(context)!.practicePlanItemFailedToast),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await patchPlanItem(
        ref,
        planId: widget.planId,
        itemId: widget.item.id,
        status: PracticePlanItemStatus.skipped,
      );
      if (!mounted) return;
      showAppSnackBar(
        SnackBar(
          content: Text(L.of(context)!.practicePlanItemSkippedToast),
          backgroundColor: AppColors.textSecondary,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        SnackBar(
          content: Text(L.of(context)!.practicePlanItemFailedToast),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openExercise() {
    // The interactive lesson route requires a child id. We don't carry
    // it on the item, so the safest universal action is to push the
    // exercise detail page where the user can pick the child if needed.
    GoRouter.of(context).push('/exercises/${widget.item.exerciseId}');
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final item = widget.item;
    final title = item.exerciseTitle ?? l.practicePlanItemNoExerciseTitle;
    final tone = _itemTone(item);

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Opacity(
        opacity: widget.muted ? 0.78 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    item.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.task_alt_rounded,
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
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.practicePlanItemProgressLabel(
                          item.completedCount,
                          item.targetCount,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.priority == 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l.practicePlanItemPriority,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: item.progress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceMuted,
                valueColor: AlwaysStoppedAnimation(tone),
              ),
            ),
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.notes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
            if (!widget.muted && item.isActionable) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: item.completedCount + 1 >= item.targetCount
                          ? l.practicePlanItemFinishedCta
                          : l.practicePlanItemDoneCta,
                      icon: Icons.check_rounded,
                      color: AppColors.primary,
                      busy: _busy,
                      onPressed: _record,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _IconAction(
                    icon: Icons.open_in_new_rounded,
                    color: AppColors.tertiary,
                    tooltip: l.practicePlanOpenExerciseCta,
                    onPressed: _busy ? null : _openExercise,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _IconAction(
                    icon: Icons.skip_next_rounded,
                    color: AppColors.textSecondary,
                    tooltip: l.practicePlanItemSkipCta,
                    onPressed: _busy ? null : _skip,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _itemTone(PracticePlanItem item) {
    switch (item.status) {
      case PracticePlanItemStatus.completed:
        return AppColors.primary;
      case PracticePlanItemStatus.inProgress:
        return AppColors.secondary;
      case PracticePlanItemStatus.skipped:
        return AppColors.textSecondary;
      case PracticePlanItemStatus.pending:
        return AppColors.sky;
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: IconButton(
          icon: Icon(icon, color: color, size: 22),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
