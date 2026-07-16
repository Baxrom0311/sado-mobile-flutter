import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/gamification.dart';
import '../core/theme.dart';
import 'parrot_mascot.dart';

/// Display a single badge in a grid. Locked badges are dimmed.
///
/// Tapping the tile (when [onTap] is provided) opens [showBadgeDetailSheet],
/// a polished detail bottom sheet that explains the badge — useful both as
/// a celebration for unlocked badges and as a "how to earn this" hint for
/// locked ones.
class BadgeTile extends StatelessWidget {
  const BadgeTile({
    super.key,
    required this.badge,
    required this.unlocked,
    required this.label,
    this.onTap,
  });

  final GameBadge badge;
  final bool unlocked;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tileLabel = unlocked
        ? '$label, ${l?.badgeStatusUnlocked ?? ''}'
        : '$label, ${l?.badgeStatusLocked ?? ''}';

    final tile = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: unlocked
                ? const LinearGradient(colors: AppColors.sunsetGradient)
                : null,
            color: unlocked ? null : AppColors.surfaceMuted,
            boxShadow: unlocked ? AppShadow.soft(AppColors.secondary) : null,
            border: Border.all(
              color: unlocked ? Colors.white : AppColors.border,
              width: 3,
            ),
          ),
          child: Center(
            child: Text(
              unlocked ? badge.emoji : '🔒',
              style: TextStyle(
                fontSize: 30,
                color: unlocked ? null : AppColors.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: unlocked ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ],
    );

    return Semantics(
      button: onTap != null,
      label: tileLabel,
      hint: l?.badgeDetailsHint,
      child: InkResponse(
        onTap: onTap,
        radius: 56,
        // Match the circular badge shape so the splash doesn't paint a
        // square halo on top of the round emoji puck.
        containedInkWell: true,
        customBorder: const CircleBorder(),
        child: tile,
      ),
    );
  }
}

/// Modal that pops in when a new badge is unlocked. Includes parrot mascot
/// celebrating, confetti is handled separately by the host.
Future<void> showBadgeUnlocked(
  BuildContext context, {
  required String emoji,
  required String title,
  required String body,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, __) {
      final curved =
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return Opacity(
        opacity: anim.value,
        child: Transform.scale(
          scale: 0.7 + curved.value * 0.3,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Material(
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                color: AppColors.surface,
                clipBehavior: Clip.antiAlias,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFF7E6), AppColors.surface],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ParrotMascot(
                        mood: ParrotMood.happy,
                        size: 110,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: AppColors.sunsetGradient,
                          ),
                          boxShadow: AppShadow.soft(AppColors.secondary),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 44),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Bottom sheet shown when a user taps a badge tile in the achievements
/// screen. Renders a hero badge, status pill, the achievement story (or
/// the "how to unlock" hint when locked) and a friendly footer.
///
/// The sheet matches the rest of the app's premium look:
/// - rounded 24-radius top corners
/// - sunset gradient hero band for unlocked badges, neutral for locked
/// - mascot reacts to status (happy when unlocked, idle when locked)
/// - all copy goes through `.arb` — no hardcoded user-facing strings
Future<void> showBadgeDetailSheet(
  BuildContext context, {
  required String badgeId,
  required bool unlocked,
  required String title,
  required String body,
  required String hint,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (sheetCtx) => BadgeDetailSheet(
      badgeId: badgeId,
      unlocked: unlocked,
      title: title,
      body: body,
      hint: hint,
    ),
  );
}

/// The actual sheet body. Public so widget tests can pump it directly
/// without going through `showModalBottomSheet` plumbing.
class BadgeDetailSheet extends StatelessWidget {
  const BadgeDetailSheet({
    super.key,
    required this.badgeId,
    required this.unlocked,
    required this.title,
    required this.body,
    required this.hint,
  });

  final String badgeId;
  final bool unlocked;
  final String title;
  final String body;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final emoji = GameBadge.emojiOf(badgeId);

    final statusLabel =
        unlocked ? l.badgeStatusUnlocked : l.badgeStatusLocked;
    final statusColor = unlocked ? AppColors.success : AppColors.textMuted;
    final footerText =
        unlocked ? l.badgeUnlockedFooter : l.badgeLockedFooter;
    final mood = unlocked ? ParrotMood.happy : ParrotMood.idle;

    final heroGradient = unlocked
        ? const [Color(0xFFFFF7E6), AppColors.surface]
        : const [AppColors.surfaceMuted, AppColors.surface];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xxl),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle so users know the sheet is dismissible by
              // dragging — even though tapping the scrim also works.
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: heroGradient,
                  ),
                ),
                child: Column(
                  children: [
                    ParrotMascot(mood: mood, size: 96)
                        .animate()
                        .fadeIn(duration: 280.ms)
                        .scale(
                          begin: const Offset(0.85, 0.85),
                          end: const Offset(1, 1),
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: AppSpacing.md),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: unlocked
                            ? const LinearGradient(
                                colors: AppColors.sunsetGradient,
                              )
                            : null,
                        color: unlocked ? null : AppColors.surface,
                        border: Border.all(
                          color: unlocked
                              ? Colors.white
                              : AppColors.border,
                          width: 4,
                        ),
                        boxShadow: unlocked
                            ? AppShadow.soft(AppColors.secondary)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          unlocked ? emoji : '🔒',
                          style: TextStyle(
                            fontSize: 44,
                            color: unlocked
                                ? null
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (unlocked) ...[
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ] else ...[
                      Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        footerText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l.close),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
