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
import 'package:sado_mobile/widgets/home_usage_meter.dart';

UserSubscription _freeSub() => UserSubscription.syntheticFree();

UserSubscription _paidSub() => UserSubscription(
      id: 'sub-1',
      planId: 'parent_pro',
      status: 'active',
      startedAt: DateTime.utc(2025, 1, 1),
    );

UsageMetric _capped(String token, {required int used, required int limit}) =>
    UsageMetric(metric: token, limit: limit, used: used);

UsageMetric _unlimited(String token) =>
    UsageMetric(metric: token, limit: -1, used: 999);

SubscriptionUsage _usageWith(List<UsageMetric> metrics) =>
    SubscriptionUsage(metrics: metrics);

GoRouter _router(GlobalKey<NavigatorState> navKey) => GoRouter(
      initialLocation: '/',
      navigatorKey: navKey,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: HomeUsageMeter(),
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
        GoRoute(
          path: '/subscription/status',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('SUBSCRIPTION_STATUS_STUB')),
          ),
        ),
      ],
    );

Widget _wrap({
  required AsyncValue<UserSubscription> subscription,
  required AsyncValue<SubscriptionUsage> usage,
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
      subscriptionUsageProvider.overrideWith((ref) async {
        return usage.when(
          data: (u) => u,
          loading: () => Completer<SubscriptionUsage>().future,
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

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('hides itself for paid users even when usage is non-empty',
      (tester) async {
    await tester.pumpWidget(_wrap(
      subscription: AsyncData(_paidSub()),
      usage: AsyncData(_usageWith([
        _capped('assessments_per_day', used: 1, limit: 3),
      ])),
    ));
    await _settle(tester);

    expect(find.byKey(const ValueKey('home.usageMeter')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('hides itself while the subscription provider is loading',
      (tester) async {
    await tester.pumpWidget(_wrap(
      subscription: const AsyncLoading(),
      usage: AsyncData(_usageWith([
        _capped('assessments_per_day', used: 1, limit: 3),
      ])),
    ));
    await _settle(tester);

    expect(find.byKey(const ValueKey('home.usageMeter')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('hides itself when the subscription provider errors',
      (tester) async {
    await tester.pumpWidget(_wrap(
      subscription: AsyncError<UserSubscription>(
        StateError('boom'),
        StackTrace.empty,
      ),
      usage: AsyncData(_usageWith([
        _capped('assessments_per_day', used: 1, limit: 3),
      ])),
    ));
    await _settle(tester);

    expect(find.byKey(const ValueKey('home.usageMeter')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'hides itself for free users when the usage envelope is empty',
      (tester) async {
    await tester.pumpWidget(_wrap(
      subscription: AsyncData(_freeSub()),
      usage: AsyncData(SubscriptionUsage.empty),
    ));
    await _settle(tester);

    expect(find.byKey(const ValueKey('home.usageMeter')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'hides itself for free users when no rendered metric is capped',
      (tester) async {
    await tester.pumpWidget(_wrap(
      subscription: AsyncData(_freeSub()),
      usage: AsyncData(_usageWith([
        _unlimited('assessments_per_day'),
        _unlimited('ai_analysis'),
      ])),
    ));
    await _settle(tester);

    expect(find.byKey(const ValueKey('home.usageMeter')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'renders the calm tone for a free user well below their daily limit',
      (tester) async {
    await tester.pumpWidget(_wrap(
      subscription: AsyncData(_freeSub()),
      usage: AsyncData(_usageWith([
        _capped('assessments_per_day', used: 1, limit: 3),
      ])),
    ));
    await _settle(tester);

    expect(find.byKey(const ValueKey('home.usageMeter')), findsOneWidget);
    expect(find.text('Bugungi foydalanish'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Kunlik baholashlar'), findsOneWidget);
    // Calm tone should *not* surface the upgrade pill.
    expect(find.byKey(const Key('home.usageMeter.cta')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'shows the near-limit headline + upgrade pill once usage crosses 70%',
      (tester) async {
    await tester.pumpWidget(_wrap(
      subscription: AsyncData(_freeSub()),
      usage: AsyncData(_usageWith([
        _capped('assessments_per_day', used: 7, limit: 10),
      ])),
    ));
    await _settle(tester);

    expect(find.byKey(const ValueKey('home.usageMeter')), findsOneWidget);
    expect(find.text('Limitga yaqin qoldingiz'), findsOneWidget);
    expect(find.text('7 / 10'), findsOneWidget);
    expect(find.byKey(const Key('home.usageMeter.cta')), findsOneWidget);
    expect(find.text('Premiumga o\'ting'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'shows the exhausted headline when the daily quota has been used up',
      (tester) async {
    await tester.pumpWidget(_wrap(
      subscription: AsyncData(_freeSub()),
      usage: AsyncData(_usageWith([
        _capped('assessments_per_day', used: 3, limit: 3),
      ])),
    ));
    await _settle(tester);

    expect(find.byKey(const ValueKey('home.usageMeter')), findsOneWidget);
    expect(find.text('Bugungi limit tugadi'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.byKey(const Key('home.usageMeter.cta')), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'renders the secondary AI metric when it is also capped',
      (tester) async {
    await tester.pumpWidget(_wrap(
      subscription: AsyncData(_freeSub()),
      usage: AsyncData(_usageWith([
        _capped('assessments_per_day', used: 1, limit: 3),
        _capped('ai_analysis', used: 4, limit: 5),
      ])),
    ));
    await _settle(tester);

    expect(
      find.byKey(const Key('home.usageMeter.metric.assessments_per_day')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home.usageMeter.metric.ai_analysis')),
      findsOneWidget,
    );
    expect(find.text('AI tahlillari'), findsOneWidget);
    // The AI metric is at 80% so the whole card flips to near-limit
    // tone even though the primary metric is calm.
    expect(find.text('Limitga yaqin qoldingiz'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'omits the secondary metric when ai_analysis is unlimited',
      (tester) async {
    await tester.pumpWidget(_wrap(
      subscription: AsyncData(_freeSub()),
      usage: AsyncData(_usageWith([
        _capped('assessments_per_day', used: 1, limit: 3),
        _unlimited('ai_analysis'),
      ])),
    ));
    await _settle(tester);

    expect(
      find.byKey(const Key('home.usageMeter.metric.assessments_per_day')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home.usageMeter.metric.ai_analysis')),
      findsNothing,
    );

    await _disposeTree(tester);
  });

  testWidgets(
      'renders the Russian copy when locale is ru',
      (tester) async {
    await tester.pumpWidget(_wrap(
      locale: const Locale('ru'),
      subscription: AsyncData(_freeSub()),
      usage: AsyncData(_usageWith([
        _capped('assessments_per_day', used: 3, limit: 3),
      ])),
    ));
    await _settle(tester);

    expect(find.text('Дневной лимит исчерпан'), findsOneWidget);
    expect(find.text('Перейти на Premium'), findsOneWidget);
    expect(find.text('Оценок в день'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'tap routes to /subscription/status under the calm tone',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_wrap(
      subscription: AsyncData(_freeSub()),
      usage: AsyncData(_usageWith([
        _capped('assessments_per_day', used: 1, limit: 3),
      ])),
      navKey: navKey,
    ));
    await _settle(tester);

    await tester.tap(find.byKey(const Key('home.usageMeter.tap')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('SUBSCRIPTION_STATUS_STUB'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'tap routes straight to /subscription when the meter is exhausted',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_wrap(
      subscription: AsyncData(_freeSub()),
      usage: AsyncData(_usageWith([
        _capped('assessments_per_day', used: 3, limit: 3),
      ])),
      navKey: navKey,
    ));
    await _settle(tester);

    await tester.tap(find.byKey(const Key('home.usageMeter.tap')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('SUBSCRIPTION_STUB'), findsOneWidget);

    await _disposeTree(tester);
  });

  test(
      'HomeUsageMeter.primaryMetricCandidates and secondaryMetricCandidates '
      'cover the canonical billing tokens', () {
    expect(
      HomeUsageMeter.primaryMetricCandidates,
      contains('assessments_per_day'),
    );
    expect(
      HomeUsageMeter.primaryMetricCandidates,
      contains('exercises_per_day'),
    );
    expect(
      HomeUsageMeter.secondaryMetricCandidates,
      contains('ai_analysis'),
    );
    expect(
      HomeUsageMeter.secondaryMetricCandidates,
      contains('ai_analyses_per_month'),
    );
  });
}
