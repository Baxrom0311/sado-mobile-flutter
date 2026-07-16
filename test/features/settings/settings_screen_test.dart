import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/api_client.dart';
import 'package:sado_mobile/data/local/preferences.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/settings/settings_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

/// In-memory [Preferences] fake mirroring the one used by `preferences_test.dart`.
/// Lets us assert that toggles in the UI actually persist.
class _FakePreferences implements Preferences {
  String? _saved;
  bool _notif;
  AudioQuality _audio;
  _FakePreferences({
    String? initialLocale,
    bool notificationsEnabled = true,
    AudioQuality audioQuality = AudioQuality.standard,
  })  : _saved = initialLocale,
        _notif = notificationsEnabled,
        _audio = audioQuality;

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
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Auth notifier that yields a stable authenticated user and exposes
/// whether [logout] was called so the settings test can verify the
/// destructive action wires through.
class _StaticAuthNotifier extends AuthNotifier {
  _StaticAuthNotifier(super.api, super.ref, User initial) {
    state = AuthState(status: AuthStatus.authenticated, user: initial);
  }

  bool didLogout = false;

  @override
  Future<void> logout() async {
    didLogout = true;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

User _user() => User(
      id: 'u1',
      email: 'parent@sado.uz',
      fullName: 'Aziz Karimov',
      role: 'parent',
      language: 'uz',
      isActive: true,
      isVerified: true,
      createdAt: DateTime.utc(2024, 1, 1),
    );

/// Stub Dio that resolves any request locally — the settings screen does not
/// hit the network directly, but [AuthNotifier]'s `_init()` does call `me()`
/// before the override takes over, so we keep this safe.
Dio _stubDio() {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: const <String, dynamic>{},
      ));
    },
  ));
  return dio;
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/profile',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('PROFILE_HOME'))),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('LOGIN_HOME'))),
      ),
    ],
  );
}

