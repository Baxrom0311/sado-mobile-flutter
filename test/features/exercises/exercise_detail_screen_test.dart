import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/api_client.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/exercises/exercise_detail_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

Exercise _exercise({
  String id = 'ex-1',
  String title = 'R tovushi mashqi',
  String description = 'Tilni yumshoq tanglayga tegizib R ni talaffuz qiling.',
  String category = 'articulation',
  String ageGroup = '5-6',
  String difficulty = 'medium',
  int durationMinutes = 7,
  String? instructions = 'Avval ohista, keyin tezroq takrorlang.',
  List<String>? targetPhonemes = const ['R', 'RR'],
}) {
  return Exercise(
    id: id,
    title: title,
    description: description,
    category: category,
    ageGroup: ageGroup,
    difficulty: difficulty,
    language: 'uz',
    durationMinutes: durationMinutes,
    instructions: instructions,
    targetPhonemes: targetPhonemes,
    isActive: true,
  );
}

Child _child({
  String id = 'c-1',
  String name = 'Aziza',
  String gender = 'female',
}) {
  return Child(
    id: id,
    name: name,
    birthDate: DateTime(2019, 4, 1),
    gender: gender,
    parentId: 'p-1',
    createdAt: DateTime(2024, 1, 1),
  );
}

class _RouteSpy {
  String? lastLocation;
  Map<String, String> lastParams = const {};
}

