import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A premium custom-painted radial progress gauge used on the assessment
/// results screen instead of the Material [CircularProgressIndicator].
///
/// Visuals:
///  - A faint translucent track behind the arc (so the empty portion still
///    reads as "scale" instead of "missing").
///  - A foreground arc whose sweep is `value.clamp(0, 1) * 2π`.
///  - Rounded stroke caps so the arc looks like a polished ring rather than
///    a sharp progress bar.
///  - An animated tween from 0 to [value] over [duration] so the result
///    "fills up" when the screen first appears (the celebratory feel).
///
/// The widget is purely cosmetic: the [child] (typically the animated score
/// counter + label) is centered on top of the painter.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.value,
    this.size = 130,
    this.strokeWidth = 10,
    this.foregroundColor = Colors.white,
    this.backgroundColor,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
    this.child,
  });

  /// Target progress in `[0, 1]`. Values outside the range are clamped.
  final double value;

  /// Width and height of the square ring. The arc is inset by half the
  /// stroke width so it never gets clipped by the bounds.
  final double size;

  /// Thickness of both the track and the foreground arc.
  final double strokeWidth;

  /// Color used for the foreground arc.
  final Color foregroundColor;

  /// Color used for the background track. Defaults to a translucent version
  /// of [foregroundColor] so it works on any branded background.
  final Color? backgroundColor;

  /// How long it takes the arc to animate from 0 to [value] on first build.
  final Duration duration;

  /// Curve applied to the fill animation.
  final Curve curve;

  /// Optional widget rendered in the center of the ring (e.g. the score).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final track = backgroundColor ?? foregroundColor.withValues(alpha: 0.25);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: clamped),
        duration: duration,
        curve: curve,
        builder: (_, v, __) => CustomPaint(
          painter: _ScoreRingPainter(
            value: v,
            strokeWidth: strokeWidth,
            foreground: foregroundColor,
            background: track,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  _ScoreRingPainter({
    required this.value,
    required this.strokeWidth,
    required this.foreground,
    required this.background,
  });

  final double value;
  final double strokeWidth;
  final Color foreground;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = background;
    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = foreground;

    // Start from the top (12 o'clock) and sweep clockwise.
    const startAngle = -math.pi / 2;
    final sweep = value.clamp(0.0, 1.0) * 2 * math.pi;
    canvas.drawArc(rect, startAngle, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) {
    return old.value != value ||
        old.strokeWidth != strokeWidth ||
        old.foreground != foreground ||
        old.background != background;
  }
}
