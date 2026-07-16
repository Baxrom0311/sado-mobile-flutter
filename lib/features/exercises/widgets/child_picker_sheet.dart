import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../../core/theme.dart';
import '../../../data/models/models.dart';

/// Modal bottom sheet that lets the user pick which of their children the
/// upcoming assessment is for.
///
/// Returns the chosen [Child.id] via the `Navigator.pop` value, or `null` if
/// the user dismissed the sheet without choosing. Use via
/// [showChildPickerSheet] which handles that wiring.
class ChildPickerSheet extends StatelessWidget {
  const ChildPickerSheet({
    super.key,
    required this.children,
    required this.selectedId,
    this.onAddChild,
  });

  final List<Child> children;
  final String? selectedId;
  final VoidCallback? onAddChild;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final media = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: AppSpacing.lg + media.viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
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
              l.chooseChildSheetTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.chooseChildSheetBody,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: children.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final c = children[i];
                  return _ChildTile(
                    child: c,
                    selected: c.id == selectedId,
                    onTap: () => Navigator.of(context).pop<String>(c.id),
                  ).animate(delay: (i * 40).ms).fadeIn().slideY(begin: 0.05);
                },
              ),
            ),
            if (onAddChild != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onAddChild!.call();
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(l.addChildShort),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChildTile extends StatelessWidget {
  const _ChildTile({
    required this.child,
    required this.selected,
    required this.onTap,
  });

  final Child child;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = child.gender == 'male' ? AppColors.sky : AppColors.pink;
    final today = DateTime.now();
    final age = today.year - child.birthDate.year -
        ((today.month < child.birthDate.month ||
                (today.month == child.birthDate.month &&
                    today.day < child.birthDate.day))
            ? 1
            : 0);
    final l = L.of(context)!;

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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  child.gender == 'male'
                      ? Icons.face_6_rounded
                      : Icons.face_3_rounded,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$age ${l.yearsOld}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? color : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convenience helper: shows the picker as a modal bottom sheet and returns
/// the chosen [Child.id], or `null` if dismissed.
Future<String?> showChildPickerSheet({
  required BuildContext context,
  required List<Child> children,
  required String? selectedId,
  VoidCallback? onAddChild,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.xxl),
      ),
    ),
    builder: (_) => ChildPickerSheet(
      children: children,
      selectedId: selectedId,
      onAddChild: onAddChild,
    ),
  );
}
