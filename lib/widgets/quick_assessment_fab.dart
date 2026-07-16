import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils/haptics.dart';

/// Premium "Quick Assessment" floating action button surfaced on the main
/// shell. Sits above the bottom navigation bar so a parent can jump into
/// the assessment flow from any tab — Phase 3.5 of the plan calls for a
/// raised center FAB and this is its on-screen embodiment.
///
/// Design choices:
/// - Circular gradient (primary → secondary) so it stands apart from the
///   muted [NavigationBar] surface.
/// - 0.92 scale-on-tap micro-interaction matching the rest of the design
///   system ([PremiumButton] uses the same family of feedback).
/// - Light haptic on press for tactile confirmation.
/// - Soft colored shadow so the button reads as "raised" without the
///   default Material elevation halo.
class QuickAssessmentFab extends StatefulWidget {
  const QuickAssessmentFab({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.icon = Icons.mic_rounded,
    this.size = 60,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final double size;

  @override
  State<QuickAssessmentFab> createState() => _QuickAssessmentFabState();
}

class _QuickAssessmentFabState extends State<QuickAssessmentFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0,
      upperBound: 0.08,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _press.forward(),
          onTapCancel: () => _press.reverse(),
          onTapUp: (_) => _press.reverse(),
          onTap: () {
            Haptics.light();
            widget.onPressed();
          },
          child: AnimatedBuilder(
            animation: _press,
            builder: (context, child) {
              return Transform.scale(
                scale: 1 - _press.value,
                child: child,
              );
            },
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: widget.size * 0.42,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
