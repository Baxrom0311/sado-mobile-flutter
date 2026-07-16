import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/widgets/animated_counter.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AnimatedCounter', () {
    testWidgets('starts at `from` and tweens up to `value`', (tester) async {
      await tester.pumpWidget(
        _wrap(const AnimatedCounter(
          value: 100,
          duration: Duration(milliseconds: 400),
        )),
      );

      // First frame is the start of the tween → value rounds to 0.
      await tester.pump();
      expect(find.text('0'), findsOneWidget);

      // Halfway through the animation we should be roughly mid-way. We
      // don't assert an exact number (curve dependent) — only that we are
      // strictly between the endpoints.
      await tester.pump(const Duration(milliseconds: 200));
      final mid = (tester.widget<Text>(find.byType(Text)).data ?? '0');
      final midValue = int.parse(mid);
      expect(midValue > 0 && midValue < 100, isTrue,
          reason: 'expected midpoint between 0 and 100, got $midValue');

      // After the duration the final value is shown.
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('appends prefix and suffix to the displayed integer',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const AnimatedCounter(
          value: 42,
          prefix: '+',
          suffix: ' XP',
          duration: Duration(milliseconds: 200),
        )),
      );
      // Settle the tween.
      await tester.pumpAndSettle();
      expect(find.text('+42 XP'), findsOneWidget);
    });

    testWidgets('value updates re-tween from the previous value',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const AnimatedCounter(
          value: 10,
          duration: Duration(milliseconds: 200),
        )),
      );
      await tester.pumpAndSettle();
      expect(find.text('10'), findsOneWidget);

      // Update to a new value: the widget should re-build and tween from
      // its previous end (10) up to the new target (50).
      await tester.pumpWidget(
        _wrap(const AnimatedCounter(
          value: 50,
          from: 10,
          duration: Duration(milliseconds: 200),
        )),
      );
      await tester.pump();
      // First frame after re-tween — should still be at the old end.
      expect(find.text('10'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('rounds fractional values to the nearest integer',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const AnimatedCounter(
          value: 12.7,
          duration: Duration(milliseconds: 100),
        )),
      );
      await tester.pumpAndSettle();
      expect(find.text('13'), findsOneWidget);
    });
  });
}
