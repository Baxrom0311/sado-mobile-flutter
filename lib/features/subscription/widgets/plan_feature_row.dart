import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Single feature row inside a plan card. Renders a check icon + label.
/// The icon and label colour adapt to the parent's "highlight" mode so
/// the card stays legible on both white and gradient backgrounds.
class PlanFeatureRow extends StatelessWidget {
  const PlanFeatureRow({
    super.key,
    required this.label,
    this.highlighted = false,
    this.icon = Icons.check_circle_rounded,
  });

  final String label;
  final bool highlighted;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? Colors.white : AppColors.primary;
    final textColor =
        highlighted ? Colors.white : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
