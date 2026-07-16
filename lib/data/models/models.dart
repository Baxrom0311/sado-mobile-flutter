// Simple data models without code generation for simplicity
// These match the API response exactly

import '../../domain/exercises/exercise_step.dart';

export '../../domain/exercises/exercise_step.dart'
    show
        ExerciseStep,
        InstructionStep,
        DemonstrateStep,
        RecordStep,
        FeedbackStep,
        UnknownStep;

export 'practice_plan.dart'
    show
        PracticePlan,
        PracticePlanItem,
        PracticePlanStatus,
        PracticePlanItemStatus;

class User {
  final String id;
  final String email;
  final String? phone;
  final String fullName;
  final String role;
  final String language;
  final bool isActive;
  final bool isVerified;
  final String? regionId;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    this.phone,
    required this.fullName,
    required this.role,
    required this.language,
    required this.isActive,
    required this.isVerified,
    this.regionId,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        language: (json['language'] as String?) ?? 'uz',
        isActive: (json['is_active'] as bool?) ?? true,
        isVerified: (json['is_verified'] as bool?) ?? false,
        regionId: json['region_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class TokenPair {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) => TokenPair(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresIn: json['expires_in'] as int,
      );
}

class Child {
  final String id;
  final String name;
  final DateTime birthDate;
  final String gender;
  final String? kindergartenId;
  final String parentId;
  final DateTime createdAt;

  const Child({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
    this.kindergartenId,
    required this.parentId,
    required this.createdAt,
  });

  factory Child.fromJson(Map<String, dynamic> json) => Child(
        id: json['id'] as String,
        name: json['name'] as String,
        birthDate: DateTime.parse(json['birth_date'] as String),
        gender: (json['gender'] as String?) ?? 'unknown',
        kindergartenId: json['kindergarten_id'] as String?,
        parentId: json['parent_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class Exercise {
  final String id;
  final String title;
  final String description;
  final String category;
  final String ageGroup;
  final String difficulty;
  final String language;
  final int durationMinutes;
  final String? audioExamplePath;
  final String? imagePath;
  final String? instructions;

  /// Phonemes this exercise targets (e.g. `['r', 'rr']`).
  ///
  /// The backend stores this as a Postgres `TEXT[]` column and serialises it
  /// to a JSON array. Older API builds (and older cached payloads written by
  /// previous versions of this app) used a comma-separated string instead,
  /// so [fromJson] is permissive and accepts either shape — never let
  /// stale cache crash a parent's session.
  final List<String>? targetPhonemes;
  final bool isActive;

  /// Ordered, structured lesson plan introduced by the API redesign in
  /// `PROJECT_BRIEF.md` §3 — see [ExerciseStep] for the type hierarchy.
  ///
  /// `null` (rather than `[]`) when the API does not ship steps for this
  /// exercise, so the UI can fall back to the legacy single-recording flow
  /// without ambiguity. This keeps every existing exercise card / detail
  /// screen working exactly as before — interactive playback only kicks in
  /// when the API has explicitly opted into the new format.
  final List<ExerciseStep>? steps;

  /// IDs of exercises that should be completed before this one is offered.
  /// Used by the recommender + the difficulty unlock UI; `null` means "no
  /// prerequisites".
  final List<String>? prerequisites;

  /// IDs of exercises this one unlocks on a successful score.
  final List<String>? unlocks;

  /// Score (0..1) the child must hit to count this exercise as passed.
  /// Defaults to `null` so call sites can apply their own policy when the
  /// API hasn't published an explicit threshold yet.
  final double? minScoreToPass;

  /// Soft cap on retries before the UI suggests an easier exercise.
  final int? maxAttempts;

  const Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.ageGroup,
    required this.difficulty,
    required this.language,
    required this.durationMinutes,
    this.audioExamplePath,
    this.imagePath,
    this.instructions,
    this.targetPhonemes,
    required this.isActive,
    this.steps,
    this.prerequisites,
    this.unlocks,
    this.minScoreToPass,
    this.maxAttempts,
  });

