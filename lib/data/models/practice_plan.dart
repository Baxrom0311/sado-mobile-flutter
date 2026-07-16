// Plain Dart models mirroring the FastAPI `PracticePlan*` schemas.
//
// We keep the parsing tolerant: missing optional fields, mixed-case
// status strings and stringified numbers all decode cleanly so a stale
// Hive snapshot or an older API build never crashes the parent's
// session. Round-trip JSON is available for the offline cache.

import 'dart:convert';

/// Lifecycle of a [PracticePlan]. Mirrors `PracticePlanStatus` on the
/// API exactly. Unknown values coerce to [PracticePlanStatus.draft]
/// rather than throwing — the UI degrades gracefully instead of
/// blocking the whole list.
enum PracticePlanStatus {
  draft,
  active,
  completed,
  archived;

  String get wire => name;

  static PracticePlanStatus fromWire(Object? raw) {
    if (raw == null) return PracticePlanStatus.draft;
    final s = raw.toString().trim().toLowerCase();
    for (final v in PracticePlanStatus.values) {
      if (v.name == s) return v;
    }
    return PracticePlanStatus.draft;
  }
}

/// Per-item status. Same tolerant parsing rules as
/// [PracticePlanStatus.fromWire].
enum PracticePlanItemStatus {
  pending,
  inProgress,
  completed,
  skipped;

  String get wire => switch (this) {
        PracticePlanItemStatus.pending => 'pending',
        PracticePlanItemStatus.inProgress => 'in_progress',
        PracticePlanItemStatus.completed => 'completed',
        PracticePlanItemStatus.skipped => 'skipped',
      };

  static PracticePlanItemStatus fromWire(Object? raw) {
    if (raw == null) return PracticePlanItemStatus.pending;
    final s = raw.toString().trim().toLowerCase().replaceAll('-', '_');
    return switch (s) {
      'pending' => PracticePlanItemStatus.pending,
      'in_progress' || 'inprogress' || 'started' || 'active' =>
        PracticePlanItemStatus.inProgress,
      'completed' || 'done' || 'finished' => PracticePlanItemStatus.completed,
      'skipped' => PracticePlanItemStatus.skipped,
      _ => PracticePlanItemStatus.pending,
    };
  }
}

/// A single prescription inside a [PracticePlan].
class PracticePlanItem {
  PracticePlanItem({
    required this.id,
    required this.planId,
    required this.exerciseId,
    required this.status,
    required this.priority,
    required this.targetCount,
    required this.completedCount,
    this.focusCode,
    this.notes,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.exerciseTitle,
    this.exerciseCategory,
    this.exerciseDifficulty,
  });

  final String id;
  final String planId;
  final String exerciseId;
  final PracticePlanItemStatus status;

  /// 1 = highest, 5 = lowest priority.
  final int priority;
  final int targetCount;
  final int completedCount;

  final String? focusCode;
  final String? notes;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Embedded exercise summary — saves a round trip per item.
  final String? exerciseTitle;
  final String? exerciseCategory;
  final String? exerciseDifficulty;

  /// True once the item has hit its target rep count or been marked
  /// complete by a therapist.
  bool get isCompleted => status == PracticePlanItemStatus.completed;

  /// True while the item is actionable for the parent (pending or in
  /// progress). Skipped items are intentionally treated as terminal.
  bool get isActionable =>
      status == PracticePlanItemStatus.pending ||
      status == PracticePlanItemStatus.inProgress;

  /// Progress toward [targetCount] in the [0, 1] range. Always returns
  /// 1.0 once [isCompleted] flips so the UI shows a full bar even when
  /// the API lags one tick behind on `completed_count`.
  double get progress {
    if (isCompleted) return 1.0;
    final t = targetCount;
    if (t <= 0) return 0.0;
    return (completedCount / t).clamp(0.0, 1.0).toDouble();
  }

