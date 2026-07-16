import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Audio capture quality tier — controls bitrate / sample rate at recording
/// time. Stored as a stable string token so we never have to migrate Hive
/// data when enum order changes.
enum AudioQuality {
  low('low'),
  standard('standard'),
  high('high');

  const AudioQuality(this.token);

  /// Persisted token. Stable across builds.
  final String token;

  static AudioQuality fromToken(String? raw, {AudioQuality fallback = AudioQuality.standard}) {
    for (final q in AudioQuality.values) {
      if (q.token == raw) return q;
    }
    return fallback;
  }
}

/// Lightweight key/value store for user-visible app preferences (locale,
/// notification opt-in, audio quality, future toggles like theme, etc.).
///
/// Backed by a single Hive box. Safe to call before [Hive.initFlutter] —
/// every method is best-effort and falls back to in-memory defaults so the
/// UI still works under flutter_test (where Hive is rarely initialized).
class Preferences {
  Preferences._(this._box);

  static const _boxName = 'sado_prefs';
  static const _localeKey = 'locale';
  static const _notificationsKey = 'notifications_enabled';
  static const _audioQualityKey = 'audio_quality';
  static const _onboardingSeenKey = 'onboarding_seen';

  final Box<dynamic>? _box;

  /// Open the underlying Hive box. If Hive is unavailable (e.g. tests
  /// without `Hive.initFlutter`), returns an instance backed by no box —
  /// reads return defaults and writes are no-ops.
  static Future<Preferences> open() async {
    try {
      final box = await Hive.openBox<dynamic>(_boxName);
      return Preferences._(box);
    } catch (_) {
      return Preferences._(null);
    }
  }

  /// Construct an in-memory only instance — used by tests that do not need
  /// persistence.
  factory Preferences.inMemory() => Preferences._(null);

  // --- Locale ---------------------------------------------------------------

  String? get savedLocaleCode {
    try {
      final raw = _box?.get(_localeKey);
      return raw is String ? raw : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setLocaleCode(String code) async {
    try {
      await _box?.put(_localeKey, code);
    } catch (_) {
      // Best effort — the StateNotifier still updates in-memory.
    }
  }

  // --- Notifications --------------------------------------------------------

  /// Defaults to `true` (opted-in) for first-launch users. Returns the saved
  /// value if one exists.
  bool get notificationsEnabled {
    try {
      final raw = _box?.get(_notificationsKey);
      return raw is bool ? raw : true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      await _box?.put(_notificationsKey, enabled);
    } catch (_) {}
  }

  // --- Audio quality --------------------------------------------------------

  AudioQuality get audioQuality {
    try {
      final raw = _box?.get(_audioQualityKey);
      return AudioQuality.fromToken(raw is String ? raw : null);
    } catch (_) {
      return AudioQuality.standard;
    }
  }

  Future<void> setAudioQuality(AudioQuality quality) async {
    try {
      await _box?.put(_audioQualityKey, quality.token);
    } catch (_) {}
  }

  // --- Onboarding -----------------------------------------------------------

  /// Whether the user has finished (or skipped) the onboarding carousel
  /// at least once. Defaults to `false` so first-launch users see it.
  bool get onboardingSeen {
    try {
      final raw = _box?.get(_onboardingSeenKey);
      return raw is bool ? raw : false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setOnboardingSeen(bool seen) async {
    try {
      await _box?.put(_onboardingSeenKey, seen);
    } catch (_) {}
  }
}

/// Set of locale codes the app actually ships translations for.
/// Anything else falls back to Uzbek.
const Set<String> _supportedLocales = {'uz', 'ru'};

/// Async-loaded preferences instance. Initialized eagerly in `main()`.
final preferencesProvider = Provider<Preferences>(
  (ref) => throw UnimplementedError(
    'preferencesProvider must be overridden in main()',
  ),
);

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._prefs) : super(_initial(_prefs));

  final Preferences _prefs;

  static Locale _initial(Preferences prefs) {
    final saved = prefs.savedLocaleCode;
    if (saved != null && _supportedLocales.contains(saved)) {
      return Locale(saved);
    }
    return const Locale('uz');
  }

  Future<void> setLocale(Locale locale) async {
    final code = _supportedLocales.contains(locale.languageCode)
        ? locale.languageCode
        : 'uz';
    state = Locale(code);
    await _prefs.setLocaleCode(code);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(ref.watch(preferencesProvider)),
);

// --- Notification preference ------------------------------------------------

class NotificationsEnabledNotifier extends StateNotifier<bool> {
  NotificationsEnabledNotifier(this._prefs) : super(_prefs.notificationsEnabled);

  final Preferences _prefs;

  Future<void> setEnabled(bool value) async {
    state = value;
    await _prefs.setNotificationsEnabled(value);
  }
}

final notificationsEnabledProvider =
    StateNotifierProvider<NotificationsEnabledNotifier, bool>(
  (ref) => NotificationsEnabledNotifier(ref.watch(preferencesProvider)),
);

// --- Audio quality preference ----------------------------------------------

class AudioQualityNotifier extends StateNotifier<AudioQuality> {
  AudioQualityNotifier(this._prefs) : super(_prefs.audioQuality);

  final Preferences _prefs;

  Future<void> setQuality(AudioQuality value) async {
    state = value;
    await _prefs.setAudioQuality(value);
  }
}

final audioQualityProvider =
    StateNotifierProvider<AudioQualityNotifier, AudioQuality>(
  (ref) => AudioQualityNotifier(ref.watch(preferencesProvider)),
);

// --- Onboarding-seen flag ---------------------------------------------------

/// Tracks whether the onboarding carousel has been completed (or skipped)
/// at least once. Persisted via [Preferences] so it survives reinstalls of
/// the underlying app process but resets cleanly when the user clears app
/// data — exactly what we want for "first-time experience".
class OnboardingSeenNotifier extends StateNotifier<bool> {
  OnboardingSeenNotifier(this._prefs) : super(_prefs.onboardingSeen);

  final Preferences _prefs;

  Future<void> markSeen() async {
    if (state) return;
    state = true;
    await _prefs.setOnboardingSeen(true);
  }

  /// Test/debug only — clears the flag so the onboarding flow can be
  /// re-exercised without uninstalling.
  Future<void> reset() async {
    state = false;
    await _prefs.setOnboardingSeen(false);
  }
}

final onboardingSeenProvider =
    StateNotifierProvider<OnboardingSeenNotifier, bool>(
  (ref) => OnboardingSeenNotifier(ref.watch(preferencesProvider)),
);
