import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/gamification.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/streak_chip.dart';
import '../../widgets/xp_bar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final auth = ref.watch(authProvider);
    final game = ref.watch(gameProvider);
    final user = auth.user;
    final initial = (user?.fullName.isNotEmpty == true)
        ? user!.fullName[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.profile),
        actions: [
          IconButton(
            tooltip: l.editProfile,
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.go('/profile/edit'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          PremiumCard(
            gradient: AppColors.heroGradient,
            shadowColor: AppColors.primary,
            padding: const EdgeInsets.all(AppSpacing.lg),
            onTap: () => context.go('/profile/edit'),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppShadow.card,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? '—',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.05),

          const SizedBox(height: AppSpacing.lg),

          PremiumCard(
            child: XpBar(state: game),
          ).animate(delay: 80.ms).fadeIn(),

          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              StreakChip(days: game.streakDays, label: l.streakDays),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PremiumCard(
                  onTap: () => context.go('/badges'),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Text('🏆',
                          style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 6),
                      Text(
                        '${game.badges.length} ${l.badges}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          _AccountStatsCard(user: user, game: game)
              .animate(delay: 140.ms)
              .fadeIn()
              .slideY(begin: 0.05),

          const SizedBox(height: AppSpacing.xl),

          _MenuTile(
            icon: Icons.edit_rounded,
            label: l.editProfile,
            color: AppColors.primary,
            onTap: () => context.go('/profile/edit'),
          ),
          _MenuTile(
            key: const ValueKey('profile.menu.children'),
            icon: Icons.child_care_rounded,
            label: l.children,
            color: AppColors.primary,
            onTap: () => context.go('/children'),
          ),
          _MenuTile(
            key: const ValueKey('profile.menu.badges'),
            icon: Icons.workspace_premium_rounded,
            label: l.badges,
            color: AppColors.secondary,
            onTap: () => context.go('/badges'),
          ),
          _MenuTile(
            key: const ValueKey('profile.menu.progress'),
            icon: Icons.trending_up_rounded,
            label: l.progress,
            color: AppColors.tertiary,
            onTap: () => context.go('/progress'),
          ),
          _MenuTile(
            key: const ValueKey('profile.menu.timeline'),
            icon: Icons.history_rounded,
            label: l.profileMenuTimeline,
            color: AppColors.fire,
            onTap: () => context.go('/timeline'),
          ),
          _MenuTile(
            key: const ValueKey('profile.menu.settings'),
            icon: Icons.settings_rounded,
            label: l.settings,
            color: AppColors.sky,
            onTap: () => context.go('/settings'),
          ),

          const SizedBox(height: AppSpacing.xl),

          PremiumCard(
            shadowColor: AppColors.danger,
            padding: EdgeInsets.zero,
            onTap: () => _confirmLogout(context, ref),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: AppColors.danger),
              title: Text(
                l.logout,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Mascot footer
          Center(
            child: Column(
              children: [
                const ParrotMascot(mood: ParrotMood.idle, size: 96),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l.appTagline,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l = L.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.logoutConfirmTitle),
        content: Text(l.logoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.logout),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      await ref.read(gameProvider.notifier).reset();
    }
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// "Account stats" tile shown on the profile screen. Surfaces the four
/// numbers the brief calls out: total assessments, longest streak,
/// children count and member-since date.
///
/// Each stat reads its own provider so a network failure on one source
/// (e.g. children) doesn't blank out the others — failed reads degrade
/// to a "—" placeholder, keeping the rest of the card visible.
class _AccountStatsCard extends ConsumerWidget {
  const _AccountStatsCard({required this.user, required this.game});

  final User? user;
  final GameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    final assessments = ref.watch(assessmentsProvider(null));
    final children = ref.watch(childrenProvider);

    String numOrDash(AsyncValue<dynamic> v, int Function(dynamic) extract) {
      return v.maybeWhen(
        data: (d) => extract(d).toString(),
        orElse: () => '—',
      );
    }

    final assessmentsCount =
        numOrDash(assessments, (d) => (d.items as List).length);
    final childrenCount =
        numOrDash(children, (d) => (d.items as List).length);

    final memberSince = user?.createdAt == null
        ? '—'
        : DateFormat.yMMMd(localeTag).format(user!.createdAt.toLocal());

    final longest = game.longestStreak >= game.streakDays
        ? game.longestStreak
        : game.streakDays;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l.accountStats,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  icon: Icons.assignment_turned_in_rounded,
                  color: AppColors.primary,
                  label: l.totalAssessments,
                  value: assessmentsCount,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatCell(
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.secondary,
                  label: l.longestStreak,
                  value: l.daysShort(longest),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  icon: Icons.child_care_rounded,
                  color: AppColors.tertiary,
                  label: l.children,
                  value: childrenCount,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatCell(
                  icon: Icons.calendar_today_rounded,
                  color: AppColors.sky,
                  label: l.memberSince,
                  value: memberSince,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
