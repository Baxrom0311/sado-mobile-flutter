import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/api/api_client.dart';
import '../../data/api/children_api.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/child_assignments_card.dart';
import '../../widgets/child_avatar.dart';
import '../../widgets/loaders.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/weekly_sparkline.dart';
import 'speech_profile_screen.dart' show SpeechProfileEntryCard;
import 'practice_calendar_screen.dart' show PracticeCalendarEntryCard;
import 'recordings_history_screen.dart' show RecordingsHistoryEntryCard;

/// Detail view for a single child with stats and recent assessments.
class ChildDetailScreen extends ConsumerWidget {
  const ChildDetailScreen({super.key, required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final children = ref.watch(childrenProvider);
    final assessments = ref.watch(assessmentsProvider(childId));

    return children.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: MascotLoader(message: l.loadingChild),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.error)),
      ),
      data: (res) {
        Child? child;
        for (final c in res.items) {
          if (c.id == childId) {
            child = c;
            break;
          }
        }
        if (child == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go('/children'),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ParrotMascot(mood: ParrotMood.sad, size: 120),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l.errorTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ],
              ),
            ),
          );
        }
        return _Body(child: child, assessments: assessments);
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.child, required this.assessments});
  final Child child;
  final AsyncValue<CachedResult<Assessment>> assessments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final isMale = child.gender == 'male';
    final color = isMale ? AppColors.sky : AppColors.pink;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(child.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/children'),
        ),
        actions: [
          IconButton(
            tooltip: l.editChild,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/children/${child.id}/edit'),
          ),
          IconButton(
            tooltip: l.deleteChild,
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
            onPressed: () => _confirmDelete(context, ref, child),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // When the assessments came from local cache (i.e. the API call
          // failed), inform the user up-front so the recent-assessments
          // list and the sparkline don't look stale by surprise. The
          // children list is fetched in the parent ConsumerWidget and we
          // also surface its cache state via the same banner — keeping
          // both checks here means the banner appears whenever any data
          // on this screen is potentially out-of-date.
          assessments.maybeWhen<Widget>(
            data: (res) => res.fromCache
                ? OfflineBanner(message: l.offlineCached)
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          PremiumCard(
            gradient: [color, color.withValues(alpha: 0.7)],
            shadowColor: color,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                ChildAvatar(
                  name: child.name,
                  gender: child.gender,
                  size: ChildAvatarSize.lg,
                  showRing: true,
                  heroTag: 'child-avatar-${child.id}',
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_age(child.birthDate)} ${l.yearsOld}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.05),

          const SizedBox(height: AppSpacing.lg),

          Text(
            l.yourStats,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          assessments.when(
            data: (res) => _StatsRow(items: res.items),
            loading: () => const _StatsRow(items: []),
            error: (_, __) => _StatsRow(items: const []),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 7-day activity sparkline. Shimmers while assessments load,
          // collapses to an empty-but-friendly state when there's no
          // data (the widget itself renders the empty hint).
          PremiumCard(
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

          const SizedBox(height: AppSpacing.lg),

          // Premium AI-derived speech profile entry. Tapping opens the
          // aggregated phoneme-mastery view; the speech profile screen
          // owns its own loading / empty / error states.
          SpeechProfileEntryCard(childId: child.id),

          const SizedBox(height: AppSpacing.lg),

          // Monthly practice calendar — heat-map of activity, current
          // streak and average score. The card itself is presentational
          // (no providers) so it renders deterministically; tapping
          // routes to the full /children/:id/calendar screen.
          PracticeCalendarEntryCard(childId: child.id),

          const SizedBox(height: AppSpacing.lg),

          // Therapist-assigned homework, scoped to this child. The card
          // owns its own loading shimmer / empty / silent-error states,
          // and hides itself entirely when there is nothing the parent
          // could act on (no pending assignments and no completed
          // history) — that keeps a brand-new child's detail screen
          // free of redundant "no homework" cards.
          ChildAssignmentsCard(childId: child.id),

          const SizedBox(height: AppSpacing.lg),

          // Premium "browse every recording" entry. Routes to the
          // dedicated recordings history screen. The entry card
          // itself never blocks the page — it shows a friendly
          // "no recordings yet" subtitle for new children and a
          // pluralised count once the child has practised.
          RecordingsHistoryEntryCard(childId: child.id),

          const SizedBox(height: AppSpacing.lg),

          Text(
            l.recentAssessments,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          assessments.when(
            data: (res) {
              if (res.items.isEmpty) {
                return PremiumCard(
                  child: Row(
                    children: [
                      const ParrotMascot(mood: ParrotMood.idle, size: 56),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          l.noAssessmentsBody,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final recent = res.items.take(5).toList();
              return Column(
                children: [
                  for (final a in recent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: PremiumCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        onTap: () =>
                            context.go('/assessment/results/${a.id}'),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: RiskLevel.fromApi(a.overallRisk)
                                    .color
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(
                                Icons.assessment_rounded,
                                color: RiskLevel.fromApi(a.overallRisk).color,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        a.score == null
                                            ? '—'
                                            : '${(a.score! * 100).round()}%',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      RiskBadge.fromApi(
                                        risk: a.overallRisk,
                                        size: RiskBadgeSize.small,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(a.createdAt),
                                    style: const TextStyle(
                                      fontSize: 12,
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
                      ),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                children: [
                  ShimmerCard(height: 64),
                  ShimmerCard(height: 64),
                ],
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: AppSpacing.xl),

          PremiumButton(
            label: l.startAssessment,
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              ref.read(selectedChildIdProvider.notifier).state = child.id;
              context.go('/exercises');
            },
          ),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Child child,
  ) async {
    final l = L.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteChild),
        content: Text(l.deleteChildConfirm(child.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final lAfter = L.of(context)!;

    try {
      final api = ChildrenApi(ref.read(dioProvider));
      await api.delete(child.id);
      ref.invalidate(childrenProvider);
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(lAfter.childDeleted)));
      context.go('/children');
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(lAfter.networkError)));
    }
  }

  static int _age(DateTime birth) {
    final n = DateTime.now();
    int a = n.year - birth.year;
    if (n.month < birth.month ||
        (n.month == birth.month && n.day < birth.day)) {
      a--;
    }
    return a;
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.items});
  final List<Assessment> items;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final scored = items.where((a) => a.score != null).toList();
    final avg = scored.isEmpty
        ? 0.0
        : scored.map((a) => a.score!).reduce((a, b) => a + b) / scored.length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            color: AppColors.primary,
            icon: Icons.assessment_rounded,
            label: l.totalAssessments,
            value: '${items.length}',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            color: AppColors.secondary,
            icon: Icons.trending_up_rounded,
            label: l.averageScore,
            value: '${(avg * 100).round()}%',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      shadowColor: color,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
