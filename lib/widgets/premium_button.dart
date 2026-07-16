import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils/haptics.dart';
import 'loaders.dart';

/// Premium primary button — scales 0.95 on press, colored shadow.
class PremiumButton extends StatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = AppColors.primary,
    this.foreground = Colors.white,
    this.expand = true,
    this.height = 56,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color foreground;
  final bool expand;
  final double height;
  final bool loading;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0,
      upperBound: 0.05,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => _c.forward(),
      onTapUp: disabled ? null : (_) => _c.reverse(),
      onTapCancel: disabled ? null : () => _c.reverse(),
      onTap: disabled
          ? null
          : () {
              Haptics.light();
              widget.onPressed?.call();
            },
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final scale = 1 - _c.value;
          return Transform.scale(scale: scale, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: widget.height,
          width: widget.expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          decoration: BoxDecoration(
            color: disabled
                ? widget.color.withValues(alpha: 0.4)
                : widget.color,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: disabled ? null : AppShadow.soft(widget.color),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.loading)
                  BrandedSpinner(
                    color: widget.foreground,
                    size: 22,
                    strokeWidth: 2.5,
                  )
                else if (widget.icon != null) ...[
                  Icon(widget.icon, color: widget.foreground, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                ],
                if (!widget.loading)
                  // Flexible + ellipsis prevents long localized labels
                  // (e.g. uz "Hammasini yuborish") from overflowing the
                  // pill's intrinsic width on narrow phones / inside cards.
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium secondary / outline variant.
class PremiumOutlineButton extends StatelessWidget {
  const PremiumOutlineButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = AppColors.primary,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        icon: Icon(icon ?? Icons.arrow_forward, size: 20, color: color),
        label: Text(label, style: TextStyle(color: color)),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
