import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/widgets/quick_assessment_fab.dart';

void main() {
  group('QuickAssessmentFab', () {
    testWidgets(
        'renders the supplied tooltip via Semantics so accessibility tools '
        'can find the action', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          floatingActionButton: QuickAssessmentFab(
            tooltip: 'Boshlash',
            onPressed: () {},
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          body: const SizedBox.shrink(),
        ),
      ));
      await tester.pump();

      // The tooltip is exposed both via Semantics(label:) — for screen
      // readers — and via the Material Tooltip overlay — for keyboard /
      // long-press users. We only need to verify the Semantics label;
      // the Tooltip text only materialises on long-press.
      final semantics = tester.getSemantics(find.byType(QuickAssessmentFab));
      expect(semantics.label, contains('Boshlash'));
    });

    testWidgets('default mic icon is rendered inside the FAB',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          floatingActionButton: QuickAssessmentFab(
            tooltip: 'Boshlash',
            onPressed: () {},
          ),
          body: const SizedBox.shrink(),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('honours an icon override', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          floatingActionButton: QuickAssessmentFab(
            tooltip: 'Boshlash',
            icon: Icons.bolt_rounded,
            onPressed: () {},
          ),
          body: const SizedBox.shrink(),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
    });

    testWidgets('tap fires the supplied onPressed callback exactly once',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          floatingActionButton: QuickAssessmentFab(
            tooltip: 'Boshlash',
            onPressed: () => taps++,
          ),
          body: const SizedBox.shrink(),
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(QuickAssessmentFab));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('press-down then release settles cleanly without throwing',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          floatingActionButton: QuickAssessmentFab(
            tooltip: 'Boshlash',
            onPressed: () {},
          ),
          body: const SizedBox.shrink(),
        ),
      ));
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(QuickAssessmentFab)),
      );
      // Hold mid-animation — should drive the scale controller forward
      // without throwing.
      await tester.pump(const Duration(milliseconds: 60));
      await gesture.up();
      // Release — controller reverses back to 0. pumpAndSettle ensures the
      // controller has fully unwound; the test would fail with a "pending
      // timers" message if disposal leaked.
      await tester.pumpAndSettle();

      expect(find.byType(QuickAssessmentFab), findsOneWidget);
    });
  });
}
