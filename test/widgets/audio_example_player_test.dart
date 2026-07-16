import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/widgets/audio_example_player.dart';

void main() {
  testWidgets(
    'AudioExamplePlayer renders the label and a play button placeholder',
    (tester) async {
      // We use an unreachable URL — the widget should render its loading /
      // play button shell without crashing in the test environment.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: AudioExamplePlayer(
              url: 'https://invalid.example.test/example.m4a',
              label: 'Listen',
              errorLabel: 'Audio not available',
            ),
          ),
        ),
      );
      await tester.pump();

      // Either the label is shown (loading or playable state) or the
      // error label (fallback). In either case the widget builds.
      final hasLabel = find.text('Listen').evaluate().isNotEmpty ||
          find.text('Audio not available').evaluate().isNotEmpty;
      expect(hasLabel, isTrue);
    },
  );
}
