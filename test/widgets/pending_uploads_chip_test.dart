// Coverage for [PendingUploadsChip] — the small status pill that surfaces
// queued offline assessment uploads on the home screen header.
//
// Contracts:
//   * Renders nothing when the queue is empty (no visual noise on a clean
//     online state).
//   * Renders the localized "X ta yuklanish kutilmoqda" copy when the
//     count is positive, with the cloud-upload icon and a chevron.
//   * Tapping the chip routes the user to /uploads.
//   * Exposes a Semantics button so accessibility tools can find it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';
import 'package:sado_mobile/widgets/pending_uploads_chip.dart';

GoRouter _router() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) =>
            const Scaffold(body: Center(child: PendingUploadsChip())),
      ),
      GoRoute(
        path: '/uploads',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('UPLOADS_PAGE'))),
      ),
    ],
  );
}

Widget _wrap({required Stream<int> countStream}) {
  return ProviderScope(
    overrides: [
      pendingUploadsCountProvider.overrideWith((ref) => countStream),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      locale: const Locale('uz'),
      routerConfig: _router(),
    ),
  );
}

void main() {
  group('PendingUploadsChip', () {
    testWidgets(
      'renders nothing when the queue is empty',
      (tester) async {
        await tester.pumpWidget(_wrap(countStream: Stream.value(0)));
        // Two pumps: one for the initial frame, one to drain the stream.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(PendingUploadsChip), findsOneWidget);
        // No icon, no chevron, no copy — the chip collapses to SizedBox.
        expect(find.byIcon(Icons.cloud_upload_rounded), findsNothing);
        expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      },
    );

    testWidgets(
      'renders the icon, count copy and chevron when there are queued uploads',
      (tester) async {
        await tester.pumpWidget(_wrap(countStream: Stream.value(3)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byIcon(Icons.cloud_upload_rounded), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
        // Localized copy contains the count — we don't lock the exact
        // wording so translations can evolve without breaking the test.
        final hasNumber = find
            .byWidgetPredicate(
              (w) => w is Text && (w.data?.contains('3') ?? false),
            )
            .evaluate()
            .isNotEmpty;
        expect(hasNumber, isTrue,
            reason: 'localized copy should surface the queue size');
      },
    );

    testWidgets(
      'exposes a Semantics button so accessibility tools can find it',
      (tester) async {
        await tester.pumpWidget(_wrap(countStream: Stream.value(2)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // The chip wraps its content in Semantics(button: true, label: ...).
        // Locate the Semantics widget the chip exposes (button: true) and
        // assert the label is non-empty so screen readers have a hook.
        final semanticsFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.button ?? false) &&
              (w.properties.label ?? '').isNotEmpty,
        );
        expect(semanticsFinder, findsOneWidget);
      },
    );

    testWidgets(
      'tapping the chip navigates to the uploads screen',
      (tester) async {
        await tester.pumpWidget(_wrap(countStream: Stream.value(5)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Tap the icon (always inside the chip's hit area).
        await tester.tap(find.byIcon(Icons.cloud_upload_rounded));
        // Allow the GoRouter transition to settle without using
        // pumpAndSettle (the chip's fade/scale entrance animation
        // continues to drive frames).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('UPLOADS_PAGE'), findsOneWidget);
      },
    );

    testWidgets(
      'reactively hides itself when the count drains back to zero',
      (tester) async {
        // Two-emission stream: starts with 4, then settles to 0.
        final controller = StreamController<int>();
        addTearDown(controller.close);

        await tester.pumpWidget(_wrap(countStream: controller.stream));
        controller.add(4);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byIcon(Icons.cloud_upload_rounded), findsOneWidget);

        controller.add(0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byIcon(Icons.cloud_upload_rounded), findsNothing);
      },
    );
  });
}
