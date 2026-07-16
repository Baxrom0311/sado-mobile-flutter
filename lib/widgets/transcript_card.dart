import 'package:flutter/material.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import 'premium_card.dart';

/// Premium card displaying the AI's best-guess transcript of what the
/// child said during the assessment.
///
/// High-affinity feature for parents — being able to see the recognised
/// words in their own language is one of the most concrete signals that
/// the AI pipeline is working. The card uses a quoted-style typography
/// so it reads as speech rather than as analysis output.
///
/// Renders nothing when [text] is null or whitespace-only so it can be
/// dropped into a column without guarding the empty case.
class TranscriptCard extends StatelessWidget {
  const TranscriptCard({super.key, required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final clean = (text ?? '').trim();
    if (clean.isEmpty) return const SizedBox.shrink();
    final l = L.of(context)!;

    return PremiumCard(
      key: const ValueKey('analysis.transcriptCard'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: AppColors.tertiary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.transcriptTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.transcriptSubtitle,
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
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.tertiary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.tertiary.withValues(alpha: 0.18),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  color: AppColors.tertiary.withValues(alpha: 0.7),
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    clean,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
