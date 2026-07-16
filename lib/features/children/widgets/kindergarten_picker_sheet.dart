import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../../core/theme.dart';
import '../../../data/models/models.dart';
import '../../../providers/providers.dart';
import '../../../widgets/feedback/empty_state.dart';
import '../../../widgets/parrot_mascot.dart';
import '../../../widgets/shimmer_loaders.dart';

/// Result returned from the kindergarten picker.
///
/// Three outcomes are possible:
///   * `null` — the user dismissed the sheet without making a choice. The
///     caller should not change the current selection.
///   * `KindergartenPickerResult.cleared()` — the user explicitly chose
///     "no kindergarten" so the caller should clear any prior selection.
///   * `KindergartenPickerResult.selected(k)` — the user picked a record.
class KindergartenPickerResult {
  const KindergartenPickerResult._(this.kindergarten);

  /// `null` means the selection was cleared.
  final Kindergarten? kindergarten;

  factory KindergartenPickerResult.selected(Kindergarten k) =>
      KindergartenPickerResult._(k);
  factory KindergartenPickerResult.cleared() =>
      const KindergartenPickerResult._(null);

  bool get isCleared => kindergarten == null;
}

/// Searchable kindergarten picker. Renders a sticky search field, a debounced
/// async result list, and a shimmer loading state. Shows an empty-state
/// (parrot + localized copy) when the search returns no matches.
///
/// Use [showKindergartenPickerSheet] to present this from a screen — that
/// helper handles the modal scaffolding, themed background and rounded
/// corners.
class KindergartenPickerSheet extends ConsumerStatefulWidget {
  const KindergartenPickerSheet({
    super.key,
    this.selectedId,
    this.debounce = const Duration(milliseconds: 280),
  });

  /// Currently-attached kindergarten id, used to highlight the active row.
  final String? selectedId;

  /// Search debounce. Exposed so widget tests can drop it to zero.
  final Duration debounce;

  @override
  ConsumerState<KindergartenPickerSheet> createState() =>
      _KindergartenPickerSheetState();
}

class _KindergartenPickerSheetState
    extends ConsumerState<KindergartenPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (widget.debounce == Duration.zero) {
      if (mounted) setState(() => _query = trimmed);
      return;
    }
    _debounce = Timer(widget.debounce, () {
      if (!mounted) return;
      setState(() => _query = trimmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final media = MediaQuery.of(context);
    final results = ref.watch(kindergartensSearchProvider(_query));

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: AppSpacing.lg + media.viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: media.size.height * 0.78,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle.
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l.selectKindergarten,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.kindergartenSheetBody,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _controller,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l.kindergartensSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.selectedId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context)
                        .pop(KindergartenPickerResult.cleared()),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    label: Text(l.clearKindergarten),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
              Flexible(
                child: results.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return EmptyState(
                        title: l.noKindergartens,
                        body: l.noKindergartensBody,
                        mood: ParrotMood.sad,
                        mascotSize: 110,
                        compact: true,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final k = items[i];
                        return _KindergartenTile(
                          kindergarten: k,
                          selected: k.id == widget.selectedId,
                          onTap: () => Navigator.of(context).pop(
                            KindergartenPickerResult.selected(k),
                          ),
                        )
                            .animate(delay: (i * 30).ms)
                            .fadeIn()
                            .slideY(begin: 0.04);
                      },
                    );
                  },
                  loading: () => const _PickerSkeleton(),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: EmptyState(
                      title: l.errorTitle,
                      body: l.tryAgainLater,
                      mood: ParrotMood.sad,
                      mascotSize: 110,
                      compact: true,
                      ctaLabel: l.retry,
                      ctaIcon: Icons.refresh_rounded,
                      onCta: () => ref
                          .invalidate(kindergartensSearchProvider(_query)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindergartenTile extends StatelessWidget {
  const _KindergartenTile({
    required this.kindergarten,
    required this.selected,
    required this.onTap,
  });

  final Kindergarten kindergarten;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.tertiary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.10)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? color : AppColors.surfaceMuted,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kindergarten.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (kindergarten.address != null &&
                        kindergarten.address!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        kindergarten.address!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color:
                    selected ? color : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerSkeleton extends StatelessWidget {
  const _PickerSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const ShimmerBox(height: 64, radius: 16),
    );
  }
}

/// Show the picker as a modal bottom sheet. Returns:
///   * `null` if dismissed,
///   * a [KindergartenPickerResult] when the user selects or clears.
Future<KindergartenPickerResult?> showKindergartenPickerSheet({
  required BuildContext context,
  String? selectedId,
}) {
  return showModalBottomSheet<KindergartenPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.xxl),
      ),
    ),
    builder: (_) => KindergartenPickerSheet(selectedId: selectedId),
  );
}
