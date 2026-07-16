import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/messenger.dart';

void main() {
  group('appMessengerKey + showAppSnackBar', () {
    setUp(() {
      // The global key is module-level. Tests that pump a MaterialApp
      // wired to it leave it attached after teardown — clear the
      // attached state by replacing it with a fresh GlobalKey is not
      // possible (it's `final`), but reading currentState after tear
      // down returns null since the framework detaches it.
    });

    testWidgets(
        'showAppSnackBar is a no-op when no MaterialApp owns the key',
        (tester) async {
      // Fresh test — the key is detached. Calling the helper must not
      // throw and the framework should not rebuild anything.
      expect(appMessengerKey.currentState, isNull);
      showAppSnackBar(const SnackBar(content: Text('ignored')));
      await tester.pump(const Duration(milliseconds: 50));
      // No exception means the no-op branch fired correctly.
    });

    testWidgets('showAppSnackBar surfaces a snackbar via the global key',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: appMessengerKey,
          home: const Scaffold(body: Center(child: Text('home'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(appMessengerKey.currentState, isNotNull);

      showAppSnackBar(const SnackBar(content: Text('uploaded auto')));
      await tester.pump(); // schedule
      await tester.pump(const Duration(milliseconds: 50)); // animate in

      expect(find.text('uploaded auto'), findsOneWidget);

      // Drain the snackbar so the framework doesn't whine about pending
      // timers.
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a second showAppSnackBar replaces the previous one',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: appMessengerKey,
          home: const Scaffold(body: Center(child: Text('home'))),
        ),
      );
      await tester.pumpAndSettle();

      showAppSnackBar(const SnackBar(content: Text('first')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('first'), findsOneWidget);

      // Calling again should hide the first and show the second.
      showAppSnackBar(const SnackBar(content: Text('second')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
    });
  });
}
