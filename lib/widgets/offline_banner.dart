import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import 'loaders.dart';

/// Streams the current connectivity. Returns true when offline.
final isOfflineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  // Emit initial state.
  final initial = await c.checkConnectivity();
  yield initial.every((r) => r == ConnectivityResult.none);
  await for (final results in c.onConnectivityChanged) {
    yield results.every((r) => r == ConnectivityResult.none);
  }
});

/// Banner shown when device is offline OR when an explicit `message` is
/// provided (e.g. "showing cached data"). Animates in.
///
/// - With no args: auto-detects connectivity. While offline it renders a
///   warning bar with an inline retry button that re-checks connectivity.
/// - With `message`: renders unconditionally as an inline notice (no retry).
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;

    if (message != null) {
      return _Banner(text: message!, color: AppColors.warning);
    }

    final offline = ref.watch(isOfflineProvider).asData?.value ?? false;
    if (!offline) return const SizedBox.shrink();

    return _Banner(
      text: l.offline,
      color: AppColors.warning,
      onRetry: () => ref.invalidate(isOfflineProvider),
    ).animate().slideY(
          begin: -1,
          end: 0,
          duration: 220.ms,
        );
  }
}

class _Banner extends StatefulWidget {
  const _Banner({required this.text, required this.color, this.onRetry});
  final String text;
  final Color color;
  final VoidCallback? onRetry;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  bool _busy = false;

  Future<void> _handleRetry() async {
    if (widget.onRetry == null) return;
    setState(() => _busy = true);
    widget.onRetry!.call();
    // A short cosmetic delay so users *see* the spinner; the real check is
    // in the connectivity provider that we just invalidated.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                widget.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(width: AppSpacing.sm),
              _RetryPill(busy: _busy, label: l.retry, onTap: _handleRetry),
            ],
          ],
        ),
      ),
    );
  }
}

class _RetryPill extends StatelessWidget {
  const _RetryPill({
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const BrandedSpinner(
                color: Colors.white,
                size: 14,
                strokeWidth: 2,
              )
            else
              const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
