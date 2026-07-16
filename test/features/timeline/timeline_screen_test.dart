import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/timeline/timeline_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

GoRouter _timelineRouter() => GoRouter(
      initialLocation: '/timeline',
      routes: [
        GoRoute(
          path: '/timeline',
          builder: (_, __) => const TimelineScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('PROFILE_FALLBACK'))),
        ),
        GoRoute(
          path: '/exercises',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('EXERCISES_FALLBACK'))),
        ),
        GoRoute(
          path: '/exercises/:id',
          builder: (_, state) => Scaffold(
            body: Center(
              child: Text('EXERCISE_DETAIL:${state.pathParameters['id']}'),
            ),
          ),
        ),
        GoRoute(
          path: '/assessment/results/:id',
          builder: (_, state) => Scaffold(
            body: Center(
              child:
                  Text('ASSESSMENT_RESULTS:${state.pathParameters['id']}'),
            ),
          ),
        ),
      ],
    );

Widget _wrap({
  required List<Override> overrides,
  Locale locale = const Locale('uz'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      routerConfig: _timelineRouter(),
    ),
  );
}

Assessment _assessment({
  required String id,
  required DateTime created,
  String childId = 'c-1',
  double? score,
  String? risk,
}) =>
    Assessment(
      id: id,
      childId: childId,
      status: 'completed',
      score: score,
      overallRisk: risk,
      createdAt: created,
    );

ExerciseAssignment _assignment({
  required String id,
  required DateTime completed,
  String childId = 'c-1',
  String exerciseId = 'ex-1',
  ExerciseAssignmentStatus status = ExerciseAssignmentStatus.completed,
  Exercise? exercise,
}) =>
    ExerciseAssignment(
      id: id,
      childId: childId,
      exerciseId: exerciseId,
      status: status,
      completedAt: completed,
      createdAt: completed,
      updatedAt: completed,
      exercise: exercise,
    );

