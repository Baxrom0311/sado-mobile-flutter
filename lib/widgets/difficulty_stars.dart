import 'package:flutter/material.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';

/// Compact 3-star indicator for an exercise's difficulty level.
///
/// API tokens map to a star count and a color:
///  * `easy`   → 1 filled star, [AppColors.success]
///  * `medium` → 2 filled stars, [AppColors.warning]
///  * `hard`   → 3 filled stars, [AppColors.danger]
///
/// Unknown tokens render zero filled stars in the muted text color so
/// the row never throws or shows a broken layout if the API ever adds
/// a new bucket before the app ships.
///
/// The widget can render either:
///  * A row of three pip-style stars only ([showLabel] = `false`), or
///  * The same row plus a localized text label (`Oson` / `O'rtacha` /
///    `Qiyin`) — useful in card hero positions where the meaning needs
///    to read at a glance ([showLabel] = `true`, the default).
///
/// The label is a [Semantics] node so screen readers announce the level
/// even when [showLabel] is `false`.
class DifficultyStars extends StatelessWidget {
  const DifficultyStars({
    super.key,
    required this.difficulty,
    this.size = 14,
    this.showLabel = true,
    this.spacing = 2,
  });

  /// API difficulty token. Expected values: `easy`, `medium`, `hard`.
  final String difficulty;

  /// Width and height of each star icon in logical pixels.
  final double size;

  /// Whether to render the localized text label beside the stars.
  final bool showLabel;

  /// Horizontal spacing between adjacent stars (in logical pixels).
  final double spacing;

  static const int _maxStars = 3;

  int _filledFor(String d) => switch (d) {
        'easy' => 1,
        'medium' => 2,
        'hard' => 3,
        _ => 0,
      };

  String _labelFor(L l, String d) => switch (d) {
        'easy' => l.easy,
        'medium' => l.medium,
        'hard' => l.hard,
        _ => d,
      };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final color = AppColors.difficultyColor(difficulty);
    final filled = _filledFor(difficulty);
    final label = _labelFor(l, difficulty);

    return Semantics(
      label: '${l.difficulty}: $label',
      // Avoid the screen reader announcing each individual star icon below.
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _maxStars; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Icon(
              i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < filled ? color : AppColors.textMuted,
            ),
          ],
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
