import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../providers/notifications_provider.dart';

/// A bell icon button that surfaces the unread-notification count as a
/// small badge in the top-right corner.
///
/// * Renders a hollow bell when there are no unread notifications.
/// * Renders a filled bell + red pill badge with the count when unread > 0.
/// * Counts above 9 collapse to "9+" so the badge doesn't overflow.
/// * Tapping it navigates to `/notifications`.
///
/// The widget reads [unreadNotificationsCountProvider] and only rebuilds
/// when the count actually changes, so it's safe to put on the home
/// header without worrying about excessive rebuilds.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({
    super.key,
    this.onPressed,
  });

  /// Optional override for the tap handler. Defaults to navigating to the
  /// notifications screen via [GoRouter]; tests inject a callback to assert
  /// the tap-through without booting a router.
  final VoidCallback? onPressed;

  /// Compresses the count into a short string. Anything above 9 becomes
  /// "9+" so the badge stays the same size regardless of the queue depth.
  static String formatBadgeCount(int count) {
    if (count <= 0) return '';
    if (count > 9) return '9+';
    return count.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final hasUnread = unread > 0;
    final tooltip = l?.notifications ?? 'Notifications';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          icon: Icon(
            hasUnread
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            color: hasUnread ? AppColors.primary : null,
          ),
          onPressed: onPressed ?? () => context.go('/notifications'),
        ),
        if (hasUnread)
          Positioned(
            top: 4,
            right: 4,
            child: IgnorePointer(
              child: _UnreadBadge(count: unread),
            ),
          ),
      ],
    );
  }
}

/// Small red pill rendered at the top-right of the bell. Animates in once
/// the count transitions from zero — so a freshly-arrived notification
/// gives a subtle attention nudge — and gently pulses while there are
/// unread items.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = NotificationBell.formatBadgeCount(count);
    final isWide = label.length > 1;

    return Container(
      key: const ValueKey('notificationBell.badge'),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 5 : 0,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.surface, width: 2),
        boxShadow: AppShadow.soft(AppColors.danger, opacity: 0.35),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            height: 1.1,
          ),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          duration: 1100.ms,
          begin: const Offset(1, 1),
          end: const Offset(1.08, 1.08),
          curve: Curves.easeInOut,
        );
  }
}