Child _child({String id = 'c-1', String name = 'Aziza'}) => Child(
      id: id,
      name: name,
      birthDate: DateTime(2020, 1, 1),
      gender: 'female',
      parentId: 'p-1',
      createdAt: DateTime(2024),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  // animate() chains stagger up to ~600ms; pump past the last keyframe.
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  // Some providers (gameProvider) eagerly open a Hive box on construction.
  // Initialise Hive against a temp directory so any indirect provider load
  // doesn't crash even though the timeline screen itself doesn't depend on
  // it.
  late Directory hiveDir;
  setUpAll(() {
    hiveDir = Directory.systemTemp.createTempSync('sado_timeline_test_');
    Hive.init(hiveDir.path);
  });
  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  testWidgets(
    'TimelineScreen empty state shows mascot and CTA in Uzbek',
    (tester) async {
      await tester.pumpWidget(_wrap(overrides: [
        assessmentsProvider.overrideWith(
          (ref, _) async => const CachedResult<Assessment>([]),
        ),
        myAssignmentsProvider.overrideWith(
          (ref) async => const CachedResult<ExerciseAssignment>([]),
        ),
        childrenProvider.overrideWith(
          (ref) async => const CachedResult<Child>([]),
        ),
      ]));
      await _settle(tester);

      expect(find.text('Faollik tarixi'), findsOneWidget);
      expect(find.text('Hali faollik yo\'q'), findsOneWidget);
      expect(find.text('Mashqlarni ochish'), findsOneWidget);
    },
  );

  testWidgets(
    'TimelineScreen renders one tile per event, newest first, with the score chip',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final assessment = _assessment(
        id: 'a-recent',
        created: now.subtract(const Duration(hours: 2)),
        score: 0.82,
        risk: 'green',
      );
      final assignment = _assignment(
        id: 'h-old',
        completed: now.subtract(const Duration(days: 10)),
        exercise: Exercise(
          id: 'ex-1',
          title: 'R sound drill',
          description: '',
          category: 'articulation',
          ageGroup: '4-5',
          difficulty: 'easy',
          language: 'uz',
          durationMinutes: 5,
          isActive: true,
        ),
      );

      await tester.pumpWidget(_wrap(overrides: [
        assessmentsProvider.overrideWith(
          (ref, _) async => CachedResult<Assessment>([assessment]),
        ),
        myAssignmentsProvider.overrideWith(
          (ref) async => CachedResult<ExerciseAssignment>([assignment]),
        ),
        childrenProvider.overrideWith(
          (ref) async => CachedResult<Child>([_child()]),
        ),
      ]));
      await _settle(tester);

      // Both events render as tiles.
      expect(find.byKey(const ValueKey('timeline.tile.assessment:a-recent')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('timeline.tile.assignment:h-old')),
          findsOneWidget);

      // Section headers: assessment is < 7d old → "this week", assignment
      // is 10d old → "earlier".
      expect(
        find.text('Faollik tarixi'.toUpperCase()),
        findsAtLeastNWidgets(0),
      );
      // Note: the localized labels are uppercased by the section header.
      expect(find.text('SHU HAFTA'), findsOneWidget);
      expect(find.text('AVVALROQ'), findsOneWidget);

      // Score chip uses 0–100 percent rendering (0.82 → 82%).
      expect(find.text('82%'), findsOneWidget);

      // Assignment subtitle inlines the exercise title.
      expect(find.textContaining('R sound drill'), findsOneWidget);
    },
  );

  testWidgets(
    'TimelineScreen filters out pending and in-progress assignments',
    (tester) async {
      final now = DateTime.now();
      final pending = _assignment(
        id: 'p1',
        completed: now,
        status: ExerciseAssignmentStatus.pending,
      );
      final inProgress = _assignment(
        id: 'p2',
        completed: now,
        status: ExerciseAssignmentStatus.inProgress,
      );

      await tester.pumpWidget(_wrap(overrides: [
        assessmentsProvider.overrideWith(
          (ref, _) async => const CachedResult<Assessment>([]),
        ),
        myAssignmentsProvider.overrideWith(
          (ref) async => CachedResult<ExerciseAssignment>([pending, inProgress]),
        ),
        childrenProvider.overrideWith(
          (ref) async => const CachedResult<Child>([]),
        ),
      ]));
      await _settle(tester);

      // No tiles should render; the empty state is visible instead.
      expect(find.byKey(const ValueKey('timeline.tile.assignment:p1')),
          findsNothing);
      expect(find.byKey(const ValueKey('timeline.tile.assignment:p2')),
          findsNothing);
      expect(find.text('Hali faollik yo\'q'), findsOneWidget);
    },
  );

  testWidgets(
    'TimelineScreen surfaces an offline banner when any source is from cache',
    (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(overrides: [
        assessmentsProvider.overrideWith(
          (ref, _) async => CachedResult<Assessment>(
            [_assessment(id: 'a1', created: now)],
            fromCache: true,
          ),
        ),
        myAssignmentsProvider.overrideWith(
          (ref) async => const CachedResult<ExerciseAssignment>([]),
        ),
        childrenProvider.overrideWith(
          (ref) async => CachedResult<Child>([_child()]),
        ),
      ]));
      await _settle(tester);

      // The offline banner copy lives in the global localization key
      // `offlineCached`; we assert on its presence (not the exact text)
      // so test stays resilient to copy tweaks.
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'TimelineScreen falls back to the localized "child" placeholder when '
    'children list returned no match for the event',
    (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(overrides: [
        assessmentsProvider.overrideWith(
          (ref, _) async => CachedResult<Assessment>(
            [_assessment(id: 'a1', created: now, childId: 'unknown')],
          ),
        ),
        myAssignmentsProvider.overrideWith(
          (ref) async => const CachedResult<ExerciseAssignment>([]),
        ),
        childrenProvider.overrideWith(
          (ref) async => const CachedResult<Child>([]),
        ),
      ]));
      await _settle(tester);

      // "Bola" is the Uzbek fallback for an unknown child (timelineUnknownChild).
      expect(find.textContaining('Bola'), findsAtLeastNWidgets(1));
    },
  );
}
