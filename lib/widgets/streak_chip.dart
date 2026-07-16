import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Streak chip showing fire icon and day count, with subtle pulse animation
/// when streak >= 3.
class StreakChip extends StatefulWidget {
  const StreakChip({super.key, required this.days, required this.label});
  final int days;
  final String label;

  @override
  State<StreakChip> createState() => _StreakChipState();
}

class _StreakChipState extends State<StreakChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.days >= 3) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant StreakChip old) {
    super.didUpdateWidget(old);
    if (widget.days >= 3 && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (widget.days < 3) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.days > 0;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final scale = 1 + _c.value * 0.06;
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: active ? AppColors.fire.withValues(alpha: 0.12) : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: active
                    ? AppColors.fire.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  active ? '🔥' : '🌱',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.days} ${widget.label}',
                  style: TextStyle(
                    color: active ? AppColors.fire : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
