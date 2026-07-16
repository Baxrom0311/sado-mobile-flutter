import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/features/settings/about_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

GoRouter _aboutRouter() => GoRouter(
      initialLocation: '/about',
      routes: [
        GoRoute(
          path: '/about',
          builder: (_, __) => const AboutScreen(appVersion: '9.9.9-test'),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('SETTINGS_FALLBACK'))),
        ),
      ],
    );

Widget _wrap({Locale locale = const Locale('uz')}) {
  return MaterialApp.router(
    theme: AppTheme.light,
    locale: locale,
    localizationsDelegates: const [
      L.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L.supportedLocales,
    routerConfig: _aboutRouter(),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

/// Brings [finder] into the viewport so subsequent taps actually hit the
/// underlying widget. The About screen is a ListView that lazily mounts
/// off-screen children, so we have to scroll first or the finder reports
/// "no widgets" even though the widget is logically in the screen.
Future<void> _bringIntoView(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets(
      'AboutScreen renders the hero with localized app name, tagline and version chip',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await _settle(tester);

    // Hero pieces.
    expect(find.text('SADO'), findsWidgets);
    expect(
      find.text("Bolalar nutqini rivojlantiruvchi do'st"),
      findsOneWidget,
    );
    // Version chip uses the injected appVersion ("Versiya 9.9.9-test").
    expect(find.textContaining('9.9.9-test'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'AboutScreen tapping a legal section reveals the long-form Terms body',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await _settle(tester);

    final terms = find.byKey(const Key('about.terms'));
    await _bringIntoView(tester, terms);

    // The body is conditionally rendered, so before expansion it is not
    // present in the tree at all.
    expect(
      find.textContaining('SADO ilovasidan foydalanib'),
      findsNothing,
    );

    await tester.tap(terms, warnIfMissed: false);
    await _settle(tester);

    expect(
      find.textContaining('SADO ilovasidan foydalanib'),
      findsOneWidget,
    );

    await _disposeTree(tester);
  });

  testWidgets(
      'AboutScreen support card surfaces a localized snackbar with the email',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await _settle(tester);

    final copyButton = find.byKey(const Key('about.support.copy'));
    await _bringIntoView(tester, copyButton);
    expect(copyButton, findsOneWidget);

    // Invoke the InkWell handler directly. We are testing wiring of the
    // support card (snackbar appears with the right email), not gesture
    // routing. The clipboard write inside _copy is fire-and-forget and
    // does not block the snackbar surfacing on platforms without a
    // clipboard plugin.
    final ink = tester.widget<InkWell>(copyButton);
    ink.onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('support@sado.uz'), findsWidgets);

    await _disposeTree(tester);
  });

  testWidgets(
      'AboutScreen licenses tile defers to the platform license page',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await _settle(tester);

    final tile = find.byKey(const Key('about.licenses.tile'));
    await _bringIntoView(tester, tile);

    final scaffoldsBefore = find.byType(Scaffold).evaluate().length;
    await tester.tap(tile, warnIfMissed: false);
    await _settle(tester);

    // showLicensePage pushes a LicensePage route which mounts its own
    // Scaffold — exact count depends on Flutter internals, so we just
    // check that something *new* mounted on top of the About screen.
    expect(
      find.byType(Scaffold).evaluate().length,
      greaterThan(scaffoldsBefore),
    );

    await _disposeTree(tester);
  });

  testWidgets(
      'AboutScreen renders the Russian copy when the locale is ru',
      (tester) async {
    await tester.pumpWidget(_wrap(locale: const Locale('ru')));
    await _settle(tester);

    expect(find.text('О приложении'), findsOneWidget);
    expect(find.textContaining('Версия 9.9.9-test'), findsOneWidget);

    await _disposeTree(tester);
  });
}
