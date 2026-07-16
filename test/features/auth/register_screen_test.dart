import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/api_client.dart';
import 'package:sado_mobile/features/auth/register_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/premium_button.dart';

/// Captures the FIRST request the screen issues. The AuthNotifier auto-
/// triggers a chain (register → login → me) on success — we only care about
/// the body of the very first POST /auth/register.
class _Capture {
  String? method;
  String? path;
  Map<String, dynamic>? body;

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

Dio _stubDio({_Capture? capture}) {
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
      // Echo a minimal user payload back for /auth/register and /users/me;
      // a TokenPair shape for /auth/login. Anything else 204s.
      if (options.path == '/auth/register') {
        handler.resolve(Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: const {
            'id': 'u-1',
            'email': 'new@sado.uz',
            'full_name': 'New User',
            'role': 'teacher',
            'language': 'uz',
            'is_active': true,
            'is_verified': false,
            'created_at': '2024-01-01T00:00:00Z',
          },
        ));
        return;
      }
      if (options.path == '/auth/login') {
        handler.resolve(Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: const {
            'access_token': 'a',
            'refresh_token': 'r',
            'expires_in': 3600,
          },
        ));
        return;
      }
      if (options.path == '/users/me') {
        handler.resolve(Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: const {
            'id': 'u-1',
            'email': 'new@sado.uz',
            'full_name': 'New User',
            'role': 'teacher',
            'language': 'uz',
            'is_active': true,
            'is_verified': false,
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
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('login-stub'))),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('home-stub'))),
        ),
      ],
    );

Widget _wrap({required Dio dio}) {
  return ProviderScope(
    overrides: [dioProvider.overrideWithValue(dio)],
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
      routerConfig: _router(),
    ),
  );
}

/// Drains animations + disposes the tree so dangling Timers from
/// flutter_animate don't poison the next test.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 800));
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

  group('RegisterScreen', () {
    testWidgets(
      'renders both role cards, the terms checkbox and the submit button',
      (tester) async {
        await tester.pumpWidget(_wrap(dio: _stubDio()));
        await tester.pump();

        final l = await L.delegate.load(const Locale('uz'));

        // Role question + both role cards visible.
        expect(find.text(l.registerRoleQuestion), findsOneWidget);
        expect(find.text(l.roleParent), findsOneWidget);
        expect(find.text(l.roleTeacher), findsOneWidget);

        // Terms checkbox + submit button rendered.
        expect(find.byKey(const ValueKey('register-terms')), findsOneWidget);
        expect(find.byType(PremiumButton), findsOneWidget);

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'submitting without accepting the terms surfaces the inline error '
      'and does NOT issue a network request',
      (tester) async {
        final cap = _Capture();
        await tester.pumpWidget(_wrap(dio: _stubDio(capture: cap)));
        await tester.pump();

        final l = await L.delegate.load(const Locale('uz'));

        await tester.enterText(
            find.byKey(const ValueKey('register-name')), 'New User');
        await tester.enterText(
            find.byKey(const ValueKey('register-email')), 'new@sado.uz');
        await tester.enterText(
            find.byKey(const ValueKey('register-password')), 'demo1234');

        await tester.ensureVisible(find.byType(PremiumButton));
        await tester.pump();
        await tester.tap(find.byType(PremiumButton));
        await tester.pump();
        // Let the setState-triggered rebuild settle.
        await tester.pump(const Duration(milliseconds: 100));

        // Inline error message should show.
        expect(find.text(l.termsRequired), findsOneWidget);
        // No request should have been issued.
        expect(cap.method, isNull);

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'submitting with the teacher role selected sends role=teacher in '
      'the registration request body',
      (tester) async {
        final cap = _Capture();
        await tester.pumpWidget(_wrap(dio: _stubDio(capture: cap)));
        await tester.pump();

        // Switch to the teacher role card.
        await tester.tap(find.byKey(const ValueKey('role-teacher')));
        await tester.pump();

        await tester.enterText(
            find.byKey(const ValueKey('register-name')), 'Aisha Teacher');
        await tester.enterText(
            find.byKey(const ValueKey('register-email')), 'aisha@sado.uz');
        await tester.enterText(
            find.byKey(const ValueKey('register-password')), 'demo1234');

        // Accept the terms.
        await tester.ensureVisible(
            find.byKey(const ValueKey('register-terms')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('register-terms')));
        await tester.pump();

        // Submit.
        await tester.ensureVisible(find.byType(PremiumButton));
        await tester.pump();
        await tester.tap(find.byType(PremiumButton));
        await tester.pump();
        // The chained register → login → me sequence needs a few pumps.
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));

        expect(cap.method, 'POST');
        expect(cap.path, '/auth/register');
        expect(cap.body, isNotNull);
        expect(cap.body!['role'], 'teacher');
        expect(cap.body!['email'], 'aisha@sado.uz');
        expect(cap.body!['full_name'], 'Aisha Teacher');

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'name validator rejects empty input even when terms are accepted',
      (tester) async {
        final cap = _Capture();
        await tester.pumpWidget(_wrap(dio: _stubDio(capture: cap)));
        await tester.pump();

        final l = await L.delegate.load(const Locale('uz'));

        // Accept terms, but leave name empty + provide otherwise valid fields.
        await tester.ensureVisible(
            find.byKey(const ValueKey('register-terms')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('register-terms')));
        await tester.pump();
        await tester.enterText(
            find.byKey(const ValueKey('register-email')), 'new@sado.uz');
        await tester.enterText(
            find.byKey(const ValueKey('register-password')), 'demo1234');

        await tester.ensureVisible(find.byType(PremiumButton));
        await tester.pump();
        await tester.tap(find.byType(PremiumButton));
        await tester.pump();
        // Form.validate() flips field state to error; the next frame paints
        // the inline error text under the field.
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text(l.nameRequired), findsOneWidget);
        expect(cap.method, isNull);

        await _disposeTree(tester);
      },
    );
  });
}
