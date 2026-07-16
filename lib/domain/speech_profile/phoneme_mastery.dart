/// Pure aggregation logic for the Speech Profile screen.
///
/// Given a list of [AssessmentAnalysis] envelopes (one per assessment),
/// this module collapses them into a per-phoneme mastery snapshot the
/// parent UI can render directly:
///
///   * a list of [PhonemeMastery] entries — one per phoneme the analyzer
///     has touched at least once — sorted with the weakest phonemes
///     first so the "focus areas" callout is immediate;
///   * convenience getters for the top mastered / struggling buckets;
///   * an overall mastery percentage.
///
/// The logic is intentionally framework-free so it can be unit-tested
/// without spinning up a widget tree, and so the same code can drive
/// future surfaces (e.g. an admin export) without depending on
/// Riverpod / Flutter.
library;

import '../../data/models/models.dart';

/// Mastery bucket for a single phoneme. Maps to the green / yellow /
/// red palette already used by the rest of the app.
enum PhonemeMasteryLevel {
  /// 0–34% — child consistently struggles with this phoneme.
  struggling,

  /// 35–69% — child is making progress but not yet consistent.
  developing,

  /// 70–100% — child reliably produces this phoneme.
  mastered,
}

/// Snapshot for one phoneme aggregated across every assessment in the
/// supplied window.
class PhonemeMastery {
  /// IPA-like phoneme code, lower-cased and trimmed (e.g. "r", "sh").
  final String phoneme;

  /// Number of recordings that included this phoneme in their analysis
  /// (either via explicit [PhonemeScore] entries or the
  /// `weakest_phonemes` parent-safe bag).
  final int sampleCount;

  /// Number of recordings where the phoneme was flagged as weak — i.e.
  /// it appeared in the `weakest_phonemes` array OR its explicit score
  /// fell below 0.7.
  final int weakCount;

  /// Mean per-phoneme accuracy, in [0..1]. When the underlying data
  /// only came from the parent-safe `weakest_phonemes` envelope (no
  /// numeric scores), this is derived from `1 - weakCount/sampleCount`
  /// so the UI still has a number to show.
  final double accuracy;

  const PhonemeMastery({
    required this.phoneme,
    required this.sampleCount,
    required this.weakCount,
    required this.accuracy,
  });

  /// Bucket the [accuracy] into a tri-color band so the UI can color
  /// chips consistently with the rest of the app.
  PhonemeMasteryLevel get level {
    if (accuracy >= 0.70) return PhonemeMasteryLevel.mastered;
    if (accuracy >= 0.35) return PhonemeMasteryLevel.developing;
    return PhonemeMasteryLevel.struggling;
  }

  /// Convenience: integer percent for display (rounded half-up).
  int get accuracyPercent => (accuracy * 100).round();
}

/// Aggregate snapshot for one child. Empty when the analyzer has never
/// produced anything actionable for this child yet — the screen renders
/// the empty state on [isEmpty].
class SpeechProfile {
  /// Per-phoneme mastery, sorted with [PhonemeMasteryLevel.struggling]
  /// first, then [PhonemeMasteryLevel.developing], then
  /// [PhonemeMasteryLevel.mastered]. Within each bucket, phonemes are
  /// ordered by ascending [PhonemeMastery.accuracy] so the UI surfaces
  /// the lowest first.
  final List<PhonemeMastery> phonemes;

  /// How many assessments contributed to this snapshot.
  final int assessmentCount;

  /// How many of those assessments produced a non-empty analysis. May
  /// be lower than [assessmentCount] when the analyzer is still
  /// processing some recordings.
  final int analysedCount;

  const SpeechProfile({
    required this.phonemes,
    required this.assessmentCount,
    required this.analysedCount,
  });

  /// Convenience constructor used by the provider when the child has
  /// never been assessed yet.
  const SpeechProfile.empty()
      : phonemes = const [],
        assessmentCount = 0,
        analysedCount = 0;

  /// True when there are no per-phoneme insights to render.
  bool get isEmpty => phonemes.isEmpty;

  /// Phonemes the child reliably produces (mastered bucket only).
  List<PhonemeMastery> get mastered =>
      phonemes.where((p) => p.level == PhonemeMasteryLevel.mastered).toList();

  /// Phonemes still in active practice (developing bucket only).
  List<PhonemeMastery> get developing =>
      phonemes.where((p) => p.level == PhonemeMasteryLevel.developing).toList();

  /// Top phonemes that need attention (struggling bucket only).
  List<PhonemeMastery> get struggling =>
      phonemes.where((p) => p.level == PhonemeMasteryLevel.struggling).toList();

  /// Average accuracy across every tracked phoneme, in [0..1]. Returns
  /// 0 when [phonemes] is empty so the UI can display a meaningful
  /// number even on cold start.
  double get overallAccuracy {
    if (phonemes.isEmpty) return 0.0;
    var sum = 0.0;
    for (final p in phonemes) {
      sum += p.accuracy;
    }
    return sum / phonemes.length;
  }

  /// Convenience: integer percent for display.
  int get overallAccuracyPercent => (overallAccuracy * 100).round();
}

/// Aggregator entry point.
///
/// Phoneme codes are normalized via [PhonemeMasteryAggregator.normalize]
/// before being grouped (lower-case, trimmed, slash/dot-stripped) so
/// `"R"`, `"r"`, and `"/r/"` all collapse onto the same bucket — this
/// matters because some analyzer payloads quote phonemes with slashes
/// while others don't.
class PhonemeMasteryAggregator {
  const PhonemeMasteryAggregator._();

  /// Threshold below which a numeric [PhonemeScore.accuracy] is
  /// treated as a "weak" attempt by the parent-friendly view. Mirrors
  /// the green-band threshold used in [PhonemeMastery.level].
  static const double weakAccuracyThreshold = 0.70;

