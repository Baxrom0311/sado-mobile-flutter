import 'package:flutter/material.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/gamification.dart';
import '../core/theme.dart';

/// XP bar with animated fill, level icon and current/next XP labels.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final levelName = _localizedLevel(l, state.level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.sunsetGradient,
                ),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: AppShadow.soft(AppColors.secondary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${l.level} ${state.level}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                levelName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${state.xp} XP',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.secondaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LayoutBuilder(
            builder: (_, c) {
              return Stack(
                children: [
                  Container(
                    height: 12,
                    color: AppColors.surfaceMuted,
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: state.levelProgress),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Container(
                      height: 12,
                      width: c.maxWidth * v,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.sunsetGradient,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${state.xpInLevel} / ${state.xpNeededInLevel} XP',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _localizedLevel(L l, int level) {
    if (level <= 2) return l.levelBeginner;
    if (level <= 5) return l.levelExplorer;
    if (level <= 9) return l.levelChampion;
    return l.levelMaster;
  }
}