  /// Convenience: the exercise has a usable structured lesson plan.
  /// Empty / null `steps` falls through to the legacy free-form flow.
  bool get hasInteractiveSteps => steps != null && steps!.isNotEmpty;

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: json['category'] as String,
        ageGroup: json['age_group'] as String,
        difficulty: json['difficulty'] as String,
        language: (json['language'] as String?) ?? 'uz',
        durationMinutes: json['duration_minutes'] as int,
        audioExamplePath: json['audio_example_path'] as String?,
        imagePath: json['image_path'] as String?,
        instructions: json['instructions'] as String?,
        targetPhonemes: _parsePhonemes(json['target_phonemes']),
        isActive: (json['is_active'] as bool?) ?? true,
        steps: _parseSteps(json['steps']),
        prerequisites: _parseStringList(json['prerequisites']),
        unlocks: _parseStringList(json['unlocks']),
        minScoreToPass: (json['min_score_to_pass'] as num?)?.toDouble(),
        maxAttempts: (json['max_attempts'] as num?)?.toInt(),
      );

  /// Tolerant parser for [targetPhonemes]:
  ///
  /// * `null` / empty → returns `null`
  /// * `List` (any element type) → trimmed string entries, dropping empties
  /// * `String` (legacy CSV) → split on comma, trimmed, dropping empties
  ///
  /// The result is also normalised to `null` when no phoneme survived,
  /// so call sites only need a single null check (`?? []` style is a code
  /// smell when the empty case carries semantic weight, e.g. "this
  /// exercise has no phoneme target").
  static List<String>? _parsePhonemes(Object? raw) {
    if (raw == null) return null;
    if (raw is List) {
      final cleaned = raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      return cleaned.isEmpty ? null : cleaned;
    }
    if (raw is String) {
      final cleaned = raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      return cleaned.isEmpty ? null : cleaned;
    }
    return null;
  }

  /// Returns `null` when the API field is missing / empty / unparseable —
  /// the calling UI uses `null` (not `[]`) as the signal to fall back to
  /// the legacy single-recording assessment flow.
  static List<ExerciseStep>? _parseSteps(Object? raw) {
    if (raw == null) return null;
    final parsed = ExerciseStep.fromJsonList(raw);
    return parsed.isEmpty ? null : parsed;
  }

  /// Tolerant parser for plain string-array fields like [prerequisites]
  /// and [unlocks]. Same nullability contract as [_parsePhonemes].
  static List<String>? _parseStringList(Object? raw) {
    if (raw == null) return null;
    if (raw is List) {
      final cleaned = raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      return cleaned.isEmpty ? null : cleaned;
    }
    if (raw is String) {
      final cleaned = raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      return cleaned.isEmpty ? null : cleaned;
    }
    return null;
  }
}

class Assessment {
  final String id;
  final String childId;
  final String? exerciseId;
  final String status;
  final String? overallRisk;
  final double? score;
  final String? audioPath;
  final DateTime createdAt;

  const Assessment({
    required this.id,
    required this.childId,
    this.exerciseId,
    required this.status,
    this.overallRisk,
    this.score,
    this.audioPath,
    required this.createdAt,
  });

