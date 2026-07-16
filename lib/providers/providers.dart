import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cache.dart';
import '../data/api/api_client.dart';
import '../data/api/auth_api.dart';
import '../data/api/children_api.dart';
import '../data/api/exercises_api.dart';
import '../data/api/assessments_api.dart';
import '../data/api/assignments_api.dart';
import '../data/api/kindergartens_api.dart';
import '../data/models/models.dart';
import '../data/services/audio_recorder_service.dart';
import '../data/services/pending_uploads_service.dart';
import '../data/services/preview_player.dart';
import '../domain/speech_profile/phoneme_mastery.dart';

/// Factory for the audio recorder used by the assessment game screen.
///
/// Provided as a *factory* (not a singleton) because the screen owns the
/// recorder's lifecycle — every time the screen is built we want a fresh
/// instance so disposing one screen doesn't break a future one.
///
/// Tests override this with a fake recorder that doesn't touch the
/// `record` plugin's platform channels.
typedef AudioRecorderFactory = AudioRecorderService Function();
final audioRecorderFactoryProvider = Provider<AudioRecorderFactory>(
  (_) => AudioRecorderService.new,
);

/// Factory for the in-app preview player (used to play the recording back
/// before submitting). Same factory rationale as the recorder above.
///
/// Tests override this with a [PreviewPlayer] fake so the screen never
/// touches `just_audio`'s platform channels.
typedef PreviewPlayerFactory = PreviewPlayer Function();
final previewPlayerFactoryProvider = Provider<PreviewPlayerFactory>(
  (_) => JustAudioPreviewPlayer.new,
);

// API instances
final authApiProvider = Provider((ref) => AuthApi(ref.watch(dioProvider)));
final childrenApiProvider =
    Provider((ref) => ChildrenApi(ref.watch(dioProvider)));
final exercisesApiProvider =
    Provider((ref) => ExercisesApi(ref.watch(dioProvider)));
final assessmentsApiProvider =
    Provider((ref) => AssessmentsApi(ref.watch(dioProvider)));
final assignmentsApiProvider =
    Provider((ref) => AssignmentsApi(ref.watch(dioProvider)));
final kindergartensApiProvider =
    Provider((ref) => KindergartensApi(ref.watch(dioProvider)));

/// Free-text search across the kindergarten directory. Returns up to 30
/// results — the picker UI scrolls inside its bottom sheet so we do not
/// paginate further. Empty / whitespace queries return the first 30
/// kindergartens so the picker is useful even before the user starts typing.
///
/// Keeping the result size capped at 30 means a "no results" empty state
/// fires for queries that genuinely don't match anything, instead of
/// silently truncating a popular term.
final kindergartensSearchProvider =
    FutureProvider.family<List<Kindergarten>, String>((ref, query) async {
  final api = ref.watch(kindergartensApiProvider);
  final res = await api.list(query: query, limit: 30);
  return res.items;
});

// Auth state
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, User? user, String? error}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authApi, this._ref) : super(const AuthState()) {
    _init();
    // React to session-expired events from the dio interceptor.
    _ref.listen<int>(sessionExpiredEventProvider, (prev, next) {
      if (prev != next && state.status != AuthStatus.unauthenticated) {
        forceLogout();
      }
    });
  }

  final AuthApi _authApi;
  final Ref _ref;

  Future<void> _init() async {
    final token = await getAccessToken();
    if (token == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _authApi.me();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      // Allow offline-authenticated UI: keep token, mark authenticated without user.
      state = state.copyWith(status: AuthStatus.authenticated, user: null);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final tokens = await _authApi.login(email: email, password: password);
      await saveTokens(
          access: tokens.accessToken, refresh: tokens.refreshToken);
      final user = await _authApi.me();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: _humanError(e));
    }
  }

  Future<void> register(
    String email,
    String password,
    String fullName, {
    String role = 'parent',
  }) async {
    try {
      await _authApi.register(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );
      await login(email, password);
    } catch (e) {
      state = state.copyWith(error: _humanError(e));
    }
  }

  Future<void> logout() async {
    try {
      await _authApi.logout();
    } catch (_) {}
    await clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Update the authenticated user's profile. Throws on failure so the UI
  /// can show a localized error; on success the in-memory user is replaced
  /// with the response from the server.
  Future<User> updateProfile({String? fullName, String? language}) async {
    final updated = await _authApi.updateProfile(
      fullName: fullName,
      language: language,
    );
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: updated,
      error: null,
    );
    return updated;
  }

  /// Mark the session as ended without calling the API. Used by the dio
  /// interceptor when refreshing the access token has failed and tokens
  /// have already been cleared.
  void forceLogout() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Network')) {
      return 'network';
    }
    return 'auth';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authApiProvider), ref),
);

