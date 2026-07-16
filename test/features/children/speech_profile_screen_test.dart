import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/domain/speech_profile/phoneme_mastery.dart';
import 'package:sado_mobile/features/children/speech_profile_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

GoRouter _stubRouter() {
  return GoRouter(
    initialLocation: '/children/c-1/speech-profile',
    routes: [
      GoRoute(
        path: '/children/:id/speech-profile',
        builder: (_, state) => SpeechProfileScreen(
          childId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/children/:id',
        builder: (_, state) =>
            Scaffold(body: Text('child-${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/children/:id/phonemes/:phoneme',
        builder: (_, state) => Scaffold(
          body: Text(
              'drill-${state.pathParameters['id']}-${state.pathParameters['phoneme']}'),
        ),
      ),
      GoRoute(
        path: '/exercises',
        builder: (_, __) => const Scaffold(body: Text('exercises-stub')),
      ),
    ],
  );
}

Widget _wrap({
  required AsyncValue<SpeechProfile> state,
  Completer<SpeechProfile>? loadingCompleter,
  String childId = 'c-1',
}) {
  return ProviderScope(
    overrides: [
      speechProfileProvider(childId).overrideWith((ref) async {
        if (state is AsyncError) {
          // ignore: only_throw_errors
          throw (state as AsyncError).error;
        }
        if (state is AsyncLoading) {
          final c = loadingCompleter ?? Completer<SpeechProfile>();
          return c.future;
        }
        return (state as AsyncData).value as SpeechProfile;
      }),
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
      routerConfig: _stubRouter(),
    ),
  );
}

void main() {
  late Directory hiveDir;
  setUpAll(() {
    hiveDir =
        Directory.systemTemp.createTempSync('sado_speech_profile_test_');
    Hive.init(hiveDir.path);
  });
  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  group('SpeechProfileScreen', () {
    testWidgets('shows shimmer placeholders while loading', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final completer = Completer<SpeechProfile>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete(const SpeechProfile.empty());
        }
      });

      await tester.pumpWidget(_wrap(
        state: const AsyncValue.loading(),
        loadingCompleter: completer,
      ));
      await tester.pump();

      // Loading state surfaces a Semantics anchor so screen readers
      // don't see a blank screen.
      expect(
        find.bySemanticsLabel('Nutq profili tayyorlanmoqda…'),
        findsOneWidget,
      );
    });

    testWidgets('renders the empty state with the start-exercise CTA',
        (tester) async {
      await tester.pumpWidget(_wrap(
        state: const AsyncValue.data(SpeechProfile.empty()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Hozircha tahlil qilingan tovushlar yo\'q'),
          findsOneWidget);
      expect(find.text('Mashqni boshlash'), findsOneWidget);
    });

    testWidgets(
        'renders the error state with a localized retry CTA when the '
        'provider throws', (tester) async {
      await tester.pumpWidget(_wrap(
        state: AsyncValue.error('boom', StackTrace.empty),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Nutq profilini yuklab bo\'lmadi'),
        findsOneWidget,
      );
      expect(find.text('Qayta urinish'), findsOneWidget);
    });

    testWidgets(
        'with data renders the overall accuracy hero, the mastery grid '
        'and the focus-area card', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profile = SpeechProfile(
        phonemes: const [
          PhonemeMastery(
              phoneme: 'r', sampleCount: 5, weakCount: 4, accuracy: 0.20),
          PhonemeMastery(
              phoneme: 'sh', sampleCount: 4, weakCount: 2, accuracy: 0.50),
          PhonemeMastery(
              phoneme: 'k', sampleCount: 3, weakCount: 0, accuracy: 0.95),
        ],
        assessmentCount: 12,
        analysedCount: 10,
      );

      await tester.pumpWidget(_wrap(state: AsyncValue.data(profile)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Allow the tween animations time to settle.
      await tester.pump(const Duration(milliseconds: 800));

      // Hero: overall accuracy %, derived from average of [0.2, 0.5, 0.95]
      // ≈ 0.55 → 55%.
      expect(find.text('55%'), findsOneWidget);
      expect(find.text('Umumiy o\'zlashtirish'), findsOneWidget);

      // Focus area card surfaces the struggling phoneme.
      expect(find.text('Diqqat qiling'), findsOneWidget);

      // Mastered card surfaces the green-band phoneme.
      expect(find.text('Mukammal tovushlar'), findsOneWidget);

      // Window footer reflects analysed/total denominators.
      expect(
        find.text('Oxirgi 10 ta tahlilning 12 tasidan'),
        findsOneWidget,
      );
    });

    testWidgets(
        'tapping a struggling phoneme chip routes into the per-phoneme '
        'drill so parents can drill straight from the bucket card',
        (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profile = SpeechProfile(
        phonemes: const [
          PhonemeMastery(
              phoneme: 'r', sampleCount: 5, weakCount: 4, accuracy: 0.20),
        ],
        assessmentCount: 4,
        analysedCount: 4,
      );

      await tester.pumpWidget(_wrap(state: AsyncValue.data(profile)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 800));

      // Tap the chip text inside the focus-area card.
      await tester.ensureVisible(find.text('r').last);
      await tester.tap(find.text('r').last);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.text('drill-c-1-r'), findsOneWidget);
    });
  });

  group('SpeechProfileEntryCard', () {
    testWidgets('renders the title, subtitle and a chevron affordance',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
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
            home: const Scaffold(
              body: SpeechProfileEntryCard(childId: 'c-1'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Nutq profili'), findsOneWidget);
      expect(
        find.text(
            'Bola qaysi tovushlarni o\'zlashtirgan va qaysilari ustida ishlash kerakligini ko\'ring'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });
}
