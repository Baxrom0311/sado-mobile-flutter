import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/api/assignments_api.dart';
import 'package:sado_mobile/data/models/models.dart';

/// Captures wire-level details of one Dio request so we can assert on
/// method + path + query + body without standing up a real server.
class _Captured {
  String? method;
  String? path;
  Map<String, dynamic>? query;
  Object? body;
}

Dio _stubDio({
  required _Captured captured,
  required Object response,
  int statusCode = 200,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      captured
        ..method = options.method
        ..path = options.path
        ..query = Map<String, dynamic>.from(options.queryParameters)
        ..body = options.data;
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: statusCode,
        data: response,
      ));
    },
  ));
  return dio;
}

Map<String, dynamic> _assignmentJson({
  String id = 'a-1',
  String childId = 'child-1',
  String exerciseId = 'ex-1',
  String status = 'pending',
  String? dueDate = '2030-01-01T00:00:00Z',
  String? completedAt,
  double? score,
  String? notes,
  Map<String, dynamic>? exercise,
}) =>
    {
      'id': id,
      'child_id': childId,
      'exercise_id': exerciseId,
      'assigned_by_id': 'therapist-1',
      'status': status,
      'due_date': dueDate,
      'completed_at': completedAt,
      'score': score,
      'notes': notes,
      'created_at': '2026-06-10T10:00:00Z',
      'updated_at': '2026-06-10T10:00:00Z',
      if (exercise != null) 'exercise': exercise,
    };

Map<String, dynamic> _exerciseJson({
  String id = 'ex-1',
  String title = 'Mashq',
  String category = 'articulation',
}) =>
    {
      'id': id,
      'title': title,
      'description': 'Tovushni mashq qilamiz',
      'category': category,
      'age_group': '4-5',
      'difficulty': 'easy',
      'language': 'uz',
      'duration_minutes': 5,
      'is_active': true,
    };

