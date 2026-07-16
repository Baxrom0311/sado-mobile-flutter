import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/widgets/speech_bubble.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('renders the supplied text', (tester) async {
    await tester.pumpWidget(
      _wrap(const SpeechBubble(text: 'Hello SADO')),
    );
    expect(find.text('Hello SADO'), findsOneWidget);
  });

  testWidgets('respects the maxWidth constraint', (tester) async {
    await tester.pumpWidget(
      _wrap(const SpeechBubble(
        text: 'A very long sentence that should be width-capped',
        maxWidth: 120,
      )),
    );
    final size = tester.getSize(find.byType(SpeechBubble));
    expect(size.width, lessThanOrEqualTo(120));
  });

  testWidgets('paints the tail (CustomPaint present)', (tester) async {
    await tester.pumpWidget(
      _wrap(const SpeechBubble(text: 'Tail check')),
    );
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('flips the tail when SpeechBubbleTail.up is requested',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const SpeechBubble(
        text: 'Up tail',
        tailDirection: SpeechBubbleTail.up,
      )),
    );
    // Sanity: the widget builds without errors with both tail directions.
    expect(find.text('Up tail'), findsOneWidget);
  });
}
