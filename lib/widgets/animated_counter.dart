import 'package:flutter/material.dart';

/// A reusable counter that animates from `from` up to `value` over [duration].
///
/// Designed for celebratory moments (assessment score, XP gained, total
/// assessments). Uses a [TweenAnimationBuilder] so it cleans up on its own.
///
/// - The displayed integer is `value.round()` at every frame.
/// - `prefix` / `suffix` are concatenated as plain text (use for "%", "+",
///   "XP", etc.). They do NOT participate in the animation.
/// - When `value` changes, the counter smoothly tweens from the previously
///   shown value to the new one — no jump.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.from = 0,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.textAlign,
  });

  final num value;
  final num from;
  final Duration duration;
  final Curve curve;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: from.toDouble(), end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (_, v, __) => Text(
        '$prefix${v.round()}$suffix',
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}
