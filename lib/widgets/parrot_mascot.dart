import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'speech_bubble.dart';

/// Mood drives both the body color of the SADO parrot and the
/// "is the parrot speaking right now" animation. We deliberately keep the
/// enum small — the mascot is a brand element, not a fully-rigged emoji.
enum ParrotMood { idle, happy, talking, sad, listening }

/// SADO's parrot mascot — a fully painted, brand-owned character used on
/// home, exercise detail, assessment intro, results and empty states.
///
/// Implementation notes:
/// - Built on real [AnimationController]s (not `flutter_animate`'s timer
///   chain) so widget tests can mount/unmount without leaking pending
///   timers — `flutter test` enforces `!timersPending` at teardown and
///   the previous `.then()`-based bob animation tripped that invariant.
/// - The painter is a [CustomPaint] (no `Text` / emoji glyph). This keeps
///   `find.byType(Text)` deterministic for parent screens (e.g. the
///   shared `EmptyState` checks that only its title contributes a Text).
class ParrotMascot extends StatefulWidget {
  const ParrotMascot({
    super.key,
    this.mood = ParrotMood.idle,
    this.size = 120,
    this.message,
  });

  final ParrotMood mood;
  final double size;
  final String? message;

  @override
  State<ParrotMascot> createState() => _ParrotMascotState();
}

