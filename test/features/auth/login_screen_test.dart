import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/api_client.dart';
import 'package:sado_mobile/features/auth/login_screen.dart';
import 'package:sado_mobile/features/auth/register_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/premium_button.dart';

/// Captures one POST body for assertion.
class _Capture {
  String? method;
  String? path;
  Map<String, dynamic>? body;

  /// Records this request only if [_Capture] is still empty. Lets the test
  /// assert against the FIRST request issued (e.g. /auth/login) and ignore
  /// the follow-up calls the AuthNotifier makes (/users/me etc).
  void recordFirst({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) {
    if (this.method != null) return;
    this.method = method;
    this.path = path;
    this.body = body;
  }
}

/// Stub Dio that auto-responds to /auth/login + /users/me + /auth/logout.
/// On 401-style failures we instead return [statusCode] with [errorBody].
Dio _stubDio({
  _Capture? capture,
  int loginStatus = 200,
  bool networkError = false,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      capture?.recordFirst(
        method: options.method,
        path: options.path,
        body: options.data is Map<String, dynamic>
            ? Map<String, dynamic>.from(options.data as Map<String, dynamic>)
            : null,
      );
      if (networkError) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'SocketException: Network is unreachable',
          ),
        );
        return;
      }
      if (options.path == '/auth/login') {
        handler.resolve(Response<dynamic>(
          requestOptions: options,
          statusCode: loginStatus,
          data: loginStatus == 200
              ? const {
                  'access_token': 'a',
                  'refresh_token': 'r',
                  'expires_in': 3600,
                }
              : const {'detail': 'invalid_credentials'},
        ));
        return;
      }
      if (options.path == '/users/me') {
        handler.resolve(Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: const {
            'id': 'u-1',
            'email': 'parent@sado.uz',
            'full_name': 'Demo Parent',
            'role': 'parent',
            'language': 'uz',
            'is_active': true,
            'is_verified': true,
            'created_at': '2024-01-01T00:00:00Z',
          },
        ));
        return;
      }
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 204,
        data: null,
      ));
    },
  ));
  return dio;
}

GoRouter _router() => GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('home-stub'))),
        ),
      ],
    );

Widget _wrap({
  required Dio dio,
  GoRouter? router,
}) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
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
      locale: const Locale('uz'),
      routerConfig: router ?? _router(),
    ),
  );
}

/// Tears down the widget tree so any [Timer] schedules from `flutter_animate`
/// delay-based effects have a chance to fire and the parrot mascot's
/// AnimationControllers are disposed cleanly. Without this, tests that
/// render the mascot or animate-decorated widgets fail at teardown with
/// "A Timer is still pending".
Future<void> _disposeTree(WidgetTester tester) async {
  // Let any in-flight animations / delays elapse.
  await tester.pump(const Duration(milliseconds: 800));
  // Replace the tree with a bare widget so dispose() runs on all stateful
  // widgets including ParrotMascot and Animate.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Stub flutter_secure_storage so token writes/reads don't hit a platform.
  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  group('LoginScreen', () {
    testWidgets('prefills demo credentials so QA can sign in instantly',
        (tester) async {
      await tester.pumpWidget(_wrap(dio: _stubDio()));
      await tester.pump();

      // Demo email + password should be prefilled per the brief.
      expect(find.text('parent@sado.uz'), findsOneWidget);
      expect(find.text('demo1234'), findsOneWidget);
      await _disposeTree(tester);
    });

    testWidgets('email validator rejects strings without @', (tester) async {
      await tester.pumpWidget(_wrap(dio: _stubDio()));
      await tester.pump();

      // Replace email with an invalid value, keep password valid.
      final emailField =
          find.widgetWithText(TextFormField, 'parent@sado.uz');
      expect(emailField, findsOneWidget);
      await tester.enterText(emailField, 'not-an-email');
      await tester.pump();

      // Tap submit.
      await tester.tap(find.byType(PremiumButton));
      await tester.pump();

      // The localized email-invalid message should now be shown.
      final l = await L.delegate.load(const Locale('uz'));
      expect(find.text(l.emailInvalid), findsOneWidget);
      await _disposeTree(tester);
    });

    testWidgets('password validator rejects strings shorter than 6 chars',
        (tester) async {
      await tester.pumpWidget(_wrap(dio: _stubDio()));
      await tester.pump();

      // Find by current text — the prefilled password is 'demo1234'.
      final passwordField =
          find.widgetWithText(TextFormField, 'demo1234');
      expect(passwordField, findsOneWidget);
      await tester.enterText(passwordField, '123');
      await tester.pump();

      await tester.tap(find.byType(PremiumButton));
      await tester.pump();

      final l = await L.delegate.load(const Locale('uz'));
      expect(find.text(l.passwordMinLength), findsOneWidget);
      await _disposeTree(tester);
    });

    testWidgets('valid form sends POST /auth/login with the expected body',
        (tester) async {
      final cap = _Capture();
      await tester.pumpWidget(_wrap(dio: _stubDio(capture: cap)));
      await tester.pump();

      // Tap login with the prefilled creds.
      await tester.tap(find.byType(PremiumButton));
      // Let the async login + me() resolve.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(cap.method, 'POST');
      expect(cap.path, '/auth/login');
      expect(cap.body?['email'], 'parent@sado.uz');
      expect(cap.body?['password'], 'demo1234');
      await _disposeTree(tester);
    });

    testWidgets('shows the localized error banner when the API rejects login',
        (tester) async {
      // Send a 401 from /auth/login.
      await tester.pumpWidget(_wrap(dio: _stubDio(loginStatus: 401)));
      await tester.pump();

      await tester.tap(find.byType(PremiumButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      final l = await L.delegate.load(const Locale('uz'));
      expect(find.text(l.loginFailed), findsOneWidget);
      await _disposeTree(tester);
    });

    testWidgets('shows the network-error variant when Dio throws transport',
        (tester) async {
      await tester.pumpWidget(_wrap(dio: _stubDio(networkError: true)));
      await tester.pump();

      await tester.tap(find.byType(PremiumButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      final l = await L.delegate.load(const Locale('uz'));
      expect(find.text(l.networkError), findsOneWidget);
      await _disposeTree(tester);
    });

    testWidgets("password visibility toggle flips the obscure state",
        (tester) async {
      await tester.pumpWidget(_wrap(dio: _stubDio()));
      await tester.pump();

      // Initially obscured → "show" icon visible.
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      // After tap, icon flips.
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await _disposeTree(tester);
    });
  });
}
