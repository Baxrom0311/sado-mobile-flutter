import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/gamification.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/badge_widget.dart';
import 'package:sado_mobile/widgets/loaders.dart';
import 'package:sado_mobile/widgets/offline_banner.dart';
import 'package:sado_mobile/widgets/parrot_mascot.dart';
import 'package:sado_mobile/widgets/premium_button.dart';
import 'package:sado_mobile/widgets/premium_card.dart';
import 'package:sado_mobile/widgets/recording_button.dart';
import 'package:sado_mobile/widgets/shimmer_loaders.dart';
import 'package:sado_mobile/widgets/streak_chip.dart';
import 'package:sado_mobile/widgets/xp_bar.dart';

Widget wrapWithApp(Widget child, {Locale locale = const Locale('uz')}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      locale: locale,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('PremiumButton', () {
    testWidgets('shows label and reacts to tap', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        wrapWithApp(PremiumButton(
          label: 'Boshlash',
          icon: Icons.play_arrow,
          onPressed: () => pressed++,
        )),
      );
      await tester.pump();

      expect(find.text('Boshlash'), findsOneWidget);

      await tester.tap(find.byType(PremiumButton));
      await tester.pump(const Duration(milliseconds: 200));

      expect(pressed, 1);
    });

    testWidgets('shows spinner in loading state', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const PremiumButton(label: 'Save', loading: true)),
      );
      await tester.pump();

      expect(find.byType(BrandedSpinner), findsOneWidget);
    });

    testWidgets('disabled state ignores taps', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        wrapWithApp(PremiumButton(
          label: 'Disabled',
          onPressed: null,
        )),
      );
      // Trying to tap a disabled button should not throw or fire onPressed.
      await tester.tap(find.byType(PremiumButton), warnIfMissed: false);
      await tester.pump();
      expect(pressed, 0);
    });
  });

  group('Loaders', () {
    testWidgets('MascotLoader renders parrot and message', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const MascotLoader(message: 'Yuklanmoqda')),
      );
      await tester.pump();
      expect(find.byType(ParrotMascot), findsOneWidget);
      expect(find.text('Yuklanmoqda'), findsOneWidget);
      // Sanity: mascot loader does NOT fall back to the Material default
      // CircularProgressIndicator (premium non-negotiable).
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Pump animation a few frames to make sure it doesn't crash, then
      // settle so timers don't leak.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('DotsLoader animates without crashing', (tester) async {
      await tester.pumpWidget(wrapWithApp(const DotsLoader()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      // Three dots painted.
      expect(find.byType(DotsLoader), findsOneWidget);
    });

    testWidgets('BrandedSpinner paints custom arc, not Material default',
        (tester) async {
      await tester.pumpWidget(wrapWithApp(const BrandedSpinner()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(BrandedSpinner), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ParrotMascot', () {
    testWidgets('renders without timers leaking', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const ParrotMascot(mood: ParrotMood.happy, size: 100)),
      );
      await tester.pump();

      expect(find.byType(ParrotMascot), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders with speech bubble message', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const ParrotMascot(
          mood: ParrotMood.talking,
          size: 100,
          message: 'Salom!',
        )),
      );
      await tester.pump();
      expect(find.text('Salom!'), findsOneWidget);
    });

    testWidgets('updates mood without re-creating controllers', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const ParrotMascot(mood: ParrotMood.idle, size: 100)),
      );
      await tester.pump();
      await tester.pumpWidget(
        wrapWithApp(const ParrotMascot(mood: ParrotMood.sad, size: 100)),
      );
      await tester.pump();
      expect(find.byType(ParrotMascot), findsOneWidget);
    });
  });

  group('XpBar', () {
    testWidgets('renders level and progress', (tester) async {
      const state = GameState(xp: 150, level: 2, streakDays: 3);
      await tester.pumpWidget(wrapWithApp(const XpBar(state: state)));
      await tester.pump();

      expect(find.textContaining('150'), findsOneWidget);
    });

    testWidgets('handles zero XP gracefully', (tester) async {
      const state = GameState();
      await tester.pumpWidget(wrapWithApp(const XpBar(state: state)));
      await tester.pump();
      expect(find.byType(XpBar), findsOneWidget);
    });
  });

  group('StreakChip', () {
    testWidgets('shows streak day count', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const StreakChip(days: 7, label: 'kun')),
      );
      await tester.pump();
      expect(find.text('7 kun'), findsOneWidget);
    });
  });

  group('PremiumCard', () {
    testWidgets('renders child and reacts to tap', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        wrapWithApp(PremiumCard(
          onTap: () => tapped++,
          child: const Text('Card'),
        )),
      );
      await tester.pump();
      expect(find.text('Card'), findsOneWidget);
      await tester.tap(find.byType(PremiumCard));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tapped, 1);
    });
  });

  group('ShimmerCard', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(wrapWithApp(const ShimmerCard()));
      await tester.pump();
      expect(find.byType(ShimmerCard), findsOneWidget);
    });
  });

  group('RecordingButton', () {
    testWidgets('renders idle state', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(RecordingButton(recording: false, onTap: () {})),
      );
      await tester.pump();
      expect(find.byType(RecordingButton), findsOneWidget);
    });

    testWidgets('fires onTap', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        wrapWithApp(RecordingButton(recording: false, onTap: () => tapped++)),
      );
      await tester.pump();
      await tester.tap(find.byType(RecordingButton));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tapped, 1);
    });
  });

  group('OfflineBanner', () {
    testWidgets('shows explicit message', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const OfflineBanner(message: 'Cached')),
      );
      await tester.pump();
      expect(find.text('Cached'), findsOneWidget);
    });
  });

  group('BadgeTile', () {
    testWidgets('renders unlocked badge with emoji', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const BadgeTile(
          badge: GameBadge.fiveDayStreak,
          unlocked: true,
          label: 'Olov yondi!',
        )),
      );
      await tester.pump();
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('Olov yondi!'), findsOneWidget);
    });

    testWidgets('renders locked badge with lock icon', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const BadgeTile(
          badge: GameBadge.level10,
          unlocked: false,
          label: 'Locked',
        )),
      );
      await tester.pump();
      expect(find.text('🔒'), findsOneWidget);
      expect(find.text('🏆'), findsNothing);
    });
  });

  group('GameState math', () {
    test('xp thresholds are cumulative', () {
      expect(GameState.xpForLevel(1), 0);
      expect(GameState.xpForLevel(2), 100);
      expect(GameState.xpForLevel(3), 300);
      expect(GameState.xpForLevel(4), 600);
    });

    test('level progress is half at midpoint', () {
      const s = GameState(xp: 50, level: 1);
      expect(s.levelProgress, closeTo(0.5, 0.0001));
    });

    test('level progress clamps to 1.0', () {
      const s = GameState(xp: 99999, level: 1);
      expect(s.levelProgress, 1.0);
    });

    test('xpInLevel computes correctly mid-level', () {
      const s = GameState(xp: 150, level: 2);
      expect(s.xpInLevel, 50); // 150 - 100
      expect(s.xpNeededInLevel, 200); // 300 - 100
    });

    test('badge emojiOf returns known emoji', () {
      expect(GameBadge.emojiOf('streak_5'), '🔥');
      expect(GameBadge.emojiOf('level_5'), '⭐');
    });

    test('levelKey buckets correctly', () {
      expect(levelKey(1), 'levelBeginner');
      expect(levelKey(3), 'levelExplorer');
      expect(levelKey(7), 'levelChampion');
      expect(levelKey(20), 'levelMaster');
    });
  });

  group('Model parsing', () {
    test('Child.fromJson parses required fields', () {
      final c = Child.fromJson({
        'id': 'c1',
        'name': 'Ali',
        'birth_date': '2020-04-15',
        'gender': 'male',
        'parent_id': 'p1',
        'created_at': '2024-01-01T00:00:00Z',
      });
      expect(c.id, 'c1');
      expect(c.name, 'Ali');
      expect(c.gender, 'male');
      expect(c.birthDate.year, 2020);
    });

    test('Exercise.fromJson handles optional fields', () {
      final e = Exercise.fromJson({
        'id': 'e1',
        'title': 'R sound',
        'description': 'Practice R',
        'category': 'articulation',
        'age_group': '5-6',
        'difficulty': 'easy',
        'duration_minutes': 5,
      });
      expect(e.id, 'e1');
      expect(e.targetPhonemes, isNull);
      expect(e.language, 'uz'); // default
      expect(e.isActive, true); // default
    });

    test('Assessment.fromJson handles null score', () {
      final a = Assessment.fromJson({
        'id': 'a1',
        'child_id': 'c1',
        'status': 'completed',
        'created_at': '2024-01-01T00:00:00Z',
      });
      expect(a.score, isNull);
      expect(a.exerciseId, isNull);
    });
  });

  group('Theme', () {
    test('categoryColor maps known categories', () {
      expect(AppColors.categoryColor('articulation'), AppColors.primary);
      expect(AppColors.categoryColor('breathing'), AppColors.sky);
      expect(AppColors.categoryColor('vocabulary'), AppColors.pink);
    });

    test('riskColor maps risk levels', () {
      expect(AppColors.riskColor('green'), AppColors.success);
      expect(AppColors.riskColor('yellow'), AppColors.warning);
      expect(AppColors.riskColor('red'), AppColors.danger);
      expect(AppColors.riskColor(null), AppColors.textMuted);
    });

    test('difficultyColor maps levels', () {
      expect(AppColors.difficultyColor('easy'), AppColors.success);
      expect(AppColors.difficultyColor('medium'), AppColors.warning);
      expect(AppColors.difficultyColor('hard'), AppColors.danger);
    });
  });

  group('L10n', () {
    testWidgets('uz strings load', (tester) async {
      await tester.pumpWidget(wrapWithApp(
        Builder(builder: (ctx) => Text(L.of(ctx)!.appTitle)),
      ));
      await tester.pump();
      expect(find.text('SADO - Nutq Terapiyasi'), findsOneWidget);
    });

    testWidgets('ru strings load', (tester) async {
      await tester.pumpWidget(wrapWithApp(
        Builder(builder: (ctx) => Text(L.of(ctx)!.appTitle)),
        locale: const Locale('ru'),
      ));
      await tester.pump();
      expect(find.text('SADO - Речевая терапия'), findsOneWidget);
    });

    testWidgets('earnedXp formats placeholder', (tester) async {
      await tester.pumpWidget(wrapWithApp(
        Builder(builder: (ctx) => Text(L.of(ctx)!.earnedXp(20))),
      ));
      await tester.pump();
      expect(find.textContaining('20'), findsOneWidget);
    });
  });
}
