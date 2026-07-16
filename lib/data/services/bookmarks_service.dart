import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

/// Persistent store for the parent-curated set of bookmarked exercise
/// IDs.
///
/// The store is intentionally local-only — bookmarks are a personal
/// shortcut layer that should survive app relaunches but must not block
/// on the network. Backed by a single Hive box that holds an entry per
/// exercise id (value: ISO-8601 timestamp). Storing the timestamp lets
/// us show "Recently saved" ordering in the bookmarks screen later
/// without an additional cache.
///
/// Every operation is best-effort: when Hive is unavailable (typical in
/// flutter_test where `Hive.initFlutter` was never called) the service
/// silently degrades to an in-memory implementation so widget tests
/// don't have to stub an entire plugin.
class BookmarksService {
  BookmarksService._(this._box, [Map<String, String>? memory])
      : _memory = memory ?? <String, String>{};

  static const _boxName = 'sado_exercise_bookmarks';

  final Box<dynamic>? _box;
  final Map<String, String> _memory;

  /// Open the persistent box. Falls back to an in-memory store if Hive
  /// has not been initialised on this isolate.
  static Future<BookmarksService> open() async {
    try {
      final box = await Hive.openBox<dynamic>(_boxName);
      return BookmarksService._(box);
    } catch (_) {
      return BookmarksService._(null);
    }
  }

  /// Build a service backed by an explicit Hive box. Used by tests so
  /// they can pass a temp-directory box without going through the
  /// global `Hive.openBox` plumbing.
  factory BookmarksService.fromBox(Box<dynamic> box) =>
      BookmarksService._(box);

  /// Build an in-memory only service. Useful for widget tests that
  /// don't need persistence.
  factory BookmarksService.inMemory() => BookmarksService._(null);

  /// Snapshot of every saved exercise id, newest-first.
  ///
  /// "Newest" is defined by the timestamp recorded the last time the
  /// id was added. Removing and re-adding an id refreshes its position.
  List<String> all() {
    final entries = _entries();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList(growable: false);
  }

  /// Number of saved exercises. Cheap — does not allocate.
  int get count => _entriesIterable().length;

  /// Whether [exerciseId] is currently bookmarked.
  bool contains(String exerciseId) {
    if (exerciseId.isEmpty) return false;
    try {
      if (_box != null) return _box.containsKey(exerciseId);
    } catch (_) {}
    return _memory.containsKey(exerciseId);
  }

  /// Add [exerciseId] to the bookmarks. Idempotent: re-adding refreshes
  /// the saved-at timestamp so the entry floats back to the top of
  /// [all].
  Future<void> add(String exerciseId) async {
    if (exerciseId.isEmpty) return;
    final stamp = DateTime.now().toUtc().toIso8601String();
    try {
      if (_box != null) {
        await _box.put(exerciseId, stamp);
        return;
      }
    } catch (_) {
      // Fall through to the in-memory store.
    }
    _memory[exerciseId] = stamp;
  }

  /// Remove [exerciseId] from the bookmarks. Safe to call for an id
  /// that was never bookmarked.
  Future<void> remove(String exerciseId) async {
    if (exerciseId.isEmpty) return;
    try {
      if (_box != null) {
        await _box.delete(exerciseId);
        return;
      }
    } catch (_) {}
    _memory.remove(exerciseId);
  }

  /// Toggle the bookmark state for [exerciseId] and return the new
  /// state (`true` when it is bookmarked after the call, `false`
  /// otherwise). Convenience for UI toggles where the caller doesn't
  /// want to read state separately.
  Future<bool> toggle(String exerciseId) async {
    if (contains(exerciseId)) {
      await remove(exerciseId);
      return false;
    }
    await add(exerciseId);
    return true;
  }

  /// Wipe the whole store. Test-only / settings hook.
  Future<void> clear() async {
    try {
      if (_box != null) {
        await _box.clear();
        return;
      }
    } catch (_) {}
    _memory.clear();
  }

  // --- internals ----------------------------------------------------------

  Iterable<MapEntry<String, String>> _entriesIterable() sync* {
    try {
      if (_box != null) {
        for (final key in _box.keys) {
          if (key is! String) continue;
          final raw = _box.get(key);
          if (raw is String) yield MapEntry(key, raw);
        }
        return;
      }
    } catch (_) {}
    yield* _memory.entries;
  }

  List<MapEntry<String, String>> _entries() =>
      _entriesIterable().toList(growable: false);
}
