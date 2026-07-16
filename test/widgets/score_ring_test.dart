import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/widgets/score_ring.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  group('ScoreRing', () {
    testWidgets('renders the supplied child centered inside the ring',
        (tester) async {
      await tester.pumpWidget(host(
        const ScoreRing(value: 0.5, child: Text('75%')),
      ));
      // Lets the entrance tween settle before we look for the child.
      await tester.pumpAndSettle();

      expect(find.text('75%'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('uses the supplied size for both axes', (tester) async {
      await tester.pumpWidget(host(
        const ScoreRing(value: 0.4, size: 200),
      ));
      await tester.pumpAndSettle();

      final box = tester.getSize(find.byType(ScoreRing));
      expect(box.width, 200);
      expect(box.height, 200);
    });

    testWidgets('does NOT use the Material default CircularProgressIndicator',
        (tester) async {
      // The whole point of ScoreRing is that the assessment results screen
      // stops relying on Material's built-in spinner widget.
      await tester.pumpWidget(host(
        const ScoreRing(value: 0.8, child: Text('80%')),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('handles NaN, negative and >1 values without throwing',
        (tester) async {
      // The widget is given junk on purpose: TweenAnimationBuilder would
      // otherwise crash on NaN, so the clamp inside ScoreRing matters.
      for (final v in const <double>[double.nan, -1, 1.5, 0]) {
        await tester.pumpWidget(host(
          ScoreRing(value: v, child: const Text('x')),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('x'), findsOneWidget);
      }
    });
  });
}
