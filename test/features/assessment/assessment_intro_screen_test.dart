import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/assessment/assessment_intro_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

/// Build a single fake Exercise for the intro screen to display.
Exercise _exercise({String id = 'e1', String title = 'R tovushi'}) => Exercise(
      id: id,
      title: title,
      description: 'Lorem',
      category: 'articulation',
      ageGroup: '4-6',
      difficulty: 'easy',
      language: 'uz',
      durationMinutes: 3,
      isActive: true,
    );

/// GoRouter with the intro screen mounted as the initial location plus a
/// stub destination route so we can assert that the countdown actually
/// pushes the next screen onto the stack.
GoRouter _stubRouter({
  required String childId,
  required String exerciseId,
}) {
  return GoRouter(
    initialLocation: '/assessment/intro/$childId/$exerciseId',
    routes: [
      GoRoute(
        path: '/assessment/intro/:childId/:exerciseId',
        builder: (_, state) => AssessmentIntroScreen(
          childId: state.pathParameters['childId']!,
          exerciseId: state.pathParameters['exerciseId']!,
        ),
      ),
      GoRoute(
        path: '/assessment/:childId/:exerciseId',
        builder: (_, state) => Scaffold(
          body: Text(
            'game-stub:${state.pathParameters['childId']}:'
            '${state.pathParameters['exerciseId']}',
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:id',
        builder: (_, __) => const Scaffold(body: Text('exercise-detail-stub')),
      ),
    ],
  );
}

Widget _wrap({
  required GoRouter router,
  required List<Exercise> exercises,
  String locale = 'uz',
}) {
  return ProviderScope(
    overrides: [
      exercisesProvider
          .overrideWith((ref) async => CachedResult<Exercise>(exercises)),
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
      locale: Locale(locale),
      routerConfig: router,
    ),
  );
}

void main() {
  // Use a realistic portrait phone viewport (iPhone 14-ish) so the layout
  // matches what real users see — the default 800×600 surface is closer to
  // a small landscape tablet and would mask portrait-only regressions.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize =
        const Size(390 * 3, 844 * 3);
    binding.platformDispatcher.views.first.devicePixelRatio = 3.0;
  });
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('AssessmentIntroScreen', () {
    testWidgets(
      'renders the exercise title, three tip cards and the Start button',
      (tester) async {
        await tester.pumpWidget(_wrap(
          router: _stubRouter(childId: 'c1', exerciseId: 'e1'),
          exercises: [_exercise(title: 'R tovushi')],
        ));
        // Resolve the FutureProvider and let entrance animations play.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Title comes from the resolved exercise.
        expect(find.text('R tovushi'), findsOneWidget);

        // All three localized tips render as separate cards.
        expect(find.text('Tinch joyda yozing'), findsOneWidget);
        expect(find.text('Aniq va sekin gapiring'), findsOneWidget);
        expect(find.text('Mikrofon yaqin bo\'lsin'), findsOneWidget);

        // The CTA is the localized "Boshladik!" label, not English.
        expect(find.text('Boshladik!'), findsOneWidget);
      },
    );

    testWidgets(
      'falls back to the localized title when the exercise is not yet loaded',
      (tester) async {
        await tester.pumpWidget(_wrap(
          router: _stubRouter(childId: 'c1', exerciseId: 'missing'),
          // Intentionally empty so the lookup misses.
          exercises: const [],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // With no matching exercise, the screen reuses the localized
        // "Baholashni boshlash" header so the user always sees real copy
        // (never an English fallback or an empty title).
        expect(find.text('Baholashni boshlash'), findsWidgets);
      },
    );

    testWidgets(
      'tapping the Start CTA hides the tips and reveals the countdown',
      (tester) async {
        await tester.pumpWidget(_wrap(
          router: _stubRouter(childId: 'c1', exerciseId: 'e1'),
          exercises: [_exercise()],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Boshladik!'));
        // Initial countdown frame.
        await tester.pump();

        // Countdown starts at 3 and the tip list is gone.
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Tinch joyda yozing'), findsNothing);
      },
    );

    testWidgets(
      'countdown ticks 3 → 2 → 1 then routes to the game screen',
      (tester) async {
        await tester.pumpWidget(_wrap(
          router: _stubRouter(childId: 'c1', exerciseId: 'e1'),
          exercises: [_exercise()],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Boshladik!'));
        await tester.pump();
        expect(find.text('3'), findsOneWidget);

        // Each Timer.periodic tick decrements by 1. Pump 1 second + a
        // small slop for the AnimatedSwitcher transition between numbers.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('2'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('1'), findsOneWidget);

        // Third tick fires context.go(...) on the destination route. We
        // pump one more second for the timer + a generous window for the
        // GoRouter rebuild and the destination's first frame.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('game-stub:c1:e1'), findsOneWidget);
      },
    );
  });
}
