import 'package:flutter/widgets.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../widgets/badge_widget.dart';
import 'gamification.dart';
import 'utils/haptics.dart';

/// Pop a celebratory dialog for every newly-unlocked badge id.
///
/// Several call sites — the home screen's daily streak ping, the assessment
/// results award flow, future server-driven unlocks — all hand back a list
/// of badge ids. This helper centralizes the "what to show and how to time
/// it" logic so the UX stays consistent (one mascot dialog per badge,
/// success haptic, ~250ms apart so the user can see each one).
///
/// Behaviour:
///   * Empty list → no-op (no haptic, no dialog).
///   * Caller is responsible for awaiting the future if they want to know
///     when the last dialog has been dismissed.
///   * If the [BuildContext] is no longer mounted between dialogs we stop
///     gracefully — never throws.
///   * Unknown badge ids fall back to [GameBadge.firstStep]'s emoji and the
///     generic "newBadgeUnlocked" copy so the user still sees *something*.
Future<void> celebrateUnlockedBadges(
  BuildContext context,
  List<String> badgeIds, {
  Duration delayBetween = const Duration(milliseconds: 250),
}) async {
  if (badgeIds.isEmpty) return;

  // Fire haptic concurrently with the visual cascade. We deliberately do
  // *not* await the haptic future — on physical devices the buzz overlaps
  // with the dialog opening, which feels punchier than haptic-then-dialog.
  // Multiple buzzes back-to-back feel noisy on iPhones; one strong success
  // pulse is enough to mark the moment.
  // ignore: unawaited_futures
  Haptics.success();

  for (var i = 0; i < badgeIds.length; i++) {
    if (!context.mounted) return;
    final id = badgeIds[i];
    final l = L.of(context);
    if (l == null) return;
    await showBadgeUnlocked(
      context,
      emoji: GameBadge.emojiOf(id),
      title: _titleFor(l, id),
      body: _bodyFor(l, id),
    );
    if (i < badgeIds.length - 1) {
      await Future<void>.delayed(delayBetween);
    }
  }
}

String _titleFor(L l, String id) => switch (id) {
      'first_step' => l.badgeFirstStepTitle,
      'streak_5' => l.badgeStreak5Title,
      'assess_10' => l.badgeAssess10Title,
      'level_5' => l.badgeLevel5Title,
      'level_10' => l.badgeLevel10Title,
      'perfect' => l.badgePerfectTitle,
      _ => l.newBadgeUnlocked,
    };

String _bodyFor(L l, String id) => switch (id) {
      'first_step' => l.badgeFirstStepBody,
      'streak_5' => l.badgeStreak5Body,
      'assess_10' => l.badgeAssess10Body,
      'level_5' => l.badgeLevel5Body,
      'level_10' => l.badgeLevel10Body,
      'perfect' => l.badgePerfectBody,
      _ => '',
    };
