import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/assignments/assignments_screen.dart'
    show AssignmentTile;
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';
import 'package:sado_mobile/widgets/child_assignments_card.dart';
import 'package:sado_mobile/widgets/parrot_mascot.dart';
import 'package:sado_mobile/widgets/shimmer_loaders.dart';

class _RouteSpy {
  String? lastLocation;
}

ExerciseAssignment _assignment({
  required String id,
  String childId = 'c-1',
  String exerciseId = 'ex-1',
  ExerciseAssignmentStatus status = ExerciseAssignmentStatus.pending,
  DateTime? dueDate,
  DateTime? createdAt,
  String? exerciseTitle,
  String? exerciseCategory,
}) {
  return ExerciseAssignment(
    id: id,
    childId: childId,
    exerciseId: exerciseId,
    status: status,
    createdAt: createdAt ?? DateTime(2024, 6, 1),
    updatedAt: createdAt ?? DateTime(2024, 6, 1),
    dueDate: dueDate,
    exercise: exerciseTitle == null
        ? null
        : Exercise(
            id: exerciseId,
            title: exerciseTitle,
            description: 'Practice $exerciseTitle',
            category: exerciseCategory ?? 'articulation',
            ageGroup: '4-5',
            difficulty: 'easy',
            language: 'uz',
            durationMinutes: 5,
            isActive: true,
          ),
  );
}