Widget _wrap({required _FakePreferences prefs}) {
  return ProviderScope(
    overrides: [
      preferencesProvider.overrideWithValue(prefs),
      dioProvider.overrideWithValue(_stubDio()),
    ],
    child: Consumer(
      builder: (ctx, ref, _) {
        final locale = ref.watch(localeProvider);
        return MaterialApp.router(
          theme: AppTheme.light,
          localizationsDelegates: const [
            L.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L.supportedLocales,
          locale: locale,
          routerConfig: _router(),
        );
      },
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

/// Scrolls the settings ListView until [finder] is on-screen so we can
/// safely tap into widgets that live below the initial viewport.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets(
      'SettingsScreen renders language, notifications, audio quality and about sections',
      (tester) async {
    final prefs = _FakePreferences();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await _settle(tester);

    // Section titles are rendered uppercase by _SectionTitle. We use
    // skipOffstage:false because the ListView clips off-screen items in
    // test viewport, but they still exist in the tree.
    expect(find.text('TIL', skipOffstage: false), findsOneWidget);
    expect(
      find.text('BILDIRISHNOMALAR', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('AUDIO SIFATI', skipOffstage: false), findsOneWidget);
    expect(find.text('ILOVA HAQIDA', skipOffstage: false), findsOneWidget);

    // Both language tiles are visible at the top of the list.
    expect(find.text('O\'zbek'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);

    // All three audio quality tiles render (may need to scroll to find).
    expect(find.text('Past', skipOffstage: false), findsOneWidget);
    expect(find.text('Standart', skipOffstage: false), findsOneWidget);
    expect(find.text('Yuqori', skipOffstage: false), findsOneWidget);

    // Notifications switch is on by default.
    final sw = tester.widget<SwitchListTile>(
      find.byKey(
        const Key('settings.notifications.toggle'),
        skipOffstage: false,
      ),
    );
    expect(sw.value, isTrue);

    await _disposeTree(tester);
  });

  testWidgets(
      'SettingsScreen tapping Русский updates locale and persists the choice',
      (tester) async {
    final prefs = _FakePreferences();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await _settle(tester);

    expect(prefs.savedLocaleCode, isNull);

    await tester.tap(find.text('Русский'));
    await _settle(tester);

    expect(prefs.savedLocaleCode, 'ru');
    // After switching, the localized strings re-render in Russian.
    // The "О приложении" section title appears uppercased somewhere
    // below the fold — search the whole tree.
    expect(find.text('О ПРИЛОЖЕНИИ', skipOffstage: false), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'SettingsScreen toggling notifications persists the new value',
      (tester) async {
    final prefs = _FakePreferences();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await _settle(tester);

    expect(prefs.notificationsEnabled, isTrue);

    final toggle = find.byKey(
      const Key('settings.notifications.toggle'),
      skipOffstage: false,
    );
    await _scrollTo(tester, toggle);
    await tester.tap(toggle);
    await _settle(tester);

    expect(prefs.notificationsEnabled, isFalse);

    final sw = tester.widget<SwitchListTile>(toggle);
    expect(sw.value, isFalse);

    await _disposeTree(tester);
  });

  testWidgets(
      'SettingsScreen selecting High audio quality persists the new tier',
      (tester) async {
    final prefs = _FakePreferences();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await _settle(tester);

    expect(prefs.audioQuality, AudioQuality.standard);

    final highTile = find.text('Yuqori', skipOffstage: false);
    await _scrollTo(tester, highTile);
    await tester.tap(highTile);
    await _settle(tester);

    expect(prefs.audioQuality, AudioQuality.high);

    await _disposeTree(tester);
  });

  testWidgets(
      'SettingsScreen restores persisted preferences on rebuild',
      (tester) async {
    final prefs = _FakePreferences(
      initialLocale: 'ru',
      notificationsEnabled: false,
      audioQuality: AudioQuality.low,
    );
    await tester.pumpWidget(_wrap(prefs: prefs));
    await _settle(tester);

    // Russian title is shown.
    expect(find.text('О ПРИЛОЖЕНИИ', skipOffstage: false), findsOneWidget);
    final sw = tester.widget<SwitchListTile>(
      find.byKey(
        const Key('settings.notifications.toggle'),
        skipOffstage: false,
      ),
    );
    expect(sw.value, isFalse);

    await _disposeTree(tester);
  });

  testWidgets(
      'SettingsScreen logout card opens a confirmation dialog and confirming logs out',
      (tester) async {
    final prefs = _FakePreferences();
    _StaticAuthNotifier? captured;

    final widget = ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        dioProvider.overrideWithValue(_stubDio()),
        authProvider.overrideWith((ref) {
          final n = _StaticAuthNotifier(
            ref.watch(authApiProvider),
            ref,
            _user(),
          );
          captured = n;
          return n;
        }),
      ],
      child: Consumer(
        builder: (ctx, ref, _) {
          final locale = ref.watch(localeProvider);
          // Pre-warm authProvider so the overridden factory runs and
          // `captured` is populated before the user taps the dialog.
          ref.watch(authProvider);
          return MaterialApp.router(
            theme: AppTheme.light,
            localizationsDelegates: const [
              L.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: L.supportedLocales,
            locale: locale,
            routerConfig: _router(),
          );
        },
      ),
    );

    await tester.pumpWidget(widget);
    await _settle(tester);

    // Logout card lives at the very bottom of the ListView — scroll until
    // the danger card becomes hittable, then tap it to open the dialog.
    final logoutCard = find.byKey(const Key('settings.logout.card'));
    await _scrollTo(tester, logoutCard);
    await tester.tap(logoutCard);
    await _settle(tester);

    // Dialog is shown, but the destructive action has NOT fired yet.
    expect(find.byKey(const Key('settings.logout.dialog')), findsOneWidget);
    expect(find.text('Chiqishni xohlaysizmi?'), findsOneWidget);
    expect(captured, isNotNull);
    expect(captured!.didLogout, isFalse);

    // Tapping "Chiqish" inside the dialog confirms the destructive action.
    await tester.tap(find.byKey(const Key('settings.logout.confirm')));
    await _settle(tester);

    expect(captured!.didLogout, isTrue);
    expect(find.byKey(const Key('settings.logout.dialog')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'SettingsScreen logout cancel keeps the user signed in',
      (tester) async {
    final prefs = _FakePreferences();
    _StaticAuthNotifier? captured;

    final widget = ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        dioProvider.overrideWithValue(_stubDio()),
        authProvider.overrideWith((ref) {
          final n = _StaticAuthNotifier(
            ref.watch(authApiProvider),
            ref,
            _user(),
          );
          captured = n;
          return n;
        }),
      ],
      child: Consumer(
        builder: (ctx, ref, _) {
          final locale = ref.watch(localeProvider);
          // Pre-warm authProvider so the override fires before the test
          // asserts on `captured`.
          ref.watch(authProvider);
          return MaterialApp.router(
            theme: AppTheme.light,
            localizationsDelegates: const [
              L.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: L.supportedLocales,
            locale: locale,
            routerConfig: _router(),
          );
        },
      ),
    );

    await tester.pumpWidget(widget);
    await _settle(tester);

    final logoutCard = find.byKey(const Key('settings.logout.card'));
    await _scrollTo(tester, logoutCard);
    await tester.tap(logoutCard);
    await _settle(tester);

    // Dialog visible; user dismisses it via Cancel.
    expect(find.byKey(const Key('settings.logout.dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings.logout.cancel')));
    await _settle(tester);

    // No logout fired and the dialog is gone.
    expect(captured, isNotNull);
    expect(captured!.didLogout, isFalse);
    expect(find.byKey(const Key('settings.logout.dialog')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'SettingsScreen renders the signed-in account header when an authed user is present',
      (tester) async {
    final prefs = _FakePreferences();

    final widget = ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        dioProvider.overrideWithValue(_stubDio()),
        authProvider.overrideWith((ref) {
          return _StaticAuthNotifier(
            ref.watch(authApiProvider),
            ref,
            _user(),
          );
        }),
      ],
      child: Consumer(
        builder: (ctx, ref, _) {
          final locale = ref.watch(localeProvider);
          return MaterialApp.router(
            theme: AppTheme.light,
            localizationsDelegates: const [
              L.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: L.supportedLocales,
            locale: locale,
            routerConfig: _router(),
          );
        },
      ),
    );

    await tester.pumpWidget(widget);
    await _settle(tester);

    // Account card surfaces the user's full name + email + the localized
    // "Kirilgan akkaunt" caption. The card itself carries a stable key so
    // tests can scroll it into view if the layout changes later.
    expect(find.byKey(const Key('settings.account.card')), findsOneWidget);
    expect(find.text('AKKAUNT', skipOffstage: false), findsOneWidget);
    expect(find.text('Kirilgan akkaunt'), findsOneWidget);
    expect(find.text('Aziz Karimov'), findsOneWidget);
    expect(find.text('parent@sado.uz'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'SettingsScreen tapping the support row surfaces the support snackbar',
      (tester) async {
    final prefs = _FakePreferences();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await _settle(tester);

    final supportRow = find.byKey(
      const Key('settings.about.support'),
      skipOffstage: false,
    );
    await _scrollTo(tester, supportRow);

    // Invoke the ListTile's onTap directly. The settings ListView lazily
    // mounts off-screen children and a hit-test tap can fall just outside
    // the row's centre after scrolling, which makes the gesture flake.
    // We're verifying wiring (the row is *connected* to a feedback path
    // that surfaces the email), not gesture routing.
    final tile = tester.widget<ListTile>(
      find.descendant(of: supportRow, matching: find.byType(ListTile)),
    );
    tile.onTap!();
    await _settle(tester);

    // A snackbar appears with the canonical support email embedded.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('support@sado.uz'), findsWidgets);

    await _disposeTree(tester);
  });

  testWidgets(
      'SettingsScreen tapping Terms & Privacy navigates to the About screen',
      (tester) async {
    final prefs = _FakePreferences();

    // Local router that knows about both /settings and /settings/about so
    // we can verify the navigation lands on the new About screen.
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/settings/about',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('ABOUT_SCREEN_LANDED')),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('PROFILE_HOME'))),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('LOGIN_HOME'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          dioProvider.overrideWithValue(_stubDio()),
        ],
        child: Consumer(
          builder: (ctx, ref, _) {
            final locale = ref.watch(localeProvider);
            return MaterialApp.router(
              theme: AppTheme.light,
              localizationsDelegates: const [
                L.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: L.supportedLocales,
              locale: locale,
              routerConfig: router,
            );
          },
        ),
      ),
    );
    await _settle(tester);

    final termsRow = find.byKey(
      const Key('settings.about.terms'),
      skipOffstage: false,
    );
    await _scrollTo(tester, termsRow);

    // Invoke the ListTile's onTap directly — same rationale as above:
    // we're testing wiring, not gesture coordinate math.
    final tile = tester.widget<ListTile>(
      find.descendant(of: termsRow, matching: find.byType(ListTile)),
    );
    tile.onTap!();
    await _settle(tester);

    expect(find.text('ABOUT_SCREEN_LANDED'), findsOneWidget);

    await _disposeTree(tester);
  });
}
