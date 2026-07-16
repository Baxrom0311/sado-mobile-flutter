import 'package:flutter/material.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../core/utils/haptics.dart';
import '../domain/tips/daily_tip.dart';
import 'parrot_mascot.dart';
import 'premium_card.dart';

/// Premium "Tip of the day" card surfaced on the home screen.
///
/// Reads a curated, localised tip from [DailyTip.forDate] and renders
/// it inside a tappable card. Tapping toggles an inline expansion that
/// reveals the body copy via [AnimatedSize] — no extra route, no
/// scaffolding hop. The mascot peeks from the leading edge so the card
/// feels of a piece with the rest of the home dashboard.
///
/// `now` is overridable by tests so the rotation can be exercised
/// across calendar dates without `fakeAsync`.
class DailyTipCard extends StatefulWidget {
  const DailyTipCard({super.key, this.now, this.initiallyExpanded = false});

  /// Override the current date — production code passes `null` so we
  /// fall through to `DateTime.now()`.
  final DateTime? now;

  /// Lets tests pin the card open so widget assertions don't have to
  /// emulate a tap.
  final bool initiallyExpanded;

  @override
  State<DailyTipCard> createState() => _DailyTipCardState();
}

class _DailyTipCardState extends State<DailyTipCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final tip = DailyTip.forDate(l, now: widget.now);

    return PremiumCard(
      key: const ValueKey('home.dailyTipCard'),
      shadowColor: AppColors.tertiary,
      gradient: const [AppColors.tertiaryLight, AppColors.surface],
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      onTap: () {
        Haptics.light();
        setState(() => _expanded = !_expanded);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: ParrotMascot(
                  mood: ParrotMood.happy,
                  size: 56,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l.tipOfTheDayLabel,
                            style: const TextStyle(
                              color: AppColors.tertiary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tip.title,
                      maxLines: _expanded ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.md,
                      left: 56 + AppSpacing.md,
                    ),
                    child: Text(
                      tip.body,
                      key: const ValueKey('home.dailyTipCard.body'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
