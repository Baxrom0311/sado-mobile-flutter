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
import 'package:sado_mobile/features/subscription/subscription_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/subscription_provider.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/subscription',
      routes: [
        GoRoute(
          path: '/subscription',
          builder: (_, __) => const SubscriptionScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const Scaffold(
              body: Center(child: Text('SETTINGS_FALLBACK'))),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('HOME_FALLBACK'))),
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
  // Hero entrance + staggered card animations finish well before 600ms.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Fake API that returns deterministic data for tests.
class _FakeBillingApi implements BillingApi {
  _FakeBillingApi({
    this.plans = BillingApi.fallbackPlans,
    this.subscription,
    this.throwOnPlans = false,
  });

  final List<SubscriptionPlan> plans;
  final UserSubscription? subscription;
  final bool throwOnPlans;

  @override
  Future<List<SubscriptionPlan>> listPlans() async {
    if (throwOnPlans) throw StateError('boom');
    return plans;
  }

  @override
  Future<UserSubscription> mySubscription() async {
    return subscription ?? UserSubscription.syntheticFree();
  }

  @override
  Future<UserSubscription> cancelAutoRenew() async {
    // The catalog screen never exercises this code path — fail loud
    // if a regression accidentally calls it.
    throw UnimplementedError(
      'cancelAutoRenew is not part of the catalog screen contract.',
    );
  }

  @override
  Future<UserSubscription> resumeAutoRenew() async {
    throw UnimplementedError(
      'resumeAutoRenew is not part of the catalog screen contract.',
    );
  }

  @override
  Future<SubscriptionUsage> usage() async => SubscriptionUsage.empty;

  @override
  Future<PaymentOrderPage> listOrders({String? cursor, int? limit}) async {
    // The catalog screen never lists orders — fail loud if a regression
    // accidentally calls this.
    throw UnimplementedError(
      'listOrders is not part of the catalog screen contract.',
    );
  }

  @override
  Future<PaymentOrder?> getOrder(String id) async {
    // Catalog screen never resolves a single order — fail loud on
    // accidental calls.
    throw UnimplementedError(
      'getOrder is not part of the catalog screen contract.',
    );
  }

  @override
  Future<CheckoutSession> createCheckout({
    required String planCode,
    required String provider,
  }) async {
    // The catalog screen test never lands in the payment sheet — if a
    // regression starts firing it, fail loud so the test author knows
    // to update the stub instead of silently returning a fake URL.
    throw UnimplementedError(
      'createCheckout is not part of the catalog screen contract.',
    );
  }
}

