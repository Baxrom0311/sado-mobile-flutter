import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';

/// One row of the parent-facing "Recent activity" feed.
///
/// The feed is a light projection of two heterogeneous wire types
/// ([Assessment] and [ExerciseAssignment]) onto a single, glanceable
/// timeline. Each event carries the timestamp it should be sorted on
/// (the moment the parent will care about) and a kind discriminator the
/// UI uses to pick an icon, colour and CTA target.
///
/// The class is deliberately a *thin* wrapper rather than a duplicate
/// of every wire field — the screen reads through to the embedded
/// [assessment] / [assignment] when it needs more detail.
@immutable
sealed class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.occurredAt,
    required this.childId,
  });

  /// Stable identifier the UI can key on. Prefixed with the kind to
  /// avoid collisions between assessment IDs and assignment IDs in the
  /// (extremely unlikely) case the backend reuses UUIDs across tables.
  final String id;

  /// The moment this event happened, in UTC. Used for sorting and for
  /// the relative-time label rendered by [formatRelativeDate].
  final DateTime occurredAt;

  /// Child this event belongs to. Lets the UI render the child's name /
  /// avatar next to the row without an extra fetch.
  final String childId;
}

/// A completed assessment — i.e. the parent recorded their child once
/// and the API analysed the audio. Carries the score so the row can
/// render a colour-coded chip.
class AssessmentEvent extends TimelineEvent {
  AssessmentEvent({required this.assessment})
      : super(
          id: 'assessment:${assessment.id}',
          occurredAt: assessment.createdAt,
          childId: assessment.childId,
        );

  final Assessment assessment;

  double? get score => assessment.score;
  String? get risk => assessment.overallRisk;
}

/// A completed homework assignment. We deliberately exclude pending /
/// in-progress assignments from the timeline — those belong on the
/// dedicated "homework" screen, not on the "look at the lovely things
/// your child did" feed.
class AssignmentCompletedEvent extends TimelineEvent {
  AssignmentCompletedEvent({required this.assignment})
      : super(
          id: 'assignment:${assignment.id}',
          // ExerciseAssignment is only emitted when status == completed
          // so completedAt should always be present, but we fall back
          // to updatedAt defensively so a server-side data glitch never
          // crashes the screen.
          occurredAt: assignment.completedAt ?? assignment.updatedAt,
          childId: assignment.childId,
        );

  final ExerciseAssignment assignment;

  /// Therapist self-assessment score on a 0–100 scale (server semantics).
  double? get score => assignment.score;

  /// Title of the underlying exercise, when the wire payload included it.
  String? get exerciseTitle => assignment.exercise?.title;
}

/// Pure aggregator that fuses the two wire sources into a single,
/// chronologically-sorted feed. Public so widget and provider tests can
/// assert the projection without standing up a Riverpod container.
///
/// Rules:
///
/// * Pending / in-progress assignments are dropped — those are
///   actionable, not historical.
/// * Events are sorted **newest first**.
/// * When two events share the exact same timestamp, the more
///   information-dense event (assessment > assignment) wins the tie,
///   so a "double-tap" never hides a richer row.
List<TimelineEvent> buildTimeline({
  required Iterable<Assessment> assessments,
  required Iterable<ExerciseAssignment> assignments,
}) {
  final events = <TimelineEvent>[
    for (final a in assessments) AssessmentEvent(assessment: a),
    for (final a in assignments)
      if (a.status == ExerciseAssignmentStatus.completed)
        AssignmentCompletedEvent(assignment: a),
  ];

  events.sort((a, b) {
    final cmp = b.occurredAt.compareTo(a.occurredAt);
    if (cmp != 0) return cmp;
    // Tie-break: assessments are richer, surface them first.
    final aRank = a is AssessmentEvent ? 0 : 1;
    final bRank = b is AssessmentEvent ? 0 : 1;
    return aRank.compareTo(bRank);
  });

  return events;
}
