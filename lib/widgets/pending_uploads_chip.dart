import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../providers/providers.dart';

/// Compact pill that announces queued offline uploads. Tap to open the
/// dedicated [PendingUploadsScreen] where the user can retry or discard
/// individual recordings. Renders nothing when the queue is empty.
class PendingUploadsChip extends ConsumerWidget {
  const PendingUploadsChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final count = ref.watch(pendingUploadsCountProvider).asData?.value ?? 0;
    if (count == 0) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: l.uploadsPending(count),
      child: GestureDetector(
        onTap: () => context.go('/uploads'),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.warning,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadow.soft(AppColors.warning),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_upload_rounded,
                  color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                l.uploadsPending(count),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 220.ms).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
        );
  }
}
