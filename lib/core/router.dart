import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import 'shell_screen.dart';
import 'transitions.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/home/home_screen.dart';
import '../features/children/children_list_screen.dart';
import '../features/children/add_child_screen.dart';
import '../features/children/child_detail_screen.dart';
import '../features/children/edit_child_screen.dart';
import '../features/children/speech_profile_screen.dart';
import '../features/children/phoneme_drill_screen.dart';
import '../features/children/practice_calendar_screen.dart';
import '../features/children/recordings_history_screen.dart';
import '../features/exercises/exercises_list_screen.dart';
import '../features/exercises/exercise_detail_screen.dart';
import '../features/exercises/interactive_lesson_screen.dart';
import '../features/assessment/assessment_intro_screen.dart';
import '../features/assessment/assessment_game_screen.dart';
import '../features/assessment/assessment_results_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/help/help_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/badges/badges_screen.dart';
import '../features/uploads/pending_uploads_screen.dart';
import '../features/assignments/assignments_screen.dart';
import '../features/practice_plans/practice_plans_screen.dart';
import '../features/practice_plans/practice_plan_detail_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/subscription/subscription_screen.dart';
import '../features/subscription/subscription_status_screen.dart';
import '../features/subscription/subscription_history_screen.dart';
import '../features/subscription/payment_order_detail_screen.dart';
import '../features/subscription/plan_comparison_screen.dart';
import '../providers/providers.dart';
import '../data/local/preferences.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  final onboardingSeen = ref.watch(onboardingSeenProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      // Splash always wins until it decides where to go.
      if (loc == '/splash') return null;

      final isAuth = auth.status == AuthStatus.authenticated;
      final isAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/onboarding';

      if (auth.status == AuthStatus.unknown) return '/splash';
      if (!isAuth && !isAuthRoute) {
        // Returning unauthenticated users skip onboarding.
        return onboardingSeen ? '/login' : '/onboarding';
      }
      // If somehow we land on /onboarding after it has been completed,
      // bounce to /login so the user doesn't replay the carousel.
      if (!isAuth && loc == '/onboarding' && onboardingSeen) {
        return '/login';
      }
      if (isAuth && isAuthRoute) return '/';
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: Text(L.of(context)?.error ?? 'Error')),
    ),
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) =>
            fadeSlideTransition(state: state, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, state) =>
            fadeSlideTransition(state: state, child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) =>
            fadeSlideTransition(state: state, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, state) =>
            fadeSlideTransition(state: state, child: const RegisterScreen()),
      ),
      ShellRoute(
        builder: (_, __, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, state) =>
                fadeSlideTransition(state: state, child: const HomeScreen()),
          ),
          GoRoute(
            path: '/children',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const ChildrenListScreen()),
          ),
          GoRoute(
            path: '/children/add',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const AddChildScreen()),
          ),
          GoRoute(
            path: '/children/:id',
            pageBuilder: (_, state) => fadeSlideTransition(
              state: state,
              child: ChildDetailScreen(
                childId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/children/:id/edit',
            pageBuilder: (_, state) => fadeSlideTransition(
              state: state,
              child: EditChildScreen(
                childId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/children/:id/speech-profile',
            pageBuilder: (_, state) => fadeSlideTransition(
              state: state,
              child: SpeechProfileScreen(
                childId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/children/:id/phonemes/:phoneme',
            pageBuilder: (_, state) => fadeSlideTransition(
              state: state,
              child: PhonemeDrillScreen(
                childId: state.pathParameters['id']!,
                phoneme: state.pathParameters['phoneme']!,
              ),
            ),
          ),
          GoRoute(
            path: '/children/:id/calendar',
            pageBuilder: (_, state) => fadeSlideTransition(
              state: state,
              child: PracticeCalendarScreen(
                childId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/children/:id/recordings',
            pageBuilder: (_, state) => fadeSlideTransition(
              state: state,
              child: RecordingsHistoryScreen(
                childId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/exercises',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const ExercisesListScreen()),
          ),
          GoRoute(
            path: '/exercises/:id',
            pageBuilder: (_, state) => fadeSlideTransition(
              state: state,
              child: ExerciseDetailScreen(
                exerciseId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            // Step-by-step interactive lesson player. Only routed to when
            // the exercise ships a non-empty `steps` array — see
            // `Exercise.hasInteractiveSteps`. The legacy single-recording
            // flow continues to use `/assessment/intro/...` so older API
            // payloads keep working untouched.
            path: '/exercises/:exerciseId/lesson/:childId',
            pageBuilder: (_, state) => fadeSlideTransition(
              state: state,
              child: InteractiveLessonScreen(
                childId: state.pathParameters['childId']!,
                exerciseId: state.pathParameters['exerciseId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/assessment/intro/:childId/:exerciseId',
            pageBuilder: (_, state) => fadeSlideTransition(
              state: state,
              child: AssessmentIntroScreen(
                childId: state.pathParameters['childId']!,
                exerciseId: state.pathParameters['exerciseId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/assessment/:childId/:exerciseId',
            pageBuilder: (_, state) => fadeSlideTransition(
              state: state,
              child: AssessmentGameScreen(
                childId: state.pathParameters['childId']!,
                exerciseId: state.pathParameters['exerciseId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/assessment/results/:id',
            pageBuilder: (_, state) => fadeSlideTransition(
              state: state,
              child: AssessmentResultsScreen(
                assessmentId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/notifications',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const NotificationsScreen()),
          ),
          GoRoute(
            path: '/progress',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const ProgressScreen()),
          ),
          GoRoute(
            path: '/badges',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const BadgesScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const ProfileScreen()),
          ),
          GoRoute(
            path: '/profile/edit',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const EditProfileScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const SettingsScreen()),
          ),
          GoRoute(
            path: '/settings/about',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const AboutScreen()),
          ),
          GoRoute(
            path: '/help',
            pageBuilder: (_, state) =>
                fadeSlideTransition(state: state, child: const HelpScreen()),
          ),
          GoRoute(
            path: '/uploads',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const PendingUploadsScreen()),
          ),
          GoRoute(
            path: '/assignments',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const AssignmentsScreen()),
          ),
          GoRoute(
            path: '/practice-plans',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const PracticePlansScreen()),
          ),
          GoRoute(
            path: '/practice-plans/:id',
            pageBuilder: (_, state) => fadeSlideTransition(
              state: state,
              child: PracticePlanDetailScreen(
                planId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/timeline',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const TimelineScreen()),
          ),
          GoRoute(
            path: '/subscription',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const SubscriptionScreen()),
          ),
          GoRoute(
            path: '/subscription/compare',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const PlanComparisonScreen()),
          ),
          GoRoute(
            path: '/subscription/status',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const SubscriptionStatusScreen()),
          ),
          GoRoute(
            path: '/subscription/history',
            pageBuilder: (_, state) => fadeSlideTransition(
                state: state, child: const SubscriptionHistoryScreen()),
          ),
          GoRoute(
            path: '/subscription/orders/:id',
            pageBuilder: (_, state) => fadeSlideTransition(
              state: state,
              child: PaymentOrderDetailScreen(
                orderId: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      ),
    ],
  );
});
