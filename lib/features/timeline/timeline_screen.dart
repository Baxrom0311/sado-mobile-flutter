import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../core/utils/relative_time.dart';
import '../../data/models/models.dart';
import '../../domain/timeline/timeline_event.dart';
import '../../providers/providers.dart';
import '../../widgets/child_avatar.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/shimmer_loaders.dart';

/// Composite provider that joins assessments + completed assignments
/// across every child in the parent's account into a single, sorted
/// timeline. Watches the underlying providers so it auto-refreshes
/// when either source invalidates.
///
/// Returns a [TimelineResult] which carries an `fromCache` flag — true
/// when *either* of the underlying providers fell back to the offline
/// snapshot. The screen surfaces that as a single banner.
final recentActivityProvider = Provider<AsyncValue<TimelineResult>>((ref) {
  final assessments = ref.watch(assessmentsProvider(null));
  final assignments = ref.watch(myAssignmentsProvider);
  final children = ref.watch(childrenProvider);

  // Children are nice-to-have for the row subtitle; if their fetch
  // fails we still render the timeline using the child id as fallback.
  final childIndex = <String, Child>{};
  children.whenData((res) {
    for (final c in res.items) {
      childIndex[c.id] = c;
    }
  });

  // Pessimistic combine: any source still loading → loading.
  if (assessments.isLoading || assignments.isLoading) {
    return const AsyncValue.loading();
  }
  // If either source errored *and* we have no cached fallback, surface
  // the error. Otherwise fall through with whatever we managed to load.
  if (assessments.hasError && !assessments.hasValue) {
    return AsyncValue.error(
        assessments.error!, assessments.stackTrace ?? StackTrace.empty);
  }
  if (assignments.hasError && !assignments.hasValue) {
    return AsyncValue.error(
        assignments.error!, assignments.stackTrace ?? StackTrace.empty);
  }

  final assessmentsList = assessments.requireValue;
  final assignmentsList = assignments.requireValue;
  final events = buildTimeline(
    assessments: assessmentsList.items,
    assignments: assignmentsList.items,
  );
  final fromCache =
      assessmentsList.fromCache || assignmentsList.fromCache;
  return AsyncValue.data(
    TimelineResult(events: events, childIndex: childIndex, fromCache: fromCache),
  );
});

/// Materialised view passed to the screen. Mutable-free so
/// `Provider.select` works cleanly when we add finer-grained rebuilds
/// later.
@immutable
class TimelineResult {
  const TimelineResult({
    required this.events,
    required this.childIndex,
    required this.fromCache,
  });

  final List<TimelineEvent> events;
  final Map<String, Child> childIndex;
  final bool fromCache;

  bool get isEmpty => events.isEmpty;
}

/// Parent-facing chronological feed of "things your child accomplished
/// recently" — assessments completed and homework checked off, joined
/// across every child the parent owns and sorted newest-first.
///
/// Render rules (every state custom, never Material defaults):
///
/// * **Loading** — three stacked shimmer cards.
/// * **Error** — branded [ErrorState] with a retry that invalidates
///   the underlying source providers (not just this composite).
/// * **Empty** — parrot mascot + friendly copy + CTA pointing to the
///   exercises list so the next assessment is one tap away.
/// * **Loaded** — grouped sections ("This week" / "Earlier") with one
///   tile per event. Tapping an assessment row deep-links to the
///   results screen; tapping a homework row deep-links to that
///   assignment's exercise.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final state = ref.watch(recentActivityProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.timelineTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
      ),
      body: state.when(
        loading: () => const _TimelineLoading(),
        error: (_, __) => ErrorState(
          title: l.timelineErrorTitle,
          body: l.timelineErrorBody,
          retryLabel: l.timelineRetry,
          onRetry: () {
            ref.invalidate(assessmentsProvider(null));
            ref.invalidate(myAssignmentsProvider);
            ref.invalidate(childrenProvider);
          },
        ),
        data: (res) {
          if (res.isEmpty) {
            return _TimelineEmpty(
              onCta: () => context.go('/exercises'),
            );
          }
          return _TimelineBody(
            result: res,
            onRefresh: () async {
              ref.invalidate(assessmentsProvider(null));
              ref.invalidate(myAssignmentsProvider);
              ref.invalidate(childrenProvider);
            },
          );
        },
      ),
    );
  }
}

class _TimelineLoading extends StatelessWidget {
  const _TimelineLoading();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Semantics(
      label: l.timelineLoading,
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

class _TimelineEmpty extends StatelessWidget {
  const _TimelineEmpty({required this.onCta});

  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: EmptyState(
          title: l.timelineEmptyTitle,
          body: l.timelineEmptyBody,
          ctaLabel: l.timelineEmptyCta,
          onCta: onCta,
          mood: ParrotMood.happy,
        ),
      ),
    );
  }
}