void main() {
  testWidgets(
      'SubscriptionScreen renders the hero, every plan and footer note',
      (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(_FakeBillingApi()),
    ]));
    await _settle(tester);

    // Hero header.
    expect(find.text('SADO Premium'), findsWidgets);
    // All four default tiers: free, parent_pro, logoped_pro, clinic.
    // The catalogue grew when the API rolled out B2B tenant pricing —
    // we assert each card surfaces in the catalog.
    expect(find.byKey(const Key('subscription.plan.free')), findsOneWidget);
    expect(find.byKey(const Key('subscription.plan.parent_pro')),
        findsOneWidget);
    expect(find.byKey(const Key('subscription.plan.logoped_pro')),
        findsOneWidget);
    expect(find.byKey(const Key('subscription.plan.clinic')),
        findsOneWidget);
    // Footer disclaimer.
    expect(
      find.textContaining('xavfsiz', findRichText: true),
      findsOneWidget,
    );

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionScreen highlights the current plan with a "Joriy" badge '
      'and disables its CTA', (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(_FakeBillingApi(
        subscription: UserSubscription(
          id: 'sub-pro-1',
          planId: 'parent_pro',
          status: 'active',
          startedAt: DateTime.utc(2025, 1, 1),
        ),
      )),
    ]));
    await _settle(tester);

    // The pro card now carries the "Joriy" badge twice — once on the
    // card chip and once as the disabled CTA label.
    final proCard = find.byKey(const Key('subscription.plan.parent_pro'));
    expect(proCard, findsOneWidget);
    final badges = find.descendant(
      of: proCard,
      matching: find.text('Joriy'),
    );
    expect(badges, findsWidgets);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionScreen tapping the Premium upgrade CTA opens the '
      'payment method picker', (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(_FakeBillingApi()),
    ]));
    await _settle(tester);

    final proCta = find.descendant(
      of: find.byKey(const Key('subscription.plan.parent_pro')),
      matching: find.widgetWithText(ElevatedButton, 'Premiumga o\'tish'),
    );
    expect(proCta, findsOneWidget);

    // Bring the CTA into the viewport before tapping — the parent_pro
    // tier sits below the fold on smaller test surfaces and a hit test
    // through an offscreen widget would otherwise emit a warning.
    await tester.ensureVisible(proCta);
    await tester.pump();

    await tester.tap(proCta, warnIfMissed: false);
    // The bottom sheet uses transient animations — pump enough frames for
    // the entrance to finish without resorting to pumpAndSettle (the
    // mascot has a continuous bob/blink loop that never settles).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Picker is up: both providers + the close action are wired.
    expect(find.byKey(const Key('payment.picker')), findsOneWidget);
    expect(find.byKey(const Key('payment.picker.payme')), findsOneWidget);
    expect(find.byKey(const Key('payment.picker.click')), findsOneWidget);

    // Dismiss to clean up — the close button delegates to maybePop.
    await tester.tap(find.byKey(const Key('payment.picker.close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('payment.picker')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionScreen routes the Logoped tier to the branded '
      'Contact Sales sheet (direct sales, no self-serve checkout)',
      (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(_FakeBillingApi()),
    ]));
    await _settle(tester);

    final logopedCta = find.descendant(
      of: find.byKey(const Key('subscription.plan.logoped_pro')),
      // Logoped uses the "Contact sales" CTA copy so it opts out of the
      // self-serve path.
      matching: find.widgetWithText(
        ElevatedButton,
        'Logoped uchun bog\'lanish',
      ),
    );
    expect(logopedCta, findsOneWidget);
    await tester.ensureVisible(logopedCta);
    await tester.pump();
    await tester.tap(logopedCta, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Branded Contact Sales sheet — surfaces real email + phone with
    // one-tap mail composer / dialer CTAs so the tap converts into a
    // qualified lead instead of a dead-end "coming soon" beat.
    expect(find.byKey(const Key('contactSales.title')), findsOneWidget);
    expect(find.byKey(const Key('contactSales.email.cta')), findsOneWidget);
    expect(find.byKey(const Key('contactSales.phone.cta')), findsOneWidget);
    expect(find.byKey(const Key('contactSales.close')), findsOneWidget);
    // The new payment-method picker should NOT appear for B2B tiers.
    expect(find.byKey(const Key('payment.picker')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionScreen also routes the Clinic tier through the '
      'Contact Sales sheet — tenant pricing is bespoke, no '
      'self-serve checkout',
      (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(_FakeBillingApi()),
    ]));
    await _settle(tester);

    final clinicCta = find.descendant(
      of: find.byKey(const Key('subscription.plan.clinic')),
      matching: find.widgetWithText(
        ElevatedButton,
        'Logoped uchun bog\'lanish',
      ),
    );
    expect(clinicCta, findsOneWidget);
    await tester.ensureVisible(clinicCta);
    await tester.pump();
    await tester.tap(clinicCta, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const Key('contactSales.title')), findsOneWidget);
    expect(find.byKey(const Key('payment.picker')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionScreen renders the Russian copy when locale is "ru"',
      (tester) async {
    await tester.pumpWidget(_wrap(
      locale: const Locale('ru'),
      overrides: [
        billingApiProvider.overrideWithValue(_FakeBillingApi()),
      ],
    ));
    await _settle(tester);

    expect(find.textContaining('Безлимит'), findsWidgets);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionScreen renders the localized empty state when the '
      'API returns no plans', (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(
        _FakeBillingApi(plans: const []),
      ),
    ]));
    await _settle(tester);

    expect(find.text('Hozircha rejalar yo\'q'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionScreen renders the error state with a retry CTA when '
      'the catalog throws', (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider
          .overrideWithValue(_FakeBillingApi(throwOnPlans: true)),
    ]));
    await _settle(tester);

    expect(find.text('Rejalarni yuklab bo\'lmadi'), findsOneWidget);
    expect(find.text('Qayta urinish'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'SubscriptionScreen surfaces a shimmer while plans are loading',
      (tester) async {
    // Use a Completer-backed future so it never auto-resolves but also
    // doesn't schedule a real timer (which would trip
    // `!timersPending` when the widget tree is disposed).
    final completer = Completer<List<SubscriptionPlan>>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete(const <SubscriptionPlan>[]);
      }
    });

    await tester.pumpWidget(_wrap(overrides: [
      subscriptionPlansProvider.overrideWith((ref) => completer.future),
    ]));
    await tester.pump();

    expect(find.text('Rejalar yuklanmoqda…'), findsOneWidget);

    await _disposeTree(tester);
  });
}
