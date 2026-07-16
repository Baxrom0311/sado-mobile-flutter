import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/daily_tip_card.dart';
import 'package:sado_mobile/widgets/parrot_mascot.dart';

void main() {
  // Pump-helper: hosts the card inside a localised MaterialApp so the
  // ARB lookups resolve. Defaults to a date that maps to the first tip
  // (January 1 → day-of-year 0 → index 0).
  //
  // We deliberately avoid `pumpAndSettle` everywhere because the parrot
  // mascot ships continuous bob / blink animations — they never settle.
  // A single [pump] is enough to wire the localisation delegates and
  // place the static layout, which is all we exercise here.
  Widget host({
    Locale locale = const Locale('uz'),
    bool initiallyExpanded = false,
    DateTime? now,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: DailyTipCard(
            now: now ?? DateTime(2026, 1, 1),
            initiallyExpanded: initiallyExpanded,
          ),
        ),
      ),
    );
  }

  testWidgets('renders the tip-of-the-day chrome label in Uzbek',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    // Uzbek chrome label.
    expect(find.text('BUGUNGI MASLAHAT'), findsOneWidget);
    // The light-bulb glyph that precedes the label.
    expect(find.text('💡'), findsOneWidget);
  });

  testWidgets('renders the tip-of-the-day chrome label in Russian',
      (tester) async {
    await tester.pumpWidget(host(locale: const Locale('ru')));
    await tester.pump();

    expect(find.text('СОВЕТ ДНЯ'), findsOneWidget);
  });

  testWidgets('shows the parrot mascot in the leading slot',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.byType(ParrotMascot), findsOneWidget);
  });

  testWidgets('shows the localised title for the rotating tip',
      (tester) async {
    // Jan 1 → index 0 → helpTip1Title in Uzbek.
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.text('Tinch muhitni tanlang'), findsOneWidget);
  });

  testWidgets('rotates the tip across consecutive days', (tester) async {
    // Index 0 first.
    await tester.pumpWidget(host(now: DateTime(2026, 1, 1)));
    await tester.pump();
    expect(find.text('Tinch muhitni tanlang'), findsOneWidget);

    // Index 1 the next day.
    await tester.pumpWidget(host(now: DateTime(2026, 1, 2)));
    await tester.pump();
    expect(find.text('Natijadan ko\'ra harakatni maqtang'), findsOneWidget);

    // Index 2 on day 3.
    await tester.pumpWidget(host(now: DateTime(2026, 1, 3)));
    await tester.pump();
    expect(find.text('Birga aytib bering'), findsOneWidget);
  });

  testWidgets('hides the body until the user taps the card',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    // Body copy is not visible in the collapsed state.
    expect(
      find.byKey(const ValueKey('home.dailyTipCard.body')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('home.dailyTipCard')));
    // Drive the AnimatedSize / AnimatedRotation tween to completion
    // without waiting on the parrot's repeating controllers.
    await tester.pump(const Duration(milliseconds: 250));

    // Now the body is rendered with the localised tip body.
    expect(
      find.byKey(const ValueKey('home.dailyTipCard.body')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Televizor va boshqa shovqinlarni'),
      findsOneWidget,
    );
  });

  testWidgets('initiallyExpanded=true skips the user tap', (tester) async {
    await tester.pumpWidget(host(initiallyExpanded: true));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('home.dailyTipCard.body')),
      findsOneWidget,
    );
  });

  testWidgets('tapping a second time collapses the card again',
      (tester) async {
    await tester.pumpWidget(host(initiallyExpanded: true));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('home.dailyTipCard.body')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('home.dailyTipCard')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('home.dailyTipCard.body')),
      findsNothing,
    );
  });

  testWidgets('localises both title and body when locale = ru',
      (tester) async {
    await tester.pumpWidget(host(
      locale: const Locale('ru'),
      initiallyExpanded: true,
    ));
    await tester.pump();

    // Russian title + Russian body should be visible.
    expect(find.text('Создайте тишину'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home.dailyTipCard.body')),
      findsOneWidget,
    );
  });
}
