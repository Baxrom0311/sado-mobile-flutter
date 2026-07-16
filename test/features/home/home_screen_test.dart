import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:sado_mobile/core/gamification.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/home/home_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

User _user() => User(
      id: 'u1',
      email: 'parent@sado.uz',
      fullName: 'Aziz Karimov',
      role: 'parent',
      language: 'uz',
      isActive: true,
      isVerified: true,
      createdAt: DateTime.utc(2024, 1, 1),
    );

Child _child(String id, String name, {String gender = 'male'}) => Child(
      id: id,
      name: name,
      birthDate: DateTime.utc(2019, 5, 1),
      gender: gender,
      parentId: 'u1',
      createdAt: DateTime.utc(2024, 1, 1),
    );

Exercise _exercise(String id, String title, {String category = 'articulation'}) =>
    Exercise(
      id: id,
      title: title,
      description: 'desc',
      category: category,
      ageGroup: '5-6',
      difficulty: 'easy',
      language: 'uz',
      durationMinutes: 5,
      isActive: true,
    );

Assessment _assessment(
  String id, {
  String risk = 'green',
  double? score = 0.9,
  required DateTime createdAt,
}) =>
    Assessment(
      id: id,
      childId: 'c1',
      exerciseId: 'e1',
      status: 'completed',
      overallRisk: risk,
      score: score,
      createdAt: createdAt,
    );

/// Authenticated state with a known user — keeps the greeting predictable.
class _StaticAuthNotifier extends AuthNotifier {
  _StaticAuthNotifier(super.api, super.ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: _user(),
    );
  }

  @override
  // ignore: must_call_super
  Future<void> login(String email, String password) async {}
}

/// In-memory game notifier so the home screen can show xp/streak/level
/// without touching Hive.
class _StaticGameNotifier extends GameNotifier {
  _StaticGameNotifier(GameState initial) {
    state = initial;
  }

  @override
  Future<List<String>> markActiveToday() async => const [];
}

