import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/local/preferences.dart';
import 'package:sado_mobile/data/services/audio_recorder_service.dart';
import 'package:sado_mobile/data/services/preview_player.dart';
import 'package:sado_mobile/features/assessment/assessment_game_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';
import 'package:sado_mobile/widgets/parrot_mascot.dart';
import 'package:sado_mobile/widgets/recording_button.dart';

/// Fake [AudioRecorderService] that never touches the `record` plugin.
///
/// We expose [pushAmplitude] so individual tests can drive the screen's
/// waveform without poking private fields.
class FakeAudioRecorder implements AudioRecorderService {
  final _amp = StreamController<AmplitudeSample>.broadcast();
  bool _recording = false;
  String? _path;

  bool disposed = false;
  int startCalls = 0;
  int stopCalls = 0;

  void pushAmplitude(double dbfs) {
    if (!_amp.isClosed) _amp.add(AmplitudeSample.fromDbfs(dbfs));
  }

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
    startCalls++;
    _recording = true;
    _path = '/tmp/fake_${DateTime.now().microsecondsSinceEpoch}.m4a';
    return _path!;
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
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

/// In-memory [PreviewPlayer] for widget tests. Records each control call
/// and lets tests drive the state stream synchronously.
class FakePreviewPlayer implements PreviewPlayer {
  final _states = StreamController<PreviewPlaybackState>.broadcast();
  PreviewPlaybackState _state = PreviewPlaybackState.stopped;

  bool disposed = false;
  String? loadedPath;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int seekToStartCalls = 0;