// Result wrapper distinguishing fresh data vs cached fallback.
class CachedResult<T> {
  final List<T> items;
  final bool fromCache;
  const CachedResult(this.items, {this.fromCache = false});
}

// Children with offline fallback
final childrenProvider =
    FutureProvider<CachedResult<Child>>((ref) async {
  final api = ref.watch(childrenApiProvider);
  try {
    final res = await api.list();
    final json = res.items.map((c) => _childToJson(c)).toList();
    await OfflineCache.save('children', json);
    return CachedResult(res.items);
  } catch (_) {
    final cached = OfflineCache.read('children');
    if (cached is List) {
      final items = cached
          .whereType<Map>()
          .map((m) => Child.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      return CachedResult(items, fromCache: true);
    }
    rethrow;
  }
});

// Exercises with offline fallback
final exercisesProvider =
    FutureProvider<CachedResult<Exercise>>((ref) async {
  final api = ref.watch(exercisesApiProvider);
  try {
    final res = await api.list();
    final json = res.items.map((e) => _exerciseToJson(e)).toList();
    await OfflineCache.save('exercises', json);
    return CachedResult(res.items);
  } catch (_) {
    final cached = OfflineCache.read('exercises');
    if (cached is List) {
      final items = cached
          .whereType<Map>()
          .map((m) => Exercise.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      return CachedResult(items, fromCache: true);
    }
    rethrow;
  }
});

// Assessments with offline fallback
final assessmentsProvider =
    FutureProvider.family<CachedResult<Assessment>, String?>(
        (ref, childId) async {
  final api = ref.watch(assessmentsApiProvider);
  final cacheKey = 'assessments:${childId ?? 'all'}';
  try {
    final res = await api.list(childId: childId);
    final json = res.items.map(_assessmentToJson).toList();
    await OfflineCache.save(cacheKey, json);
    return CachedResult(res.items);
  } catch (_) {
    final cached = OfflineCache.read(cacheKey);
    if (cached is List) {
      final items = cached
          .whereType<Map>()
          .map((m) => Assessment.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      return CachedResult(items, fromCache: true);
    }
    rethrow;
  }
});

// Currently selected child id (in-memory).
final selectedChildIdProvider = StateProvider<String?>((ref) => null);

/// AI speech-analysis for a single assessment, fetched from
/// `GET /assessments/{id}/analysis`. Returns an empty
/// [AssessmentAnalysis] (instead of throwing) when the analyzer hasn't
/// produced anything yet — this keeps the results screen's error state
/// reserved for genuine transport failures.
final assessmentAnalysisProvider =
    FutureProvider.family<AssessmentAnalysis, String>((ref, id) async {
  final api = ref.watch(assessmentsApiProvider);
  return api.getAnalysis(id);
});

/// Aggregated [SpeechProfile] for one child.
///
/// Hits the existing `/assessments?child_id=…` endpoint, then fans out
/// to `/analysis/{id}` for each row to collect per-recording weak
/// phoneme bags, and finally folds everything down into a parent-friendly
/// per-phoneme mastery snapshot via [PhonemeMasteryAggregator.aggregate].
///
/// The fan-out is bounded to the most recent [_speechProfileWindow]
/// assessments so a child with hundreds of historical recordings
/// doesn't blow the screen's load time. We keep the wider denominator
/// (`assessmentCount`) on the result so the UI can communicate which
/// window was sampled.
///
/// Errors during individual analysis fetches are swallowed — a missing
/// or pending analysis simply contributes nothing to the aggregate, so
/// the screen never has to show a global error just because one of ten
/// recordings is still being processed.
const int _speechProfileWindow = 12;

final speechProfileProvider =
    FutureProvider.autoDispose.family<SpeechProfile, String>(
        (ref, childId) async {
  final assessmentsApi = ref.watch(assessmentsApiProvider);

  // 1) Fetch every assessment for this child.
  final cacheKey = 'assessments:$childId';
  List<Assessment> items;
  try {
    final res = await assessmentsApi.list(childId: childId);
    final json = res.items.map(_assessmentToJson).toList();
    await OfflineCache.save(cacheKey, json);
    items = res.items;
  } catch (_) {
    final cached = OfflineCache.read(cacheKey);
    if (cached is List) {
      items = cached
          .whereType<Map>()
          .map((m) => Assessment.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } else {
      rethrow;
    }
  }

  if (items.isEmpty) {
    return const SpeechProfile.empty();
  }

  // 2) Sort newest-first, take the analysis window.
  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final window = items.take(_speechProfileWindow).toList(growable: false);

  // 3) Fan out to /analysis/{id}; tolerate per-row failures.
  final analyses = <AssessmentAnalysis>[];
  for (final a in window) {
    try {
      final analysis = await assessmentsApi.getAnalysis(a.id);
      analyses.add(analysis);
    } catch (_) {
      // Skip — a single failed analysis row should never sink the
      // whole speech profile screen.
    }
  }

  // 4) Aggregate. Keep the wider [items.length] as the denominator so
  // the UI can show "from 24 assessments" even when we only sampled
  // the most recent 12.
  return PhonemeMasteryAggregator.aggregate(
    analyses,
    assessmentCount: items.length,
  );
});

/// Snapshot returned by [phonemeDrillProvider] — combines the per-phoneme
/// [PhonemeMastery] (which may be `null` when the analyzer has not seen
/// this phoneme yet) with the exercises that target it.
@immutable
class PhonemeDrillData {
  const PhonemeDrillData({
    required this.phoneme,
    required this.mastery,
    required this.exercises,
    required this.exercisesFromCache,
  });

  /// The (normalized) phoneme code used for the drill.
  final String phoneme;

  /// Aggregated mastery for the phoneme. `null` when the speech profile
  /// has no record of it yet — the screen still renders the exercises
  /// list with a friendly "first attempt" hero.
  final PhonemeMastery? mastery;

  /// Exercises that target the requested phoneme, sorted by difficulty
  /// then duration (shortest first) so the recommended starting point
  /// is at the top of the list.
  final List<Exercise> exercises;

  /// True when [exercises] came from the offline Hive snapshot.
  final bool exercisesFromCache;

  /// True when there are no recommended exercises to render.
  bool get hasNoExercises => exercises.isEmpty;
}

/// Filters `exercises` to those that target [phoneme] (case-insensitive,
/// whitespace + `/[]` tolerant). Exposed for unit testing.
@visibleForTesting
List<Exercise> filterExercisesByPhoneme(
  List<Exercise> exercises,
  String phoneme,
) {
  final needle = PhonemeMasteryAggregator.normalize(phoneme);
  if (needle.isEmpty) return const [];
  final matches = <Exercise>[];
  for (final e in exercises) {
    final targets = e.targetPhonemes;
    if (targets == null || targets.isEmpty) continue;
    for (final t in targets) {
      if (PhonemeMasteryAggregator.normalize(t) == needle) {
        matches.add(e);
        break;
      }
    }
  }
  // Sort: easy → medium → hard, then shortest duration first so the
  // suggested starting point is at the top.
  int rankDifficulty(String d) {
    switch (d.toLowerCase()) {
      case 'easy':
        return 0;
      case 'medium':
        return 1;
      case 'hard':
        return 2;
      default:
        return 3;
    }
  }

  matches.sort((a, b) {
    final byDiff = rankDifficulty(a.difficulty)
        .compareTo(rankDifficulty(b.difficulty));
    if (byDiff != 0) return byDiff;
    return a.durationMinutes.compareTo(b.durationMinutes);
  });
  return List.unmodifiable(matches);
}

/// Per-phoneme drill provider — combines the speech profile + exercises
/// catalogue into a focused practice surface.
///
/// The screen drives this with a `(childId, phoneme)` tuple. The
/// underlying providers are already cache-tolerant, so a parent without
/// connectivity will still see whatever exercises were cached on the
/// last successful load.
final phonemeDrillProvider = FutureProvider.autoDispose
    .family<PhonemeDrillData, ({String childId, String phoneme})>(
        (ref, args) async {
  final normalised = PhonemeMasteryAggregator.normalize(args.phoneme);

  // Run both fetches in parallel — they are independent and the screen
  // can render meaningfully as soon as both resolve.
  final profileFuture = ref.watch(speechProfileProvider(args.childId).future);
  final exercisesFuture = ref.watch(exercisesProvider.future);

  final results = await Future.wait([profileFuture, exercisesFuture]);
  final profile = results[0] as SpeechProfile;
  final exercisesResult = results[1] as CachedResult<Exercise>;

  PhonemeMastery? mastery;
  for (final p in profile.phonemes) {
    if (p.phoneme == normalised) {
      mastery = p;
      break;
    }
  }

  final filtered =
      filterExercisesByPhoneme(exercisesResult.items, normalised);

  return PhonemeDrillData(
    phoneme: normalised,
    mastery: mastery,
    exercises: filtered,
    exercisesFromCache: exercisesResult.fromCache,
  );
});
Map<String, dynamic> _childToJson(Child c) => {
      'id': c.id,
      'name': c.name,
      'birth_date': c.birthDate.toIso8601String(),
      'gender': c.gender,
      'kindergarten_id': c.kindergartenId,
      'parent_id': c.parentId,
      'created_at': c.createdAt.toIso8601String(),
    };

Map<String, dynamic> _exerciseToJson(Exercise e) => {
      'id': e.id,
      'title': e.title,
      'description': e.description,
      'category': e.category,
      'age_group': e.ageGroup,
      'difficulty': e.difficulty,
      'language': e.language,
      'duration_minutes': e.durationMinutes,
      'audio_example_path': e.audioExamplePath,
      'image_path': e.imagePath,
      'instructions': e.instructions,
      'target_phonemes': e.targetPhonemes,
      'is_active': e.isActive,
    };

Map<String, dynamic> _assessmentToJson(Assessment a) => {
      'id': a.id,
      'child_id': a.childId,
      'exercise_id': a.exerciseId,
      'status': a.status,
      'overall_risk': a.overallRisk,
      'score': a.score,
      'audio_path': a.audioPath,
      'created_at': a.createdAt.toIso8601String(),
    };

// Pending uploads queue (offline assessment submissions).
//
// The service is constructed asynchronously because it needs to open a Hive
// box. We expose:
//   * [pendingUploadsServiceProvider] — the service itself (FutureProvider)
//   * [pendingUploadsCountProvider]   — current queue size as a StreamProvider
//
// Both are tolerant of being read in test environments where Hive may not be
// initialised — they simply emit `0` and a no-op service.

final pendingUploadsServiceProvider =
    FutureProvider<PendingUploadsService>((ref) async {
  return PendingUploadsService.open();
});

final pendingUploadsCountProvider = StreamProvider<int>((ref) async* {
  final service = await ref.watch(pendingUploadsServiceProvider.future);
  yield* service.watchCount();
});

/// Live list of queued uploads, sorted oldest-first. Emits an initial value
/// immediately and re-emits on every box mutation, so retry/discard actions
/// update the UI without manual invalidation.
///
/// In environments where the service can't be opened (Hive not initialised
/// in tests, missing platform plugin), this falls back to an empty list
/// rather than throwing — the surrounding UI just renders the empty state.
final pendingUploadsListProvider =
    StreamProvider<List<PendingUpload>>((ref) async* {
  late PendingUploadsService service;
  try {
    service = await ref.watch(pendingUploadsServiceProvider.future);
  } catch (_) {
    yield const <PendingUpload>[];
    return;
  }
  // watchCount() emits immediately on subscribe and again on every box
  // mutation, so we get the initial snapshot for free without a race.
  await for (final _ in service.watchCount()) {
    yield service.all();
  }
});

/// Flush any queued uploads using the current Dio. Safe to call repeatedly;
/// the service guards against concurrent flushes.
///
/// Accepts either a [Ref] (from a Provider) or a [WidgetRef] (from a
/// ConsumerWidget). The [readFuture] / [readAssessmentsApi] adapters keep us
/// portable across both without duplicating logic.
Future<FlushResult> _flushPendingUploads({
  required Future<PendingUploadsService> serviceFuture,
  required AssessmentsApi api,
  required void Function() invalidateAssessments,
}) async {
  try {
    final service = await serviceFuture;
    final result = await service.flush(api);
    if (result.succeeded > 0) {
      invalidateAssessments();
    }
    return result;
  } catch (_) {
    return const FlushResult(succeeded: 0, failed: 0, uploaded: []);
  }
}

/// Convenience wrapper for [WidgetRef] callers (e.g. ConsumerWidgets).
Future<FlushResult> flushPendingUploads(WidgetRef ref) {
  return _flushPendingUploads(
    serviceFuture: ref.read(pendingUploadsServiceProvider.future),
    api: ref.read(assessmentsApiProvider),
    invalidateAssessments: () => ref.invalidate(assessmentsProvider),
  );
}

/// Convenience wrapper for [Ref] callers (e.g. inside other Providers).
Future<FlushResult> flushPendingUploadsRef(Ref ref) {
  return _flushPendingUploads(
    serviceFuture: ref.read(pendingUploadsServiceProvider.future),
    api: ref.read(assessmentsApiProvider),
    invalidateAssessments: () => ref.invalidate(assessmentsProvider),
  );
}


// ──────────────────────────────────────────────────────────────────
// Therapist-assigned exercises ("homework")
// ──────────────────────────────────────────────────────────────────
//
// Two providers feed the UI:
//
//   * [myAssignmentsProvider]      — every active assignment across the
//                                    parent's children. Drives the home
//                                    screen "Today's homework" card and
//                                    the dedicated assignments screen.
//
//   * [childAssignmentsProvider]   — assignments scoped to one child.
//                                    Drives the section on the child
//                                    detail screen.
//
// Both providers fall back to a Hive snapshot on transport failure so
// the parent never sees a blank list when offline. Mutations
// (`completeAssignment`, `startAssignment`) invalidate both providers
// so the UI stays consistent across screens.

/// Listing of therapist-assigned exercises for the authenticated parent
/// (across every child). The returned list is sorted by:
///
///   1. actionable assignments (pending / in-progress) before terminal
///      ones (completed / skipped),
///   2. overdue assignments first within the actionable group,
///   3. due-soon assignments next, then ordering by [createdAt] descending.
///
/// On transport failure, the cached snapshot is returned with
/// [CachedResult.fromCache] = `true` so the UI can render an
/// "offline-cached" banner.
final myAssignmentsProvider =
    FutureProvider<CachedResult<ExerciseAssignment>>((ref) async {
  final api = ref.watch(assignmentsApiProvider);
  const cacheKey = 'assignments:me';
  try {
    final res = await api.listMine();
    final sorted = sortAssignmentsForUi(res.items);
    final json = sorted.map((a) => a.toJson()).toList();
    await OfflineCache.save(cacheKey, json);
    return CachedResult(sorted);
  } catch (_) {
    final cached = OfflineCache.read(cacheKey);
    if (cached is List) {
      final items = cached
          .whereType<Map>()
          .map(
              (m) => ExerciseAssignment.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      return CachedResult(sortAssignmentsForUi(items), fromCache: true);
    }
    rethrow;
  }
});

/// Assignments for one specific child, sorted with the same UI ordering
/// as [myAssignmentsProvider].
final childAssignmentsProvider =
    FutureProvider.family<CachedResult<ExerciseAssignment>, String>(
        (ref, childId) async {
  final api = ref.watch(assignmentsApiProvider);
  final cacheKey = 'assignments:child:$childId';
  try {
    final res = await api.listForChild(childId);
    final sorted = sortAssignmentsForUi(res.items);
    final json = sorted.map((a) => a.toJson()).toList();
    await OfflineCache.save(cacheKey, json);
    return CachedResult(sorted);
  } catch (_) {
    final cached = OfflineCache.read(cacheKey);
    if (cached is List) {
      final items = cached
          .whereType<Map>()
          .map(
              (m) => ExerciseAssignment.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      return CachedResult(sortAssignmentsForUi(items), fromCache: true);
    }
    rethrow;
  }
});

/// UI-friendly comparator for [ExerciseAssignment] lists.
///
/// Visible for testing. The ordering rules are deliberately stable so
/// snapshot-style widget tests don't flap:
///
///   1. actionable (pending / in_progress) before terminal
///      (completed / skipped / other),
///   2. overdue actionable first,
///   3. due-soon actionable next (closest due date first; null due
///      dates sort after dated entries within the same bucket),
///   4. otherwise the most recently created first.
List<ExerciseAssignment> sortAssignmentsForUi(
    List<ExerciseAssignment> items) {
  final list = [...items];
  list.sort((a, b) {
    final aActionable = a.isActionable ? 0 : 1;
    final bActionable = b.isActionable ? 0 : 1;
    if (aActionable != bActionable) return aActionable - bActionable;

    if (a.isActionable && b.isActionable) {
      final aOverdue = a.isOverdue ? 0 : 1;
      final bOverdue = b.isOverdue ? 0 : 1;
      if (aOverdue != bOverdue) return aOverdue - bOverdue;

      final aDue = a.dueDate;
      final bDue = b.dueDate;
      if (aDue != null && bDue != null) {
        final c = aDue.compareTo(bDue);
        if (c != 0) return c;
      } else if (aDue != null) {
        return -1;
      } else if (bDue != null) {
        return 1;
      }
    }
    return b.createdAt.compareTo(a.createdAt);
  });
  return list;
}

/// Mark an assignment as completed and invalidate the providers that
/// surface it so every screen refreshes in lockstep.
///
/// Returns the updated [ExerciseAssignment] from the server. Throws on
/// transport failure so the UI can show a localized error snackbar.
Future<ExerciseAssignment> completeAssignment(
  WidgetRef ref,
  String id, {
  double? score,
  String? notes,
}) async {
  final api = ref.read(assignmentsApiProvider);
  final updated = await api.complete(id, score: score, notes: notes);
  ref.invalidate(myAssignmentsProvider);
  ref.invalidate(childAssignmentsProvider(updated.childId));
  return updated;
}

/// Patch a single assignment (status / notes / score / due_date). Used by
/// the parent UI to flip status to `in_progress` when they tap "Start"
/// without completing the homework yet.
Future<ExerciseAssignment> patchAssignment(
  WidgetRef ref,
  String id, {
  String? status,
  String? notes,
  double? score,
  DateTime? dueDate,
}) async {
  final api = ref.read(assignmentsApiProvider);
  final updated = await api.update(
    id,
    status: status,
    notes: notes,
    score: score,
    dueDate: dueDate,
  );
  ref.invalidate(myAssignmentsProvider);
  ref.invalidate(childAssignmentsProvider(updated.childId));
  return updated;
}
