import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../domain/exercises/exercise_step.dart';
import 'parrot_mascot.dart';
import 'premium_card.dart';
import 'speech_bubble.dart';

/// Compact, parent-facing preview of an interactive lesson plan.
///
/// Shown on the exercise detail screen whenever the API ships a non-empty
/// `steps` array (see [Exercise.hasInteractiveSteps]). Renders the parrot
/// mascot with a localized intro bubble, a one-line summary of the lesson
/// length, and one numbered tile per step describing what will happen.
///
/// This widget is intentionally read-only — it does NOT start the lesson.
/// The "Start" CTA further down the detail screen is responsible for that.
/// Keeping the preview pure also means it's safe to embed inside any other
/// screen (e.g. an upcoming homework / assignment detail) without dragging
/// in the audio recorder.
class LessonPreviewCard extends StatelessWidget {
  const LessonPreviewCard({
    super.key,
    required this.steps,
    required this.accentColor,
  });

  /// Ordered list of steps as parsed by [Exercise.fromJson]. Must be
  /// non-empty — callers should hide this widget entirely when there are
  /// no steps to render.
  final List<ExerciseStep> steps;

  /// Accent color for the leading badges and mascot bubble border.
  /// Should match the exercise's category color for visual continuity.
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    assert(steps.isNotEmpty,
        'LessonPreviewCard expects callers to skip rendering when empty.');
    final l = L.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return Semantics(
      container: true,
      label: l.lessonPreviewSemantics(steps.length),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.lessonPreviewTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.lessonPreviewSubtitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    l.lessonPreviewStepsCount(steps.length),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Mascot strip with a contextual intro bubble — keeps the card
            // visually anchored to the rest of the SADO experience and
            // gives the parent a one-line "what is this?" answer before
            // the step list.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const ParrotMascot(mood: ParrotMood.talking, size: 64),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: SpeechBubble(
                    text: l.lessonPreviewMascotIntro(steps.length),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Numbered list — keeps a calm vertical rhythm regardless of
            // how many steps the API ships. The numbers are 1-based since
            // they are visible to parents and we never want a "Step 0".
            for (int i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              _LessonStepTile(
                number: i + 1,
                step: steps[i],
                accentColor: accentColor,
                locale: locale,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LessonStepTile extends StatelessWidget {
  const _LessonStepTile({
    required this.number,
    required this.step,
    required this.accentColor,
    required this.locale,
  });

  final int number;
  final ExerciseStep step;
  final Color accentColor;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final descriptor = _descriptorFor(step, l, locale);
    final iconColor = AppColors.categoryColor(_categoryHint(step));

    return Semantics(
      // Combine the step kind, title and detail into a single accessible
      // label so screen readers announce the whole step in one breath
      // instead of three disconnected siblings.
      label: '${l.lessonPreviewStepsCount(number)} · '
          '${descriptor.title} · ${descriptor.body}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(descriptor.icon, size: 16, color: iconColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          descriptor.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (descriptor.duration != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          descriptor.duration!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    descriptor.body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hints at a category color for the leading icon based on the step
  /// kind — so instruction steps get the calm primary blue, demonstrate
  /// steps the bright phonemic-awareness purple, etc. Keeps the tile
  /// rhythm visually varied without relying on the parent passing extra
  /// metadata.
  String _categoryHint(ExerciseStep step) {
    return switch (step) {
      InstructionStep() => 'listening',
      DemonstrateStep() => 'phonemic_awareness',
      RecordStep() => 'articulation',
      FeedbackStep() => 'fluency',
      _ => 'vocabulary',
    };
  }

  /// Builds the visible (icon, title, body, optional duration suffix)
  /// for one step. Falls back to safe localized copy when the API
  /// shipped no usable text — never returns an empty body.
  _StepDescriptor _descriptorFor(
    ExerciseStep step,
    L l,
    String locale,
  ) {
    return switch (step) {
      InstructionStep() => _StepDescriptor(
          icon: Icons.menu_book_outlined,
          title: l.lessonStepInstruction,
          body: _stringOrFallback(
              step.localizedText(locale), l.lessonStepInstructionFallback),
          duration: step.durationSec == null
              ? null
              : l.lessonStepDurationSec(step.durationSec!),
        ),
      DemonstrateStep() => _StepDescriptor(
          icon: Icons.hearing_outlined,
          title: l.lessonStepDemonstrate,
          body: _stringOrFallback(
              step.localizedText(locale), l.lessonStepDemonstrateFallback),
          duration: step.durationSec == null
              ? null
              : l.lessonStepDurationSec(step.durationSec!),
        ),
      RecordStep() => _StepDescriptor(
          icon: Icons.mic_none_rounded,
          title: l.lessonStepRecord,
          body: _recordBody(step, l, locale),
          duration: _recordDurationLabel(step, l),
        ),
      FeedbackStep() => _StepDescriptor(
          icon: Icons.celebration_outlined,
          title: l.lessonStepFeedback,
          body: _stringOrFallback(
              step.localizedEncouragement(locale), l.lessonStepFeedbackFallback),
          duration: step.durationSec == null
              ? null
              : l.lessonStepDurationSec(step.durationSec!),
        ),
      UnknownStep() => _StepDescriptor(
          icon: Icons.more_horiz_rounded,
          title: l.lessonStepUnknown,
          body: l.lessonStepInstructionFallback,
          duration: null,
        ),
    };
  }

  String _recordBody(RecordStep step, L l, String locale) {
    final word = step.targetWord?.trim() ?? '';
    final prompt = step.localizedPrompt(locale);
    final phonemesPart = (step.targetPhonemes != null &&
            step.targetPhonemes!.isNotEmpty)
        ? '\n${l.lessonStepRecordPhonemes(step.targetPhonemes!.join(' · '))}'
        : '';
    if (word.isNotEmpty) {
      return '${l.lessonStepRecordTargetWord(word)}$phonemesPart';
    }
    if (prompt.isNotEmpty) {
      return '$prompt$phonemesPart';
    }
    return l.lessonStepRecordFallback + phonemesPart;
  }

  String? _recordDurationLabel(RecordStep step, L l) {
    final min = step.minDurationSec;
    final max = step.maxDurationSec;
    if (min != null && max != null) {
      return l.lessonStepDurationRange(min, max);
    }
    if (max != null) {
      return l.lessonStepDurationMaxOnly(max);
    }
    if (min != null) {
      return l.lessonStepDurationSec(min);
    }
    if (step.durationSec != null) {
      return l.lessonStepDurationSec(step.durationSec!);
    }
    return null;
  }

  String _stringOrFallback(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}

/// Small POD used to keep the icon/title/body/duration assembly readable
/// in [_LessonStepTile.build] — no need to expose this outside the file.
@immutable
class _StepDescriptor {
  const _StepDescriptor({
    required this.icon,
    required this.title,
    required this.body,
    required this.duration,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? duration;
}

/// Re-export for the rare consumer that needs to call [debugString] on
/// the descriptor in tests. Currently only the file-private tile uses it,
/// but exposing it keeps the test surface flexible.
@visibleForTesting
String debugStepKind(ExerciseStep step) => step.kind;

/// Restores a previously dropped [SemanticsAction.tap] flag whenever the
/// preview is wrapped inside an interactive ancestor — kept here as a
/// guard for the (rare) cases where a parent forces `excludeSemantics:
/// true` on the whole subtree. Not used today, but documented so future
/// modifications don't accidentally swallow tile semantics.
@visibleForTesting
SemanticsFlag get lessonPreviewLiveRegionFlag => SemanticsFlag.isLiveRegion;
