import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/widgets/recording_button.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('RecordingButton', () {
    testWidgets(
      'idle state shows the microphone icon, no pulse rings',
      (tester) async {
        await tester.pumpWidget(_wrap(
          RecordingButton(recording: false, onTap: () {}),
        ));
        await tester.pump();

        expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
        expect(find.byIcon(Icons.stop_rounded), findsNothing);
      },
    );

    testWidgets(
      'recording state swaps to the stop icon and renders pulse rings',
      (tester) async {
        await tester.pumpWidget(_wrap(
          RecordingButton(recording: true, onTap: () {}),
        ));
        // Pump a single frame so AnimatedBuilders inside the Stack mount.
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
        expect(find.byIcon(Icons.mic_rounded), findsNothing);

        // We render exactly 3 expanding pulse rings in the recording state
        // (see _RecordingButtonState.build). Asserting the count guards
        // against future refactors silently dropping the visual.
        final rings = tester.widgetList<AnimatedBuilder>(
          find.descendant(
            of: find.byType(RecordingButton),
            matching: find.byType(AnimatedBuilder),
          ),
        );
        expect(rings.length, 3);
      },
    );

    testWidgets(
      'tapping fires onTap exactly once',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(_wrap(
          RecordingButton(recording: false, onTap: () => taps++),
        ));
        await tester.pump();

        await tester.tap(find.byType(RecordingButton));
        await tester.pump();

        expect(taps, 1);
      },
    );

    testWidgets(
      'transitioning recording → idle stops the pulse animation',
      (tester) async {
        await tester.pumpWidget(_wrap(
          RecordingButton(recording: true, onTap: () {}),
        ));
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

        await tester.pumpWidget(_wrap(
          RecordingButton(recording: false, onTap: () {}),
        ));
        await tester.pump();

        // Once stopped, the pulse rings disappear and the mic icon comes back.
        expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
        final rings = tester.widgetList<AnimatedBuilder>(
          find.descendant(
            of: find.byType(RecordingButton),
            matching: find.byType(AnimatedBuilder),
          ),
        );
        expect(rings, isEmpty);
      },
    );
  });
}
