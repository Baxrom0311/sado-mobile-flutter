import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/billing_api.dart';
import 'package:sado_mobile/data/local/preferences.dart';
import 'package:sado_mobile/data/models/subscription_plan.dart';
import 'package:sado_mobile/features/subscription/plan_comparison_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/subscription_provider.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/subscription/compare',
      routes: [
        GoRoute(
          path: '/subscription/compare',
          builder: (_, __) => const PlanComparisonScreen(),
        ),
        GoRoute(
          path: '/subscription',
          builder: (_, __) => const Scaffold(
              body: Center(child: Text('CATALOG_FALLBACK'))),
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
  // Hero entrance + matrix paint finish well within ~600ms; the
  // mascot has a perpetual idle animation so we cannot pumpAndSettle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Deterministic billing API fake — only [listPlans] / [mySubscription]
/// are exercised on this screen.
class _FakeBillingApi implements BillingApi {
  _FakeBillingApi({
    this.plans = BillingApi.fallbackPlans,
    this.subscription,
    this.throwOnPlans = false,
    this.delayPlans = false,
  });

  final List<SubscriptionPlan> plans;
  final UserSubscription? subscription;
  final bool throwOnPlans;
  final bool delayPlans;

  @override
  Future<List<SubscriptionPlan>> listPlans() async {
    if (delayPlans) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (throwOnPlans) throw StateError('boom');
    return plans;
  }

  @override
  Future<UserSubscription> mySubscription() async {
    return subscription ?? UserSubscription.syntheticFree();
  }

  @override
  Future<UserSubscription> cancelAutoRenew() async {
    throw UnimplementedError(
      'cancelAutoRenew is not exercised on the comparison screen.',
    );
  }

  @override
  Future<UserSubscription> resumeAutoRenew() async {
    throw UnimplementedError(
      'resumeAutoRenew is not exercised on the comparison screen.',
    );
  }

  @override
  Future<SubscriptionUsage> usage() async => SubscriptionUsage.empty;

  @override
  Future<PaymentOrderPage> listOrders({String? cursor, int? limit}) async {
    throw UnimplementedError(
      'listOrders is not exercised on the comparison screen.',
    );
  }

  @override
  Future<PaymentOrder?> getOrder(String id) async {
    throw UnimplementedError(
      'getOrder is not exercised on the comparison screen.',
    );
  }

  @override
  Future<CheckoutSession> createCheckout({
    required String planCode,
    required String provider,
  }) async {
    throw UnimplementedError(
      'createCheckout is not exercised directly on the comparison screen.',
    );
  }
}

void main() {
  testWidgets(
      'PlanComparisonScreen renders the hero, three columns and the '
      'usage / features / support sections', (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(_FakeBillingApi()),
    ]));
    await _settle(tester);

    // Title bar.
    expect(find.text('Rejalarni taqqoslash'), findsWidgets);
    // Plan column headers (the static catalogue ships with all three).
    expect(find.text('Bepul'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Logoped'), findsOneWidget);

    // Recommended pill on the pro column.
    expect(find.text('Tavsiya'), findsOneWidget);

    // Section headers.
    expect(
      find.text('FOYDALANISH CHEGARALARI'),
      findsOneWidget,
    );
    expect(find.text('IMKONIYATLAR'), findsOneWidget);
    expect(find.text("QO'LLAB-QUVVATLASH"), findsOneWidget);

    // A representative usage row + cell value (free = 3/kun).
    expect(find.text('Kunlik mashqlar'), findsOneWidget);
    expect(find.text('3/kun'), findsOneWidget);
    // Unlimited cells should be present somewhere on the matrix.
    expect(find.text('Cheksiz'), findsWidgets);

    // Primary CTA at the bottom.
    expect(find.byKey(const Key('planCompare.primaryCta')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('planCompare.primaryCta')),
        matching: find.text("Premiumga o'tish"),
      ),
      findsOneWidget,
    );

    await _disposeTree(tester);
  });

  testWidgets(
      'PlanComparisonScreen marks the active plan with a "Joriy" badge and '
      'disables the upgrade CTA when the user is already on Premium',
      (tester) async {
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

    // Joriy badge present in the header row.
    expect(find.text('Joriy'), findsOneWidget);

    // CTA flips to "Joriy reja" and is disabled.
    final cta = find.byKey(const Key('planCompare.primaryCta'));
    expect(cta, findsOneWidget);
    final btn = tester.widget<ElevatedButton>(cta);
    expect(btn.onPressed, isNull);
    expect(
      find.descendant(of: cta, matching: find.text('Joriy reja')),
      findsOneWidget,
    );

    await _disposeTree(tester);
  });

  testWidgets(
      'PlanComparisonScreen renders the localised matrix when locale = ru',
      (tester) async {
    final prefs = Preferences.inMemory();
    await prefs.setLocaleCode('ru');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        localeProvider.overrideWith((_) => LocaleNotifier(prefs)),
        billingApiProvider.overrideWithValue(_FakeBillingApi()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('ru'),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L.supportedLocales,
        routerConfig: _router(),
      ),
    ));
    await _settle(tester);

    expect(find.text('Сравнение планов'), findsWidgets);
    // RU "Безлимит" must appear at least once for the unlimited tiers.
    expect(find.text('Безлимит'), findsWidgets);
    // Per-day formatter must produce the RU "/день" suffix.
    expect(find.text('3/день'), findsOneWidget);
    // CTA in Russian.
    expect(
      find.descendant(
        of: find.byKey(const Key('planCompare.primaryCta')),
        matching: find.text('Перейти на Premium'),
      ),
      findsOneWidget,
    );

    await _disposeTree(tester);
  });

  testWidgets(
      'PlanComparisonScreen shows a shimmer matrix while plans are loading '
      '(no default CircularProgressIndicator)',
      (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(
        _FakeBillingApi(delayPlans: true),
      ),
    ]));
    // Pump a single frame so the FutureProvider is still in the
    // "loading" state.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Shimmer placeholders rely on the standard ShimmerBox primitive
    // — at least one shimmer animation should be present.
    expect(find.byType(AnimatedBuilder), findsWidgets);

    // Drain the deferred future so dispose can proceed cleanly.
    await tester.pump(const Duration(seconds: 2));
    await _disposeTree(tester);
  });

  testWidgets(
      'PlanComparisonScreen surfaces the friendly error state and lets the '
      'user retry when /billing/plans rejects', (tester) async {
    final api = _FakeBillingApi(throwOnPlans: true);
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));
    await _settle(tester);

    expect(
      find.text("Taqqoslashni yuklab bo'lmadi"),
      findsOneWidget,
    );
    expect(find.text('Qayta urinish'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'PlanComparisonScreen primary CTA opens the payment method picker '
      'for free users on the Premium tier', (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(_FakeBillingApi()),
    ]));
    await _settle(tester);

    // The CTA renders only after plans hydrate — assert presence
    // before exercising the tap.
    expect(
      find.byKey(const Key('planCompare.primaryCta')),
      findsOneWidget,
    );

    // Scroll the screen so the CTA is in the viewport. The screen
    // uses a SingleChildScrollView so the CTA is always in the
    // widget tree, but the tap gesture still needs the CTA centre to
    // land inside the viewport. Drag the scrollable up so the CTA
    // surfaces.
    await tester.drag(
      find.byKey(const Key('planCompare.refresh')),
      const Offset(0, -2000),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('planCompare.primaryCta')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Picker comes up with both providers wired.
    expect(find.byKey(const Key('payment.picker')), findsOneWidget);
    expect(find.byKey(const Key('payment.picker.payme')), findsOneWidget);
    expect(find.byKey(const Key('payment.picker.click')), findsOneWidget);

    await tester.tap(find.byKey(const Key('payment.picker.close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('payment.picker')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'PlanComparisonScreen still renders cleanly when the API only ships '
      'the free tier (defensive fallback)', (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(_FakeBillingApi(
        plans: const [
          SubscriptionPlan(
            id: 'free',
            nameUz: 'Bepul',
            nameRu: 'Бесплатно',
            priceUzs: 0,
            limits: SubscriptionLimits(
              exercisesPerDay: 3,
              aiAnalysesPerMonth: 5,
              maxChildren: 1,
            ),
            features: ['basic_exercises', 'basic_progress'],
            sortOrder: 0,
          ),
        ],
      )),
    ]));
    await _settle(tester);

    // Free column rendered even though no other plans are in the
    // catalogue — this protects against regressions where a sparse
    // API response would leave the screen blank.
    expect(find.text('Bepul'), findsOneWidget);
    // The Premium-tier specific row still renders, even though the
    // pro column itself is missing — the row labels live in the
    // localised matrix definition.
    expect(find.text('PDF eksport'), findsOneWidget);

    await _disposeTree(tester);
  });
}
