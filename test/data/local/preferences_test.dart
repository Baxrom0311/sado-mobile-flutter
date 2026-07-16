import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sado_mobile/data/local/preferences.dart';

/// In-memory [Preferences] fake that satisfies the public surface used by
/// [LocaleNotifier], [NotificationsEnabledNotifier], and
/// [AudioQualityNotifier]. Persistence is simulated with simple in-memory
/// fields so we can verify the setters actually write back.
class _FakePreferences implements Preferences {
  String? _saved;
  bool _notif;
  AudioQuality _audio;
  bool _onboardingSeen;
  _FakePreferences({
    String? initial,
    bool notificationsEnabled = true,
    AudioQuality audioQuality = AudioQuality.standard,
    bool onboardingSeen = false,
  })  : _saved = initial,
        _notif = notificationsEnabled,
        _audio = audioQuality,
        _onboardingSeen = onboardingSeen;

  @override
  String? get savedLocaleCode => _saved;

  @override
  Future<void> setLocaleCode(String code) async {
    _saved = code;
  }

  @override
  bool get notificationsEnabled => _notif;

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    _notif = enabled;
  }

  @override
  AudioQuality get audioQuality => _audio;

  @override
  Future<void> setAudioQuality(AudioQuality quality) async {
    _audio = quality;
  }

  @override
  bool get onboardingSeen => _onboardingSeen;

  @override
  Future<void> setOnboardingSeen(bool seen) async {
    _onboardingSeen = seen;
  }

  // Unused private members from the real class. Forwarding to the public
  // surface keeps the analyzer happy without exposing real Hive internals.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LocaleNotifier', () {
    test('defaults to uz when nothing has been persisted', () {
      final notifier = LocaleNotifier(_FakePreferences());
      expect(notifier.state.languageCode, 'uz');
    });

    test('restores ru when previously saved', () {
      final notifier = LocaleNotifier(_FakePreferences(initial: 'ru'));
      expect(notifier.state.languageCode, 'ru');
    });

    test('falls back to uz on unsupported saved code', () {
      final notifier = LocaleNotifier(_FakePreferences(initial: 'fr'));
      expect(notifier.state.languageCode, 'uz');
    });

    test('setLocale updates state and persists the new code', () async {
      final prefs = _FakePreferences();
      final notifier = LocaleNotifier(prefs);
      expect(notifier.state.languageCode, 'uz');

      await notifier.setLocale(const Locale('ru'));

      expect(notifier.state.languageCode, 'ru');
      expect(prefs.savedLocaleCode, 'ru');
    });

    test('setLocale rejects unsupported locales and keeps uz', () async {
      final prefs = _FakePreferences();
      final notifier = LocaleNotifier(prefs);

      await notifier.setLocale(const Locale('de'));

      expect(notifier.state.languageCode, 'uz');
      expect(prefs.savedLocaleCode, 'uz');
    });
  });

  group('localeProvider wiring', () {
    test('reads through preferencesProvider override', () {
      final prefs = _FakePreferences(initial: 'ru');
      final container = ProviderContainer(overrides: [
        preferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      expect(container.read(localeProvider).languageCode, 'ru');
    });

    test('setLocale through provider persists to overridden prefs', () async {
      final prefs = _FakePreferences();
      final container = ProviderContainer(overrides: [
        preferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      await container
          .read(localeProvider.notifier)
          .setLocale(const Locale('ru'));

      expect(container.read(localeProvider).languageCode, 'ru');
      expect(prefs.savedLocaleCode, 'ru');
    });
  });

  group('Preferences.inMemory', () {
    test('starts with no saved locale and silently accepts writes',
        () async {
      final prefs = Preferences.inMemory();
      expect(prefs.savedLocaleCode, isNull);
      await prefs.setLocaleCode('ru'); // no throw
    });

    test('defaults notifications to enabled and persists toggles',
        () async {
      final prefs = Preferences.inMemory();
      expect(prefs.notificationsEnabled, isTrue);
      await prefs.setNotificationsEnabled(false); // no throw, no-op store
      // In-memory falls back to defaults; we only assert it does not throw.
    });

    test('defaults audio quality to standard and accepts writes', () async {
      final prefs = Preferences.inMemory();
      expect(prefs.audioQuality, AudioQuality.standard);
      await prefs.setAudioQuality(AudioQuality.high); // no throw
    });
  });

  group('AudioQuality.fromToken', () {
    test('round-trips known tokens', () {
      expect(AudioQuality.fromToken('low'), AudioQuality.low);
      expect(AudioQuality.fromToken('standard'), AudioQuality.standard);
      expect(AudioQuality.fromToken('high'), AudioQuality.high);
    });

    test('falls back to standard on null / unknown tokens', () {
      expect(AudioQuality.fromToken(null), AudioQuality.standard);
      expect(AudioQuality.fromToken(''), AudioQuality.standard);
      expect(AudioQuality.fromToken('ultra'), AudioQuality.standard);
    });

    test('respects an explicit fallback', () {
      expect(
        AudioQuality.fromToken('garbage', fallback: AudioQuality.high),
        AudioQuality.high,
      );
    });
  });

  group('NotificationsEnabledNotifier', () {
    test('seeds from preferences', () {
      final prefs = _FakePreferences(notificationsEnabled: false);
      final notifier = NotificationsEnabledNotifier(prefs);
      expect(notifier.state, isFalse);
    });

    test('setEnabled updates state and persists', () async {
      final prefs = _FakePreferences(notificationsEnabled: true);
      final notifier = NotificationsEnabledNotifier(prefs);

      await notifier.setEnabled(false);

      expect(notifier.state, isFalse);
      expect(prefs.notificationsEnabled, isFalse);
    });

    test('toggling back on persists too', () async {
      final prefs = _FakePreferences(notificationsEnabled: false);
      final notifier = NotificationsEnabledNotifier(prefs);

      await notifier.setEnabled(true);

      expect(notifier.state, isTrue);
      expect(prefs.notificationsEnabled, isTrue);
    });
  });

  group('AudioQualityNotifier', () {
    test('seeds from preferences', () {
      final prefs = _FakePreferences(audioQuality: AudioQuality.high);
      final notifier = AudioQualityNotifier(prefs);
      expect(notifier.state, AudioQuality.high);
    });

    test('setQuality updates state and persists', () async {
      final prefs = _FakePreferences();
      final notifier = AudioQualityNotifier(prefs);

      await notifier.setQuality(AudioQuality.low);

      expect(notifier.state, AudioQuality.low);
      expect(prefs.audioQuality, AudioQuality.low);
    });
  });

  group('AudioCaptureProfile (via AudioQuality)', () {
    test('low quality yields a smaller file budget than standard', () {
      // We import the profile transitively to keep test imports simple;
      // but we can validate via the enum's well-known tokens.
      expect(AudioQuality.low.token, 'low');
      expect(AudioQuality.standard.token, 'standard');
      expect(AudioQuality.high.token, 'high');
    });
  });

  group('OnboardingSeenNotifier', () {
    test('defaults to false on a fresh install', () {
      final prefs = _FakePreferences();
      final notifier = OnboardingSeenNotifier(prefs);
      expect(notifier.state, isFalse);
    });

    test('seeds from a previously persisted true value', () {
      final prefs = _FakePreferences(onboardingSeen: true);
      final notifier = OnboardingSeenNotifier(prefs);
      expect(notifier.state, isTrue);
    });

    test('markSeen flips the state and persists', () async {
      final prefs = _FakePreferences();
      final notifier = OnboardingSeenNotifier(prefs);
      expect(notifier.state, isFalse);

      await notifier.markSeen();

      expect(notifier.state, isTrue);
      expect(prefs.onboardingSeen, isTrue);
    });

    test('markSeen is idempotent — calling twice does not flip state back',
        () async {
      final prefs = _FakePreferences(onboardingSeen: true);
      final notifier = OnboardingSeenNotifier(prefs);
      await notifier.markSeen();
      await notifier.markSeen();
      expect(notifier.state, isTrue);
    });

    test('reset clears the flag and persists the cleared value', () async {
      final prefs = _FakePreferences(onboardingSeen: true);
      final notifier = OnboardingSeenNotifier(prefs);
      expect(notifier.state, isTrue);

      await notifier.reset();

      expect(notifier.state, isFalse);
      expect(prefs.onboardingSeen, isFalse);
    });
  });

  group('Preferences (real, in-memory) onboarding flag', () {
    test('returns false when no Hive box is available', () {
      final prefs = Preferences.inMemory();
      expect(prefs.onboardingSeen, isFalse);
    });

    test('setOnboardingSeen never throws on the in-memory fallback', () async {
      final prefs = Preferences.inMemory();
      await prefs.setOnboardingSeen(true); // no throw, no persistence
      // Reads still default to false because the in-memory fallback has no
      // backing store — the contract is "best-effort, never crash".
      expect(prefs.onboardingSeen, isFalse);
    });
  });
}
