import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:sado_mobile/core/gamification.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/badges/badges_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';
import 'package:sado_mobile/widgets/badge_widget.dart';
import 'package:sado_mobile/widgets/next_badge_card.dart';

/// In-memory game notifier so the badges screen renders deterministic
/// XP/streak/level state without depending on Hive's actual contents.
class _StaticGameNotifier extends GameNotifier {
  _StaticGameNotifier(GameState initial) {
    state = initial;
  }

  @override
  Future<List<String>> markActiveToday() async => const [];
}

GoRouter _router() => GoRouter(
      initialLocation: '/badges',
      routes: [
        GoRoute(path: '/badges', builder: (_, __) => const BadgesScreen()),
        GoRoute(
          path: '/profile',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('profile-stub'))),
        ),
      ],
    );

Widget _wrap({required GameState state}) {
  return ProviderScope(
    overrides: [
      gameProvider.overrideWith((ref) => _StaticGameNotifier(state)),
      // The screen reads assessmentsProvider for the count — feed it an
      // empty CachedResult so the screen doesn't talk to the network.
      assessmentsProvider.overrideWith(
        (ref, _) async => const CachedResult<Assessment>(<Assessment>[]),
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
      routerConfig: _router(),
    ),
  );
}

void main() {
  // GameNotifier eagerly opens a Hive box on construction; even though our
  // _StaticGameNotifier sets state immediately, the parent's _load() still
  // runs. Initialise Hive against a temp directory once for the group so it
  // doesn't surface as an "uncaught" error in the test framework.
  late Directory hiveDir;
  setUpAll(() {
    hiveDir = Directory.systemTemp.createTempSync('sado_badges_test_');
    Hive.init(hiveDir.path);
  });
  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  group('BadgesScreen — next badge card', () {
    testWidgets(
      'a brand-new user with no badges sees a NextBadgeCard pointing at '
      'the first badge milestone',
      (tester) async {
        await tester.pumpWidget(_wrap(state: const GameState()));
        // Let Riverpod resolve the FutureProvider + give animations a tick.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final l = await L.delegate.load(const Locale('uz'));

        final card = find.byType(NextBadgeCard);
        expect(card, findsOneWidget);
        expect(find.text(l.nextBadgeTitle), findsOneWidget);
        expect(
          find.descendant(
            of: card,
            matching: find.text(l.badgeFirstStepTitle),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a user with a 4-day streak gets the streak-5 badge surfaced as '
      'the next milestone',
      (tester) async {
        await tester.pumpWidget(_wrap(
          state: const GameState(
            xp: 80,
            level: 1,
            streakDays: 4,
            badges: ['first_step'],
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final l = await L.delegate.load(const Locale('uz'));
        final card = find.byType(NextBadgeCard);

        expect(
          find.descendant(
            of: card,
            matching: find.text(l.badgeStreak5Title),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text(l.nextBadgeStreakProgress(4, 5)),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'when every built-in badge is already unlocked, the screen shows '
      'the celebratory all-unlocked copy instead of a progress card',
      (tester) async {
        await tester.pumpWidget(_wrap(
          state: GameState(
            xp: 999,
            level: 99,
            streakDays: 99,
            badges: GameBadge.all.map((b) => b.id).toList(),
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final l = await L.delegate.load(const Locale('uz'));
        expect(find.text(l.nextBadgeAllUnlocked), findsOneWidget);
      },
    );
  });

  group('BadgesScreen — tappable badge tiles', () {
    // The badges screen and the detail sheet both contain a parrot mascot
    // with continuous animations (bob + blink). Using `pumpAndSettle` would
    // time out because those controllers `repeat()` forever — so we drive
    // the test frames manually with bounded `pump` calls instead.

    Future<void> pumpScreen(WidgetTester tester, GameState state) async {
      // Make the test viewport tall enough that the entire badge grid is
      // visible without needing to scroll, which sidesteps both the
      // continuous-mascot pumpAndSettle issue and the multi-Scrollable
      // ambiguity in scrollUntilVisible.
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(state: state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
    }

    Future<void> openTileForBadge(
      WidgetTester tester,
      String label,
    ) async {
      final tile = find.ancestor(
        of: find.text(label),
        matching: find.byType(BadgeTile),
      );
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      // Open animation for the modal sheet (Material default ~250ms).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets(
      'tapping a locked badge opens a detail sheet with the locked status '
      'and the how-to-unlock hint (not the past-tense achievement story)',
      (tester) async {
        // No badges unlocked yet — every tile is in its locked state.
        await pumpScreen(tester, const GameState());

        final l = await L.delegate.load(const Locale('uz'));
        await openTileForBadge(tester, l.badgePerfectTitle);

        expect(find.byType(BadgeDetailSheet), findsOneWidget);
        // Hero title in the sheet
        expect(
          find.descendant(
            of: find.byType(BadgeDetailSheet),
            matching: find.text(l.badgePerfectTitle),
          ),
          findsOneWidget,
        );
        // Locked status pill
        expect(
          find.descendant(
            of: find.byType(BadgeDetailSheet),
            matching: find.text(l.badgeStatusLocked),
          ),
          findsOneWidget,
        );
        // The actionable "how do I unlock this?" hint is shown for locked.
        expect(
          find.descendant(
            of: find.byType(BadgeDetailSheet),
            matching: find.text(l.badgePerfectHint),
          ),
          findsOneWidget,
        );
        // Locked footer (encouragement, not the celebratory copy).
        expect(
          find.descendant(
            of: find.byType(BadgeDetailSheet),
            matching: find.text(l.badgeLockedFooter),
          ),
          findsOneWidget,
        );
        // The unlocked-only emoji is hidden — the hero shows the lock icon
        // until the badge is earned.
        expect(
          find.descendant(
            of: find.byType(BadgeDetailSheet),
            matching: find.text('💯'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'tapping an unlocked badge opens the sheet with the unlocked status, '
      'the achievement story and the celebratory footer',
      (tester) async {
        await pumpScreen(
          tester,
          const GameState(
            xp: 30,
            level: 1,
            streakDays: 1,
            badges: ['first_step'],
          ),
        );

        final l = await L.delegate.load(const Locale('uz'));
        await openTileForBadge(tester, l.badgeFirstStepTitle);

        final sheet = find.byType(BadgeDetailSheet);
        expect(sheet, findsOneWidget);

        // Unlocked-status pill
        expect(
          find.descendant(
            of: sheet,
            matching: find.text(l.badgeStatusUnlocked),
          ),
          findsOneWidget,
        );
        // Past-tense achievement story body
        expect(
          find.descendant(
            of: sheet,
            matching: find.text(l.badgeFirstStepBody),
          ),
          findsOneWidget,
        );
        // Celebratory footer (not the locked one).
        expect(
          find.descendant(
            of: sheet,
            matching: find.text(l.badgeUnlockedFooter),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sheet,
            matching: find.text(l.badgeLockedFooter),
          ),
          findsNothing,
        );
        // Hero shows the badge emoji, not the lock.
        expect(
          find.descendant(of: sheet, matching: find.text('🔒')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'the close button on the detail sheet dismisses the modal',
      (tester) async {
        await pumpScreen(tester, const GameState());

        final l = await L.delegate.load(const Locale('uz'));
        await openTileForBadge(tester, l.badgeFirstStepTitle);
        expect(find.byType(BadgeDetailSheet), findsOneWidget);

        final closeBtn = find.descendant(
          of: find.byType(BadgeDetailSheet),
          matching: find.widgetWithText(FilledButton, l.close),
        );
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(BadgeDetailSheet), findsNothing);
      },
    );
  });
}
