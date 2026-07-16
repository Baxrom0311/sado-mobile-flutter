import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:sado_mobile/core/gamification.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/api_client.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/assessment/assessment_results_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

/// In-memory game notifier — keeps Hive untouched in widget tests.
class _StaticGameNotifier extends GameNotifier {
  _StaticGameNotifier();
  @override
  Future<List<String>> recordAssessment({
    required int totalAssessments,
    double? score,
  }) async =>
      const [];
}

/// Stub Dio that resolves GET /assessments/:id from a static map.
Dio _stubDio(Map<String, dynamic> assessmentJson) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: assessmentJson,
      ));
    },
  ));
  return dio;
}

/// Stub Dio that routes based on URL — distinguishes the `/analysis/{id}`
/// envelope from the parent `/assessments/{id}` call so analysis-section
/// tests can drive each one independently.
Dio _routedStubDio({
  required Map<String, dynamic> assessmentJson,
  required Map<String, dynamic> analysisJson,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      // The parent-safe analysis endpoint lives at the root of the v1
      // router as `/analysis/{assessment_id}`, NOT under
      // `/assessments/...`. Match both shapes (and the new "detailed"
      // path) so future therapist-tier UIs can share this stub.
      final path = options.path;
      final isAnalysis =
          path.startsWith('/analysis/') || path.endsWith('/analysis');
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: isAnalysis ? analysisJson : assessmentJson,
      ));
    },
  ));
  return dio;
}

Map<String, dynamic> _payload({
  String id = 'a-1',
  String risk = 'green',
  double score = 0.92,
  String? audioPath,
}) =>
    {
      'id': id,
      'child_id': 'c1',
      'exercise_id': 'e1',
      'status': 'completed',
      'overall_risk': risk,
      'score': score,
      if (audioPath != null) 'audio_path': audioPath,
      'created_at': DateTime.utc(2025, 6, 1).toIso8601String(),
    };

GoRouter _stubRouter(String assessmentId) {
  return GoRouter(
    initialLocation: '/assessment/results/$assessmentId',
    routes: [
      GoRoute(
        path: '/assessment/results/:id',
        builder: (_, state) => AssessmentResultsScreen(
          assessmentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('home-stub')),
      ),
      GoRoute(
        path: '/exercises',
        builder: (_, __) => const Scaffold(body: Text('exercises-stub')),
      ),
      GoRoute(
        path: '/progress',
        builder: (_, __) => const Scaffold(body: Text('progress-stub')),
      ),
    ],
  );
}

