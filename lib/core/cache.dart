import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Simple offline cache: stores JSON-encoded API responses keyed by URL.
/// Used as a fallback when network calls fail.
///
/// Resilient to environments where Hive has not been initialised (e.g.
/// pure-Dart unit tests). When the box cannot be opened, [save] becomes a
/// silent no-op and [read] returns null — every caller already treats null
/// as "no cache available".
class OfflineCache {
  static const _boxName = 'sado_offline_cache';
  static Box? _box;
  static bool _initAttempted = false;

  /// Open the underlying Hive box. Best-effort — on failure (Hive not
  /// initialised, sandboxed test, etc.) we leave [_box] null and remember
  /// not to retry on every read/write.
  static Future<void> init() async {
    if (_box != null) return;
    if (_initAttempted) return;
    _initAttempted = true;
    try {
      _box = await Hive.openBox(_boxName);
    } catch (_) {
      // Hive uninitialised — remain in a no-op fallback mode.
      _box = null;
    }
  }

  /// Persist [value] under [key]. No-op when Hive is unavailable.
  static Future<void> save(String key, Object value) async {
    await init();
    final box = _box;
    if (box == null) return;
    try {
      await box.put(key, jsonEncode(value));
    } catch (_) {
      // Hive can throw synchronously if the box was closed — swallow.
    }
  }

  /// Decode the JSON value stored under [key], or null if missing/invalid.
  /// Never throws.
  static dynamic read(String key) {
    try {
      final raw = _box?.get(key);
      if (raw is String) {
        return jsonDecode(raw);
      }
    } catch (_) {/* fall through */}
    return null;
  }

  /// Wipe every cached entry. Best-effort.
  static Future<void> clear() async {
    await init();
    final box = _box;
    if (box == null) return;
    try {
      await box.clear();
    } catch (_) {/* best effort */}
  }

  /// Test-only: forget the open box and the "already attempted" flag so
  /// the next [init] call re-tries against a freshly-set-up Hive.
  static void debugResetForTesting() {
    _box = null;
    _initAttempted = false;
  }
}
