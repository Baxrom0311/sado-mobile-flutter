import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/widgets/streak_chip.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('StreakChip', () {
    testWidgets('renders day count and the supplied label', (tester) async {
      await tester.pumpWidget(
        _wrap(const StreakChip(days: 7, label: 'kun')),
      );
      // Settle the pulse animation so we land on a stable frame.
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('7 kun'), findsOneWidget);
      // Active state renders the fire emoji.
      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('zero streak uses the dormant sprout emoji', (tester) async {
      await tester.pumpWidget(
        _wrap(const StreakChip(days: 0, label: 'kun')),
      );
      await tester.pump();

      expect(find.text('0 kun'), findsOneWidget);
      // No fire when streak is dormant — it should fall back to the seedling.
      expect(find.text('🌱'), findsOneWidget);
      expect(find.text('🔥'), findsNothing);
    });

    testWidgets(
      'short streaks (< 3) skip the pulse animation',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const StreakChip(days: 2, label: 'kun')),
        );
        await tester.pump();

        // Capture the transform scale once before the animation could tick.
        // For days < 3 the controller never repeats, so a second pump 1.4s
        // later should still report scale == 1.0.
        Transform first = tester
            .widgetList<Transform>(find.byType(Transform))
            .first;
        final firstScale = first.transform.getMaxScaleOnAxis();

        await tester.pump(const Duration(milliseconds: 1400));
        first = tester.widgetList<Transform>(find.byType(Transform)).first;
        final secondScale = first.transform.getMaxScaleOnAxis();

        expect(firstScale, closeTo(secondScale, 0.0001),
            reason: 'days < 3 must not trigger the pulsing animation');
      },
    );

    testWidgets(
      'crossing the 3-day threshold via didUpdateWidget kicks the pulse on',
      (tester) async {
        // Start dormant…
        await tester.pumpWidget(
          _wrap(const StreakChip(days: 1, label: 'kun')),
        );
        await tester.pump();
        Transform first = tester
            .widgetList<Transform>(find.byType(Transform))
            .first;
        final dormantScale = first.transform.getMaxScaleOnAxis();
        expect(dormantScale, closeTo(1.0, 0.0001));

        // …and rebuild with a streak that should pulse.
        await tester.pumpWidget(
          _wrap(const StreakChip(days: 5, label: 'kun')),
        );
        // Advance halfway through the pulse cycle so the transform value
        // diverges from 1.0.
        await tester.pump(const Duration(milliseconds: 700));
        first = tester.widgetList<Transform>(find.byType(Transform)).first;
        final pulsingScale = first.transform.getMaxScaleOnAxis();
        // Allow either direction since the controller reverses.
        expect(pulsingScale, greaterThanOrEqualTo(1.0));
        expect(pulsingScale, lessThanOrEqualTo(1.07));
      },
    );
  });
}
