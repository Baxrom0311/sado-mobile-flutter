import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/api_client.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/children/edit_child_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

/// Records the most recent request body our stub Dio received.
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
          'id': 'c-1',
          'name': options.data is Map && options.data['name'] != null
              ? options.data['name']
              : 'Aziz',
          'birth_date': '2019-04-01',
          'gender': options.data is Map && options.data['gender'] != null
              ? options.data['gender']
              : 'male',
          'parent_id': 'p-1',
          'created_at': '2024-01-01T00:00:00Z',
        },
      ));
    },
  ));
  return dio;
}

Child _seedChild() => Child(
      id: 'c-1',
      name: 'Aziz',
      birthDate: DateTime(2019, 4, 1),
      gender: 'male',
      parentId: 'p-1',
      createdAt: DateTime(2024, 1, 1),
    );

GoRouter _router(Widget screen) {
  return GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(path: '/edit', builder: (_, __) => screen),
      GoRoute(
        path: '/children/:id',
        builder: (_, __) => const Scaffold(body: Text('detail')),
      ),
      GoRoute(
        path: '/children',
        builder: (_, __) => const Scaffold(body: Text('list')),
      ),
    ],
  );
}

Widget _wrap({
  required Widget screen,
  required _Capture cap,
}) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(_stubDio(cap)),
      childrenProvider.overrideWith(
        (ref) async => CachedResult<Child>([_seedChild()]),
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

void main() {
  testWidgets('EditChildScreen prefills with current child data',
      (tester) async {
    final cap = _Capture();
    await tester.pumpWidget(_wrap(
      cap: cap,
      screen: const EditChildScreen(childId: 'c-1'),
    ));
    // Resolve the future provider.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.byType(EditChildScreen), findsOneWidget);
    // Name field should be prefilled.
    expect(find.widgetWithText(TextFormField, 'Aziz'), findsOneWidget);
    // Date should appear as 01.04.2019.
    expect(find.text('01.04.2019'), findsOneWidget);
  });

  testWidgets('EditChildScreen rejects empty name',
      (tester) async {
    // Use a tall viewport so the Saqlash button is hit-testable without
    // first scrolling. The default 800×600 puts it off-screen at y≈675.
    // We use binding.setSurfaceSize (not view.physicalSize) because the
    // latter races with the first layout pass and made this test flaky.
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cap = _Capture();
    await tester.pumpWidget(_wrap(
      cap: cap,
      screen: const EditChildScreen(childId: 'c-1'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    // Clear the name and try to save.
    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(find.text('Saqlash'));
    await tester.pump();

    // Validation message should appear (uz locale for nameRequired).
    expect(find.text('Ism kiriting'), findsOneWidget);
    // No request should have been issued.
    expect(cap.method, isNull);
  });

  testWidgets('EditChildScreen submits only changed fields',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cap = _Capture();
    await tester.pumpWidget(_wrap(
      cap: cap,
      screen: const EditChildScreen(childId: 'c-1'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    // Change name only.
    await tester.enterText(find.byType(TextFormField), 'Aziza');
    await tester.tap(find.text('Saqlash'));
    // First pump triggers the request, second resolves the future.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(cap.method, 'PUT');
    expect(cap.path, '/children/c-1');
    expect(cap.body, {'name': 'Aziza'});
  });
}
