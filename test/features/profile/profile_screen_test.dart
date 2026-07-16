import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:sado_mobile/core/gamification.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/api_client.dart';
import 'package:sado_mobile/data/local/preferences.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/profile/profile_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';
import 'package:sado_mobile/widgets/streak_chip.dart';

User _user({
  String fullName = 'Aziz Karimov',
  String email = 'parent@sado.uz',
}) =>
    User(
      id: 'u1',
      email: email,
      fullName: fullName,
      role: 'parent',
      language: 'uz',
      isActive: true,
      isVerified: true,
      createdAt: DateTime.utc(2024, 1, 1),
    );

/// AuthNotifier stub — bypasses the network probe in [AuthNotifier._init]
/// so the test never resolves a real /users/me request and the screen
/// renders the supplied user immediately.
class _StaticAuthNotifier extends AuthNotifier {
  _StaticAuthNotifier(super.api, super.ref, User initial) {
    state = AuthState(status: AuthStatus.authenticated, user: initial);
  }
}

/// GameNotifier stub — sets a deterministic in-memory game state, skipping
/// the Hive load that runs in the production constructor. This lets us
/// assert custom XP / streak / badge counts without booting Hive in tests.
class _StaticGameNotifier extends GameNotifier {
  _StaticGameNotifier(GameState initial) {
    state = initial;
  }
}

class _RouteSpy {
  String? lastLocation;
}

GoRouter _router(_RouteSpy spy) {
  Widget stub(String tag) => Scaffold(body: Text('STUB:$tag'));
  return GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, state) {
          spy.lastLocation = state.matchedLocation;
          return stub('edit');
        },
      ),
      GoRoute(
        path: '/children',
        builder: (_, state) {
          spy.lastLocation = state.matchedLocation;
          return stub('children');
        },
      ),
      GoRoute(
        path: '/badges',
        builder: (_, state) {
          spy.lastLocation = state.matchedLocation;
          return stub('badges');
        },
      ),
      GoRoute(
        path: '/progress',
        builder: (_, state) {
          spy.lastLocation = state.matchedLocation;
          return stub('progress');
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (_, state) {
          spy.lastLocation = state.matchedLocation;
          return stub('settings');
        },
      ),
    ],
  );
}

Widget _wrap({
  required _RouteSpy spy,
  User? user,
  GameState? game,
}) {
  return ProviderScope(
    overrides: [
      preferencesProvider.overrideWithValue(Preferences.inMemory()),
      // Inert dio — the screen never makes network calls, but the
      // AuthNotifier constructor still asks for an authApi instance.
      dioProvider.overrideWithValue(Dio()),
      authProvider.overrideWith(
        (ref) => _StaticAuthNotifier(
          ref.watch(authApiProvider),
          ref,
          user ?? _user(),
        ),
      ),
      gameProvider.overrideWith(
        (ref) => _StaticGameNotifier(game ?? const GameState()),
      ),
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
      routerConfig: _router(spy),
    ),
  );
}

