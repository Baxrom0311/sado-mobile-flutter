import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_card.dart';

/// Parent-facing Help & Tips center.
///
/// Reachable from `Settings → "Yordam va maslahatlar"`. Premium-feel layout:
///
///   • Parrot mascot hero with an inviting subtitle.
///   • Important disclaimer reminding parents that SADO is a screening
///     tool, not a substitute for a clinical diagnosis.
///   • A list of expandable FAQ entries (six entries, fully localised).
///   • A list of static "tip" cards giving practical home-practice advice.
///
/// Every label routes through `L.of(context)` — no hardcoded copy. The
/// FAQ accordion uses an [AnimatedSize] + [AnimatedRotation] cluster so
/// the expand/collapse motion stays inline with the rest of the app.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.helpTitle),
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
        key: const Key('help.list'),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Hero(
            title: l.helpHeroTitle,
            subtitle: l.helpHeroSubtitle,
          ).animate().fadeIn(duration: 320.ms).slideY(begin: -0.06),

          const SizedBox(height: AppSpacing.lg),

          _Disclaimer(
            title: l.helpDisclaimerTitle,
            body: l.helpDisclaimerBody,
          ).animate(delay: 60.ms).fadeIn().slideY(begin: 0.06),

          const SizedBox(height: AppSpacing.lg),

          _SectionTitle(label: l.helpFaqSectionTitle),
          const SizedBox(height: AppSpacing.sm),
          _FaqList(entries: _faqEntries(l)),

          const SizedBox(height: AppSpacing.lg),

          _SectionTitle(label: l.helpTipsSectionTitle),
          const SizedBox(height: AppSpacing.sm),
          _TipsList(tips: _tipEntries(l)),

          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  // Centralised so localisations stay alongside the layout that consumes
  // them. The arrays are tiny — keeping them inline avoids a new
  // top-level repository for ~6 entries that are essentially copy.
  List<_Faq> _faqEntries(L l) => <_Faq>[
        _Faq(question: l.helpFaq1Q, answer: l.helpFaq1A),
        _Faq(question: l.helpFaq2Q, answer: l.helpFaq2A),
        _Faq(question: l.helpFaq3Q, answer: l.helpFaq3A),
        _Faq(question: l.helpFaq4Q, answer: l.helpFaq4A),
        _Faq(question: l.helpFaq5Q, answer: l.helpFaq5A),
        _Faq(question: l.helpFaq6Q, answer: l.helpFaq6A),
      ];

  List<_Tip> _tipEntries(L l) => <_Tip>[
        _Tip(
          icon: Icons.volume_off_rounded,
          title: l.helpTip1Title,
          body: l.helpTip1Body,
        ),
        _Tip(
          icon: Icons.favorite_rounded,
          title: l.helpTip2Title,
          body: l.helpTip2Body,
        ),
        _Tip(
          icon: Icons.record_voice_over_rounded,
          title: l.helpTip3Title,
          body: l.helpTip3Body,
        ),
        _Tip(
          icon: Icons.timer_outlined,
          title: l.helpTip4Title,
          body: l.helpTip4Body,
        ),
        _Tip(
          icon: Icons.local_fire_department_rounded,
          title: l.helpTip5Title,
          body: l.helpTip5Body,
        ),
      ];
}

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      key: const Key('help.hero'),
      gradient: AppColors.heroGradient,
      shadowColor: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const ParrotMascot(mood: ParrotMood.happy, size: 88),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
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

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      key: const Key('help.disclaimer'),
      shadowColor: AppColors.warning,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: AppColors.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs, top: AppSpacing.xs),
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

class _FaqList extends StatelessWidget {
  const _FaqList({required this.entries});
  final List<_Faq> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('help.faq.list'),
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          _FaqTile(
            tileKey: Key('help.faq.$i'),
            entry: entries[i],
          ).animate(delay: (60 * i).ms).fadeIn(duration: 240.ms).slideY(
                begin: 0.04,
              ),
          if (i != entries.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.tileKey, required this.entry});
  final Key tileKey;
  final _Faq entry;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      key: widget.tileKey,
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.entry.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        height: 1.3,
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
                          widget.entry.answer,
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

class _TipsList extends StatelessWidget {
  const _TipsList({required this.tips});
  final List<_Tip> tips;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('help.tips.list'),
      children: [
        for (var i = 0; i < tips.length; i++) ...[
          _TipCard(
            cardKey: Key('help.tip.$i'),
            tip: tips[i],
          ).animate(delay: (60 * i).ms).fadeIn(duration: 240.ms).slideY(
                begin: 0.04,
              ),
          if (i != tips.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.cardKey, required this.tip});
  final Key cardKey;
  final _Tip tip;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      key: cardKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(tip.icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tip.body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
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

@immutable
class _Faq {
  const _Faq({required this.question, required this.answer});
  final String question;
  final String answer;
}

@immutable
class _Tip {
  const _Tip({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}
