import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/domain/timeline/timeline_event.dart';

Assessment _assessment({
  required String id,
  required DateTime createdAt,
  String childId = 'child-1',
  double? score,
  String? risk,
}) =>
    Assessment(
      id: id,
      childId: childId,
      status: 'completed',
      score: score,
      overallRisk: risk,
      createdAt: createdAt,
    );

ExerciseAssignment _assignment({
  required String id,
  required DateTime createdAt,
  ExerciseAssignmentStatus status = ExerciseAssignmentStatus.completed,
  DateTime? completedAt,
  String childId = 'child-1',
  String exerciseId = 'ex-1',
  Exercise? exercise,
}) =>
    ExerciseAssignment(
      id: id,
      childId: childId,
      exerciseId: exerciseId,
      status: status,
      completedAt: completedAt ?? createdAt,
      createdAt: createdAt,
      updatedAt: completedAt ?? createdAt,
      exercise: exercise,
    );

Exercise _exercise({String title = 'S sound drill'}) => Exercise(
      id: 'ex-1',
      title: title,
      description: '',
      category: 'articulation',
      ageGroup: '4-5',
      difficulty: 'easy',
      language: 'uz',
      durationMinutes: 5,
      isActive: true,
    );

void main() {
  group('TimelineEvent — IDs and timestamps', () {
    test('AssessmentEvent prefixes id with assessment: and uses createdAt',
        () {
      final created = DateTime.utc(2025, 6, 1, 12);
      final e = AssessmentEvent(
        assessment: _assessment(id: 'a1', createdAt: created),
      );
      expect(e.id, 'assessment:a1');
      expect(e.occurredAt, created);
      expect(e.childId, 'child-1');
    });

    test(
        'AssignmentCompletedEvent uses completedAt when present, '
        'falls back to updatedAt otherwise', () {
      final created = DateTime.utc(2025, 6, 1, 12);
      final completed = DateTime.utc(2025, 6, 2, 9);
      final withCompleted = AssignmentCompletedEvent(
        assignment: _assignment(
          id: 'asg1',
          createdAt: created,
          completedAt: completed,
        ),
      );
      expect(withCompleted.id, 'assignment:asg1');
      expect(withCompleted.occurredAt, completed);

      // Manually construct an assignment whose completedAt is null —
      // simulates a server-side data glitch — and confirm the event
      // falls back to updatedAt instead of throwing.
      final fallback = AssignmentCompletedEvent(
        assignment: ExerciseAssignment(
          id: 'asg2',
          childId: 'child-1',
          exerciseId: 'ex-1',
          status: ExerciseAssignmentStatus.completed,
          completedAt: null,
          createdAt: created,
          updatedAt: created,
        ),
      );
      expect(fallback.occurredAt, created);
    });

    test('AssessmentEvent surfaces score and risk passthroughs', () {
      final e = AssessmentEvent(
        assessment: _assessment(
          id: 'a1',
          createdAt: DateTime.utc(2025, 1, 1),
          score: 0.83,
          risk: 'green',
        ),
      );
      expect(e.score, closeTo(0.83, 0.0001));
      expect(e.risk, 'green');
    });

    test('AssignmentCompletedEvent exposes exerciseTitle when embedded',
        () {
      final e = AssignmentCompletedEvent(
        assignment: _assignment(
          id: 'asg1',
          createdAt: DateTime.utc(2025, 1, 1),
          exercise: _exercise(title: 'R drill'),
        ),
      );
      expect(e.exerciseTitle, 'R drill');

      final none = AssignmentCompletedEvent(
        assignment: _assignment(id: 'asg2', createdAt: DateTime.utc(2025, 1, 2)),
      );
      expect(none.exerciseTitle, isNull);
    });
  });

  group('buildTimeline — projection rules', () {
    test('drops pending and in-progress assignments', () {
      final pending = _assignment(
        id: 'p1',
        createdAt: DateTime.utc(2025, 6, 1),
        status: ExerciseAssignmentStatus.pending,
      );
      final inProgress = _assignment(
        id: 'p2',
        createdAt: DateTime.utc(2025, 6, 2),
        status: ExerciseAssignmentStatus.inProgress,
      );
      final completed = _assignment(
        id: 'p3',
        createdAt: DateTime.utc(2025, 6, 3),
        status: ExerciseAssignmentStatus.completed,
      );

      final feed = buildTimeline(
        assessments: const [],
        assignments: [pending, inProgress, completed],
      );
      expect(feed, hasLength(1));
      expect(feed.single.id, 'assignment:p3');
    });

    test('returns events sorted newest-first across both sources', () {
      final feed = buildTimeline(
        assessments: [
          _assessment(id: 'a1', createdAt: DateTime.utc(2025, 6, 1)),
          _assessment(id: 'a2', createdAt: DateTime.utc(2025, 6, 5)),
        ],
        assignments: [
          _assignment(id: 'h1', createdAt: DateTime.utc(2025, 6, 3)),
          _assignment(id: 'h2', createdAt: DateTime.utc(2025, 6, 6)),
        ],
      );
      expect(
        feed.map((e) => e.id).toList(),
        ['assignment:h2', 'assessment:a2', 'assignment:h1', 'assessment:a1'],
      );
    });

    test('on identical timestamps the assessment wins the tie-break', () {
      final ts = DateTime.utc(2025, 6, 5, 10);
      final feed = buildTimeline(
        assessments: [_assessment(id: 'a1', createdAt: ts)],
        assignments: [_assignment(id: 'h1', createdAt: ts)],
      );
      expect(feed.first, isA<AssessmentEvent>());
      expect(feed.last, isA<AssignmentCompletedEvent>());
    });

    test('returns an empty list when both sources are empty', () {
      expect(buildTimeline(assessments: const [], assignments: const []),
          isEmpty);
    });
  });
}
