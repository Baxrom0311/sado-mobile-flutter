import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/paginated_exercises_provider.dart';
import '../../widgets/difficulty_stars.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/shimmer_loaders.dart';

class ExercisesListScreen extends ConsumerStatefulWidget {
  const ExercisesListScreen({super.key});

  @override
  ConsumerState<ExercisesListScreen> createState() =>
      _ExercisesListScreenState();
}

class _ExercisesListScreenState extends ConsumerState<ExercisesListScreen> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  /// Trigger pagination ~400 px before the bottom of the list so the next
  /// page lands while the user is still scrolling.
  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(paginatedExercisesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final state = ref.watch(paginatedExercisesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.exercises)),
      body: _Body(scroll: _scroll, state: state, l: l),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.scroll, required this.state, required this.l});

  final ScrollController scroll;
  final PaginatedExercisesState state;
  final L l;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return const ShimmerList(itemCount: 5);
    }
    if (state.items.isEmpty && state.error != null) {
      return EmptyState(
        title: l.errorTitle,
        body: l.tryAgainLater,
        mood: ParrotMood.sad,
        ctaLabel: l.retry,
        ctaIcon: Icons.refresh_rounded,
        onCta: () =>
            ref.read(paginatedExercisesProvider.notifier).refresh(),
      );
    }

    final items = state.filteredItems;
    // Don't show the dangling load-more spinner when a search is active —
    // filtering is local and "more pages" don't apply to the visible slice.
    final canPaginate = !state.isSearching;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          ref.read(paginatedExercisesProvider.notifier).refresh(),
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (state.fromCache) OfflineBanner(message: l.offlineCached),
          _CategoryFilter(
            selected: state.category,
            onChanged: (c) =>
                ref.read(paginatedExercisesProvider.notifier).setCategory(c),
          ),
          const SizedBox(height: AppSpacing.md),
          _AgeGroupFilter(
            selected: state.ageGroup,
            onChanged: (g) =>
                ref.read(paginatedExercisesProvider.notifier).setAgeGroup(g),
          ),
          const SizedBox(height: AppSpacing.md),
          _DifficultyFilter(
            selected: state.difficulty,
            onChanged: (d) => ref
                .read(paginatedExercisesProvider.notifier)
                .setDifficulty(d),
          ),
          const SizedBox(height: AppSpacing.md),
          _SearchField(
            value: state.searchQuery,
            onChanged: (q) => ref
                .read(paginatedExercisesProvider.notifier)
                .setSearchQuery(q),
            onClear: () =>
                ref.read(paginatedExercisesProvider.notifier).clearSearch(),
            hint: l.searchExercisesHint,
            clearTooltip: l.clearSearch,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (items.isEmpty)
            EmptyState(
              title:
                  state.isSearching ? l.noSearchResults : l.noExercises,
              body: state.isSearching
                  ? l.noSearchResultsBody
                  : l.noExercisesBody,
              ctaLabel: state.isSearching ? l.clearSearch : l.retry,
              ctaIcon: state.isSearching
                  ? Icons.close_rounded
                  : Icons.refresh_rounded,
              onCta: () {
                if (state.isSearching) {
                  ref
                      .read(paginatedExercisesProvider.notifier)
                      .clearSearch();
                } else {
                  ref.read(paginatedExercisesProvider.notifier).refresh();
                }
              },
            )
          else
            ...List.generate(items.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ExerciseCard(exercise: items[i])
                    .animate(delay: (i * 30).ms)
                    .fadeIn()
                    .slideY(begin: 0.05),
              );
            }),
          if (canPaginate && state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: ShimmerCard(),
            )
          else if (canPaginate && state.hasMore && state.error == null)
            const SizedBox(height: AppSpacing.md)
          else if (canPaginate &&
              state.error != null &&
              state.items.isNotEmpty)
            _LoadMoreError(
              onRetry: () =>
                  ref.read(paginatedExercisesProvider.notifier).loadMore(),
              label: l.retry,
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Premium search field for the exercises list. Matches the brand language
/// (rounded fill, primary focus ring, custom shadow) and exposes an
/// inline clear affordance once the user has typed anything.
class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.value,
    required this.onChanged,
    required this.onClear,
    required this.hint,
    required this.clearTooltip,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hint;
  final String clearTooltip;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SearchField old) {
    super.didUpdateWidget(old);
    // Keep the field in sync if the parent state was reset programmatically
    // (e.g. via the empty-state "Clear search" CTA) without clobbering the
    // caret while the user is actively typing.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection:
            TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: widget.value.isEmpty
            ? null
            : IconButton(
                tooltip: widget.clearTooltip,
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _controller.clear();
                  widget.onClear();
                },
              ),
      ),
    );
  }
}

