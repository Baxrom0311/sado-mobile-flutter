import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/loaders.dart';
import 'package:sado_mobile/widgets/offline_banner.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      locale: const Locale('uz'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('OfflineBanner — explicit message mode', () {
    testWidgets('renders the supplied message and the cloud-off icon',
        (tester) async {
      await tester.pumpWidget(_wrap(const OfflineBanner(message: 'Cached')));
      await tester.pump();

      expect(find.text('Cached'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('does NOT render a retry button in message mode',
        (tester) async {
      await tester.pumpWidget(_wrap(const OfflineBanner(message: 'Cached')));
      await tester.pump();

      // Brief: explicit-message mode is a passive notice, not an action.
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    });
  });

  group('OfflineBanner — auto-detect mode', () {
    testWidgets('hides itself when connectivity stream reports online',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const OfflineBanner(),
        overrides: [
          isOfflineProvider.overrideWith((ref) => Stream.value(false)),
        ],
      ));
      // Let the StreamProvider emit.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    });

    testWidgets('shows the offline label AND a retry pill when offline',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const OfflineBanner(),
        overrides: [
          isOfflineProvider.overrideWith((ref) => Stream.value(true)),
        ],
      ));
      // Resolve the stream, then settle the slide-in animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
    });

    testWidgets('tapping retry swaps the icon for a BrandedSpinner briefly',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const OfflineBanner(),
        overrides: [
          isOfflineProvider.overrideWith((ref) => Stream.value(true)),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 250));

      // Sanity: refresh icon is the resting state.
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.byType(BrandedSpinner), findsNothing);

      await tester.tap(find.text('Qayta urinish'));
      // One frame after the tap the busy state should be visible.
      await tester.pump();

      expect(find.byType(BrandedSpinner), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);

      // After the cosmetic delay we return to the resting state.
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(BrandedSpinner), findsNothing);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets(
        'never falls back to the Material default CircularProgressIndicator',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const OfflineBanner(),
        overrides: [
          isOfflineProvider.overrideWith((ref) => Stream.value(true)),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text('Qayta urinish'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason:
              'OfflineBanner retry must use BrandedSpinner per non-negotiable '
              'design rules.');

      // Drain the cosmetic delay so no timer leaks past the test.
      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
