import 'package:dio/dio.dart';

import '../models/models.dart';

/// Wire-level client for the FastAPI `/practice-plans` surface.
///
/// Mirrors the Pydantic schemas in
/// `app/schemas/practice_plan.py` exactly. Every method returns Dart
/// types — call sites never see a raw [Map]. Dio errors propagate so
/// the caller can decide whether to fall back to the offline snapshot.
class PracticePlansApi {
  PracticePlansApi(this._dio);

  final Dio _dio;

  /// `GET /practice-plans` — every plan visible to the caller, paginated.
  ///
  /// [childId] scopes the listing to one child; omit it for the
  /// "all my plans" listing on the parent home screen. [statusFilter]
  /// maps to the wire `status` query param (`draft|active|completed|archived`).
  Future<PaginatedResponse<PracticePlan>> list({
    String? cursor,
    int? limit,
    String? childId,
    PracticePlanStatus? statusFilter,
  }) async {
    final res = await _dio.get(
      '/practice-plans',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
        if (childId != null) 'child_id': childId,
        if (statusFilter != null) 'status': statusFilter.wire,
      },
    );
    return _parsePage(res.data);
  }

  /// `GET /practice-plans/{id}` — full plan detail (items embedded).
  Future<PracticePlan> get(String id) async {
    final res = await _dio.get('/practice-plans/$id');
    return PracticePlan.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// `POST /practice-plans/generate` — auto-generate a plan from the
  /// most recent assessment. Parents can call this for their own
  /// children's assessments; therapists / admins for any.
  Future<PracticePlan> generate({
    required String assessmentId,
    String? locale,
    int maxItems = 5,
    bool activate = false,
    String? title,
  }) async {
    final res = await _dio.post(
      '/practice-plans/generate',
      data: {
        'assessment_id': assessmentId,
        if (locale != null) 'locale': locale,
        'max_items': maxItems,
        'activate': activate,
        if (title != null) 'title': title,
      },
    );
    return PracticePlan.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// `POST /practice-plans/{plan_id}/items/{item_id}/complete` —
  /// record practice progress. Once `completed_count` reaches
  /// `target_count` the API flips status to `completed`.
  Future<PracticePlanItem> completeItem(
    String planId,
    String itemId, {
    int increment = 1,
    String? notes,
  }) async {
    final res = await _dio.post(
      '/practice-plans/$planId/items/$itemId/complete',
      data: {
        'increment': increment,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return PracticePlanItem.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  /// `PUT /practice-plans/{plan_id}/items/{item_id}` — patch an item.
  /// Used by the parent UI to flip an item to `in_progress` when they
  /// open it without finishing the reps yet.
  Future<PracticePlanItem> updateItem(
    String planId,
    String itemId, {
    PracticePlanItemStatus? status,
    int? completedCount,
    int? priority,
    int? targetCount,
    String? focusCode,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      if (status != null) 'status': status.wire,
      if (completedCount != null) 'completed_count': completedCount,
      if (priority != null) 'priority': priority,
      if (targetCount != null) 'target_count': targetCount,
      if (focusCode != null) 'focus_code': focusCode,
      if (notes != null) 'notes': notes,
    };
    final res = await _dio.put(
      '/practice-plans/$planId/items/$itemId',
      data: body,
    );
    return PracticePlanItem.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────

  PaginatedResponse<PracticePlan> _parsePage(Object? data) {
    if (data is! Map) {
      return const PaginatedResponse(items: [], hasMore: false);
    }
    final map = Map<String, dynamic>.from(data);
    final rawItems = map['items'];
    final items = <PracticePlan>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          try {
            items.add(
              PracticePlan.fromJson(Map<String, dynamic>.from(raw)),
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
