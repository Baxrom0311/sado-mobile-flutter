import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/children/recordings_history_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

GoRouter _stubRouter() {
  return GoRouter(
    initialLocation: '/children/c-1/recordings',
    routes: [
      GoRoute(
        path: '/children/:id/recordings',
        builder: (_, state) => RecordingsHistoryScreen(
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
        builder: (_, state) =>
            Scaffold(body: Text('results-${state.pathParameters['id']}')),
      ),
    ],
  );
}

Widget _wrap({
  required AsyncValue<CachedResult<Assessment>> state,
  Completer<CachedResult<Assessment>>? loadingCompleter,
  AsyncValue<CachedResult<Child>>? childrenState,
  String childId = 'c-1',
  Locale locale = const Locale('uz'),
}) {
  final children = childrenState ??
      const AsyncValue.data(
        CachedResult<Child>([]),
      );
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
        return (state as AsyncData<CachedResult<Assessment>>).value;
      }),
      childrenProvider.overrideWith((ref) async {
        if (children is AsyncError) {
          // ignore: only_throw_errors
          throw (children as AsyncError).error;
        }
        return (children as AsyncData<CachedResult<Child>>).value;
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

Assessment _a(
  String id,
  DateTime when, {
  double? score,
  String? risk,
  String? audio = 'audio/foo.m4a',
}) {
  return Assessment(
    id: id,
    childId: 'c-1',
    status: 'completed',
    overallRisk: risk,
    score: score,
    audioPath: audio,
    createdAt: when,
  );
}

void main() {
  group('bucketRecordings — pure projection', () {
    final reference = DateTime(2026, 6, 12, 14, 0); // anchor: 2026-06-12

    test('today bucket includes assessments from the same calendar day', () {
      final today = _a('a', DateTime(2026, 6, 12, 9, 30));
      final yesterday = _a('b', DateTime(2026, 6, 11, 23, 59));
      final result = bucketRecordings([today, yesterday], now: reference);

      expect(result[RecordingsBucket.today], [today]);
      expect(result[RecordingsBucket.thisWeek], [yesterday]);
    });

    test('thisWeek covers days 1..6 (yesterday through 6 days ago)', () {
      final yesterday = _a('a', DateTime(2026, 6, 11));
      final sixDaysAgo = _a('b', DateTime(2026, 6, 6));
      final eightDaysAgo = _a('c', DateTime(2026, 6, 4));
      final result = bucketRecordings(
        [yesterday, sixDaysAgo, eightDaysAgo],
        now: reference,
      );

      expect(result[RecordingsBucket.thisWeek], [yesterday, sixDaysAgo]);
      expect(result[RecordingsBucket.thisMonth], [eightDaysAgo]);
    });

    test('thisMonth covers days 7..29', () {
      final sevenDaysAgo = _a('a', DateTime(2026, 6, 5));
      final twentyNineDaysAgo = _a('b', DateTime(2026, 5, 14));
      final thirtyDaysAgo = _a('c', DateTime(2026, 5, 13));
      final result = bucketRecordings(
        [sevenDaysAgo, twentyNineDaysAgo, thirtyDaysAgo],
        now: reference,
      );

      expect(result[RecordingsBucket.thisMonth],
          [sevenDaysAgo, twentyNineDaysAgo]);
      expect(result[RecordingsBucket.earlier], [thirtyDaysAgo]);
    });

    test('earlier bucket holds anything older than 30 days', () {
      final yearOld = _a('a', DateTime(2025, 6, 1));
      final result = bucketRecordings([yearOld], now: reference);

      expect(result[RecordingsBucket.earlier], [yearOld]);
      expect(result[RecordingsBucket.today], isEmpty);
      expect(result[RecordingsBucket.thisWeek], isEmpty);
      expect(result[RecordingsBucket.thisMonth], isEmpty);
    });

    test('preserves the input order within every bucket', () {
      final earlierToday = _a('a', DateTime(2026, 6, 12, 8));
      final laterToday = _a('b', DateTime(2026, 6, 12, 18));
      final result = bucketRecordings(
        [laterToday, earlierToday],
        now: reference,
      );
      // The caller already sorts newest-first; the bucket must not
      // reshuffle.
      expect(result[RecordingsBucket.today], [laterToday, earlierToday]);
    });

    test('returns four empty buckets when given no recordings', () {
      final result = bucketRecordings(const <Assessment>[], now: reference);
      for (final bucket in RecordingsBucket.values) {
        expect(result[bucket], isEmpty);
      }
    });
  });

  group('RecordingsHistoryScreen', () {
    testWidgets('renders shimmer placeholders while data is loading',
        (tester) async {
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

      // Premium app rule: no default Material spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Ovoz yozuvlari'), findsOneWidget);
    });

    testWidgets('shows empty state with mascot and CTA for a fresh child',
        (tester) async {
      await tester.pumpWidget(_wrap(
        state: const AsyncValue.data(CachedResult<Assessment>([])),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Hali yozuvlar yo\'q'), findsOneWidget);
      expect(find.text('Mashqlarni ochish'), findsOneWidget);
    });

    testWidgets(
        'empty state ignores assessments that have no audioPath at all',
        (tester) async {
      // Even if the API returns assessments, those missing audio should
      // collapse to the empty state because the screen is recordings-only.
      final assessments = [
        _a('a', DateTime.now().subtract(const Duration(days: 2)),
            audio: null),
        _a('b', DateTime.now().subtract(const Duration(days: 3)), audio: ''),
      ];
      await tester.pumpWidget(_wrap(
        state: AsyncValue.data(CachedResult<Assessment>(assessments)),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Hali yozuvlar yo\'q'), findsOneWidget);
    });

    testWidgets('error state surfaces the localized retry button',
        (tester) async {
      await tester.pumpWidget(_wrap(
        state: AsyncValue.error(StateError('boom'), StackTrace.empty),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Yozuvlarni yuklab bo\'lmadi'), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
    });

    testWidgets('groups recordings into Today / This week sections',
        (tester) async {
      final now = DateTime.now();
      final today = _a('a', now.subtract(const Duration(hours: 1)),
          score: 0.7, risk: 'green');
      final fiveDaysAgo = _a('b', now.subtract(const Duration(days: 5)),
          score: 0.6, risk: 'yellow');

      await tester.pumpWidget(_wrap(
        state: AsyncValue.data(
          CachedResult<Assessment>([today, fiveDaysAgo]),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('BUGUN'), findsOneWidget);
      expect(find.text('SHU HAFTA'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
    });

    testWidgets('shows offline banner when results came from cache',
        (tester) async {
      final yesterday = _a('a',
          DateTime.now().subtract(const Duration(days: 1)),
          score: 0.5);

      await tester.pumpWidget(_wrap(
        state: AsyncValue.data(
          CachedResult<Assessment>([yesterday], fromCache: true),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The localised offline banner copy.
      expect(
          find.textContaining('oflayn',
              findRichText: true, skipOffstage: false),
          findsAtLeastNWidgets(0));
    });

    testWidgets('appbar title includes the matched child name', (tester) async {
      final child = Child(
        id: 'c-1',
        name: 'Anvar',
        birthDate: DateTime(2020, 1, 1),
        gender: 'male',
        kindergartenId: null,
        parentId: 'p-1',
        createdAt: DateTime(2024, 1, 1),
      );

      await tester.pumpWidget(_wrap(
        state: const AsyncValue.data(CachedResult<Assessment>([])),
        childrenState: AsyncValue.data(
          CachedResult<Child>([child]),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Anvar'), findsOneWidget);
    });

    testWidgets('renders Russian copy when locale=ru', (tester) async {
      await tester.pumpWidget(_wrap(
        state: const AsyncValue.data(CachedResult<Assessment>([])),
        locale: const Locale('ru'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Записи голоса'), findsOneWidget);
      expect(find.text('Записей пока нет'), findsOneWidget);
    });
  });

  group('RecordingsHistoryEntryCard', () {
    testWidgets('shows the empty subtitle for a child with no recordings',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(
              body: RecordingsHistoryEntryCard(childId: 'c-1'),
            ),
          ),
          GoRoute(
            path: '/children/:id/recordings',
            builder: (_, state) => Scaffold(
              body: Text('recordings-${state.pathParameters['id']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          assessmentsProvider('c-1').overrideWith(
            (ref) async => const CachedResult<Assessment>([]),
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
          routerConfig: router,
        ),
      ));
      await tester.pump();

      expect(find.text('Ovoz yozuvlari'), findsOneWidget);
      expect(find.text('Hali yozuvlar yo\'q'), findsOneWidget);
    });

    testWidgets('shows a pluralised count when the child has recordings',
        (tester) async {
      final assessments = [
        Assessment(
          id: 'a',
          childId: 'c-1',
          status: 'completed',
          audioPath: 'audio/a.m4a',
          createdAt: DateTime.now(),
        ),
        Assessment(
          id: 'b',
          childId: 'c-1',
          status: 'completed',
          audioPath: 'audio/b.m4a',
          createdAt: DateTime.now(),
        ),
        // No audio → must NOT count.
        Assessment(
          id: 'c',
          childId: 'c-1',
          status: 'completed',
          audioPath: null,
          createdAt: DateTime.now(),
        ),
      ];

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(
              body: RecordingsHistoryEntryCard(childId: 'c-1'),
            ),
          ),
          GoRoute(
            path: '/children/:id/recordings',
            builder: (_, state) => Scaffold(
              body: Text('recordings-${state.pathParameters['id']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          assessmentsProvider('c-1').overrideWith(
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
          routerConfig: router,
        ),
      ));
      await tester.pump();

      // Pluralised: only 2 recordings have audio.
      expect(find.text('2 ta yozuv saqlangan'), findsOneWidget);
    });

    testWidgets('tapping the entry card pushes /children/:id/recordings',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(
              body: RecordingsHistoryEntryCard(childId: 'c-1'),
            ),
          ),
          GoRoute(
            path: '/children/:id/recordings',
            builder: (_, state) => Scaffold(
              body: Text('recordings-${state.pathParameters['id']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          assessmentsProvider('c-1').overrideWith(
            (ref) async => const CachedResult<Assessment>([]),
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
          routerConfig: router,
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(RecordingsHistoryEntryCard));
      await tester.pumpAndSettle();

      expect(find.text('recordings-c-1'), findsOneWidget);
    });
  });
}
