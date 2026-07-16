import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/difficulty_stars.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('uz')}) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    localizationsDelegates: const [
      L.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

/// Counts the number of *filled* star icons painted by the widget under
/// test. We rely on the icon code point because the widget mixes filled
/// and outlined stars to indicate the level.
int _filledStarCount(WidgetTester tester) {
  return tester
      .widgetList<Icon>(find.byType(Icon))
      .where((icon) => icon.icon == Icons.star_rounded)
      .length;
}

int _outlinedStarCount(WidgetTester tester) {
  return tester
      .widgetList<Icon>(find.byType(Icon))
      .where((icon) => icon.icon == Icons.star_outline_rounded)
      .length;
}

void main() {
  group('DifficultyStars', () {
    testWidgets('easy → 1 filled star + 2 outlined + localized label',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const DifficultyStars(difficulty: 'easy'),
      ));

      expect(_filledStarCount(tester), 1);
      expect(_outlinedStarCount(tester), 2);
      expect(find.text('Oson'), findsOneWidget);
    });

    testWidgets('medium → 2 filled + 1 outlined', (tester) async {
      await tester.pumpWidget(_wrap(
        const DifficultyStars(difficulty: 'medium'),
      ));

      expect(_filledStarCount(tester), 2);
      expect(_outlinedStarCount(tester), 1);
      expect(find.text('O\'rtacha'), findsOneWidget);
    });

    testWidgets('hard → 3 filled + 0 outlined', (tester) async {
      await tester.pumpWidget(_wrap(
        const DifficultyStars(difficulty: 'hard'),
      ));

      expect(_filledStarCount(tester), 3);
      expect(_outlinedStarCount(tester), 0);
      expect(find.text('Qiyin'), findsOneWidget);
    });

    testWidgets(
      'unknown token falls back to zero stars (defensive default)',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const DifficultyStars(difficulty: 'expert'),
        ));

        expect(_filledStarCount(tester), 0);
        expect(_outlinedStarCount(tester), 3);
        // The label echoes the raw token instead of throwing — better UX
        // than an empty space if the API ever ships a new bucket.
        expect(find.text('expert'), findsOneWidget);
      },
    );

    testWidgets(
      'showLabel: false hides the text but keeps the star row',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const DifficultyStars(
            difficulty: 'medium',
            showLabel: false,
          ),
        ));

        expect(_filledStarCount(tester), 2);
        expect(_outlinedStarCount(tester), 1);
        expect(find.text('O\'rtacha'), findsNothing);
      },
    );

    testWidgets(
      'renders Russian label when locale is ru',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const DifficultyStars(difficulty: 'hard'),
          locale: const Locale('ru'),
        ));

        expect(_filledStarCount(tester), 3);
        // Russian translation for "hard" is "Сложный".
        expect(find.text('Сложный'), findsOneWidget);
      },
    );

    testWidgets(
      'star color matches the AppColors.difficultyColor mapping',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const DifficultyStars(difficulty: 'easy'),
        ));

        final filled = tester
            .widgetList<Icon>(find.byType(Icon))
            .firstWhere((i) => i.icon == Icons.star_rounded);
        expect(filled.color, AppColors.difficultyColor('easy'));
      },
    );

    testWidgets(
      'wraps stars + label in a Semantics announcement that includes both',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const DifficultyStars(difficulty: 'medium'),
        ));

        // Find the explicit Semantics wrapping the star row by matching
        // the localized label we expect in the announcement.
        final semantics = tester.getSemantics(find.byType(DifficultyStars));
        expect(semantics.label, contains('Qiyinlik darajasi'));
        expect(semantics.label, contains('O\'rtacha'));
      },
    );
  });
}
