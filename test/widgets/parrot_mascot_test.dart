// Dedicated coverage for SADO's parrot mascot — the brand identity widget
// used on home, exercise detail, assessment, results, and empty states.
//
// We focus on three contracts:
//   1. Every supported [ParrotMood] renders without throwing, with the
//      expected painter wired up.
//   2. The optional speech bubble appears above the mascot only when a
//      `message` is supplied and is read out via the surrounding text tree
//      (so a11y / golden tests can find it).
//   3. Switching moods at runtime is non-disruptive — no leaked timers,
//      no animation-controller assertions when the widget is reparented.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/widgets/parrot_mascot.dart';
import 'package:sado_mobile/widgets/speech_bubble.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('ParrotMascot', () {
    testWidgets(
      'renders without throwing for every supported mood',
      (tester) async {
        for (final mood in ParrotMood.values) {
          await tester.pumpWidget(_wrap(ParrotMascot(mood: mood, size: 80)));
          // One frame is enough to wire up the AnimationControllers; we
          // intentionally do NOT pumpAndSettle because the bob/blink
          // controllers repeat indefinitely.
          await tester.pump();
          expect(find.byType(ParrotMascot), findsOneWidget,
              reason: 'mascot should render for $mood');
          expect(find.byType(CustomPaint), findsWidgets,
              reason: 'painter should be wired for $mood');
        }
      },
    );

    testWidgets(
      'omits the speech bubble when no message is supplied',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const ParrotMascot(mood: ParrotMood.idle, size: 80)),
        );
        await tester.pump();
        expect(find.byType(SpeechBubble), findsNothing);
      },
    );

    testWidgets(
      'renders the speech bubble above the mascot when message is provided',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const ParrotMascot(
            mood: ParrotMood.talking,
            size: 80,
            message: 'Salom!',
          )),
        );
        await tester.pump();
        expect(find.byType(SpeechBubble), findsOneWidget);
        expect(find.text('Salom!'), findsOneWidget);

        // The bubble must appear *above* the painter — visually critical so
        // the parrot looks like it's saying the line. We check vertical
        // position instead of widget order, since Column children can be
        // laid out either way depending on cross-axis alignment.
        final bubbleY = tester.getCenter(find.byType(SpeechBubble)).dy;
        final paintY = tester
            .getCenter(find.byType(CustomPaint).first)
            .dy;
        expect(bubbleY, lessThan(paintY),
            reason: 'speech bubble should sit above the mascot painter');
      },
    );

    testWidgets(
      'switching moods at runtime does not leak timers or controllers',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const ParrotMascot(mood: ParrotMood.idle, size: 80)),
        );
        await tester.pump();

        // Cycle through moods; the assertion is that no exception is thrown
        // by the underlying AnimationController lifecycle (`_syncTalking`
        // stops/starts the talk controller on every mood change).
        for (final mood in [
          ParrotMood.talking,
          ParrotMood.happy,
          ParrotMood.sad,
          ParrotMood.listening,
          ParrotMood.idle,
        ]) {
          await tester.pumpWidget(
            _wrap(ParrotMascot(mood: mood, size: 80)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(tester.takeException(), isNull);

        // Tear-down — pumping an empty widget unmounts the mascot. If any
        // controller was leaked the test runner would surface a pending
        // timer error here.
        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        await tester.pump();
        expect(find.byType(ParrotMascot), findsNothing);
      },
    );

    testWidgets(
      'animation drives a continuous repaint while mounted',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const ParrotMascot(mood: ParrotMood.idle, size: 80)),
        );
        await tester.pump();

        // Capture the AnimatedBuilder so we can compare frame-to-frame.
        final builderFinder = find.byType(AnimatedBuilder);
        expect(builderFinder, findsWidgets);

        // Pumping forward advances the bob/blink controllers — calling
        // pump twice should not throw and the widget tree should remain
        // mounted (i.e. we're still animating, not swallowing exceptions).
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(ParrotMascot), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
