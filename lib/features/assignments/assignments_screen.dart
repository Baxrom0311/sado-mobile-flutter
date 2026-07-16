import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/shimmer_loaders.dart';

/// Parent-facing "homework" screen. Shows every therapist-assigned
/// exercise across all of the parent's children, grouped into a
/// pending bucket (work to do) and a completed history.
///
/// Loading shows shimmer cards (no default [CircularProgressIndicator]).
/// Errors render the branded [BrandedErrorState] with retry. The empty
/// state hosts the parrot mascot and friendly copy. When the data was
/// served from the offline cache, an [OfflineBanner] is rendered above
/// the list so parents understand they may be looking at slightly stale
/// data.
class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final state = ref.watch(myAssignmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.assignmentsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: state.when(
        loading: () => const _AssignmentsLoading(),
        error: (e, _) => ErrorState(
          title: l.assignmentsErrorTitle,
          body: l.assignmentsErrorBody,
          retryLabel: l.assignmentsRetry,
          onRetry: () => ref.invalidate(myAssignmentsProvider),
        ),
        data: (res) {
          if (res.items.isEmpty) {
            return _AssignmentsEmpty();
          }
          return _AssignmentsBody(
            assignments: res.items,
            fromCache: res.fromCache,
          );
        },
      ),
    );
  }
}

class _AssignmentsLoading extends StatelessWidget {
  const _AssignmentsLoading();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Semantics(
      label: l.assignmentsLoading,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          ShimmerCard(height: 96),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 96),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 96),
        ],
      ),
    );
  }
}

class _AssignmentsEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: EmptyState(
          title: l.assignmentsEmptyTitle,
          body: l.assignmentsEmptyBody,
        ),
      ),
    );
  }
}

class _AssignmentsBody extends ConsumerWidget {
  const _AssignmentsBody({
    required this.assignments,
    required this.fromCache,
  });

