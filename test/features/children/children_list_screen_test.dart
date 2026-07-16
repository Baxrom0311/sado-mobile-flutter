import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/children/children_list_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';
import 'package:sado_mobile/widgets/risk_badge.dart';

/// Builds a [Child] with sensible defaults so each test only has to override
/// the fields that matter for that scenario.
Child _child({
  required String id,
  required String name,
  String gender = 'male',
  DateTime? birthDate,
}) {
  return Child(
    id: id,
    name: name,
    birthDate: birthDate ?? DateTime(2019, 4, 1),
    gender: gender,
    parentId: 'p-1',
    createdAt: DateTime(2024, 1, 1),
  );
}

Assessment _assessment({
  required String id,
  required String childId,
  String? risk,
  DateTime? createdAt,
}) {
  return Assessment(
    id: id,
    childId: childId,
    status: 'completed',
    overallRisk: risk,
    score: 0.8,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Tracks whatever route the GoRouter ended up on so each test can assert
/// post-tap navigation without spinning up real screens for every route.
class _RouteSpy {
  String? lastLocation;
}

GoRouter _router(_RouteSpy spy) {
  return GoRouter(
    initialLocation: '/children',
    routes: [
      GoRoute(
        path: '/children',
        builder: (_, __) => const ChildrenListScreen(),
      ),
      GoRoute(
        path: '/children/add',
        builder: (_, state) {
          spy.lastLocation = state.matchedLocation;
          return const Scaffold(body: Text('add'));
        },
      ),
      GoRoute(
        path: '/children/:id',
        builder: (_, state) {
          spy.lastLocation = state.matchedLocation;
          return Scaffold(
              body: Text('detail-${state.pathParameters['id']}'));
        },
      ),
      GoRoute(
        path: '/children/:id/edit',
        builder: (_, state) {
          spy.lastLocation = state.matchedLocation;
          return Scaffold(
              body: Text('edit-${state.pathParameters['id']}'));
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const Scaffold(body: Text('profile')),
      ),
    ],
  );
}

Widget _wrap({
  required AsyncValue<CachedResult<Child>> children,
  required _RouteSpy spy,
  Completer<CachedResult<Child>>? loadingCompleter,
  List<Assessment> assessments = const [],
}) {
  return ProviderScope(
    overrides: [
      childrenProvider.overrideWith((ref) async {
        // The test injects an AsyncValue snapshot; `overrideWith` only takes
        // a Future, so we collapse loading/error/data into a single Future
        // that mirrors the requested terminal state.
        return children.when<Future<CachedResult<Child>>>(
          data: (v) async => v,
          // For loading we use a caller-owned Completer so the test can
          // complete it before tearing down — otherwise `Future.delayed`
          // would leave a pending timer and trip the binding's invariants.
          loading: () =>
              (loadingCompleter ?? Completer<CachedResult<Child>>()).future,
          error: (e, _) async => throw e,
        );
      }),
      // The list tile now reads assessments to show a per-child "last
      // assessment" line, so override with a deterministic in-memory list.
      assessmentsProvider(null).overrideWith(
        (ref) async => CachedResult<Assessment>(assessments),
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
      routerConfig: _router(spy),
    ),
  );
}

/// Helps the staggered fade/slide animations finish so the underlying
/// widgets become hit-testable for our taps.
///
/// We pump several frames with a generous duration to let:
///   1. Riverpod's overridden async providers resolve their first microtask.
///   2. The children list FutureProvider rebuild kick off the per-tile
///      assessments lookup.
///   3. The flutter_animate staggered fadeIn/slideY (delay = index * 60ms,
///      duration ~250ms) fully finish.
///
/// Using pumpAndSettle would deadlock because [Shimmer] runs an infinite
/// loading animation while the FAB hero widget keeps a transient ticker
/// alive on first frame, so we drive time forward in fixed slices instead.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'renders the empty state with the add-child CTA when no children exist',
    (tester) async {
      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        children: const AsyncValue.data(CachedResult<Child>([])),
        spy: spy,
      ));
      await _settle(tester);

      // Empty-state copy from the uz arb file — title "Hali bola
      // qo'shilmagan" plus the add-child CTA "Bola qo'shish".
      expect(find.text('Hali bola qo\'shilmagan'), findsOneWidget);
      expect(find.text('Bola qo\'shish'), findsAtLeastNWidgets(1));
      // Tapping the in-place CTA must route to the multi-step add form.
      // The CTA inside EmptyState is the same "Bola qo'shish" label rendered
      // by the FAB, so we tap the first match (the EmptyState button).
      await tester.tap(find.text('Bola qo\'shish').first);
      await tester.pumpAndSettle();
      expect(spy.lastLocation, '/children/add');
    },
  );

  testWidgets(
    'renders one tile per child with the localized age suffix',
    (tester) async {
      final spy = _RouteSpy();
      // Fixed birth date so the displayed age is stable across CI clocks.
      final old = DateTime(2018, 1, 1);
      await tester.pumpWidget(_wrap(
        children: AsyncValue.data(CachedResult<Child>([
          _child(id: 'c-1', name: 'Aziza', gender: 'female', birthDate: old),
          _child(id: 'c-2', name: 'Bekzod', gender: 'male', birthDate: old),
        ])),
        spy: spy,
      ));
      await _settle(tester);

      expect(find.text('Aziza'), findsOneWidget);
      expect(find.text('Bekzod'), findsOneWidget);
      // The "yosh" suffix is rendered for every child tile.
      expect(find.textContaining('yosh'), findsAtLeastNWidgets(2));
    },
  );

  testWidgets(
    'tile shows initials avatar from the child name',
    (tester) async {
      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        children: AsyncValue.data(CachedResult<Child>([
          _child(id: 'c-1', name: 'Aziza Karimova', gender: 'female'),
        ])),
        spy: spy,
      ));
      await _settle(tester);

      // Avatar renders the two-letter initials "AK", not the face icon.
      expect(find.text('AK'), findsOneWidget);
    },
  );

  testWidgets(
    'tile shows "no assessments yet" when this child has none',
    (tester) async {
      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        children: AsyncValue.data(CachedResult<Child>([
          _child(id: 'c-1', name: 'Aziza'),
        ])),
        spy: spy,
        // No assessments at all → row should show the friendly empty hint.
      ));
      await _settle(tester);

      expect(find.text('Hali baholanmagan'), findsOneWidget);
      // No risk badge should appear without an assessment.
      expect(find.byType(RiskBadge), findsNothing);
    },
  );

  testWidgets(
    'tile shows the latest assessment date with a risk badge for that child',
    (tester) async {
      final spy = _RouteSpy();
      // Anchor to noon today so subtracting hours stays on the same calendar
      // day regardless of when CI runs the test.
      final today = DateTime.now();
      final noon = DateTime(today.year, today.month, today.day, 12);
      await tester.pumpWidget(_wrap(
        children: AsyncValue.data(CachedResult<Child>([
          _child(id: 'c-1', name: 'Aziza'),
          _child(id: 'c-2', name: 'Bekzod'),
        ])),
        spy: spy,
        assessments: [
          // Old assessment for Aziza, should NOT be picked.
          _assessment(
            id: 'a1',
            childId: 'c-1',
            risk: 'red',
            createdAt: noon.subtract(const Duration(days: 10)),
          ),
          // Most recent assessment for Aziza — what we expect to render.
          _assessment(
            id: 'a2',
            childId: 'c-1',
            risk: 'green',
            createdAt: noon,
          ),
          // Bekzod has no assessment.
        ],
      ));
      await _settle(tester);

      // The latest assessment is "low risk" (green) → its localized label
      // appears, AND it's on a single tile (Aziza's).
      expect(find.text('Xavf past'), findsOneWidget);
      expect(find.byType(RiskBadge), findsOneWidget);
      // The "high risk" label from the older assessment must NOT bleed
      // through — only the latest is shown.
      expect(find.text('Xavf yuqori'), findsNothing);
      // Bekzod still gets the empty hint.
      expect(find.text('Hali baholanmagan'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a child tile routes to /children/:id',
    (tester) async {
      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        children: AsyncValue.data(CachedResult<Child>([
          _child(id: 'c-42', name: 'Aziza'),
        ])),
        spy: spy,
      ));
      await _settle(tester);

      await tester.tap(find.text('Aziza'));
      await tester.pumpAndSettle();
      expect(spy.lastLocation, '/children/c-42');
    },
  );

  testWidgets(
    'tapping the edit icon routes to /children/:id/edit, not the detail',
    (tester) async {
      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        children: AsyncValue.data(CachedResult<Child>([
          _child(id: 'c-7', name: 'Aziza'),
        ])),
        spy: spy,
      ));
      await _settle(tester);

      // Use the tooltip the screen attaches to its edit IconButton.
      await tester.tap(find.byTooltip('Tahrirlash'));
      await tester.pumpAndSettle();
      expect(spy.lastLocation, '/children/c-7/edit');
    },
  );

  testWidgets(
    'tapping the floating action button routes to /children/add',
    (tester) async {
      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        children: AsyncValue.data(CachedResult<Child>([
          _child(id: 'c-1', name: 'Aziza'),
        ])),
        spy: spy,
      ));
      await _settle(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(spy.lastLocation, '/children/add');
    },
  );

  testWidgets(
    'shows shimmer skeletons (not a Material spinner) while loading',
    (tester) async {
      final spy = _RouteSpy();
      // Caller-owned completer means we control teardown: complete it with
      // an empty result before the test exits so no timers stay pending.
      final completer = Completer<CachedResult<Child>>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete(const CachedResult<Child>([]));
        }
      });

      await tester.pumpWidget(_wrap(
        children: const AsyncValue.loading(),
        spy: spy,
        loadingCompleter: completer,
      ));
      // Don't settle — we want to observe the loading state.
      await tester.pump();

      // The brief explicitly forbids Material's default spinner here.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Drain the future and one frame so the widget tree disposes cleanly.
      // We can't `pumpAndSettle` because the shimmer animation is a forever
      // loop, so we tear down with a fixed-duration pump instead.
      completer.complete(const CachedResult<Child>([]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets(
    'shows the offline-cached banner when the children list is from cache',
    (tester) async {
      final spy = _RouteSpy();
      // Simulate an API failure path: provider returned data, but flagged
      // it as `fromCache: true`. The screen must render the banner so the
      // parent knows the list may be stale.
      await tester.pumpWidget(_wrap(
        children: AsyncValue.data(CachedResult<Child>(
          [_child(id: 'c-1', name: 'Aziza')],
          fromCache: true,
        )),
        spy: spy,
      ));
      await _settle(tester);

      // Banner copy from the uz arb file.
      expect(
        find.text('Oflayn rejim — keshlangan ma\'lumot'),
        findsOneWidget,
      );
      // The list still renders — the banner is additive, not a replacement.
      expect(find.text('Aziza'), findsOneWidget);
    },
  );

  testWidgets(
    'does NOT show the offline-cached banner when data is fresh',
    (tester) async {
      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        children: AsyncValue.data(CachedResult<Child>(
          [_child(id: 'c-1', name: 'Aziza')],
          // Default fromCache is false → no banner expected.
        )),
        spy: spy,
      ));
      await _settle(tester);

      expect(
        find.text('Oflayn rejim — keshlangan ma\'lumot'),
        findsNothing,
      );
      expect(find.text('Aziza'), findsOneWidget);
    },
  );
}