GoRouter _router(_RouteSpy spy, {required String exerciseId}) {
  Widget stub(String tag, GoRouterState state) {
    spy.lastLocation = state.matchedLocation;
    spy.lastParams = Map<String, String>.from(state.pathParameters);
    return Scaffold(body: Text('STUB:$tag'));
  }

  return GoRouter(
    initialLocation: '/exercises/$exerciseId',
    routes: [
      GoRoute(
        path: '/exercises',
        builder: (_, state) => stub('list', state),
      ),
      GoRoute(
        path: '/exercises/:id',
        builder: (_, state) =>
            ExerciseDetailScreen(exerciseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/children/add',
        builder: (_, state) => stub('add-child', state),
      ),
      GoRoute(
        path: '/assessment/intro/:childId/:exerciseId',
        builder: (_, state) => stub('intro', state),
      ),
    ],
  );
}

Widget _wrap({
  required _RouteSpy spy,
  required String exerciseId,
  required List<Exercise> exercises,
  required List<Child> children,
}) {
  return ProviderScope(
    overrides: [
      // Avoid hitting a real Dio; the screen never makes a request because
      // we override the data providers below, but [exercisesProvider]'s
      // implementation reads the api as a side-effect.
      dioProvider.overrideWithValue(Dio()),
      exercisesProvider.overrideWith(
        (ref) async => CachedResult<Exercise>(exercises),
      ),
      childrenProvider.overrideWith(
        (ref) async => CachedResult<Child>(children),
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
      routerConfig: _router(spy, exerciseId: exerciseId),
    ),
  );
}

/// Pumps long enough for [flutter_animate] entrance effects + the
/// FutureProvider data resolution to settle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Replaces the running widget tree with a sentinel so any pending
/// AnimationControllers used by the parrot mascot or flutter_animate
/// effects get a chance to dispose cleanly.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets(
    'renders exercise title, description, instructions and target phonemes',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      final ex = _exercise();
      await tester.pumpWidget(_wrap(
        spy: spy,
        exerciseId: ex.id,
        exercises: [ex],
        children: [_child()],
      ));
      await _settle(tester);

      // Title is rendered in two places: once in the SliverAppBar's
      // collapsing title, and once in the Hero header row at the top of
      // the body so it stays visible after the user scrolls past the
      // expanded app bar.
      expect(find.text('R tovushi mashqi'), findsNWidgets(2));
      expect(
        find.text('Tilni yumshoq tanglayga tegizib R ni talaffuz qiling.'),
        findsOneWidget,
      );
      expect(
        find.text('Avval ohista, keyin tezroq takrorlang.'),
        findsOneWidget,
      );
      // Each target phoneme renders as its own pill so the parent can
      // scan the targeted sounds at a glance.
      expect(find.text('R'), findsOneWidget);
      expect(find.text('RR'), findsOneWidget);
      // The legacy CSV literal must NOT be rendered anymore — we now own
      // the layout and chip the values out individually.
      expect(find.text('R, RR'), findsNothing);

      // Section headers for description / instructions / target sounds use
      // the localized labels.
      expect(find.text('Tavsif'), findsOneWidget);
      expect(find.text('Yo\'riqnoma'), findsOneWidget);
      expect(find.text('Tovushlar'), findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'renders the metadata chip row (duration, difficulty, age group, category)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      final ex = _exercise();
      await tester.pumpWidget(_wrap(
        spy: spy,
        exerciseId: ex.id,
        exercises: [ex],
        children: [_child()],
      ));
      await _settle(tester);

      // Duration chip uses the localized "daqiqa" suffix.
      expect(find.text('7 daqiqa'), findsOneWidget);
      // Difficulty chip shows the localized "O'rtacha" label.
      expect(find.text('O\'rtacha'), findsOneWidget);
      // Age-group token "5-6" maps to "5-6 yosh".
      expect(find.text('5-6 yosh'), findsOneWidget);
      // Category "articulation" → "Talaffuz".
      expect(find.text('Talaffuz'), findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'when the parent has no children, the CTA invites them to add one',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      final ex = _exercise();
      await tester.pumpWidget(_wrap(
        spy: spy,
        exerciseId: ex.id,
        exercises: [ex],
        children: const [],
      ));
      await _settle(tester);

      // Empty-children CTA copy.
      expect(find.text('Avval bola qo\'shing'), findsOneWidget);
      // The "Bolani tanlang" label only appears in the with-children path,
      // so it must NOT be on screen when the children list is empty.
      expect(find.text('Bolani tanlang'), findsNothing);

      // Tap the CTA card → routes to /children/add.
      await tester.tap(find.text('Avval bola qo\'shing'));
      await tester.pumpAndSettle();

      expect(spy.lastLocation, '/children/add');

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'with at least one child, the start CTA routes to /assessment/intro/:childId/:exerciseId',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      final ex = _exercise();
      await tester.pumpWidget(_wrap(
        spy: spy,
        exerciseId: ex.id,
        exercises: [ex],
        children: [_child(id: 'c-7', name: 'Bobur', gender: 'male')],
      ));
      await _settle(tester);

      // The selected-child preview shows the child's name once the picker
      // has populated.
      expect(find.text('Bobur'), findsOneWidget);
      expect(find.text('Bolani tanlang'), findsOneWidget);

      // Find the "Baholashni boshlash" button (PremiumButton) and tap it.
      final start = find.text('Baholashni boshlash');
      expect(start, findsOneWidget);
      await tester.ensureVisible(start);
      await tester.pump();
      await tester.tap(start);
      await tester.pumpAndSettle();

      expect(spy.lastLocation, '/assessment/intro/c-7/${ex.id}');
      expect(spy.lastParams['childId'], 'c-7');
      expect(spy.lastParams['exerciseId'], ex.id);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'unknown exercise id renders the localized "exercise not found" empty state',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        spy: spy,
        exerciseId: 'does-not-exist',
        // A different exercise is in the cache; the screen must fall
        // through to the not-found state because the id doesn't match.
        exercises: [_exercise(id: 'something-else')],
        children: const [],
      ));
      await _settle(tester);

      expect(find.text('Mashq topilmadi'), findsOneWidget);
      // Rich detail labels must NOT render in the not-found path.
      expect(find.text('Tavsif'), findsNothing);
      expect(find.text('Tovushlar'), findsNothing);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'detail body hosts the Hero badge with the exercise-specific tag '
    '— matches the source Hero in the exercises list for smooth transition',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      final ex = _exercise(id: 'ex-hero-7');
      await tester.pumpWidget(_wrap(
        spy: spy,
        exerciseId: ex.id,
        exercises: [ex],
        children: [_child()],
      ));
      await _settle(tester);

      // Hero must be present at the destination with the canonical tag
      // shape so the transition pairs up with the list-side Hero.
      final heroes = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'exercise-icon-${ex.id}',
      );
      expect(heroes, findsOneWidget);

      // Category headline appears alongside the Hero badge.
      expect(find.text('TALAFFUZ'), findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'shows the LessonPreviewCard only when the exercise ships interactive steps',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      // Same shape as the legacy fixture, plus the new structured `steps`
      // array — the widget under test must render the new lesson preview
      // card without breaking any of the existing cards above it.
      final ex = Exercise(
        id: 'ex-interactive-1',
        title: 'S tovushi darsi',
        description: "S tovushini mashq qilish darsi",
        category: 'articulation',
        ageGroup: '5-6',
        difficulty: 'medium',
        language: 'uz',
        durationMinutes: 6,
        instructions: 'Birga mashq qilamiz.',
        targetPhonemes: const ['s'],
        isActive: true,
        steps: const [
          InstructionStep(textUz: 'Hozir S tovushini mashq qilamiz'),
          DemonstrateStep(textUz: 'Tinglang va takrorlang'),
          RecordStep(targetWord: 'sut', targetPhonemes: ['s', 'u', 't']),
          FeedbackStep(encouragementUz: 'Ajoyib!'),
        ],
      );
      await tester.pumpWidget(_wrap(
        spy: spy,
        exerciseId: ex.id,
        exercises: [ex],
        children: [_child()],
      ));
      await _settle(tester);

      // The lesson preview card renders title + step-count chip.
      // "Interaktiv dars" appears twice: once as the preview card header
      // and once as the Start CTA label (we reuse the same localized
      // copy so the parent recognises the new flow).
      expect(find.text('Interaktiv dars'), findsNWidgets(2));
      expect(find.text('4 qadam'), findsOneWidget);
      // Each step kind label is visible (steps are scrolled into view by
      // the card itself, which is inside a CustomScrollView body — at
      // 800x2400 the entire stack fits without scrolling). The
      // "Yo'riqnoma" string is also used as the legacy
      // `exerciseInstructions` section header above the lesson preview,
      // so we expect it to appear twice — once for the existing card,
      // once as the lesson-step kind label.
      expect(find.text("Yo'riqnoma"), findsNWidgets(2));
      expect(find.text("Ko'rsatish"), findsOneWidget);
      expect(find.text('Yozib olish'), findsOneWidget);
      expect(find.text('Natija va maqtov'), findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'legacy exercises (no steps field) render unchanged — no lesson preview card',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      // Use the legacy fixture exactly as it ships from the helper above.
      final ex = _exercise();
      await tester.pumpWidget(_wrap(
        spy: spy,
        exerciseId: ex.id,
        exercises: [ex],
        children: [_child()],
      ));
      await _settle(tester);

      // The lesson preview card must NOT appear on legacy exercises —
      // backward compatibility guarantee from `Exercise.hasInteractiveSteps`.
      expect(find.text('Interaktiv dars'), findsNothing);

      await _disposeTree(tester);
    },
  );
}
