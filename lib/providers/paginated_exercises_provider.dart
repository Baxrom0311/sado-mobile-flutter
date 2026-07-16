import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cache.dart';
import '../data/api/exercises_api.dart';
import '../data/models/models.dart';
import 'providers.dart';

/// Immutable state for the paginated exercises list.
///
/// The screen uses this for infinite scroll: render [items] now, append more
/// when [hasMore] is true and the user scrolls near the bottom.
@immutable
class PaginatedExercisesState {
  /// Items loaded so far across all pages.
  final List<Exercise> items;

  /// Cursor to fetch the next page, or null if [hasMore] is false.
  final String? nextCursor;

  /// True when the server reports more pages are available.
  final bool hasMore;

  /// True while the *first* page is loading (used to show shimmer).
  final bool isLoading;

  /// True while a *subsequent* page is loading (used to show a footer).
  final bool isLoadingMore;

  /// Network error from the most recent fetch attempt, if any.
  final Object? error;

  /// True when [items] came from the offline Hive cache rather than the API.
  final bool fromCache;

  /// Currently selected category filter (null = all).
  final String? category;

  /// Currently selected age-group filter (null = all). Tokens follow the
  /// API convention: "2-3", "3-4", "4-5", "5-6", "6-7".
  final String? ageGroup;

  /// Currently selected difficulty filter (null = all). Tokens follow the
  /// API convention: "easy", "medium", "hard".
  final String? difficulty;

  /// Free-text search query the user typed. Filtering is performed
  /// client-side over [items] so it remains responsive even when the API
  /// does not (yet) implement a `q` parameter. Comparisons are
  /// case-insensitive against the exercise title and description.
  final String searchQuery;

