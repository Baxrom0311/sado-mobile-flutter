import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/assignments/assignments_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

ExerciseAssignment _assignment({
  String id = 'a-1',
  String childId = 'c-1',
  String exerciseId = 'ex-1',
  ExerciseAssignmentStatus status = ExerciseAssignmentStatus.pending,
  DateTime? dueDate,
  DateTime? completedAt,
  String? notes,
  Exercise? exercise,
}) {
  return ExerciseAssignment(
    id: id,
    childId: childId,
    exerciseId: exerciseId,
    status: status,
    dueDate: dueDate,
    completedAt: completedAt,
    notes: notes,
    createdAt: DateTime.utc(2026, 6, 10),
    updatedAt: DateTime.utc(2026, 6, 10),
    exercise: exercise,
  );
}

Exercise _exercise({
  String id = 'ex-1',
  String title = 'R tovushi',
  String category = 'articulation',
}) =>
    Exercise(
      id: id,
      title: title,
      description: 'Mashq qilamiz',
      category: category,
      ageGroup: '4-5',
      difficulty: 'easy',
      language: 'uz',
      durationMinutes: 5,
      isActive: true,
    );

GoRouter _stubRouter() {
  return GoRouter(
    initialLocation: '/assignments',
    routes: [
      GoRoute(
        path: '/assignments',
        builder: (_, __) => const AssignmentsScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('home-stub')),
      ),
      GoRoute(
        path: '/assessment/intro/:childId/:exerciseId',
        builder: (_, state) => Scaffold(
          body: Text(
            'intro-${state.pathParameters['childId']}-${state.pathParameters['exerciseId']}',
          ),
        ),
      ),
    ],
  );
}

Widget _wrap({
  required AsyncValue<CachedResult<ExerciseAssignment>> state,
  Completer<CachedResult<ExerciseAssignment>>? loadingCompleter,
}) {
  return ProviderScope(
    overrides: [
      myAssignmentsProvider.overrideWith((ref) async {
        if (state is AsyncError) {
          // ignore: only_throw_errors
          throw (state as AsyncError).error;
        }
        if (state is AsyncLoading) {
          // The test owns the completer so it can complete (or cancel)
          // the future explicitly via [Completer.complete] before the
          // widget is disposed. Avoids leaking pending timers.
          final c = loadingCompleter ??
              Completer<CachedResult<ExerciseAssignment>>();
          return c.future;
        }
        return (state as AsyncData).value
            as CachedResult<ExerciseAssignment>;
      }),
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
      routerConfig: _stubRouter(),
    ),
  );
}

