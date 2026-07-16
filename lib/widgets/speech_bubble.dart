import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A small, animated speech bubble used by the parrot mascot and any
/// instructional copy that needs a friendly, child-style presentation.
///
/// The bubble has a downward-pointing tail and uses the surface color
/// + soft border / shadow from the design system. Width is constrained
/// to keep it readable on phones without forcing parent layouts.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.text,
    this.maxWidth = 260,
    this.tailDirection = SpeechBubbleTail.down,
    this.color,
    this.textColor,
  });

  final String text;
  final double maxWidth;
  final SpeechBubbleTail tailDirection;

  /// Optional override for the bubble fill color. Defaults to surface.
  final Color? color;

  /// Optional override for the text color. Defaults to textPrimary.
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? AppColors.surface;
    final fg = textColor ?? AppColors.textPrimary;
    final bubble = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.3,
        ),
      ),
    );

    final tail = CustomPaint(
      size: const Size(18, 10),
      painter: _BubbleTailPainter(
        fill: fill,
        stroke: AppColors.border,
        flip: tailDirection == SpeechBubbleTail.up,
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: tailDirection == SpeechBubbleTail.up
            ? Alignment.topCenter
            : Alignment.bottomCenter,
        children: [
          bubble,
          Positioned(
            top: tailDirection == SpeechBubbleTail.up ? -8 : null,
            bottom: tailDirection == SpeechBubbleTail.down ? -8 : null,
            child: tail,
          ),
        ],
      ),
    );
  }
}

enum SpeechBubbleTail { up, down }

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({
    required this.fill,
    required this.stroke,
    required this.flip,
  });

  final Color fill;
  final Color stroke;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = fill;
    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path();
    if (flip) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..close();
    }
    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) =>
      old.fill != fill || old.stroke != stroke || old.flip != flip;
}
