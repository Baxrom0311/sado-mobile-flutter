import 'package:flutter/material.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';

/// Three traffic-light risk buckets surfaced by the API.
///
/// We re-export them as a typed enum so the widgets that render risk no
/// longer have to repeat the same `switch` over magic strings. The string
/// values still come straight from the backend (`green`/`yellow`/`red`)
/// or from the legacy `low`/`medium`/`high` aliases.
enum RiskLevel {
  low,
  medium,
  high,
  unknown;

  static RiskLevel fromApi(String? raw) => switch (raw) {
        'green' || 'low' => RiskLevel.low,
        'yellow' || 'medium' => RiskLevel.medium,
        'red' || 'high' => RiskLevel.high,
        _ => RiskLevel.unknown,
      };

  /// Localized label, safe to use in chips, dialogs and share sheets.
  String label(L l) => switch (this) {
        RiskLevel.low => l.riskLow,
        RiskLevel.medium => l.riskMedium,
        RiskLevel.high => l.riskHigh,
        RiskLevel.unknown => l.riskUnknown,
      };

  /// Brand color matching the design-system traffic light.
  Color get color => switch (this) {
        RiskLevel.low => AppColors.success,
        RiskLevel.medium => AppColors.warning,
        RiskLevel.high => AppColors.danger,
        RiskLevel.unknown => AppColors.textMuted,
      };

  IconData get icon => switch (this) {
        RiskLevel.low => Icons.check_circle_rounded,
        RiskLevel.medium => Icons.warning_amber_rounded,
        RiskLevel.high => Icons.error_rounded,
        RiskLevel.unknown => Icons.help_outline_rounded,
      };
}

/// Visual sizes for [RiskBadge]. Small fits inside list rows, medium is
/// the default for cards, large is reserved for hero displays such as the
/// assessment results screen.
enum RiskBadgeSize { small, medium, large }

/// Pill-shaped badge with an icon + localized label, color-coded by the
/// risk level. Use this anywhere the user needs to read the verdict.
///
/// Example:
/// ```dart
/// RiskBadge(level: RiskLevel.fromApi(assessment.overallRisk));
/// ```
class RiskBadge extends StatelessWidget {
  const RiskBadge({
    super.key,
    required this.level,
    this.size = RiskBadgeSize.medium,
    this.label,
  });

  /// Optional override for the displayed text. Defaults to the localized
  /// risk label so tests and design tokens stay consistent.
  final String? label;
  final RiskLevel level;
  final RiskBadgeSize size;

  /// Convenience constructor when the caller only has the raw API string.
  factory RiskBadge.fromApi({
    Key? key,
    required String? risk,
    RiskBadgeSize size = RiskBadgeSize.medium,
    String? label,
  }) =>
      RiskBadge(
        key: key,
        level: RiskLevel.fromApi(risk),
        size: size,
        label: label,
      );

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text =
        label ?? (l != null ? level.label(l) : _fallbackLabel(level));
    final color = level.color;
    final paddings = switch (size) {
      RiskBadgeSize.small => const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 4),
      RiskBadgeSize.medium => const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
      RiskBadgeSize.large => const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
    };
    final iconSize = switch (size) {
      RiskBadgeSize.small => 14.0,
      RiskBadgeSize.medium => 16.0,
      RiskBadgeSize.large => 20.0,
    };
    final fontSize = switch (size) {
      RiskBadgeSize.small => 11.0,
      RiskBadgeSize.medium => 13.0,
      RiskBadgeSize.large => 15.0,
    };

    return Container(
      padding: paddings,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: iconSize, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  /// Used only when [L] isn't yet attached (e.g. a bare widget test that
  /// constructs the badge without a [Localizations] ancestor). Falls back
  /// to a single dash so we never paint English copy in the tree.
  String _fallbackLabel(RiskLevel level) =>
      level == RiskLevel.unknown ? '—' : '•';
}

/// Compact, label-less variant for tight spots (list-row leading icons,
/// timeline dots). Pairs well with [RiskBadge] in the same screen so the
/// design language stays consistent.
class RiskDot extends StatelessWidget {
  const RiskDot({
    super.key,
    required this.level,
    this.size = 14,
  });

  factory RiskDot.fromApi({
    Key? key,
    required String? risk,
    double size = 14,
  }) =>
      RiskDot(
        key: key,
        level: RiskLevel.fromApi(risk),
        size: size,
      );

  final RiskLevel level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: level.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: level.color.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
