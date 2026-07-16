import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/api_client.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/notifications/notifications_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/notifications_provider.dart';
import 'package:sado_mobile/widgets/parrot_mascot.dart';
import 'package:sado_mobile/widgets/shimmer_loaders.dart';

AppNotification _n(
  String id, {
  bool read = false,
  String? title,
  String? body,
}) =>
    AppNotification(
      id: id,
      title: title ?? 'Title $id',
      body: body ?? 'Body $id',
      isRead: read,
      createdAt: DateTime.utc(2025, 1, 1),
    );

/// Captures every request the mark-read flow issues so we can assert against
/// the exact endpoint that fired (without needing a real server).
class _DioCapture {
  final List<String> paths = [];
}

Dio _stubDio(_DioCapture cap) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      cap.paths.add('${options.method} ${options.path}');
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
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      // Back button on the AppBar `context.go('/profile')`s — give it a real
      // landing page so the navigation succeeds.
      GoRoute(
        path: '/profile',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('PROFILE_HOME'))),
      ),
    ],
  );
}

Widget _wrap({
  required AsyncValue<List<AppNotification>> Function()? overrideValue,
  Future<List<AppNotification>> Function(Ref ref)? overrideFuture,
  _DioCapture? cap,
}) {
  // We accept either a synchronous AsyncValue (loading/error/data) or a
  // future-style override. Keeps each test focused on one branch.
  final overrides = <Override>[
    if (overrideFuture != null)
      notificationsProvider.overrideWith((ref) => overrideFuture(ref))
    else
      notificationsProvider.overrideWith((ref) async {
        final v = overrideValue!();
        return v.maybeWhen(
          data: (items) => items,
          orElse: () => const <AppNotification>[],
        );
      }),
    if (cap != null) dioProvider.overrideWithValue(_stubDio(cap)),
  ];

  return ProviderScope(
    overrides: overrides,
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

void main() {
  // Realistic phone viewport so vertical layouts (mascot + body + retry CTA)
  // do not clip in the empty/error states.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize =
        const Size(390 * 3, 844 * 3);
    binding.platformDispatcher.views.first.devicePixelRatio = 3.0;
  });
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('NotificationsScreen', () {
    testWidgets('shows shimmer placeholders while the future is loading',
        (tester) async {
      // Use a never-completing Completer (instead of Future.delayed) so we
      // do not leave a pending Timer behind — flutter_test fails the suite
      // if a Timer survives past the end of the testWidgets body.
      final pending = Completer<List<AppNotification>>();
      addTearDown(() {
        if (!pending.isCompleted) pending.complete(const []);
      });

      await tester.pumpWidget(_wrap(
        overrideValue: null,
        overrideFuture: (_) => pending.future,
      ));
      await tester.pump();

      expect(find.byType(ShimmerList), findsOneWidget);
      // The "Mark all read" action must not show while loading.
      expect(find.byIcon(Icons.done_all_rounded), findsNothing);
      // Shimmer is the loader — never a Material default.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'empty state renders the parrot mascot, friendly copy and a retry CTA',
      (tester) async {
        await tester.pumpWidget(_wrap(
          overrideValue: () => const AsyncData(<AppNotification>[]),
        ));
        // Resolve the future + entrance animations.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(ParrotMascot), findsOneWidget);
        expect(find.text('Hozircha bildirishnoma yo\'q'), findsOneWidget);
        expect(
          find.text('Yangiliklar paydo bo\'lganda shu yerda ko\'rasiz'),
          findsOneWidget,
        );
        // The retry CTA reuses the global `retry` localization so users can
        // re-pull the (eventually-real) backend without leaving the page.
        expect(find.text('Qayta urinish'), findsOneWidget);

        // Empty state suppresses "Mark all read" — there is nothing to mark.
        expect(find.byIcon(Icons.done_all_rounded), findsNothing);
      },
    );

    testWidgets('error state degrades to the same empty mascot scaffold',
        (tester) async {
      await tester.pumpWidget(_wrap(
        overrideValue: null,
        overrideFuture: (_) => Future.error(StateError('boom')),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // We swallow errors and surface the friendly empty state — no red banner.
      expect(find.byType(ParrotMascot), findsOneWidget);
      expect(find.text('Hozircha bildirishnoma yo\'q'), findsOneWidget);
      // No analyzer-flagged error text, no spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'data state renders one tile per notification with correct copy '
      'and exposes the "Mark all read" action',
      (tester) async {
        await tester.pumpWidget(_wrap(
          overrideValue: () => AsyncData([
            _n('a', title: 'Sizga yangi mashq', body: 'Articulation R'),
            _n('b', read: true, title: 'Eslatma', body: 'Bugun mashq vaqti'),
          ]),
        ));
        await tester.pump();
        // flutter_animate stagger: each tile fades in with a 50ms delay.
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Sizga yangi mashq'), findsOneWidget);
        expect(find.text('Articulation R'), findsOneWidget);
        expect(find.text('Eslatma'), findsOneWidget);
        expect(find.text('Bugun mashq vaqti'), findsOneWidget);

        // The mark-all-read action surfaces as an AppBar icon (with the
        // localized copy moved into the tooltip so it never overflows on
        // a narrow phone).
        final action = find.byIcon(Icons.done_all_rounded);
        expect(action, findsOneWidget);
        expect(
          tester.widget<IconButton>(find.ancestor(
            of: action,
            matching: find.byType(IconButton),
          )).tooltip,
          'Hammasini o\'qilgan deb belgilash',
        );

        // The bell empty-state should not be visible while data exists.
        expect(find.text('Hozircha bildirishnoma yo\'q'), findsNothing);
      },
    );

    testWidgets(
      'tapping an unread tile fires the mark-read endpoint with the right id',
      (tester) async {
        final cap = _DioCapture();
        await tester.pumpWidget(_wrap(
          cap: cap,
          overrideValue: () =>
              AsyncData([_n('abc-123', title: 'Yangi natija')]),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Tap the tile by its displayed title — most natural user action.
        await tester.tap(find.text('Yangi natija'));
        // Allow the async mark-read + invalidate cycle to flush.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          cap.paths.where((p) => p == 'POST /notifications/abc-123/read'),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'tapping "Mark all read" hits the bulk endpoint exactly once',
      (tester) async {
        final cap = _DioCapture();
        await tester.pumpWidget(_wrap(
          cap: cap,
          overrideValue: () => AsyncData([_n('a'), _n('b'), _n('c')]),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.byIcon(Icons.done_all_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          cap.paths.where((p) => p == 'POST /notifications/read-all'),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'tapping an already-read tile does NOT fire the mark-read endpoint',
      (tester) async {
        final cap = _DioCapture();
        await tester.pumpWidget(_wrap(
          cap: cap,
          overrideValue: () =>
              AsyncData([_n('done', read: true, title: 'O\'qilgan')]),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.text('O\'qilgan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          cap.paths.where((p) => p.contains('/read')),
          isEmpty,
        );
      },
    );

    testWidgets(
      'tile shows a localized relative time label next to the title',
      (tester) async {
        // Build a notification dated "today" and another dated 3 days ago.
        // Because formatRelativeDate is computed lazily inside the tile we
        // can use the real DateTime.now() and trust the helper is already
        // covered by its own unit tests; here we just confirm the label
        // surface area renders the expected uz copy.
        final now = DateTime.now();
        final today = AppNotification(
          id: 'today',
          title: 'Bugun yangilik',
          body: 'today body',
          isRead: false,
          createdAt: now,
        );
        final threeDaysAgo = AppNotification(
          id: 'past',
          title: 'Eski yangilik',
          body: 'past body',
          isRead: true,
          createdAt: now.subtract(const Duration(days: 3)),
        );

        await tester.pumpWidget(_wrap(
          overrideValue: () => AsyncData([today, threeDaysAgo]),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Bugun'), findsOneWidget);
        expect(find.text('3 kun oldin'), findsOneWidget);
      },
    );

    testWidgets('AppBar back button routes to /profile, not pop-to-nothing',
        (tester) async {
      await tester.pumpWidget(_wrap(
        overrideValue: () => const AsyncData(<AppNotification>[]),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('PROFILE_HOME'), findsOneWidget);
    });
  });
}
