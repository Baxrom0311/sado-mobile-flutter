import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../core/utils/relative_time.dart';
import '../../data/api/api_client.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/audio_example_player.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/shimmer_loaders.dart';

/// Bucket used to group a child's recordings into time-of-life sections
/// on the recordings history screen. Order matters — the screen renders
/// sections in declaration order so the most recent activity always
/// floats to the top.
enum RecordingsBucket { today, thisWeek, thisMonth, earlier }

/// Pure projection: takes a child's assessment list (already filtered
/// to those with a non-null `audioPath`) and groups it into the four
/// [RecordingsBucket]s. Kept framework-free so the unit tests can
/// exercise it without Flutter bindings.
///
/// Buckets:
///   * **today** — `createdAt` falls on the same calendar day as `now`.
///   * **thisWeek** — within the last 7 days but not today.
///   * **thisMonth** — within the last 30 days but not this week.
///   * **earlier** — anything older.
///
/// Within every bucket the order is preserved (which means the caller
/// is responsible for sorting newest-first up-front; the API already
/// does that).
Map<RecordingsBucket, List<Assessment>> bucketRecordings(
  Iterable<Assessment> recordings, {
  DateTime? now,
}) {
  final reference = _atMidnight(now ?? DateTime.now());
  final out = <RecordingsBucket, List<Assessment>>{
    RecordingsBucket.today: <Assessment>[],
    RecordingsBucket.thisWeek: <Assessment>[],
    RecordingsBucket.thisMonth: <Assessment>[],
    RecordingsBucket.earlier: <Assessment>[],
  };
  for (final a in recordings) {
    final days = reference.difference(_atMidnight(a.createdAt)).inDays;
    if (days <= 0) {
      out[RecordingsBucket.today]!.add(a);
    } else if (days < 7) {
      out[RecordingsBucket.thisWeek]!.add(a);
    } else if (days < 30) {
      out[RecordingsBucket.thisMonth]!.add(a);
    } else {
      out[RecordingsBucket.earlier]!.add(a);
    }
  }
  return out;
}

DateTime _atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// Browse-and-replay screen for every audio recording a child has made.
///
/// Source of truth is the existing per-child [assessmentsProvider] — we
/// filter to assessments that ship a non-null `audioPath` so the parent
/// only sees rows they can actually replay. The screen never refetches
/// recordings on its own; pulling-to-refresh invalidates the underlying
/// provider so any other screens reading the same data stay in lockstep.
///
/// Render contract — every state has a custom branded experience, no
/// raw Material spinners or default empty pages:
///
/// * **Loading** — three stacked shimmer cards.
/// * **Error** — branded [ErrorState] with retry that invalidates the
///   underlying assessments provider.
/// * **Empty** — parrot mascot + friendly copy + CTA pointing to the
///   exercises catalogue so the next recording is one tap away.
/// * **Loaded** — sections (Today / This week / This month / Earlier)
///   with one [_RecordingTile] per row. Each tile carries an inline
///   [AudioExamplePlayer] that streams the recording from the API and
///   a "Batafsil" link to the full results screen.
class RecordingsHistoryScreen extends ConsumerWidget {
  const RecordingsHistoryScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final children = ref.watch(childrenProvider);
    final assessments = ref.watch(assessmentsProvider(childId));

    Child? matchedChild;
    children.whenData((res) {
      for (final c in res.items) {
        if (c.id == childId) {
          matchedChild = c;
          break;
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          matchedChild != null
              ? '${matchedChild!.name} • ${l.recordingsHistoryTitle}'
              : l.recordingsHistoryTitle,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/children/$childId');
            }
          },
        ),
      ),
      body: assessments.when(
        loading: () => const _RecordingsLoading(),
        error: (_, __) => ErrorState(
          title: l.recordingsHistoryErrorTitle,
          body: l.recordingsHistoryErrorBody,
          retryLabel: l.recordingsHistoryRetry,
          onRetry: () => ref.invalidate(assessmentsProvider(childId)),
        ),
        data: (res) {
          final recordings = res.items
              .where((a) => (a.audioPath ?? '').trim().isNotEmpty)
              .toList(growable: false);
          if (recordings.isEmpty) {
            return _RecordingsEmpty(
              onCta: () => context.go('/exercises'),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(assessmentsProvider(childId));
            },
            child: _RecordingsBody(
              recordings: recordings,
              fromCache: res.fromCache,
            ),
          );
        },
      ),
    );
  }
}

