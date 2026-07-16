import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/features/help/help_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

GoRouter _helpRouter() => GoRouter(
      initialLocation: '/help',
      routes: [
        GoRoute(
          path: '/help',
          builder: (_, __) => const HelpScreen(),
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
    routerConfig: _helpRouter(),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  // Animations on this screen stagger up to ~520ms (5 * 60ms delay +
  // 240ms duration). 800ms is comfortably past the last keyframe.
  await tester.pump(const Duration(milliseconds: 800));
}

/// Drains a long ListView so every animated/lazy tile has been built
/// at least once. Currently only used by tests that don't need to
/// assert keys after the scroll completes — kept around as a debugging
/// helper and to keep parity with similar setups in this codebase.
// ignore: unused_element
Future<void> _scrollToBottom(WidgetTester tester) async {
  final listView = find.byKey(const Key('help.list'));
  for (var i = 0; i < 8; i++) {
    await tester.drag(listView, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 120));
  }
  await tester.pump(const Duration(milliseconds: 200));
}

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
      'HelpScreen renders the localized hero, disclaimer and section titles',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await _settle(tester);

    // App bar.
    expect(find.text('Yordam markazi'), findsOneWidget);

    // Hero copy (uz).
    expect(find.text('Sizga yordam berish uchun shu yerdamiz'), findsOneWidget);
    expect(find.textContaining('amaliy maslahatlar'), findsOneWidget);

    // Disclaimer card.
    expect(find.byKey(const Key('help.disclaimer')), findsOneWidget);
    expect(find.text('Eslatma'), findsOneWidget);
    expect(find.textContaining('skrining va mashq vositasi'), findsOneWidget);

    // FAQ section title is uppercased: "TEZ-TEZ BERILADIGAN SAVOLLAR"
    expect(
      find.textContaining(RegExp(r'TEZ-TEZ', caseSensitive: false)),
      findsAtLeastNWidgets(1),
    );

    await _disposeTree(tester);
  });

  testWidgets(
    'HelpScreen exposes 6 FAQ tiles and 5 tip cards by stable key',
    (tester) async {
      // Force a tall viewport so the entire screen fits without
      // ListView culling the off-screen entries we want to assert on.
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap());
      await _settle(tester);

      for (var i = 0; i < 6; i++) {
        expect(
          find.byKey(Key('help.faq.$i')),
          findsOneWidget,
          reason: 'FAQ tile help.faq.$i should be in the tree',
        );
      }
      for (var i = 0; i < 5; i++) {
        expect(
          find.byKey(Key('help.tip.$i')),
          findsOneWidget,
          reason: 'Tip card help.tip.$i should be in the tree',
        );
      }

      // Tips section title also rendered (uppercased "UYDAGI ...").
      expect(
        find.textContaining(RegExp(r'UYDAGI', caseSensitive: false)),
        findsAtLeastNWidgets(1),
      );

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'HelpScreen FAQ tile reveals its answer body after tapping',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await _settle(tester);

      // Before tap: the first FAQ's question is on screen, but the
      // answer body should not have been built yet (collapsed).
      expect(
        find.textContaining(
            'Mobil ilova qisqa audio'), // first words of helpFaq1A
        findsNothing,
      );

      final firstFaq = find.byKey(const Key('help.faq.0'));
      await _bringIntoView(tester, firstFaq);
      await tester.tap(firstFaq);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));

      // After tap: answer body is in the tree.
      expect(
        find.textContaining('Mobil ilova qisqa audio'),
        findsOneWidget,
      );

      await _disposeTree(tester);
    },
  );

  testWidgets('HelpScreen renders Russian copy when locale is ru',
      (tester) async {
    await tester.pumpWidget(_wrap(locale: const Locale('ru')));
    await _settle(tester);

    expect(find.text('Центр помощи'), findsOneWidget);
    expect(find.text('Мы рядом, чтобы помочь'), findsOneWidget);
    expect(find.text('Важно'), findsOneWidget);
    // Russian disclaimer body.
    expect(
      find.textContaining('инструмент для скрининга'),
      findsOneWidget,
    );

    await _disposeTree(tester);
  });

  testWidgets('HelpScreen back arrow falls back to /settings via go()',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await _settle(tester);

    final backButton = find.byIcon(Icons.arrow_back_rounded);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('SETTINGS_FALLBACK'), findsOneWidget);

    await _disposeTree(tester);
  });
}
