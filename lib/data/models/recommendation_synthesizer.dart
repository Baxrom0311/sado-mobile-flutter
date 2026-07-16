import 'package:sado_mobile/l10n/app_localizations.dart';

import '../models/models.dart';

/// Synthesise localized recommendations for a parent when the API only
/// returns the parent-safe analysis envelope (which omits actionable
/// recommendations on purpose).
///
/// Strategy:
///   * One high-priority "practice this phoneme" tip per weak phoneme
///     (capped at three so the list stays scannable).
///   * One medium-priority "consistency wins" reminder.
///   * One low-priority "celebrate progress" reminder.
///
/// The output is fully localised — keys live in the ARB files —
/// so this never violates the no-hardcoded-strings rule.
///
/// Returns an empty list when [weakestPhonemes] is empty AND no padding
/// is requested, which lets the caller hide the recommendations card
/// instead of showing two generic tips with no phoneme context.
List<AnalysisRecommendation> synthesizeRecommendations(
  L l,
  List<String> weakestPhonemes, {
  bool includeGenericTips = true,
  int maxPhonemeTips = 3,
}) {
  final recs = <AnalysisRecommendation>[];

  for (final p in weakestPhonemes.take(maxPhonemeTips)) {
    final clean = p.trim();
    if (clean.isEmpty) continue;
    recs.add(
      AnalysisRecommendation(
        type: 'practice_phoneme',
        message: l.synthesizedRecPracticePhoneme(clean),
        priority: RecommendationPriority.high,
      ),
    );
  }

  if (recs.isEmpty && !includeGenericTips) return const [];

  if (includeGenericTips) {
    recs.add(
      AnalysisRecommendation(
        type: 'consistency',
        message: l.synthesizedRecConsistency,
        priority: RecommendationPriority.medium,
      ),
    );
    recs.add(
      AnalysisRecommendation(
        type: 'celebrate',
        message: l.synthesizedRecCelebrate,
        priority: RecommendationPriority.low,
      ),
    );
  }

  return recs;
}
