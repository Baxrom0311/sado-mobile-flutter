import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sado_mobile/core/shell_screen.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/quick_assessment_fab.dart';

/// Connectivity stub that always reports the device as online so the
/// OfflineBanner inside the shell stays hidden during tests.
class _AlwaysOnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  static void install() {
    ConnectivityPlatform.instance = _AlwaysOnlineConnectivity();
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      const [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

GoRouter _router({required String initial}) {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));

  return GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (_, __, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => stub('home-stub')),
          GoRoute(
            path: '/exercises',
            builder: (_, __) => stub('exercises-stub'),
          ),
          GoRoute(
            path: '/progress',
            builder: (_, __) => stub('progress-stub'),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => stub('profile-stub'),
          ),
          GoRoute(
            path: '/badges',
            builder: (_, __) => stub('badges-stub'),
          ),
          GoRoute(
            path: '/children',
            builder: (_, __) => stub('children-stub'),
          ),
        ],
      ),
    ],
  );
}

Widget _wrap(GoRouter router) {
  return ProviderScope(
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

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Pin connectivity to "online" so the offline banner doesn't render and
  // the bottom nav layout doesn't shift between assertions.
  _AlwaysOnlineConnectivity.install();

  group('ShellScreen', () {
    testWidgets('renders the four primary tabs', (tester) async {
      await tester.pumpWidget(_wrap(_router(initial: '/')));
      await tester.pump();

      final l = await L.delegate.load(const Locale('uz'));
      expect(find.text(l.tabHome), findsOneWidget);
      expect(find.text(l.tabExercises), findsOneWidget);
      expect(find.text(l.tabProgress), findsOneWidget);
      expect(find.text(l.tabProfile), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('home tab is selected for / route', (tester) async {
      await tester.pumpWidget(_wrap(_router(initial: '/')));
      await tester.pump();

      final navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);
      await _disposeTree(tester);
    });

    testWidgets('exercises tab is selected when on /exercises',
        (tester) async {
      await tester.pumpWidget(_wrap(_router(initial: '/exercises')));
      await tester.pump();

      final navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);
      await _disposeTree(tester);
    });

    testWidgets('progress tab is selected on /progress', (tester) async {
      await tester.pumpWidget(_wrap(_router(initial: '/progress')));
      await tester.pump();

      final navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 2);
      await _disposeTree(tester);
    });

    testWidgets('profile tab is selected on /profile', (tester) async {
      await tester.pumpWidget(_wrap(_router(initial: '/profile')));
      await tester.pump();

      final navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 3);
      await _disposeTree(tester);
    });

    testWidgets('profile tab also lights up on nested routes (/badges)',
        (tester) async {
      await tester.pumpWidget(_wrap(_router(initial: '/badges')));
      await tester.pump();

      final navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 3,
          reason: '/badges, /children, /settings all surface under Profile');
      await _disposeTree(tester);
    });

    testWidgets('tapping Exercises navigates to /exercises', (tester) async {
      final router = _router(initial: '/');
      await tester.pumpWidget(_wrap(router));
      await tester.pump();

      final l = await L.delegate.load(const Locale('uz'));

      await tester.tap(find.text(l.tabExercises));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('exercises-stub'), findsOneWidget);
      await _disposeTree(tester);
    });

    testWidgets('tapping Progress navigates to /progress', (tester) async {
      final router = _router(initial: '/');
      await tester.pumpWidget(_wrap(router));
      await tester.pump();

      final l = await L.delegate.load(const Locale('uz'));

      await tester.tap(find.text(l.tabProgress));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('progress-stub'), findsOneWidget);
      await _disposeTree(tester);
    });

    testWidgets(
        'surfaces the QuickAssessmentFab above the bottom nav on every tab',
        (tester) async {
      await tester.pumpWidget(_wrap(_router(initial: '/')));
      await tester.pump();

      // Home tab — FAB is visible.
      expect(find.byType(QuickAssessmentFab), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Switch to a different tab and confirm the FAB persists — it lives
      // on the shell, not the routed page.
      await tester
          .pumpWidget(_wrap(_router(initial: '/progress')));
      await tester.pump();
      expect(find.byType(QuickAssessmentFab), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('tapping the FAB jumps to the exercises (assessment) tab',
        (tester) async {
      // /profile so that "exercises-stub" is not already on screen.
      final router = _router(initial: '/profile');
      await tester.pumpWidget(_wrap(router));
      await tester.pump();

      expect(find.text('profile-stub'), findsOneWidget);
      expect(find.text('exercises-stub'), findsNothing);

      await tester.tap(find.byType(QuickAssessmentFab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('exercises-stub'), findsOneWidget);
      await _disposeTree(tester);
    });
  });
}
