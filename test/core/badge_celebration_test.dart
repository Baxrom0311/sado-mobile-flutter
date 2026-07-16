import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/badge_celebration.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

/// Renders a button that, when tapped, calls [onTapWithCtx] with a
/// [BuildContext] that lives *under* the MaterialApp — exactly like a
/// real screen would.
Widget _harness(void Function(BuildContext ctx) onTapWithCtx) {
  return MaterialApp(
    locale: const Locale('uz'),
    localizationsDelegates: const [
      L.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L.supportedLocales,
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => onTapWithCtx(ctx),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
}

/// Pump the test environment long enough for the haptic delay (70ms),
/// the showGeneralDialog open transition (320ms) and a generous safety
/// margin. The dialog uses showGeneralDialog with no animations declared
/// here so pumpAndSettle isn't safe — we'd settle into the OK button's
/// material ripple. Use explicit durations.
///
/// The total wait is generous on purpose: between the haptic burst
/// (`Haptics.success` does a `Future.delayed(70ms)` between the two
/// pulses), the route push, and the 320ms `showGeneralDialog` transition,
/// we need at least ~500ms — we give it more headroom so a slow CI host
/// doesn't make this flaky.
Future<void> _waitForDialogIn(WidgetTester tester) async {
  await tester.pump(); // schedule the future + drain microtasks
  // Step the clock in coarse chunks instead of one giant pump so each
  // microtask boundary (haptic 1 → 70ms delay → haptic 2 → showGeneralDialog
  // → route push → transition) gets a chance to advance the build.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitForDialogOut(WidgetTester tester) async {
  await tester.pump(); // start exit animation
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('celebrateUnlockedBadges', () {
    testWidgets('empty list is a complete no-op (no dialog)', (tester) async {
      var called = false;
      await tester.pumpWidget(_harness((ctx) async {
        await celebrateUnlockedBadges(ctx, const []);
        called = true;
      }));
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(called, isTrue);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('single badge id pops one mascot dialog with title + body',
        (tester) async {
      await tester.pumpWidget(_harness((ctx) {
        // ignore: unawaited_futures
        celebrateUnlockedBadges(ctx, const ['first_step']);
      }));
      await tester.tap(find.text('go'));
      await _waitForDialogIn(tester);

      expect(find.text('Birinchi qadam'), findsOneWidget);
      expect(
        find.text('SADO bilan tanishishni boshladingiz!'),
        findsOneWidget,
      );

      // Drain the dialog cleanly.
      await tester.tap(find.text('OK'));
      await _waitForDialogOut(tester);
    });

    testWidgets('multiple badge ids cascade — second appears after dismiss',
        (tester) async {
      await tester.pumpWidget(_harness((ctx) {
        // ignore: unawaited_futures
        celebrateUnlockedBadges(
          ctx,
          const ['first_step', 'streak_5'],
          delayBetween: const Duration(milliseconds: 50),
        );
      }));
      await tester.tap(find.text('go'));
      await _waitForDialogIn(tester);
      expect(find.text('Birinchi qadam'), findsOneWidget);

      // Dismiss → wait long enough for the close animation, the inter-
      // dialog gap and the next open animation to finish.
      await tester.tap(find.text('OK'));
      await _waitForDialogOut(tester);
      await _waitForDialogIn(tester);

      expect(find.text('Birinchi qadam'), findsNothing);
      expect(find.text('Olov yondi!'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await _waitForDialogOut(tester);
    });

    testWidgets(
        'unknown badge ids fall back to generic newBadgeUnlocked copy',
        (tester) async {
      await tester.pumpWidget(_harness((ctx) {
        // ignore: unawaited_futures
        celebrateUnlockedBadges(ctx, const ['this_is_not_a_real_badge']);
      }));
      await tester.tap(find.text('go'));
      await _waitForDialogIn(tester);

      expect(find.text('Yangi nishon ochildi!'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await _waitForDialogOut(tester);
    });
  });
}
