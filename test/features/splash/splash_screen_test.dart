import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/api_client.dart';
import 'package:sado_mobile/data/local/preferences.dart';
import 'package:sado_mobile/features/splash/splash_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/loaders.dart';
import 'package:sado_mobile/widgets/parrot_mascot.dart';

/// Mutable holder so each test can configure its own session before
/// `pumpWidget` is called. Mirrors the way a real device boots: the auth
/// notifier's `_init()` reads from secure storage, and (if there's a token)
/// calls `/users/me` to hydrate the user object.
class _Session {
  String? accessToken;
  String? refreshToken;
}

const _storageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void _bindStorage(_Session session) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_storageChannel, (call) async {
    if (call.method == 'read') {
      final args = (call.arguments as Map?)?.cast<String, dynamic>();
      final key = args?['key'] as String?;
      if (key == 'access_token') return session.accessToken;
      if (key == 'refresh_token') return session.refreshToken;
      return null;
    }
    if (call.method == 'readAll') {
      return <String, String>{
        if (session.accessToken != null) 'access_token': session.accessToken!,
        if (session.refreshToken != null) 'refresh_token': session.refreshToken!,
      };
    }
    return null;
  });
}

/// Tiny stub Dio that satisfies just `/users/me` (the only call the auth
/// notifier issues during `_init()`).
Dio _stubDio({bool networkError = false}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    if (networkError) {
      return handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'SocketException: test',
      ));
    }
    if (options.path == '/users/me') {
      return handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: const <String, dynamic>{
          'id': 'u1',
          'email': 'parent@sado.uz',
          'full_name': 'Aziz Karimov',
          'role': 'parent',
          'language': 'uz',
          'is_active': true,
          'is_verified': true,
          'created_at': '2024-01-01T00:00:00Z',
        },
      ));
    }
    handler.resolve(Response<dynamic>(
      requestOptions: options,
      statusCode: 204,
      data: null,
    ));
  }));
  return dio;
}

/// Tiny in-memory [Preferences] stub. Only needs to satisfy the
/// onboarding-seen contract used by the splash; everything else is forwarded
/// to safe defaults.
class _StubPreferences implements Preferences {
  bool _onboardingSeen;
  _StubPreferences({bool onboardingSeen = false})
      : _onboardingSeen = onboardingSeen;

  @override
  bool get onboardingSeen => _onboardingSeen;

  @override
  Future<void> setOnboardingSeen(bool seen) async {
    _onboardingSeen = seen;
  }

  @override
  String? get savedLocaleCode => null;

  @override
  Future<void> setLocaleCode(String code) async {}

  @override
  bool get notificationsEnabled => true;

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {}

  @override
  AudioQuality get audioQuality => AudioQuality.standard;

  @override
  Future<void> setAudioQuality(AudioQuality quality) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GoRouter _stubRouter() {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('home-stub')),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const Scaffold(body: Text('onboarding-stub')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('login-stub')),
      ),
    ],
  );
}

Widget _wrap({
  required Dio dio,
  String locale = 'uz',
  GoRouter? router,
  Preferences? prefs,
}) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      preferencesProvider.overrideWithValue(prefs ?? _StubPreferences()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      locale: Locale(locale),
      routerConfig: router ?? _stubRouter(),
    ),
  );
}