void main() {
  // Hive must be initialised even though this screen doesn't use it
  // directly — the providers tree pulls it in via the cache helpers.
  late Directory hiveDir;
  setUpAll(() {
    hiveDir = Directory.systemTemp.createTempSync('sado_assignments_test_');
    Hive.init(hiveDir.path);
  });
  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  group('AssignmentsScreen', () {
    testWidgets('shows shimmer placeholders while data is loading',
        (tester) async {
      final completer = Completer<CachedResult<ExerciseAssignment>>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete(CachedResult<ExerciseAssignment>(const []));
        }
      });
      await tester.pumpWidget(_wrap(
        state: const AsyncValue.loading(),
        loadingCompleter: completer,
      ));
      await tester.pump();
      // Loading state surfaces a Semantics label so screen readers don't
      // see a blank screen — and we get a unique anchor to assert against.
      expect(
        find.bySemanticsLabel('Vazifalar yuklanmoqda…'),
        findsOneWidget,
      );
    });

    testWidgets('renders the empty state when the parent has no assignments',
        (tester) async {
      await tester.pumpWidget(_wrap(
        state: AsyncValue.data(
            CachedResult<ExerciseAssignment>(const [])),
      ));
      // Empty state animates in via `flutter_animate` which schedules
      // a steady tick stream; pump a few discrete frames instead of
      // `pumpAndSettle` so we don't time out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Hozircha vazifalar yo\'q'), findsOneWidget);
    });

    testWidgets(
        'renders the error state with a localized retry CTA when the '
        'provider throws', (tester) async {
      await tester.pumpWidget(_wrap(
        state: AsyncValue.error(
          'boom',
          StackTrace.empty,
        ),
      ));
      // ErrorState wraps its content in a flutter_animate cascade that
      // never settles in tests (the animation library schedules ticks
      // perpetually for repeated transitions); pump a few discrete
      // frames so the FutureProvider rejects, then assert without
      // pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vazifalarni yuklab bo\'lmadi'), findsOneWidget);
      expect(find.text('Qayta urinib ko\'rish'), findsOneWidget);
    });

    testWidgets(
        'splits actionable items into a "to do" section above the '
        '"completed" section', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pending = _assignment(
        id: 'a-pending',
        status: ExerciseAssignmentStatus.pending,
        dueDate: DateTime.now().add(const Duration(days: 2)),
        exercise: _exercise(title: 'R tovushi'),
      );
      final completed = _assignment(
        id: 'a-done',
        status: ExerciseAssignmentStatus.completed,
        completedAt: DateTime.utc(2026, 6, 9),
        exercise: _exercise(id: 'ex-2', title: 'S tovushi'),
      );

      await tester.pumpWidget(_wrap(
        state: AsyncValue.data(CachedResult<ExerciseAssignment>(
          [pending, completed],
        )),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Bajarish kerak'), findsOneWidget);
      // "Bajarilgan" appears as both the section header AND the status
      // chip on the completed tile, so we expect at least 2 — but not
      // zero. This guards regression on either signal.
      expect(find.text('Bajarilgan'), findsNWidgets(2));
      expect(find.text('R tovushi'), findsOneWidget);
      expect(find.text('S tovushi'), findsOneWidget);

      // The pending tile renders the start CTA; completed ones don't.
      expect(
        find.byKey(const ValueKey('assignment.start.a-pending')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('assignment.start.a-done')),
        findsNothing,
      );
    });

    testWidgets('overdue chip surfaces the localized warning copy',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final overdue = _assignment(
        id: 'a-overdue',
        status: ExerciseAssignmentStatus.pending,
        dueDate: DateTime.utc(2000, 1, 1),
        exercise: _exercise(title: 'X tovushi'),
      );

      await tester.pumpWidget(_wrap(
        state: AsyncValue.data(
            CachedResult<ExerciseAssignment>([overdue])),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Muddati o\'tgan'), findsOneWidget);
    });

    testWidgets(
        'embedded therapist notes render in the muted notes block when '
        'present', (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final withNotes = _assignment(
        id: 'a-notes',
        status: ExerciseAssignmentStatus.pending,
        notes: 'Each evening before bed',
        exercise: _exercise(),
      );

      await tester.pumpWidget(_wrap(
        state: AsyncValue.data(
            CachedResult<ExerciseAssignment>([withNotes])),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Logoped izohi'), findsOneWidget);
      expect(find.text('Each evening before bed'), findsOneWidget);
    });
  });

  group('sortAssignmentsForUi', () {
    test('actionable assignments come before terminal ones', () {
      final pending = _assignment(
        id: 'p',
        status: ExerciseAssignmentStatus.pending,
      );
      final completed = _assignment(
        id: 'c',
        status: ExerciseAssignmentStatus.completed,
        completedAt: DateTime.utc(2026, 6, 11),
      );
      final out = sortAssignmentsForUi([completed, pending]);
      expect(out.first.id, 'p');
      expect(out.last.id, 'c');
    });

    test('overdue actionable items sort before due-soon ones', () {
      final overdue = _assignment(
        id: 'over',
        status: ExerciseAssignmentStatus.pending,
        dueDate: DateTime.utc(2000, 1, 1),
      );
      final dueSoon = _assignment(
        id: 'soon',
        status: ExerciseAssignmentStatus.pending,
        dueDate: DateTime.now().add(const Duration(days: 5)),
      );
      final out = sortAssignmentsForUi([dueSoon, overdue]);
      expect(out.first.id, 'over');
    });

    test('within actionable: nearer due date wins, nulls sort last', () {
      final near = _assignment(
        id: 'near',
        status: ExerciseAssignmentStatus.pending,
        dueDate: DateTime.now().add(const Duration(days: 1)),
      );
      final far = _assignment(
        id: 'far',
        status: ExerciseAssignmentStatus.pending,
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );
      final undated = _assignment(
        id: 'open',
        status: ExerciseAssignmentStatus.pending,
      );
      final out = sortAssignmentsForUi([far, undated, near]);
      expect(out.map((a) => a.id).toList(), ['near', 'far', 'open']);
    });
  });
}
