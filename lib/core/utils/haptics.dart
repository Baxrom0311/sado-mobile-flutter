import 'package:flutter/services.dart';

/// Thin wrapper over [HapticFeedback] with semantic intents.
///
/// Use [light] for routine button presses, [medium] for primary actions
/// (record start/stop), [heavy] for destructive confirmations, [selection]
/// for picker / chip taps, [success] for level-up + badge unlock and
/// [error] for failed submissions.
///
/// All calls are fire-and-forget. They never throw; the underlying
/// platform channel returns void on platforms that don't support
/// haptics (web, desktop) so we silently swallow any errors.
abstract final class Haptics {
  /// Soft tap. Suitable for non-destructive button presses.
  static Future<void> light() => _safe(HapticFeedback.lightImpact);

  /// Medium tap. Suitable for primary interactions (record, submit).
  static Future<void> medium() => _safe(HapticFeedback.mediumImpact);

  /// Strong tap. Reserve for destructive confirmations.
  static Future<void> heavy() => _safe(HapticFeedback.heavyImpact);

  /// Subtle tick used for selectors, chips and toggles.
  static Future<void> selection() => _safe(HapticFeedback.selectionClick);

  /// Two-pulse celebration: ideal for badge unlock + level-up.
  static Future<void> success() async {
    await _safe(HapticFeedback.lightImpact);
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await _safe(HapticFeedback.mediumImpact);
  }

  /// Hard double-pulse for failures. Distinct enough from [success] that
  /// the user doesn't have to look at the screen to know what happened.
  static Future<void> error() async {
    await _safe(HapticFeedback.heavyImpact);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await _safe(HapticFeedback.heavyImpact);
  }

  static Future<void> _safe(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (_) {
      // Platforms without haptics throw a MissingPluginException; ignore
      // so callers can use Haptics.light() unconditionally.
    }
  }
}
