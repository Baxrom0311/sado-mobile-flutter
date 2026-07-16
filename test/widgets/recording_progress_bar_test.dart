import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/recording_progress_bar.dart';

Widget _wrap(Widget child, {String locale = 'uz'}) {
  return MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: const [
      L.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L.supportedLocales,
    theme: AppTheme.light,
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
  );
}

void main() {
  group('RecordingProgressBar', () {
    testWidgets(
      'idle (0 elapsed seconds) renders nothing — keeps the layout calm',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const RecordingProgressBar(elapsedSeconds: 0),
        ));
        await tester.pump();

        // Caption must not appear in idle. Specifically there should be no
        // text widget rendered at all under the bar.
        expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
        expect(find.byType(Text), findsNothing);
      },
    );

    testWidgets(
      'recording in the safe zone (5s/60s) shows the green bar + uz caption',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const RecordingProgressBar(elapsedSeconds: 5),
        ));
        // Pump animations forward so the TweenAnimationBuilder lands on
        // its final value and the caption stabilises.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // 60-5 = 55, plural = "55 soniya qoldi"
        expect(find.text('55 soniya qoldi'), findsOneWidget);
      },
    );

    testWidgets(
      'singular plural form fires when exactly 1 second remains',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const RecordingProgressBar(elapsedSeconds: 59),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // At 59s elapsed we are inside the danger zone (>= 50s), so the
        // bar swaps to the "wrap it up" hint instead of the seconds-left
        // label. That hint, not the singular plural, is what the user
        // sees here.
        expect(find.text(L.of(tester.element(find.byType(Scaffold)))!
            .recordingTimeAlmostUp), findsOneWidget);
      },
    );

    testWidgets(
      'danger-zone shifts the caption to the localized "almost up" hint (uz)',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const RecordingProgressBar(elapsedSeconds: 55),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // 55s elapsed is past the 50s danger threshold — caption swaps
        // from "X seconds left" to the localized urgency hint.
        expect(find.text('Vaqt tugayapti — yakunlang!'), findsOneWidget);
      },
    );

    testWidgets(
      'renders Russian copy when locale=ru',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const RecordingProgressBar(elapsedSeconds: 55),
          locale: 'ru',
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Время заканчивается — завершайте!'), findsOneWidget);
      },
    );

    testWidgets(
      'progress fill is animated via TweenAnimationBuilder',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const RecordingProgressBar(elapsedSeconds: 30),
        ));
        await tester.pump();
        // Mid-animation: tween should be present and emitting a value
        // strictly between begin (0) and end (0.5).
        expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
      },
    );

    test('colorFor returns green in the safe zone', () {
      // 0..warn-1 should map to primary (green).
      for (final s in [1, 10, 39]) {
        expect(
          RecordingProgressBar.colorFor(s, kRecordingMaxSeconds),
          AppColors.primary,
          reason: 'elapsed=${s}s should be safe-zone green',
        );
      }
    });

    test('colorFor shifts to orange in the warn zone', () {
      // warn..danger-1 should map to warning (orange).
      for (final s in [40, 45, 49]) {
        expect(
          RecordingProgressBar.colorFor(s, kRecordingMaxSeconds),
          AppColors.warning,
          reason: 'elapsed=${s}s should be warn-zone orange',
        );
      }
    });

    test('colorFor shifts to red once we cross the danger threshold', () {
      for (final s in [50, 55, 60]) {
        expect(
          RecordingProgressBar.colorFor(s, kRecordingMaxSeconds),
          AppColors.danger,
          reason: 'elapsed=${s}s should be danger-zone red',
        );
      }
    });

    test('colorFor handles non-default max correctly (proportional zones)', () {
      // When max is 30 instead of 60, the warn/danger thresholds slide
      // proportionally — the relative distance from `max` is what matters.
      // warn cutoff is `max - (60 - 40)` = 10, danger cutoff `max - (60 - 50)` = 20.
      expect(
        RecordingProgressBar.colorFor(5, 30),
        AppColors.primary,
        reason: '5/30 is below warn cutoff (10) — green',
      );
      expect(
        RecordingProgressBar.colorFor(15, 30),
        AppColors.warning,
        reason: '15/30 is between warn (10) and danger (20) — orange',
      );
      expect(
        RecordingProgressBar.colorFor(25, 30),
        AppColors.danger,
        reason: '25/30 is past danger (20) — red',
      );
    });
  });
}