GoRouter _router(_RouteSpy spy, {String childId = 'c-1'}) {
  return GoRouter(
    initialLocation: '/children/$childId',
    routes: [
      GoRoute(
        path: '/children/:id',
        builder: (_, state) => Scaffold(
          body: SingleChildScrollView(
            child: ChildAssignmentsCard(
              childId: state.pathParameters['id']!,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/assignments',
        builder: (_, state) {
          spy.lastLocation = state.matchedLocation;
          return const Scaffold(body: Text('all-assignments'));
        },
      ),
    ],
  );
}

Widget _wrap({
  required _RouteSpy spy,
  required Override assignmentsOverride,
  String childId = 'c-1',
  Locale locale = const Locale('uz'),
}) {
  return ProviderScope(
    overrides: [assignmentsOverride],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      locale: locale,
      routerConfig: _router(spy, childId: childId),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  group('ChildAssignmentsCard', () {
    testWidgets(
      'hides itself when there are no assignments at all (new child)',
      (tester) async {
        final spy = _RouteSpy();
        await tester.pumpWidget(_wrap(
          spy: spy,
          assignmentsOverride: childAssignmentsProvider.overrideWith(
            (ref, _) async =>
                const CachedResult<ExerciseAssignment>(<ExerciseAssignment>[]),
          ),
        ));
        await _settle(tester);

        expect(find.byKey(const ValueKey('childAssignments.section')),
            findsNothing);
        expect(find.byKey(const ValueKey('childAssignments.empty')),
            findsNothing);
      },
    );

    testWidgets(
      'shows the empty state when only completed assignments exist',
      (tester) async {
        final spy = _RouteSpy();
        await tester.pumpWidget(_wrap(
          spy: spy,
          assignmentsOverride: childAssignmentsProvider.overrideWith(
            (ref, _) async => CachedResult<ExerciseAssignment>([
              _assignment(
                id: 'a-completed',
                status: ExerciseAssignmentStatus.completed,
                exerciseTitle: 'S sound practice',
              ),
            ]),
          ),
        ));
        await _settle(tester);

        expect(find.byKey(const ValueKey('childAssignments.empty')),
            findsOneWidget);
        // uz copy from the existing arb.
        expect(
          find.text('Bu bola uchun hozircha vazifalar yo\'q.'),
          findsOneWidget,
        );
        // Mascot is visible inside the empty state.
        expect(find.byType(ParrotMascot), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the empty card routes to the dedicated assignments screen',
      (tester) async {
        final spy = _RouteSpy();
        await tester.pumpWidget(_wrap(
          spy: spy,
          assignmentsOverride: childAssignmentsProvider.overrideWith(
            (ref, _) async => CachedResult<ExerciseAssignment>([
              _assignment(
                id: 'a-completed',
                status: ExerciseAssignmentStatus.completed,
                exerciseTitle: 'Done one',
              ),
            ]),
          ),
        ));
        await _settle(tester);

        await tester.tap(
          find.byKey(const ValueKey('childAssignments.empty')),
        );
        await tester.pumpAndSettle();
        expect(spy.lastLocation, '/assignments');
      },
    );

    testWidgets(
      'renders a section header + tiles for actionable assignments',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _RouteSpy();
        await tester.pumpWidget(_wrap(
          spy: spy,
          assignmentsOverride: childAssignmentsProvider.overrideWith(
            (ref, _) async => CachedResult<ExerciseAssignment>([
              _assignment(
                id: 'a-1',
                exerciseTitle: 'S sound drill',
              ),
              _assignment(
                id: 'a-2',
                status: ExerciseAssignmentStatus.inProgress,
                exerciseTitle: 'R sound drill',
              ),
            ]),
          ),
        ));
        await _settle(tester);

        expect(find.byKey(const ValueKey('childAssignments.section')),
            findsOneWidget);
        // uz title from the arb.
        expect(find.text('Vazifalar'), findsAtLeastNWidgets(1));
        expect(find.text('S sound drill'), findsOneWidget);
        expect(find.text('R sound drill'), findsOneWidget);
        // Both tiles render via the existing AssignmentTile (so the
        // visual language is shared with the dedicated screen).
        expect(find.byType(AssignmentTile), findsNWidgets(2));
        // No "see all" link when everything fits inline.
        expect(find.byKey(const ValueKey('childAssignments.seeAll')),
            findsNothing);
      },
    );

    testWidgets(
      'caps inline tiles at 3 and surfaces a See all link for the overflow',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _RouteSpy();
        await tester.pumpWidget(_wrap(
          spy: spy,
          assignmentsOverride: childAssignmentsProvider.overrideWith(
            (ref, _) async => CachedResult<ExerciseAssignment>([
              for (var i = 0; i < 5; i++)
                _assignment(
                  id: 'a-$i',
                  exerciseTitle: 'Drill $i',
                ),
            ]),
          ),
        ));
        await _settle(tester);

        expect(find.byType(AssignmentTile), findsNWidgets(3));
        expect(find.byKey(const ValueKey('childAssignments.seeAll')),
            findsOneWidget);
      },
    );

    testWidgets(
      'See all link routes to /assignments',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _RouteSpy();
        await tester.pumpWidget(_wrap(
          spy: spy,
          assignmentsOverride: childAssignmentsProvider.overrideWith(
            (ref, _) async => CachedResult<ExerciseAssignment>([
              for (var i = 0; i < 5; i++)
                _assignment(
                  id: 'a-$i',
                  exerciseTitle: 'Drill $i',
                ),
            ]),
          ),
        ));
        // Settle through the fade-in animation; flutter_animate wraps the
        // section in an AnimatedOpacity / IgnorePointer until the tween
        // completes, so a tap dispatched mid-fade silently misses.
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await tester.ensureVisible(
          find.byKey(const ValueKey('childAssignments.seeAll')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('childAssignments.seeAll')),
        );
        await tester.pumpAndSettle();
        expect(spy.lastLocation, '/assignments');
      },
    );

    testWidgets(
      'See all also surfaces when only history exists alongside <=3 pending',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _RouteSpy();
        await tester.pumpWidget(_wrap(
          spy: spy,
          assignmentsOverride: childAssignmentsProvider.overrideWith(
            (ref, _) async => CachedResult<ExerciseAssignment>([
              _assignment(
                id: 'a-1',
                exerciseTitle: 'Today drill',
              ),
              _assignment(
                id: 'a-2',
                status: ExerciseAssignmentStatus.completed,
                exerciseTitle: 'Old drill',
              ),
            ]),
          ),
        ));
        await _settle(tester);

        // 1 pending tile + see-all link (because of the completed history).
        expect(find.byType(AssignmentTile), findsNWidgets(1));
        expect(find.byKey(const ValueKey('childAssignments.seeAll')),
            findsOneWidget);
      },
    );

    testWidgets(
      'silently hides on transport error so it never competes with the offline banner',
      (tester) async {
        final spy = _RouteSpy();
        await tester.pumpWidget(_wrap(
          spy: spy,
          assignmentsOverride: childAssignmentsProvider.overrideWith(
            (ref, _) async => throw StateError('network down'),
          ),
        ));
        await _settle(tester);

        expect(find.byKey(const ValueKey('childAssignments.section')),
            findsNothing);
        expect(find.byKey(const ValueKey('childAssignments.empty')),
            findsNothing);
        // No exception text leaked into the surface.
        expect(find.textContaining('network down'), findsNothing);
      },
    );

    testWidgets(
      'shimmers while the provider is in flight (no Material spinner)',
      (tester) async {
        final spy = _RouteSpy();
        // A future that we control — the test must complete it before
        // the widget tree disposes, otherwise flutter_test flags a
        // pending timer. We complete it in tearDown after the
        // assertions have run.
        final completer = Completer<CachedResult<ExerciseAssignment>>();
        addTearDown(() {
          if (!completer.isCompleted) {
            completer.complete(
              const CachedResult<ExerciseAssignment>(<ExerciseAssignment>[]),
            );
          }
        });

        await tester.pumpWidget(_wrap(
          spy: spy,
          assignmentsOverride: childAssignmentsProvider.overrideWith(
            (ref, _) => completer.future,
          ),
        ));
        await tester.pump();

        expect(find.byKey(const ValueKey('childAssignments.loading')),
            findsOneWidget);
        expect(find.byType(ShimmerCard), findsAtLeastNWidgets(1));
        // Premium rule: no default Material spinner.
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Drain the future so the test can clean up cleanly.
        completer.complete(
          const CachedResult<ExerciseAssignment>(<ExerciseAssignment>[]),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'renders the Russian title when locale is ru',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _RouteSpy();
        await tester.pumpWidget(_wrap(
          spy: spy,
          locale: const Locale('ru'),
          assignmentsOverride: childAssignmentsProvider.overrideWith(
            (ref, _) async => CachedResult<ExerciseAssignment>([
              _assignment(id: 'a-1', exerciseTitle: 'Drill RU'),
            ]),
          ),
        ));
        await _settle(tester);

        // ru title from the arb.
        expect(find.text('Задания'), findsAtLeastNWidgets(1));
      },
    );
  });
}
