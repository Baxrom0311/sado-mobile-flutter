import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/gamification.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/home_next_badge_peek.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('uz'),
    supportedLocales: L.supportedLocales,
    localizationsDelegates: const [
      L.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

void main() {
  group('HomeNextBadgePeek', () {
    testWidgets('renders nothing when goal is null', (tester) async {
      await tester.pumpWidget(_harness(
        const HomeNextBadgePeek(
          goal: null,
          label: 'Keyingi nishongacha',
          badgeTitle: 'irrelevant',
          progressText: 'irrelevant',
        ),
      ));

      // Nothing user-facing should render.
      expect(find.text('Keyingi nishongacha'), findsNothing);
      expect(find.text('irrelevant'), findsNothing);
    });

    testWidgets(
        'renders label, badge title, progress text and computed percentage',
        (tester) async {
      const goal = NextBadgeGoal(
        badgeId: 'streak_5',
        kind: NextBadgeGoalKind.streak,
        current: 3,
        target: 5,
      );

      await tester.pumpWidget(_harness(
        const HomeNextBadgePeek(
          goal: goal,
          label: 'Keyingi nishongacha',
          badgeTitle: '5 kunlik seriya',
          progressText: '3/5 kun',
        ),
      ));
      // Drain the progress-bar tween.
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Keyingi nishongacha'), findsOneWidget);
      expect(find.text('5 kunlik seriya'), findsOneWidget);
      expect(find.text('3/5 kun'), findsOneWidget);
      // 3/5 = 0.6 → 60%.
      expect(find.text('60%'), findsOneWidget);
    });

    testWidgets('uses the badge emoji for the supplied badge id',
        (tester) async {
      const goal = NextBadgeGoal(
        badgeId: 'first_step',
        kind: NextBadgeGoalKind.streak,
        current: 0,
        target: 1,
      );

      await tester.pumpWidget(_harness(
        const HomeNextBadgePeek(
          goal: goal,
          label: 'Next',
          badgeTitle: 'First step',
          progressText: '0/1',
        ),
      ));

      expect(find.text(GameBadge.firstStep.emoji), findsOneWidget);
    });

    testWidgets('shows a chevron only when an onTap handler is provided',
        (tester) async {
      const goal = NextBadgeGoal(
        badgeId: 'first_step',
        kind: NextBadgeGoalKind.streak,
        current: 0,
        target: 1,
      );

      // Without onTap → no chevron.
      await tester.pumpWidget(_harness(
        const HomeNextBadgePeek(
          goal: goal,
          label: 'Next',
          badgeTitle: 'First step',
          progressText: '0/1',
        ),
      ));
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      // With onTap → chevron appears.
      await tester.pumpWidget(_harness(
        HomeNextBadgePeek(
          goal: goal,
          label: 'Next',
          badgeTitle: 'First step',
          progressText: '0/1',
          onTap: () {},
        ),
      ));
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('invokes onTap when the card is tapped', (tester) async {
      const goal = NextBadgeGoal(
        badgeId: 'first_step',
        kind: NextBadgeGoalKind.streak,
        current: 0,
        target: 1,
      );

      var taps = 0;
      await tester.pumpWidget(_harness(
        HomeNextBadgePeek(
          goal: goal,
          label: 'Next',
          badgeTitle: 'First step',
          progressText: '0/1',
          onTap: () => taps++,
        ),
      ));

      await tester.tap(find.byType(HomeNextBadgePeek));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('clamps progress to 100% when current exceeds target',
        (tester) async {
      const goal = NextBadgeGoal(
        badgeId: 'streak_5',
        kind: NextBadgeGoalKind.streak,
        current: 12,
        target: 5,
      );

      await tester.pumpWidget(_harness(
        const HomeNextBadgePeek(
          goal: goal,
          label: 'Next',
          badgeTitle: '5-day streak',
          progressText: '12/5',
        ),
      ));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('100%'), findsOneWidget);
    });
  });
}