  final List<ExerciseAssignment> assignments;
  final bool fromCache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final pending = assignments.where((a) => a.isActionable).toList();
    final completed =
        assignments.where((a) => !a.isActionable).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(myAssignmentsProvider),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (fromCache) ...[
            OfflineBanner(message: l.offlineCached),
            const SizedBox(height: AppSpacing.md),
          ],
          if (pending.isNotEmpty) ...[
            _SectionHeader(label: l.assignmentsPendingHeader),
            const SizedBox(height: AppSpacing.sm),
            for (final a in pending) ...[
              AssignmentTile(
                key: ValueKey('assignment.pending.${a.id}'),
                assignment: a,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          if (completed.isNotEmpty) ...[
            _SectionHeader(label: l.assignmentsCompletedHeader),
            const SizedBox(height: AppSpacing.sm),
            for (final a in completed) ...[
              AssignmentTile(
                key: ValueKey('assignment.done.${a.id}'),
                assignment: a,
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

/// Card representation of one [ExerciseAssignment]. Surfaces the
/// embedded exercise title, a status chip (overdue / due today / due in
/// N days), the therapist's notes when present, and a primary CTA that
/// either starts the exercise or marks it complete.
class AssignmentTile extends ConsumerWidget {
  const AssignmentTile({
    super.key,
    required this.assignment,
    this.muted = false,
  });

  final ExerciseAssignment assignment;

  /// When true, the tile renders in a muted "history" style (used in the
  /// completed bucket). Pending assignments use the full premium style.
  final bool muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final exercise = assignment.exercise;
    final title = exercise?.title ??
        // Fall back to the exercise id when the API didn't embed the
        // exercise (older deployments). Better than rendering an empty
        // header.
        assignment.exerciseId;

    final categoryChipColor = _categoryColor(exercise?.category);

    return PremiumCard(
      key: ValueKey('assignment.tile.${assignment.id}'),
      onTap: assignment.isActionable
          ? () => _onTap(context, ref)
          : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Opacity(
        opacity: muted ? 0.78 : 1,
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
                    color: categoryChipColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    _categoryIcon(exercise?.category),
                    color: categoryChipColor,
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
                          fontSize: 15,
                        ),
                      ),
                      if ((exercise?.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          exercise!.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(assignment: assignment),
                if (assignment.status ==
                    ExerciseAssignmentStatus.completed) ...[
                  _CompletedChip(date: assignment.completedAt),
                ],
              ],
            ),
            if ((assignment.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.assignmentsTherapistNotesTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assignment.notes!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (assignment.isActionable) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: PremiumButton(
                      key: ValueKey(
                          'assignment.start.${assignment.id}'),
                      label: l.assignmentsStartCta,
                      icon: Icons.play_arrow_rounded,
                      height: 48,
                      onPressed: () => _onStart(context, ref),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PremiumButton(
                      key: ValueKey(
                          'assignment.complete.${assignment.id}'),
                      label: l.assignmentsCompleteCta,
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      height: 48,
                      onPressed: () => _onComplete(context, ref),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context, WidgetRef ref) {
    if (!assignment.isActionable) return;
    _onStart(context, ref);
  }

  void _onStart(BuildContext context, WidgetRef ref) {
    final exerciseId = assignment.exerciseId;
    final childId = assignment.childId;
    // Let the assignment screen optimistically flip to in_progress in
    // the background so therapists see engagement even if the parent
    // never completes the exercise inside the app. We don't await this
    // — the navigation is the user-visible action, the status flip is
    // purely housekeeping.
    if (assignment.status == ExerciseAssignmentStatus.pending) {
      // Best-effort: swallow errors here. The list will reconcile on
      // its next refresh.
      // ignore: discarded_futures
      patchAssignment(ref, assignment.id, status: 'in_progress')
          .catchError(
        (_) => assignment,
      );
    }
    context.go('/assessment/intro/$childId/$exerciseId');
  }

  Future<void> _onComplete(BuildContext context, WidgetRef ref) async {
    final l = L.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final score = await showModalBottomSheet<double?>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      builder: (sheet) => _ScoreSheet(),
    );
    if (score == null && score != 0) {
      // User dismissed the sheet without confirming.
      return;
    }
    try {
      await completeAssignment(ref, assignment.id, score: score);
      Haptics.success();
      messenger.showSnackBar(SnackBar(
        content: Text(l.assignmentsCompletedToast),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(
        content: Text(l.assignmentsCompleteFailed),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Color _categoryColor(String? category) {
    switch (category) {
      case 'breathing':
        return AppColors.sky;
      case 'fluency':
        return AppColors.primary;
      case 'vocabulary':
        return AppColors.tertiary;
      case 'phonemic_awareness':
        return AppColors.secondary;
      case 'listening':
        return AppColors.tertiary;
      case 'articulation':
      default:
        return AppColors.primary;
    }
  }

  IconData _categoryIcon(String? category) {
    switch (category) {
      case 'breathing':
        return Icons.air_rounded;
      case 'fluency':
        return Icons.timeline_rounded;
      case 'vocabulary':
        return Icons.menu_book_rounded;
      case 'phonemic_awareness':
        return Icons.spellcheck_rounded;
      case 'listening':
        return Icons.hearing_rounded;
      case 'articulation':
      default:
        return Icons.record_voice_over_rounded;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.assignment});
  final ExerciseAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final due = assignment.dueDate;

    Color color;
    String label;
    IconData icon;

    if (assignment.status == ExerciseAssignmentStatus.completed) {
      color = AppColors.success;
      label = l.assignmentsCompletedHeader;
      icon = Icons.check_circle_rounded;
    } else if (assignment.isOverdue) {
      color = AppColors.danger;
      label = l.assignmentsOverdueChip;
      icon = Icons.error_outline_rounded;
    } else if (due == null) {
      color = AppColors.textSecondary;
      label = l.assignmentsDueOpen;
      icon = Icons.event_note_rounded;
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(due.year, due.month, due.day);
      final delta = dueDay.difference(today).inDays;
      icon = Icons.schedule_rounded;
      if (delta == 0) {
        color = AppColors.warning;
        label = l.assignmentsDueTodayChip;
      } else if (delta == 1) {
        color = AppColors.warning;
        label = l.assignmentsDueTomorrowChip;
      } else {
        color = AppColors.textSecondary;
        label = l.assignmentsDueInDays(delta);
      }
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedChip extends StatelessWidget {
  const _CompletedChip({required this.date});
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    final l = L.of(context)!;
    final s = '${date!.day.toString().padLeft(2, '0')}.'
        '${date!.month.toString().padLeft(2, '0')}.${date!.year}';
    return Text(
      l.assignmentsCompletedAt(s),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}

/// Bottom sheet shown when the parent taps "Mark complete". Lets them
/// optionally attach a 0–100 score so therapists can see how confident
/// the parent felt about the recording. Pops with the chosen score
/// (or null when the parent skips the rating).
class _ScoreSheet extends StatefulWidget {
  @override
  State<_ScoreSheet> createState() => _ScoreSheetState();
}

class _ScoreSheetState extends State<_ScoreSheet> {
  double _value = 80;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ParrotMascot(mood: ParrotMood.happy, size: 80),
          const SizedBox(height: AppSpacing.md),
          Text(
            l.assignmentsScoreLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${_value.round()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 40,
              color: AppColors.primary,
            ),
          ),
          Slider(
            value: _value,
            min: 0,
            max: 100,
            divisions: 20,
            label: _value.round().toString(),
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _value = v),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(l.assignmentsCancel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: PremiumButton(
                  key: const ValueKey('assignment.score.save'),
                  label: l.assignmentsScoreSave,
                  icon: Icons.check_rounded,
                  height: 48,
                  onPressed: () =>
                      Navigator.of(context).pop(_value),
                ),
              ),
            ],
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 280.ms)
          .slideY(begin: 0.04, end: 0),
    );
  }
}
