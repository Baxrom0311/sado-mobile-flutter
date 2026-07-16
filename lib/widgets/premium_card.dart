import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Premium tappable card — soft shadow, subtle lift on press.
class PremiumCard extends StatefulWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surface,
    this.gradient,
    this.borderRadius = AppRadius.lg,
    this.shadowColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color color;
  final List<Color>? gradient;
  final double borderRadius;
  final Color? shadowColor;

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0,
      upperBound: 0.04,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final box = AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final lift = _c.value * 6; // 0..6 px lift
        return Transform.translate(
          offset: Offset(0, -lift),
          child: child,
        );
      },
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.gradient == null ? widget.color : null,
          gradient: widget.gradient != null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.gradient!,
                )
              : null,
          borderRadius: radius,
          boxShadow: widget.shadowColor != null
              ? AppShadow.soft(widget.shadowColor!, opacity: 0.22)
              : AppShadow.card,
        ),
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return box;

    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) => _c.reverse(),
      onTapCancel: () => _c.reverse(),
      onTap: widget.onTap,
      child: box,
    );
  }
}