  factory Assessment.fromJson(Map<String, dynamic> json) => Assessment(
        id: json['id'] as String,
        childId: json['child_id'] as String,
        exerciseId: json['exercise_id'] as String?,
        status: json['status'] as String,
        overallRisk: json['overall_risk'] as String?,
        score: (json['score'] as num?)?.toDouble(),
        audioPath: json['audio_path'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class Kindergarten {
  final String id;
  final String name;
  final String? address;
  final String? regionId;

  const Kindergarten({
    required this.id,
    required this.name,
    this.address,
    this.regionId,
  });

  factory Kindergarten.fromJson(Map<String, dynamic> json) => Kindergarten(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        regionId: json['region_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (address != null) 'address': address,
        if (regionId != null) 'region_id': regionId,
      };
}

class Region {
  final String id;
  final String name;
  final String code;
  final String type;
  final String? parentId;

  const Region({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    this.parentId,
  });

  factory Region.fromJson(Map<String, dynamic> json) => Region(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String,
        type: json['type'] as String,
        parentId: json['parent_id'] as String?,
      );
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        isRead: (json['is_read'] as bool?) ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class PaginatedResponse<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  const PaginatedResponse({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });
}

/// Phoneme-level analysis result for a single target phoneme.
///
/// Backed by the API's `analysis_results.phoneme_scores[]` JSON column.
/// Wire shape: `{"phoneme": "s", "accuracy": 0.81, "error_type": "distortion"}`
class PhonemeScore {
  /// IPA-like phoneme code (e.g. "r", "sh", "k").
  final String phoneme;

  /// Accuracy in [0..1]. Clamped on parse so the UI never has to defend.
  final double accuracy;

  /// One of `substitution`, `omission`, `distortion` — or `null` when the
  /// phoneme was produced correctly. Other values are tolerated and surface
  /// as the generic "other" label so a future backend rename doesn't crash
  /// the UI.
  final String? errorType;

  const PhonemeScore({
    required this.phoneme,
    required this.accuracy,
    this.errorType,
  });

  factory PhonemeScore.fromJson(Map<String, dynamic> json) {
    final raw = (json['accuracy'] as num?)?.toDouble() ?? 0.0;
    final clamped = raw < 0 ? 0.0 : (raw > 1 ? 1.0 : raw);
    final phoneme = (json['phoneme'] as String?)?.trim() ?? '';
    final err = (json['error_type'] as String?)?.trim();
    return PhonemeScore(
      phoneme: phoneme,
      accuracy: clamped,
      errorType: (err == null || err.isEmpty) ? null : err,
    );
  }

  /// Convenience: integer percent for display (rounded half-up).
  int get accuracyPercent => (accuracy * 100).round();
}

/// Aggregate fluency metrics for a single recording.
class FluencyScore {
  /// Speaking rate in syllables per second.
  final double? rate;

  /// Fraction of the recording spent in pauses, in [0..1].
  final double? pauseRatio;

  /// Number of detected repetitions (a stuttering indicator).
  final int? repetitions;

  const FluencyScore({this.rate, this.pauseRatio, this.repetitions});

  factory FluencyScore.fromJson(Map<String, dynamic> json) {
    double? clamp01(num? n) {
      if (n == null) return null;
      final v = n.toDouble();
      if (v.isNaN || v.isInfinite) return null;
      if (v < 0) return 0.0;
      if (v > 1) return 1.0;
      return v;
    }

    return FluencyScore(
      rate: (json['rate'] as num?)?.toDouble(),
      pauseRatio: clamp01(json['pause_ratio'] as num?),
      repetitions: (json['repetitions'] as num?)?.toInt(),
    );
  }

  bool get isEmpty =>
      rate == null && pauseRatio == null && repetitions == null;
}

/// Status bucket for one [VoiceQuality] metric.
///
/// Maps the numeric value into a parent-friendly traffic-light tier so
/// the UI can colour the tile without re-implementing the threshold
/// logic. The thresholds are kept in sync with the API
/// (`app/services/voice_quality.py`) — when the backend updates the
/// clinical bands the constants below should follow.
enum VoiceQualityStatus {
  /// The metric is missing / could not be computed (analyzer fell back).
  unknown,

  /// The metric is comfortably within the clinical-normal band.
  normal,

  /// The metric is mildly outside the normal band — worth flagging
  /// but not alarming.
  elevated,

  /// The metric is well outside the normal band; the app surfaces
  /// the matching clinical recommendation.
  abnormal,
}

/// Parent-friendly snapshot of the four clinical voice-quality
/// metrics produced by the API analyzer:
///
///   * [jitterLocalPct]    — cycle-to-cycle pitch perturbation (%)
///   * [shimmerLocalPct]   — cycle-to-cycle amplitude perturbation (%)
///   * [hnrDb]             — Harmonics-to-Noise Ratio (dB)
///   * [speechRateWpm]     — speaking rate in words-per-minute
///
/// We deliberately keep this model independent of where it was parsed
/// from: it ships from the API in two slightly different shapes —
/// the parent-safe envelope embeds the four numbers inside
/// `feature_summary`, while the therapist-grade envelope returns a
/// dedicated `voice_quality: {...}` map (with an optional `flags`
/// array). [VoiceQuality.tryFromMap] accepts either shape.
class VoiceQuality {
  /// Cycle-to-cycle fundamental-frequency perturbation in percent.
  /// Healthy adult speech typically lives below ~1.04%.
  final double? jitterLocalPct;

  /// Cycle-to-cycle amplitude perturbation in percent.
  /// Healthy adult speech typically lives below ~3.81%.
  final double? shimmerLocalPct;

  /// Harmonics-to-noise ratio in dB. Higher is cleaner.
  /// Sustained healthy adult voices usually land above ~20 dB.
  final double? hnrDb;

  /// Speaking rate in words-per-minute. Fluent child speech is
  /// roughly 100–180 WPM.
  final double? speechRateWpm;

  /// Stable string codes emitted by the backend when a metric is
  /// outside its clinical band. Surfaced here so the UI can swap
  /// to a "needs attention" headline without re-deriving the
  /// thresholds. Empty for the parent-safe envelope (which never
  /// includes flags).
  final List<String> flags;

  const VoiceQuality({
    this.jitterLocalPct,
    this.shimmerLocalPct,
    this.hnrDb,
    this.speechRateWpm,
    this.flags = const [],
  });

  // Clinical thresholds — kept in sync with
  // ``app/services/voice_quality.py``. When the backend revs these
  // constants the app should follow on the next release; they are
  // intentionally kept in code (not a remote config) so that
  // disagreement between server flags and client colours is impossible
  // for any given app version.
  static const double jitterHealthyMaxPct = 1.04;
  static const double shimmerHealthyMaxPct = 3.81;
  static const double hnrHealthyMinDb = 20.0;
  static const double speechRateNormalLowWpm = 100.0;
  static const double speechRateNormalHighWpm = 180.0;

  /// Parse the API's voice-quality map. Accepts the dedicated
  /// `voice_quality: {...}` block or a `feature_summary` map (which
  /// contains the same numeric keys but never a `flags` list).
  ///
  /// Returns `null` when the map is missing or contains none of the
  /// known keys, so callers can use it as a presence check.
  static VoiceQuality? tryFromMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return null;

    double? num01(Object? v) {
      if (v is! num) return null;
      final d = v.toDouble();
      return (d.isNaN || d.isInfinite) ? null : d;
    }

    final jitter = num01(raw['jitter_local_pct']);
    final shimmer = num01(raw['shimmer_local_pct']);
    final hnr = num01(raw['hnr_db']);
    final wpm = num01(raw['speech_rate_wpm']);

    final flagsRaw = raw['flags'];
    List<String> flags = const [];
    if (flagsRaw is List) {
      flags = flagsRaw
          .map((e) => (e?.toString() ?? '').trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    if (jitter == null &&
        shimmer == null &&
        hnr == null &&
        wpm == null &&
        flags.isEmpty) {
      return null;
    }

    return VoiceQuality(
      jitterLocalPct: jitter,
      shimmerLocalPct: shimmer,
      hnrDb: hnr,
      speechRateWpm: wpm,
      flags: flags,
    );
  }

  bool get isEmpty =>
      jitterLocalPct == null &&
      shimmerLocalPct == null &&
      hnrDb == null &&
      speechRateWpm == null;

  /// True when a metric exists AND is meaningful (>0 for HNR / WPM,
  /// the others are inherently non-negative). Used by the widget to
  /// distinguish "metric reported zero" (still surfaceable) from
  /// "metric was never produced".
  bool get hasJitter => jitterLocalPct != null;
  bool get hasShimmer => shimmerLocalPct != null;
  bool get hasHnr => hnrDb != null && hnrDb! > 0;
  bool get hasSpeechRate => speechRateWpm != null && speechRateWpm! > 0;

  VoiceQualityStatus get jitterStatus {
    final v = jitterLocalPct;
    if (v == null) return VoiceQualityStatus.unknown;
    if (v <= jitterHealthyMaxPct) return VoiceQualityStatus.normal;
    if (v <= jitterHealthyMaxPct * 2) return VoiceQualityStatus.elevated;
    return VoiceQualityStatus.abnormal;
  }

  VoiceQualityStatus get shimmerStatus {
    final v = shimmerLocalPct;
    if (v == null) return VoiceQualityStatus.unknown;
    if (v <= shimmerHealthyMaxPct) return VoiceQualityStatus.normal;
    if (v <= shimmerHealthyMaxPct * 1.5) return VoiceQualityStatus.elevated;
    return VoiceQualityStatus.abnormal;
  }

  VoiceQualityStatus get hnrStatus {
    final v = hnrDb;
    if (v == null || v <= 0) return VoiceQualityStatus.unknown;
    if (v >= hnrHealthyMinDb) return VoiceQualityStatus.normal;
    if (v >= hnrHealthyMinDb * 0.5) return VoiceQualityStatus.elevated;
    return VoiceQualityStatus.abnormal;
  }

  VoiceQualityStatus get speechRateStatus {
    final v = speechRateWpm;
    if (v == null || v <= 0) return VoiceQualityStatus.unknown;
    if (v >= speechRateNormalLowWpm && v <= speechRateNormalHighWpm) {
      return VoiceQualityStatus.normal;
    }
    // Allow ±25% of the band before flipping to abnormal.
    if (v >= speechRateNormalLowWpm * 0.75 &&
        v <= speechRateNormalHighWpm * 1.25) {
      return VoiceQualityStatus.elevated;
    }
    return VoiceQualityStatus.abnormal;
  }

  /// Worst-of-all-metrics rollup, used to colour the card header.
  VoiceQualityStatus get overallStatus {
    final all = [
      jitterStatus,
      shimmerStatus,
      hnrStatus,
      speechRateStatus,
    ].where((s) => s != VoiceQualityStatus.unknown);
    if (all.isEmpty) return VoiceQualityStatus.unknown;
    if (all.contains(VoiceQualityStatus.abnormal)) {
      return VoiceQualityStatus.abnormal;
    }
    if (all.contains(VoiceQualityStatus.elevated)) {
      return VoiceQualityStatus.elevated;
    }
    return VoiceQualityStatus.normal;
  }

  /// Element-wise mean of two [VoiceQuality] snapshots, used to
  /// aggregate per-recording numbers up to the assessment level.
  /// Missing values are skipped so a single recording with one bad
  /// number doesn't poison the average.
  static VoiceQuality? mean(Iterable<VoiceQuality> snapshots) {
    final list = snapshots.toList(growable: false);
    if (list.isEmpty) return null;

    double? avg(double? Function(VoiceQuality) pick) {
      double sum = 0;
      int n = 0;
      for (final s in list) {
        final v = pick(s);
        if (v == null) continue;
        sum += v;
        n++;
      }
      return n == 0 ? null : sum / n;
    }

    final flags = <String>{};
    for (final s in list) {
      flags.addAll(s.flags);
    }

    final result = VoiceQuality(
      jitterLocalPct: avg((s) => s.jitterLocalPct),
      shimmerLocalPct: avg((s) => s.shimmerLocalPct),
      hnrDb: avg((s) => s.hnrDb),
      speechRateWpm: avg((s) => s.speechRateWpm),
      flags: flags.toList(growable: false),
    );
    return result.isEmpty && result.flags.isEmpty ? null : result;
  }
}

enum RecommendationPriority { low, medium, high }

extension RecommendationPriorityX on RecommendationPriority {
  static RecommendationPriority fromWire(String? raw) {
    final v = (raw ?? '').toLowerCase().trim();
    if (v == 'high') return RecommendationPriority.high;
    if (v == 'medium' || v == 'med') return RecommendationPriority.medium;
    return RecommendationPriority.low;
  }
}

/// One actionable recommendation produced by the analyzer.
class AnalysisRecommendation {
  /// Free-form category code from the API (e.g. `home_practice`,
  /// `referral`, `exercise`). Not user-facing — we keep it for analytics
  /// and so future versions can map to icons.
  final String? type;

  /// Human-readable message — already localized server-side. The UI does
  /// not translate; it just renders.
  final String message;

  /// Display priority; controls the colored dot on the bullet.
  final RecommendationPriority priority;

  const AnalysisRecommendation({
    this.type,
    required this.message,
    required this.priority,
  });

  factory AnalysisRecommendation.fromJson(Map<String, dynamic> json) {
    return AnalysisRecommendation(
      type: (json['type'] as String?)?.trim(),
      message: (json['message'] as String?)?.trim() ?? '',
      priority: RecommendationPriorityX.fromWire(json['priority'] as String?),
    );
  }
}

/// Per-recording analysis row — one entry per microphone capture inside
/// a single assessment. Mirrors FastAPI's `AnalysisPublic` schema.
///
/// The parent-safe endpoint exposes only opaque [featureSummary] data;
/// we surface a few well-known keys via getters so widgets don't have
/// to spelunk the map themselves.
class RecordingAnalysis {
  /// Stable backend id of the audio recording this analysis belongs to.
  final String recordingId;

  /// `green` / `yellow` / `red` per the API contract.
  final String riskLevel;

  /// Model confidence in [0..1]. Clamped on parse.
  final double confidence;

  /// Best-effort STT transcript of what the child said. Optional —
  /// older recordings produced before the analyzer was wired up have
  /// no transcript.
  final String? transcript;

  /// Free-form bag of acoustic + linguistic features. Stable keys
  /// produced by the current analyzer (`mock-xgb-v1`):
  ///   * `duration_sec`            (num)
  ///   * `sample_rate`             (int)
  ///   * `n_frames`                (int)
  ///   * `transcript_word_count`   (int)
  ///   * `voiced_ratio`            (num in [0..1])
  ///   * `f0_mean`                 (num, Hz)
  ///   * `f1_mean`, `f2_mean`      (num, Hz)
  ///   * `weakest_phonemes`        (list of phoneme codes)
  ///   * `rationale`               (per-feature score breakdown)
  ///
  /// Future analyzers may add keys; we deliberately keep the bag
  /// dynamic so this model never has to be revved in lockstep.
  final Map<String, dynamic>? featureSummary;

  /// Model identity — surfaced verbatim in About / settings for support.
  final String? modelName;
  final String? modelVersion;

  /// When the analysis row landed in the database.
  final DateTime? createdAt;

  /// Optional dedicated voice-quality block. Only the therapist-grade
  /// `AnalysisDetailedPublic` API surface populates this; the parent-
  /// safe envelope keeps the same numbers in [featureSummary] and
  /// they are surfaced via the [voiceQuality] getter below.
  final VoiceQuality? voiceQualityBlock;

  const RecordingAnalysis({
    required this.recordingId,
    required this.riskLevel,
    required this.confidence,
    this.transcript,
    this.featureSummary,
    this.modelName,
    this.modelVersion,
    this.createdAt,
    this.voiceQualityBlock,
  });

  factory RecordingAnalysis.fromJson(Map<String, dynamic> json) {
    final rawConf = (json['confidence'] as num?)?.toDouble() ?? 0.0;
    final clamped = rawConf < 0 ? 0.0 : (rawConf > 1 ? 1.0 : rawConf);

    DateTime? parseDate(Object? raw) {
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    Map<String, dynamic>? fs;
    final fsRaw = json['feature_summary'];
    if (fsRaw is Map) fs = Map<String, dynamic>.from(fsRaw);

    Map<String, dynamic>? vqRaw;
    final vqJson = json['voice_quality'];
    if (vqJson is Map) vqRaw = Map<String, dynamic>.from(vqJson);

    return RecordingAnalysis(
      recordingId: (json['recording_id'] as String?) ?? '',
      riskLevel: (json['risk_level'] as String?)?.trim() ?? '',
      confidence: clamped,
      transcript: (json['transcript'] as String?)?.trim().isEmpty == true
          ? null
          : (json['transcript'] as String?)?.trim(),
      featureSummary: fs,
      modelName: (json['model_name'] as String?)?.trim(),
      modelVersion: (json['model_version'] as String?)?.trim(),
      createdAt: parseDate(json['created_at']),
      voiceQualityBlock: VoiceQuality.tryFromMap(vqRaw),
    );
  }

  // ─── Convenience getters into [featureSummary] ────────────────────

  /// Phoneme codes flagged as the bottom-three by the analyzer for
  /// this recording. Empty when the key is missing.
  List<String> get weakestPhonemes {
    final raw = featureSummary?['weakest_phonemes'];
    if (raw is! List) return const [];
    return raw
        .map((e) => (e?.toString() ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// Fraction of the recording that contained voice, in [0..1].
  double? get voicedRatio {
    final raw = featureSummary?['voiced_ratio'];
    if (raw is! num) return null;
    final v = raw.toDouble();
    if (v.isNaN || v.isInfinite) return null;
    return v < 0 ? 0.0 : (v > 1 ? 1.0 : v);
  }

  /// Estimated mean fundamental frequency (Hz). Useful for "average
  /// pitch" callouts on the parent UI.
  double? get f0Mean {
    final raw = featureSummary?['f0_mean'];
    if (raw is! num) return null;
    final v = raw.toDouble();
    return (v.isNaN || v.isInfinite) ? null : v;
  }

  /// Wall-clock duration of the recording in seconds.
  double? get durationSec {
    final raw = featureSummary?['duration_sec'];
    if (raw is! num) return null;
    final v = raw.toDouble();
    return v.isFinite ? v : null;
  }

  /// Number of words in the transcript.
  int? get transcriptWordCount {
    final raw = featureSummary?['transcript_word_count'];
    return (raw is num) ? raw.toInt() : null;
  }

  /// Best-effort voice-quality snapshot for this recording. Prefers the
  /// dedicated `voice_quality` block when present (therapist-grade
  /// payloads include `flags`), and falls back to parsing the same
  /// numeric keys out of [featureSummary] (the parent-safe payload).
  VoiceQuality? get voiceQuality =>
      voiceQualityBlock ?? VoiceQuality.tryFromMap(featureSummary);
}

/// AI speech-analysis envelope returned by `GET /analysis/{id}`.
///
/// All fields are optional because:
///   * the analyzer may still be running (status `pending`)
///   * legacy assessments created before the AI pipeline existed have no
///     analysis row at all and the API may return an empty object
///
/// The model accepts BOTH the production wire shape (with `results: [...]`
/// per recording) and a richer "explicit" shape with top-level
/// `phoneme_scores`, `fluency_score`, `recommendations` arrays — the
/// latter is forward-compatible with future therapist-grade endpoints
/// that may flatten the per-recording data, and keeps unit tests
/// surgical without having to mock the full nested envelope.
class AssessmentAnalysis {
  final String? assessmentId;

  /// Per-recording results parsed straight from the API payload. Empty
  /// when the API returned a flat / explicit shape.
  final List<RecordingAnalysis> results;

  /// Per-phoneme accuracy scores. Populated only when a future
  /// (therapist-tier) endpoint flattens scores into the response.
  /// Empty list for the parent-safe `/analysis/{id}` endpoint, which
  /// never exposes raw scores.
  final List<PhonemeScore> phonemeScores;

  /// Fluency snapshot — either explicit (legacy / future) or derived
  /// from per-recording [featureSummary] (production path).
  final FluencyScore? fluency;

  /// Localized recommendations. Either explicit from the API, or
  /// synthesized client-side from [weakestPhonemes] when the API
  /// only returns the parent-safe envelope (which has no recs).
  final List<AnalysisRecommendation> recommendations;

  /// Aggregated phoneme codes that need attention across all
  /// recordings. Deduped, in first-seen order.
  final List<String> weakestPhonemes;

  /// Best-of-the-recordings transcript — the first non-empty transcript
  /// the analyzer produced. Surfaced in the new "what was said" card.
  final String? transcript;

  /// Overall score on a 0–100 scale (when surfaced explicitly).
  final double? overallScore;

  /// Aggregate model confidence in [0..1] across the assessment.
  final double? overallConfidence;

  /// `green` / `yellow` / `red` per the API contract.
  final String? riskLevel;

  /// Identifier for the analyzer build that produced these numbers.
  final String? modelVersion;

  /// Wall-clock time the analysis took, in milliseconds.
  final int? processingTimeMs;

  /// Aggregated voice-quality snapshot across all per-recording
  /// analyses. The four metrics (jitter, shimmer, HNR, WPM) are
  /// element-wise averaged and the union of `flags` is preserved so
  /// the parent UI can surface a single "voice quality" card per
  /// assessment without losing any clinical signal.
  final VoiceQuality? voiceQuality;

  const AssessmentAnalysis({
    this.assessmentId,
    this.results = const [],
    this.phonemeScores = const [],
    this.fluency,
    this.recommendations = const [],
    this.weakestPhonemes = const [],
    this.transcript,
    this.overallScore,
    this.overallConfidence,
    this.riskLevel,
    this.modelVersion,
    this.processingTimeMs,
    this.voiceQuality,
  });

  factory AssessmentAnalysis.fromJson(Map<String, dynamic> json) {
    // ── Parse the per-recording results array (production path) ──
    final results = <RecordingAnalysis>[];
    final rawResults = json['results'];
    if (rawResults is List) {
      for (final r in rawResults) {
        if (r is Map) {
          results.add(
            RecordingAnalysis.fromJson(Map<String, dynamic>.from(r)),
          );
        }
      }
    }

    // ── Aggregate parent-friendly views from [results] ───────────
    final weakSet = <String>{};
    String? firstTranscript;
    double voicedSum = 0;
    int voicedN = 0;
    int wordCount = 0;
    double durationSum = 0;
    String? modelVersionFromResults;
    for (final r in results) {
      if (firstTranscript == null &&
          r.transcript != null &&
          r.transcript!.isNotEmpty) {
        firstTranscript = r.transcript;
      }
      for (final p in r.weakestPhonemes) {
        weakSet.add(p);
      }
      final vr = r.voicedRatio;
      if (vr != null) {
        voicedSum += vr;
        voicedN++;
      }
      final wc = r.transcriptWordCount;
      if (wc != null) wordCount += wc;
      final d = r.durationSec;
      if (d != null && d > 0) durationSum += d;
      modelVersionFromResults ??= r.modelVersion;
    }

    // Derive a [FluencyScore] from feature_summary when no explicit
    // fluency block is present in the payload.
    FluencyScore? derivedFluency;
    if (voicedN > 0 || (durationSum > 0 && wordCount > 0)) {
      final avgVoiced = voicedN > 0 ? voicedSum / voicedN : null;
      final rate = (durationSum > 0 && wordCount > 0)
          ? wordCount / durationSum
          : null;
      derivedFluency = FluencyScore(
        rate: rate,
        pauseRatio:
            avgVoiced != null ? (1 - avgVoiced).clamp(0.0, 1.0) : null,
        repetitions: null,
      );
    }

    // ── Optional explicit fields (legacy / future flat shape) ────
    List<PhonemeScore> parsePhonemes(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => PhonemeScore.fromJson(Map<String, dynamic>.from(m)))
          .where((p) => p.phoneme.isNotEmpty)
          .toList(growable: false);
    }

    List<AnalysisRecommendation> parseRecs(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) =>
              AnalysisRecommendation.fromJson(Map<String, dynamic>.from(m)))
          .where((r) => r.message.isNotEmpty)
          .toList(growable: false);
    }

    FluencyScore? parseFluency(Object? raw) {
      if (raw is! Map) return null;
      final f = FluencyScore.fromJson(Map<String, dynamic>.from(raw));
      return f.isEmpty ? null : f;
    }

    final explicitFluency = parseFluency(json['fluency_score']);
    final explicitPhonemes = parsePhonemes(json['phoneme_scores']);
    final explicitRecs = parseRecs(json['recommendations']);

    // ── Voice quality: aggregate per-recording snapshots up to the
    //    assessment level, and prefer an explicit top-level
    //    `voice_quality: {...}` block when the API surfaces one. The
    //    explicit shape wins because it is what therapist-grade
    //    endpoints emit; the per-recording rollup is the parent-safe
    //    fallback.
    final perRecordingVq = <VoiceQuality>[];
    for (final r in results) {
      final vq = r.voiceQuality;
      if (vq != null && !vq.isEmpty) perRecordingVq.add(vq);
    }
    final aggregateVq = VoiceQuality.mean(perRecordingVq);

    VoiceQuality? explicitVq;
    final explicitVqRaw = json['voice_quality'];
    if (explicitVqRaw is Map) {
      explicitVq = VoiceQuality.tryFromMap(
        Map<String, dynamic>.from(explicitVqRaw),
      );
    }

    return AssessmentAnalysis(
      assessmentId: json['assessment_id'] as String?,
      results: results,
      phonemeScores: explicitPhonemes,
      fluency: explicitFluency ?? derivedFluency,
      recommendations: explicitRecs,
      weakestPhonemes: weakSet.toList(growable: false),
      transcript: firstTranscript,
      overallScore: (json['overall_score'] as num?)?.toDouble(),
      overallConfidence: (json['overall_confidence'] as num?)?.toDouble(),
      riskLevel: ((json['risk_level'] as String?) ??
              (json['overall_risk'] as String?))
          ?.trim(),
      modelVersion:
          (json['model_version'] as String?)?.trim() ?? modelVersionFromResults,
      processingTimeMs: (json['processing_time_ms'] as num?)?.toInt(),
      voiceQuality: explicitVq ?? aggregateVq,
    );
  }

  /// True when the analyzer hasn't produced anything actionable yet.
  /// Used by the UI to show the "tahlil hozircha mavjud emas" placeholder
  /// instead of an empty card.
  bool get isEmpty =>
      phonemeScores.isEmpty &&
      recommendations.isEmpty &&
      fluency == null &&
      weakestPhonemes.isEmpty &&
      (transcript == null || transcript!.isEmpty) &&
      results.isEmpty &&
      voiceQuality == null;
}


/// Lifecycle status of an [ExerciseAssignment]. The API stores this as a
/// free-form string today, but only four values are surfaced through the
/// parent UI; everything else falls into [ExerciseAssignmentStatus.other]
/// so a future server-side rename never crashes the screen.
enum ExerciseAssignmentStatus { pending, inProgress, completed, skipped, other }

extension ExerciseAssignmentStatusX on ExerciseAssignmentStatus {
  /// Stable wire value (snake_case) for [ExerciseAssignmentStatus].
  String get wire {
    switch (this) {
      case ExerciseAssignmentStatus.pending:
        return 'pending';
      case ExerciseAssignmentStatus.inProgress:
        return 'in_progress';
      case ExerciseAssignmentStatus.completed:
        return 'completed';
      case ExerciseAssignmentStatus.skipped:
        return 'skipped';
      case ExerciseAssignmentStatus.other:
        return 'other';
    }
  }

  static ExerciseAssignmentStatus fromWire(String? raw) {
    final v = (raw ?? '').toLowerCase().trim();
    switch (v) {
      case 'pending':
      case 'assigned':
      case 'new':
        return ExerciseAssignmentStatus.pending;
      case 'in_progress':
      case 'in-progress':
      case 'started':
      case 'active':
        return ExerciseAssignmentStatus.inProgress;
      case 'completed':
      case 'done':
      case 'complete':
        return ExerciseAssignmentStatus.completed;
      case 'skipped':
      case 'cancelled':
      case 'canceled':
        return ExerciseAssignmentStatus.skipped;
      default:
        return ExerciseAssignmentStatus.other;
    }
  }
}

/// One therapist-assigned exercise — a piece of "homework" attached to a
/// specific child by a clinician. Mirrors FastAPI's
/// `ExerciseAssignmentPublic` schema and may carry an embedded
/// [Exercise] summary so the list view can render the title/category
/// without a follow-up fetch.
class ExerciseAssignment {
  final String id;
  final String childId;
  final String exerciseId;

  /// Therapist / teacher who issued the assignment. Null when the
  /// assignment was generated automatically (e.g. by the recommender).
  final String? assignedById;

  /// Lifecycle bucket. Always one of the [ExerciseAssignmentStatus]
  /// values — unknown wire codes coerce to [ExerciseAssignmentStatus.other].
  final ExerciseAssignmentStatus status;

  /// Optional deadline. Null = open-ended ("anytime") homework.
  final DateTime? dueDate;

  /// Wall-clock when [status] transitioned to `completed`. Null otherwise.
  final DateTime? completedAt;

  /// Therapist score on a 0–100 scale (server semantics). Optional.
  final double? score;

  /// Free-form clinician notes attached to this assignment.
  final String? notes;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Embedded summary of the underlying exercise — populated by the
  /// list endpoint so the UI can render category, title, target
  /// phonemes etc. without a follow-up GET.
  final Exercise? exercise;

  const ExerciseAssignment({
    required this.id,
    required this.childId,
    required this.exerciseId,
    this.assignedById,
    required this.status,
    this.dueDate,
    this.completedAt,
    this.score,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.exercise,
  });

  factory ExerciseAssignment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? raw) {
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    Exercise? embedded;
    final rawEx = json['exercise'];
    if (rawEx is Map) {
      try {
        embedded = Exercise.fromJson(Map<String, dynamic>.from(rawEx));
      } catch (_) {
        // Defensive: a malformed embedded exercise never crashes the list.
        embedded = null;
      }
    }

    return ExerciseAssignment(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      exerciseId: json['exercise_id'] as String,
      assignedById: json['assigned_by_id'] as String?,
      status: ExerciseAssignmentStatusX.fromWire(json['status'] as String?),
      dueDate: parseDate(json['due_date']),
      completedAt: parseDate(json['completed_at']),
      score: (json['score'] as num?)?.toDouble(),
      notes: (json['notes'] as String?)?.trim().isEmpty == true
          ? null
          : (json['notes'] as String?)?.trim(),
      createdAt:
          parseDate(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          parseDate(json['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      exercise: embedded,
    );
  }

  /// Convenience: true when the assignment is past its due date and
  /// hasn't been marked completed yet.
  bool get isOverdue {
    final due = dueDate;
    if (due == null) return false;
    if (status == ExerciseAssignmentStatus.completed) return false;
    return due.isBefore(DateTime.now());
  }

  /// Convenience: true when the assignment is still actionable (pending
  /// or in-progress) — drives the "Today's homework" CTA on home.
  bool get isActionable =>
      status == ExerciseAssignmentStatus.pending ||
      status == ExerciseAssignmentStatus.inProgress;

  /// Lightweight JSON representation suitable for the offline cache.
  Map<String, dynamic> toJson() => {
        'id': id,
        'child_id': childId,
        'exercise_id': exerciseId,
        'assigned_by_id': assignedById,
        'status': status.wire,
        'due_date': dueDate?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'score': score,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (exercise != null)
          'exercise': {
            'id': exercise!.id,
            'title': exercise!.title,
            'description': exercise!.description,
            'category': exercise!.category,
            'age_group': exercise!.ageGroup,
            'difficulty': exercise!.difficulty,
            'language': exercise!.language,
            'duration_minutes': exercise!.durationMinutes,
            'audio_example_path': exercise!.audioExamplePath,
            'image_path': exercise!.imagePath,
            'instructions': exercise!.instructions,
            'target_phonemes': exercise!.targetPhonemes,
            'is_active': exercise!.isActive,
          },
      };
}
