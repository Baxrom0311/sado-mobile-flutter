import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/local/preferences.dart';
import 'package:sado_mobile/features/auth/onboarding_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/premium_button.dart';

/// Minimal in-memory [Preferences] stub. Onboarding-flag persistence is the
/// only behavior we care about here, so the rest of the surface forwards to
/// safe defaults via [noSuchMethod].
class _StubPreferences implements Preferences {
  bool _onboardingSeen;
  _StubPreferences({bool onboardingSeen = false})
      : _onboardingSeen = onboardingSeen;

  @override
  bool get onboardingSeen => _onboardingSeen;

  @override
  Future<void> setOnboardingSeen(bool seen) async {
    _onboardingSeen = seen;
  }

  @override
  String? get savedLocaleCode => null;

  @override
  Future<void> setLocaleCode(String code) async {}

  @override
  bool get notificationsEnabled => true;

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {}

  @override
  AudioQuality get audioQuality => AudioQuality.standard;

  @override
  Future<void> setAudioQuality(AudioQuality quality) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GoRouter _router(GlobalKey<NavigatorState> navKey) => GoRouter(
      navigatorKey: navKey,
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('login-stub')),
          ),
        ),
      ],
    );

Widget _wrap(GoRouter router, {Preferences? prefs}) {
  return ProviderScope(
    overrides: [
      preferencesProvider.overrideWithValue(prefs ?? _StubPreferences()),
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
      routerConfig: router,
    ),
  );
}

/// Drains pending animations / delays before the test ends.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingScreen', () {
    testWidgets('renders the first page with mascot and CTA', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_wrap(_router(navKey)));
      await tester.pump();

      final l = await L.delegate.load(const Locale('uz'));

      // First page title visible.
      expect(find.text(l.onboarding1Title), findsOneWidget);
      // Skip button rendered.
      expect(find.text(l.skip), findsOneWidget);
      // CTA is "Next" on pages 1+2 and "Get started" on page 3.
      expect(find.text(l.next), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('Next button advances through the pages', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_wrap(_router(navKey)));
      await tester.pump();

      final l = await L.delegate.load(const Locale('uz'));

      // Page 1.
      expect(find.text(l.onboarding1Title), findsOneWidget);

      // Tap Next → page 2.
      await tester.tap(find.byType(PremiumButton));
      // Page transition animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text(l.onboarding2Title), findsOneWidget);

      // Tap Next → page 3.
      await tester.tap(find.byType(PremiumButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text(l.onboarding3Title), findsOneWidget);
      // CTA label flips to "getStarted" on the last page.
      expect(find.text(l.getStarted), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets("'Get started' on the final page navigates to /login",
        (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final router = _router(navKey);
      final prefs = _StubPreferences();
      await tester.pumpWidget(_wrap(router, prefs: prefs));
      await tester.pump();

      // Skip directly to the last page.
      await tester.tap(find.byType(PremiumButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byType(PremiumButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Now press "Get started".
      await tester.tap(find.byType(PremiumButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // We should have navigated to /login (route stub renders 'login-stub').
      expect(find.text('login-stub'), findsOneWidget);
      // …and the onboarding flag should now be persisted.
      expect(prefs.onboardingSeen, isTrue);

      await _disposeTree(tester);
    });

    testWidgets("'Skip' jumps straight to /login and marks onboarding seen",
        (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final router = _router(navKey);
      final prefs = _StubPreferences();
      await tester.pumpWidget(_wrap(router, prefs: prefs));
      await tester.pump();

      final l = await L.delegate.load(const Locale('uz'));

      await tester.tap(find.text(l.skip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('login-stub'), findsOneWidget);
      expect(prefs.onboardingSeen, isTrue);

      await _disposeTree(tester);
    });

    testWidgets('page indicator highlights the active page', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_wrap(_router(navKey)));
      await tester.pump();

      // Three pill indicators are rendered (one per page). The active one
      // is wider than the others — assert by counting widths.
      final indicators = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          // Filter out unrelated AnimatedContainers (e.g. inside the
          // PremiumButton). The pill indicators specify a fixed height of 8.
          .where((c) {
        final h = (c.constraints?.maxHeight) ?? 0;
        return h == 8;
      }).toList();

      expect(indicators, hasLength(3),
          reason: 'expected exactly 3 page indicators');

      // Exactly one indicator should be the wider 'active' state (28 px),
      // the other two the inactive 8 px.
      final widths =
          indicators.map((c) => c.constraints?.maxWidth ?? 0).toList()..sort();
      expect(widths, [8, 8, 28]);

      await _disposeTree(tester);
    });
  });
}