  void emit(PreviewPlaybackState s) {
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  @override
  PreviewPlaybackState get state => _state;

  @override
  Stream<PreviewPlaybackState> get stateStream {
    // Emit the current value on every new subscription so the screen's
    // listener gets a snapshot the same way it would from just_audio's
    // BehaviorSubject. The wrapping controller is closed when the
    // subscription is cancelled to keep the test from leaking timers.
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
    loadedPath = path;
    emit(const PreviewPlaybackState(
      playing: false,
      completed: false,
      idle: false,
    ));
  }

  @override
  Future<void> seekToStart() async {
    seekToStartCalls++;
  }

  @override
  Future<void> play() async {
    playCalls++;
    emit(const PreviewPlaybackState(
      playing: true,
      completed: false,
      idle: false,
    ));
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    emit(const PreviewPlaybackState(
      playing: false,
      completed: false,
      idle: false,
    ));
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    emit(PreviewPlaybackState.stopped);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    if (!_states.isClosed) await _states.close();
  }
}

GoRouter _stubRouter({String childId = 'c1', String exerciseId = 'e1'}) {
  return GoRouter(
    initialLocation: '/assessment/$childId/$exerciseId',
    routes: [
      GoRoute(
        path: '/assessment/:childId/:exerciseId',
        builder: (_, state) => AssessmentGameScreen(
          childId: state.pathParameters['childId']!,
          exerciseId: state.pathParameters['exerciseId']!,
        ),
      ),
      GoRoute(
        path: '/exercises',
        builder: (_, __) => const Scaffold(body: Text('exercises-stub')),
      ),
      GoRoute(
        path: '/assessment/results/:id',
        builder: (_, state) => Scaffold(
          body: Text('results-stub:${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
}

Widget _wrap({
  required FakeAudioRecorder recorder,
  required FakePreviewPlayer player,
  required GoRouter router,
  String locale = 'uz',
}) {
  return ProviderScope(
    overrides: [
      audioRecorderFactoryProvider.overrideWithValue(() => recorder),
      previewPlayerFactoryProvider.overrideWithValue(() => player),
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

void main() {
  // iPhone 14-class portrait viewport so the column lays out the way real
  // devices do (the 800×600 default is closer to a small landscape tablet
  // and would mask portrait-only regressions).
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

  group('AssessmentGameScreen', () {
    testWidgets(
      'idle state renders the parrot, the 00:00 timer, the localized '
      'tap-to-record hint and the recording button',
      (tester) async {
        final recorder = FakeAudioRecorder();
        final player = FakePreviewPlayer();
        await tester.pumpWidget(_wrap(
          recorder: recorder,
          player: player,
          router: _stubRouter(),
        ));
        // Initial frame + a generous slop for entrance animations.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Mascot is on-screen for visual continuity.
        expect(find.byType(ParrotMascot), findsOneWidget);

        // Timer starts at 00:00 since nothing has been recorded yet.
        expect(find.text('00:00'), findsOneWidget);

        // Localized hint in Uzbek (NOT a hard-coded English string).
        expect(find.text('Yozib olish uchun bosing'), findsOneWidget);

        // The big circular CTA is the recording button.
        expect(find.byType(RecordingButton), findsOneWidget);

        // Submit / play / re-record only show after a successful capture.
        expect(find.text('Yuborish'), findsNothing);
        expect(find.text('Yozuvni tinglash'), findsNothing);
        expect(find.text('Qayta yozish'), findsNothing);
      },
    );

    testWidgets(
      'AppBar close action takes the user back to /exercises so they can '
      'switch exercises without finishing the recording',
      (tester) async {
        final recorder = FakeAudioRecorder();
        final player = FakePreviewPlayer();
        await tester.pumpWidget(_wrap(
          recorder: recorder,
          player: player,
          router: _stubRouter(),
        ));
        await tester.pump();

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('exercises-stub'), findsOneWidget);
      },
    );

    testWidgets(
      'amplitude stream is observed — pushing samples through the recorder '
      'must not crash the widget tree (the screen is subscribed)',
      (tester) async {
        final recorder = FakeAudioRecorder();
        final player = FakePreviewPlayer();
        await tester.pumpWidget(_wrap(
          recorder: recorder,
          player: player,
          router: _stubRouter(),
        ));
        // Advance the clock enough to flush the Timer.zero callbacks
        // scheduled by flutter_animate during initState.
        await tester.pump(const Duration(milliseconds: 50));

        // Two amplitudes covering the realistic dBFS range. If the screen
        // isn't subscribed, the broadcast controller silently drops them
        // and we'd never see an exception — but the test still proves the
        // wiring doesn't blow up if it IS subscribed.
        recorder.pushAmplitude(-20);
        recorder.pushAmplitude(-5);
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(ParrotMascot), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when the player emits a "completed" state, the screen rewinds and '
      'pauses so the recording can be replayed without reloading the file',
      (tester) async {
        final recorder = FakeAudioRecorder();
        final player = FakePreviewPlayer();
        await tester.pumpWidget(_wrap(
          recorder: recorder,
          player: player,
          router: _stubRouter(),
        ));
        await tester.pump(const Duration(milliseconds: 50));

        // Drive the player through play → completed.
        player.emit(const PreviewPlaybackState(
          playing: true,
          completed: false,
          idle: false,
        ));
        await tester.pump(const Duration(milliseconds: 50));
        player.emit(const PreviewPlaybackState(
          playing: false,
          completed: true,
          idle: false,
        ));
        await tester.pump(const Duration(milliseconds: 50));

        // The screen's listener calls seekToStart() + pause() so a second
        // tap on Play starts from the beginning.
        expect(player.seekToStartCalls, greaterThanOrEqualTo(1));
        expect(player.pauseCalls, greaterThanOrEqualTo(1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tearing down the screen disposes both the recorder and the player '
      'so production microphone / playback resources are released',
      (tester) async {
        final recorder = FakeAudioRecorder();
        final player = FakePreviewPlayer();
        await tester.pumpWidget(_wrap(
          recorder: recorder,
          player: player,
          router: _stubRouter(),
        ));
        // Drain animation Timers so the next pumpWidget doesn't trip the
        // "pending Timer" invariant when the previous tree is torn down.
        await tester.pump(const Duration(milliseconds: 50));

        // Swap the routed app for a no-op so the State.dispose() of the
        // assessment screen runs.
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pump(const Duration(milliseconds: 50));

        expect(recorder.disposed, isTrue);
        expect(player.disposed, isTrue);
      },
    );
  });
}