void main() {
  group('AssignmentsApi', () {
    test(
        'listMine issues GET /exercises/assignments/me with no query when '
        'no filters are passed', () async {
      final cap = _Captured();
      final api = AssignmentsApi(_stubDio(
        captured: cap,
        response: {
          'items': [_assignmentJson()],
          'next_cursor': null,
          'has_more': false,
        },
      ));

      final res = await api.listMine();

      expect(cap.method, 'GET');
      expect(cap.path, '/exercises/assignments/me');
      expect(cap.query, isEmpty);
      expect(res.items, hasLength(1));
      expect(res.items.first.id, 'a-1');
      expect(res.hasMore, isFalse);
    });

    test('listMine propagates cursor + status filters', () async {
      final cap = _Captured();
      final api = AssignmentsApi(_stubDio(
        captured: cap,
        response: {
          'items': [_assignmentJson(status: 'in_progress')],
          'next_cursor': 'page-2',
          'has_more': true,
        },
      ));

      final res = await api.listMine(cursor: 'page-1', status: 'in_progress');

      expect(cap.query?['cursor'], 'page-1');
      expect(cap.query?['status'], 'in_progress');
      expect(res.nextCursor, 'page-2');
      expect(res.hasMore, isTrue);
      expect(res.items.single.status,
          ExerciseAssignmentStatus.inProgress);
    });

    test(
        'listForChild issues GET /exercises/{child_id}/assignments and parses '
        'the embedded exercise summary', () async {
      final cap = _Captured();
      final api = AssignmentsApi(_stubDio(
        captured: cap,
        response: {
          'items': [
            _assignmentJson(
              childId: 'child-42',
              exercise: _exerciseJson(category: 'breathing'),
            ),
          ],
          'has_more': false,
        },
      ));

      final res = await api.listForChild('child-42');

      expect(cap.path, '/exercises/child-42/assignments');
      expect(res.items.single.exercise, isNotNull);
      expect(res.items.single.exercise!.category, 'breathing');
    });

    test('complete sends PUT with optional score + notes', () async {
      final cap = _Captured();
      final api = AssignmentsApi(_stubDio(
        captured: cap,
        response: _assignmentJson(
          status: 'completed',
          completedAt: '2026-06-10T12:00:00Z',
          score: 88,
          notes: 'great job',
        ),
      ));

      final res = await api.complete('a-1', score: 88, notes: 'great job');

      expect(cap.method, 'PUT');
      expect(cap.path, '/exercises/assignments/a-1/complete');
      final body = cap.body as Map<String, dynamic>;
      expect(body['score'], 88);
      expect(body['notes'], 'great job');
      expect(res.status, ExerciseAssignmentStatus.completed);
      expect(res.score, 88);
    });

    test('complete omits null fields from the request body', () async {
      final cap = _Captured();
      final api = AssignmentsApi(_stubDio(
        captured: cap,
        response: _assignmentJson(status: 'completed'),
      ));

      await api.complete('a-1');

      final body = cap.body as Map<String, dynamic>;
      // No score / notes should be sent when the user skipped the rating
      // sheet — matters because the API treats `score: null` differently
      // from "field absent".
      expect(body.containsKey('score'), isFalse);
      expect(body.containsKey('notes'), isFalse);
    });

    test('update sends PATCH-style PUT to /exercises/assignments/{id}',
        () async {
      final cap = _Captured();
      final api = AssignmentsApi(_stubDio(
        captured: cap,
        response: _assignmentJson(status: 'in_progress'),
      ));

      final dueDate = DateTime.utc(2026, 7, 1);
      await api.update(
        'a-1',
        status: 'in_progress',
        notes: 'started',
        score: 75,
        dueDate: dueDate,
      );

      expect(cap.method, 'PUT');
      expect(cap.path, '/exercises/assignments/a-1');
      final body = cap.body as Map<String, dynamic>;
      expect(body['status'], 'in_progress');
      expect(body['notes'], 'started');
      expect(body['score'], 75);
      expect(body['due_date'], dueDate.toIso8601String());
    });

    test('list page tolerates malformed item entries without crashing',
        () async {
      final api = AssignmentsApi(_stubDio(
        captured: _Captured(),
        response: {
          'items': [
            _assignmentJson(),
            // Missing required fields — must be skipped, not raise.
            {'id': 'broken'},
          ],
          'has_more': false,
        },
      ));

      final res = await api.listMine();
      expect(res.items, hasLength(1));
      expect(res.items.single.id, 'a-1');
    });
  });

  group('ExerciseAssignment model', () {
    test('isOverdue is true when due date is in the past and status pending',
        () {
      final a = ExerciseAssignment.fromJson(_assignmentJson(
        dueDate: '2000-01-01T00:00:00Z',
        status: 'pending',
      ));
      expect(a.isOverdue, isTrue);
      expect(a.isActionable, isTrue);
    });

    test('isOverdue is false when status is completed', () {
      final a = ExerciseAssignment.fromJson(_assignmentJson(
        dueDate: '2000-01-01T00:00:00Z',
        status: 'completed',
        completedAt: '2026-06-10T11:00:00Z',
      ));
      expect(a.isOverdue, isFalse);
      expect(a.isActionable, isFalse);
    });

    test('status fromWire coerces unknown codes to "other"', () {
      final a = ExerciseAssignment.fromJson(_assignmentJson(
        status: 'mystery_state',
      ));
      expect(a.status, ExerciseAssignmentStatus.other);
      // Unknown / terminal states are not actionable so they don't show
      // up in the home-screen "Today's homework" callout.
      expect(a.isActionable, isFalse);
    });

    test(
        'in_progress synonyms (started, active, in-progress) all map to '
        'ExerciseAssignmentStatus.inProgress', () {
      for (final raw in ['in_progress', 'in-progress', 'started', 'active']) {
        final a = ExerciseAssignment.fromJson(_assignmentJson(status: raw));
        expect(a.status, ExerciseAssignmentStatus.inProgress,
            reason: 'wire="$raw"');
      }
    });

    test('toJson round-trips', () {
      final original = ExerciseAssignment.fromJson(_assignmentJson(
        exercise: _exerciseJson(),
      ));
      final round =
          ExerciseAssignment.fromJson(original.toJson());
      expect(round.id, original.id);
      expect(round.childId, original.childId);
      expect(round.status, original.status);
      expect(round.dueDate, original.dueDate);
      expect(round.exercise?.id, original.exercise?.id);
    });
  });
}
