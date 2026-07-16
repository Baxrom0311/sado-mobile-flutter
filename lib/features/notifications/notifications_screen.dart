import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../core/utils/relative_time.dart';
import '../../data/api/api_client.dart';
import '../../data/api/notifications_api.dart';
import '../../data/models/models.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/shimmer_loaders.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.notifications),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/profile'),
        ),
        actions: [
          notifications.maybeWhen(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    // Use an icon + tooltip instead of a TextButton: the
                    // localized "Mark all read" copy in `uz` and `ru` is too
                    // long to sit in a phone-width AppBar action slot
                    // without overflowing.
                    icon: const Icon(Icons.done_all_rounded),
                    tooltip: l.markAllRead,
                    onPressed: () async {
                      final api =
                          NotificationsApi(ref.read(dioProvider));
                      try {
                        await api.markAllRead();
                      } catch (_) {}
                      ref.invalidate(notificationsProvider);
                    },
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const ShimmerList(),
        error: (_, __) => _Empty(
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (items) => items.isEmpty
            ? _Empty(onRetry: () => ref.invalidate(notificationsProvider))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) =>
                      _NotificationTile(notification: items[i])
                          .animate(delay: (i * 50).ms)
                          .fadeIn()
                          .slideY(begin: 0.1),
                ),
              ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});
  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final unread = !notification.isRead;
    final timeLabel = formatRelativeDate(l, notification.createdAt);
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: unread
          ? () async {
              final api = NotificationsApi(ref.read(dioProvider));
              try {
                await api.markRead(notification.id);
              } catch (_) {}
              ref.invalidate(notificationsProvider);
            }
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: unread ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (notification.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ParrotMascot(mood: ParrotMood.idle, size: 140),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.noNotifications,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.noNotificationsBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            PremiumButton(
              label: l.retry,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