  /// Normalises a raw phoneme code into the canonical form used to
  /// group entries together. Returns the empty string for inputs that
  /// can't be parsed (caller should drop those).
  static String normalize(String raw) {
    final trimmed = raw.trim().toLowerCase();
    // Strip phonetic slashes / brackets that some payloads include
    // around the symbol (e.g. "/r/" → "r", "[s]" → "s").
    final stripped = trimmed.replaceAll(RegExp(r'[\\/\[\]\.]'), '');
    return stripped;
  }

  /// Builds a [SpeechProfile] from a list of analyses for one child.
  ///
  /// Inputs:
  ///   * [analyses] — one envelope per assessment; an empty envelope
  ///     (i.e. [AssessmentAnalysis.isEmpty]) is counted toward
  ///     [SpeechProfile.assessmentCount] but contributes nothing to
  ///     the per-phoneme buckets.
  ///   * [assessmentCount] — total number of assessments observed
  ///     (defaults to `analyses.length`). Pass a higher value when
  ///     some analyses failed to load and you want the UI to reflect
  ///     the true denominator.
  static SpeechProfile aggregate(
    List<AssessmentAnalysis> analyses, {
    int? assessmentCount,
  }) {
    if (analyses.isEmpty) {
      return SpeechProfile(
        phonemes: const [],
        assessmentCount: assessmentCount ?? 0,
        analysedCount: 0,
      );
    }

    // phoneme → running totals.
    final samples = <String, int>{};
    final weak = <String, int>{};
    final scoreSums = <String, double>{};
    final scoreCounts = <String, int>{};

    var analysed = 0;
    for (final a in analyses) {
      if (a.isEmpty) continue;
      analysed++;

      // 1) Explicit per-phoneme scores (therapist-tier endpoint).
      for (final score in a.phonemeScores) {
        final code = normalize(score.phoneme);
        if (code.isEmpty) continue;
        samples[code] = (samples[code] ?? 0) + 1;
        scoreSums[code] = (scoreSums[code] ?? 0) + score.accuracy;
        scoreCounts[code] = (scoreCounts[code] ?? 0) + 1;
        if (score.accuracy < weakAccuracyThreshold) {
          weak[code] = (weak[code] ?? 0) + 1;
        }
      }

      // 2) Parent-safe `weakest_phonemes` bag — one per recording.
      for (final r in a.results) {
        // Phonemes flagged as weak count as both a "sample" (we know
        // the analyzer looked at this phoneme) AND a "weak" attempt.
        // We track by recording so a child who repeatedly stumbles on
        // /r/ across three recordings shows three weak attempts.
        for (final raw in r.weakestPhonemes) {
          final code = normalize(raw);
          if (code.isEmpty) continue;
          samples[code] = (samples[code] ?? 0) + 1;
          weak[code] = (weak[code] ?? 0) + 1;
        }
      }

      // 3) Aggregate `weakestPhonemes` (already-deduped envelope-level
      // list). Skip when we've already covered them via the
      // per-recording loop to avoid double counting — the envelope
      // list is just a deduped view of the per-recording lists.
      if (a.results.isEmpty) {
        for (final raw in a.weakestPhonemes) {
          final code = normalize(raw);
          if (code.isEmpty) continue;
          samples[code] = (samples[code] ?? 0) + 1;
          weak[code] = (weak[code] ?? 0) + 1;
        }
      }
    }

    if (samples.isEmpty) {
      return SpeechProfile(
        phonemes: const [],
        assessmentCount: assessmentCount ?? analyses.length,
        analysedCount: analysed,
      );
    }

    // Build the per-phoneme list. When we have explicit numeric scores
    // we average them; otherwise we synthesise an accuracy from the
    // weak-attempt ratio so the UI still has a colour to render.
    final list = <PhonemeMastery>[];
    samples.forEach((code, samp) {
      final w = weak[code] ?? 0;
      final scoredN = scoreCounts[code] ?? 0;
      double accuracy;
      if (scoredN > 0) {
        accuracy = (scoreSums[code] ?? 0) / scoredN;
      } else {
        // Pure parent-safe data: every "sample" is a weak attempt by
        // construction, so 1 - weak/sample fairly represents the
        // child's success rate on that phoneme.
        accuracy = samp == 0 ? 0.0 : (1.0 - (w / samp));
      }
      // Defensive clamp.
      if (accuracy.isNaN || accuracy.isInfinite) accuracy = 0.0;
      if (accuracy < 0) accuracy = 0.0;
      if (accuracy > 1) accuracy = 1.0;

      list.add(
        PhonemeMastery(
          phoneme: code,
          sampleCount: samp,
          weakCount: w,
          accuracy: accuracy,
        ),
      );
    });

    // Sort: struggling first, then developing, then mastered.
    // Inside each bucket: ascending accuracy (worst first) so the
    // child's most pressing focus area lands at the top.
    int bucketRank(PhonemeMasteryLevel l) {
      switch (l) {
        case PhonemeMasteryLevel.struggling:
          return 0;
        case PhonemeMasteryLevel.developing:
          return 1;
        case PhonemeMasteryLevel.mastered:
          return 2;
      }
    }

    list.sort((a, b) {
      final byBucket = bucketRank(a.level).compareTo(bucketRank(b.level));
      if (byBucket != 0) return byBucket;
      final byAccuracy = a.accuracy.compareTo(b.accuracy);
      if (byAccuracy != 0) return byAccuracy;
      return a.phoneme.compareTo(b.phoneme);
    });

    return SpeechProfile(
      phonemes: List.unmodifiable(list),
      assessmentCount: assessmentCount ?? analyses.length,
      analysedCount: analysed,
    );
  }
}
