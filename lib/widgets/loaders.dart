import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'parrot_mascot.dart';

/// Branded full-screen loader: pulsing parrot mascot with concentric rings
/// + optional caption. Replaces plain CircularProgressIndicator on loading
/// states everywhere in the app.
class MascotLoader extends StatefulWidget {
  const MascotLoader({
    super.key,
    this.message,
    this.size = 120,
    this.mood = ParrotMood.happy,
    this.color = AppColors.primary,
  });

  final String? message;
  final double size;
  final ParrotMood mood;
  final Color color;

  @override
  State<MascotLoader> createState() => _MascotLoaderState();
}

class _MascotLoaderState extends State<MascotLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size + 80,
            height: widget.size + 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ...List.generate(3, (i) {
                  return AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) {
                      final phase = ((_c.value + i / 3) % 1);
                      final r = widget.size + phase * 70;
                      final opacity = (1 - phase).clamp(0.0, 1.0);
                      return Container(
                        width: r,
                        height: r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color
                              .withValues(alpha: 0.16 * opacity),
                        ),
                      );
                    },
                  );
                }),
                ParrotMascot(mood: widget.mood, size: widget.size),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DotsLoader(color: widget.color),
          if (widget.message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact three-dot bouncing loader with brand color.
/// Use inside buttons or rows where the mascot loader would be too big.
class DotsLoader extends StatefulWidget {
  const DotsLoader({
    super.key,
    this.color = AppColors.primary,
    this.size = 8,
  });

  final Color color;
  final double size;

  @override
  State<DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<DotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 5 + 8,
      height: widget.size * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(3, (i) {
              final phase = (_c.value + i * 0.18) % 1;
              final lift =
                  math.sin(phase * math.pi * 2).clamp(-1, 1).toDouble();
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.size * 0.25),
                child: Transform.translate(
                  offset: Offset(0, -lift * widget.size * 0.6),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// Tiny ring used as a non-default tinted spinner inside small surfaces
/// (e.g., button while submitting). Painted as an arc so it does NOT
/// fall back to the Material default style.
class BrandedSpinner extends StatefulWidget {
  const BrandedSpinner({
    super.key,
    this.color = AppColors.primary,
    this.size = 22,
    this.strokeWidth = 2.5,
  });

  final Color color;
  final double size;
  final double strokeWidth;

  @override
  State<BrandedSpinner> createState() => _BrandedSpinnerState();
}

class _BrandedSpinnerState extends State<BrandedSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _SpinnerPainter(
            progress: _c.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    final r = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, r, track);
    final start = progress * 2 * math.pi - math.pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      start,
      math.pi * 1.4,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
