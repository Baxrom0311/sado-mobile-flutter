import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/notifications/notifications_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/notifications_provider.dart';
import 'package:sado_mobile/widgets/offline_banner.dart';
import 'package:sado_mobile/widgets/parrot_mascot.dart';

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
      home: child,
    ),
  );
}

void main() {
  testWidgets('OfflineBanner renders the supplied message', (tester) async {
    await tester.pumpWidget(_wrap(
      const Scaffold(body: OfflineBanner(message: 'Cached data')),
    ));
    await tester.pump();

    expect(find.text('Cached data'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
  });

  testWidgets(
      'NotificationsScreen empty state shows mascot and friendly copy',
      (tester) async {
    // Override the FutureProvider to resolve synchronously to an empty list,
    // so we don't hit real network in widget tests.
    await tester.pumpWidget(_wrap(
      const NotificationsScreen(),
      overrides: [
        notificationsProvider.overrideWith(
          (ref) async => const <AppNotification>[],
        ),
      ],
    ));
    // Allow the FutureProvider microtask to resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.byType(ParrotMascot), findsOneWidget);
    expect(
      find.text("Hozircha bildirishnoma yo'q"),
      findsOneWidget,
    );
  });
}