Widget _wrap({
  required Map<String, dynamic> payload,
  String locale = 'uz',
  Map<String, dynamic>? analysis,
}) {
  final id = payload['id'] as String;
  final dio = analysis == null
      ? _stubDio(payload)
      : _routedStubDio(assessmentJson: payload, analysisJson: analysis);
  return ProviderScope(
    overrides: [
      // Returns our canned assessment for any GET.
      dioProvider.overrideWithValue(dio),
      gameProvider.overrideWith((ref) => _StaticGameNotifier()),
      // The results screen reads this to compute the badge target. Empty
      // list is sufficient — the assertions don't depend on the count.
      assessmentsProvider.overrideWith(
        (ref, _) async => const CachedResult<Assessment>([]),
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
      locale: Locale(locale),
      routerConfig: _stubRouter(id),
    ),
  );
}

void main() {
  // GameNotifier still tries to open a Hive box on construction, even when
  // overridden — point Hive at a temp dir so the load is harmless.
  late Directory hiveDir;
  setUpAll(() {
    hiveDir = Directory.systemTemp.createTempSync('sado_results_test_');
    Hive.init(hiveDir.path);
  });
  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  // Capture all Clipboard.setData calls so we can assert the share button
  // copied the right summary.
  final clipboardWrites = <String>[];
  setUp(() {
    clipboardWrites.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map?;
        if (args != null && args['text'] is String) {
          clipboardWrites.add(args['text'] as String);
        }
      }
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('AssessmentResultsScreen', () {
    testWidgets('renders animated score, risk badge and the three CTAs',
        (tester) async {
      await tester
          .pumpWidget(_wrap(payload: _payload(score: 0.92, risk: 'green')));
      // Resolve the FutureProvider, then let the score + XP animations
      // settle. We pump in chunks rather than `pumpAndSettle` because
      // flutter_animate may keep timers alive on confetti.
      await tester.pump(); // first frame
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 500));

      // The animated counter should have settled at the final percentage.
      expect(find.text('92%'), findsOneWidget);

      // Localized risk label (uz).
      expect(find.text('Xavf past'), findsWidgets);

      // The three primary CTAs from the brief.
      expect(find.byKey(const ValueKey('results.tryAnother')), findsOneWidget);
      expect(find.byKey(const ValueKey('results.share')), findsOneWidget);
      expect(find.byKey(const ValueKey('results.home')), findsOneWidget);

      // XP earned card (animated counter ends at 20). Scroll into view first.
      await tester.scrollUntilVisible(
        find.text('20 XP qozondingiz!'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('20 XP qozondingiz!'), findsOneWidget);
    });

    testWidgets('share button copies a localized summary to the clipboard',
        (tester) async {
      await tester
          .pumpWidget(_wrap(payload: _payload(score: 0.6, risk: 'yellow')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1000));

      // The share button lives below the fold on a 600-pixel test viewport.
      await tester.ensureVisible(find.byKey(const ValueKey('results.share')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('results.share')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Snackbar shows the localized confirmation.
      expect(find.text('Natija nusxalandi'), findsOneWidget);

      // The clipboard payload contains the percent + risk label.
      expect(clipboardWrites, hasLength(1));
      final copied = clipboardWrites.single;
      expect(copied, contains('60%'));
      expect(copied, contains('Xavf o\'rtacha'));
      expect(copied, contains('SADO'));

      // Wait for the snackbar's auto-dismiss timer (2s) so it doesn't
      // outlive the widget tree and trigger a "pending timer" failure.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('try-another navigates to the exercises screen',
        (tester) async {
      await tester.pumpWidget(_wrap(payload: _payload()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1000));

      await tester
          .ensureVisible(find.byKey(const ValueKey('results.tryAnother')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('results.tryAnother')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('exercises-stub'), findsOneWidget);
    });

    testWidgets('home button returns to the dashboard', (tester) async {
      await tester.pumpWidget(_wrap(payload: _payload()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1000));

      await tester.ensureVisible(find.byKey(const ValueKey('results.home')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('results.home')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('home-stub'), findsOneWidget);
    });

    testWidgets(
      'renders the "Your recording" playback section when audio_path is set',
      (tester) async {
        await tester.pumpWidget(_wrap(
          payload: _payload(audioPath: '/storage/recordings/abc.m4a'),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 1000));

        // Section title is rendered before the player so parents see what
        // they are about to play. Localized via .arb (uz).
        expect(find.text('Sizning yozuvingiz'), findsOneWidget);

        // Player widget itself is mounted with a stable key so other
        // screens / tests can target it.
        expect(
          find.byKey(const ValueKey('results.recordingPlayer')),
          findsOneWidget,
        );

        // Drain any pending audio-plugin timers so the test exits cleanly.
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'omits the playback section when the API did not return an audio_path',
      (tester) async {
        await tester.pumpWidget(_wrap(payload: _payload()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 1000));

        // No section title and no player — keeps the layout calm when the
        // server didn't persist a recording (legacy assessment, missing
        // upload, etc.).
        expect(find.text('Sizning yozuvingiz'), findsNothing);
        expect(
          find.byKey(const ValueKey('results.recordingPlayer')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'renders the AI analysis section when the analyzer returns phoneme '
      'scores, fluency stats and recommendations',
      (tester) async {
        await tester.pumpWidget(_wrap(
          payload: _payload(),
          analysis: {
            'assessment_id': 'a-1',
            'overall_score': 92.0,
            'risk_level': 'green',
            'model_version': 'sado-v1',
            'processing_time_ms': 420,
            'phoneme_scores': [
              {'phoneme': 's', 'accuracy': 0.92, 'error_type': null},
              {
                'phoneme': 'r',
                'accuracy': 0.55,
                'error_type': 'distortion',
              },
            ],
            'fluency_score': {
              'rate': 3.2,
              'pause_ratio': 0.18,
              'repetitions': 1,
            },
            'recommendations': [
              {
                'type': 'home_practice',
                'message': 'Uyda har kuni 5 daqiqa mashq qiling',
                'priority': 'high',
              },
              {
                'type': 'exercise',
                'message': '"R" tovushiga e\'tibor bering',
                'priority': 'medium',
              },
            ],
          },
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 1000));

        // Localized phoneme breakdown card title (uz).
        await tester.scrollUntilVisible(
          find.text('Tovushlar tahlili'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Tovushlar tahlili'), findsOneWidget);

        // Both phoneme rows render with their accuracy percent.
        expect(find.text('92%'), findsWidgets);
        expect(find.text('55%'), findsOneWidget);

        // Fluency card title (uz).
        await tester.scrollUntilVisible(
          find.text('Ravonlik'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Ravonlik'), findsOneWidget);

        // Recommendations card and the high-priority message land below.
        await tester.scrollUntilVisible(
          find.text('Tavsiyalar'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Tavsiyalar'), findsOneWidget);
        expect(
          find.text('Uyda har kuni 5 daqiqa mashq qiling'),
          findsOneWidget,
        );

        // Empty placeholder must NOT appear when real data is present.
        expect(
          find.byKey(const ValueKey('results.analysisEmpty')),
          findsNothing,
        );

        // Drain the cascading flutter_animate delays (up to 700ms) and
        // the per-phoneme TweenAnimationBuilder (700ms) so no timers
        // leak past teardown.
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets(
      'renders the friendly placeholder when the analyzer returned an '
      'empty envelope (analysis still warming up)',
      (tester) async {
        await tester.pumpWidget(_wrap(
          payload: _payload(),
          analysis: const <String, dynamic>{},
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 1000));

        // Friendly empty placeholder copy (uz) appears...
        await tester.scrollUntilVisible(
          find.text('Tahlil hozircha mavjud emas'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Tahlil hozircha mavjud emas'), findsOneWidget);

        // ...via the keyed placeholder so future screens can target it.
        expect(
          find.byKey(const ValueKey('results.analysisEmpty')),
          findsOneWidget,
        );
        // No production analysis section was rendered.
        expect(
          find.byKey(const ValueKey('results.analysisSection')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'against the real /analysis/{id} wire shape (production path) the '
      'screen renders transcript, weak-phonemes chips, derived fluency '
      'and synthesised recommendations',
      (tester) async {
        // Mirrors FastAPI's AssessmentAnalysisResponse exactly — one
        // assessment with two recordings, each carrying a
        // feature_summary like the mock speech analyzer produces.
        await tester.pumpWidget(_wrap(
          payload: _payload(),
          analysis: {
            'assessment_id': 'a-1',
            'overall_risk': 'green',
            'overall_confidence': 0.84,
            'status': 'completed',
            'completed_at': '2025-06-12T01:00:00Z',
            'results': [
              {
                'recording_id': 'rec-1',
                'risk_level': 'green',
                'confidence': 0.86,
                'transcript': 'olma non rahmat',
                'feature_summary': {
                  'duration_sec': 6.2,
                  'sample_rate': 16000,
                  'n_frames': 248,
                  'transcript_word_count': 3,
                  'voiced_ratio': 0.78,
                  'f0_mean': 245.1,
                  'f1_mean': 820.0,
                  'f2_mean': 1900.0,
                  'weakest_phonemes': ['r', 'sh'],
                },
                'model_name': 'mock-xgb-v1',
                'model_version': '0.1.0',
                'created_at': '2025-06-12T01:00:00Z',
              },
              {
                'recording_id': 'rec-2',
                'risk_level': 'yellow',
                'confidence': 0.72,
                'transcript': 'ona ota',
                'feature_summary': {
                  'duration_sec': 4.0,
                  'transcript_word_count': 2,
                  'voiced_ratio': 0.62,
                  'weakest_phonemes': ['k', 'r'],
                },
                'model_name': 'mock-xgb-v1',
                'model_version': '0.1.0',
                'created_at': '2025-06-12T01:00:30Z',
              },
            ],
          },
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 1000));

        // The first recording's transcript surfaces in the new
        // TranscriptCard with quoted styling.
        await tester.scrollUntilVisible(
          find.text('Bola nima dedi'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Bola nima dedi'), findsOneWidget);
        expect(find.text('olma non rahmat'), findsOneWidget);

        // Weak-phoneme chips: the union across both recordings,
        // deduped — `r` should appear exactly once even though it's in
        // both feature_summaries.
        await tester.scrollUntilVisible(
          find.text("E'tibor talab qiladigan tovushlar"),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text("E'tibor talab qiladigan tovushlar"),
          findsOneWidget,
        );
        expect(find.text('r'), findsOneWidget);
        expect(find.text('sh'), findsOneWidget);
        expect(find.text('k'), findsOneWidget);
        // Per-phoneme accuracy bars MUST NOT render — the parent-safe
        // endpoint never exposes scores, so PhonemeBreakdownCard
        // stays out of the tree.
        expect(find.text('Tovushlar tahlili'), findsNothing);

        // Derived fluency card (rate from word_count/duration,
        // pause_ratio from 1 - voiced_ratio).
        await tester.scrollUntilVisible(
          find.text('Ravonlik'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Ravonlik'), findsOneWidget);

        // Synthesised recommendations: one "practice" tip per top-three
        // weak phoneme + the consistency + celebrate generic tips.
        await tester.scrollUntilVisible(
          find.text('Tavsiyalar'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Tavsiyalar'), findsOneWidget);
        // The practice tip for the first weak phoneme renders verbatim
        // (the synthesizer interpolates the phoneme into the localized
        // template).
        expect(
          find.textContaining('"r" tovushini'),
          findsOneWidget,
        );

        // Empty placeholder must NOT appear when real data is present.
        expect(
          find.byKey(const ValueKey('results.analysisEmpty')),
          findsNothing,
        );

        // Drain animation timers so no asynchronous work leaks past
        // teardown.
        await tester.pump(const Duration(seconds: 2));
      },
    );
  });
}
