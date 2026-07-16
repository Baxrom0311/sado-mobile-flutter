import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/services/audio_recorder_service.dart';
import 'package:sado_mobile/widgets/loaders.dart';
import 'package:sado_mobile/widgets/waveform_visualizer.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('Loaders', () {
    testWidgets('MascotLoader renders message and disposes cleanly',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const MascotLoader(message: 'Yuklanmoqda...')),
      );
      await tester.pump();
      expect(find.byType(MascotLoader), findsOneWidget);
      expect(find.text('Yuklanmoqda...'), findsOneWidget);
      // Pump enough time to cycle the animation, then unmount.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    });

    testWidgets('BrandedSpinner paints without crashing', (tester) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(
          width: 40,
          height: 40,
          child: BrandedSpinner(size: 24),
        )),
      );
      await tester.pump();
      expect(find.byType(BrandedSpinner), findsOneWidget);
      // Cycle the rotation once and unmount cleanly.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    });

    testWidgets('DotsLoader renders three dots', (tester) async {
      await tester.pumpWidget(_wrap(const DotsLoader()));
      await tester.pump();
      expect(find.byType(DotsLoader), findsOneWidget);
      // DotsLoader internally builds 3 dot Containers wrapped in Transform.
      expect(
        find.descendant(
          of: find.byType(DotsLoader),
          matching: find.byType(Container),
        ),
        findsNWidgets(3),
      );
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    });
  });

  group('WaveformVisualizer', () {
    testWidgets('renders flat baseline with no input', (tester) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(
          width: 200,
          child: WaveformVisualizer(),
        )),
      );
      await tester.pump();
      expect(find.byType(WaveformVisualizer), findsOneWidget);
    });

    testWidgets('updates from amplitude prop', (tester) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(
          width: 200,
          child: WaveformVisualizer(amplitude: -45, active: true),
        )),
      );
      await tester.pump();
      // Send a louder amplitude — widget should accept the new value
      // without throwing.
      await tester.pumpWidget(
        _wrap(const SizedBox(
          width: 200,
          child: WaveformVisualizer(amplitude: -10, active: true),
        )),
      );
      await tester.pump();
      expect(find.byType(WaveformVisualizer), findsOneWidget);
    });

    testWidgets('consumes a sample stream', (tester) async {
      final controller = StreamController<AmplitudeSample>.broadcast();

      await tester.pumpWidget(
        _wrap(SizedBox(
          width: 200,
          child: WaveformVisualizer(
            samples: controller.stream,
            active: true,
          ),
        )),
      );
      await tester.pump();

      controller.add(const AmplitudeSample(normalized: 0.7, dbfs: -10));
      await tester.pump();
      controller.add(const AmplitudeSample(normalized: 0.2, dbfs: -38));
      await tester.pump();

      expect(find.byType(WaveformVisualizer), findsOneWidget);
      await controller.close();
    });
  });
}