class _RecordingsLoading extends StatelessWidget {
  const _RecordingsLoading();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Semantics(
      label: l.recordingsHistoryLoading,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          ShimmerCard(height: 132),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 132),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 132),
        ],
      ),
    );
  }
}

class _RecordingsEmpty extends StatelessWidget {
  const _RecordingsEmpty({required this.onCta});

  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: EmptyState(
          title: l.recordingsHistoryEmptyTitle,
          body: l.recordingsHistoryEmptyBody,
          ctaLabel: l.recordingsHistoryEmptyCta,
          ctaIcon: Icons.play_arrow_rounded,
          onCta: onCta,
          mood: ParrotMood.idle,
        ),
      ),
    );
  }
}

class _RecordingsBody extends StatelessWidget {
  const _RecordingsBody({
    required this.recordings,
    required this.fromCache,
  });

  final List<Assessment> recordings;
  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final buckets = bucketRecordings(recordings);

    final children = <Widget>[];
    if (fromCache) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: OfflineBanner(message: l.offlineCached),
      ));
    }

    var animationIndex = 0;
    for (final bucket in RecordingsBucket.values) {
      final items = buckets[bucket]!;
      if (items.isEmpty) continue;
      children
        ..add(_SectionHeader(label: _bucketLabel(l, bucket)))
        ..add(const SizedBox(height: AppSpacing.sm));
      for (final a in items) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _RecordingTile(assessment: a)
                .animate(delay: (animationIndex * 40).ms)
                .fadeIn(duration: 240.ms)
                .slideY(begin: 0.06),
          ),
        );
        animationIndex++;
      }
      children.add(const SizedBox(height: AppSpacing.sm));
    }
    children.add(const SizedBox(height: AppSpacing.huge));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: children,
    );
  }

  static String _bucketLabel(L l, RecordingsBucket bucket) {
    switch (bucket) {
      case RecordingsBucket.today:
        return l.recordingsHistorySectionToday;
      case RecordingsBucket.thisWeek:
        return l.recordingsHistorySectionThisWeek;
      case RecordingsBucket.thisMonth:
        return l.recordingsHistorySectionThisMonth;
      case RecordingsBucket.earlier:
        return l.recordingsHistorySectionEarlier;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// One recording row. Combines the score / risk header, the inline
/// [AudioExamplePlayer] and a "view details" link in a single
/// [PremiumCard].
class _RecordingTile extends StatelessWidget {
  const _RecordingTile({required this.assessment});

  final Assessment assessment;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final risk = RiskLevel.fromApi(assessment.overallRisk);
    final relative = formatRelativeDate(l, assessment.createdAt);
    final url = resolveMediaUrl(assessment.audioPath);

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: risk.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.graphic_eq_rounded, color: risk.color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          assessment.score == null
                              ? '—'
                              : '${(assessment.score! * 100).round()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        RiskBadge.fromApi(
                          risk: assessment.overallRisk,
                          size: RiskBadgeSize.small,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      relative,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (url != null)
            AudioExamplePlayer(
              key: ValueKey('audio-${assessment.id}'),
              url: url,
              label: l.recordingsHistoryPlayLabel,
              errorLabel: l.recordingsHistoryPlayError,
              color: risk.color,
            )
          else
            _NoAudioBanner(label: l.recordingsHistoryNoAudio),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () =>
                  context.go('/assessment/results/${assessment.id}'),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(l.recordingsHistoryViewDetails),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoAudioBanner extends StatelessWidget {
  const _NoAudioBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_off_rounded, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline CTA inserted into [ChildDetailScreen] so parents can hop into
/// the recordings history with a single tap. Lives in this file so the
/// screen and its entry point stay in lockstep.
class RecordingsHistoryEntryCard extends ConsumerWidget {
  const RecordingsHistoryEntryCard({super.key, required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final assessments = ref.watch(assessmentsProvider(childId));

    final count = assessments.maybeWhen<int>(
      data: (res) => res.items
          .where((a) => (a.audioPath ?? '').trim().isNotEmpty)
          .length,
      orElse: () => 0,
    );

    final subtitle = count == 0
        ? l.recordingsHistoryEntrySubtitleEmpty
        : l.recordingsHistoryEntrySubtitle(count);

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: () => context.go('/children/$childId/recordings'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.recordingsHistoryEntryTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
