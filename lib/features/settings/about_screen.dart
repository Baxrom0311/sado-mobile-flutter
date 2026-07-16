import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_card.dart';

/// Public, app-store-ready About / Legal screen.
///
/// Reachable from Settings → "Terms & Privacy". Shows:
///   • A premium hero with the mascot, app name and version.
///   • A friendly description of what SADO does.
///   • Terms of Service and Privacy Policy as expandable cards
///     (long-form copy lives in the .arb files — never hard-coded).
///   • Support card with a copy-email action that surfaces a snackbar.
///   • Open-source licenses tile that defers to Flutter's built-in
///     [showLicensePage] so we never lie about what we ship.
///
/// All user-facing strings come from `L.of(context)` — there are no
/// hard-coded labels in this file beyond the email constant, which is
/// also exposed via the .arb so translators can localise the format.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.appVersion = '1.0.0'});

  /// Shown in the hero card and license dialog. Defaults to the value
  /// in `pubspec.yaml`. Tests can pin a known version for golden checks.
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.aboutTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // Prefer the GoRouter back stack; fall back to /settings if
            // we landed here via a deep link with no history.
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Hero(version: appVersion)
              .animate()
              .fadeIn(duration: 320.ms)
              .slideY(begin: -0.06),
          const SizedBox(height: AppSpacing.lg),
          _DescriptionCard(text: l.aboutAppDescription)
              .animate(delay: 80.ms)
              .fadeIn()
              .slideY(begin: 0.05),
          const SizedBox(height: AppSpacing.lg),
          _LegalSection(
            heading: l.aboutTermsHeading,
            body: l.aboutTermsBody,
            icon: Icons.description_outlined,
            openLabel: l.aboutTermsOpen,
            sectionKey: const Key('about.terms'),
          ),
          const SizedBox(height: AppSpacing.md),
          _LegalSection(
            heading: l.aboutPrivacyHeading,
            body: l.aboutPrivacyBody,
            icon: Icons.lock_outline_rounded,
            openLabel: l.aboutPrivacyOpen,
            sectionKey: const Key('about.privacy'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SupportCard(
            heading: l.aboutSupportHeading,
            body: l.aboutSupportBody,
            email: l.aboutSupportEmail,
            copyLabel: l.aboutCopyEmail,
            copiedTemplate: l.aboutEmailCopied,
          ),
          const SizedBox(height: AppSpacing.md),
          _LicensesTile(
            title: l.aboutLicensesTitle,
            subtitle: l.aboutLicensesSubtitle,
            appName: l.aboutAppName,
            version: appVersion,
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              l.aboutBuiltBy,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.version});
  final String version;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return PremiumCard(
      gradient: AppColors.heroGradient,
      shadowColor: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const ParrotMascot(mood: ParrotMood.happy, size: 120),
          const SizedBox(height: AppSpacing.md),
          Text(
            l.aboutAppName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.appTagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '${l.aboutVersionLabel} $version',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }
}

class _LegalSection extends StatefulWidget {
  const _LegalSection({
    required this.heading,
    required this.body,
    required this.icon,
    required this.openLabel,
    required this.sectionKey,
  });

  final String heading;
  final String body;
  final IconData icon;
  final String openLabel;
  final Key sectionKey;

  @override
  State<_LegalSection> createState() => _LegalSectionState();
}

class _LegalSectionState extends State<_LegalSection> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      key: widget.sectionKey,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(widget.icon,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.heading,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: !_expanded
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          widget.body,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.heading,
    required this.body,
    required this.email,
    required this.copyLabel,
    required this.copiedTemplate,
  });

  final String heading;
  final String body;
  final String email;
  final String copyLabel;
  final String Function(String email) copiedTemplate;

  void _copy(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    // Fire-and-forget: clipboard plugin may be unavailable on some
    // surfaces (web fallbacks, restricted environments). The snackbar
    // is the user-facing confirmation either way; we do not block on
    // the platform call.
    Clipboard.setData(ClipboardData(text: email)).catchError((_) {});
    messenger.showSnackBar(
      SnackBar(
        content: Text(copiedTemplate(email)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      key: const Key('about.support.card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent_rounded,
                  color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  heading,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            key: const Key('about.support.copy'),
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => _copy(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    copyLabel,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded,
                      color: AppColors.primary, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LicensesTile extends StatelessWidget {
  const _LicensesTile({
    required this.title,
    required this.subtitle,
    required this.appName,
    required this.version,
  });

  final String title;
  final String subtitle;
  final String appName;
  final String version;

  void _open(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: appName,
      applicationVersion: version,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      key: const Key('about.licenses.tile'),
      padding: EdgeInsets.zero,
      onTap: () => _open(context),
      child: ListTile(
        leading: const Icon(Icons.code_rounded, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
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
    );
  }
}