class _ParrotMascotState extends State<ParrotMascot>
    with TickerProviderStateMixin {
  /// Slow up-and-down "breathing" bob, always running.
  late final AnimationController _bob;

  /// Long-period blink controller — drives a sharp eyelid flash near the
  /// end of each cycle so the parrot feels alive without being twitchy.
  late final AnimationController _blink;

  /// Beak-open animation; only running while [ParrotMood.talking] is set.
  late final AnimationController _talk;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _talk = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _syncTalking();
  }

  @override
  void didUpdateWidget(covariant ParrotMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _syncTalking();
    }
  }

  /// Start/stop the beak controller so the parrot only "talks" when the
  /// caller asks it to. Idempotent — safe to call from initState and from
  /// didUpdateWidget on every mood swap.
  void _syncTalking() {
    if (widget.mood == ParrotMood.talking) {
      if (!_talk.isAnimating) _talk.repeat(reverse: true);
    } else {
      if (_talk.isAnimating) _talk.stop();
      _talk.value = 0.0;
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    _blink.dispose();
    _talk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SpeechBubble(text: widget.message!),
          ),
        AnimatedBuilder(
          animation: Listenable.merge([_bob, _blink, _talk]),
          builder: (context, _) {
            // Bob is a triangular -1..1..-1 wave (reverse-repeating
            // controller). Convert to vertical pixel offset.
            final bobValue = (_bob.value - 0.5) * 2;
            final dy = -bobValue * (size * 0.025);
            return Transform.translate(
              offset: Offset(0, dy),
              child: SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _ParrotPainter(
                    mood: widget.mood,
                    blink: _blinkOpenness(_blink.value),
                    talk: _talk.value,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Maps the linear blink-controller value (0..1) into an "eye openness"
  /// curve. The eye is open most of the time and closes briefly near
  /// `value≈0.92` so the blink reads as a real wink, not a slow squint.
  double _blinkOpenness(double t) {
    const blinkStart = 0.90;
    const blinkEnd = 0.98;
    if (t < blinkStart || t > blinkEnd) return 1.0;
    final phase = (t - blinkStart) / (blinkEnd - blinkStart); // 0..1
    // Closed at the midpoint of the blink window.
    return (math.cos(phase * math.pi * 2) * 0.5 + 0.5).clamp(0.0, 1.0);
  }
}

/// Pure painter for the parrot. Mood drives palette + facial expression;
/// blink + talk drive eyelid + beak opening.
class _ParrotPainter extends CustomPainter {
  _ParrotPainter({
    required this.mood,
    required this.blink,
    required this.talk,
  });

  final ParrotMood mood;
  final double blink;
  final double talk;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) / 2;

    // 1. Soft halo / aura behind the parrot — gives the brand-y feel.
    final halo = _haloFor(mood);
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [halo[0], halo[1].withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, haloPaint);

    // 2. Body — slightly oval, sits a touch below center so the head reads
    //    as the focal point.
    final bodyColor = _bodyFor(mood);
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.18),
      width: r * 1.30,
      height: r * 1.55,
    );
    canvas.drawOval(bodyRect, Paint()..color = bodyColor);

    // 3. Belly — lighter accent on the chest.
    final bellyRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.30),
      width: r * 0.80,
      height: r * 1.05,
    );
    canvas.drawOval(
      bellyRect,
      Paint()..color = _bellyFor(mood),
    );

    // 4. Wing — tucked on the right.
    final wingPath = Path()
      ..moveTo(cx + r * 0.20, cy + r * 0.05)
      ..quadraticBezierTo(
        cx + r * 0.85,
        cy + r * 0.20,
        cx + r * 0.55,
        cy + r * 0.85,
      )
      ..quadraticBezierTo(
        cx + r * 0.30,
        cy + r * 0.55,
        cx + r * 0.20,
        cy + r * 0.05,
      )
      ..close();
    canvas.drawPath(wingPath, Paint()..color = bodyColor.withValues(alpha: 0.85));

    // 5. Head — pure circle so blinks/beak land predictably.
    final headRadius = r * 0.55;
    final headCenter = Offset(cx, cy - r * 0.30);
    canvas.drawCircle(headCenter, headRadius, Paint()..color = bodyColor);

    // 6. Cheek blush.
    if (mood == ParrotMood.happy) {
      final blush = Paint()..color = const Color(0x66EF5350);
      canvas.drawCircle(
        Offset(headCenter.dx - headRadius * 0.45, headCenter.dy + headRadius * 0.20),
        headRadius * 0.20,
        blush,
      );
      canvas.drawCircle(
        Offset(headCenter.dx + headRadius * 0.45, headCenter.dy + headRadius * 0.20),
        headRadius * 0.20,
        blush,
      );
    }

    // 7. Eyes (white sclera + black pupil + soft highlight).
    final eyeOffsetX = headRadius * 0.35;
    final eyeY = headCenter.dy - headRadius * 0.10;
    final eyeRadius = headRadius * 0.18;
    final left = Offset(headCenter.dx - eyeOffsetX, eyeY);
    final right = Offset(headCenter.dx + eyeOffsetX, eyeY);

    final eyeWhite = Paint()..color = Colors.white;
    _drawEye(canvas, left, eyeRadius, blink, eyeWhite);
    _drawEye(canvas, right, eyeRadius, blink, eyeWhite);

    // Pupils — only paint while the eye is meaningfully open so the
    // blink reads cleanly.
    if (blink > 0.15) {
      final pupil = Paint()..color = const Color(0xFF263238);
      _drawEye(canvas, left, eyeRadius * 0.55, blink, pupil);
      _drawEye(canvas, right, eyeRadius * 0.55, blink, pupil);

      final highlight = Paint()..color = Colors.white;
      canvas.drawCircle(
        Offset(left.dx + eyeRadius * 0.18, left.dy - eyeRadius * 0.18),
        eyeRadius * 0.18,
        highlight,
      );
      canvas.drawCircle(
        Offset(right.dx + eyeRadius * 0.18, right.dy - eyeRadius * 0.18),
        eyeRadius * 0.18,
        highlight,
      );
    }

    // Sad mood — single tear under the right eye.
    if (mood == ParrotMood.sad) {
      final tear = Paint()..color = const Color(0xFF42A5F5);
      final tearPath = Path()
        ..moveTo(right.dx, right.dy + eyeRadius * 1.1)
        ..quadraticBezierTo(
          right.dx + eyeRadius * 0.35,
          right.dy + eyeRadius * 1.7,
          right.dx,
          right.dy + eyeRadius * 2.1,
        )
        ..quadraticBezierTo(
          right.dx - eyeRadius * 0.35,
          right.dy + eyeRadius * 1.7,
          right.dx,
          right.dy + eyeRadius * 1.1,
        )
        ..close();
      canvas.drawPath(tearPath, tear);
    }

    // 8. Beak — opens with `talk`. Always rendered so eyes have something
    //    to anchor to.
    final beakY = headCenter.dy + headRadius * 0.18;
    final beakHalfWidth = headRadius * 0.22;
    final beakOpen = headRadius * (0.18 + talk * 0.40);
    final beak = Paint()..color = const Color(0xFFFFB300);
    final beakPath = Path()
      ..moveTo(headCenter.dx - beakHalfWidth, beakY)
      ..lineTo(headCenter.dx + beakHalfWidth, beakY)
      ..lineTo(headCenter.dx, beakY + beakOpen)
      ..close();
    canvas.drawPath(beakPath, beak);

    // Beak shadow / lower mandible — adds dimension.
    final beakShadow = Paint()..color = const Color(0xFFEF6C00);
    final shadowPath = Path()
      ..moveTo(headCenter.dx - beakHalfWidth * 0.5, beakY + beakOpen * 0.55)
      ..lineTo(headCenter.dx + beakHalfWidth * 0.5, beakY + beakOpen * 0.55)
      ..lineTo(headCenter.dx, beakY + beakOpen)
      ..close();
    canvas.drawPath(shadowPath, beakShadow);

    // 9. Tuft on the head.
    final tuft = Paint()..color = _tuftFor(mood);
    final tuftPath = Path()
      ..moveTo(headCenter.dx, headCenter.dy - headRadius * 1.05)
      ..quadraticBezierTo(
        headCenter.dx + headRadius * 0.32,
        headCenter.dy - headRadius * 1.45,
        headCenter.dx + headRadius * 0.20,
        headCenter.dy - headRadius * 0.85,
      )
      ..quadraticBezierTo(
        headCenter.dx - headRadius * 0.05,
        headCenter.dy - headRadius * 1.20,
        headCenter.dx - headRadius * 0.20,
        headCenter.dy - headRadius * 0.85,
      )
      ..quadraticBezierTo(
        headCenter.dx - headRadius * 0.32,
        headCenter.dy - headRadius * 1.45,
        headCenter.dx,
        headCenter.dy - headRadius * 1.05,
      )
      ..close();
    canvas.drawPath(tuftPath, tuft);

    // 10. Listening cue — semicircle "ear" that pulses with the bob.
    if (mood == ParrotMood.listening) {
      final ear = Paint()
        ..color = AppColors.tertiary.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = headRadius * 0.10
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(headCenter.dx + headRadius * 1.05, headCenter.dy),
          radius: headRadius * 0.45,
        ),
        -math.pi / 2.5,
        math.pi / 1.4,
        false,
        ear,
      );
    }
  }

  /// Draw an eye scaled vertically by [openness] (0 = fully closed slit,
  /// 1 = fully open circle).
  void _drawEye(
    Canvas canvas,
    Offset center,
    double radius,
    double openness,
    Paint paint,
  ) {
    final h = radius * 2 * openness.clamp(0.05, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 2,
        height: h,
      ),
      paint,
    );
  }

  // --- Color tokens -----------------------------------------------------

  Color _bodyFor(ParrotMood m) => switch (m) {
        ParrotMood.idle => const Color(0xFF66BB6A),
        ParrotMood.happy => const Color(0xFFFFB74D),
        ParrotMood.talking => const Color(0xFF26C6DA),
        ParrotMood.sad => const Color(0xFF7CB342),
        ParrotMood.listening => const Color(0xFFAB47BC),
      };

  Color _bellyFor(ParrotMood m) => switch (m) {
        ParrotMood.happy => const Color(0xFFFFE0B2),
        ParrotMood.talking => const Color(0xFFB2EBF2),
        ParrotMood.sad => const Color(0xFFDCEDC8),
        ParrotMood.listening => const Color(0xFFE1BEE7),
        _ => const Color(0xFFC8E6C9),
      };

  Color _tuftFor(ParrotMood m) => switch (m) {
        ParrotMood.happy => const Color(0xFFFF7043),
        ParrotMood.talking => const Color(0xFF00ACC1),
        ParrotMood.sad => const Color(0xFF558B2F),
        ParrotMood.listening => const Color(0xFF8E24AA),
        _ => const Color(0xFF388E3C),
      };

  List<Color> _haloFor(ParrotMood m) => switch (m) {
        ParrotMood.idle => const [Color(0xFFC8E6C9), Color(0xFFE8F5E9)],
        ParrotMood.happy => const [Color(0xFFFFE0B2), Color(0xFFFFF8E1)],
        ParrotMood.talking => const [Color(0xFFB2EBF2), Color(0xFFE3F2FD)],
        ParrotMood.sad => const [Color(0xFFDCEDC8), Color(0xFFF1F8E9)],
        ParrotMood.listening => const [Color(0xFFE1BEE7), Color(0xFFF3E5F5)],
      };

  @override
  bool shouldRepaint(covariant _ParrotPainter old) =>
      old.mood != mood || old.blink != blink || old.talk != talk;
}
