import 'package:flutter/material.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../domain/speech_profile/phoneme_mastery.dart';
import 'premium_card.dart';

/// Premium grid of phoneme tiles, color-coded by mastery bucket.
///
/// Each tile shows:
///   * the phoneme glyph in the centre
///   * an inner accuracy ring (animated from 0 → accuracy on first build)
///   * a sample-count chip for accessibility users / motivated parents
///
/// When [onPhonemeTap] is supplied the tiles become tappable (and read
/// to assistive tech as buttons) so the parent can drill into a
/// per-phoneme practice screen. When `null` the tiles render as static
/// chips.
///
/// Renders nothing when [phonemes] is empty so callers can drop the
/// widget into a column without guarding the empty case themselves.
class PhonemeMasteryGrid extends StatelessWidget {
  const PhonemeMasteryGrid({
    super.key,
    required this.phonemes,
    this.onPhonemeTap,
  });

  final List<PhonemeMastery> phonemes;
  final ValueChanged<PhonemeMastery>? onPhonemeTap;

  /// Mastery bucket → tile colour palette. Mirrors the risk badge
  /// colours used elsewhere so the language is consistent.
  static Color colorFor(PhonemeMasteryLevel level) {
    switch (level) {
      case PhonemeMasteryLevel.struggling:
        return AppColors.danger;
      case PhonemeMasteryLevel.developing:
        return AppColors.warning;
      case PhonemeMasteryLevel.mastered:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    if (phonemes.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Semantics(
        container: true,
        label: l.speechProfileGridSemantics(phonemes.length),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Aim for ~84 px tiles; clamp to a 4-6 column grid so the
            // layout reads well across phones and tablets.
            final w = constraints.maxWidth;
            final columns = (w / 96).floor().clamp(4, 6);
            final spacing = AppSpacing.sm;
            final tileSize =
                (w - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final p in phonemes)
                  SizedBox(
                    width: tileSize,
                    height: tileSize,
                    child: _PhonemeTile(
                      mastery: p,
                      onTap: onPhonemeTap == null
                          ? null
                          : () => onPhonemeTap!(p),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PhonemeTile extends StatelessWidget {
  const _PhonemeTile({required this.mastery, this.onTap});
  final PhonemeMastery mastery;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final color = PhonemeMasteryGrid.colorFor(mastery.level);

    final tile = Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Accuracy ring — animates from 0 → accuracy on build.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0, end: mastery.accuracy),
                builder: (_, value, __) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mastery.phoneme,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.phonemeAccuracyPercent(mastery.accuracyPercent),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label: l.speechProfilePhonemeTile(
        mastery.phoneme,
        mastery.accuracyPercent,
      ),
      child: onTap == null
          ? tile
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: onTap,
                child: tile,
              ),
            ),
    );
  }
}
