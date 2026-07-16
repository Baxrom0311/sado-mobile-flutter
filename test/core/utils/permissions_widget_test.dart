import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/core/utils/permissions.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('uz'),
    localizationsDelegates: const [
      L.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L.supportedLocales,
    home: child,
  );
}

void main() {
  testWidgets(
    'ensureMicPermission shows rationale, returns granted on accept + grant',
    (tester) async {
      MicPermissionOutcome? captured;

      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  captured = await MicPermission.ensureMicPermission(
                    context,
                    statusReader: () async => PermissionStatus.denied,
                    requester: () async => PermissionStatus.granted,
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // Rationale dialog visible with both actions.
      expect(find.byType(AlertDialog), findsOneWidget);
      // The "allow" button label comes from arb (uz: "Ruxsat berish").
      final allow = find.widgetWithText(FilledButton, 'Ruxsat berish');
      expect(allow, findsOneWidget);
      await tester.tap(allow);
      await tester.pumpAndSettle();

      expect(captured, MicPermissionOutcome.granted);
    },
  );

  testWidgets(
    'ensureMicPermission returns cancelled when user declines rationale',
    (tester) async {
      MicPermissionOutcome? captured;
      bool requesterCalled = false;

      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  captured = await MicPermission.ensureMicPermission(
                    context,
                    statusReader: () async => PermissionStatus.denied,
                    requester: () async {
                      requesterCalled = true;
                      return PermissionStatus.granted;
                    },
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // Tap "Hozir emas" — the cancel action.
      final cancel = find.widgetWithText(TextButton, 'Hozir emas');
      expect(cancel, findsOneWidget);
      await tester.tap(cancel);
      await tester.pumpAndSettle();

      expect(captured, MicPermissionOutcome.cancelled);
      // Requester must not have been called when the user declined.
      expect(requesterCalled, isFalse);
    },
  );

  testWidgets(
    'ensureMicPermission shortcuts to permanentlyDenied without dialog',
    (tester) async {
      MicPermissionOutcome? captured;
      bool requesterCalled = false;

      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  captured = await MicPermission.ensureMicPermission(
                    context,
                    statusReader: () async =>
                        PermissionStatus.permanentlyDenied,
                    requester: () async {
                      requesterCalled = true;
                      return PermissionStatus.granted;
                    },
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // No dialog appears because the status is already permanent.
      expect(find.byType(AlertDialog), findsNothing);
      expect(captured, MicPermissionOutcome.permanentlyDenied);
      expect(requesterCalled, isFalse);
    },
  );

  testWidgets(
    'ensureMicPermission shortcuts to granted when already granted',
    (tester) async {
      MicPermissionOutcome? captured;

      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  captured = await MicPermission.ensureMicPermission(
                    context,
                    statusReader: () async => PermissionStatus.granted,
                    requester: () async => PermissionStatus.denied,
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(captured, MicPermissionOutcome.granted);
    },
  );
}