  /// Display-friendly "X/Y" string ("3/5"). Defensive against the
  /// rare case where the API returns `target_count = 0`.
  String get progressLabel {
    final t = targetCount <= 0 ? 1 : targetCount;
    final c = completedCount.clamp(0, t);
    return '$c/$t';
  }

  factory PracticePlanItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? raw) {
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    String? trimToNullable(Object? raw) {
      if (raw is! String) return null;
      final t = raw.trim();
      return t.isEmpty ? null : t;
    }

    return PracticePlanItem(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      exerciseId: json['exercise_id'] as String,
      status: PracticePlanItemStatus.fromWire(json['status']),
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      targetCount: (json['target_count'] as num?)?.toInt() ?? 1,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      focusCode: trimToNullable(json['focus_code']),
      notes: trimToNullable(json['notes']),
      completedAt: parseDate(json['completed_at']),
      createdAt: parseDate(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: parseDate(json['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      exerciseTitle: trimToNullable(json['exercise_title']),
      exerciseCategory: trimToNullable(json['exercise_category']),
      exerciseDifficulty: trimToNullable(json['exercise_difficulty']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plan_id': planId,
        'exercise_id': exerciseId,
        'status': status.wire,
        'priority': priority,
        'target_count': targetCount,
        'completed_count': completedCount,
        if (focusCode != null) 'focus_code': focusCode,
        if (notes != null) 'notes': notes,
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (exerciseTitle != null) 'exercise_title': exerciseTitle,
        if (exerciseCategory != null) 'exercise_category': exerciseCategory,
        if (exerciseDifficulty != null)
          'exercise_difficulty': exerciseDifficulty,
      };

  PracticePlanItem copyWith({
    PracticePlanItemStatus? status,
    int? completedCount,
    DateTime? completedAt,
    String? notes,
  }) =>
      PracticePlanItem(
        id: id,
        planId: planId,
        exerciseId: exerciseId,
        status: status ?? this.status,
        priority: priority,
        targetCount: targetCount,
        completedCount: completedCount ?? this.completedCount,
        focusCode: focusCode,
        notes: notes ?? this.notes,
        completedAt: completedAt ?? this.completedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
        exerciseTitle: exerciseTitle,
        exerciseCategory: exerciseCategory,
        exerciseDifficulty: exerciseDifficulty,
      );
}

/// A practice plan — a focused, therapist- or auto-generated curriculum
/// tied to one child. Items are nullable so the list-page payload (which
/// does not embed items) and the detail-page payload (which does) share
/// the same model.
class PracticePlan {
  PracticePlan({
    required this.id,
    required this.childId,
    this.assessmentId,
    this.createdById,
    this.tenantId,
    required this.title,
    this.summary,
    required this.status,
    required this.locale,
    this.focusAreas,
    this.startDate,
    this.endDate,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.itemCount,
    required this.completedItemCount,
    this.items,
  });

  final String id;
  final String childId;
  final String? assessmentId;
  final String? createdById;
  final String? tenantId;
  final String title;
  final String? summary;
  final PracticePlanStatus status;
  final String locale;
  final List<String>? focusAreas;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Total items in the plan. Comes from the API summary so the list
  /// page can render `3/5 done` without fetching the items.
  final int itemCount;
  final int completedItemCount;

  /// Embedded items. `null` on list responses, populated on detail
  /// responses.
  final List<PracticePlanItem>? items;

  /// Plan-level progress in the [0, 1] range. Falls back to 0 for empty
  /// plans rather than throwing on divide-by-zero.
  double get progress {
    if (itemCount <= 0) return 0.0;
    return (completedItemCount / itemCount).clamp(0.0, 1.0).toDouble();
  }

  /// Display-friendly "X/Y" of completed items.
  String get progressLabel => '$completedItemCount/$itemCount';

  /// Convenience: every item has been completed (or the plan was
  /// flipped to `completed` server-side).
  bool get isCompleted =>
      status == PracticePlanStatus.completed ||
      (itemCount > 0 && completedItemCount >= itemCount);

  /// Convenience: the plan is active and still has work to do.
  bool get isActive =>
      status == PracticePlanStatus.active && !isCompleted;

  /// Items the parent should still tackle, sorted by priority then by
  /// completion ratio (least progress first). Always returns the empty
  /// list when [items] hasn't been hydrated yet.
  List<PracticePlanItem> get pendingItems {
    final raw = items;
    if (raw == null || raw.isEmpty) return const [];
    final pending = raw.where((i) => i.isActionable).toList();
    pending.sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      if (byPriority != 0) return byPriority;
      return a.progress.compareTo(b.progress);
    });
    return List.unmodifiable(pending);
  }

  /// Items already completed or skipped. Sorted newest-first using
  /// `completedAt` (falling back to `updatedAt`).
  List<PracticePlanItem> get historyItems {
    final raw = items;
    if (raw == null || raw.isEmpty) return const [];
    final done = raw.where((i) => !i.isActionable).toList();
    DateTime stamp(PracticePlanItem i) => i.completedAt ?? i.updatedAt;
    done.sort((a, b) => stamp(b).compareTo(stamp(a)));
    return List.unmodifiable(done);
  }

  factory PracticePlan.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? raw) {
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    List<String>? parseStrings(Object? raw) {
      if (raw == null) return null;
      if (raw is List) {
        final cleaned = raw
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
        return cleaned.isEmpty ? null : cleaned;
      }
      if (raw is String) {
        final cleaned = raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
        return cleaned.isEmpty ? null : cleaned;
      }
      return null;
    }

    List<PracticePlanItem>? parseItems(Object? raw) {
      if (raw is! List) return null;
      final out = <PracticePlanItem>[];
      for (final entry in raw) {
        if (entry is Map) {
          try {
            out.add(
              PracticePlanItem.fromJson(Map<String, dynamic>.from(entry)),
            );
          } catch (_) {
            // Skip malformed entries rather than nuking the whole plan.
          }
        }
      }
      return out;
    }

    final itemsList = parseItems(json['items']);

    final apiItemCount = (json['item_count'] as num?)?.toInt();
    final apiCompletedCount =
        (json['completed_item_count'] as num?)?.toInt();

    return PracticePlan(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      assessmentId: json['assessment_id'] as String?,
      createdById: json['created_by_id'] as String?,
      tenantId: json['tenant_id'] as String?,
      title: (json['title'] as String?)?.trim() ?? '',
      summary: (json['summary'] as String?)?.trim().isEmpty == true
          ? null
          : (json['summary'] as String?)?.trim(),
      status: PracticePlanStatus.fromWire(json['status']),
      locale: (json['locale'] as String?)?.trim().isEmpty == true
          ? 'uz'
          : (json['locale'] as String? ?? 'uz').trim(),
      focusAreas: parseStrings(json['focus_areas']),
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      completedAt: parseDate(json['completed_at']),
      createdAt: parseDate(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: parseDate(json['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      itemCount: apiItemCount ?? itemsList?.length ?? 0,
      completedItemCount: apiCompletedCount ??
          itemsList?.where((i) => i.isCompleted).length ??
          0,
      items: itemsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'child_id': childId,
        if (assessmentId != null) 'assessment_id': assessmentId,
        if (createdById != null) 'created_by_id': createdById,
        if (tenantId != null) 'tenant_id': tenantId,
        'title': title,
        if (summary != null) 'summary': summary,
        'status': status.wire,
        'locale': locale,
        if (focusAreas != null) 'focus_areas': focusAreas,
        if (startDate != null)
          'start_date': startDate!.toIso8601String().split('T').first,
        if (endDate != null)
          'end_date': endDate!.toIso8601String().split('T').first,
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'item_count': itemCount,
        'completed_item_count': completedItemCount,
        if (items != null) 'items': items!.map((i) => i.toJson()).toList(),
      };

  /// Round-trips a plan through JSON encode/decode — used by the offline
  /// cache layer in [providers.dart].
  String encode() => jsonEncode(toJson());
}
