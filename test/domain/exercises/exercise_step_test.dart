import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/models/models.dart';

void main() {
  group('ExerciseStep.fromJson — instruction', () {
    test('parses uz/ru text and a positive duration', () {
      final step = ExerciseStep.fromJson({
        'type': 'instruction',
        'text_uz': 'Hozir S tovushini mashq qilamiz',
        'text_ru': 'Сейчас потренируем звук С',
        'duration_sec': 3,
      });
      expect(step, isA<InstructionStep>());
      final s = step as InstructionStep;
      expect(s.kind, 'instruction');
      expect(s.textUz, 'Hozir S tovushini mashq qilamiz');
      expect(s.textRu, 'Сейчас потренируем звук С');
      expect(s.durationSec, 3);
    });

    test('localizedText prefers the requested locale, falls back to the other',
        () {
      const step = InstructionStep(textUz: 'Salom', textRu: 'Привет');
      expect(step.localizedText('uz'), 'Salom');
      expect(step.localizedText('ru'), 'Привет');
    });

    test('localizedText falls back when one locale is empty', () {
      const onlyUz = InstructionStep(textUz: 'Salom');
      expect(onlyUz.localizedText('ru'), 'Salom');
      const onlyRu = InstructionStep(textRu: 'Привет');
      expect(onlyRu.localizedText('uz'), 'Привет');
    });

    test('localizedText returns "" when both are blank', () {
      const blank = InstructionStep(textUz: '   ', textRu: '');
      expect(blank.localizedText('uz'), '');
      expect(blank.localizedText('ru'), '');
    });

    test('drops zero/negative durations to null (UI uses null = "wait")', () {
      final zero = ExerciseStep.fromJson({'type': 'instruction', 'duration_sec': 0});
      expect(zero.durationSec, isNull);
      final neg = ExerciseStep.fromJson({'type': 'instruction', 'duration_sec': -5});
      expect(neg.durationSec, isNull);
    });

    test('accepts numeric duration as a string for tolerant parsing', () {
      final step = ExerciseStep.fromJson({
        'type': 'instruction',
        'duration_sec': '7',
      });
      expect(step.durationSec, 7);
    });
  });

  group('ExerciseStep.fromJson — demonstrate', () {
    test('captures audio_url, image_url, and duration', () {
      final step = ExerciseStep.fromJson({
        'type': 'demonstrate',
        'text_uz': 'Tinglang va takrorlang',
        'audio_url': '/audio/s_demo.m4a',
        'image_url': '/images/mouth_s.png',
        'duration_sec': 5,
      });
      expect(step, isA<DemonstrateStep>());
      final d = step as DemonstrateStep;
      expect(d.audioUrl, '/audio/s_demo.m4a');
      expect(d.imageUrl, '/images/mouth_s.png');
      expect(d.hasAudio, isTrue);
      expect(d.durationSec, 5);
    });

    test('hasAudio is false when audio_url is missing or empty', () {
      const noAudio = DemonstrateStep(textUz: 'Tinglang');
      const blankAudio = DemonstrateStep(textUz: 'Tinglang', audioUrl: '');
      expect(noAudio.hasAudio, isFalse);
      expect(blankAudio.hasAudio, isFalse);
    });
  });

  group('ExerciseStep.fromJson — record', () {
    test('parses target_word, target_phonemes (list) and capture limits', () {
      final step = ExerciseStep.fromJson({
        'type': 'record',
        'prompt_uz': 'Endi siz ayting: Sut',
        'prompt_ru': 'Теперь скажите: Сут',
        'target_word': 'sut',
        'target_phonemes': ['s', 'u', 't'],
        'min_duration_sec': 1,
        'max_duration_sec': 10,
      });
      expect(step, isA<RecordStep>());
      final r = step as RecordStep;
      expect(r.targetWord, 'sut');
      expect(r.targetPhonemes, ['s', 'u', 't']);
      expect(r.minDurationSec, 1);
      expect(r.maxDurationSec, 10);
    });

    test('parses comma-separated target_phonemes for legacy payloads', () {
      final step = ExerciseStep.fromJson({
        'type': 'record',
        'target_phonemes': 's, u, t',
      });
      final r = step as RecordStep;
      expect(r.targetPhonemes, ['s', 'u', 't']);
    });

    test('drops empty entries from target_phonemes', () {
      final step = ExerciseStep.fromJson({
        'type': 'record',
        'target_phonemes': ['s', '', '  ', null, 'a'],
      });
      final r = step as RecordStep;
      expect(r.targetPhonemes, ['s', 'a']);
    });

    test('targetPhonemes is null (not []) when API omits it', () {
      final step =
          ExerciseStep.fromJson({'type': 'record'}) as RecordStep;
      expect(step.targetPhonemes, isNull);
    });

    test('displayWord prefers target_word over the localized prompt', () {
      const step = RecordStep(
        targetWord: 'sut',
        promptUz: 'Endi ayting: Sut',
        promptRu: 'Теперь скажите: Сут',
      );
      expect(step.displayWord('uz'), 'sut');
      expect(step.displayWord('ru'), 'sut');
    });

    test('displayWord falls back to the localized prompt', () {
      const step = RecordStep(
        promptUz: 'Endi ayting',
        promptRu: 'Теперь скажите',
      );
      expect(step.displayWord('uz'), 'Endi ayting');
      expect(step.displayWord('ru'), 'Теперь скажите');
    });

    test('displayWord returns "" when nothing is provided', () {
      const step = RecordStep();
      expect(step.displayWord('uz'), '');
    });
  });

  group('ExerciseStep.fromJson — feedback', () {
    test('captures show_score / show_phoneme_detail flags', () {
      final step = ExerciseStep.fromJson({
        'type': 'feedback',
        'encouragement_uz': 'Ajoyib!',
        'encouragement_ru': 'Отлично!',
        'retry_uz': 'Yana urinib ko\'ring',
        'retry_ru': 'Попробуйте ещё раз',
        'show_score': true,
        'show_phoneme_detail': false,
      });
      expect(step, isA<FeedbackStep>());
      final f = step as FeedbackStep;
      expect(f.showScore, isTrue);
      expect(f.showPhonemeDetail, isFalse);
      expect(f.localizedEncouragement('uz'), 'Ajoyib!');
      expect(f.localizedRetry('ru'), 'Попробуйте ещё раз');
    });

    test('defaults showScore to true when API omits it', () {
      final step = ExerciseStep.fromJson({'type': 'feedback'}) as FeedbackStep;
      expect(step.showScore, isTrue);
      expect(step.showPhonemeDetail, isFalse);
    });

    test('coerces "true"/"false"/"1"/"0" strings into booleans', () {
      final t1 =
          ExerciseStep.fromJson({'type': 'feedback', 'show_score': 'false'})
              as FeedbackStep;
      expect(t1.showScore, isFalse);
      final t2 = ExerciseStep.fromJson(
              {'type': 'feedback', 'show_phoneme_detail': '1'})
          as FeedbackStep;
      expect(t2.showPhonemeDetail, isTrue);
    });
  });

  group('ExerciseStep.fromJson — unknown / defensive', () {
    test('unknown type boxes into UnknownStep without throwing', () {
      final step =
          ExerciseStep.fromJson({'type': 'breathe-fire', 'duration_sec': 4});
      expect(step, isA<UnknownStep>());
      final u = step as UnknownStep;
      expect(u.rawType, 'breathe-fire');
      expect(u.durationSec, 4);
    });

    test('missing type token also becomes UnknownStep', () {
      final step = ExerciseStep.fromJson({});
      expect(step, isA<UnknownStep>());
      expect((step as UnknownStep).rawType, '');
    });

    test('uppercases / mixed case still parse the canonical type', () {
      final step = ExerciseStep.fromJson({'type': 'INSTRUCTION'});
      expect(step, isA<InstructionStep>());
    });
  });

  group('ExerciseStep.fromJsonList', () {
    test('returns an empty list when input is null or non-list', () {
      expect(ExerciseStep.fromJsonList(null), isEmpty);
      expect(ExerciseStep.fromJsonList('not a list'), isEmpty);
      expect(ExerciseStep.fromJsonList(42), isEmpty);
    });

    test('skips entries that are not maps', () {
      final list = ExerciseStep.fromJsonList([
        {'type': 'instruction', 'text_uz': 'Salom'},
        'oops, not a map',
        null,
        42,
        {'type': 'record'},
      ]);
      expect(list, hasLength(2));
      expect(list[0], isA<InstructionStep>());
      expect(list[1], isA<RecordStep>());
    });

    test('accepts Map<dynamic, dynamic> for cached Hive entries', () {
      // Hive returns dynamic-keyed maps when round-tripping JSON-ish blobs.
      final list = ExerciseStep.fromJsonList([
        <dynamic, dynamic>{'type': 'instruction', 'text_uz': 'OK'},
      ]);
      expect(list, hasLength(1));
      expect(list[0], isA<InstructionStep>());
    });
  });

  group('Exercise.fromJson — interactive steps', () {
    Map<String, dynamic> baseJson({Object? steps}) => {
          'id': 'ex-1',
          'title': 'Sut sutni sevadi',
          'description': 'S tovushi mashqi',
          'category': 'articulation',
          'age_group': '4-5',
          'difficulty': 'easy',
          'duration_minutes': 5,
          'is_active': true,
          if (steps != null) 'steps': steps,
        };

    test('legacy payloads (no `steps` field) keep hasInteractiveSteps=false',
        () {
      final ex = Exercise.fromJson(baseJson());
      expect(ex.steps, isNull);
      expect(ex.hasInteractiveSteps, isFalse);
    });

    test('empty steps array normalises to null (not [])', () {
      final ex = Exercise.fromJson(baseJson(steps: const []));
      expect(ex.steps, isNull);
      expect(ex.hasInteractiveSteps, isFalse);
    });

    test('parses a full multi-step lesson plan', () {
      final ex = Exercise.fromJson(baseJson(steps: [
        {'type': 'instruction', 'text_uz': 'Salom', 'duration_sec': 3},
        {
          'type': 'demonstrate',
          'text_uz': 'Tinglang',
          'audio_url': '/a.m4a',
        },
        {
          'type': 'record',
          'target_word': 'sut',
          'target_phonemes': ['s', 'u', 't'],
        },
        {'type': 'feedback', 'encouragement_uz': 'Ajoyib!'},
      ]));
      expect(ex.hasInteractiveSteps, isTrue);
      expect(ex.steps, hasLength(4));
      expect(ex.steps![0], isA<InstructionStep>());
      expect(ex.steps![1], isA<DemonstrateStep>());
      expect(ex.steps![2], isA<RecordStep>());
      expect(ex.steps![3], isA<FeedbackStep>());
    });

    test('parses prerequisites, unlocks, min_score_to_pass, max_attempts', () {
      final ex = Exercise.fromJson({
        'id': 'ex-2',
        'title': 'R drill',
        'description': 'd',
        'category': 'articulation',
        'age_group': '5-6',
        'difficulty': 'medium',
        'duration_minutes': 4,
        'is_active': true,
        'prerequisites': ['ex-prereq-1', 'ex-prereq-2'],
        'unlocks': ['ex-next-1'],
        'min_score_to_pass': 0.65,
        'max_attempts': 3,
      });
      expect(ex.prerequisites, ['ex-prereq-1', 'ex-prereq-2']);
      expect(ex.unlocks, ['ex-next-1']);
      expect(ex.minScoreToPass, closeTo(0.65, 1e-9));
      expect(ex.maxAttempts, 3);
    });

    test('null progression fields stay null', () {
      final ex = Exercise.fromJson({
        'id': 'ex-3',
        'title': 'X',
        'description': 'd',
        'category': 'articulation',
        'age_group': '4-5',
        'difficulty': 'easy',
        'duration_minutes': 5,
        'is_active': true,
      });
      expect(ex.prerequisites, isNull);
      expect(ex.unlocks, isNull);
      expect(ex.minScoreToPass, isNull);
      expect(ex.maxAttempts, isNull);
    });

    test('legacy comma-separated prerequisites string still parses', () {
      final ex = Exercise.fromJson({
        'id': 'ex-4',
        'title': 'X',
        'description': 'd',
        'category': 'articulation',
        'age_group': '4-5',
        'difficulty': 'easy',
        'duration_minutes': 5,
        'is_active': true,
        'prerequisites': 'a-1, a-2 , ,a-3',
      });
      expect(ex.prerequisites, ['a-1', 'a-2', 'a-3']);
    });
  });

  group('Equality + hashCode', () {
    test('InstructionStep value equality', () {
      const a = InstructionStep(textUz: 'x', durationSec: 3);
      const b = InstructionStep(textUz: 'x', durationSec: 3);
      const c = InstructionStep(textUz: 'y', durationSec: 3);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('RecordStep equality respects target_phonemes order', () {
      const a = RecordStep(targetPhonemes: ['s', 'u', 't']);
      const b = RecordStep(targetPhonemes: ['s', 'u', 't']);
      const c = RecordStep(targetPhonemes: ['t', 'u', 's']);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('FeedbackStep equality includes showScore + showPhonemeDetail', () {
      const a = FeedbackStep(showScore: true, showPhonemeDetail: false);
      const b = FeedbackStep(showScore: true, showPhonemeDetail: false);
      const c = FeedbackStep(showScore: false);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
