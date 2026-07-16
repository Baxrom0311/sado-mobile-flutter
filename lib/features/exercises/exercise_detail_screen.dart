import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/api/api_client.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/audio_example_player.dart';
import '../../widgets/difficulty_stars.dart';
import '../../widgets/lesson_preview_card.dart';
import '../../widgets/loaders.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_card.dart';
import 'widgets/child_picker_sheet.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});
  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final exercises = ref.watch(exercisesProvider);
    final children = ref.watch(childrenProvider);

    return exercises.when(
      data: (res) {
        Exercise? exercise;
        for (final e in res.items) {
          if (e.id == exerciseId) {
            exercise = e;
            break;
          }
        }
        if (exercise == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ParrotMascot(mood: ParrotMood.sad, size: 120),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l.exerciseNotFound,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
            ),
          );
        }

        return _Detail(exercise: exercise, children: children);
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: MascotLoader(message: l.loadingExercise),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.error)),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.exercise, required this.children});
  final Exercise exercise;
  final AsyncValue<CachedResult<Child>> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final color = AppColors.categoryColor(exercise.category);
    final exampleUrl = resolveMediaUrl(exercise.audioExamplePath);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: color,
            foregroundColor: Colors.white,
            expandedHeight: 220,
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go('/exercises'),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                exercise.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.75)],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: const ParrotMascot(
                            mood: ParrotMood.talking, size: 130)
                        .animate()
                        .fadeIn(duration: 350.ms),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Hero-tagged category badge — receives the icon flying in
                // from the exercises list / home for a smooth premium
                // transition. Sits inline so layout stays calm at every
                // scroll position.
                Row(
                  children: [
                    Hero(
                      tag: 'exercise-icon-${exercise.id}',
                      flightShuttleBuilder: (_, __, ___, ____, toCtx) =>
                          (toCtx.widget as Hero).child,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [color, color.withValues(alpha: 0.7)],
                          ),
                          borderRadius:
                              BorderRadius.circular(AppRadius.lg),
                          boxShadow: AppShadow.soft(color),
                        ),
                        child: Icon(
                          _categoryIcon(exercise.category),
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _localizedCategory(l, exercise.category)
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            exercise.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Chip(
                      icon: Icons.timer_rounded,
                      label: '${exercise.durationMinutes} ${l.minutes}',
                      color: AppColors.textSecondary,
                    ),
                    _DifficultyChip(difficulty: exercise.difficulty),
                    _Chip(
                      icon: Icons.cake_rounded,
                      label: _localizedAgeGroup(l, exercise.ageGroup),
                      color: AppColors.tertiary,
                    ),
                    _Chip(
                      icon: Icons.category_rounded,
                      label: _localizedCategory(l, exercise.category),
                      color: color,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (exampleUrl != null) ...[
                  AudioExamplePlayer(
                    url: exampleUrl,
                    label: l.listenExample,
                    errorLabel: l.audioExampleUnavailable,
                    color: color,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              color: AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(l.description,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        exercise.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (exercise.instructions != null &&
                    exercise.instructions!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.menu_book_rounded,
                                color: AppColors.tertiary),
                            const SizedBox(width: AppSpacing.sm),
                            Text(l.exerciseInstructions,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          exercise.instructions!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (exercise.targetPhonemes != null &&
                    exercise.targetPhonemes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.graphic_eq_rounded,
                                color: AppColors.secondary),
                            const SizedBox(width: AppSpacing.sm),
                            Text(l.targetSounds,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Render each phoneme as its own pill so the
                        // children can scan the target sounds at a glance
                        // and the layout adapts gracefully when the API
                        // returns long arrays (e.g. multi-syllable drills).
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final phoneme in exercise.targetPhonemes!)
                              _PhonemeChip(label: phoneme),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (exercise.hasInteractiveSteps) ...[
                  const SizedBox(height: AppSpacing.md),
                  // Lesson plan preview — only renders when the API
                  // ships the new `steps` array. Existing exercises
                  // (legacy single-recording flow) skip this card
                  // entirely so their detail page is byte-for-byte
                  // identical to the previous release.
                  LessonPreviewCard(
                    steps: exercise.steps!,
                    accentColor: color,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                children.when(
                  data: (res) => _StartCta(
                    exercise: exercise,
                    color: color,
                    children: res.items,
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => Text(l.error),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _localizedCategory(L l, String c) => switch (c) {
        'articulation' => l.categoryArticulation,
        'breathing' => l.categoryBreathing,
        'vocabulary' => l.categoryVocabulary,
        'fluency' => l.categoryFluency,
        'listening' => l.categoryListening,
        'phonemic_awareness' => l.categoryPhonemicAwareness,
        _ => c,
      };

  /// API age-group tokens are short ranges like "3-4". Map the known ones
  /// to localized labels and fall back to the raw token for unknown values
  /// (defensive: the API may add a new bucket before the app ships).
  String _localizedAgeGroup(L l, String token) => switch (token) {
        '2-3' => l.ageGroup2to3,
        '3-4' => l.ageGroup3to4,
        '4-5' => l.ageGroup4to5,
        '5-6' => l.ageGroup5to6,
        '6-7' => l.ageGroup6to7,
        _ => token,
      };
}

class _StartCta extends ConsumerWidget {
  const _StartCta({
    required this.exercise,
    required this.color,
    required this.children,
  });

  final Exercise exercise;
  final Color color;
  final List<Child> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    if (children.isEmpty) {
      return PremiumCard(
        gradient: AppColors.sunsetGradient,
        shadowColor: AppColors.secondary,
        onTap: () => context.go('/children/add'),
        child: Row(
          children: [
            const Text('🐣', style: TextStyle(fontSize: 36)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                l.noChildSelectFirst,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(Icons.add_circle, color: Colors.white),
          ],
        ),
      );
    }

    final selectedId = ref.watch(selectedChildIdProvider) ?? children.first.id;
    Child selectedChild = children.first;
    for (final c in children) {
      if (c.id == selectedId) {
        selectedChild = c;
        break;
      }
    }

    final selectedColor = selectedChild.gender == 'male'
        ? AppColors.sky
        : AppColors.pink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.selectChild,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        PremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          shadowColor: selectedColor,
          onTap: () async {
            final picked = await showChildPickerSheet(
              context: context,
              children: children,
              selectedId: selectedId,
              onAddChild: () => context.go('/children/add'),
            );
            if (picked != null) {
              ref.read(selectedChildIdProvider.notifier).state = picked;
            }
          },
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selectedColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selectedChild.gender == 'male'
                      ? Icons.face_6_rounded
                      : Icons.face_3_rounded,
                  color: selectedColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedChild.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      l.tapToContinue,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.expand_more_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PremiumButton(
          label: exercise.hasInteractiveSteps
              ? l.lessonPreviewTitle
              : l.startAssessment,
          icon: exercise.hasInteractiveSteps
              ? Icons.menu_book_rounded
              : Icons.play_arrow_rounded,
          color: color,
          onPressed: () {
            // Modern step-based lessons go through the interactive
            // player; legacy single-recording exercises keep the old
            // assessment intro flow byte-for-byte.
            if (exercise.hasInteractiveSteps) {
              context.go(
                '/exercises/${exercise.id}/lesson/$selectedId',
              );
            } else {
              context.go(
                '/assessment/intro/$selectedId/${exercise.id}',
              );
            }
          },
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              )),
        ],
      ),
    );
  }
}

/// Pill that hosts the [DifficultyStars] indicator. Shares the same
/// rounded/tinted look as [_Chip] so the four-chip row above the
/// description card aligns visually instead of mixing component
/// languages.
class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.difficulty});
  final String difficulty;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.difficultyColor(difficulty);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: DifficultyStars(
        difficulty: difficulty,
        showLabel: true,
        size: 14,
      ),
    );
  }
}

/// Category → icon mapping used by the Hero badge at the top of the
/// detail body. Mirrors the same mapping used by the exercises list
/// and home recommendations, so the icon flying in via Hero matches
/// the one rendered at the destination.
IconData _categoryIcon(String c) => switch (c) {
      'articulation' => Icons.mic_rounded,
      'breathing' => Icons.air_rounded,
      'vocabulary' => Icons.menu_book_rounded,
      'fluency' => Icons.speed_rounded,
      'listening' => Icons.hearing_rounded,
      'phonemic_awareness' => Icons.music_note_rounded,
      _ => Icons.fitness_center_rounded,
    };

/// Branded phoneme tag rendered inside the "Target sounds" card.
///
/// We deliberately roll our own pill (rather than using the Material
/// [Chip]) so the sound character renders in a heavier weight and the
/// background tint matches the secondary brand colour — the Material
/// default would inherit the global ChipTheme which we keep neutral
/// for filter rows elsewhere.
class _PhonemeChip extends StatelessWidget {
  const _PhonemeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.30),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.secondary,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