class _TimelineBody extends StatelessWidget {
  const _TimelineBody({required this.result, required this.onRefresh});

  final TimelineResult result;
  final Future<void> Function() onRefresh;

  static const Duration _thisWeekWindow = Duration(days: 7);

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final now = DateTime.now();
    final cutoff = now.subtract(_thisWeekWindow);

    final thisWeek = <TimelineEvent>[];
    final earlier = <TimelineEvent>[];
    for (final e in result.events) {
      if (e.occurredAt.isAfter(cutoff)) {
        thisWeek.add(e);
      } else {
        earlier.add(e);
      }
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (result.fromCache)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: OfflineBanner(message: l.offlineCached),
            ),
          if (thisWeek.isNotEmpty) ...[
            _SectionHeader(label: l.timelineSectionThisWeek),
            const SizedBox(height: AppSpacing.sm),
            ..._renderEvents(thisWeek, result.childIndex, baseDelay: 0),
            if (earlier.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          ],
          if (earlier.isNotEmpty) ...[
            _SectionHeader(label: l.timelineSectionEarlier),
            const SizedBox(height: AppSpacing.sm),
            ..._renderEvents(earlier, result.childIndex,
                baseDelay: thisWeek.length),
          ],
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  List<Widget> _renderEvents(
    List<TimelineEvent> events,
    Map<String, Child> childIndex, {
    required int baseDelay,
  }) {
    final out = <Widget>[];
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      final child = childIndex[e.childId];
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: TimelineTile(event: e, child: child)
              .animate(delay: ((baseDelay + i) * 40).ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
        ),
      );
    }
    return out;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Single tile in the timeline. Public so widget tests can mount it
/// in isolation without needing a provider container.
class TimelineTile extends StatelessWidget {
  const TimelineTile({super.key, required this.event, this.child});

  final TimelineEvent event;
  final Child? child;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final relative = formatRelativeDate(l, event.occurredAt);
    final childName = child?.name ?? l.timelineUnknownChild;

    return PremiumCard(
      key: ValueKey('timeline.tile.${event.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _handleTap(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChildAvatar(name: childName, size: ChildAvatarSize.sm),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_iconFor(event), size: 16, color: _colorFor(event)),
                    const SizedBox(width: 6),
                    Text(
                      _labelFor(l, event),
                      style: TextStyle(
                        color: _colorFor(event),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      relative,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitleFor(l, event, childName),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                _ScoreChip(event: event),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context) {
    switch (event) {
      case AssessmentEvent(:final assessment):
        context.go('/assessment/results/${assessment.id}');
      case AssignmentCompletedEvent(:final assignment):
        context.go('/exercises/${assignment.exerciseId}');
    }
  }

  IconData _iconFor(TimelineEvent e) => switch (e) {
        AssessmentEvent _ => Icons.mic_rounded,
        AssignmentCompletedEvent _ => Icons.check_circle_rounded,
      };

  Color _colorFor(TimelineEvent e) => switch (e) {
        AssessmentEvent _ => AppColors.primary,
        AssignmentCompletedEvent _ => AppColors.success,
      };

  String _labelFor(L l, TimelineEvent e) => switch (e) {
        AssessmentEvent _ => l.timelineAssessmentLabel,
        AssignmentCompletedEvent _ => l.timelineAssignmentLabel,
      };

  String _subtitleFor(L l, TimelineEvent e, String childName) => switch (e) {
        AssessmentEvent _ => l.timelineAssessmentSubtitle(childName),
        AssignmentCompletedEvent(:final exerciseTitle) =>
          (exerciseTitle == null || exerciseTitle.isEmpty)
              ? l.timelineAssignmentSubtitle(childName)
              : l.timelineAssignmentSubtitleNamed(childName, exerciseTitle),
      };
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.event});

  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return switch (event) {
      AssessmentEvent(:final score, :final risk) => Row(
          children: [
            if (score != null)
              _Pill(
                label: l.timelineAssessmentScore((score * 100).round()),
                color: _scoreColor(score),
              )
            else
              _Pill(
                label: l.timelineAssessmentNoScore,
                color: AppColors.textMuted,
              ),
            if (risk != null) ...[
              const SizedBox(width: AppSpacing.xs),
              RiskBadge.fromApi(risk: risk, size: RiskBadgeSize.small),
            ],
          ],
        ),
      AssignmentCompletedEvent(:final score) => score != null
          // Therapist score is on a 0–100 scale already.
          ? _Pill(
              label: l.timelineAssessmentScore(score.round()),
              color: _scoreColor(score / 100),
            )
          : const SizedBox.shrink(),
    };
  }

  Color _scoreColor(double normalised) {
    if (normalised >= 0.75) return AppColors.success;
    if (normalised >= 0.5) return AppColors.warning;
    return AppColors.danger;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
