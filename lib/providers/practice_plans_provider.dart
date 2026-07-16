import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cache.dart';
import '../data/api/api_client.dart';
import '../data/api/practice_plans_api.dart';
import '../data/models/practice_plan.dart';
import 'providers.dart';

/// Dio-backed [PracticePlansApi] instance. Tests override this to
/// inject a fake.
final practicePlansApiProvider = Provider<PracticePlansApi>(
  (ref) => PracticePlansApi(ref.watch(dioProvider)),
);

/// Result wrapper used by the cache-tolerant providers below. Same
/// shape as [CachedResult] in the main provider file but parameterised
/// for plans so the screens can drop the generic type annotation.
@immutable
class PracticePlansResult {
  const PracticePlansResult(this.items, {this.fromCache = false});

  final List<PracticePlan> items;

  /// True when the plans were served from the offline Hive snapshot —
  /// the screen renders an [OfflineBanner] when this fires so parents
  /// understand they may be looking at slightly stale data.
  final bool fromCache;

  bool get isEmpty => items.isEmpty;
}

/// Every practice plan visible to the authenticated parent across all
/// of their children. Drives the home-screen "active plan" surface and
/// the dedicated practice-plans list screen.
///
/// On transport failure, falls back to the most recent successful
/// snapshot from the Hive cache (`offlineCache: practice_plans:me`)
/// with [PracticePlansResult.fromCache] = `true`.
final myPracticePlansProvider =
    FutureProvider<PracticePlansResult>((ref) async {
  final api = ref.watch(practicePlansApiProvider);
  const cacheKey = 'practice_plans:me';
  try {
    final res = await api.list();
    final sorted = sortPlansForUi(res.items);
    final json = sorted.map((p) => p.toJson()).toList();
    await OfflineCache.save(cacheKey, json);
    return PracticePlansResult(sorted);
  } catch (_) {
    final cached = OfflineCache.read(cacheKey);
    if (cached is List) {
      final items = cached
          .whereType<Map>()
          .map(
              (m) => _safeFromJson(Map<String, dynamic>.from(m)))
          .whereType<PracticePlan>()
          .toList();
      return PracticePlansResult(
        sortPlansForUi(items),
        fromCache: true,
      );
    }
    rethrow;
  }
});

/// Practice plans scoped to one child. Same caching contract as
/// [myPracticePlansProvider].
final childPracticePlansProvider =
    FutureProvider.family<PracticePlansResult, String>((ref, childId) async {
  final api = ref.watch(practicePlansApiProvider);
  final cacheKey = 'practice_plans:child:$childId';
  try {
    final res = await api.list(childId: childId);
    final sorted = sortPlansForUi(res.items);
    final json = sorted.map((p) => p.toJson()).toList();
    await OfflineCache.save(cacheKey, json);
    return PracticePlansResult(sorted);
  } catch (_) {
    final cached = OfflineCache.read(cacheKey);
    if (cached is List) {
      final items = cached
          .whereType<Map>()
          .map(
              (m) => _safeFromJson(Map<String, dynamic>.from(m)))
          .whereType<PracticePlan>()
          .toList();
      return PracticePlansResult(
        sortPlansForUi(items),
        fromCache: true,
      );
    }
    rethrow;
  }
});

/// Detail provider for one plan (with its items). Auto-disposes when
/// the screen pops.
///
/// Keeps a per-plan offline snapshot so reopening a plan offline still
/// shows the items the parent saw last.
final practicePlanDetailProvider = FutureProvider.autoDispose
    .family<PracticePlan, String>((ref, planId) async {
  final api = ref.watch(practicePlansApiProvider);
  final cacheKey = 'practice_plans:detail:$planId';
  try {
    final plan = await api.get(planId);
    await OfflineCache.save(cacheKey, plan.toJson());
    return plan;
  } catch (_) {
    final cached = OfflineCache.read(cacheKey);
    if (cached is Map) {
      final hydrated = _safeFromJson(Map<String, dynamic>.from(cached));
      if (hydrated != null) return hydrated;
    }
    rethrow;
  }
});

/// UI ordering used by the list providers above. Visible for testing.
///
/// Rules — kept stable so widget snapshots don't flap:
///   1. active plans first, then draft, then completed, then archived,
///   2. within a bucket, the most recently updated plan first.
List<PracticePlan> sortPlansForUi(List<PracticePlan> items) {
  int rank(PracticePlanStatus s) {
    switch (s) {
      case PracticePlanStatus.active:
        return 0;
      case PracticePlanStatus.draft:
        return 1;
      case PracticePlanStatus.completed:
        return 2;
      case PracticePlanStatus.archived:
        return 3;
    }
  }

  final sorted = [...items];
  sorted.sort((a, b) {
    final byBucket = rank(a.status).compareTo(rank(b.status));
    if (byBucket != 0) return byBucket;
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return sorted;
}

/// Imperatively record one rep of progress on an item. On success, the
/// list + detail providers are invalidated so every screen refreshes
/// in lockstep.
///
/// Returns the updated [PracticePlanItem] from the server. Throws on
/// transport failure so the UI can show a localized error toast.
Future<PracticePlanItem> recordPlanItemProgress(
  WidgetRef ref, {
  required String planId,
  required String itemId,
  int increment = 1,
  String? notes,
}) async {
  final api = ref.read(practicePlansApiProvider);
  final updated = await api.completeItem(
    planId,
    itemId,
    increment: increment,
    notes: notes,
  );
  ref.invalidate(myPracticePlansProvider);
  ref.invalidate(practicePlanDetailProvider(planId));
  // We don't know the childId here — invalidating every per-child
  // listing keeps the UI in sync without leaking implementation details.
  ref.invalidate(childPracticePlansProvider);
  return updated;
}

/// Imperatively flip an item's status (e.g. to `in_progress` when the
/// parent taps "Start" without recording a rep yet, or to `skipped`
/// when they want to dismiss it).
Future<PracticePlanItem> patchPlanItem(
  WidgetRef ref, {
  required String planId,
  required String itemId,
  PracticePlanItemStatus? status,
  int? completedCount,
  String? notes,
}) async {
  final api = ref.read(practicePlansApiProvider);
  final updated = await api.updateItem(
    planId,
    itemId,
    status: status,
    completedCount: completedCount,
    notes: notes,
  );
  ref.invalidate(myPracticePlansProvider);
  ref.invalidate(practicePlanDetailProvider(planId));
  ref.invalidate(childPracticePlansProvider);
  return updated;
}

/// Generate a plan from a finished assessment. Parents call this from
/// the assessment-results screen; therapists from the dashboard. The
/// list providers are invalidated so the new plan shows up immediately.
Future<PracticePlan> generatePlanFromAssessment(
  WidgetRef ref, {
  required String assessmentId,
  String? locale,
  int maxItems = 5,
  bool activate = true,
  String? title,
}) async {
  final api = ref.read(practicePlansApiProvider);
  final plan = await api.generate(
    assessmentId: assessmentId,
    locale: locale,
    maxItems: maxItems,
    activate: activate,
    title: title,
  );
  ref.invalidate(myPracticePlansProvider);
  ref.invalidate(childPracticePlansProvider);
  return plan;
}

PracticePlan? _safeFromJson(Map<String, dynamic> json) {
  try {
    return PracticePlan.fromJson(json);
  } catch (_) {
    // Defensive: malformed cache entries should never crash the UI.
    return null;
  }
}

/// Visible for testing — encodes a plan list into the same shape the
/// offline cache stores.
@visibleForTesting
String encodePlanCache(List<PracticePlan> plans) =>
    jsonEncode(plans.map((p) => p.toJson()).toList());
