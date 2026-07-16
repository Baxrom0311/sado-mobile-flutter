import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../data/api/billing_interceptor.dart';
import '../widgets/offline_banner.dart';
import '../widgets/quick_assessment_fab.dart';
import '../widgets/upgrade_prompt_sheet.dart';
import 'theme.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  // Tracks the seq number of the last `PlanLimitEvent` we already
  // surfaced via the bottom sheet. The interceptor announces a fresh
  // event on every 402 (even on identical metric/limit pairs), so we
  // gate presentation on a strictly-increasing counter to avoid
  // re-firing the modal during a hot-reload, a route swap, or a
  // listener replay after a `ref.invalidate(...)`.
  int _lastHandledSeq = 0;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    // Capture the initial seq if a 402 happened before the shell
    // mounted (e.g. during an eager bootstrap fetch). We deliberately
    // do *not* show the sheet for that pre-existing event — the user
    // hasn't done anything to trigger it from this surface.
    final initial = ref.read(planLimitEventProvider);
    _lastHandledSeq = initial?.seq ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;

    // Bottom-sheet presentation lives in `build` (via a listener) so
    // it survives every Riverpod rebuild without leaking subscriptions.
    ref.listen<PlanLimitEvent?>(planLimitEventProvider, (previous, next) {
      if (next == null || next.seq <= _lastHandledSeq) return;
      _lastHandledSeq = next.seq;
      _maybeShowSheet(next.notice);
    });

    int index = 0;
    if (location.startsWith('/exercises')) {
      index = 1;
    }
    if (location.startsWith('/progress')) {
      index = 2;
    }
    if (location.startsWith('/profile') ||
        location.startsWith('/settings') ||
        location.startsWith('/badges') ||
        location.startsWith('/children') ||
        location.startsWith('/notifications')) {
      index = 3;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: widget.child),
        ],
      ),
      // Phase 3.5: a raised center FAB for "Quick assessment" — surfaced
      // from every tab so parents can jump straight into the recording
      // flow without first navigating to the Exercises tab. Lives above
      // the NavigationBar via `centerFloat` so the four primary tabs stay
      // intact and the existing shell tests (which assert on the
      // [NavigationBar] widget directly) keep passing.
      floatingActionButton: QuickAssessmentFab(
        tooltip: l.startAssessment,
        onPressed: () => context.go('/exercises'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) {
              switch (i) {
                case 0:
                  context.go('/');
                case 1:
                  context.go('/exercises');
                case 2:
                  context.go('/progress');
                case 3:
                  context.go('/profile');
              }
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: l.tabHome,
              ),
              NavigationDestination(
                icon: const Icon(Icons.fitness_center_outlined),
                selectedIcon: const Icon(Icons.fitness_center_rounded),
                label: l.tabExercises,
              ),
              NavigationDestination(
                icon: const Icon(Icons.trending_up_outlined),
                selectedIcon: const Icon(Icons.trending_up_rounded),
                label: l.tabProgress,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: l.tabProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _maybeShowSheet(PlanLimitNotice notice) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    try {
      // Defer a frame so the modal opens *after* whatever screen
      // navigation is in flight (a 402 typically arrives in response
      // to a button press that may itself be transitioning). Without
      // this, the sheet sometimes loses its parent navigator during
      // route swaps.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      await UpgradePromptSheet.show(context, notice: notice);
    } finally {
      _sheetOpen = false;
      // Best-effort clear so the same event isn't re-announced after
      // a hot reload / test rebuild.
      if (mounted) {
        ref.read(planLimitEventProvider.notifier).clear();
      }
    }
  }
}
