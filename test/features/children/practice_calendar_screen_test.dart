import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/children/practice_calendar_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

GoRouter _stubRouter() {
  return GoRouter(
    initialLocation: '/children/c-1/calendar',
    routes: [
      GoRoute(
        path: '/children/:id/calendar',
        builder: (_, state) => PracticeCalendarScreen(
          childId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/children/:id',
        builder: (_, state) =>
            Scaffold(body: Text('child-${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/exercises',
        builder: (_, __) => const Scaffold(body: Text('exercises-stub')),
      ),
      GoRoute(
        path: '/assessment/results/:id',
        builder: (_, state) => Scaffold(
            body: Text('results-${state.pathParameters['id']}')),
      ),
    ],
  );
}

Widget _wrap({
  required AsyncValue<CachedResult<Assessment>> state,
  Completer<CachedResult<Assessment>>? loadingCompleter,
  String childId = 'c-1',
  Locale locale = const Locale('uz'),
}) {
  return ProviderScope(
    overrides: [
      assessmentsProvider(childId).overrideWith((ref) async {
        if (state is AsyncError) {
          // ignore: only_throw_errors
          throw (state as AsyncError).error;
        }
        if (state is AsyncLoading) {
          final c = loadingCompleter ?? Completer<CachedResult<Assessment>>();
          return c.future;
        }
        return (state as AsyncData).value as CachedResult<Assessment>;
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
      locale: locale,
      routerConfig: _stubRouter(),
    ),
  );
}

Assessment _a(String id, DateTime when, {double? score, String? risk}) {
  return Assessment(
    id: id,
    childId: 'c-1',
    status: 'completed',
    overallRisk: risk,
    score: score,
    createdAt: when,
  );
}

void main() {
  group('PracticeCalendarScreen', () {
    testWidgets('renders shimmer skeleton while assessments load',
        (tester) async {
      // Never-completing completer + tearDown so pending timers don't
      // survive the test body — `flutter_test` fails the suite when a
      // Timer leaks past the end of `testWidgets`.
      final pending = Completer<CachedResult<Assessment>>();
      addTearDown(() {
        if (!pending.isCompleted) {
          pending.complete(const CachedResult<Assessment>([]));
        }
      });

      await tester.pumpWidget(_wrap(
        state: const AsyncValue.loading(),
        loadingCompleter: pending,
      ));
      await tester.pump();

      // No CircularProgressIndicator — premium app rule.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Mashq taqvimi'), findsOneWidget);
    });

    testWidgets('shows empty state with mascot for a child with no history',
        (tester) async {
      await tester.pumpWidget(_wrap(
        state: const AsyncValue.data(CachedResult<Assessment>([])),
      ));
      await tester.pump(); // build
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('practiceCalendar.empty')),
          findsOneWidget);
      expect(find.text('Hali mashqlar yo\'q'), findsOneWidget);
      // Empty state surfaces a CTA into the exercises catalogue.
      expect(find.text('Mashqni boshlash'), findsOneWidget);
    });

    testWidgets('error state surfaces the localized retry button',
        (tester) async {
      await tester.pumpWidget(_wrap(
        state: AsyncValue.error(StateError('boom'), StackTrace.empty),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Taqvimni yuklab bo\'lmadi'), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
    });

    testWidgets('renders the month label and 1..n day cells with data',
        (tester) async {
      // Anchor to a date during the test so the visible "today" is real.
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1);
      final assessments = [
        _a('a1', firstOfMonth, score: 0.7),
      ];

      await tester.pumpWidget(_wrap(
        state: AsyncValue.data(CachedResult<Assessment>(assessments)),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The very first day of the month is always rendered.
      expect(find.text('1'), findsWidgets);
      // Stats card shows the total session count we provided.
      expect(find.text('${assessments.length}'), findsWidgets);
    });

    testWidgets('renders Russian copy when locale is ru', (tester) async {
      await tester.pumpWidget(_wrap(
        state: const AsyncValue.data(CachedResult<Assessment>([])),
        locale: const Locale('ru'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Календарь занятий'), findsOneWidget);
      expect(find.text('Занятий пока нет'), findsOneWidget);
    });

    testWidgets(
        'PracticeCalendarEntryCard routes to /children/:id/calendar on tap',
        (tester) async {
      // Mount the card on a stub home and verify it pushes the calendar.
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(
              body: PracticeCalendarEntryCard(childId: 'c-1'),
            ),
          ),
          GoRoute(
            path: '/children/:id/calendar',
            builder: (_, state) => Scaffold(
              body: Text('calendar-${state.pathParameters['id']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
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
          routerConfig: router,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('practiceCalendar.entryCard')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('calendar-c-1'), findsOneWidget);
    });
  });
}
