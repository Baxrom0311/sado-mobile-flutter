/// Domain model for the new step-based interactive exercise format.
///
/// Backed by the API redesign described in `PROJECT_BRIEF.md` §3
/// ("Interactive Exercises Redesign") — every exercise can now ship with an
/// ordered list of [ExerciseStep]s describing how the lesson is presented to
/// the child, instead of just a free-form description and a single recording.
///
/// The four step kinds mirror the JSON shape from the brief:
///
///   * [InstructionStep] — narrator-style intro ("Hozir 'S' tovushini mashq
///     qilamiz"). Pure text, optional supporting audio.
///   * [DemonstrateStep] — therapist demonstration ("Tinglang va takrorlang"),
///     usually carries an `audio_url` and an `image_url` of the mouth shape.
///   * [RecordStep] — the child speaks. Carries a target word/phrase, the
///     phonemes being evaluated, and capture limits.
///   * [FeedbackStep] — celebration / retry copy. Optionally hides the score.
///
/// [ExerciseStep.fromJson] is intentionally permissive: unknown step types,
/// missing optional fields, and stale cached payloads must NEVER throw out
/// of a parent's session. Anything we cannot parse becomes [UnknownStep] so
/// the surrounding UI can still skip past it gracefully.
library;

import 'package:flutter/foundation.dart';

/// One ordered step inside an interactive exercise lesson.
///
/// Use the sealed-style hierarchy ([InstructionStep], [DemonstrateStep],
/// [RecordStep], [FeedbackStep], [UnknownStep]) plus [ExerciseStep.fromJson]
/// to safely parse the API payload.
@immutable
sealed class ExerciseStep {
  const ExerciseStep({
    required this.kind,
    this.durationSec,
  });

  /// Wire-format discriminator (e.g. `"instruction"`, `"demonstrate"`).
  ///
  /// Preserved as-is so debugging tools and analytics can still see the
  /// original token even after we've boxed an unknown type into
  /// [UnknownStep].
  final String kind;

  /// Suggested duration in seconds for auto-advancing instruction-like
  /// steps. `null` means "wait for the user". Always honours `> 0` only.
  final int? durationSec;

  /// Tolerant parser. Returns [UnknownStep] for anything we can't recognise
  /// rather than throwing — see file-level docs for the rationale.
  factory ExerciseStep.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String?)?.trim().toLowerCase() ?? '';
    final duration = _readPositiveInt(json['duration_sec']);
    switch (type) {
      case 'instruction':
        return InstructionStep(
          textUz: _readTrimmedString(json['text_uz']),
          textRu: _readTrimmedString(json['text_ru']),
          audioUrl: _readTrimmedString(json['audio_url']),
          durationSec: duration,
        );
      case 'demonstrate':
        return DemonstrateStep(
          textUz: _readTrimmedString(json['text_uz']),
          textRu: _readTrimmedString(json['text_ru']),
          audioUrl: _readTrimmedString(json['audio_url']),
          imageUrl: _readTrimmedString(json['image_url']),
          durationSec: duration,
        );
      case 'record':
        return RecordStep(
          promptUz: _readTrimmedString(json['prompt_uz']),
          promptRu: _readTrimmedString(json['prompt_ru']),
          targetWord: _readTrimmedString(json['target_word']),
          targetPhonemes: _readPhonemes(json['target_phonemes']),
          minDurationSec: _readPositiveInt(json['min_duration_sec']),
          maxDurationSec: _readPositiveInt(json['max_duration_sec']),
          durationSec: duration,
        );
      case 'feedback':
        return FeedbackStep(
          encouragementUz: _readTrimmedString(json['encouragement_uz']),
          encouragementRu: _readTrimmedString(json['encouragement_ru']),
          retryUz: _readTrimmedString(json['retry_uz']),
          retryRu: _readTrimmedString(json['retry_ru']),
          showScore: _readBool(json['show_score'], defaultValue: true),
          showPhonemeDetail:
              _readBool(json['show_phoneme_detail'], defaultValue: false),
          durationSec: duration,
        );
      default:
        return UnknownStep(rawType: type, durationSec: duration);
    }
  }

  /// Bulk parser used by [Exercise.fromJson]. Skips entries that are
  /// neither maps nor parseable.
  static List<ExerciseStep> fromJsonList(Object? raw) {
    if (raw is! List) return const [];
    final result = <ExerciseStep>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        result.add(ExerciseStep.fromJson(entry));
      } else if (entry is Map) {
        // Hive sometimes returns Map<dynamic, dynamic> — accept it.
        result.add(
          ExerciseStep.fromJson(
            entry.map((k, v) => MapEntry(k.toString(), v)),
          ),
        );
      }
    }
    return result;
  }
}

/// Narrator-style introduction step. Renders as a calm full-bleed card
/// with the parrot mascot in `talking` mood — no recording happens here.
class InstructionStep extends ExerciseStep {
  const InstructionStep({
    this.textUz,
    this.textRu,
    this.audioUrl,
    super.durationSec,
  }) : super(kind: 'instruction');

  final String? textUz;
  final String? textRu;
  final String? audioUrl;

  /// Resolves the localized copy for the supplied two-letter [locale]
  /// code. Falls back to the other locale or an empty string when the
  /// preferred one is missing — never returns `null`, so the UI can
  /// always render *something*.
  String localizedText(String locale) =>
      _pickLocalized(locale, uz: textUz, ru: textRu);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstructionStep &&
          other.textUz == textUz &&
          other.textRu == textRu &&
          other.audioUrl == audioUrl &&
          other.durationSec == durationSec;

  @override
  int get hashCode => Object.hash(textUz, textRu, audioUrl, durationSec);
}

