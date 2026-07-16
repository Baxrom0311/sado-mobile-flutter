import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/providers/notifications_provider.dart';

AppNotification _n(String id, {bool read = false}) => AppNotification(
      id: id,
      title: 'Title $id',
      body: 'Body $id',
      isRead: read,
      createdAt: DateTime.utc(2025, 1, 1),
    );

void main() {
  group('unreadNotificationsCountProvider', () {
    test('returns 0 when the future is still loading', () {
      // No override pushed: the real provider would attempt a network call.
      // We override with a never-completing future so the derived count
      // observes an `AsyncLoading` state and returns 0 instead of throwing.
      final container = ProviderContainer(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) => Future.delayed(const Duration(seconds: 30)),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(unreadNotificationsCountProvider), 0);
    });

    test('returns 0 when the future errors out', () async {
      final container = ProviderContainer(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) async => throw StateError('boom'),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Trigger evaluation of the future before reading the derived value.
      await container.read(notificationsProvider.future).catchError(
            (_) => const <AppNotification>[],
          );

      expect(container.read(unreadNotificationsCountProvider), 0);
    });

    test('returns 0 for an empty list', () async {
      final container = ProviderContainer(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) async => const <AppNotification>[],
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(notificationsProvider.future);

      expect(container.read(unreadNotificationsCountProvider), 0);
    });

    test('counts only unread notifications', () async {
      final container = ProviderContainer(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) async => [
              _n('a', read: false),
              _n('b', read: true),
              _n('c', read: false),
              _n('d', read: false),
              _n('e', read: true),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(notificationsProvider.future);

      expect(container.read(unreadNotificationsCountProvider), 3);
    });

    test('refreshes when the underlying provider is invalidated', () async {
      var firstFetch = true;
      final container = ProviderContainer(
        overrides: [
          notificationsProvider.overrideWith((ref) async {
            if (firstFetch) {
              firstFetch = false;
              return [_n('a'), _n('b'), _n('c')];
            }
            // After invalidation, simulate the user marking everything as read.
            return [
              _n('a', read: true),
              _n('b', read: true),
              _n('c', read: true),
            ];
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(notificationsProvider.future);
      expect(container.read(unreadNotificationsCountProvider), 3);

      container.invalidate(notificationsProvider);
      await container.read(notificationsProvider.future);
      expect(container.read(unreadNotificationsCountProvider), 0);
    });
  });
}
