import 'package:flutter/material.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import 'premium_card.dart';

/// Premium card highlighting the phonemes the AI flagged as needing
/// attention.
///
/// The parent-safe analysis endpoint never exposes per-phoneme accuracy
/// scores — it only surfaces the bottom-three phoneme codes via
/// `feature_summary.weakest_phonemes`. This widget renders those codes
/// as branded chips so parents see a clear "focus on these sounds"
/// callout without us having to invent fake percentages.
///
/// Renders nothing when [phonemes] is empty so callers can drop the
/// widget into a column without guarding the empty case themselves.
class WeakPhonemesCard extends StatelessWidget {
  const WeakPhonemesCard({super.key, required this.phonemes});

  /// Ordered, deduped list of phoneme codes (e.g. `['r', 'sh', 'k']`).
  final List<String> phonemes;

  @override
  Widget build(BuildContext context) {
    if (phonemes.isEmpty) return const SizedBox.shrink();
    final l = L.of(context)!;

    return PremiumCard(
      key: const ValueKey('analysis.weakPhonemesCard'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Semantics(
        container: true,
        label: l.weakPhonemesSemantics(phonemes.length),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.priority_high_rounded,
                    color: AppColors.warning,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.weakPhonemesTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.weakPhonemesSubtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final p in phonemes) _PhonemeChip(phoneme: p),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhonemeChip extends StatelessWidget {
  const _PhonemeChip({required this.phoneme});
  final String phoneme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: phoneme,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.35),
            width: 1.4,
          ),
        ),
        child: Text(
          phoneme,
          style: const TextStyle(
            color: AppColors.warning,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
