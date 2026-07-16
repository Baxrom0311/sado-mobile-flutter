import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/domain/speech_profile/phoneme_mastery.dart';

void main() {
  group('PhonemeMasteryAggregator.normalize', () {
    test('lower-cases and trims', () {
      expect(PhonemeMasteryAggregator.normalize('  R '), 'r');
      expect(PhonemeMasteryAggregator.normalize('SH'), 'sh');
    });

    test('strips phonetic slashes / brackets / dots', () {
      expect(PhonemeMasteryAggregator.normalize('/r/'), 'r');
      expect(PhonemeMasteryAggregator.normalize('[s]'), 's');
      expect(PhonemeMasteryAggregator.normalize('s.'), 's');
    });

    test('returns empty for empty / whitespace input', () {
      expect(PhonemeMasteryAggregator.normalize(''), '');
      expect(PhonemeMasteryAggregator.normalize('   '), '');
    });
  });

  group('PhonemeMasteryAggregator.aggregate', () {
    test('returns empty profile when given no analyses', () {
      final profile = PhonemeMasteryAggregator.aggregate(const []);
      expect(profile.isEmpty, isTrue);
      expect(profile.assessmentCount, 0);
      expect(profile.analysedCount, 0);
      expect(profile.overallAccuracy, 0.0);
    });

    test('counts empty envelopes toward the assessment denominator only',
        () {
      final profile = PhonemeMasteryAggregator.aggregate(const [
        AssessmentAnalysis(),
        AssessmentAnalysis(),
      ]);
      expect(profile.isEmpty, isTrue);
      expect(profile.assessmentCount, 2);
      // Empty envelopes don't increment analysedCount because they
      // contributed nothing to the per-phoneme buckets.
      expect(profile.analysedCount, 0);
    });

    test('explicit phoneme scores produce the right buckets', () {
      final profile = PhonemeMasteryAggregator.aggregate([
        const AssessmentAnalysis(
          phonemeScores: [
            PhonemeScore(phoneme: 'r', accuracy: 0.20),
            PhonemeScore(phoneme: 's', accuracy: 0.55),
            PhonemeScore(phoneme: 'k', accuracy: 0.95),
          ],
        ),
      ]);

      expect(profile.phonemes, hasLength(3));
      expect(profile.struggling.map((p) => p.phoneme), ['r']);
      expect(profile.developing.map((p) => p.phoneme), ['s']);
      expect(profile.mastered.map((p) => p.phoneme), ['k']);
      // Worst-first ordering surfaces the focus area at the top.
      expect(profile.phonemes.first.phoneme, 'r');
      expect(profile.phonemes.last.phoneme, 'k');
      // 1 out of 3 is "weak" by the >= 0.7 threshold.
      expect(profile.phonemes.firstWhere((p) => p.phoneme == 'r').weakCount, 1);
      expect(profile.phonemes.firstWhere((p) => p.phoneme == 'k').weakCount, 0);
      expect(profile.assessmentCount, 1);
      expect(profile.analysedCount, 1);
    });

    test('parent-safe weakest_phonemes synthesises an accuracy', () {
      // Build a mini envelope using the wire shape so we exercise the
      // featureSummary path the production analyzer uses.
      final analysis = AssessmentAnalysis.fromJson({
        'assessment_id': 'a1',
        'results': [
          {
            'recording_id': 'r1',
            'risk_level': 'yellow',
            'confidence': 0.7,
            'feature_summary': {
              'weakest_phonemes': ['r', 'sh'],
            },
          },
          {
            'recording_id': 'r2',
            'risk_level': 'yellow',
            'confidence': 0.7,
            'feature_summary': {
              'weakest_phonemes': ['r'],
            },
          },
        ],
      });

      final profile = PhonemeMasteryAggregator.aggregate([analysis]);

      expect(profile.phonemes, hasLength(2));
      // /r/ was weak in 2 of 2 attempts → 0% accuracy.
      final r = profile.phonemes.firstWhere((p) => p.phoneme == 'r');
      expect(r.sampleCount, 2);
      expect(r.weakCount, 2);
      expect(r.accuracy, 0.0);
      expect(r.level, PhonemeMasteryLevel.struggling);
      // /sh/ was weak in 1 of 1 attempts → 0% accuracy.
      final sh = profile.phonemes.firstWhere((p) => p.phoneme == 'sh');
      expect(sh.sampleCount, 1);
      expect(sh.weakCount, 1);
      expect(sh.accuracy, 0.0);
    });

    test('case-insensitive grouping (R vs r vs /r/)', () {
      final profile = PhonemeMasteryAggregator.aggregate([
        AssessmentAnalysis.fromJson({
          'results': [
            {
              'recording_id': 'r1',
              'risk_level': 'red',
              'confidence': 0.6,
              'feature_summary': {
                'weakest_phonemes': ['R', '/r/'],
              },
            },
          ],
        }),
      ]);
      expect(profile.phonemes, hasLength(1));
      expect(profile.phonemes.single.phoneme, 'r');
      expect(profile.phonemes.single.sampleCount, 2);
    });

    test('passes through caller-supplied assessmentCount denominator', () {
      final profile = PhonemeMasteryAggregator.aggregate(
        [
          const AssessmentAnalysis(phonemeScores: [
            PhonemeScore(phoneme: 'k', accuracy: 0.9),
          ]),
        ],
        assessmentCount: 24,
      );
      // analysedCount reflects the analyses we actually saw,
      // assessmentCount reflects the wider denominator.
      expect(profile.analysedCount, 1);
      expect(profile.assessmentCount, 24);
    });

    test('overall accuracy averages every tracked phoneme', () {
      final profile = PhonemeMasteryAggregator.aggregate([
        const AssessmentAnalysis(phonemeScores: [
          PhonemeScore(phoneme: 'a', accuracy: 0.4),
          PhonemeScore(phoneme: 'b', accuracy: 0.8),
        ]),
      ]);
      expect(profile.overallAccuracy, closeTo(0.6, 1e-9));
      expect(profile.overallAccuracyPercent, 60);
    });

    test('mixed sources prefer explicit numeric scores over weak-bag', () {
      final profile = PhonemeMasteryAggregator.aggregate([
        AssessmentAnalysis.fromJson({
          'phoneme_scores': [
            {'phoneme': 'r', 'accuracy': 0.85},
          ],
          'results': [
            {
              'recording_id': 'r1',
              'risk_level': 'green',
              'confidence': 0.9,
              'feature_summary': {
                'weakest_phonemes': ['r'],
              },
            },
          ],
        }),
      ]);
      // /r/ shows up via both paths, but the explicit 0.85 score must
      // win the accuracy field — otherwise a single weak-bag mention
      // could wrongly downgrade a phoneme the analyzer says is strong.
      final r = profile.phonemes.single;
      expect(r.phoneme, 'r');
      expect(r.accuracy, closeTo(0.85, 1e-9));
      expect(r.level, PhonemeMasteryLevel.mastered);
    });

    test('drops phonemes with empty codes after normalization', () {
      final profile = PhonemeMasteryAggregator.aggregate([
        const AssessmentAnalysis(phonemeScores: [
          PhonemeScore(phoneme: '   ', accuracy: 0.9),
          PhonemeScore(phoneme: 'k', accuracy: 0.9),
        ]),
      ]);
      expect(profile.phonemes.map((p) => p.phoneme), ['k']);
    });
  });

  group('PhonemeMastery.level boundaries', () {
    test('exactly 0.70 is mastered (lower bound is inclusive)', () {
      const m =
          PhonemeMastery(phoneme: 'r', sampleCount: 1, weakCount: 0, accuracy: 0.70);
      expect(m.level, PhonemeMasteryLevel.mastered);
    });
    test('just below 0.70 is developing', () {
      const m =
          PhonemeMastery(phoneme: 'r', sampleCount: 1, weakCount: 0, accuracy: 0.6999);
      expect(m.level, PhonemeMasteryLevel.developing);
    });
    test('exactly 0.35 is developing', () {
      const m =
          PhonemeMastery(phoneme: 'r', sampleCount: 1, weakCount: 0, accuracy: 0.35);
      expect(m.level, PhonemeMasteryLevel.developing);
    });
    test('just below 0.35 is struggling', () {
      const m =
          PhonemeMastery(phoneme: 'r', sampleCount: 1, weakCount: 1, accuracy: 0.34);
      expect(m.level, PhonemeMasteryLevel.struggling);
    });
  });
}
