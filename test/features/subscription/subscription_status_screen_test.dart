import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/billing_api.dart';
import 'package:sado_mobile/data/local/preferences.dart';
import 'package:sado_mobile/data/models/subscription_plan.dart';
import 'package:sado_mobile/features/subscription/subscription_status_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/subscription_provider.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/subscription/status',
      routes: [
        GoRoute(
          path: '/subscription/status',
          builder: (_, __) => const SubscriptionStatusScreen(),
        ),
        GoRoute(
          path: '/subscription',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('SUBSCRIPTION_CATALOG_STUB')),
          ),
        ),
        GoRoute(
          path: '/subscription/history',
          builder: (_, __) => const Scaffold(
            // Mimics the real screen's app-bar title so the routing
            // assertion can match on a stable, localized string.
            appBar: null,
            body: Center(child: Text("To'lovlar tarixi")),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('SETTINGS_STUB')),
          ),
        ),
      ],
    );

Widget _wrap({
  required List<Override> overrides,
  Locale locale = const Locale('uz'),
}) {
  return ProviderScope(
    overrides: [
      preferencesProvider.overrideWithValue(Preferences.inMemory()),
      ...overrides,
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
      routerConfig: _router(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  // Hero entrance + RefreshIndicator settle within ~500ms.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// The screen's ListView lazily builds tiles, so widgets below the
/// fold of a small test viewport (default 800×600) won't be in the
/// element tree. Bump the surface so the entire paid layout renders
/// without scrolling.
Future<void> _useTallSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Lightweight stand-in for [BillingApi] that lets tests script
/// `cancelAutoRenew` and `resumeAutoRenew` outcomes deterministically.
class _StubBillingApi implements BillingApi {
  _StubBillingApi({
    required this.subscription,
    this.cancelOutcome = _CancelOutcome.success,
    this.resumeOutcome = _ResumeOutcome.success,
  });

  UserSubscription subscription;
  _CancelOutcome cancelOutcome;
  _ResumeOutcome resumeOutcome;
  int cancelCalls = 0;
  int resumeCalls = 0;

  @override
  Future<List<SubscriptionPlan>> listPlans() async =>
      BillingApi.fallbackPlans;

  @override
  Future<UserSubscription> mySubscription() async => subscription;

  @override
  Future<UserSubscription> cancelAutoRenew() async {
    cancelCalls++;
    switch (cancelOutcome) {
      case _CancelOutcome.success:
        final updated = subscription.copyWith(
          autoRenew: false,
          status: 'cancelled',
          cancelledAt: DateTime.utc(2025, 1, 15),
        );
        subscription = updated;
        return updated;
      case _CancelOutcome.notImplemented:
        throw const BillingNotImplemented('coming soon');
      case _CancelOutcome.failure:
        throw StateError('boom');
    }
  }

  @override
  Future<UserSubscription> resumeAutoRenew() async {
    resumeCalls++;
    switch (resumeOutcome) {
      case _ResumeOutcome.success:
        // copyWith can't null `cancelledAt` (`null ?? existing`),
        // so re-build the record explicitly to mirror what the API
        // returns when the user resumes a still-active period.
        final s = subscription;
        final updated = UserSubscription(
          id: s.id,
          planId: s.planId,
          status: 'active',
          startedAt: s.startedAt,
          expiresAt: s.expiresAt,
          cancelledAt: null,
          autoRenew: true,
          isActive: s.isActive,
          daysRemaining: s.daysRemaining,
          features: s.features,
        );
        subscription = updated;
        return updated;
      case _ResumeOutcome.notImplemented:
        throw const BillingNotImplemented('coming soon');
      case _ResumeOutcome.failure:
        throw StateError('boom');
    }
  }

  @override
  Future<SubscriptionUsage> usage() async => SubscriptionUsage.empty;

  @override
  Future<PaymentOrderPage> listOrders({String? cursor, int? limit}) async {
    // The status screen never lists orders directly — the history
    // affordance navigates instead. Fail loud if a regression dives
    // into the API from this screen.
    throw UnimplementedError(
      'listOrders is not part of the status-screen contract.',
    );
  }

  @override
  Future<PaymentOrder?> getOrder(String id) async {
    throw UnimplementedError(
      'getOrder is not part of the status-screen contract.',
    );
  }

  @override
  Future<CheckoutSession> createCheckout({
    required String planCode,
    required String provider,
  }) async {
    throw UnimplementedError(
      'createCheckout is not part of the status-screen contract.',
    );
  }
}

enum _CancelOutcome { success, notImplemented, failure }

enum _ResumeOutcome { success, notImplemented, failure }

UserSubscription _activeProSub() => UserSubscription(
      id: 'sub-1',
      planId: 'parent_pro',
      status: 'active',
      startedAt: DateTime.utc(2025, 1, 1),
      expiresAt: DateTime.utc(2025, 2, 1),
      autoRenew: true,
      isActive: true,
      daysRemaining: 14,
      features: const ['detailed_progress', 'export_pdf'],
    );

/// A paid subscription the user has already cancelled but whose paid
/// period hasn't ended yet. The status screen shows the "Resume" CTA
/// for exactly this state so the user can re-enable auto-renew before
/// the period ends.
UserSubscription _cancelledRunningSub() => UserSubscription(
      id: 'sub-1',
      planId: 'parent_pro',
      status: 'cancelled',
      startedAt: DateTime.utc(2025, 1, 1),
      // Far enough in the future that `isCancelledButRunning` evaluates
      // to true regardless of when the test runs.
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 14)),
      cancelledAt: DateTime.utc(2025, 1, 15),
      autoRenew: false,
      isActive: true,
      daysRemaining: 14,
      features: const ['detailed_progress', 'export_pdf'],
    );

void main() {
  testWidgets(
      'SubscriptionStatusScreen — free user sees the upsell hero, '
      'three bullets and the upgrade CTA', (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(
        _StubBillingApi(subscription: UserSubscription.syntheticFree()),
      ),
    ]));
    await _settle(tester);

    expect(find.byKey(const Key('subscription.status.freeHero')),
        findsOneWidget);
    expect(find.byKey(const Key('subscription.status.upgradeCta')),
        findsOneWidget);
    expect(find.text('Premiumga o\'tish'), findsOneWidget);
    expect(
      find.byKey(const Key('subscription.status.cancelCta')),
      findsNothing,
    );
    // The paid hero must not show up for free users.
    expect(find.byKey(const Key('subscription.status.paidHero')),
        findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — active paid user sees the hero, '
      'status badge, detail rows and a destructive cancel CTA',
      (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(
        _StubBillingApi(subscription: _activeProSub()),
      ),
    ]));
    await _settle(tester);

    expect(find.byKey(const Key('subscription.status.paidHero')),
        findsOneWidget);
    expect(find.byKey(const Key('subscription.status.detailCard')),
        findsOneWidget);
    expect(find.byKey(const Key('subscription.status.featuresCard')),
        findsOneWidget);
    expect(find.byKey(const Key('subscription.status.changePlanCta')),
        findsOneWidget);
    expect(find.byKey(const Key('subscription.status.cancelCta')),
        findsOneWidget);

    // Status pill says "Faol" (Active).
    expect(find.text('Faol'), findsOneWidget);
    // Days-remaining row uses the localized plural template.
    expect(find.text('14 kun'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — cancel flow asks for confirmation, '
      'then disables auto-renew and shows a success snackbar',
      (tester) async {
    await _useTallSurface(tester);
    final api = _StubBillingApi(subscription: _activeProSub());
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));
    await _settle(tester);

    // Open the confirm dialog.
    await tester.ensureVisible(
        find.byKey(const Key('subscription.status.cancelCta')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('subscription.status.cancelCta')));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Avtomatik yangilashni o\'chirish?'), findsOneWidget);

    // Confirm.
    await tester.tap(find
        .byKey(const Key('subscription.status.cancelDialog.confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.cancelCalls, 1);
    expect(
      find.textContaining('Avtomatik yangilash o\'chirildi'),
      findsWidgets,
    );

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — cancel flow keeps the subscription '
      'when the user dismisses the confirmation dialog', (tester) async {
    await _useTallSurface(tester);
    final api = _StubBillingApi(subscription: _activeProSub());
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));
    await _settle(tester);

    await tester.ensureVisible(
        find.byKey(const Key('subscription.status.cancelCta')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('subscription.status.cancelCta')));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 600));

    // Dismiss the dialog with "Saqlab qolish" (Keep).
    await tester.tap(find
        .byKey(const Key('subscription.status.cancelDialog.dismiss')));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 600));

    expect(api.cancelCalls, 0);
    expect(find.text('Avtomatik yangilashni o\'chirish?'), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — cancel falls back to the friendly '
      '"coming soon" sheet when the API is not yet deployed',
      (tester) async {
    await _useTallSurface(tester);
    final api = _StubBillingApi(
      subscription: _activeProSub(),
      cancelOutcome: _CancelOutcome.notImplemented,
    );
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));
    await _settle(tester);

    await tester.ensureVisible(
        find.byKey(const Key('subscription.status.cancelCta')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('subscription.status.cancelCta')));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find
        .byKey(const Key('subscription.status.cancelDialog.confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(api.cancelCalls, 1);
    expect(
      find.byKey(const Key('subscription.status.cancelComingSoon.close')),
      findsOneWidget,
    );

    // Dismiss to clean up overlays.
    await tester.tap(
      find.byKey(const Key('subscription.status.cancelComingSoon.close')),
    );
    await tester.pump(); await tester.pump(const Duration(milliseconds: 600));

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — cancelled-but-running subscription '
      'shows the Resume CTA (and hides the Cancel button)',
      (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(
        _StubBillingApi(subscription: _cancelledRunningSub()),
      ),
    ]));
    await _settle(tester);

    expect(
      find.byKey(const Key('subscription.status.resumeCta')),
      findsOneWidget,
    );
    // Cancel CTA is gated on `autoRenew == true`, so it should not
    // render once the subscription is already cancelled.
    expect(
      find.byKey(const Key('subscription.status.cancelCta')),
      findsNothing,
    );
    // The cancelled-hint banner remains so the user understands the
    // current state alongside the resume affordance.
    expect(
      find.textContaining('Avtomatik yangilash o\'chirilgan'),
      findsWidgets,
    );

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — resume flow asks for confirmation, '
      'then re-enables auto-renew and shows a success snackbar',
      (tester) async {
    await _useTallSurface(tester);
    final api = _StubBillingApi(subscription: _cancelledRunningSub());
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));
    await _settle(tester);

    await tester.ensureVisible(
      find.byKey(const Key('subscription.status.resumeCta')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('subscription.status.resumeCta')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Obunani davom ettirasizmi?'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('subscription.status.resumeDialog.confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.resumeCalls, 1);
    expect(
      find.textContaining('Avtomatik yangilash qayta yoqildi'),
      findsWidgets,
    );

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — resume flow keeps the cancelled state '
      'when the user dismisses the dialog', (tester) async {
    await _useTallSurface(tester);
    final api = _StubBillingApi(subscription: _cancelledRunningSub());
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));
    await _settle(tester);

    await tester.ensureVisible(
      find.byKey(const Key('subscription.status.resumeCta')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('subscription.status.resumeCta')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(
      find.byKey(const Key('subscription.status.resumeDialog.dismiss')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(api.resumeCalls, 0);
    expect(find.text('Obunani davom ettirasizmi?'), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — resume falls back to the friendly '
      '"coming soon" sheet when the API is not yet deployed',
      (tester) async {
    await _useTallSurface(tester);
    final api = _StubBillingApi(
      subscription: _cancelledRunningSub(),
      resumeOutcome: _ResumeOutcome.notImplemented,
    );
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));
    await _settle(tester);

    await tester.ensureVisible(
      find.byKey(const Key('subscription.status.resumeCta')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('subscription.status.resumeCta')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(
      find.byKey(const Key('subscription.status.resumeDialog.confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(api.resumeCalls, 1);
    expect(
      find.byKey(const Key('subscription.status.resumeComingSoon.close')),
      findsOneWidget,
    );

    // Dismiss to clean up the bottom sheet overlay.
    await tester.tap(
      find.byKey(const Key('subscription.status.resumeComingSoon.close')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — resume failure snackbar surfaces '
      'when the API throws a non-NotImplemented error',
      (tester) async {
    await _useTallSurface(tester);
    final api = _StubBillingApi(
      subscription: _cancelledRunningSub(),
      resumeOutcome: _ResumeOutcome.failure,
    );
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));
    await _settle(tester);

    await tester.ensureVisible(
      find.byKey(const Key('subscription.status.resumeCta')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('subscription.status.resumeCta')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(
      find.byKey(const Key('subscription.status.resumeDialog.confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(api.resumeCalls, 1);
    expect(
      find.textContaining('Davom ettirib bo\'lmadi'),
      findsWidgets,
    );

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — expired subscription replaces the '
      'cancel button with the expired hint banner', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(
        _StubBillingApi(
          subscription: _activeProSub().copyWith(
            status: 'expired',
            autoRenew: false,
          ),
        ),
      ),
    ]));
    await _settle(tester);

    expect(find.byKey(const Key('subscription.status.cancelCta')),
        findsNothing);
    expect(find.text('Muddati tugagan'), findsOneWidget);
    expect(
      find.textContaining('Obuna muddati tugadi'),
      findsWidgets,
    );

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — error state shows the retry button '
      'and triggers a refetch on tap', (tester) async {
    await _useTallSurface(tester);
    var threw = false;
    await tester.pumpWidget(_wrap(overrides: [
      mySubscriptionProvider.overrideWith((ref) async {
        if (!threw) {
          threw = true;
          throw StateError('boom');
        }
        return _activeProSub();
      }),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Obuna ma\'lumotlarini yuklab bo\'lmadi'),
        findsOneWidget);
    expect(find.text('Qayta urinish'), findsOneWidget);

    await tester.tap(find.text('Qayta urinish'));
    await _settle(tester);

    expect(find.byKey(const Key('subscription.status.paidHero')),
        findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — Russian locale renders the localized '
      'copy', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrap(
      locale: const Locale('ru'),
      overrides: [
        billingApiProvider.overrideWithValue(
          _StubBillingApi(subscription: _activeProSub()),
        ),
      ],
    ));
    await _settle(tester);

    expect(find.text('Активна'), findsOneWidget);
    expect(find.text('Сменить план'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — shimmer placeholder shows while the '
      'subscription is loading', (tester) async {
    final completer = Completer<UserSubscription>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete(UserSubscription.syntheticFree());
      }
    });

    await tester.pumpWidget(_wrap(overrides: [
      mySubscriptionProvider.overrideWith((ref) => completer.future),
    ]));
    await tester.pump();

    // The screen never falls back to a default CircularProgressIndicator.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Three shimmer cards stamp the loading layout.
    expect(find.byKey(const Key('subscription.status.freeHero')),
        findsNothing);
    expect(find.byKey(const Key('subscription.status.paidHero')),
        findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — usage card surfaces every tracked '
      'metric for free users', (tester) async {
    await _useTallSurface(tester);
    const usage = SubscriptionUsage(
      metrics: [
        UsageMetric(
          metric: 'assessments_per_day',
          limit: 3,
          used: 2,
          remaining: 1,
        ),
        UsageMetric(
          metric: 'children_total',
          limit: 1,
          used: 1,
          remaining: 0,
        ),
      ],
    );
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(
        _StubBillingApi(subscription: UserSubscription.syntheticFree()),
      ),
      subscriptionUsageProvider.overrideWith((ref) async => usage),
    ]));
    await _settle(tester);

    expect(find.byKey(const Key('subscription.usageCard')), findsOneWidget);
    expect(find.text('Kunlik baholashlar'), findsOneWidget);
    expect(find.text('Bolalar profili'), findsOneWidget);
    // Exhausted hint surfaces because children_total used == limit.
    expect(find.textContaining('Limitga yetdingiz'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — usage card surfaces unlimited metrics '
      'for paid users', (tester) async {
    await _useTallSurface(tester);
    const usage = SubscriptionUsage(
      metrics: [
        UsageMetric(metric: 'assessments_per_day', limit: -1, used: 12),
        UsageMetric(metric: 'ai_analysis', limit: -1, used: 4),
      ],
    );
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(
        _StubBillingApi(subscription: _activeProSub()),
      ),
      subscriptionUsageProvider.overrideWith((ref) async => usage),
    ]));
    await _settle(tester);

    expect(find.byKey(const Key('subscription.usageCard')), findsOneWidget);
    // Both metrics show "Unlimited" instead of a fraction.
    expect(find.text('Cheksiz'), findsNWidgets(2));
    // Exhausted hint never surfaces for unlimited metrics.
    expect(find.textContaining('Limitga yetdingiz'), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — usage error renders the retry pill '
      'without breaking the rest of the screen', (tester) async {
    await _useTallSurface(tester);
    var threw = false;
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(
        _StubBillingApi(subscription: _activeProSub()),
      ),
      subscriptionUsageProvider.overrideWith((ref) async {
        if (!threw) {
          threw = true;
          throw StateError('boom');
        }
        return const SubscriptionUsage(metrics: []);
      }),
    ]));
    await _settle(tester);

    expect(find.byKey(const Key('subscription.usageCard.errorPill')),
        findsOneWidget);
    // The rest of the screen still renders.
    expect(find.byKey(const Key('subscription.status.paidHero')),
        findsOneWidget);

    // Tap retry → pill disappears, empty card replaces it.
    await tester.ensureVisible(
        find.byKey(const Key('subscription.usageCard.errorPill.retry')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('subscription.usageCard.errorPill.retry')),
    );
    await _settle(tester);

    expect(find.byKey(const Key('subscription.usageCard.errorPill')),
        findsNothing);
    expect(find.byKey(const Key('subscription.usageCard.empty')),
        findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — billing-history link routes to '
      '/subscription/history from the free layout', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(_StubBillingApi(
        subscription: UserSubscription.syntheticFree(),
      )),
    ]));
    await _settle(tester);

    final link = find.byKey(const Key('subscription.status.historyLink'));
    expect(link, findsOneWidget);
    await tester.ensureVisible(link);
    await tester.pump();
    await tester.tap(link);
    await _settle(tester);

    // History screen renders the localized "To'lovlar tarixi" title.
    expect(find.text("To'lovlar tarixi"), findsWidgets);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionStatusScreen — billing-history link is also visible '
      'on the paid layout', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(
        _StubBillingApi(subscription: _activeProSub()),
      ),
    ]));
    await _settle(tester);

    expect(
      find.byKey(const Key('subscription.status.historyLink')),
      findsOneWidget,
    );

    await _disposeTree(tester);
  });
}
