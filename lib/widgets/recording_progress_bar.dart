import 'package:flutter/material.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';

/// Maximum recording duration in seconds. Mirrors the upper bound enforced
/// by [_AssessmentGameScreenState] when the timer trips at 60 seconds.
const int kRecordingMaxSeconds = 60;

/// Threshold (seconds elapsed) where the bar shifts from green → orange
/// to warn the user the budget is more than two-thirds spent.
const int kRecordingWarnSeconds = 40;

/// Threshold (seconds elapsed) where the bar shifts to red and a friendly
/// "wrap it up!" hint is shown. Recording auto-stops at [kRecordingMaxSeconds].
const int kRecordingDangerSeconds = 50;

/// Slim progress bar that visualises how much of the recording budget the
/// user has consumed.
///
/// Renders nothing when the recording is idle (`elapsedSeconds == 0`) so the
/// UI stays calm before the user actually taps record. While recording it
/// shifts color from green → orange → red as it nears [kRecordingMaxSeconds]
/// and surfaces a localized "X seconds left" caption that becomes a
/// "wrap it up!" hint inside the danger zone.
///
/// Pure presentational widget — accepts the elapsed seconds as input so the
/// caller (the game screen) keeps full control of the timer logic and the
/// widget itself stays trivially testable.
class RecordingProgressBar extends StatelessWidget {
  const RecordingProgressBar({
    super.key,
    required this.elapsedSeconds,
    this.maxSeconds = kRecordingMaxSeconds,
  });

  /// Number of full seconds that have elapsed since the recording started.
  final int elapsedSeconds;

  /// Max allowed recording length, in seconds. Defaults to
  /// [kRecordingMaxSeconds] (60s) — overridable for tests / future tuning.
  final int maxSeconds;

  /// Color the progress fill takes for a given [elapsed]/[max] pair.
  ///
  /// Exposed as a static helper so widget tests can assert the exact
  /// color transitions without having to render the full widget.
  static Color colorFor(int elapsed, int max) {
    if (elapsed >= max - (kRecordingMaxSeconds - kRecordingDangerSeconds)) {
      return AppColors.danger;
    }
    if (elapsed >= max - (kRecordingMaxSeconds - kRecordingWarnSeconds)) {
      return AppColors.warning;
    }
    return AppColors.primary;
  }

  /// Localized caption for a given elapsed second count. Returns either a
  /// "X seconds left" plural string or a "wrap it up!" hint when inside
  /// the danger zone.
  static String captionFor(L l, int elapsed, int max) {
    final remaining = (max - elapsed).clamp(0, max);
    final dangerCutoff =
        max - (kRecordingMaxSeconds - kRecordingDangerSeconds);
    if (elapsed >= dangerCutoff) {
      return l.recordingTimeAlmostUp;
    }
    return l.secondsLeft(remaining);
  }

  @override
  Widget build(BuildContext context) {
    if (elapsedSeconds <= 0) {
      // Idle — keep the slot collapsed so the layout above the record
      // button doesn't shift when recording starts.
      return const SizedBox.shrink();
    }

    final l = L.of(context)!;
    final clampedMax = maxSeconds <= 0 ? 1 : maxSeconds;
    final progress =
        (elapsedSeconds / clampedMax).clamp(0.0, 1.0).toDouble();
    final color = colorFor(elapsedSeconds, clampedMax);
    final caption = captionFor(l, elapsedSeconds, clampedMax);

    return Semantics(
      liveRegion: true,
      value: caption,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Animated bar fill. We use TweenAnimationBuilder so transitions
          // between the once-per-second integer ticks feel smooth instead
          // of stepping in 1/60 jumps.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(color: AppColors.surfaceMuted),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: color,
                          boxShadow: AppShadow.soft(color, opacity: 0.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            child: Text(caption, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
