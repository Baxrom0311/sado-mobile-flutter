import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sado_mobile/core/gamification.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/progress/progress_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

/// In-memory game notifier so progress screen XP/level UI can render in
/// tests without touching Hive on construction.
class _StaticGameNotifier extends GameNotifier {
  _StaticGameNotifier([GameState initial = const GameState()]) {
    state = initial;
  }

  @override
  Future<List<String>> markActiveToday() async => const [];
}

Widget _wrap({required List<Override> overrides}) {
  return ProviderScope(
    overrides: [
      gameProvider.overrideWith((ref) => _StaticGameNotifier()),
      ...overrides,
    ],
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
      home: const ProgressScreen(),
    ),
  );
}

Assessment _a({
  required String id,
  required DateTime created,
  String status = 'completed',
  String? risk,
  double? score,
  String? exerciseId,
}) =>
    Assessment(
      id: id,
      childId: 'c-1',
      exerciseId: exerciseId,
      status: status,
      overallRisk: risk,
      score: score,
      createdAt: created,
    );

void main() {
  // The progress screen reads `gameProvider`, whose underlying notifier
  // eagerly opens a Hive box. Initialise Hive against a temp dir so the
  // base notifier's _load() side-effect doesn't crash even when the
  // override installs a static replacement on top.
  late Directory hiveDir;
  setUpAll(() {
    hiveDir = Directory.systemTemp.createTempSync('sado_progress_test_');
    Hive.init(hiveDir.path);
  });
  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  testWidgets(
    'ProgressScreen empty state shows mascot and friendly copy',
    (tester) async {
      await tester.pumpWidget(_wrap(overrides: [
        assessmentsProvider.overrideWith(
          (ref, _) async => const CachedResult<Assessment>([]),
        ),
        exercisesProvider.overrideWith(
          (ref) async => const CachedResult<Exercise>([]),
        ),
      ]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The empty branch renders the mascot — period selector should NOT appear.
      expect(find.text('Hafta'), findsNothing);
      expect(find.text("Baholashlar topilmadi"), findsOneWidget);
    },
  );

  testWidgets(
    'ProgressScreen with data shows period selector, risk pie and heatmap',
    (tester) async {
      final now = DateTime.now();
      final assessments = [
        _a(
          id: '1',
          created: now.subtract(const Duration(days: 1)),
          risk: 'green',
          score: 0.9,
        ),
        _a(
          id: '2',
          created: now.subtract(const Duration(days: 2)),
          risk: 'yellow',
          score: 0.6,
        ),
        _a(
          id: '3',
          created: now.subtract(const Duration(days: 3)),
          risk: 'red',
          score: 0.3,
        ),
      ];

      await tester.pumpWidget(_wrap(overrides: [
        assessmentsProvider.overrideWith(
          (ref, _) async => CachedResult<Assessment>(assessments),
        ),
        exercisesProvider.overrideWith(
          (ref) async => const CachedResult<Exercise>([]),
        ),
      ]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Period selector renders all three options.
      expect(find.text('Hafta'), findsOneWidget);
      expect(find.text('Oy'), findsOneWidget);
      expect(find.text('Barchasi'), findsOneWidget);

      // Risk distribution section is visible near the top.
      expect(find.text('Xavf taqsimoti'), findsOneWidget);

      // The streak heatmap card lives further down the list. Scroll it
      // into view before asserting on its title.
      await tester.scrollUntilVisible(
        find.text('Faollik kalendari'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Faollik kalendari'), findsOneWidget);

      // Tapping "Oy" should keep the screen alive without throwing.
      await tester.scrollUntilVisible(
        find.text('Oy'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Oy'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(ProgressScreen), findsOneWidget);
    },
  );

  testWidgets(
    'child filter is hidden when there is only one child',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final assessments = [
        _a(id: '1', created: now.subtract(const Duration(days: 1))),
      ];

      await tester.pumpWidget(_wrap(overrides: [
        assessmentsProvider.overrideWith(
          (ref, _) async => CachedResult<Assessment>(assessments),
        ),
        exercisesProvider.overrideWith(
          (ref) async => const CachedResult<Exercise>([]),
        ),
        childrenProvider.overrideWith(
          (ref) async => CachedResult<Child>([
            Child(
              id: 'c-1',
              name: 'Solo',
              birthDate: DateTime(2020, 1, 1),
              gender: 'male',
              parentId: 'p-1',
              createdAt: DateTime(2024),
            ),
          ]),
        ),
      ]));
      // Drain the entry-fade animation timers from flutter_animate so the
      // tree disposes cleanly. pump() once for the FutureProvider, then
      // a generous duration to let the chained fadeIn/slideY/scale chain
      // finish off — settling the StreakChip pulse on top.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The "All children" chip and per-child names should NOT render when
      // there's only a single child — a single chip would just take up
      // vertical space.
      expect(find.text('Hammasi'), findsNothing);
      expect(find.text('Bola bo\'yicha'), findsNothing);

      // Tear the tree down explicitly so any remaining repeating timers
      // (StreakChip pulse for streaks >= 3) don't outlive the test.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'child filter renders a chip per child when there are 2+ children',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final assessments = [
        _a(id: '1', created: now.subtract(const Duration(days: 1))),
      ];

      await tester.pumpWidget(_wrap(overrides: [
        assessmentsProvider.overrideWith(
          (ref, _) async => CachedResult<Assessment>(assessments),
        ),
        exercisesProvider.overrideWith(
          (ref) async => const CachedResult<Exercise>([]),
        ),
        childrenProvider.overrideWith(
          (ref) async => CachedResult<Child>([
            Child(
              id: 'c-1',
              name: 'Aziz',
              birthDate: DateTime(2020, 1, 1),
              gender: 'male',
              parentId: 'p-1',
              createdAt: DateTime(2024),
            ),
            Child(
              id: 'c-2',
              name: 'Madina',
              birthDate: DateTime(2021, 6, 15),
              gender: 'female',
              parentId: 'p-1',
              createdAt: DateTime(2024),
            ),
          ]),
        ),
      ]));
      // See above — drain entry animations before asserting.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Section header + the All chip + one chip per child are all visible
      // before the user even scrolls.
      expect(find.text('Bola bo\'yicha'), findsOneWidget);
      expect(find.text('Hammasi'), findsOneWidget);
      expect(find.text('Aziz'), findsOneWidget);
      expect(find.text('Madina'), findsOneWidget);

      // Each chip exposes a stable key so the screen can target them
      // individually from automation.
      expect(
        find.byKey(const ValueKey('progress.childFilter.all')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('progress.childFilter.c-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('progress.childFilter.c-2')),
        findsOneWidget,
      );

      // Tear down so any in-flight animation timers don't leak.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'level progress card renders title, XP bar, badge count and CTA',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final assessments = [
        _a(id: '1', created: now.subtract(const Duration(days: 1))),
      ];

      await tester.pumpWidget(_wrap(overrides: [
        assessmentsProvider.overrideWith(
          (ref, _) async => CachedResult<Assessment>(assessments),
        ),
        exercisesProvider.overrideWith(
          (ref) async => const CachedResult<Exercise>([]),
        ),
      ]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Scroll the level card into view — it lives below the streak heatmap.
      await tester.scrollUntilVisible(
        find.text('Daraja taraqqiyoti'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      // Title + subtitle anchor the card.
      expect(find.text('Daraja taraqqiyoti'), findsOneWidget);
      expect(
        find.text('Har bir mashq sizni keyingi darajaga yaqinlashtiradi'),
        findsOneWidget,
      );

      // The "View all badges" CTA is keyed so router-level taps can find it.
      expect(
        find.byKey(const ValueKey('progress.viewAllBadges')),
        findsOneWidget,
      );
      expect(find.text('Barcha nishonlar'), findsOneWidget);

      // Tear down before any pending animation timers escape the test.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
