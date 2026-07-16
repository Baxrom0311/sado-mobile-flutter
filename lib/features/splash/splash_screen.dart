import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/local/preferences.dart';
import '../../providers/providers.dart';
import '../../widgets/loaders.dart';
import '../../widgets/parrot_mascot.dart';

/// First screen the app shows. The mascot flies in, then we wait for
/// auth state to resolve and route to the right place.
///
/// Routes:
///   - authenticated → /
///   - unauthenticated → /onboarding
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // After 1.4s + auth resolved, navigate.
    Future<void>.delayed(const Duration(milliseconds: 1400), _maybeNavigate);
  }

  void _maybeNavigate() {
    if (!mounted || _navigated) return;
    final auth = ref.read(authProvider);
    if (auth.status == AuthStatus.unknown) {
      // Auth still resolving — try again shortly.
      Future<void>.delayed(const Duration(milliseconds: 200), _maybeNavigate);
      return;
    }
    _navigated = true;
    if (auth.status == AuthStatus.authenticated) {
      context.go('/');
    } else {
      // First launch → onboarding; returning unauth users → straight to login.
      final seen = ref.read(onboardingSeenProvider);
      context.go(seen ? '/login' : '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    // Listen so navigation also kicks in once auth resolves.
    ref.listen<AuthState>(authProvider, (_, __) => _maybeNavigate());

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE9F9EE), AppColors.surface],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ParrotMascot(mood: ParrotMood.happy, size: 200)
                    .animate()
                    .fadeIn(duration: 350.ms)
                    .slideY(
                      begin: -0.4,
                      end: 0,
                      duration: 700.ms,
                      curve: Curves.easeOutBack,
                    )
                    .scale(
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1, 1),
                      duration: 700.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  l.appTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.2),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l.splashTagline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ).animate(delay: 500.ms).fadeIn(),
                const SizedBox(height: AppSpacing.huge),
                const DotsLoader(color: AppColors.primary, size: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
