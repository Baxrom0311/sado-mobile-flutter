import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../core/utils/relative_time.dart';
import '../../data/models/models.dart';
import '../../data/services/pending_uploads_service.dart';
import '../../providers/providers.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/loaders.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/shimmer_loaders.dart';

/// Dedicated management screen for the offline upload queue.
///
/// Lists every assessment-audio job that is still waiting to be sent,
/// joined with the child + exercise it belongs to so the user sees who/what
/// the recording is for instead of opaque IDs. Each row offers per-item
/// retry and discard. A primary "Retry all" button at the top mirrors the
/// chip behaviour but lives on a dedicated surface so it's easier to find.
class PendingUploadsScreen extends ConsumerStatefulWidget {
  const PendingUploadsScreen({super.key});

  @override
  ConsumerState<PendingUploadsScreen> createState() =>
      _PendingUploadsScreenState();
}

class _PendingUploadsScreenState extends ConsumerState<PendingUploadsScreen> {
  bool _retryingAll = false;
  // Track in-flight per-row work so we can show a spinner on the right row
  // without blocking the rest of the list.
  final Set<String> _retryingIds = <String>{};

  Future<bool> _isOffline() async {
    final results = await Connectivity().checkConnectivity();
    return results.every((r) => r == ConnectivityResult.none);
  }

  Future<void> _retryAll() async {
    if (_retryingAll) return;
    final l = L.of(context)!;
    setState(() => _retryingAll = true);
    try {
      if (await _isOffline()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.pendingUploadOfflineHint)),
        );
        return;
      }
      final result = await flushPendingUploads(ref);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (result.failed > 0) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.uploadsFailedSome(result.failed))),
        );
      } else if (result.succeeded > 0) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.uploadsAllSent)),
        );
      }
    } finally {
      if (mounted) setState(() => _retryingAll = false);
    }
  }

  Future<void> _retryOne(PendingUpload job) async {
    if (_retryingIds.contains(job.id)) return;
    final l = L.of(context)!;
    setState(() => _retryingIds.add(job.id));
    try {
      if (await _isOffline()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.pendingUploadOfflineHint)),
        );
        return;
      }
      final service =
          await ref.read(pendingUploadsServiceProvider.future);
      final api = ref.read(assessmentsApiProvider);
      final remaining = await service.retryOne(job.id, api);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (remaining == null) {
        // Success — the job is gone. Refresh assessments so the new
        // submission shows up everywhere it's listed.
        ref.invalidate(assessmentsProvider);
        messenger.showSnackBar(SnackBar(content: Text(l.uploadsAllSent)));
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(l.uploadsFailedSome(1))),
        );
      }
    } finally {
      if (mounted) setState(() => _retryingIds.remove(job.id));
    }
  }

  Future<void> _discardOne(PendingUpload job) async {
    final l = L.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.pendingUploadDiscard),
        content: Text(l.pendingUploadDiscardConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final service = await ref.read(pendingUploadsServiceProvider.future);
    await service.remove(job.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.pendingUploadDiscarded)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final list = ref.watch(pendingUploadsListProvider);
    final children = ref.watch(childrenProvider);
    final exercises = ref.watch(exercisesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.pendingUploadsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: list.when(
        loading: () => const ShimmerList(),
        error: (_, __) => EmptyState(
          title: l.errorTitle,
          body: l.tryAgainLater,
          mood: ParrotMood.sad,
          ctaIcon: Icons.refresh_rounded,
          ctaLabel: l.retry,
          onCta: () => ref.invalidate(pendingUploadsListProvider),
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return EmptyState(
              title: l.pendingUploadsAllSent,
              body: l.pendingUploadsAllSentBody,
              mood: ParrotMood.happy,
              ctaLabel: l.home,
              ctaIcon: Icons.home_rounded,
              onCta: () => context.go('/'),
            );
          }
          // Pre-resolve children + exercises once per build so each row
          // can do an O(1) lookup without re-walking the lists.
          final byChildId = <String, Child>{
            for (final c in children.asData?.value.items ?? const <Child>[])
              c.id: c,
          };
          final byExerciseId = <String, Exercise>{
            for (final e in exercises.asData?.value.items ??
                const <Exercise>[])
              e.id: e,
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.huge,
            ),
            children: [
              _Header(count: jobs.length, subtitle: l.pendingUploadsSubtitle),
              const SizedBox(height: AppSpacing.lg),
              PremiumButton(
                label: l.pendingUploadsRetryAll,
                icon: Icons.cloud_upload_rounded,
                loading: _retryingAll,
                onPressed: _retryingAll ? null : _retryAll,
              ),
              const SizedBox(height: AppSpacing.lg),
              for (var i = 0; i < jobs.length; i++) ...[
                _PendingUploadTile(
                  job: jobs[i],
                  child: byChildId[jobs[i].childId],
                  exercise: byExerciseId[jobs[i].exerciseId],
                  retrying: _retryingIds.contains(jobs[i].id),
                  onRetry: () => _retryOne(jobs[i]),
                  onDiscard: () => _discardOne(jobs[i]),
                ).animate(delay: (i * 60).ms).fadeIn(duration: 220.ms).slideY(
                      begin: 0.05,
                      end: 0,
                    ),
                if (i != jobs.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.subtitle});

  final int count;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return PremiumCard(
      gradient: const [AppColors.secondary, AppColors.secondaryDark],
      shadowColor: AppColors.secondary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.cloud_upload_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.uploadsPending(count),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingUploadTile extends StatelessWidget {
  const _PendingUploadTile({
    required this.job,
    required this.child,
    required this.exercise,
    required this.retrying,
    required this.onRetry,
    required this.onDiscard,
  });

  final PendingUpload job;
  final Child? child;
  final Exercise? exercise;
  final bool retrying;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final childName = child?.name ?? l.pendingUploadUnknownChild;
    final exerciseTitle = exercise?.title ?? l.pendingUploadUnknownExercise;
    final whenLabel = formatRelativeDate(l, job.createdAt);

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                color: AppColors.categoryColor(exercise?.category ?? ''),
                icon: Icons.mic_rounded,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l.pendingUploadChildLabel}: $childName',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: l.pendingUploadAddedAt(whenLabel),
                tone: _ChipTone.neutral,
              ),
              _MetaChip(
                icon: Icons.refresh_rounded,
                label: l.pendingUploadRetries(job.retries),
                tone: job.retries == 0 ? _ChipTone.neutral : _ChipTone.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: retrying ? null : onRetry,
                  icon: retrying
                      ? const BrandedSpinner(
                          color: AppColors.primary,
                          size: 16,
                          strokeWidth: 2,
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(l.uploadsRetryNow),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: l.pendingUploadDiscard,
                onPressed: retrying ? null : onDiscard,
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.danger,
                style: IconButton.styleFrom(
                  backgroundColor:
                      AppColors.danger.withValues(alpha: 0.10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  minimumSize: const Size(48, 44),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

enum _ChipTone { neutral, warning }

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final isWarn = tone == _ChipTone.warning;
    final fg = isWarn ? AppColors.warning : AppColors.textSecondary;
    final bg = isWarn
        ? AppColors.warning.withValues(alpha: 0.12)
        : AppColors.surfaceMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
