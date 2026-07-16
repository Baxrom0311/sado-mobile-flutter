import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/children/child_detail_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

Child _seedChild() => Child(
      id: 'c-1',
      name: 'Aziza',
      birthDate: DateTime(2019, 4, 1),
      gender: 'female',
      parentId: 'p-1',
      createdAt: DateTime(2024, 1, 1),
    );

Assessment _assessment({
  required String id,
  String overallRisk = 'low',
  double? score = 0.92,
  DateTime? at,
}) {
  return Assessment(
    id: id,
    childId: 'c-1',
    status: 'completed',
    overallRisk: overallRisk,
    score: score,
    createdAt: at ?? DateTime(2024, 6, 1),
  );
}

class _RouteSpy {
  String? lastLocation;
}

GoRouter _router(_RouteSpy spy, {String childId = 'c-1'}) {
  return GoRouter(
    initialLocation: '/children/$childId',
    routes: [
      GoRoute(
        path: '/children',
        builder: (_, __) => const Scaffold(body: Text('list')),
      ),
      GoRoute(
        path: '/children/:id',
        builder: (_, state) =>
            ChildDetailScreen(childId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/children/:id/edit',
        builder: (_, state) {
          spy.lastLocation = state.matchedLocation;
          return Scaffold(body: Text('edit-${state.pathParameters['id']}'));
        },
      ),
      GoRoute(
        path: '/exercises',
        builder: (_, state) {
          spy.lastLocation = state.matchedLocation;
          return const Scaffold(body: Text('exercises'));
        },
      ),
      GoRoute(
        path: '/assessment/results/:id',
        builder: (_, state) {
          spy.lastLocation = state.matchedLocation;
          return Scaffold(body: Text('result-${state.pathParameters['id']}'));
        },
      ),
    ],
  );
}

Widget _wrap({
  required _RouteSpy spy,
  required List<Child> children,
  required List<Assessment> assessments,
  String childId = 'c-1',
  bool assessmentsFromCache = false,
  List<ExerciseAssignment> assignments = const [],
}) {
  return ProviderScope(
    overrides: [
      childrenProvider.overrideWith(
        (ref) async => CachedResult<Child>(children),
      ),
      assessmentsProvider.overrideWith(
        (ref, _) async => CachedResult<Assessment>(
          assessments,
          fromCache: assessmentsFromCache,
        ),
      ),
      childAssignmentsProvider.overrideWith(
        (ref, _) async => CachedResult<ExerciseAssignment>(assignments),
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
      routerConfig: _router(spy, childId: childId),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  testWidgets(
    'renders the child header, stats, and an empty-recent-assessments card',
    (tester) async {
      // Force a tall viewport so the bottom CTA is hit-testable later on.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        spy: spy,
        children: [_seedChild()],
        assessments: const [],
      ));
      await _settle(tester);

      // Header shows the child's name (in the AppBar and the gradient card).
      expect(find.text('Aziza'), findsAtLeastNWidgets(1));

      // The stats row always renders, so "Jami baholashlar" + "O'rtacha
      // ball" labels (from the uz arb) must be present even with no
      // assessments.
      expect(find.text('Jami baholashlar'), findsOneWidget);
      expect(find.text('O\'rtacha ball'), findsOneWidget);

      // The "no assessments yet" mascot copy ("Birinchi mashqingizni
      // bajaring") should appear since we seeded an empty list.
      expect(find.text('Birinchi mashqingizni bajaring'), findsOneWidget);
    },
  );

  testWidgets(
    'lists recent assessments and shows the score percentage on each tile',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        spy: spy,
        children: [_seedChild()],
        assessments: [
          _assessment(id: 'a-1', score: 0.92, overallRisk: 'low'),
          _assessment(id: 'a-2', score: 0.61, overallRisk: 'medium'),
          _assessment(id: 'a-3', score: 0.34, overallRisk: 'high'),
        ],
      ));
      await _settle(tester);

      // Each score is rendered as an integer percentage.
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('61%'), findsOneWidget);
      expect(find.text('34%'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a recent-assessment tile navigates to the results screen',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      // Two assessments with distinct scores — that way "92%" appears only
      // on the row tile (the average rounds to a different number) so our
      // tap target is unambiguous.
      await tester.pumpWidget(_wrap(
        spy: spy,
        children: [_seedChild()],
        assessments: [
          _assessment(id: 'a-1', score: 0.92),
          _assessment(id: 'a-2', score: 0.50),
        ],
      ));
      await _settle(tester);

      await tester.tap(find.text('92%'));
      await tester.pumpAndSettle();
      expect(spy.lastLocation, '/assessment/results/a-1');
    },
  );

  testWidgets(
    'tapping the AppBar edit action routes to /children/:id/edit',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        spy: spy,
        children: [_seedChild()],
        assessments: const [],
      ));
      await _settle(tester);

      await tester.tap(find.byTooltip('Tahrirlash'));
      await tester.pumpAndSettle();
      expect(spy.lastLocation, '/children/c-1/edit');
    },
  );

  testWidgets(
    'shows the friendly not-found mascot when the requested child is missing',
    (tester) async {
      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        spy: spy,
        // Provide a different child than the route asks for so the screen
        // hits its "child == null" branch.
        children: [
          Child(
            id: 'c-other',
            name: 'Other',
            birthDate: DateTime(2019, 1, 1),
            gender: 'male',
            parentId: 'p-1',
            createdAt: DateTime(2024, 1, 1),
          ),
        ],
        assessments: const [],
        childId: 'c-1',
      ));
      await _settle(tester);

      // The error / fallback copy uses the localized errorTitle.
      expect(find.text('Nimadir noto\'g\'ri ketdi'), findsOneWidget);
    },
  );

  testWidgets(
    'surfaces the offline-cached banner when assessments come from cache',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        spy: spy,
        children: [_seedChild()],
        // Two distinct scores so the per-tile "92%" is unambiguous (the
        // average rounds differently).
        assessments: [
          _assessment(id: 'a-1', score: 0.92),
          _assessment(id: 'a-2', score: 0.50),
        ],
        assessmentsFromCache: true,
      ));
      await _settle(tester);

      expect(
        find.text('Oflayn rejim — keshlangan ma\'lumot'),
        findsOneWidget,
      );
      // The list itself still renders despite the banner.
      expect(find.text('92%'), findsOneWidget);
    },
  );
}