/// Pumps long enough for [flutter_animate] entrance effects to settle but
/// short enough that the test is still fast.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Replaces the running widget tree with a sentinel so any pending
/// AnimationControllers used by the parrot mascot or flutter_animate
/// effects get a chance to dispose cleanly.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  // GameNotifier eagerly opens a Hive box on construction. Initialise Hive
  // against a temp directory so our static stub's super-call doesn't blow
  // up before we can override its state.
  late Directory hiveDir;
  setUpAll(() {
    hiveDir = Directory.systemTemp.createTempSync('sado_profile_test_');
    Hive.init(hiveDir.path);
  });
  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  testWidgets(
    'renders the user header, XP bar, streak chip and the menu tiles',
    (tester) async {
      // The profile screen is a long ListView. Use a tall viewport so all
      // tiles are laid out and discoverable without scrolling.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(
        spy: spy,
        user: _user(fullName: 'Aziz Karimov', email: 'parent@sado.uz'),
        game: const GameState(
          xp: 350,
          level: 3,
          streakDays: 7,
          badges: ['first_step', 'streak_5'],
        ),
      ));
      await _settle(tester);

      // Hero card: name + email + the avatar initial.
      expect(find.text('Aziz Karimov'), findsOneWidget);
      expect(find.text('parent@sado.uz'), findsOneWidget);
      expect(find.text('A'), findsOneWidget); // avatar initial

      // Streak chip uses the localized "kun" suffix and the day count,
      // composed into a single Text widget. With a 7-day streak the
      // _AccountStatsCard's longest-streak cell *also* renders "7 kun"
      // (longest defaults to streak when not set), so this label is
      // expected to appear at least once. We pin it precisely by scoping
      // the find to the StreakChip subtree.
      expect(
        find.descendant(
          of: find.byType(StreakChip),
          matching: find.text('7 kun'),
        ),
        findsOneWidget,
      );
      // …and the longest-streak stat cell shows the same value, in a
      // different style/colour.
      expect(find.text('7 kun'), findsNWidgets(2));

      // Badges count tile: "<count> Nishonlar".
      expect(find.text('2 Nishonlar'), findsOneWidget);

      // The four primary navigation tiles each render their localized
      // label. "Profilni tahrirlash" comes from the localized editProfile
      // string and is unique to the menu tile.
      expect(find.text('Profilni tahrirlash'), findsOneWidget);
      // "Bolalar" appears both as the AccountStats children label AND as
      // the children menu tile, so we pin the menu tile via _MenuTile.
      expect(find.text('Bolalar'), findsAtLeastNWidgets(1));
      expect(find.text('Taraqqiyot'), findsOneWidget);
      expect(find.text('Sozlamalar'), findsOneWidget);
      // "Nishonlar" appears both inside the badge counter card and the
      // dedicated menu tile.
      expect(find.text('Nishonlar'), findsAtLeastNWidgets(1));

      // Logout tile renders the destructive label.
      expect(find.text('Chiqish'), findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'tapping the editProfile menu tile navigates to /profile/edit',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(spy: spy));
      await _settle(tester);

      // The menu tile (not the AppBar action) is the one wrapped in a
      // PremiumCard with the "Profilni tahrirlash" label.
      await tester.tap(find.text('Profilni tahrirlash'));
      await tester.pumpAndSettle();

      expect(spy.lastLocation, '/profile/edit');

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'tapping the children tile navigates to /children',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      await tester.pumpWidget(_wrap(spy: spy));
      await _settle(tester);

      // The menu tile is tagged with a stable ValueKey so we don't have
      // to disambiguate it from the AccountStats children stat label
      // (which also reads "Bolalar").
      final tile = find.byKey(const ValueKey('profile.menu.children'));
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(spy.lastLocation, '/children');

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'tapping the logout button shows a confirmation dialog with cancel + logout',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      // Use a streak below 3 so the StreakChip skips its repeating pulse —
      // otherwise pumpAndSettle never converges. We aren't testing the
      // streak rendering here, just the logout flow.
      await tester.pumpWidget(_wrap(
        spy: spy,
        game: const GameState(streakDays: 0),
      ));
      await _settle(tester);

      // Tap on the logout icon — uniquely identifies the destructive tile,
      // and it's the very last item in the ListView so it's already visible
      // on a tall viewport.
      await tester.ensureVisible(find.byIcon(Icons.logout_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.logout_rounded));
      // Dialog open animation: ~150ms. Pump twice to flush the route push.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Confirmation dialog renders title, body and both action buttons.
      expect(find.text('Chiqishni xohlaysizmi?'), findsOneWidget);
      expect(find.text('Akkauntingizdan chiqasiz'), findsOneWidget);
      expect(find.text('Bekor qilish'), findsOneWidget);
      // The "Chiqish" label now appears on both the underlying tile and
      // the dialog's destructive button.
      expect(find.text('Chiqish'), findsAtLeastNWidgets(2));

      // Cancel keeps the user on /profile.
      await tester.tap(find.text('Bekor qilish'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Chiqishni xohlaysizmi?'), findsNothing);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'AccountStatsCard surfaces the longest streak even after the current resets',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _RouteSpy();
      // Current streak is back to 1, but the user previously hit 12. The
      // stat card should display the personal-best (12), not the current.
      await tester.pumpWidget(_wrap(
        spy: spy,
        game: const GameState(
          streakDays: 1,
          longestStreak: 12,
          badges: [],
        ),
      ));
      await _settle(tester);

      // Card title.
      expect(find.text('Akkaunt statistikasi'), findsOneWidget);

      // Longest streak cell — uses the localized day-count plural so we
      // assert against the rendered "12 kun" string.
      expect(find.text('12 kun'), findsOneWidget);

      // The current-streak chip still shows "1 kun" so the user has both
      // cues at a glance.
      expect(
        find.descendant(
          of: find.byType(StreakChip),
          matching: find.text('1 kun'),
        ),
        findsOneWidget,
      );

      await _disposeTree(tester);
    },
  );
}
