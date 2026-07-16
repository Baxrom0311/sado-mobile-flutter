import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/daily_goal_card.dart';

void main() {
  group('isDailyGoalDone (pure logic)', () {
    test('null lastActiveDate is never done', () {
      expect(isDailyGoalDone(null), isFalse);
      expect(
        isDailyGoalDone(null, now: DateTime(2026, 6, 11)),
        isFalse,
      );
    });

    test('empty string is never done', () {
      expect(isDailyGoalDone(''), isFalse);
    });

    test('exact yyyy-MM-dd match returns true', () {
      final now = DateTime(2026, 6, 11, 14, 32, 7);
      expect(isDailyGoalDone('2026-06-11', now: now), isTrue);
    });

    test('zero-padding mismatches still match because we always pad', () {
      // The store always writes zero-padded keys, so a stored value of
      // '2026-06-11' must match a computed '2026-06-11'.
      final now = DateTime(2026, 6, 1);
      expect(isDailyGoalDone('2026-06-01', now: now), isTrue);
      // Wrong padding doesn't match — and that's fine, the store only
      // writes padded values, so this guards against accidental drift.
      expect(isDailyGoalDone('2026-6-1', now: now), isFalse);
    });

    test('yesterday does not count as done', () {
      final now = DateTime(2026, 6, 11);
      expect(isDailyGoalDone('2026-06-10', now: now), isFalse);
    });

    test('a future-dated stamp does not count as done', () {
      final now = DateTime(2026, 6, 11);
      expect(isDailyGoalDone('2026-06-12', now: now), isFalse);
    });

    test('crossing a month boundary is handled', () {
      expect(
        isDailyGoalDone('2026-05-31', now: DateTime(2026, 6, 1)),
        isFalse,
      );
      expect(
        isDailyGoalDone('2026-06-01', now: DateTime(2026, 6, 1)),
        isTrue,
      );
    });

    test('crossing a year boundary is handled', () {
      expect(
        isDailyGoalDone('2025-12-31', now: DateTime(2026, 1, 1)),
        isFalse,
      );
      expect(
        isDailyGoalDone('2026-01-01', now: DateTime(2026, 1, 1)),
        isTrue,
      );
    });
  });

  group('DailyGoalCard widget', () {
    Widget host(Widget child, {Locale locale = const Locale('uz')}) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L.supportedLocales,
        home: Scaffold(body: child),
      );
    }

    testWidgets(
      'pending state renders the localized title, subtitle and CTA',
      (tester) async {
        await tester.pumpWidget(host(
          DailyGoalCard(isDone: false, onStart: () {}),
        ));
        await tester.pump(const Duration(milliseconds: 320));

        expect(find.text('Bugungi maqsad'), findsOneWidget);
        expect(find.text('Bugun bitta mashqni bajaring'), findsOneWidget);
        expect(find.text('Boshlash'), findsOneWidget);
        // The icon for the pending state.
        expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'pending card invokes onStart when tapped',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(host(
          DailyGoalCard(isDone: false, onStart: () => taps++),
        ));
        await tester.pump(const Duration(milliseconds: 320));

        // Tap the headline label, which sits inside the GestureDetector
        // wired up on the PremiumCard. This is the user-visible surface.
        await tester.tap(find.text('Bugungi maqsad'));
        await tester.pump();

        expect(taps, 1);
      },
    );

    testWidgets(
      'done state shows the celebration title, subtitle and "Bajarildi" badge',
      (tester) async {
        await tester.pumpWidget(host(const DailyGoalCard(isDone: true)));
        await tester.pump(const Duration(milliseconds: 320));

        expect(
          find.text('Bugungi maqsad bajarildi! 🎉'),
          findsOneWidget,
        );
        expect(
          find.text('Streakni davom ettirish uchun ertaga ham keling'),
          findsOneWidget,
        );
        expect(find.text('Bajarildi'), findsOneWidget);
        // The done state uses a check icon and never the flag.
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.byIcon(Icons.flag_rounded), findsNothing);
      },
    );

    testWidgets(
      'done state does NOT render the Start CTA',
      (tester) async {
        await tester.pumpWidget(host(
          DailyGoalCard(isDone: true, onStart: () {}),
        ));
        await tester.pump(const Duration(milliseconds: 320));

        expect(find.text('Boshlash'), findsNothing);
      },
    );

    testWidgets(
      'renders Russian copy when locale=ru',
      (tester) async {
        await tester.pumpWidget(host(
          DailyGoalCard(isDone: false, onStart: () {}),
          locale: const Locale('ru'),
        ));
        await tester.pump(const Duration(milliseconds: 320));

        expect(find.text('Цель на сегодня'), findsOneWidget);
        expect(find.text('Выполните одно упражнение'), findsOneWidget);
        expect(find.text('Начать'), findsOneWidget);
      },
    );

    testWidgets(
      'announces a meaningful Semantics label tied to its state',
      (tester) async {
        // Pending — semantics label should mention the pending headline.
        await tester.pumpWidget(host(
          DailyGoalCard(isDone: false, onStart: () {}),
        ));
        await tester.pump(const Duration(milliseconds: 320));

        // The Semantics node lives at the top of the widget; its label
        // is composed from `dailyGoalSemantics(state)`.
        final pendingNode = tester
            .getSemantics(find.byKey(const ValueKey('home.dailyGoalCard')));
        expect(pendingNode.label, contains('Bugungi maqsad'));

        // Done — semantics label should mention "Bajarildi".
        await tester.pumpWidget(host(const DailyGoalCard(isDone: true)));
        await tester.pump(const Duration(milliseconds: 320));

        final doneNode = tester
            .getSemantics(find.byKey(const ValueKey('home.dailyGoalCard')));
        expect(doneNode.label, contains('Bajarildi'));
      },
    );
  });
}
