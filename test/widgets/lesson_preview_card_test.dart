import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/domain/exercises/exercise_step.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/lesson_preview_card.dart';
import 'package:sado_mobile/widgets/parrot_mascot.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('uz')}) =>
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      locale: locale,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(width: 600, child: child),
          ),
        ),
      ),
    );

void main() {
  // Sample lesson plan covering all four step kinds plus an unknown one,
  // so each widget test can pull from the same canonical fixture.
  const sampleSteps = <ExerciseStep>[
    InstructionStep(
      textUz: 'Hozir S tovushini mashq qilamiz',
      textRu: 'Сейчас потренируем звук С',
      durationSec: 3,
    ),
    DemonstrateStep(
      textUz: 'Tinglang va takrorlang: SSS',
      textRu: 'Послушайте и повторите: ССС',
      audioUrl: '/audio/s_demo.m4a',
      imageUrl: '/images/mouth_s.png',
      durationSec: 5,
    ),
    RecordStep(
      promptUz: 'Endi siz ayting',
      promptRu: 'Теперь скажите вы',
      targetWord: 'sut',
      targetPhonemes: ['s', 'u', 't'],
      maxDurationSec: 10,
      minDurationSec: 1,
    ),
    FeedbackStep(
      encouragementUz: 'Ajoyib!',
      encouragementRu: 'Отлично!',
      retryUz: 'Yana urinib koring',
      retryRu: 'Попробуйте ещё раз',
      showScore: true,
    ),
  ];

  group('LessonPreviewCard', () {
    testWidgets('renders title, subtitle and step count chip in Uzbek',
        (tester) async {
      await tester.pumpWidget(_wrap(const LessonPreviewCard(
        steps: sampleSteps,
        accentColor: AppColors.primary,
      )));
      await tester.pump();

      expect(find.text('Interaktiv dars'), findsOneWidget);
      expect(find.text("Bola dars davomida nima qilishini ko'ring"),
          findsOneWidget);
      // 4 steps in the sample fixture → "4 qadam" pill.
      expect(find.text('4 qadam'), findsOneWidget);
    });

    testWidgets('renders the parrot mascot intro bubble', (tester) async {
      await tester.pumpWidget(_wrap(const LessonPreviewCard(
        steps: sampleSteps,
        accentColor: AppColors.primary,
      )));
      await tester.pump();

      expect(find.byType(ParrotMascot), findsOneWidget);
      // Localized substring; full mascot copy is generated.
      expect(find.textContaining('4 qadamdan'), findsOneWidget);
    });

    testWidgets('renders one numbered tile per step (1..n)', (tester) async {
      await tester.pumpWidget(_wrap(const LessonPreviewCard(
        steps: sampleSteps,
        accentColor: AppColors.primary,
      )));
      await tester.pump();

      // Each step row prefixes a 1-based number.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('renders kind labels for every step', (tester) async {
      await tester.pumpWidget(_wrap(const LessonPreviewCard(
        steps: sampleSteps,
        accentColor: AppColors.primary,
      )));
      await tester.pump();

      // Localized kind titles.
      expect(find.text("Yo'riqnoma"), findsOneWidget); // instruction
      expect(find.text("Ko'rsatish"), findsOneWidget); // demonstrate
      expect(find.text('Yozib olish'), findsOneWidget); // record
      expect(find.text('Natija va maqtov'), findsOneWidget); // feedback
    });

    testWidgets('uses the localized text body for instruction/demonstrate',
        (tester) async {
      await tester.pumpWidget(_wrap(const LessonPreviewCard(
        steps: sampleSteps,
        accentColor: AppColors.primary,
      )));
      await tester.pump();

      expect(find.text('Hozir S tovushini mashq qilamiz'), findsOneWidget);
      expect(find.text('Tinglang va takrorlang: SSS'), findsOneWidget);
    });

    testWidgets('record step shows the localized target-word + phonemes line',
        (tester) async {
      await tester.pumpWidget(_wrap(const LessonPreviewCard(
        steps: sampleSteps,
        accentColor: AppColors.primary,
      )));
      await tester.pump();

      // The record body composes "Aytish kerak: sut\nTovushlar: s · u · t".
      expect(find.textContaining('Aytish kerak: sut'), findsOneWidget);
      expect(find.textContaining('s · u · t'), findsOneWidget);
    });

    testWidgets('record step shows the duration range chip', (tester) async {
      await tester.pumpWidget(_wrap(const LessonPreviewCard(
        steps: sampleSteps,
        accentColor: AppColors.primary,
      )));
      await tester.pump();

      // min=1, max=10 → "1–10 soniya".
      expect(find.text('1–10 soniya'), findsOneWidget);
    });

    testWidgets('localizes copy when locale is ru', (tester) async {
      await tester.pumpWidget(_wrap(
        const LessonPreviewCard(
          steps: sampleSteps,
          accentColor: AppColors.primary,
        ),
        locale: const Locale('ru'),
      ));
      await tester.pump();

      expect(find.text('Интерактивный урок'), findsOneWidget);
      expect(find.text('Инструкция'), findsOneWidget);
      expect(find.text('Показ'), findsOneWidget);
      expect(find.text('Запись'), findsOneWidget);
      expect(find.text('Результат и похвала'), findsOneWidget);
      // Russian sample copy from the fixture.
      expect(find.text('Сейчас потренируем звук С'), findsOneWidget);
      expect(find.text('Послушайте и повторите: ССС'), findsOneWidget);
      // Russian range chip.
      expect(find.text('1–10 сек'), findsOneWidget);
    });

    testWidgets('falls back to localized fallback copy when text is empty',
        (tester) async {
      await tester.pumpWidget(_wrap(const LessonPreviewCard(
        steps: <ExerciseStep>[
          // No localized text whatsoever — UI must not collapse to ''.
          InstructionStep(),
          DemonstrateStep(),
          // Record without any prompt or target_word.
          RecordStep(),
          // Feedback without encouragement.
          FeedbackStep(),
        ],
        accentColor: AppColors.primary,
      )));
      await tester.pump();

      expect(find.text('Ovozli yo\'riqnoma tinglanadi.'), findsOneWidget);
      expect(find.text('Logoped to\'g\'ri talaffuzni namoyish qiladi.'),
          findsOneWidget);
      expect(find.text('Bola yozib oladi.'), findsOneWidget);
      expect(find.text('Natija va maqtov ko\'rsatiladi.'), findsOneWidget);
    });

    testWidgets('UnknownStep renders without throwing and still gets a tile',
        (tester) async {
      await tester.pumpWidget(_wrap(const LessonPreviewCard(
        steps: <ExerciseStep>[
          InstructionStep(textUz: 'Salom'),
          UnknownStep(rawType: 'breathe-fire'),
        ],
        accentColor: AppColors.primary,
      )));
      await tester.pump();

      expect(find.text('Boshqa qadam'), findsOneWidget);
      // 2 tiles total → numbers 1 and 2 are both visible.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('exposes a container Semantics label with the step count',
        (tester) async {
      await tester.pumpWidget(_wrap(const LessonPreviewCard(
        steps: sampleSteps,
        accentColor: AppColors.primary,
      )));
      await tester.pump();

      // The card container Semantics announces the lesson size; we don't
      // assert the inner-tile semantics since each tile uses
      // excludeSemantics: true to merge its three pieces of copy.
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp(r'Dars rejasi\s*—\s*4 ta qadam')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('asserts when callers pass an empty steps list', (tester) async {
      // The widget contract is "skip rendering when empty"; passing [] is
      // a programmer error. The assert protects the contract in debug.
      await tester.pumpWidget(_wrap(const LessonPreviewCard(
        steps: <ExerciseStep>[],
        accentColor: AppColors.primary,
      )));
      // The first frame raises an assertion captured by the framework.
      expect(tester.takeException(), isA<AssertionError>());
    });
  });
}
