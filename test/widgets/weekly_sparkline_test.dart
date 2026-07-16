import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/weekly_sparkline.dart';

/// Wraps [child] in the minimal context the sparkline needs (theme +
/// localizations). Anchored to a fixed `now` so the bucketing is
/// deterministic across CI runs and timezones.
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
        width: 320,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

Assessment _assessment({
  required String id,
  required DateTime createdAt,
  String childId = 'child-1',
  String? overallRisk,
  double? score,
}) {
  return Assessment(
    id: id,
    childId: childId,
    status: 'completed',
    overallRisk: overallRisk,
    score: score,
    createdAt: createdAt,
  );
}

void main() {
  // Mid-day on a fixed reference date. The sparkline truncates createdAt
  // to its date component so the time-of-day doesn't matter for bucketing,
  // but we anchor it for clarity.
  final now = DateTime(2026, 6, 11, 9, 0);

  group('WeeklySparkline', () {
    testWidgets('renders the empty hint when there are no assessments',
        (tester) async {
      await tester.pumpWidget(
        _wrap(WeeklySparkline(assessments: const [], now: now)),
      );
      // Settle entrance staggered animation.
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Oxirgi 7 kun'), findsOneWidget);
      expect(find.text('Bu haftada baholash bo\'lmadi'), findsOneWidget);
      // 0-count plural label.
      expect(find.text('Bahosiz'), findsOneWidget);
    });

    testWidgets('counts active days within the trailing 7-day window',
        (tester) async {
      // Two assessments today, one yesterday, one 6 days ago, and one
      // 30 days ago that must be ignored (outside the window).
      final assessments = [
        _assessment(id: 'a', createdAt: now),
        _assessment(id: 'b', createdAt: now.add(const Duration(hours: 2))),
        _assessment(
          id: 'c',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        _assessment(
          id: 'd',
          createdAt: now.subtract(const Duration(days: 6)),
        ),
        _assessment(
          id: 'old',
          createdAt: now.subtract(const Duration(days: 30)),
        ),
      ];

      await tester.pumpWidget(
        _wrap(WeeklySparkline(assessments: assessments, now: now)),
      );
      await tester.pump(const Duration(milliseconds: 800));

      // 3 distinct active days inside the window — d, c, today.
      expect(find.text('3/7 kun faol'), findsOneWidget);
      // 4 in-window assessments total → "4 ta baholash" via plural.
      expect(find.text('4 ta baholash'), findsOneWidget);
      // Empty hint should NOT appear when there's data.
      expect(find.text('Bu haftada baholash bo\'lmadi'), findsNothing);
    });

    testWidgets('drops assessments older than 7 days from totals',
        (tester) async {
      final assessments = [
        _assessment(
          id: 'old1',
          createdAt: now.subtract(const Duration(days: 10)),
        ),
        _assessment(
          id: 'old2',
          createdAt: now.subtract(const Duration(days: 14)),
        ),
      ];

      await tester.pumpWidget(
        _wrap(WeeklySparkline(assessments: assessments, now: now)),
      );
      await tester.pump(const Duration(milliseconds: 800));

      // Both assessments fall outside the trailing 7-day window so the
      // chart should look identical to the empty case.
      expect(find.text('Bu haftada baholash bo\'lmadi'), findsOneWidget);
      expect(find.text('Bahosiz'), findsOneWidget);
    });

    testWidgets('localizes captions when locale=ru', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WeeklySparkline(assessments: const [], now: now),
          locale: const Locale('ru'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Последние 7 дней'), findsOneWidget);
      expect(find.text('На этой неделе ещё нет оценок'), findsOneWidget);
      expect(find.text('Без оценок'), findsOneWidget);
    });

    testWidgets('renders 7 day-letter labels regardless of activity',
        (tester) async {
      await tester.pumpWidget(
        _wrap(WeeklySparkline(assessments: const [], now: now)),
      );
      await tester.pump(const Duration(milliseconds: 800));

      // We expect exactly seven single-character day prefixes — one
      // per column. The intl-locale formatter capitalises and trims to
      // a single grapheme inside the widget.
      final letterFinder = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data != null &&
            w.data!.length == 1 &&
            w.style?.fontWeight == FontWeight.w800,
      );
      expect(letterFinder, findsNWidgets(7));
    });
  });
}
