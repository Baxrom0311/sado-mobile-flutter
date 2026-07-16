import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/api_client.dart';
import '../data/api/notifications_api.dart';
import '../data/models/models.dart';

/// Centralized notifications state so multiple screens (the bell on Home,
/// the Notifications page, etc.) share a single source of truth.
///
/// This provider intentionally swallows network errors and falls back to
/// an empty list — the backend does not expose `/notifications` on every
/// environment yet, and we don't want to surface a scary error banner in
/// the UI while the API is still being rolled out.
///
/// The provider is *not* autoDispose so the cached list survives the user
/// navigating between tabs. Call [invalidateNotificationsProvider] (or
/// `ref.invalidate(notificationsProvider)`) to force a refetch after
/// marking a notification as read.
final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final api = NotificationsApi(ref.watch(dioProvider));
  try {
    final res = await api.list();
    return res.items;
  } catch (_) {
    return const <AppNotification>[];
  }
});

/// Derived provider exposing the number of unread notifications. Returns
/// `0` while the backing future is loading or has errored, so the home
/// screen's bell badge degrades gracefully instead of flashing stale data.
///
/// Callers should `ref.watch(unreadNotificationsCountProvider)` and render
/// a badge only when the value is `> 0`.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final async = ref.watch(notificationsProvider);
  return async.maybeWhen(
    data: (items) => items.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});
