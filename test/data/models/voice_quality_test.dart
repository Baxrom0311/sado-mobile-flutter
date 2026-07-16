import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/models/models.dart';

void main() {
  group('VoiceQuality.tryFromMap', () {
    test('returns null for a null or empty map', () {
      expect(VoiceQuality.tryFromMap(null), isNull);
      expect(VoiceQuality.tryFromMap(<String, dynamic>{}), isNull);
    });

    test('parses the four canonical numeric keys', () {
      final vq = VoiceQuality.tryFromMap({
        'jitter_local_pct': 0.8,
        'shimmer_local_pct': 2.5,
        'hnr_db': 22.0,
        'speech_rate_wpm': 120,
      });

      expect(vq, isNotNull);
      expect(vq!.jitterLocalPct, 0.8);
      expect(vq.shimmerLocalPct, 2.5);
      expect(vq.hnrDb, 22.0);
      expect(vq.speechRateWpm, 120);
      expect(vq.flags, isEmpty);
    });

    test('skips NaN / infinite numerics defensively', () {
      final vq = VoiceQuality.tryFromMap({
        'jitter_local_pct': double.nan,
        'shimmer_local_pct': double.infinity,
        'hnr_db': 18.0,
        'speech_rate_wpm': 110,
      });

      expect(vq, isNotNull);
      expect(vq!.jitterLocalPct, isNull);
      expect(vq.shimmerLocalPct, isNull);
      expect(vq.hnrDb, 18.0);
      expect(vq.speechRateWpm, 110);
    });

    test('parses a dedicated voice_quality block with flags', () {
      final vq = VoiceQuality.tryFromMap({
        'jitter_local_pct': 1.5,
        'shimmer_local_pct': 4.5,
        'hnr_db': 14.0,
        'speech_rate_wpm': 90,
        'flags': ['high_jitter', 'low_hnr', 'slow_speech_rate'],
      });

      expect(vq, isNotNull);
      expect(vq!.flags, ['high_jitter', 'low_hnr', 'slow_speech_rate']);
    });

    test('returns null when no known keys present, even with extra keys', () {
      expect(
        VoiceQuality.tryFromMap({'foo': 1, 'bar': 'baz'}),
        isNull,
      );
    });

    test('returns a model when only flags are present', () {
      final vq = VoiceQuality.tryFromMap({
        'flags': ['high_jitter'],
      });
      expect(vq, isNotNull);
      expect(vq!.flags, ['high_jitter']);
      expect(vq.isEmpty, isTrue,
          reason: 'numerics still missing → considered empty');
    });
  });

  group('VoiceQuality status thresholds', () {
    test('jitter: normal/elevated/abnormal traffic-light bands', () {
      const normal = VoiceQuality(jitterLocalPct: 0.6);
      const elevated = VoiceQuality(jitterLocalPct: 1.5);
      const abnormal = VoiceQuality(jitterLocalPct: 3.0);
      expect(normal.jitterStatus, VoiceQualityStatus.normal);
      expect(elevated.jitterStatus, VoiceQualityStatus.elevated);
      expect(abnormal.jitterStatus, VoiceQualityStatus.abnormal);
    });

    test('jitter: missing value is unknown', () {
      const empty = VoiceQuality();
      expect(empty.jitterStatus, VoiceQualityStatus.unknown);
    });

    test('shimmer: normal/elevated/abnormal traffic-light bands', () {
      const normal = VoiceQuality(shimmerLocalPct: 2.0);
      const elevated = VoiceQuality(shimmerLocalPct: 5.0);
      const abnormal = VoiceQuality(shimmerLocalPct: 8.0);
      expect(normal.shimmerStatus, VoiceQualityStatus.normal);
      expect(elevated.shimmerStatus, VoiceQualityStatus.elevated);
      expect(abnormal.shimmerStatus, VoiceQualityStatus.abnormal);
    });

    test('hnr: higher is healthier (inverted band)', () {
      const normal = VoiceQuality(hnrDb: 25.0);
      const elevated = VoiceQuality(hnrDb: 12.0);
      const abnormal = VoiceQuality(hnrDb: 4.0);
      expect(normal.hnrStatus, VoiceQualityStatus.normal);
      expect(elevated.hnrStatus, VoiceQualityStatus.elevated);
      expect(abnormal.hnrStatus, VoiceQualityStatus.abnormal);
    });

    test('hnr: zero is treated as missing', () {
      const zero = VoiceQuality(hnrDb: 0);
      expect(zero.hnrStatus, VoiceQualityStatus.unknown);
    });

    test('speech rate: normal lives within 100..180 wpm', () {
      const tooSlow = VoiceQuality(speechRateWpm: 60);
      const slowEdge = VoiceQuality(speechRateWpm: 90);
      const normal = VoiceQuality(speechRateWpm: 140);
      const fastEdge = VoiceQuality(speechRateWpm: 200);
      const tooFast = VoiceQuality(speechRateWpm: 250);
      expect(tooSlow.speechRateStatus, VoiceQualityStatus.abnormal);
      expect(slowEdge.speechRateStatus, VoiceQualityStatus.elevated);
      expect(normal.speechRateStatus, VoiceQualityStatus.normal);
      expect(fastEdge.speechRateStatus, VoiceQualityStatus.elevated);
      expect(tooFast.speechRateStatus, VoiceQualityStatus.abnormal);
    });

    test('speech rate: zero is treated as missing', () {
      const zero = VoiceQuality(speechRateWpm: 0);
      expect(zero.speechRateStatus, VoiceQualityStatus.unknown);
    });
  });

  group('VoiceQuality.overallStatus', () {
    test('all-unknown returns unknown', () {
      const empty = VoiceQuality();
      expect(empty.overallStatus, VoiceQualityStatus.unknown);
    });

    test('all-normal returns normal', () {
      const allGood = VoiceQuality(
        jitterLocalPct: 0.5,
        shimmerLocalPct: 2.0,
        hnrDb: 25.0,
        speechRateWpm: 140,
      );
      expect(allGood.overallStatus, VoiceQualityStatus.normal);
    });

    test('a single elevated metric promotes the overall to elevated', () {
      const mixed = VoiceQuality(
        jitterLocalPct: 0.5, // normal
        shimmerLocalPct: 5.0, // elevated
        hnrDb: 25.0, // normal
        speechRateWpm: 140, // normal
      );
      expect(mixed.overallStatus, VoiceQualityStatus.elevated);
    });

    test('a single abnormal metric promotes the overall to abnormal', () {
      const mixed = VoiceQuality(
        jitterLocalPct: 3.0, // abnormal
        shimmerLocalPct: 2.0, // normal
        hnrDb: 25.0, // normal
        speechRateWpm: 140, // normal
      );
      expect(mixed.overallStatus, VoiceQualityStatus.abnormal);
    });

    test('unknown metrics are ignored when other metrics are present', () {
      const partial = VoiceQuality(jitterLocalPct: 0.5);
      expect(partial.overallStatus, VoiceQualityStatus.normal);
    });
  });

  group('VoiceQuality.mean', () {
    test('returns null on empty input', () {
      expect(VoiceQuality.mean(const []), isNull);
    });

    test('averages numerics and unions flags', () {
      const a = VoiceQuality(
        jitterLocalPct: 0.4,
        shimmerLocalPct: 2.0,
        hnrDb: 22.0,
        speechRateWpm: 110,
        flags: ['high_jitter'],
      );
      const b = VoiceQuality(
        jitterLocalPct: 0.6,
        shimmerLocalPct: 4.0,
        hnrDb: 18.0,
        speechRateWpm: 130,
        flags: ['low_hnr'],
      );

      final mean = VoiceQuality.mean([a, b])!;
      expect(mean.jitterLocalPct, closeTo(0.5, 1e-9));
      expect(mean.shimmerLocalPct, closeTo(3.0, 1e-9));
      expect(mean.hnrDb, closeTo(20.0, 1e-9));
      expect(mean.speechRateWpm, closeTo(120, 1e-9));
      expect(mean.flags, containsAll(['high_jitter', 'low_hnr']));
    });

    test('skips missing values when averaging (no NaN poisoning)', () {
      const a = VoiceQuality(jitterLocalPct: 0.5);
      const b = VoiceQuality(shimmerLocalPct: 3.0);
      final mean = VoiceQuality.mean([a, b])!;
      expect(mean.jitterLocalPct, 0.5);
      expect(mean.shimmerLocalPct, 3.0);
      expect(mean.hnrDb, isNull);
      expect(mean.speechRateWpm, isNull);
    });
  });

  group('AssessmentAnalysis voice-quality wiring', () {
    test('aggregates voice quality from per-recording feature_summary', () {
      final analysis = AssessmentAnalysis.fromJson({
        'assessment_id': 'a1',
        'results': [
          {
            'recording_id': 'r1',
            'risk_level': 'green',
            'confidence': 0.9,
            'feature_summary': {
              'jitter_local_pct': 0.6,
              'shimmer_local_pct': 2.5,
              'hnr_db': 22.0,
              'speech_rate_wpm': 130,
            },
            'model_name': 'mock',
            'model_version': 'v1',
            'created_at': '2024-01-01T10:00:00Z',
          },
          {
            'recording_id': 'r2',
            'risk_level': 'green',
            'confidence': 0.85,
            'feature_summary': {
              'jitter_local_pct': 1.0,
              'shimmer_local_pct': 3.5,
              'hnr_db': 18.0,
              'speech_rate_wpm': 110,
            },
            'model_name': 'mock',
            'model_version': 'v1',
            'created_at': '2024-01-01T10:00:30Z',
          },
        ],
      });

      expect(analysis.voiceQuality, isNotNull);
      expect(analysis.voiceQuality!.jitterLocalPct, closeTo(0.8, 1e-9));
      expect(analysis.voiceQuality!.shimmerLocalPct, closeTo(3.0, 1e-9));
      expect(analysis.voiceQuality!.hnrDb, closeTo(20.0, 1e-9));
      expect(analysis.voiceQuality!.speechRateWpm, closeTo(120.0, 1e-9));
    });

    test(
        'prefers explicit top-level voice_quality block over per-recording '
        'aggregate', () {
      final analysis = AssessmentAnalysis.fromJson({
        'assessment_id': 'a1',
        'results': [
          {
            'recording_id': 'r1',
            'risk_level': 'green',
            'confidence': 0.9,
            'feature_summary': {
              'jitter_local_pct': 0.6,
            },
            'model_name': 'mock',
            'model_version': 'v1',
            'created_at': '2024-01-01T10:00:00Z',
          },
        ],
        'voice_quality': {
          'jitter_local_pct': 5.0,
          'shimmer_local_pct': 10.0,
          'hnr_db': 5.0,
          'speech_rate_wpm': 50.0,
          'flags': ['high_jitter', 'high_shimmer', 'low_hnr'],
        },
      });

      expect(analysis.voiceQuality, isNotNull);
      // The explicit block wins, untouched.
      expect(analysis.voiceQuality!.jitterLocalPct, 5.0);
      expect(analysis.voiceQuality!.flags, contains('high_jitter'));
    });

    test('isEmpty stays true when no voice quality and no other content', () {
      final analysis = AssessmentAnalysis.fromJson({
        'assessment_id': 'a1',
        'results': [],
      });
      expect(analysis.isEmpty, isTrue);
    });

    test('isEmpty becomes false once voice quality is present', () {
      final analysis = AssessmentAnalysis.fromJson({
        'assessment_id': 'a1',
        'results': [
          {
            'recording_id': 'r1',
            'risk_level': 'green',
            'confidence': 0.9,
            'feature_summary': {
              'jitter_local_pct': 0.6,
            },
            'model_name': 'mock',
            'model_version': 'v1',
            'created_at': '2024-01-01T10:00:00Z',
          },
        ],
      });
      expect(analysis.isEmpty, isFalse);
      expect(analysis.voiceQuality, isNotNull);
    });
  });
}
