import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/subscription_plan.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/subscription_provider.dart';
import 'package:sado_mobile/widgets/home_premium_card.dart';

GoRouter _router(GlobalKey<NavigatorState> navKey) => GoRouter(
      initialLocation: '/',
      navigatorKey: navKey,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: HomePremiumCard(),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/subscription',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('SUBSCRIPTION_STUB')),
          ),
        ),
      ],
    );

Widget _wrap({
  required AsyncValue<UserSubscription> subscription,
  Locale locale = const Locale('uz'),
  GlobalKey<NavigatorState>? navKey,
}) {
  final key = navKey ?? GlobalKey<NavigatorState>();
  return ProviderScope(
    overrides: [
      mySubscriptionProvider.overrideWith((ref) async {
        return subscription.when(
          data: (s) => s,
          loading: () => Completer<UserSubscription>().future,
          error: (e, _) => throw e,
        );
      }),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      routerConfig: _router(key),
    ),
  );
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('HomePremiumCard renders for confirmed-free users in Uzbek',
      (tester) async {
    await tester.pumpWidget(_wrap(
      subscription: AsyncData(UserSubscription.syntheticFree()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const ValueKey('home.premiumCard')), findsOneWidget);
    expect(find.text('Premiumga o\'ting'), findsOneWidget);
    expect(
      find.textContaining('Cheksiz mashq'),
      findsOneWidget,
    );

    await _disposeTree(tester);
  });

  testWidgets('HomePremiumCard renders Russian copy when locale is ru',
      (tester) async {
    await tester.pumpWidget(_wrap(
      locale: const Locale('ru'),
      subscription: AsyncData(UserSubscription.syntheticFree()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Перейти на Premium'), findsOneWidget);
    expect(find.textContaining('Безлимит'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'HomePremiumCard hides itself when the user is on a paid plan',
      (tester) async {
    await tester.pumpWidget(_wrap(
      subscription: AsyncData(UserSubscription(
        id: 'sub-1',
        planId: 'parent_pro',
        status: 'active',
        startedAt: DateTime.utc(2025, 1, 1),
      )),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const ValueKey('home.premiumCard')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'HomePremiumCard hides itself while the subscription is loading',
      (tester) async {
    await tester.pumpWidget(_wrap(subscription: const AsyncLoading()));
    await tester.pump();

    expect(find.byKey(const ValueKey('home.premiumCard')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'HomePremiumCard hides itself when the subscription provider errors',
      (tester) async {
    await tester.pumpWidget(_wrap(
      subscription: AsyncError<UserSubscription>(
        StateError('boom'),
        StackTrace.empty,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const ValueKey('home.premiumCard')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('HomePremiumCard tap routes to /subscription', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_wrap(
      subscription: AsyncData(UserSubscription.syntheticFree()),
      navKey: navKey,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const ValueKey('home.premiumCard')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('SUBSCRIPTION_STUB'), findsOneWidget);

    await _disposeTree(tester);
  });
}
