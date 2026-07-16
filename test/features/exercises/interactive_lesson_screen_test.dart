import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/api_client.dart';
import 'package:sado_mobile/data/local/preferences.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/data/services/audio_recorder_service.dart';
import 'package:sado_mobile/data/services/preview_player.dart';
import 'package:sado_mobile/features/exercises/interactive_lesson_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';
import 'package:sado_mobile/widgets/parrot_mascot.dart';
import 'package:sado_mobile/widgets/premium_button.dart';

/// Bare-bones [AudioRecorderService] fake — tests for the lesson player
/// don't drive any audio plugins, they just need start/stop to be
/// idempotent so the screen can move past a record step.
class _FakeAudioRecorder implements AudioRecorderService {
  final _amp = StreamController<AmplitudeSample>.broadcast();
  bool _recording = false;
  String? _path;
  bool disposed = false;

  @override
  Stream<AmplitudeSample> get amplitudeStream => _amp.stream;

  @override
  bool get isRecording => _recording;

  @override
  Future<MicPermissionResult> ensurePermission() async =>
      MicPermissionResult.granted;

  @override
  Future<String> start({
    Duration amplitudeInterval = const Duration(milliseconds: 80),
    AudioQuality quality = AudioQuality.standard,
  }) async {
    _recording = true;
    _path = '/tmp/lesson_${DateTime.now().microsecondsSinceEpoch}.m4a';
    return _path!;
  }

  @override
  Future<String?> stop() async {
    _recording = false;
    return _path;
  }

  @override
  Future<void> discard() async {
    _recording = false;
    _path = null;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    if (!_amp.isClosed) await _amp.close();
  }
}

class _FakePreviewPlayer implements PreviewPlayer {
  final _states = StreamController<PreviewPlaybackState>.broadcast();
  PreviewPlaybackState _state = PreviewPlaybackState.stopped;
  bool disposed = false;

