import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/local/preferences.dart';
import '../../data/models/subscription_plan.dart';
import '../../data/models/subscription_plan_labels.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/speech_bubble.dart';
import 'widgets/contact_sales_sheet.dart';
import 'widgets/payment_method_sheet.dart';
import 'widgets/plan_card.dart';

/// Premium upgrade screen.
///
/// Renders the static-or-API-driven plan catalog and highlights the user's
/// current plan. Tapping a paid plan opens a friendly "Coming soon"
/// bottom sheet — the actual checkout flow (Payme / Click) lives on the
/// API side and ships in a follow-up. Until then this screen serves as
/// the value-prop surface and the conversion entry point.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final mySubAsync = ref.watch(mySubscriptionProvider);
    final locale = ref.watch(localeProvider).languageCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.subscriptionTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: plansAsync.when(
          loading: () => const _SubscriptionLoading(),
          error: (_, __) => ErrorState(
            title: l.subscriptionErrorTitle,
            body: l.subscriptionErrorBody,
            retryLabel: l.subscriptionErrorRetry,
            onRetry: () =>
                ref.invalidate(subscriptionPlansProvider),
          ),
          data: (plans) {
            if (plans.isEmpty) {
              return EmptyState(
                title: l.subscriptionEmptyTitle,
                body: l.subscriptionEmptyBody,
              );
            }

            // The API returns plans sorted by `sort_order`; the
            // recommended tier is the first paid plan after the free
            // one (parent_pro). When listing fewer plans (e.g. only
            // free + one paid) we still highlight the cheapest paid.
            final recommendedId = _recommendedPlanId(plans);
            final currentPlanId = mySubAsync.maybeWhen(
              data: (s) => s.planId,
              orElse: () => 'free',
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.huge,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hero(
                    title: l.subscriptionTitle,
                    subtitle: l.subscriptionSubtitle,
                    mascotMessage: l.subscriptionMascotMessage,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ...List.generate(plans.length, (i) {
                    final plan = plans[i];
                    return Padding(
                      key: Key('subscription.plan.${plan.id}'),
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _planCard(
                        context: context,
                        l: l,
                        locale: locale,
                        plan: plan,
                        isCurrent: plan.id == currentPlanId,
                        isRecommended: plan.id == recommendedId,
                        delay: Duration(milliseconds: 80 * i),
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.md),
                  _CompareLink(
                    label: l.planCompareEntryCta,
                    hint: l.planCompareEntryHint,
                    onTap: () => context.go('/subscription/compare'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l.subscriptionFooterNote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _planCard({
    required BuildContext context,
    required L l,
    required String locale,
    required SubscriptionPlan plan,
    required bool isCurrent,
    required bool isRecommended,
    required Duration delay,
  }) {
    final priceText = plan.isFree
        ? l.subscriptionPriceFree
        : l.subscriptionPricePerMonth(_formatPrice(plan.priceUzs, locale));
    final priceSubtext = plan.priceUsd > 0
        ? l.subscriptionPricePerMonthUsd(plan.priceUsd.toStringAsFixed(0))
        : null;

    final ctaLabel = isCurrent
        ? l.subscriptionCurrentBadge
        : (_isB2BPlan(plan)
            ? l.subscriptionContactSales
            : (plan.isFree
                ? l.subscriptionContinueFree
                : l.subscriptionUpgradeCta));

    return PlanCard(
      title: _planName(l, plan, locale),
      tagline: _planTagline(l, plan, locale),
      priceText: priceText,
      priceSubtext: priceSubtext,
      features: _buildFeatures(l, plan),
      ctaLabel: ctaLabel,
      onCtaPressed: () => _handleCta(context, l, plan),
      recommended: isRecommended && !isCurrent,
      current: isCurrent,
      currentBadgeText: l.subscriptionCurrentBadge,
      recommendedBadgeText: l.subscriptionRecommendedBadge,
      entranceDelay: delay,
    );
  }

  /// B2B / B2B2C plans need the "Contact sales" CTA — they are sold
  /// through a human conversation rather than self-serve checkout.
  bool _isB2BPlan(SubscriptionPlan plan) {
    final id = SubscriptionPlanLabels.normalise(plan.id);
    return id == SubscriptionPlanLabels.logoped ||
        id == SubscriptionPlanLabels.logopedPro ||
        id == SubscriptionPlanLabels.clinic ||
        id == SubscriptionPlanLabels.clinicBasic ||
        id == SubscriptionPlanLabels.clinicPremium;
  }

  String _planName(L l, SubscriptionPlan plan, String locale) =>
      SubscriptionPlanLabels.nameForPlan(l, plan, locale);

  String _planTagline(L l, SubscriptionPlan plan, String locale) =>
      SubscriptionPlanLabels.taglineForPlan(l, plan, locale);

  List<String> _buildFeatures(L l, SubscriptionPlan plan) {
    final lines = <String>[];

    // Free quotas.
    if (plan.id == 'free') {
      lines.add(l.subscriptionFeatureBasicExercises);
      lines.add(l.subscriptionFeatureBasicProgress);
      if (plan.limits.exercisesPerDay > 0) {
        lines.add(l.subscriptionFeatureExerciseLimit(
            plan.limits.exercisesPerDay));
      }
      if (plan.limits.aiAnalysesPerMonth > 0) {
        lines.add(l.subscriptionFeatureAiLimit(
            plan.limits.aiAnalysesPerMonth));
      }
      if (plan.limits.maxChildren > 0) {
        lines.add(l.subscriptionFeatureChildLimit(
            plan.limits.maxChildren));
      }
      return lines;
    }

    // Unlimited tiers.
    if (plan.limits.exercisesPerDay < 0) {
      lines.add(l.subscriptionFeatureUnlimitedExercises);
    }
    if (plan.limits.aiAnalysesPerMonth < 0) {
      lines.add(l.subscriptionFeatureUnlimitedAi);
    }
    if (plan.limits.maxChildren > 1) {
      lines.add(l.subscriptionFeatureMultipleChildren(
          plan.limits.maxChildren));
    }

    // Feature flags (display-only — server already controls access).
    final featureMap = <String, String>{
      'detailed_progress': l.subscriptionFeatureDetailedProgress,
      'recommendations': l.subscriptionFeatureRecommendations,
      'export_pdf': l.subscriptionFeatureExportPdf,
      'patient_management':
          l.subscriptionFeaturePatientManagement,
      'assign_exercises': l.subscriptionFeatureAssignExercises,
      'therapy_goals': l.subscriptionFeatureTherapyGoals,
      'screening_battery': l.subscriptionFeatureScreeningBattery,
      'referral_pdf': l.subscriptionFeatureReferralPdf,
      'analytics': l.subscriptionFeatureAnalytics,
    };
    for (final f in plan.features) {
      final label = featureMap[f];
      if (label != null && !lines.contains(label)) {
        lines.add(label);
      }
    }

    if (plan.limits.maxPatients > 0) {
      lines.add(l.subscriptionFeaturePatientLimit(
          plan.limits.maxPatients));
    }

    return lines;
  }

  Future<void> _handleCta(
    BuildContext context,
    L l,
    SubscriptionPlan plan,
  ) async {
    // Logoped/clinic tiers are sold via direct sales — no self-serve
    // checkout path yet. Surface the branded Contact Sales sheet so
    // the upgrade tap converts into a qualified lead (email composer
    // + dialer + copy-to-clipboard fallback) instead of a dead-end
    // "coming soon" beat. We check this *before* `plan.isFree`
    // because the clinic tier ships with priceUzs == 0 (bespoke
    // pricing → "Contact sales") yet must never fall through to the
    // "Continue free" branch.
    if (_isB2BPlan(plan)) {
      final locale = L.of(context)?.localeName ?? 'uz';
      await ContactSalesSheet.show(
        context,
        plan: plan,
        planDisplayName: _planName(l, plan, locale),
      );
      return;
    }
    if (plan.isFree) {
      context.canPop() ? context.pop() : context.go('/');
      return;
    }
    final locale = L.of(context)?.localeName ?? 'uz';
    await PaymentMethodSheet.show(
      context,
      plan: plan,
      planDisplayName: _planName(l, plan, locale),
    );
  }

  /// Selects the recommended (visually highlighted) plan id from the
  /// available list. Prefers `parent_pro` if present; otherwise the
  /// cheapest paid plan; otherwise the only plan available.
  String? _recommendedPlanId(List<SubscriptionPlan> plans) {
    final paid = plans.where((p) => p.isPaid).toList()
      ..sort((a, b) => a.priceUzs.compareTo(b.priceUzs));
    if (paid.isEmpty) return null;
    final pro = paid.firstWhere(
      (p) => p.id == 'parent_pro',
      orElse: () => paid.first,
    );
    return pro.id;
  }

  String _formatPrice(int uzs, String locale) {
    final fmt = NumberFormat.decimalPattern(locale == 'ru' ? 'ru' : 'uz');
    return fmt.format(uzs);
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.subtitle,
    required this.mascotMessage,
  });

  final String title;
  final String subtitle;
  final String mascotMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft(AppColors.primary, opacity: 0.22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ParrotMascot(mood: ParrotMood.happy, size: 96),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SpeechBubble(
                  text: mascotMessage,
                  color: Colors.white,
                  textColor: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.06);
  }
}

class _SubscriptionLoading extends StatelessWidget {
  const _SubscriptionLoading();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const ShimmerCard(height: 140),
        const SizedBox(height: AppSpacing.lg),
        const ShimmerCard(height: 220),
        const SizedBox(height: AppSpacing.md),
        const ShimmerCard(height: 220),
        const SizedBox(height: AppSpacing.md),
        const ShimmerCard(height: 220),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            l.subscriptionLoadingTitle,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Low-emphasis link below the plan cards that opens the side-by-side
/// matrix view. Kept visually quiet so it never competes with the
/// primary plan CTAs but still surfaces the comparison flow for users
/// who want a closer apples-to-apples look.
class _CompareLink extends StatelessWidget {
  const _CompareLink({
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        key: const Key('subscription.compareLink'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      hint,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
