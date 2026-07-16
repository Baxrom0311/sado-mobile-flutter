import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/local/preferences.dart';
import 'package:sado_mobile/data/services/audio_recorder_service.dart';

/// Unit tests for the pure portions of [AudioRecorderService] — namely the
/// dBFS → 0..1 amplitude normalisation. The recording state machine itself
/// depends on the `record` and `permission_handler` plugins which are not
/// available under `flutter_test`, so they're exercised manually on device.
void main() {
  group('AmplitudeSample.normalizeDbfs', () {
    test('0 dBFS (loudest) maps to 1.0', () {
      expect(AmplitudeSample.normalizeDbfs(0), 1.0);
    });

    test('-60 dBFS (silence floor) maps to 0.0', () {
      expect(AmplitudeSample.normalizeDbfs(-60), 0.0);
    });

    test('-30 dBFS (mid) maps roughly to the midpoint', () {
      expect(AmplitudeSample.normalizeDbfs(-30), closeTo(0.5, 1e-9));
    });

    test('values below -60 dBFS clamp to 0', () {
      expect(AmplitudeSample.normalizeDbfs(-160), 0.0);
      expect(AmplitudeSample.normalizeDbfs(-1e6), 0.0);
    });

    test('positive values clamp to 1', () {
      // Some platforms can briefly emit slightly positive dBFS due to
      // metering quirks. We still want the visualiser to stay sane.
      expect(AmplitudeSample.normalizeDbfs(5), 1.0);
    });

    test('NaN and infinity are treated as silence', () {
      expect(AmplitudeSample.normalizeDbfs(double.nan), 0.0);
      expect(AmplitudeSample.normalizeDbfs(double.infinity), 0.0);
      expect(AmplitudeSample.normalizeDbfs(double.negativeInfinity), 0.0);
    });

    test('curve is monotonic across the working range', () {
      double previous = -1;
      for (final db in [-60.0, -45.0, -30.0, -15.0, -3.0, 0.0]) {
        final v = AmplitudeSample.normalizeDbfs(db);
        expect(v, greaterThanOrEqualTo(previous));
        previous = v;
      }
    });
  });

  group('AmplitudeSample.fromDbfs', () {
    test('preserves the raw dBFS reading', () {
      final s = AmplitudeSample.fromDbfs(-12.5);
      expect(s.dbfs, -12.5);
      // -12.5 dBFS → (47.5 / 60) ≈ 0.7917
      expect(s.normalized, closeTo(0.79166, 1e-3));
    });

    test('clamps gracefully when the recorder reports nonsense', () {
      final s = AmplitudeSample.fromDbfs(double.nan);
      expect(s.normalized, 0);
      expect(s.dbfs.isNaN, isTrue,
          reason: 'raw value is preserved even when normalised is 0');
    });
  });

  group('AudioCaptureProfile.forQuality', () {
    test('low quality uses a lower bitrate than standard', () {
      final low = AudioCaptureProfile.forQuality(AudioQuality.low);
      final standard = AudioCaptureProfile.forQuality(AudioQuality.standard);
      expect(low.bitRate, lessThan(standard.bitRate));
      expect(low.sampleRate, lessThanOrEqualTo(standard.sampleRate));
    });

    test('high quality uses a higher bitrate than standard', () {
      final high = AudioCaptureProfile.forQuality(AudioQuality.high);
      final standard = AudioCaptureProfile.forQuality(AudioQuality.standard);
      expect(high.bitRate, greaterThan(standard.bitRate));
      expect(high.sampleRate, greaterThanOrEqualTo(standard.sampleRate));
    });

    test('bitrate is positive and sample rate is realistic for AAC', () {
      for (final q in AudioQuality.values) {
        final p = AudioCaptureProfile.forQuality(q);
        expect(p.bitRate, greaterThan(0));
        expect(p.sampleRate, inInclusiveRange(8000, 96000));
      }
    });
  });
}
