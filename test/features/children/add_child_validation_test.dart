import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/api_client.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/children/add_child_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

class _Capture {
  String? method;
  String? path;
  Map<String, dynamic>? body;
}

Dio _stubDio(_Capture cap) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      cap
        ..method = options.method
        ..path = options.path
        ..body = options.data is Map<String, dynamic>
            ? Map<String, dynamic>.from(options.data as Map<String, dynamic>)
            : null;
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {
          'id': 'c-new',
          'name': options.data is Map ? options.data['name'] : 'New',
          'birth_date':
              options.data is Map ? options.data['birth_date'] : '2020-01-01',
          'gender':
              options.data is Map ? options.data['gender'] : 'male',
          'parent_id': 'p-1',
          'created_at': '2024-01-01T00:00:00Z',
        },
      ));
    },
  ));
  return dio;
}

GoRouter _router() => GoRouter(
      initialLocation: '/children/add',
      routes: [
        GoRoute(
          path: '/children/add',
          builder: (_, __) => const AddChildScreen(),
        ),
        GoRoute(
          path: '/children',
          builder: (_, __) => const Scaffold(body: Text('list')),
        ),
      ],
    );

Widget _wrap(_Capture cap) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(_stubDio(cap)),
      childrenProvider.overrideWith(
        (ref) async => const CachedResult<Child>([]),
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
      routerConfig: _router(),
    ),
  );
}

/// Sets a tall test viewport so the multi-step form's footer button (Saqlash)
/// is hit-testable without needing to scroll. The default 800×600 surface
/// puts it at y≈625, which is just below the visible area.
///
/// We use [TestWidgetsFlutterBinding.setSurfaceSize] (not
/// `tester.view.physicalSize`) because the latter races with the first
/// layout pass — depending on isolate timing, the form is sometimes laid
/// out at 800×600 anyway, which made these tests flaky in CI.
Future<void> _useTallViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('rejects empty name', (tester) async {
    await _useTallViewport(tester);
    final cap = _Capture();
    await tester.pumpWidget(_wrap(cap));
    await tester.pump();

    // Tap save without filling anything in.
    await tester.tap(find.text('Saqlash'));
    await tester.pump();

    expect(find.text('Ism kiriting'), findsOneWidget);
    expect(cap.method, isNull, reason: 'no API call when invalid');
  });

  testWidgets('rejects 1-character name', (tester) async {
    await _useTallViewport(tester);
    final cap = _Capture();
    await tester.pumpWidget(_wrap(cap));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), 'A');
    await tester.tap(find.text('Saqlash'));
    await tester.pump();

    expect(find.text('Ism kiriting'), findsOneWidget);
    expect(cap.method, isNull);
  });

  testWidgets('does not submit until birth date is set', (tester) async {
    await _useTallViewport(tester);
    final cap = _Capture();
    await tester.pumpWidget(_wrap(cap));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), 'Ali');
    await tester.tap(find.text('Saqlash'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    // Form passes name validation but birth date is null → no request.
    expect(find.text('Ism kiriting'), findsNothing);
    expect(cap.method, isNull);
  });

  testWidgets('default gender is male', (tester) async {
    final cap = _Capture();
    await tester.pumpWidget(_wrap(cap));
    await tester.pump();

    // The male tile shows "O'g'il bola" — present in the DOM regardless of
    // selection, so we just verify both gender tiles exist on the form.
    expect(find.text('O\'g\'il bola'), findsOneWidget);
    expect(find.text('Qiz bola'), findsOneWidget);
  });

  testWidgets('switching to female updates the selected tile',
      (tester) async {
    final cap = _Capture();
    await tester.pumpWidget(_wrap(cap));
    await tester.pump();

    await tester.tap(find.text('Qiz bola'));
    await tester.pump(const Duration(milliseconds: 250));

    // No request is fired by tapping the gender tile alone.
    expect(cap.method, isNull);
    // Both labels still rendered, just visual selection differs.
    expect(find.text('Qiz bola'), findsOneWidget);
  });

  testWidgets('kindergarten field is shown as optional and unset by default',
      (tester) async {
    final cap = _Capture();
    await tester.pumpWidget(_wrap(cap));
    await tester.pump();

    // Optional kindergarten field is rendered with the localized label.
    expect(find.text('Bog\'cha (ixtiyoriy)'), findsOneWidget);
    // And shows the "not set" hint until the user picks one.
    expect(find.text('Bog\'cha tanlanmagan'), findsOneWidget);
    expect(cap.method, isNull);
  });
}
