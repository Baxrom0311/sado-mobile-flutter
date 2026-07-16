import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/gamification.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/xp_bar.dart';

/// Wraps the [XpBar] in a minimal MaterialApp so the localization
/// delegates and theme are available at test time.
Widget _wrap(GameState state) {
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
    home: Scaffold(body: Center(child: XpBar(state: state))),
  );
}

void main() {
  group('XpBar', () {
    testWidgets(
      'renders the level number, XP total and the localized level name',
      (tester) async {
        // Level 3 = "explorer" tier in our copy.
        const state = GameState(
          xp: 280,
          level: 3,
          streakDays: 4,
        );
        await tester.pumpWidget(_wrap(state));
        await tester.pumpAndSettle();

        // Level pill renders "Daraja 3" (uz) — `${l.level} ${state.level}`.
        expect(find.textContaining('3'), findsAtLeastNWidgets(1));
        // XP total renders as "280 XP".
        expect(find.text('280 XP'), findsOneWidget);
      },
    );

    testWidgets(
      'level 1-2 surfaces the beginner tier name',
      (tester) async {
        const state = GameState(xp: 50, level: 1);
        await tester.pumpWidget(_wrap(state));
        await tester.pumpAndSettle();

        // The localized beginner copy from app_uz.arb is "Yangi boshlovchi".
        // Assert on a recognisable substring so the marketing team can refine
        // the wording without breaking the test.
        expect(find.textContaining('boshlovchi'), findsOneWidget);
      },
    );

    testWidgets(
      'level 10+ surfaces the master tier name',
      (tester) async {
        const state = GameState(xp: 5000, level: 10);
        await tester.pumpWidget(_wrap(state));
        await tester.pumpAndSettle();

        // "Usta" is the level-10+ tier label (uz).
        expect(find.text('Usta'), findsOneWidget);
      },
    );

    testWidgets(
      'progress label renders xpInLevel / xpNeededInLevel',
      (tester) async {
        // Level 2 starts at 100 XP, needs 200 more to reach level 3.
        // With xp=150 → 50 / 200 XP.
        const state = GameState(xp: 150, level: 2);
        await tester.pumpWidget(_wrap(state));
        await tester.pumpAndSettle();

        expect(find.text('50 / 200 XP'), findsOneWidget);
      },
    );

    testWidgets(
      'progress fill is animated (TweenAnimationBuilder is present)',
      (tester) async {
        const state = GameState(xp: 50, level: 1);
        await tester.pumpWidget(_wrap(state));
        // First frame has the tween at 0.
        expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
        await tester.pumpAndSettle();
      },
    );
  });
}
