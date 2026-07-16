import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/local/preferences.dart';
import '../../providers/providers.dart';
import '../../widgets/child_avatar.dart';
import '../../widgets/premium_card.dart';

// Re-export the persistent locale provider so legacy imports of
// `settings_screen.dart` keep working without a behavioural change.
export '../../data/local/preferences.dart' show localeProvider;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final locale = ref.watch(localeProvider);
    final notificationsOn = ref.watch(notificationsEnabledProvider);
    final quality = ref.watch(audioQualityProvider);
    // Watching authProvider here serves two purposes:
    //   1. Renders the signed-in user header at the top of the settings list.
    //   2. Eagerly instantiates AuthNotifier so widget tests that override it
    //      can capture the notifier instance before the user hits "Logout".
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.settings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/profile'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (auth.user != null) ...[
            _SectionTitle(label: l.settingsAccountSection),
            PremiumCard(
              key: const Key('settings.account.card'),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  ChildAvatar(
                    name: auth.user!.fullName,
                    size: ChildAvatarSize.md,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.signedInAs,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auth.user!.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auth.user!.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          _SectionTitle(label: l.language),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.language_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      locale.languageCode == 'uz'
                          ? l.uzbekLanguage
                          : l.russianLanguage,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _LangTile(
                        selected: locale.languageCode == 'uz',
                        label: l.uzbek,
                        flag: '🇺🇿',
                        onTap: () => ref
                            .read(localeProvider.notifier)
                            .setLocale(const Locale('uz')),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _LangTile(
                        selected: locale.languageCode == 'ru',
                        label: l.russian,
                        flag: '🇷🇺',
                        onTap: () => ref
                            .read(localeProvider.notifier)
                            .setLocale(const Locale('ru')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(label: l.notifications),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('settings.notifications.toggle'),
                  secondary: const Icon(Icons.notifications_rounded,
                      color: AppColors.primary),
                  title: Text(l.notificationsToggleTitle,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    notificationsOn
                        ? l.notificationsOnHint
                        : l.notificationsOffHint,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: notificationsOn,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => ref
                      .read(notificationsEnabledProvider.notifier)
                      .setEnabled(v),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(label: l.audioQualitySection),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.high_quality_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(l.audioQualityTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.audioQualitySubtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _QualityTile(
                        selected: quality == AudioQuality.low,
                        label: l.audioQualityLow,
                        hint: l.audioQualityLowHint,
                        onTap: () => ref
                            .read(audioQualityProvider.notifier)
                            .setQuality(AudioQuality.low),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _QualityTile(
                        selected: quality == AudioQuality.standard,
                        label: l.audioQualityStandard,
                        hint: l.audioQualityStandardHint,
                        onTap: () => ref
                            .read(audioQualityProvider.notifier)
                            .setQuality(AudioQuality.standard),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _QualityTile(
                        selected: quality == AudioQuality.high,
                        label: l.audioQualityHigh,
                        hint: l.audioQualityHighHint,
                        onTap: () => ref
                            .read(audioQualityProvider.notifier)
                            .setQuality(AudioQuality.high),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(label: l.subscriptionTitle),
          PremiumCard(
            key: const Key('settings.subscription.card'),
            padding: EdgeInsets.zero,
            onTap: () => context.go('/subscription'),
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.heroGradient,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                ),
              ),
              title: Text(
                l.subscriptionMenuRow,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                l.subscriptionMenuRowHint,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: GestureDetector(
                key: const Key('settings.subscription.manageHandle'),
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go('/subscription/status'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Tooltip(
                    message: l.subscriptionStatusManageMenuRow,
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(label: l.helpAndTips),
          PremiumCard(
            key: const Key('settings.help.card'),
            padding: EdgeInsets.zero,
            onTap: () => context.go('/help'),
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: AppColors.primary,
                ),
              ),
              title: Text(
                l.helpAndTips,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                l.helpAndTipsHint,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(label: l.about),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.info_outline_rounded,
                  label: l.version,
                  value: '1.0.0',
                ),
                const Divider(height: 1, color: AppColors.border),
                _InfoRow(
                  key: const Key('settings.about.support'),
                  icon: Icons.support_agent_rounded,
                  label: l.support,
                  value: l.aboutSupportEmail,
                  onTap: () => _copySupportEmail(context, l),
                ),
                const Divider(height: 1, color: AppColors.border),
                _InfoRow(
                  key: const Key('settings.about.terms'),
                  icon: Icons.policy_rounded,
                  label: l.termsAndPrivacy,
                  value: '',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted),
                  onTap: () => context.go('/settings/about'),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          PremiumCard(
            key: const Key('settings.logout.card'),
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
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }
}

/// Shows a centered confirmation dialog before invoking the destructive
/// [AuthNotifier.logout] action. Logging out drops the user back to the
/// login screen, so the brief calls for an explicit "are you sure?" gate
/// to avoid accidental sign-outs from a single tap on the danger card.
Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final l = L.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('settings.logout.dialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(
        l.logoutConfirmTitle,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: Text(
        l.logoutConfirmBody,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      actions: [
        TextButton(
          key: const Key('settings.logout.cancel'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            l.cancel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          key: const Key('settings.logout.confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            l.logout,
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(authProvider.notifier).logout();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          left: AppSpacing.xs, bottom: AppSpacing.sm, top: AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  const _LangTile({
    required this.selected,
    required this.label,
    required this.flag,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final String flag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                )),
          ],
        ),
      ),
    );
  }
}

class _QualityTile extends StatelessWidget {
  const _QualityTile({
    required this.selected,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: trailing ??
          Text(value,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              )),
    );
  }
}

/// Copies the canonical support email to the system clipboard and shows
/// a confirmation snackbar. Used by the dedicated "Support" row in the
/// Settings → About section so a tap actually does something useful.
///
/// The clipboard write is fire-and-forget: if the platform plugin is
/// missing (web fallbacks, restricted environments), we still surface
/// the snackbar so the user always knows which email address to use.
void _copySupportEmail(BuildContext context, L l) {
  final email = l.aboutSupportEmail;
  Clipboard.setData(ClipboardData(text: email)).catchError((_) {});
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l.aboutEmailCopied(email)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
