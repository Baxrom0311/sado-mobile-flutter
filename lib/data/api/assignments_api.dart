import 'package:dio/dio.dart';

import '../models/models.dart';

/// Wire-level client for the therapist-assigned exercise endpoints
/// (the "homework" surface). Mirrors the FastAPI `ExerciseAssignment*`
/// schemas exactly; everything else (filtering by status, deriving
/// "today's homework", etc.) is layered on top in the providers.
///
/// All methods return Dart-native types — the screen code never sees a
/// raw [Map]. Errors propagate as [DioException] so the calling provider
/// can decide whether to fall back to the offline snapshot.
class AssignmentsApi {
  AssignmentsApi(this._dio);
  final Dio _dio;

  /// `GET /exercises/assignments/me` — every active assignment across all
  /// of the parent's children, paginated. The mobile app currently
  /// surfaces the first page only (the API caps results, and parents
  /// rarely have more than a handful of open assignments at a time).
  Future<PaginatedResponse<ExerciseAssignment>> listMine({
    String? cursor,
    String? status,
  }) async {
    final res = await _dio.get(
      '/exercises/assignments/me',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        if (status != null) 'status': status,
      },
    );
    return _parsePage(res.data);
  }

  /// `GET /exercises/{child_id}/assignments` — assignments for one child.
  Future<PaginatedResponse<ExerciseAssignment>> listForChild(
    String childId, {
    String? cursor,
    String? status,
  }) async {
    final res = await _dio.get(
      '/exercises/$childId/assignments',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        if (status != null) 'status': status,
      },
    );
    return _parsePage(res.data);
  }

  /// `GET /exercises/assignments/{id}` — full record for one assignment.
  Future<ExerciseAssignment> get(String id) async {
    final res = await _dio.get('/exercises/assignments/$id');
    return ExerciseAssignment.fromJson(res.data as Map<String, dynamic>);
  }

  /// `PUT /exercises/assignments/{id}/complete` — mark the assignment as
  /// done, optionally attaching a 0–100 self-assessment score and notes.
  ///
  /// The API treats this as idempotent on the assignment id: completing
  /// an already-completed assignment refreshes the score/notes without
  /// erroring.
  Future<ExerciseAssignment> complete(
    String id, {
    double? score,
    String? notes,
  }) async {
    final res = await _dio.put(
      '/exercises/assignments/$id/complete',
      data: {
        if (score != null) 'score': score,
        if (notes != null) 'notes': notes,
      },
    );
    return ExerciseAssignment.fromJson(res.data as Map<String, dynamic>);
  }

  /// `PUT /exercises/assignments/{id}` — patch a subset of fields.
  /// Used by the parent UI to flip status from `pending` to
  /// `in_progress` when they start an assignment but haven't finished
  /// it yet, so therapists can see who has actually engaged.
  Future<ExerciseAssignment> update(
    String id, {
    String? status,
    String? notes,
    double? score,
    DateTime? dueDate,
  }) async {
    final body = <String, dynamic>{
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (score != null) 'score': score,
      if (dueDate != null) 'due_date': dueDate.toIso8601String(),
    };
    final res = await _dio.put(
      '/exercises/assignments/$id',
      data: body,
    );
    return ExerciseAssignment.fromJson(res.data as Map<String, dynamic>);
  }

  // ─────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────

  PaginatedResponse<ExerciseAssignment> _parsePage(Object? data) {
    if (data is! Map) {
      return const PaginatedResponse(items: [], hasMore: false);
    }
    final map = Map<String, dynamic>.from(data);
    final rawItems = map['items'];
    final items = <ExerciseAssignment>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          try {
            items.add(
              ExerciseAssignment.fromJson(Map<String, dynamic>.from(raw)),
            );
          } catch (_) {
            // Skip malformed items rather than crashing the whole list.
            continue;
          }
        }
      }
    }
    return PaginatedResponse(
      items: items,
      nextCursor: map['next_cursor'] as String?,
      hasMore: (map['has_more'] as bool?) ?? false,
    );
  }
}
