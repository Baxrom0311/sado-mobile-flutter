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
import 'package:sado_mobile/features/profile/edit_profile_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';
import 'package:sado_mobile/widgets/premium_button.dart';

/// Captures the latest request the screen issued against the stub Dio so the
/// test can assert that the right PATCH body went out.
class _Capture {
  String? method;
  String? path;
  Map<String, dynamic>? body;
}

User _user({String fullName = 'Aziz Karimov', String language = 'uz'}) =>
    User(
      id: 'u1',
      email: 'parent@sado.uz',
      fullName: fullName,
      role: 'parent',
      language: language,
      isActive: true,
      isVerified: true,
      createdAt: DateTime.utc(2024, 1, 1),
    );

Dio _stubDio(_Capture cap) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      cap
        ..method = options.method
        ..path = options.path
        ..body = options.data is Map
            ? Map<String, dynamic>.from(options.data as Map)
            : null;
      // Echo a minimal user payload back so AuthApi.updateProfile can parse
      // a successful response and the notifier rebuilds in-memory user.
      final reqBody = options.data is Map ? options.data as Map : const {};
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {
          'id': 'u1',
          'email': 'parent@sado.uz',
          'full_name': reqBody['full_name'] is String
              ? reqBody['full_name']
              : 'Aziz Karimov',
          'role': 'parent',
          'language':
              reqBody['language'] is String ? reqBody['language'] : 'uz',
          'is_active': true,
          'is_verified': true,
          'created_at': '2024-01-01T00:00:00Z',
        },
      ));
    },
  ));
  return dio;
}

class _StaticAuthNotifier extends AuthNotifier {
  _StaticAuthNotifier(super.api, super.ref, User initial) {
    // Skip the real _init() probe by reasserting a static state right away.
    state = AuthState(status: AuthStatus.authenticated, user: initial);
  }
}

GoRouter _router(Widget screen) {
  return GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(path: '/edit', builder: (_, __) => screen),
      GoRoute(
        path: '/profile',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('PROFILE_HOME'))),
      ),
    ],
  );
}

Widget _wrap({
  required _Capture cap,
  required User user,
  required Widget screen,
}) {
  return ProviderScope(
    overrides: [
      preferencesProvider.overrideWithValue(Preferences.inMemory()),
      dioProvider.overrideWithValue(_stubDio(cap)),
      authProvider.overrideWith(
        (ref) => _StaticAuthNotifier(ref.watch(authApiProvider), ref, user),
      ),
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
      routerConfig: _router(screen),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
}

/// Tears down the widget tree so any [Timer] schedules from `flutter_animate`
/// delay-based effects have a chance to fire and the parrot mascot's
/// AnimationControllers are disposed cleanly. Without this, tests that
/// render the mascot or animate-decorated widgets fail at teardown with
/// "A Timer is still pending".
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('EditProfileScreen prefills the current user name',
      (tester) async {
    final cap = _Capture();
    await tester.pumpWidget(_wrap(
      cap: cap,
      user: _user(),
      screen: const EditProfileScreen(),
    ));
    await _settle(tester);

    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Aziz Karimov'),
      findsOneWidget,
    );

    // Save button is a PremiumButton with label "O'zgarishlarni saqlash"
    // (the localized "Save changes"). It is disabled while the form is
    // pristine because nothing has changed yet.
    final btn = tester.widget<PremiumButton>(
      find.byWidgetPredicate(
        (w) => w is PremiumButton && w.label == 'O\'zgarishlarni saqlash',
      ),
    );
    expect(btn.onPressed, isNull);

    await _disposeTree(tester);
  });

  testWidgets('EditProfileScreen rejects empty / too-short names',
      (tester) async {
    final cap = _Capture();
    await tester.pumpWidget(_wrap(
      cap: cap,
      user: _user(),
      screen: const EditProfileScreen(),
    ));
    await _settle(tester);

    // Clear the name → form becomes dirty → Save enables → tap.
    await tester.enterText(find.byType(TextFormField), '');
    await _settle(tester);
    await tester.tap(find.text('O\'zgarishlarni saqlash'));
    await _settle(tester);

    // Validator surfaces the localized "field required" message and the
    // network was never touched.
    expect(find.text('Bu maydon to\'ldirilishi shart'), findsOneWidget);
    expect(cap.method, isNull);

    await _disposeTree(tester);
  });

  testWidgets('EditProfileScreen sends PATCH /users/me with changed fields',
      (tester) async {
    final cap = _Capture();
    await tester.pumpWidget(_wrap(
      cap: cap,
      user: _user(),
      screen: const EditProfileScreen(),
    ));
    await _settle(tester);

    await tester.enterText(find.byType(TextFormField), 'Aziza Karimova');
    await _settle(tester);
    await tester.tap(find.text('O\'zgarishlarni saqlash'));
    // Drain the PATCH future + the post-success router.go() + animations.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(cap.method, 'PATCH');
    expect(cap.path, '/users/me');
    expect(cap.body, {'full_name': 'Aziza Karimova'});

    await _disposeTree(tester);
  });
}
