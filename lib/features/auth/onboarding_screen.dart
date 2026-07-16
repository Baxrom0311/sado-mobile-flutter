import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/local/preferences.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Mark the onboarding as completed and route the user to login.
  ///
  /// Persistence and navigation are intentionally separate awaits so even if
  /// Hive is unavailable (no-op fallback), the user still progresses to the
  /// login screen instead of being stuck on the carousel.
  Future<void> _finish() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;

    final pages = [
      _OnboardPage(
        gradient: const [Color(0xFFE9F9EE), AppColors.surface],
        mood: ParrotMood.happy,
        title: l.onboarding1Title,
        body: l.onboarding1Body,
      ),
      _OnboardPage(
        gradient: const [Color(0xFFFFEDD5), AppColors.surface],
        mood: ParrotMood.talking,
        title: l.onboarding2Title,
        body: l.onboarding2Body,
      ),
      _OnboardPage(
        gradient: const [Color(0xFFEDE9FE), AppColors.surface],
        mood: ParrotMood.idle,
        title: l.onboarding3Title,
        body: l.onboarding3Body,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    l.skip,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _page == i ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _page == i
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PremiumButton(
                    label:
                        _page < pages.length - 1 ? l.next : l.getStarted,
                    icon: _page < pages.length - 1
                        ? Icons.arrow_forward_rounded
                        : Icons.rocket_launch_rounded,
                    onPressed: () {
                      if (_page < pages.length - 1) {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeInOutCubic,
                        );
                      } else {
                        _finish();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.gradient,
    required this.mood,
    required this.title,
    required this.body,
  });

  final List<Color> gradient;
  final ParrotMood mood;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ParrotMascot(mood: mood, size: 200)
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.2),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ).animate(delay: 220.ms).fadeIn(),
        ],
      ),
    );
  }
}