/// Horizontal chip row for the age-group filter. Tokens follow the API
/// convention ("2-3", "3-4", …) so they can be passed straight through to
/// `/exercises?age_group=…`. Labels are localized via the .arb files.
class _AgeGroupFilter extends StatelessWidget {
  const _AgeGroupFilter({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final groups = <(String?, String)>[
      (null, l.allAges),
      ('2-3', l.ageGroup2to3),
      ('3-4', l.ageGroup3to4),
      ('4-5', l.ageGroup4to5),
      ('5-6', l.ageGroup5to6),
      ('6-7', l.ageGroup6to7),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
          child: Text(
            l.filterByAge,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: groups.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.xs),
            itemBuilder: (_, i) {
              final g = groups[i];
              final isSelected = g.$1 == selected;
              return GestureDetector(
                onTap: () => onChanged(g.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                    boxShadow: isSelected
                        ? AppShadow.soft(AppColors.primary)
                        : AppShadow.card,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    g.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Horizontal pill row for the difficulty filter. Tokens follow the API
/// convention ("easy" / "medium" / "hard"). Each pill is colour-coded
/// against the brand traffic-light palette so the difficulty ramp is
/// readable at a glance.
class _DifficultyFilter extends StatelessWidget {
  const _DifficultyFilter({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final levels = <(String?, String, Color)>[
      (null, l.allDifficulties, AppColors.textSecondary),
      ('easy', l.easy, AppColors.success),
      ('medium', l.medium, AppColors.accent),
      ('hard', l.hard, AppColors.danger),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
          child: Text(
            l.filterByDifficulty,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: levels.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.xs),
            itemBuilder: (_, i) {
              final lvl = levels[i];
              final isSelected = lvl.$1 == selected;
              return Semantics(
                button: true,
                selected: isSelected,
                label: lvl.$2,
                child: GestureDetector(
                  onTap: () => onChanged(lvl.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? lvl.$3 : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: isSelected
                          ? AppShadow.soft(lvl.$3)
                          : AppShadow.card,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      lvl.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final cats = [
      (null as String?, l.total, Icons.dashboard_rounded, AppColors.primary),
      ('articulation', l.categoryArticulation, Icons.mic_rounded,
          AppColors.primary),
      ('breathing', l.categoryBreathing, Icons.air_rounded, AppColors.sky),
      ('vocabulary', l.categoryVocabulary, Icons.menu_book_rounded,
          AppColors.pink),
      ('fluency', l.categoryFluency, Icons.speed_rounded,
          AppColors.secondary),
      ('listening', l.categoryListening, Icons.hearing_rounded,
          AppColors.tertiary),
      ('phonemic_awareness', l.categoryPhonemicAwareness,
          Icons.music_note_rounded, AppColors.accent),
    ];

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final c = cats[i];
          final isSelected = c.$1 == selected;
          return GestureDetector(
            onTap: () => onChanged(c.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 96,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected ? c.$4 : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: isSelected
                    ? AppShadow.soft(c.$4)
                    : AppShadow.card,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(c.$3,
                      color: isSelected ? Colors.white : c.$4, size: 24),
                  const SizedBox(height: 6),
                  Text(
                    c.$2,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color:
                          isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final color = AppColors.categoryColor(exercise.category);

    return PremiumCard(
      shadowColor: color,
      onTap: () => context.go('/exercises/${exercise.id}'),
      child: Row(
        children: [
          // Hero-tagged category icon — animates smoothly into the
          // matching badge on the detail screen for a premium feel.
          Hero(
            tag: 'exercise-icon-${exercise.id}',
            // Custom flightShuttle keeps the gradient + shadow visible
            // mid-flight (the default Hero shuttle re-parents the child
            // and would lose Material shadows during the animation).
            flightShuttleBuilder: (_, __, ___, ____, toCtx) =>
                (toCtx.widget as Hero).child,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadow.soft(color),
              ),
              child: Icon(_categoryIcon(exercise.category),
                  color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  exercise.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Pill(
                      label: '${exercise.durationMinutes} ${l.minutes}',
                      color: AppColors.textSecondary,
                      icon: Icons.timer_outlined,
                    ),
                    DifficultyStars(
                      difficulty: exercise.difficulty,
                      showLabel: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String c) => switch (c) {
        'articulation' => Icons.mic_rounded,
        'breathing' => Icons.air_rounded,
        'vocabulary' => Icons.menu_book_rounded,
        'fluency' => Icons.speed_rounded,
        'listening' => Icons.hearing_rounded,
        'phonemic_awareness' => Icons.music_note_rounded,
        _ => Icons.fitness_center_rounded,
      };
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              )),
        ],
      ),
    );
  }
}

class _LoadMoreError extends StatelessWidget {
  const _LoadMoreError({required this.onRetry, required this.label});
  final VoidCallback onRetry;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(label),
      ),
    );
  }
}