/// Drains the splash → destination handoff: the screen waits 1400ms before
/// it navigates, then GoRouter rebuilds. We deliberately pump in small
/// chunks instead of `pumpAndSettle` because the parrot mascot has looping
/// animations that would prevent settling.
Future<void> _waitForRedirect(WidgetTester tester) async {
  // _init() chains microtasks (storage read → me() → state update). Pump a
  // few short slices so each microtask boundary is reached before the
  // splash's 1400ms timer fires.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  // Advance past the splash delay so `context.go(...)` is invoked.
  await tester.pump(const Duration(milliseconds: 1500));
  // Drive the page transition to completion. Flutter's
  // `pump(Duration)` advances the test clock and renders ONE frame; the
  // outgoing route's AnimationController only fully detaches after a
  // few additional frames have run. A granular cadence covers the
  // ~500ms platform-default Material transition without hanging on the
  // mascot's looping ticker (which `pumpAndSettle` would).
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Cleans up flutter_animate timers and the splash's 1400ms scheduling
/// future so the test framework doesn't trip the "Timer is still pending"
/// invariant on teardown.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Session session;

  setUp(() {
    session = _Session();
    _bindStorage(session);

    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize =
        const Size(390 * 3, 844 * 3);
    binding.platformDispatcher.views.first.devicePixelRatio = 3.0;
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storageChannel, null);
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('SplashScreen', () {
    testWidgets(
      'renders the parrot mascot, app title, tagline and the dots loader',
      (tester) async {
        await tester.pumpWidget(_wrap(dio: _stubDio()));
        // Pump one frame to let the screen build, but stop before the
        // 1400ms delay so we observe the splash layout itself rather than
        // the post-redirect destination.
        await tester.pump();

        expect(find.byType(ParrotMascot), findsOneWidget);
        // appTitle (uz) and splashTagline (uz) come from the .arb file.
        expect(find.text('SADO - Nutq Terapiyasi'), findsOneWidget);
        expect(find.text('Bolalar uchun aqlli nutq do\'sti'), findsOneWidget);
        // We use a custom branded loader instead of the Material default
        // CircularProgressIndicator — verify both halves of that contract.
        expect(find.byType(DotsLoader), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await _disposeTree(tester);
      },
    );

    testWidgets(
      'with no saved token, redirects to /onboarding after the splash delay',
      (tester) async {
        // Empty session → secure storage returns null for access_token.
        await tester.pumpWidget(_wrap(dio: _stubDio()));
        await tester.pump();
        await _waitForRedirect(tester);

        expect(find.text('onboarding-stub'), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        await _disposeTree(tester);
      },
    );

    testWidgets(
      'returning unauthenticated user with onboarding seen skips the carousel',
      (tester) async {
        await tester.pumpWidget(_wrap(
          dio: _stubDio(),
          prefs: _StubPreferences(onboardingSeen: true),
        ));
        await tester.pump();
        await _waitForRedirect(tester);

        // Should land on /login, NOT /onboarding.
        expect(find.text('login-stub'), findsOneWidget);
        expect(find.text('onboarding-stub'), findsNothing);
        expect(find.byType(SplashScreen), findsNothing);
        await _disposeTree(tester);
      },
    );

    testWidgets(
      'with a valid saved token, redirects to /',
      (tester) async {
        // Pre-populate the storage stub so `_init` walks the
        // authenticated branch and asks the API for the current user.
        session.accessToken = 'fake.jwt';
        session.refreshToken = 'fake.refresh';

        await tester.pumpWidget(_wrap(dio: _stubDio()));
        await tester.pump();
        await _waitForRedirect(tester);

        expect(find.text('home-stub'), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        await _disposeTree(tester);
      },
    );

    testWidgets(
      'with a saved token but the API is offline, still routes to /',
      (tester) async {
        // The auth notifier's `_init` falls back to "authenticated without
        // user" when the API is unreachable so the user stays inside the
        // app — verify that boot path leads to /, not /onboarding.
        session.accessToken = 'fake.jwt';
        session.refreshToken = 'fake.refresh';

        await tester.pumpWidget(_wrap(dio: _stubDio(networkError: true)));
        await tester.pump();
        await _waitForRedirect(tester);

        expect(find.text('home-stub'), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        await _disposeTree(tester);
      },
    );

    testWidgets(
      'still uses the branded loader (not Material default) under locale=ru',
      (tester) async {
        await tester.pumpWidget(_wrap(dio: _stubDio(), locale: 'ru'));
        await tester.pump();

        // Sanity check: the Uzbek tagline must NOT appear in ru mode.
        expect(
          find.text('Bolalar uchun aqlli nutq do\'sti'),
          findsNothing,
        );
        // Brand UI invariants apply across locales.
        expect(find.byType(ParrotMascot), findsOneWidget);
        expect(find.byType(DotsLoader), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await _disposeTree(tester);
      },
    );
  });
}
