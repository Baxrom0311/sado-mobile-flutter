import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/notifications_provider.dart';
import 'package:sado_mobile/widgets/notification_bell.dart';

AppNotification _n(String id, {bool read = false}) => AppNotification(
      id: id,
      title: 'Title $id',
      body: 'Body $id',
      isRead: read,
      createdAt: DateTime.utc(2025, 1, 1),
    );

Widget _wrap(
  Widget child, {
  required List<AppNotification> notifications,
}) {
  return ProviderScope(
    overrides: [
      notificationsProvider.overrideWith((ref) async => notifications),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      locale: const Locale('uz'),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('NotificationBell.formatBadgeCount', () {
    test('returns empty string for non-positive counts', () {
      expect(NotificationBell.formatBadgeCount(0), '');
      expect(NotificationBell.formatBadgeCount(-3), '');
    });

    test('returns the literal count for 1..9', () {
      for (var i = 1; i <= 9; i++) {
        expect(NotificationBell.formatBadgeCount(i), '$i');
      }
    });

    test('collapses any double-digit count to "9+"', () {
      expect(NotificationBell.formatBadgeCount(10), '9+');
      expect(NotificationBell.formatBadgeCount(42), '9+');
      expect(NotificationBell.formatBadgeCount(999), '9+');
    });
  });

  group('NotificationBell widget', () {
    testWidgets('renders the hollow bell with no badge when there are no '
        'unread notifications', (tester) async {
      await tester.pumpWidget(_wrap(
        const NotificationBell(),
        notifications: [_n('a', read: true)],
      ));
      // Let the FutureProvider resolve.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notifications_rounded), findsNothing);
      expect(
        find.byKey(const ValueKey('notificationBell.badge')),
        findsNothing,
      );
    });

    testWidgets('renders the filled bell + numeric badge when there is one '
        'unread notification', (tester) async {
      await tester.pumpWidget(_wrap(
        const NotificationBell(),
        notifications: [_n('a'), _n('b', read: true)],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
      expect(
        find.byKey(const ValueKey('notificationBell.badge')),
        findsOneWidget,
      );
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('collapses badge to "9+" when more than nine notifications '
        'are unread', (tester) async {
      final many = List.generate(15, (i) => _n('n$i'));
      await tester.pumpWidget(_wrap(
        const NotificationBell(),
        notifications: many,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('9+'), findsOneWidget);
      // Sanity: the literal "15" should never make it into the tree.
      expect(find.text('15'), findsNothing);
    });

    testWidgets('invokes the supplied onPressed callback when tapped',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        NotificationBell(onPressed: () => taps++),
        notifications: [_n('a')],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tap the IconButton specifically (the badge has IgnorePointer so it
      // can't swallow the gesture).
      await tester.tap(find.byType(IconButton));
      expect(taps, 1);
    });
  });
}
