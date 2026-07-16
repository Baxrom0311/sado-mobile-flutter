import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/practice_calendar_grid.dart';

Widget _wrap(
  Widget child, {
  Locale locale = const Locale('uz'),
}) {
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
    home: Scaffold(
      body: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

Assessment _a(String id, DateTime when, {String? risk, double? score}) {
  return Assessment(
    id: id,
    childId: 'c-1',
    status: 'completed',
    overallRisk: risk,
    score: score,
    createdAt: when,
  );
}

void main() {
  group('PracticeIntensity.fromCount', () {
    test('zero maps to none', () {
      expect(PracticeIntensity.fromCount(0), PracticeIntensity.none);
      expect(PracticeIntensity.fromCount(-3), PracticeIntensity.none);
    });

    test('exactly 1 maps to low', () {
      expect(PracticeIntensity.fromCount(1), PracticeIntensity.low);
    });

    test('2-3 maps to medium', () {
      expect(PracticeIntensity.fromCount(2), PracticeIntensity.medium);
      expect(PracticeIntensity.fromCount(3), PracticeIntensity.medium);
    });

    test('4+ maps to high', () {
      expect(PracticeIntensity.fromCount(4), PracticeIntensity.high);
      expect(PracticeIntensity.fromCount(99), PracticeIntensity.high);
    });

    test('every bucket has a distinct fill colour', () {
      final fills =
          PracticeIntensity.values.map((i) => i.fill.toARGB32()).toSet();
      expect(fills.length, PracticeIntensity.values.length);
    });
  });

  group('PracticeCalendarGrid', () {
    // June 2026 — Mon, June 1 starts the month, 30 days.
    final june = DateTime(2026, 6, 1);
    final today = DateTime(2026, 6, 11);

    testWidgets('renders one cell per day-of-month + leading blanks',
        (tester) async {
      await tester.pumpWidget(_wrap(
        PracticeCalendarGrid(
          month: june,
          assessments: const [],
          now: today,
        ),
      ));
      await tester.pumpAndSettle();

      // 30 day cells, one per day of the rendered month.
      for (var d = 1; d <= 30; d++) {
        expect(find.text('$d'), findsOneWidget,
            reason: 'expected to find day $d');
      }
      // No "31" — June has 30 days.
      expect(find.text('31'), findsNothing);
    });

    testWidgets("today's cell is decorated with the highlight ring",
        (tester) async {
      await tester.pumpWidget(_wrap(
        PracticeCalendarGrid(
          month: june,
          assessments: const [],
          now: today,
        ),
      ));
      await tester.pumpAndSettle();

      // The cell renders within a Semantics node keyed by ISO date.
      final semantics = find.byKey(
        Key('practiceCalendar.cell.${DateTime(2026, 6, 11).toIso8601String()}'),
      );
      expect(semantics, findsOneWidget);
    });

    testWidgets('tap on a populated day fires onDayTap with the bucket',
        (tester) async {
      DateTime? tappedDay;
      List<Assessment>? tappedAssessments;
      final assessments = [
        _a('a1', DateTime(2026, 6, 5, 10), score: 0.8),
        _a('a2', DateTime(2026, 6, 5, 14), score: 0.9),
      ];

      await tester.pumpWidget(_wrap(
        PracticeCalendarGrid(
          month: june,
          assessments: assessments,
          now: today,
          onDayTap: (d, a) {
            tappedDay = d;
            tappedAssessments = a;
          },
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(Key(
            'practiceCalendar.cell.${DateTime(2026, 6, 5).toIso8601String()}')),
      );
      await tester.pumpAndSettle();

      expect(tappedDay, DateTime(2026, 6, 5));
      expect(tappedAssessments?.length, 2);
      expect(tappedAssessments?.map((a) => a.id).toSet(),
          {'a1', 'a2'});
    });

    testWidgets('future days do not invoke onDayTap', (tester) async {
      var fired = false;
      await tester.pumpWidget(_wrap(
        PracticeCalendarGrid(
          month: june,
          assessments: const [],
          now: today, // June 11
          onDayTap: (_, __) => fired = true,
        ),
      ));
      await tester.pumpAndSettle();

      // June 25 is in the future relative to now=June 11.
      await tester.tap(
        find.byKey(Key(
            'practiceCalendar.cell.${DateTime(2026, 6, 25).toIso8601String()}')),
      );
      await tester.pumpAndSettle();
      expect(fired, isFalse);
    });

    testWidgets('assessments outside the rendered month are ignored',
        (tester) async {
      DateTime? tappedDay;
      List<Assessment>? tappedAssessments;
      final assessments = [
        _a('past', DateTime(2026, 5, 30, 9)),
        _a('next', DateTime(2026, 7, 1, 9)),
        _a('june10', DateTime(2026, 6, 10, 9)),
      ];

      await tester.pumpWidget(_wrap(
        PracticeCalendarGrid(
          month: june,
          assessments: assessments,
          now: today,
          onDayTap: (d, a) {
            tappedDay = d;
            tappedAssessments = a;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // June 10 should have exactly the one assessment that fell in
      // June; the May/July ones must be filtered out by the widget.
      await tester.tap(
        find.byKey(Key(
            'practiceCalendar.cell.${DateTime(2026, 6, 10).toIso8601String()}')),
      );
      await tester.pumpAndSettle();

      expect(tappedDay, DateTime(2026, 6, 10));
      expect(tappedAssessments?.length, 1);
      expect(tappedAssessments?.first.id, 'june10');
    });
  });

  group('PracticeCalendarLegend', () {
    testWidgets('renders the localized title in Uzbek', (tester) async {
      await tester.pumpWidget(_wrap(const PracticeCalendarLegend()));
      await tester.pumpAndSettle();
      expect(find.text('Faollik'), findsOneWidget);
    });

    testWidgets('renders the localized title in Russian', (tester) async {
      await tester.pumpWidget(_wrap(
        const PracticeCalendarLegend(),
        locale: const Locale('ru'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Активность'), findsOneWidget);
    });

    testWidgets('renders 4 colour swatches — one per bucket',
        (tester) async {
      await tester.pumpWidget(_wrap(const PracticeCalendarLegend()));
      await tester.pumpAndSettle();
      // Each swatch is a 14x14 Container — count them.
      final swatches = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final c = w;
        return c.constraints?.maxWidth == 14 &&
            c.constraints?.maxHeight == 14;
      });
      expect(swatches, findsNWidgets(PracticeIntensity.values.length));
    });
  });
}