  const PaginatedExercisesState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.fromCache = false,
    this.category,
    this.ageGroup,
    this.difficulty,
    this.searchQuery = '',
  });

  /// Trimmed lower-case search needle, or `null` when the user has not
  /// typed anything meaningful. Cached as a getter so the screen and the
  /// notifier stay in sync.
  String? get _needle {
    final trimmed = searchQuery.trim().toLowerCase();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Items to actually render. Equals [items] when no search is active;
  /// otherwise filtered case-insensitively by title + description.
  List<Exercise> get filteredItems {
    final needle = _needle;
    if (needle == null) return items;
    return items.where((e) {
      final hay =
          '${e.title.toLowerCase()} ${e.description.toLowerCase()}';
      return hay.contains(needle);
    }).toList(growable: false);
  }

  /// True when a search query is active. Lets the UI swap the empty-state
  /// copy from "no exercises in this category yet" to "no matches for X".
  bool get isSearching => _needle != null;

  PaginatedExercisesState copyWith({
    List<Exercise>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
    bool? fromCache,
    String? category,
    bool clearCategory = false,
    String? ageGroup,
    bool clearAgeGroup = false,
    String? difficulty,
    bool clearDifficulty = false,
    String? searchQuery,
  }) {
    return PaginatedExercisesState(
      items: items ?? this.items,
      nextCursor:
          clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      fromCache: fromCache ?? this.fromCache,
      category: clearCategory ? null : (category ?? this.category),
      ageGroup: clearAgeGroup ? null : (ageGroup ?? this.ageGroup),
      difficulty:
          clearDifficulty ? null : (difficulty ?? this.difficulty),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// State notifier driving the exercises-list screen.
///
/// Responsibilities:
/// * Fetch the first page on construction.
/// * Append subsequent pages via [loadMore].
/// * Reset and refetch when the user changes [setCategory].
/// * Hydrate from Hive cache when the network is unreachable.
class PaginatedExercisesNotifier
    extends StateNotifier<PaginatedExercisesState> {
  PaginatedExercisesNotifier(this._api)
      : super(const PaginatedExercisesState()) {
    // Kick off the first page eagerly so consumers don't need to call init().
    // Expose the future so tests can await deterministic completion.
    _ready = refresh();
  }

  final ExercisesApi _api;

  /// Future that resolves once the very first page-load attempt has settled
  /// (success, error, or cache-fallback). Tests can await this to avoid
  /// races with the eager constructor-driven fetch.
  late final Future<void> _ready;
  Future<void> get ready => _ready;

  static const _cacheKeyPrefix = 'exercises_page1';

  String _cacheKey(String? category, String? ageGroup, String? difficulty) {
    final cat = category ?? '_';
    final age = ageGroup ?? '_';
    final diff = difficulty ?? '_';
    return '$_cacheKeyPrefix:$cat:$age:$diff';
  }

  /// Reload the first page using the currently-selected filters. Safe to
  /// call from `RefreshIndicator`. To switch filters use [setCategory],
  /// [setAgeGroup], or [setDifficulty].
  Future<void> refresh() =>
      _refresh(state.category, state.ageGroup, state.difficulty);

  /// Switch the category filter and reload from page 1.
  Future<void> setCategory(String? category) async {
    if (category == state.category) return;
    await _refresh(category, state.ageGroup, state.difficulty);
  }

  /// Switch the age-group filter and reload from page 1.
  Future<void> setAgeGroup(String? ageGroup) async {
    if (ageGroup == state.ageGroup) return;
    await _refresh(state.category, ageGroup, state.difficulty);
  }

  /// Switch the difficulty filter and reload from page 1. Tokens follow
  /// the API convention: "easy", "medium", "hard". Pass `null` for "any".
  Future<void> setDifficulty(String? difficulty) async {
    if (difficulty == state.difficulty) return;
    await _refresh(state.category, state.ageGroup, difficulty);
  }

  /// Update the free-text search query. Filtering happens client-side over
  /// the items already loaded — no network round-trip is incurred. Whitespace
  /// is preserved as-typed so the text field stays in sync, but matching
  /// runs against a trimmed/lower-cased copy (see [PaginatedExercisesState]).
  void setSearchQuery(String query) {
    if (query == state.searchQuery) return;
    state = state.copyWith(searchQuery: query);
  }

  /// Convenience wrapper that wipes the active query.
  void clearSearch() => setSearchQuery('');

  /// Internal: load the first page of [category] + [ageGroup] +
  /// [difficulty]. Pass `null` for "any". Always honours the requested
  /// values (no falling back to the existing state filters).
  Future<void> _refresh(
    String? category,
    String? ageGroup,
    String? difficulty,
  ) async {
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
      items: const [],
      hasMore: false,
      clearNextCursor: true,
      fromCache: false,
      category: category,
      clearCategory: category == null,
      ageGroup: ageGroup,
      clearAgeGroup: ageGroup == null,
      difficulty: difficulty,
      clearDifficulty: difficulty == null,
    );

    try {
      final res = await _api.list(
        category: category,
        ageGroup: ageGroup,
        difficulty: difficulty,
      );
      // Persist first page so we can show something offline.
      try {
        await OfflineCache.save(
          _cacheKey(category, ageGroup, difficulty),
          res.items.map(_toJson).toList(),
        );
      } catch (_) {/* best effort */}

      state = state.copyWith(
        items: res.items,
        nextCursor: res.nextCursor,
        clearNextCursor: res.nextCursor == null,
        hasMore: res.hasMore,
        isLoading: false,
        fromCache: false,
        clearError: true,
      );
    } catch (e) {
      // Network failed — try the offline cache.
      final cached =
          OfflineCache.read(_cacheKey(category, ageGroup, difficulty));
      if (cached is List) {
        final items = cached
            .whereType<Map>()
            .map((m) => Exercise.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        state = state.copyWith(
          items: items,
          isLoading: false,
          fromCache: true,
          hasMore: false,
          clearNextCursor: true,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: e,
          fromCache: false,
          hasMore: false,
        );
      }
    }
  }

  /// Append the next page if there is one and we're not already loading.
  Future<void> loadMore() async {
    if (state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.nextCursor == null) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final res = await _api.list(
        category: state.category,
        ageGroup: state.ageGroup,
        difficulty: state.difficulty,
        cursor: state.nextCursor,
      );
      state = state.copyWith(
        items: [...state.items, ...res.items],
        nextCursor: res.nextCursor,
        clearNextCursor: res.nextCursor == null,
        hasMore: res.hasMore,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (e) {
      // Keep what we have; surface the error so the screen can show a retry.
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  Map<String, dynamic> _toJson(Exercise e) => {
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
}

/// Provider for the paginated exercises list. The list screen reads this;
/// the home screen continues to use the simpler [exercisesProvider].
final paginatedExercisesProvider = StateNotifierProvider.autoDispose<
    PaginatedExercisesNotifier, PaginatedExercisesState>(
  (ref) => PaginatedExercisesNotifier(ref.watch(exercisesApiProvider)),
);