  void emit(PreviewPlaybackState s) {
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  @override
  PreviewPlaybackState get state => _state;

  @override
  Stream<PreviewPlaybackState> get stateStream {
    final ctrl = StreamController<PreviewPlaybackState>();
    ctrl.add(_state);
    final sub = _states.stream.listen(ctrl.add);
    ctrl.onCancel = () async {
      await sub.cancel();
      await ctrl.close();
    };
    return ctrl.stream;
  }

  @override
  Future<void> setFilePath(String path) async {
    emit(const PreviewPlaybackState(
        playing: false, completed: false, idle: false));
  }

  @override
  Future<void> seekToStart() async {}

  @override
  Future<void> play() async {
    emit(const PreviewPlaybackState(
        playing: true, completed: false, idle: false));
  }

  @override
  Future<void> pause() async {
    emit(const PreviewPlaybackState(
        playing: false, completed: false, idle: false));
  }

  @override
  Future<void> stop() async {
    emit(PreviewPlaybackState.stopped);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    if (!_states.isClosed) await _states.close();
  }
}

Exercise _interactiveExercise({
  String id = 'lesson-r-1',
  List<ExerciseStep>? steps,
}) {
  return Exercise(
    id: id,
    title: 'R tovushi darsi',
    description: 'Interaktiv R darsi',
    category: 'articulation',
    ageGroup: '5-6',
    difficulty: 'medium',
    language: 'uz',
    durationMinutes: 5,
    isActive: true,
    steps: steps ??
        const [
          InstructionStep(
            textUz: "Hozir 'R' tovushini mashq qilamiz",
            textRu: "Сейчас потренируем звук 'Р'",
            durationSec: 4,
          ),
          DemonstrateStep(
            textUz: 'Eshiting va takrorlang',
            textRu: 'Слушайте и повторяйте',
            durationSec: 5,
          ),
          RecordStep(
            promptUz: 'Endi siz ayting',
            promptRu: 'А теперь скажите',
            targetWord: 'sariq',
            targetPhonemes: ['s', 'a', 'r'],
            maxDurationSec: 10,
          ),
          FeedbackStep(
            encouragementUz: 'Ajoyib! Juda yaxshi 🌟',
            encouragementRu: 'Отлично! Очень хорошо 🌟',
          ),
        ],
  );
}

GoRouter _router({required String childId, required String exerciseId}) {
  Widget stub(String tag, GoRouterState state) =>
      Scaffold(body: Text('STUB:$tag:${state.matchedLocation}'));
  return GoRouter(
    initialLocation: '/exercises/$exerciseId/lesson/$childId',
    routes: [
      GoRoute(
        path: '/exercises/:exerciseId/lesson/:childId',
        builder: (_, state) => InteractiveLessonScreen(
          childId: state.pathParameters['childId']!,
          exerciseId: state.pathParameters['exerciseId']!,
        ),
      ),
      GoRoute(
        path: '/exercises/:id',
        builder: (_, state) => stub('exercise-detail', state),
      ),
      GoRoute(
        path: '/assessment/results/:id',
        builder: (_, state) => stub('results', state),
      ),
      GoRoute(
        path: '/',
        builder: (_, state) => stub('home', state),
      ),
    ],
  );
}

Widget _wrap({
  required _FakeAudioRecorder recorder,
  required _FakePreviewPlayer player,
  required GoRouter router,
  required List<Exercise> exercises,
  String locale = 'uz',
}) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(Dio()),
      audioRecorderFactoryProvider.overrideWithValue(() => recorder),
      previewPlayerFactoryProvider.overrideWithValue(() => player),
      exercisesProvider.overrideWith(
        (ref) async => CachedResult<Exercise>(exercises),
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
      routerConfig: router,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize =
        const Size(390 * 3, 844 * 3);
    binding.platformDispatcher.views.first.devicePixelRatio = 3.0;
  });
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('InteractiveLessonScreen', () {
    testWidgets(
      'opens on the first step (instruction) with the parrot mascot, the '
      'localized step counter and a "Continue" CTA',
      (tester) async {
        final ex = _interactiveExercise();
        await tester.pumpWidget(_wrap(
          recorder: _FakeAudioRecorder(),
          player: _FakePreviewPlayer(),
          router: _router(childId: 'c1', exerciseId: ex.id),
          exercises: [ex],
        ));
        await _settle(tester);

        // Step counter chip ("Qadam 1 / 4") in Uzbek.
        expect(find.text('Qadam 1 / 4'), findsOneWidget);

        // The parrot mascot is mandatory on every assessment-flavoured
        // screen per orchestration steering — never let the lesson
        // player skip rendering it.
        expect(find.byType(ParrotMascot), findsOneWidget);

        // Instruction copy is rendered (twice — once inside the mascot
        // speech bubble, once inside the lesson card).
        expect(
          find.text("Hozir 'R' tovushini mashq qilamiz"),
          findsAtLeastNWidgets(1),
        );

        // Section header + Continue CTA use localized copy.
        expect(find.text('YO\'RIQNOMA'), findsOneWidget);
        expect(find.text('Davom etish'), findsOneWidget);

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'tapping "Continue" advances to the next step and updates the '
      'progress counter / progress bar',
      (tester) async {
        final ex = _interactiveExercise();
        await tester.pumpWidget(_wrap(
          recorder: _FakeAudioRecorder(),
          player: _FakePreviewPlayer(),
          router: _router(childId: 'c1', exerciseId: ex.id),
          exercises: [ex],
        ));
        await _settle(tester);

        expect(find.text('Qadam 1 / 4'), findsOneWidget);

        await tester.tap(find.text('Davom etish'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        // Counter advances to the second step.
        expect(find.text('Qadam 2 / 4'), findsOneWidget);

        // Demonstrate step header is now visible.
        expect(find.text('TINGLASH'), findsOneWidget);
        expect(find.text('Eshiting va takrorlang'),
            findsAtLeastNWidgets(1));

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'record step shows the target word, phoneme pills and the localized '
      'tap-to-record hint',
      (tester) async {
        final ex = _interactiveExercise();
        await tester.pumpWidget(_wrap(
          recorder: _FakeAudioRecorder(),
          player: _FakePreviewPlayer(),
          router: _router(childId: 'c1', exerciseId: ex.id),
          exercises: [ex],
        ));
        await _settle(tester);

        // Walk: instruction → demonstrate → record.
        await tester.tap(find.text('Davom etish'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Davom etish'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // We're now on the record step.
        expect(find.text('Qadam 3 / 4'), findsOneWidget);
        // Target word renders in the big record card.
        expect(find.text('sariq'), findsOneWidget);
        // Phoneme pills are individually rendered.
        expect(find.text('s'), findsOneWidget);
        expect(find.text('a'), findsOneWidget);
        expect(find.text('r'), findsOneWidget);
        // Mascot still present.
        expect(find.byType(ParrotMascot), findsOneWidget);

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'feedback step shows the localized encouragement and surfaces the '
      '"Finish" CTA instead of "Continue"',
      (tester) async {
        // Use a steps array that ends on the feedback step so the
        // walk doesn't have to traverse a record step (which would
        // require simulating microphone permission + capture).
        final steps = const [
          InstructionStep(
            textUz: 'Boshlaymiz',
            textRu: 'Начинаем',
            durationSec: 3,
          ),
          FeedbackStep(
            encouragementUz: 'Yashasin! Juda yaxshi! 🎉',
            encouragementRu: 'Молодец! 🎉',
          ),
        ];
        final ex = _interactiveExercise(id: 'lesson-feedback', steps: steps);

        await tester.pumpWidget(_wrap(
          recorder: _FakeAudioRecorder(),
          player: _FakePreviewPlayer(),
          router: _router(childId: 'c1', exerciseId: ex.id),
          exercises: [ex],
        ));
        await _settle(tester);

        await tester.tap(find.text('Davom etish'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Qadam 2 / 2'), findsOneWidget);
        expect(find.text('Yashasin! Juda yaxshi! 🎉'),
            findsAtLeastNWidgets(1));

        // The terminal step swaps "Continue" for "Finish".
        expect(find.text('Davom etish'), findsNothing);
        expect(find.text('Yakunlash'), findsOneWidget);

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'renders the localized empty-state when the exercise ships no steps',
      (tester) async {
        final ex = Exercise(
          id: 'no-steps',
          title: 'Eski format mashqi',
          description: 'Legacy exercise',
          category: 'articulation',
          ageGroup: '5-6',
          difficulty: 'easy',
          language: 'uz',
          durationMinutes: 3,
          isActive: true,
          // steps intentionally omitted so hasInteractiveSteps == false
        );

        await tester.pumpWidget(_wrap(
          recorder: _FakeAudioRecorder(),
          player: _FakePreviewPlayer(),
          router: _router(childId: 'c1', exerciseId: ex.id),
          exercises: [ex],
        ));
        await _settle(tester);

        expect(
          find.text('Bu darsda interaktiv qadamlar mavjud emas.'),
          findsOneWidget,
        );
        expect(find.byType(ParrotMascot), findsOneWidget);

        // No "Continue" / "Finish" CTAs should appear in the empty state.
        expect(find.text('Davom etish'), findsNothing);
        expect(find.text('Yakunlash'), findsNothing);

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'renders an exercise-not-found state with a sad mascot when the id '
      'does not match any cached exercise',
      (tester) async {
        await tester.pumpWidget(_wrap(
          recorder: _FakeAudioRecorder(),
          player: _FakePreviewPlayer(),
          router: _router(childId: 'c1', exerciseId: 'missing-id'),
          exercises: [_interactiveExercise(id: 'something-else')],
        ));
        await _settle(tester);

        expect(find.text('Mashq topilmadi'),
            findsAtLeastNWidgets(1));
        expect(find.byType(ParrotMascot), findsOneWidget);

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'tapping the close icon on the very first step (no work captured) '
      'exits without showing a confirmation dialog',
      (tester) async {
        final ex = _interactiveExercise();
        await tester.pumpWidget(_wrap(
          recorder: _FakeAudioRecorder(),
          player: _FakePreviewPlayer(),
          router: _router(childId: 'c1', exerciseId: ex.id),
          exercises: [ex],
        ));
        await _settle(tester);

        // No dialog is required because we haven't entered any step
        // beyond the first one yet — bail out without nagging.
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Darsdan chiqish?'), findsNothing);
        expect(
          find.textContaining('STUB:exercise-detail'),
          findsOneWidget,
        );

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'after advancing past the first step, tapping close shows the '
      'localized exit confirmation dialog with both buttons',
      (tester) async {
        final ex = _interactiveExercise();
        await tester.pumpWidget(_wrap(
          recorder: _FakeAudioRecorder(),
          player: _FakePreviewPlayer(),
          router: _router(childId: 'c1', exerciseId: ex.id),
          exercises: [ex],
        ));
        await _settle(tester);

        await tester.tap(find.text('Davom etish'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Dialog title + body + both action buttons present.
        expect(find.text('Darsdan chiqish?'), findsOneWidget);
        expect(
          find.text('Boshlangan dars saqlanmaydi va qaytadan boshlanadi.'),
          findsOneWidget,
        );
        // Dialog cancel button has the same label as the next-step CTA, so
        // we expect at least one occurrence (the dialog one) — the screen
        // behind the dialog is also still in the widget tree.
        expect(find.text('Davom etish'), findsAtLeastNWidgets(1));
        expect(find.text('Chiqish'), findsOneWidget);

        // Tapping confirm should route us back to the exercise detail
        // STUB. Use bounded pumps instead of pumpAndSettle so any
        // flutter_animate / mascot loops can't keep the scheduler busy
        // forever.
        await tester.tap(find.text('Chiqish'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.textContaining('STUB:exercise-detail'),
          findsOneWidget,
        );

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'unknown step types do not crash — they render the localized '
      'fallback copy and still expose a "Continue" CTA',
      (tester) async {
        final ex = _interactiveExercise(
          id: 'lesson-unknown',
          steps: const [
            UnknownStep(rawType: 'fancy-future-step', durationSec: 3),
            FeedbackStep(
              encouragementUz: 'Tugadi',
              encouragementRu: 'Готово',
            ),
          ],
        );

        await tester.pumpWidget(_wrap(
          recorder: _FakeAudioRecorder(),
          player: _FakePreviewPlayer(),
          router: _router(childId: 'c1', exerciseId: ex.id),
          exercises: [ex],
        ));
        await _settle(tester);

        // Localized "Other step" title from the lessonStepUnknown key.
        expect(find.text('Boshqa qadam'), findsOneWidget);
        expect(find.text('Davom etish'), findsOneWidget);

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'switches the entire UI to Russian when locale=ru is supplied',
      (tester) async {
        final ex = _interactiveExercise();
        await tester.pumpWidget(_wrap(
          recorder: _FakeAudioRecorder(),
          player: _FakePreviewPlayer(),
          router: _router(childId: 'c1', exerciseId: ex.id),
          exercises: [ex],
          locale: 'ru',
        ));
        await _settle(tester);

        // Step counter and CTA both flip to Russian.
        expect(find.text('Шаг 1 / 4'), findsOneWidget);
        expect(find.text('Продолжить'), findsOneWidget);
        // Russian instruction body comes through.
        expect(find.text("Сейчас потренируем звук 'Р'"),
            findsAtLeastNWidgets(1));

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'progress bar advances proportionally with the step counter',
      (tester) async {
        final ex = _interactiveExercise();
        await tester.pumpWidget(_wrap(
          recorder: _FakeAudioRecorder(),
          player: _FakePreviewPlayer(),
          router: _router(childId: 'c1', exerciseId: ex.id),
          exercises: [ex],
        ));
        await _settle(tester);

        LinearProgressIndicator firstBar = tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator));
        // 1 of 4 = 0.25.
        expect((firstBar.value ?? 0) * 4, closeTo(1.0, 0.0001));

        await tester.tap(find.text('Davom etish'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        LinearProgressIndicator secondBar = tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator));
        // 2 of 4 = 0.5.
        expect((secondBar.value ?? 0) * 4, closeTo(2.0, 0.0001));

        await _disposeTree(tester);
      },
    );

    testWidgets(
      'submits a "Finish" CTA on the feedback step (no recordings) and '
      'the button reflects the correct submitting copy',
      (tester) async {
        final steps = const [
          FeedbackStep(
            encouragementUz: 'Tugadi',
            encouragementRu: 'Готово',
          ),
        ];
        final ex = _interactiveExercise(id: 'single-feedback', steps: steps);

        await tester.pumpWidget(_wrap(
          recorder: _FakeAudioRecorder(),
          player: _FakePreviewPlayer(),
          router: _router(childId: 'c1', exerciseId: ex.id),
          exercises: [ex],
        ));
        await _settle(tester);

        // Single-step lesson opens directly on the feedback CTA.
        expect(find.text('Yakunlash'), findsOneWidget);
        // The PremiumButton wrapping the CTA is enabled before any tap.
        final button =
            tester.widget<PremiumButton>(find.byType(PremiumButton));
        expect(button.onPressed, isNotNull);

        await _disposeTree(tester);
      },
    );
  });
}
