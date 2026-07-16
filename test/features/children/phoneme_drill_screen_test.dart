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
import 'package:sado_mobile/domain/speech_profile/phoneme_mastery.dart';
import 'package:sado_mobile/features/children/phoneme_drill_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

GoRouter _stubRouter() {
  return GoRouter(
    initialLocation: '/children/c-1/phonemes/r',
    routes: [
      GoRoute(
        path: '/children/:id/phonemes/:phoneme',
        builder: (_, state) => PhonemeDrillScreen(
          childId: state.pathParameters['id']!,
          phoneme: state.pathParameters['phoneme']!,
        ),
      ),
      GoRoute(
        path: '/children/:id/speech-profile',
        builder: (_, state) => Scaffold(
          body: Text('speech-profile-${state.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: '/exercises',
        builder: (_, __) => const Scaffold(body: Text('exercises-stub')),
      ),
      GoRoute(
        path: '/exercises/:id',
        builder: (_, state) => Scaffold(
          body: Text('exercise-${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
}

Exercise _exercise({
  required String id,
  required String title,
  String difficulty = 'easy',
  int durationMinutes = 5,
  List<String>? targetPhonemes,
}) =>
    Exercise(
      id: id,
      title: title,
      description: 'desc',
      category: 'articulation',
      ageGroup: '5-6',
      difficulty: difficulty,
      language: 'uz',
      durationMinutes: durationMinutes,
      targetPhonemes: targetPhonemes,
      isActive: true,
    );

PhonemeDrillData _drillData({
  String phoneme = 'r',
  PhonemeMastery? mastery,
  List<Exercise> exercises = const [],
  bool fromCache = false,
}) {
  return PhonemeDrillData(
    phoneme: phoneme,
    mastery: mastery,
    exercises: exercises,
    exercisesFromCache: fromCache,
  );
}

Widget _wrap({
  required AsyncValue<PhonemeDrillData> state,
  Completer<PhonemeDrillData>? loadingCompleter,
  String childId = 'c-1',
  String phoneme = 'r',
  Locale locale = const Locale('uz'),
}) {
  return ProviderScope(
    overrides: [
      phonemeDrillProvider((childId: childId, phoneme: phoneme))
          .overrideWith((ref) async {
        if (state is AsyncError) {
          // ignore: only_throw_errors
          throw (state as AsyncError).error;
        }
        if (state is AsyncLoading) {
          final c = loadingCompleter ?? Completer<PhonemeDrillData>();
          return c.future;
        }
        return (state as AsyncData).value as PhonemeDrillData;
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

void main() {
  late Directory hiveDir;
  setUpAll(() {
    hiveDir =
        Directory.systemTemp.createTempSync('sado_phoneme_drill_test_');
    Hive.init(hiveDir.path);
  });
  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  group('filterExercisesByPhoneme', () {
    test('drops exercises with no targetPhonemes', () {
      final exercises = [
        _exercise(id: 'a', title: 'A'),
        _exercise(id: 'b', title: 'B', targetPhonemes: const ['r']),
      ];
      final filtered = filterExercisesByPhoneme(exercises, 'r');
      expect(filtered.map((e) => e.id), ['b']);
    });

    test('matches case-insensitively and tolerates slashes / brackets', () {
      final exercises = [
        _exercise(id: 'a', title: 'A', targetPhonemes: const ['/R/']),
        _exercise(id: 'b', title: 'B', targetPhonemes: const ['[r]']),
        _exercise(id: 'c', title: 'C', targetPhonemes: const ['s']),
      ];
      final filtered = filterExercisesByPhoneme(exercises, 'r');
      expect(filtered.map((e) => e.id), ['a', 'b']);
    });

    test('sorts by difficulty (easy → medium → hard) then by duration',
        () {
      final exercises = [
        _exercise(
          id: 'hard',
          title: 'Hard',
          difficulty: 'hard',
          durationMinutes: 1,
          targetPhonemes: const ['r'],
        ),
        _exercise(
          id: 'easy-long',
          title: 'Easy long',
          difficulty: 'easy',
          durationMinutes: 10,
          targetPhonemes: const ['r'],
        ),
        _exercise(
          id: 'easy-short',
          title: 'Easy short',
          difficulty: 'easy',
          durationMinutes: 3,
          targetPhonemes: const ['r'],
        ),
        _exercise(
          id: 'medium',
          title: 'Medium',
          difficulty: 'medium',
          durationMinutes: 5,
          targetPhonemes: const ['r'],
        ),
      ];
      final filtered = filterExercisesByPhoneme(exercises, 'r');
      expect(
        filtered.map((e) => e.id),
        ['easy-short', 'easy-long', 'medium', 'hard'],
      );
    });

    test('returns an unmodifiable list', () {
      final exercises = [
        _exercise(id: 'a', title: 'A', targetPhonemes: const ['r']),
      ];
      final filtered = filterExercisesByPhoneme(exercises, 'r');
      expect(() => filtered.add(exercises.first), throwsUnsupportedError);
    });

    test('returns an empty list for whitespace / blank phoneme input', () {
      final exercises = [
        _exercise(id: 'a', title: 'A', targetPhonemes: const ['r']),
      ];
      expect(filterExercisesByPhoneme(exercises, '   '), isEmpty);
      expect(filterExercisesByPhoneme(exercises, ''), isEmpty);
    });
  });

  group('PhonemeDrillScreen', () {
    testWidgets('shows shimmer placeholders while loading', (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final completer = Completer<PhonemeDrillData>();
      addTearDown(() {
        if (!completer.isCompleted) completer.complete(_drillData());
      });

      await tester.pumpWidget(_wrap(
        state: const AsyncValue.loading(),
        loadingCompleter: completer,
      ));
      await tester.pump();

      expect(
        find.bySemanticsLabel('Mashqlar tanlanmoqda…'),
        findsOneWidget,
      );
    });

    testWidgets(
        'renders the localized error state with a retry CTA when the '
        'provider throws', (tester) async {
      await tester.pumpWidget(_wrap(
        state: AsyncValue.error('boom', StackTrace.empty),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mashqlarni yuklab bo\'lmadi'), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
    });

    testWidgets(
        'renders the empty state with the browse-all CTA when no '
        'exercises target this phoneme yet', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final data = _drillData(
        mastery: const PhonemeMastery(
          phoneme: 'r',
          sampleCount: 3,
          weakCount: 2,
          accuracy: 0.40,
        ),
      );

      await tester.pumpWidget(_wrap(state: AsyncValue.data(data)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Hozircha bu tovush bo\'yicha mashq yo\'q'),
        findsOneWidget,
      );
      // The empty-state CTA + the body link both spell "browse all";
      // the empty-state widget alone owns the button.
      expect(find.text('Barcha mashqlarni ko\'rish'), findsOneWidget);
    });

    testWidgets(
        'with mastery data renders the hero accuracy ring, the coach '
        'card and one tile per recommended exercise', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final data = _drillData(
        mastery: const PhonemeMastery(
          phoneme: 'r',
          sampleCount: 7,
          weakCount: 5,
          accuracy: 0.30, // struggling bucket
        ),
        exercises: [
          _exercise(
            id: 'rolling',
            title: 'Rolling Rrr',
            targetPhonemes: const ['r'],
          ),
          _exercise(
            id: 'rocket',
            title: 'Rocket Race',
            difficulty: 'medium',
            targetPhonemes: const ['r'],
          ),
        ],
      );

      await tester.pumpWidget(_wrap(state: AsyncValue.data(data)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 800));

      // Hero shows the percent and the localized samples line.
      expect(find.text('30%'), findsOneWidget);
      expect(
        find.text('7 ta urinish oxirgi tahlillarda'),
        findsOneWidget,
      );

      // Struggling bucket → coach copy that calls for focus.
      expect(
        find.text(
            'Bu tovush ustida birga ishlaymiz! Quyidagi mashqlar bola uchun maxsus tanlangan.'),
        findsOneWidget,
      );

      // One tile per recommended exercise.
      expect(find.text('Rolling Rrr'), findsOneWidget);
      expect(find.text('Rocket Race'), findsOneWidget);

      // Counter chip in the header reflects the list size.
      expect(find.text('2 ta mos mashq'), findsOneWidget);

      // Primary CTA renders.
      expect(find.text('Birinchi mashqni boshlash'), findsOneWidget);
    });

    testWidgets(
        'with no mastery yet still renders the exercises so a parent '
        'can start practising the very first time', (tester) async {
      tester.view.physicalSize = const Size(900, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final data = _drillData(
        exercises: [
          _exercise(
            id: 'sun',
            title: 'Sun song',
            targetPhonemes: const ['r'],
          ),
        ],
      );

      await tester.pumpWidget(_wrap(state: AsyncValue.data(data)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));

      // Hero falls back to the friendly "no analysis yet" copy.
      expect(
        find.text('Hozircha tahlil qilingan tovushlar yo\'q'),
        findsOneWidget,
      );
      // List still surfaces the exercise.
      expect(find.text('Sun song'), findsOneWidget);
    });

    testWidgets(
        'tapping the primary CTA routes to /exercises/{id} for the first '
        'recommended exercise and bumps the active child', (tester) async {
      tester.view.physicalSize = const Size(900, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final data = _drillData(
        mastery: const PhonemeMastery(
          phoneme: 'r',
          sampleCount: 4,
          weakCount: 1,
          accuracy: 0.75,
        ),
        exercises: [
          _exercise(
            id: 'rolling',
            title: 'Rolling Rrr',
            targetPhonemes: const ['r'],
          ),
        ],
      );

      await tester.pumpWidget(_wrap(state: AsyncValue.data(data)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('Birinchi mashqni boshlash'));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.text('exercise-rolling'), findsOneWidget);
    });

    testWidgets(
        'shows the offline-cached banner when the exercises came from '
        'the local snapshot', (tester) async {
      tester.view.physicalSize = const Size(900, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final data = _drillData(
        fromCache: true,
        exercises: [
          _exercise(
            id: 'rolling',
            title: 'Rolling Rrr',
            targetPhonemes: const ['r'],
          ),
        ],
      );

      await tester.pumpWidget(_wrap(state: AsyncValue.data(data)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Oflayn rejim — keshlangan ma\'lumot'), findsOneWidget);
    });

    testWidgets('renders Russian copy when locale=ru', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final data = _drillData(
        mastery: const PhonemeMastery(
          phoneme: 'r',
          sampleCount: 3,
          weakCount: 0,
          accuracy: 0.90,
        ),
        exercises: [
          _exercise(
            id: 'rolling',
            title: 'Rolling Rrr',
            targetPhonemes: const ['r'],
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(state: AsyncValue.data(data), locale: const Locale('ru')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Mastered bucket → celebratory copy in Russian.
      expect(
        find.text(
            'Отлично! Ребёнок уверенно произносит этот звук. Закрепите результат регулярной практикой.'),
        findsOneWidget,
      );
      expect(find.text('Начать первое упражнение'), findsOneWidget);
    });
  });
}
