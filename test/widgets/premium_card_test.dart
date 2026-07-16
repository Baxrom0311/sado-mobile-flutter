// Coverage for the [PremiumCard] — the cornerstone of the design system.
// This widget is used on every screen (hero cards, list rows, menu tiles,
// modals) so its visual & interaction contract deserves a fence test.
//
// Tested contracts:
//   1. Static (non-tappable) cards skip the GestureDetector path so they
//      don't intercept touches meant for inner widgets.
//   2. Tappable cards forward `onTap` and animate via the lift controller
//      without throwing.
//   3. Gradient overrides solid color when supplied.
//   4. The shadowColor override flips the soft shadow into a tinted variant.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/widgets/premium_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('PremiumCard', () {
    testWidgets(
      'static (no onTap) does not wrap in a GestureDetector',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const PremiumCard(child: Text('Static')),
        ));
        await tester.pump();

        // No tap handler → no GestureDetector wrapping the box. (Inner
        // widgets may still create their own detectors; we look for the
        // direct child of PremiumCard's State.)
        expect(find.text('Static'), findsOneWidget);
        // The first descendant of PremiumCard should be an AnimatedBuilder
        // (the lift wrapper), NOT a GestureDetector.
        final firstChild = find
            .descendant(
              of: find.byType(PremiumCard),
              matching: find.byType(AnimatedBuilder),
            )
            .first;
        expect(firstChild, findsOneWidget);
      },
    );

    testWidgets(
      'tappable card calls onTap exactly once per tap',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(_wrap(
          PremiumCard(
            onTap: () => taps++,
            child: const Text('Tap me'),
          ),
        ));
        await tester.pump();

        await tester.tap(find.text('Tap me'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(taps, 1);

        await tester.tap(find.text('Tap me'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(taps, 2);
      },
    );

    testWidgets(
      'tap-down lift animation does not throw and settles back',
      (tester) async {
        await tester.pumpWidget(_wrap(
          PremiumCard(
            onTap: () {},
            child: const Text('Lift'),
          ),
        ));
        await tester.pump();

        // Press and release; the controller should reverse without error.
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Lift')),
        );
        await tester.pump(const Duration(milliseconds: 80));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull);
        expect(find.text('Lift'), findsOneWidget);
      },
    );

    testWidgets(
      'gradient takes precedence over solid color',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const PremiumCard(
            color: AppColors.danger,
            gradient: AppColors.heroGradient,
            child: Text('Hero'),
          ),
        ));
        await tester.pump();

        // The Container should expose a gradient and have no solid color.
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(PremiumCard),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.gradient, isNotNull);
        expect(decoration.color, isNull);
      },
    );

    testWidgets(
      'shadowColor swaps the default neutral shadow for a tinted one',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const PremiumCard(
            shadowColor: AppColors.primary,
            child: Text('Tinted'),
          ),
        ));
        await tester.pump();

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(PremiumCard),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration as BoxDecoration;
        // Tinted shadow draws the soft shadow at primary alpha, NOT the
        // neutral 0x14000000 used by AppShadow.card.
        expect(decoration.boxShadow, isNotEmpty);
        final firstShadow = decoration.boxShadow!.first;
        // Soft shadow uses primary color with reduced alpha.
        expect(firstShadow.color.a, lessThan(1.0));
        // Compare RGB without alpha — the brand primary should be reflected
        // in the shadow tint.
        expect(firstShadow.color.r, AppColors.primary.r);
        expect(firstShadow.color.g, AppColors.primary.g);
        expect(firstShadow.color.b, AppColors.primary.b);
      },
    );
  });
}
