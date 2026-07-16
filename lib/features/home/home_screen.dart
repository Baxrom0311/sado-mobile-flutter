import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/badge_celebration.dart';
import '../../core/gamification.dart';
import '../../core/theme.dart';
import '../../core/utils/age_bucket.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/child_avatar.dart';
import '../../widgets/daily_goal_card.dart';
import '../../widgets/daily_tip_card.dart';
import '../../widgets/home_assignments_card.dart';
import '../../widgets/home_next_badge_peek.dart';
import '../../widgets/home_premium_card.dart';
import '../../widgets/home_usage_meter.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/pending_uploads_chip.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/speech_bubble.dart';
import '../../widgets/streak_chip.dart';
import '../../widgets/weekly_sparkline.dart';
import '../../widgets/xp_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Set once per HomeScreen instance so re-builds don't double-celebrate.
  // markActiveToday() is itself idempotent on the persistence side, but we
  // still want to keep dialog presentation clean across rebuilds.
  bool _celebratedThisMount = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final unlocked =
          await ref.read(gameProvider.notifier).markActiveToday();
      if (!mounted || _celebratedThisMount) return;
      if (unlocked.isNotEmpty) {
        _celebratedThisMount = true;
        await celebrateUnlockedBadges(context, unlocked);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final auth = ref.watch(authProvider);
    final game = ref.watch(gameProvider);
    final children = ref.watch(childrenProvider);
    final exercises = ref.watch(exercisesProvider);
    final assessments = ref.watch(assessmentsProvider(null));

    final greeting = _greeting(l);
    final userName = auth.user?.fullName.split(' ').first ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.homeGradient,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(childrenProvider);
              ref.invalidate(exercisesProvider);
              ref.invalidate(assessmentsProvider(null));
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l.welcome}${userName.isNotEmpty ? ', $userName' : ''} 👋',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.appTitle,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StreakChip(
                        days: game.streakDays, label: l.streakDays),
                    const SizedBox(width: AppSpacing.sm),
                    const NotificationBell(),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => context.go('/settings'),
                    ),
                  ],
                ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),

                // Inline status pill: shows queued uploads with retry CTA.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: const PendingUploadsChip(),
                  ),
                ),

                // Single banner when ANY of the home-screen providers are
                // serving stale data. This is in addition to the global
                // connectivity banner in [ShellScreen]: the global banner
                // only fires when the device has no network, but our API
                // can also fail individually (server hiccup, DNS issue,
                // 5xx) and we still serve cached data — so the user
                // deserves to know their hero / children / exercises list
                // may be a few minutes old.
                if (_anyFromCache(children, exercises, assessments))
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: OfflineBanner(message: l.offlineCached),
                  ),

                const SizedBox(height: AppSpacing.lg),

                // Hero card with mascot + XP
                PremiumCard(
                  gradient: AppColors.heroGradient,
                  shadowColor: AppColors.primary,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      const ParrotMascot(
                          mood: ParrotMood.happy, size: 96),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              l.todayExercises,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.1),

                const SizedBox(height: AppSpacing.lg),

                // XP card
                PremiumCard(
                  onTap: () => context.go('/badges'),
                  child: XpBar(state: game),
                ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.1),

                const SizedBox(height: AppSpacing.md),

                // Compact "next badge" peek — the engagement loop's nearest
                // milestone surfaced right under the XP bar so users see a
                // concrete next reward the moment they open the app. The
                // tile renders nothing when every built-in badge is already
                // unlocked (the achievements screen owns that celebration).
                Builder(builder: (context) {
                  final assessmentsCount = assessments.maybeWhen(
                    data: (r) => r.items.length,
                    orElse: () => 0,
                  );
                  final goal = NextBadgeGoal.compute(
                    unlockedBadgeIds: game.badges,
                    streakDays: game.streakDays,
                    level: game.level,
                    assessmentsCount: assessmentsCount,
                  );
                  if (goal == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: HomeNextBadgePeek(
                      goal: goal,
                      label: l.nextBadgeTitle,
                      badgeTitle: _badgeTitleFor(l, goal.badgeId),
                      progressText: _progressTextFor(l, goal),
                      onTap: () => context.go('/badges'),
                    ).animate(delay: 175.ms).fadeIn().slideY(begin: 0.1),
                  );
                }),

                // Daily goal nudge. Reads `lastActiveDate` from the
                // gamification store — if the persisted day matches today
                // (UTC-naïve `yyyy-MM-dd`) we celebrate, otherwise we
                // surface a one-tap CTA into the exercises tab. This is
                // the engagement loop's daily heartbeat — much like
                // Duolingo's daily-goal card.
                DailyGoalCard(
                  isDone: isDailyGoalDone(game.lastActiveDate),
                  onStart: () => context.go('/exercises'),
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1),

                const SizedBox(height: AppSpacing.md),

                // Tip of the day — surfaces one of the curated home-practice
                // tips already maintained for the Help screen, rotated by
                // calendar day so a parent who opens the app every morning
                // sees a fresh nudge. Tapping the card expands the body
                // inline; no extra navigation hop, no Material spinner.
                DailyTipCard()
                    .animate(delay: 220.ms)
                    .fadeIn()
                    .slideY(begin: 0.1),

                const SizedBox(height: AppSpacing.md),

                // Therapist-assigned homework callout. Renders nothing when
                // the parent has no actionable assignments so it never
                // appears as a "ghost" card on first-time installs.
                const HomeAssignmentsCard(),

                const SizedBox(height: AppSpacing.md),

                // Premium upsell — shown only after the subscription
                // provider has resolved AND the user is on the free
                // plan. Hidden silently for premium users, during the
                // initial loading window, and on hard provider errors
                // so it never competes with the offline banner. The
                // card is keyed by ValueKey so widget tests can assert
                // its presence/absence directly.
                const HomePremiumCard(),

                const SizedBox(height: AppSpacing.md),

                // Today's-usage meter — only renders for free users
                // when the API has actually surfaced quota data. Lets
                // a parent see how close they are to the daily cap
                // *before* hitting a 402 wall, and gives a
                // tone-shifting upgrade nudge as they approach the
                // limit. Hidden silently in every "nothing to say"
                // case (loading, paid plan, empty usage, all-unlimited
                // metrics) so home stays calm by default.
                const HomeUsageMeter(),

                const SizedBox(height: AppSpacing.md),

                // This-week activity snapshot. Surfaces engagement on the
                // entry point so parents see at a glance whether their
                // child is on a roll or due for a session. Tapping the
                // card jumps to the full Progress screen. The sparkline
                // already runs its own staggered bar animations, so we
                // skip an extra `.animate()` on the wrapper to keep test
                // teardown free of pending timers.
                PremiumCard(
                  onTap: () => context.go('/progress'),
                  child: assessments.when(
                    data: (res) => WeeklySparkline(assessments: res.items),
                    loading: () => const SizedBox(
                      height: 116,
                      child: ShimmerBox(height: 116, radius: AppRadius.md),
                    ),
                    error: (_, __) =>
                        WeeklySparkline(assessments: const []),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Quick actions
                _SectionTitle(title: l.quickActions),
                const SizedBox(height: AppSpacing.md),
                children.when(
                  data: (res) => _QuickActions(
                    hasChildren: res.items.isNotEmpty,
                  ),
                  loading: () => const _QuickActions(hasChildren: false),
                  error: (_, __) => const _QuickActions(hasChildren: false),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Children section
                _SectionHeader(
                  title: l.children,
                  actionLabel: l.addChild,
                  onAction: () => context.go('/children/add'),
                ),
                const SizedBox(height: AppSpacing.md),
                children.when(
                  data: (res) => res.items.isEmpty
                      ? _EmptyChildrenCard(
                          onAdd: () => context.go('/children/add'))
                      : SizedBox(
                          height: 124,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: res.items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: AppSpacing.md),
                            itemBuilder: (_, i) =>
                                _ChildChip(child: res.items[i]),
                          ),
                        ),
                  loading: () => const SizedBox(
                    height: 124,
                    child: Row(
                      children: [
                        Expanded(
                            child: ShimmerBox(
                                height: 124, radius: AppRadius.lg)),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                            child: ShimmerBox(
                                height: 124, radius: AppRadius.lg)),
                      ],
                    ),
                  ),
                  error: (_, __) => _EmptyChildrenCard(
                      onAdd: () => context.go('/children/add')),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Today's exercises section. When at least one child is
                // attached, the list is filtered to that child's age
                // bucket so the recommendations actually feel personal —
                // the brief calls this out as "recommended based on age".
                // The youngest child wins (younger = more developmental
                // signal). If the filter empties the list (e.g. there
                // are no exercises in that bucket yet), we fall back to
                // the unfiltered top-N so the home never feels broken.
                Builder(builder: (context) {
                  final recommendation = _recommendationFor(children);
                  return _SectionHeader(
                    title: l.todayExercises,
                    subtitle: recommendation == null
                        ? null
                        : l.recommendedAgeSubtitle(
                            localizedAgeBucket(l, recommendation.bucket) ??
                                recommendation.bucket,
                            recommendation.childName,
                          ),
                    actionLabel: '${l.viewAll} →',
                    onAction: () => context.go('/exercises'),
                  );
                }),
                const SizedBox(height: AppSpacing.md),
                exercises.when(
                  data: (res) {
                    final recommendation = _recommendationFor(children);
                    final filtered = recommendation == null
                        ? res.items
                        : res.items
                            .where((e) => e.ageGroup == recommendation.bucket)
                            .toList();
                    // Fall back to the unfiltered list when filtering wipes
                    // everything out — better to show *something* than an
                    // empty section the user can't act on.
                    final pool = filtered.isEmpty ? res.items : filtered;
                    final list = pool.take(4).toList();
                    if (list.isEmpty) {
                      return PremiumCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(l.noExercises),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (int i = 0; i < list.length; i++) ...[
                          _ExerciseRow(exercise: list[i])
                              .animate(delay: (i * 60).ms)
                              .fadeIn()
                              .slideX(begin: 0.05),
                          if (i != list.length - 1)
                            const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    );
                  },
                  loading: () => const Column(
                    children: [
                      ShimmerCard(),
                      ShimmerCard(),
                      ShimmerCard(),
                    ],
                  ),
                  error: (_, __) => PremiumCard(
                    child: Text(l.error),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Recent assessments section
                _SectionHeader(
                  title: l.recentAssessments,
                  actionLabel: '${l.viewAll} →',
                  onAction: () => context.go('/progress'),
                ),
                const SizedBox(height: AppSpacing.md),
                assessments.when(
                  data: (res) {
                    final list = (res.items.toList()
                          ..sort((a, b) =>
                              b.createdAt.compareTo(a.createdAt)))
                        .take(3)
                        .toList();
                    if (list.isEmpty) {
                      return _EmptyAssessmentsCard(
                        onStart: () => context.go('/exercises'),
                      );
                    }
                    return Column(
                      children: [
                        for (int i = 0; i < list.length; i++) ...[
                          _AssessmentRow(assessment: list[i])
                              .animate(delay: (i * 60).ms)
                              .fadeIn()
                              .slideX(begin: -0.05),
                          if (i != list.length - 1)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    );
                  },
                  loading: () => const Column(
                    children: [
                      ShimmerCard(height: 72),
                      SizedBox(height: AppSpacing.sm),
                      ShimmerCard(height: 72),
                    ],
                  ),
                  error: (_, __) => _EmptyAssessmentsCard(
                    onStart: () => context.go('/exercises'),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Bottom motivational quote
                _MotivationCard(quote: _pickMotivation(l, game.xp)),

                const SizedBox(height: AppSpacing.huge),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pick a recommendation for the home's "Today's exercises" section,
  /// based on the youngest child the user has on file. Returns `null`
  /// when there are no children yet (or no child fits the supported
  /// age range), so the caller can fall back to "show everything".
  ///
  /// Kept on the State so we can call it from both the section header
  /// (for the subtitle) and the `exercises.when` data branch (for the
  /// actual filter) without re-deriving the value.
  _HomeRecommendation? _recommendationFor(
    AsyncValue<CachedResult<Child>> childrenAsync,
  ) {
    final children = childrenAsync.maybeWhen(
      data: (r) => r.items,
      orElse: () => const <Child>[],
    );
    if (children.isEmpty) return null;
    // Youngest = latest birth date.
    final youngest =
        children.reduce((a, b) => a.birthDate.isAfter(b.birthDate) ? a : b);
    final bucket = recommendedAgeBucket(youngest.birthDate);
    if (bucket == null) return null;
    final firstName = youngest.name.split(' ').first;
    return _HomeRecommendation(bucket: bucket, childName: firstName);
  }

  String _greeting(L l) {
    final h = DateTime.now().hour;
    if (h < 12) return l.mascotGreetingMorning;
    if (h < 18) return l.mascotGreetingDay;
    return l.mascotGreetingEvening;
  }

  /// Returns `true` when ANY of the data providers we render up-top has
  /// resolved to a [CachedResult.fromCache] = true value. We deliberately
  /// only consider the `data` branch — while the requests are still
  /// loading, the shimmers already convey "we're working on it" and a
  /// banner would be premature. Errors (without cache fallback) surface
  /// in their own per-section error UI.
  bool _anyFromCache(
    AsyncValue<CachedResult<Child>> a,
    AsyncValue<CachedResult<Exercise>> b,
    AsyncValue<CachedResult<Assessment>> c,
  ) {
    bool fromCache(AsyncValue<CachedResult<dynamic>> v) =>
        v.maybeWhen(data: (r) => r.fromCache, orElse: () => false);
    return fromCache(a) || fromCache(b) || fromCache(c);
  }

  /// Pick a motivational quote deterministically based on date + xp so the
  /// same user sees a stable message during a session, but it rotates daily.
  String _pickMotivation(L l, int xp) {
    final pool = [
      l.motivation1,
      l.motivation2,
      l.motivation3,
      l.motivation4,
      l.motivation5,
    ];
    final daySeed =
        DateTime.now().day + DateTime.now().month + (xp ~/ 10);
    return pool[daySeed % pool.length];
  }

  /// Localised display title for the badge id surfaced by
  /// [NextBadgeGoal.compute]. Mirrors the lookup in [BadgesScreen] so the
  /// home peek and the dedicated achievements screen always use the same
  /// copy.
  String _badgeTitleFor(L l, String id) => switch (id) {
        'first_step' => l.badgeFirstStepTitle,
        'streak_5' => l.badgeStreak5Title,
        'assess_10' => l.badgeAssess10Title,
        'level_5' => l.badgeLevel5Title,
        'level_10' => l.badgeLevel10Title,
        'perfect' => l.badgePerfectTitle,
        _ => l.badges,
      };

  /// Localised "x/y …" copy for the goal's progress counter. Mirrors the
  /// lookup in [BadgesScreen]; kept in sync so peek + full card never drift.
  String _progressTextFor(L l, NextBadgeGoal goal) => switch (goal.kind) {
        NextBadgeGoalKind.streak =>
          l.nextBadgeStreakProgress(goal.current, goal.target),
        NextBadgeGoalKind.assessments =>
          l.nextBadgeAssessProgress(goal.current, goal.target),
        NextBadgeGoalKind.level =>
          l.nextBadgeLevelProgress(goal.current, goal.target),
      };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

/// Value object describing a personalised home-screen recommendation:
/// the API age-group token to filter by and the (first) name we should
/// surface in the subtitle so the user understands *why* this list looks
/// this way.
class _HomeRecommendation {
  const _HomeRecommendation({
    required this.bucket,
    required this.childName,
  });
  final String bucket;
  final String childName;
}

/// Pair of large, colorful action cards. The second card swaps between
/// "Add child" (when there are no children yet) and "Run assessment"
/// (when the user already has at least one child).
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.hasChildren});
  final bool hasChildren;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            key: const ValueKey('quick.startExercise'),
            icon: Icons.play_arrow_rounded,
            title: l.quickStartExercise,
            subtitle: l.quickStartExerciseHint,
            color: AppColors.primary,
            onTap: () => GoRouter.of(context).go('/exercises'),
          ).animate(delay: 200.ms).fadeIn().slideX(begin: -0.05),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: hasChildren
              ? _ActionCard(
                  key: const ValueKey('quick.assessment'),
                  icon: Icons.mic_rounded,
                  title: l.quickAssessment,
                  subtitle: l.quickAssessmentHint,
                  color: AppColors.secondary,
                  onTap: () => GoRouter.of(context).go('/exercises'),
                ).animate(delay: 240.ms).fadeIn().slideX(begin: 0.05)
              : _ActionCard(
                  key: const ValueKey('quick.addChild'),
                  icon: Icons.person_add_alt_1_rounded,
                  title: l.quickAddChild,
                  subtitle: l.quickAddChildHint,
                  color: AppColors.tertiary,
                  onTap: () => GoRouter.of(context).go('/children/add'),
                ).animate(delay: 240.ms).fadeIn().slideX(begin: 0.05),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      shadowColor: color,
      gradient: [color, color.withValues(alpha: 0.78)],
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        height: 116,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChildrenCard extends ConsumerWidget {
  const _EmptyChildrenCard({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    return PremiumCard(
      onTap: onAdd,
      shadowColor: AppColors.secondary,
      gradient: AppColors.sunsetGradient,
      child: Row(
        children: [
          const Text('🐣', style: TextStyle(fontSize: 40)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.noChildren,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.noChildrenBody,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.add_circle, color: Colors.white, size: 28),
        ],
      ),
    );
  }
}

class _EmptyAssessmentsCard extends StatelessWidget {
  const _EmptyAssessmentsCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return PremiumCard(
      onTap: onStart,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.history_rounded,
                color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.noRecentAssessments,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.noRecentAssessmentsBody,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _ChildChip extends ConsumerWidget {
  const _ChildChip({required this.child});
  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final color = ChildAvatar.paletteOf(child.name, gender: child.gender).last;
    final age = _age(child.birthDate);

    return PremiumCard(
      onTap: () {
        ref.read(selectedChildIdProvider.notifier).state = child.id;
        context.go('/children/${child.id}');
      },
      padding: const EdgeInsets.all(AppSpacing.md),
      shadowColor: color,
      child: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChildAvatar(
              name: child.name,
              gender: child.gender,
              size: ChildAvatarSize.sm,
              heroTag: 'child-avatar-${child.id}',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              child.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$age ${l.yearsOld}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _age(DateTime birth) {
    final now = DateTime.now();
    int a = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      a--;
    }
    return a;
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final color = AppColors.categoryColor(exercise.category);
    return PremiumCard(
      onTap: () => context.go('/exercises/${exercise.id}'),
      shadowColor: color,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(_categoryIcon(exercise.category),
                color: color, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercise.durationMinutes} ${l.minutes} • ${_localizedDifficulty(l, exercise.difficulty)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: AppShadow.soft(color),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 22),
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

  String _localizedDifficulty(L l, String d) => switch (d) {
        'easy' => l.easy,
        'medium' => l.medium,
        'hard' => l.hard,
        _ => d,
      };
}

class _AssessmentRow extends StatelessWidget {
  const _AssessmentRow({required this.assessment});
  final Assessment assessment;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final risk = RiskLevel.fromApi(assessment.overallRisk);
    final color = risk.color;
    final score = assessment.score;
    final percent = score == null ? null : (score * 100).round();
    final dateStr = DateFormat.yMMMd(Localizations.localeOf(context)
            .toLanguageTag())
        .format(assessment.createdAt.toLocal());

    return PremiumCard(
      onTap: () => context.go('/assessment/results/${assessment.id}'),
      shadowColor: color,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(risk.icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  percent == null ? '—' : '$percent%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${risk.label(l)} • $dateStr',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Footer card: parrot mascot delivering a localized motivational quote
/// in a speech bubble. Shown at the bottom of the home feed.
class _MotivationCard extends StatelessWidget {
  const _MotivationCard({required this.quote});
  final String quote;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const ParrotMascot(mood: ParrotMood.happy, size: 80),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SpeechBubble(
              key: const ValueKey('home.motivation.bubble'),
              text: quote,
              tailDirection: SpeechBubbleTail.down,
              maxWidth: 400,
            ),
          ),
        ],
      ),
    ).animate(delay: 320.ms).fadeIn().slideY(begin: 0.08);
  }
}