GoRouter _stubRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/exercises',
        builder: (_, __) => const Scaffold(body: Text('exercises-stub')),
      ),
      GoRoute(
        path: '/children/add',
        builder: (_, __) => const Scaffold(body: Text('add-child-stub')),
      ),
      GoRoute(
        path: '/children/:id',
        builder: (_, state) =>
            Scaffold(body: Text('child-${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/progress',
        builder: (_, __) => const Scaffold(body: Text('progress-stub')),
      ),
      GoRoute(
        path: '/assessment/results/:id',
        builder: (_, state) =>
            Scaffold(body: Text('result-${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const Scaffold(body: Text('notifications-stub')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('settings-stub')),
      ),
      GoRoute(
        path: '/badges',
        builder: (_, __) => const Scaffold(body: Text('badges-stub')),
      ),
    ],
  );
}

Widget _wrap({
  required List<Child> children,
  required List<Exercise> exercises,
  required List<Assessment> assessments,
  GameState game = const GameState(xp: 60, level: 1, streakDays: 3),
  bool childrenFromCache = false,
  bool exercisesFromCache = false,
  bool assessmentsFromCache = false,
}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(
        (ref) => _StaticAuthNotifier(ref.watch(authApiProvider), ref),
      ),
      gameProvider.overrideWith((ref) => _StaticGameNotifier(game)),
      childrenProvider.overrideWith(
        (ref) async =>
            CachedResult<Child>(children, fromCache: childrenFromCache),
      ),
      exercisesProvider.overrideWith(
        (ref) async => CachedResult<Exercise>(
          exercises,
          fromCache: exercisesFromCache,
        ),
      ),
      assessmentsProvider.overrideWith(
        (ref, _) async => CachedResult<Assessment>(
          assessments,
          fromCache: assessmentsFromCache,
        ),
      ),
      // Pending uploads queue uses Hive — short-circuit it with a static
      // stream so the home screen's status pill doesn't crash in tests.
      pendingUploadsCountProvider.overrideWith((ref) => Stream.value(0)),
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
  // GameNotifier eagerly opens a Hive box on construction. Initialise Hive
  // against a temp directory so the in-memory fake we install via
  // overrideWith doesn't crash on its parent's _load() side-effect.
  late Directory hiveDir;
  setUpAll(() {
    hiveDir = Directory.systemTemp.createTempSync('sado_home_test_');
    Hive.init(hiveDir.path);
  });
  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  group('HomeScreen', () {
    testWidgets('renders quick actions, motivational bubble, and greeting',
        (tester) async {
      // Force a tall viewport so the entire feed can be rendered without
      // scrolling triggering ballistic animations that pollute teardown.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(
        children: [_child('c1', 'Bobur')],
        exercises: [_exercise('e1', 'R tovushi')],
        assessments: [],
      ));

      // Let Riverpod resolve the FutureProviders + drain the staggered
      // WeeklySparkline bar animations (last bar settles at ~960ms).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      // Greeting uses the localized welcome + first name.
      expect(find.textContaining('Salom'), findsWidgets);
      expect(find.textContaining('Aziz'), findsOneWidget);

      // Quick actions: Start exercise card always visible. With at least
      // one child, the second card is the assessment card.
      expect(find.text('Mashqni boshlash'), findsWidgets);
      expect(find.text('Bolani tekshirish'), findsOneWidget);

      // The motivational speech bubble lives at the bottom of the feed.
      // Scroll the page so the bubble is built and laid out.
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -2000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.byKey(const ValueKey('home.motivation.bubble')),
          findsOneWidget);
    });

    testWidgets('without children, second quick action invites adding a child',
        (tester) async {
      // Tall viewport so the QuickActions row is built — the home feed
      // is a ListView, so anything below the fold is not laid out at the
      // default 800×600 widget-test size.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(
        children: const [],
        exercises: [_exercise('e1', 'R tovushi')],
        assessments: [],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      // The "Add child" quick action replaces the assessment shortcut.
      expect(
        find.byKey(const ValueKey('quick.addChild')),
        findsOneWidget,
      );
      expect(find.text('Bola qo\'shish'), findsWidgets);
      expect(find.text('Bolani tekshirish'), findsNothing);
    });

    testWidgets('shows the most recent assessment in the recent list',
        (tester) async {
      // Tall viewport so ballistic scroll physics don't pile pending
      // timers onto teardown after the home gained the WeeklySparkline.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final older = _assessment('a-old',
          risk: 'yellow',
          score: 0.5,
          createdAt: DateTime.utc(2025, 1, 1));
      final newer = _assessment('a-new',
          risk: 'green',
          score: 0.92,
          createdAt: DateTime.utc(2025, 6, 1));

      await tester.pumpWidget(_wrap(
        children: [_child('c1', 'Bobur')],
        exercises: [_exercise('e1', 'R tovushi')],
        // Provide them in chronological order; the screen must sort newest-first.
        assessments: [older, newer],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      // Drag the list up so the recent-assessments section enters the viewport.
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -1700));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Newer assessment's score is rendered as a percentage (0.92 → 92%).
      expect(find.text('92%'), findsOneWidget);
    });

    testWidgets('with no assessments, shows an empty-state CTA',
        (tester) async {
      // Tall viewport so ballistic scroll physics don't pile pending
      // timers onto teardown after the home gained the WeeklySparkline.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(
        children: [_child('c1', 'Bobur')],
        exercises: [_exercise('e1', 'R tovushi')],
        assessments: const [],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -1700));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Hali baholash yo\'q'), findsOneWidget);
    });

    testWidgets(
      'shows the offline-cached banner when ANY home provider is from cache',
      (tester) async {
        // Children fresh, but exercises came from cache → banner expected.
        await tester.pumpWidget(_wrap(
          children: [_child('c1', 'Bobur')],
          exercises: [_exercise('e1', 'R tovushi')],
          assessments: const [],
          exercisesFromCache: true,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.text('Oflayn rejim — keshlangan ma\'lumot'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'does NOT show the offline-cached banner when every provider is fresh',
      (tester) async {
        await tester.pumpWidget(_wrap(
          children: [_child('c1', 'Bobur')],
          exercises: [_exercise('e1', 'R tovushi')],
          assessments: const [],
          // All defaults: fromCache = false.
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.text('Oflayn rejim — keshlangan ma\'lumot'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'today\'s exercises section is filtered to the youngest child\'s age '
      'bucket and shows a personalised subtitle',
      (tester) async {
        // Two children: a 5-year-old and a 3-year-old. The youngest
        // (3yo "Diyor") wins, so we expect the home to show only "3-4"
        // exercises and surface "3-4 yosh • Diyor uchun" as the subtitle.
        final now = DateTime.now();
        final fiveYoBirth = DateTime.utc(now.year - 5, 6, 1);
        final threeYoBirth = DateTime.utc(now.year - 3, 6, 1);

        Child child(String id, String name, DateTime birth,
                {String gender = 'male'}) =>
            Child(
              id: id,
              name: name,
              birthDate: birth,
              gender: gender,
              parentId: 'u1',
              createdAt: DateTime.utc(2024, 1, 1),
            );

        Exercise ex(String id, String title, String bucket) => Exercise(
              id: id,
              title: title,
              description: 'desc',
              category: 'articulation',
              ageGroup: bucket,
              difficulty: 'easy',
              language: 'uz',
              durationMinutes: 5,
              isActive: true,
            );

        await tester.pumpWidget(_wrap(
          children: [
            child('c1', 'Bobur', fiveYoBirth),
            child('c2', 'Diyor', threeYoBirth),
          ],
          exercises: [
            ex('e1', 'Mashq besh-olti', '5-6'),
            ex('e2', 'Mashq uch-tort', '3-4'),
            ex('e3', 'Yana uch-tort', '3-4'),
          ],
          assessments: const [],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Drag to ensure the section is laid out. The drag is wide
        // enough to clear the home dashboard's growing roster of cards
        // (XP bar, daily goal, daily tip, weekly sparkline, …) and bring
        // the personalised recommendations section into the viewport.
        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -900));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The recommendation subtitle is rendered.
        expect(find.text('3-4 yosh • Diyor uchun'), findsOneWidget);
        // 3-4 exercises are shown; the 5-6 one is filtered out.
        expect(find.text('Mashq uch-tort'), findsOneWidget);
        expect(find.text('Yana uch-tort'), findsOneWidget);
        expect(find.text('Mashq besh-olti'), findsNothing);
      },
    );

    testWidgets(
      'when there are NO exercises in the recommended bucket, the home '
      'falls back to the unfiltered list so the section never feels broken',
      (tester) async {
        final now = DateTime.now();
        final threeYoBirth = DateTime.utc(now.year - 3, 6, 1);

        Child child(String id, String name) => Child(
              id: id,
              name: name,
              birthDate: threeYoBirth,
              gender: 'male',
              parentId: 'u1',
              createdAt: DateTime.utc(2024, 1, 1),
            );

        Exercise ex(String id, String title, String bucket) => Exercise(
              id: id,
              title: title,
              description: 'desc',
              category: 'articulation',
              ageGroup: bucket,
              difficulty: 'easy',
              language: 'uz',
              durationMinutes: 5,
              isActive: true,
            );

        await tester.pumpWidget(_wrap(
          children: [child('c1', 'Diyor')],
          exercises: [
            // Nothing matches the 3-4 bucket; we should still see them.
            ex('e1', 'Faqat besh-olti', '5-6'),
            ex('e2', 'Yana besh-olti', '5-6'),
          ],
          assessments: const [],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -900));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Both exercises render even though neither matches the bucket.
        expect(find.text('Faqat besh-olti'), findsOneWidget);
        expect(find.text('Yana besh-olti'), findsOneWidget);
      },
    );

    testWidgets(
      'renders the WeeklySparkline activity card above the quick actions',
      (tester) async {
        // Tall viewport so the sparkline lays out without scroll-physics
        // ballistics polluting teardown.
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        await tester.pumpWidget(_wrap(
          children: [_child('c1', 'Bobur')],
          exercises: [_exercise('e1', 'R tovushi')],
          assessments: [
            _assessment('a1',
                risk: 'green', score: 0.9, createdAt: today),
            _assessment('a2',
                risk: 'green', score: 0.8, createdAt: yesterday),
          ],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));

        // The sparkline header copy ("Oxirgi 7 kun") is the most stable
        // assertion — it is rendered by the WeeklySparkline regardless of
        // data — and confirms the card landed on the home dashboard.
        expect(find.text('Oxirgi 7 kun'), findsOneWidget);
      },
    );

    testWidgets(
      'surfaces the next-badge peek between the XP bar and daily goal '
      'card whenever there is at least one locked badge',
      (tester) async {
        // Tall viewport so the peek + daily goal card both lay out.
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Default game state has no unlocked badges → first_step (1 step
        // away from a streak of 1) wins the goal compute, so its localised
        // title surfaces on the home.
        await tester.pumpWidget(_wrap(
          children: [_child('c1', 'Bobur')],
          exercises: [_exercise('e1', 'R tovushi')],
          assessments: const [],
          game: const GameState(xp: 0, level: 1, streakDays: 0),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));

        // Peek heading is shown.
        expect(find.text('Keyingi nishongacha'), findsOneWidget);
        // First-step badge title is the closest goal.
        expect(find.text('Birinchi qadam'), findsOneWidget);
      },
    );

    testWidgets(
      'hides the next-badge peek when every built-in badge is unlocked',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // All known badge ids unlocked → compute() returns null → the
        // home should NOT render a peek tile (the achievements screen
        // owns the "all unlocked" celebration instead).
        await tester.pumpWidget(_wrap(
          children: [_child('c1', 'Bobur')],
          exercises: [_exercise('e1', 'R tovushi')],
          assessments: const [],
          game: const GameState(
            xp: 9999,
            level: 12,
            streakDays: 30,
            badges: [
              'first_step',
              'streak_5',
              'assess_10',
              'level_5',
              'level_10',
              'perfect',
            ],
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Keyingi nishongacha'), findsNothing);
      },
    );
  });
}