/// Therapist demonstration step. Usually accompanied by an audio file
/// (the canonical pronunciation) and a mouth-shape image.
class DemonstrateStep extends ExerciseStep {
  const DemonstrateStep({
    this.textUz,
    this.textRu,
    this.audioUrl,
    this.imageUrl,
    super.durationSec,
  }) : super(kind: 'demonstrate');

  final String? textUz;
  final String? textRu;
  final String? audioUrl;
  final String? imageUrl;

  String localizedText(String locale) =>
      _pickLocalized(locale, uz: textUz, ru: textRu);

  /// Convenience: a demonstrate step is "playable" only if the API ships
  /// an audio_url — otherwise the UI just shows the text + image.
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DemonstrateStep &&
          other.textUz == textUz &&
          other.textRu == textRu &&
          other.audioUrl == audioUrl &&
          other.imageUrl == imageUrl &&
          other.durationSec == durationSec;

  @override
  int get hashCode =>
      Object.hash(textUz, textRu, audioUrl, imageUrl, durationSec);
}

/// Record-the-child step. The UI uses [maxDurationSec] for the recording
/// progress bar's upper bound and [minDurationSec] as a "too short" hint.
class RecordStep extends ExerciseStep {
  const RecordStep({
    this.promptUz,
    this.promptRu,
    this.targetWord,
    this.targetPhonemes,
    this.minDurationSec,
    this.maxDurationSec,
    super.durationSec,
  }) : super(kind: 'record');

  final String? promptUz;
  final String? promptRu;

  /// The exact word or phrase the child should say. Falls through to
  /// [promptUz] / [promptRu] when not provided.
  final String? targetWord;

  /// Phonemes scored after this recording, e.g. `['s', 'a', 'r']`.
  final List<String>? targetPhonemes;

  final int? minDurationSec;
  final int? maxDurationSec;

  String localizedPrompt(String locale) =>
      _pickLocalized(locale, uz: promptUz, ru: promptRu);

  /// The string to display front-and-centre during the recording. Prefers
  /// [targetWord] when present so a non-Russian speaker still sees the
  /// Uzbek target word; otherwise falls back to the localized prompt.
  String displayWord(String locale) {
    final word = targetWord?.trim() ?? '';
    if (word.isNotEmpty) return word;
    return localizedPrompt(locale);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordStep &&
          other.promptUz == promptUz &&
          other.promptRu == promptRu &&
          other.targetWord == targetWord &&
          listEquals(other.targetPhonemes, targetPhonemes) &&
          other.minDurationSec == minDurationSec &&
          other.maxDurationSec == maxDurationSec &&
          other.durationSec == durationSec;

  @override
  int get hashCode => Object.hash(
        promptUz,
        promptRu,
        targetWord,
        targetPhonemes == null ? null : Object.hashAll(targetPhonemes!),
        minDurationSec,
        maxDurationSec,
        durationSec,
      );
}

/// Final celebration / coaching step. Combines copy for the success
/// branch ([encouragementUz/Ru]) and the failure branch
/// ([retryUz/Ru]) so the UI can choose based on the score.
class FeedbackStep extends ExerciseStep {
  const FeedbackStep({
    this.encouragementUz,
    this.encouragementRu,
    this.retryUz,
    this.retryRu,
    this.showScore = true,
    this.showPhonemeDetail = false,
    super.durationSec,
  }) : super(kind: 'feedback');

  final String? encouragementUz;
  final String? encouragementRu;
  final String? retryUz;
  final String? retryRu;
  final bool showScore;
  final bool showPhonemeDetail;

  String localizedEncouragement(String locale) =>
      _pickLocalized(locale, uz: encouragementUz, ru: encouragementRu);

  String localizedRetry(String locale) =>
      _pickLocalized(locale, uz: retryUz, ru: retryRu);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedbackStep &&
          other.encouragementUz == encouragementUz &&
          other.encouragementRu == encouragementRu &&
          other.retryUz == retryUz &&
          other.retryRu == retryRu &&
          other.showScore == showScore &&
          other.showPhonemeDetail == showPhonemeDetail &&
          other.durationSec == durationSec;

  @override
  int get hashCode => Object.hash(
        encouragementUz,
        encouragementRu,
        retryUz,
        retryRu,
        showScore,
        showPhonemeDetail,
        durationSec,
      );
}

/// Catch-all for step types we don't recognise yet. The UI skips past
/// these silently — never blocks the lesson — and analytics sees the
/// raw type via [rawType].
class UnknownStep extends ExerciseStep {
  const UnknownStep({
    required this.rawType,
    super.durationSec,
  }) : super(kind: 'unknown');

  final String rawType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnknownStep &&
          other.rawType == rawType &&
          other.durationSec == durationSec;

  @override
  int get hashCode => Object.hash(rawType, durationSec);
}

// ---------------------------------------------------------------------------
// Shared parsing helpers
// ---------------------------------------------------------------------------

String _pickLocalized(String locale, {String? uz, String? ru}) {
  final pref = locale.toLowerCase().startsWith('ru') ? ru : uz;
  if (pref != null && pref.trim().isNotEmpty) return pref.trim();
  final fallback = locale.toLowerCase().startsWith('ru') ? uz : ru;
  return (fallback ?? '').trim();
}

String? _readTrimmedString(Object? raw) {
  if (raw == null) return null;
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _readPositiveInt(Object? raw) {
  if (raw is int) return raw > 0 ? raw : null;
  if (raw is num) {
    final v = raw.toInt();
    return v > 0 ? v : null;
  }
  if (raw is String) {
    final v = int.tryParse(raw.trim());
    return (v != null && v > 0) ? v : null;
  }
  return null;
}

bool _readBool(Object? raw, {required bool defaultValue}) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final v = raw.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
  }
  return defaultValue;
}

List<String>? _readPhonemes(Object? raw) {
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
