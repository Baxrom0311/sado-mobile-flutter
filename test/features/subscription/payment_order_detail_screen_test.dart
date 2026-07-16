import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/billing_api.dart';
import 'package:sado_mobile/data/local/preferences.dart';
import 'package:sado_mobile/data/models/subscription_plan.dart';
import 'package:sado_mobile/features/subscription/payment_order_detail_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/subscription_provider.dart';
import 'package:sado_mobile/widgets/feedback/empty_state.dart';
import 'package:sado_mobile/widgets/feedback/error_state.dart';

GoRouter _router(String orderId) => GoRouter(
      initialLocation: '/subscription/orders/$orderId',
      routes: [
        GoRoute(
          path: '/subscription/orders/:id',
          builder: (_, state) => PaymentOrderDetailScreen(
            orderId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/subscription/history',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('SUBSCRIPTION_HISTORY_STUB')),
          ),
        ),
      ],
    );

Widget _wrap({
  required List<Override> overrides,
  required String orderId,
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
      routerConfig: _router(orderId),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _useTallSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _StubBillingApi implements BillingApi {
  _StubBillingApi({
    this.singleOrder,
    this.errorOnGet = false,
  });

  PaymentOrder? singleOrder;
  bool errorOnGet;
  int getCalls = 0;

  @override
  Future<List<SubscriptionPlan>> listPlans() async =>
      BillingApi.fallbackPlans;

  @override
  Future<UserSubscription> mySubscription() async =>
      UserSubscription.syntheticFree();

  @override
  Future<UserSubscription> cancelAutoRenew() async =>
      throw UnimplementedError('detail screen never cancels');

  @override
  Future<UserSubscription> resumeAutoRenew() async =>
      throw UnimplementedError('detail screen never resumes');

  @override
  Future<SubscriptionUsage> usage() async => SubscriptionUsage.empty;

  @override
  Future<CheckoutSession> createCheckout({
    required String planCode,
    required String provider,
  }) async {
    // Resume payment opens the sheet which lazily calls this — keep it
    // tolerant so the sheet animation doesn't crash the test tree.
    return const CheckoutSession(
      url: 'https://checkout.example/test',
      provider: 'payme',
    );
  }

  @override
  Future<PaymentOrderPage> listOrders({String? cursor, int? limit}) async {
    // Detail screen never lists orders directly. Return an empty page
    // for safety so a stray call doesn't crash the test tree.
    return PaymentOrderPage.empty;
  }

  @override
  Future<PaymentOrder?> getOrder(String id) async {
    getCalls++;
    if (errorOnGet) throw StateError('boom');
    if (singleOrder?.id == id) return singleOrder;
    return null;
  }
}

PaymentOrder _order({
  required String id,
  String state = 'paid',
  String provider = 'payme',
  int amountUzs = 39000,
  String planCode = 'parent_pro',
  DateTime? createdAt,
  DateTime? paidAt,
  DateTime? cancelledAt,
  DateTime? updatedAt,
}) {
  final created = createdAt ?? DateTime.utc(2025, 6, 10, 12);
  return PaymentOrder(
    id: id,
    planCode: planCode,
    amountUzs: amountUzs,
    amountTiyin: amountUzs * 100,
    state: state,
    provider: provider,
    createdAt: created,
    paidAt: state == 'paid' ? (paidAt ?? created) : paidAt,
    cancelledAt: state == 'cancelled' ? (cancelledAt ?? created) : cancelledAt,
    updatedAt: updatedAt ?? created,
  );
}

void main() {
  testWidgets(
      'PaymentOrderDetailScreen — paid order shows the celebratory '
      'header, amount, plan, provider badge and receipt fact list',
      (tester) async {
    await _useTallSurface(tester);
    final order = _order(
      id: 'ord-paid',
      state: 'paid',
      provider: 'payme',
      planCode: 'parent_pro',
      amountUzs: 39000,
    );
    final api = _StubBillingApi(singleOrder: order);

    await tester.pumpWidget(_wrap(
      orderId: order.id,
      overrides: [billingApiProvider.overrideWithValue(api)],
    ));
    await _settle(tester);

    // Header — celebratory copy + amount + plan + provider badge.
    expect(find.byKey(const Key('order.header.title')), findsOneWidget);
    expect(
      find.text('To\'lov yakunlandi'),
      findsOneWidget,
      reason: 'paid orders surface the celebratory header copy',
    );
    expect(find.byKey(const Key('order.header.amount')), findsOneWidget);
    expect(find.textContaining('39'), findsWidgets);
    expect(find.byKey(const Key('order.header.plan')), findsOneWidget);
    // The plan name appears both in the header tag-line and inside the
    // fact list — checking the localized string surfaces is enough,
    // we don't pin the exact widget count to keep the layout flexible.
    expect(find.text('Premium'), findsAtLeastNWidgets(1));

    // Fact list rows.
    expect(find.byKey(const Key('order.fact.amount')), findsOneWidget);
    expect(find.byKey(const Key('order.fact.plan')), findsOneWidget);
    expect(find.byKey(const Key('order.fact.provider')), findsOneWidget);
    expect(find.byKey(const Key('order.fact.state')), findsOneWidget);
    expect(find.byKey(const Key('order.fact.created')), findsOneWidget);
    expect(find.byKey(const Key('order.fact.paid')), findsOneWidget);
    expect(find.byKey(const Key('order.fact.id')), findsOneWidget);
    // Paid orders never show updatedAt or cancelledAt rows.
    expect(find.byKey(const Key('order.fact.updated')), findsNothing);
    expect(find.byKey(const Key('order.fact.cancelled')), findsNothing);

    // Hint card surfaces the "receipt is on its way" copy + mascot.
    expect(find.byKey(const Key('order.hint')), findsOneWidget);
    expect(
      find.textContaining('Kvitansiya'),
      findsOneWidget,
      reason: 'paid orders surface the receipt-en-route hint',
    );

    // Paid orders close out with the back-to-history secondary CTA.
    expect(find.byKey(const Key('order.cta.history')), findsOneWidget);
    expect(find.byKey(const Key('order.cta.resume')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets(
      'pending order shows the pending header, hint copy, updated_at row '
      'and the Resume payment CTA', (tester) async {
    await _useTallSurface(tester);
    final order = _order(
      id: 'ord-pending',
      state: 'pending',
      provider: 'click',
      planCode: 'parent_pro',
      amountUzs: 39000,
      updatedAt: DateTime.utc(2025, 6, 11, 13),
    );
    final api = _StubBillingApi(singleOrder: order);

    await tester.pumpWidget(_wrap(
      orderId: order.id,
      overrides: [billingApiProvider.overrideWithValue(api)],
    ));
    await _settle(tester);

    expect(find.text('To\'lov kutilmoqda'), findsOneWidget);
    // Click badge surfaces.
    expect(find.text('Click'), findsWidgets);
    expect(
      find.textContaining('to\'lov tasdiqlanmagan'),
      findsOneWidget,
      reason: 'pending hint copy is rendered',
    );
    // updated_at row only surfaces when there is no paid/cancelled
    // timestamp to lean on.
    expect(find.byKey(const Key('order.fact.updated')), findsOneWidget);
    expect(find.byKey(const Key('order.fact.paid')), findsNothing);
    expect(find.byKey(const Key('order.fact.cancelled')), findsNothing);
    // Pending orders surface the resume CTA, not the back-to-history one.
    expect(find.byKey(const Key('order.cta.resume')), findsOneWidget);
    expect(find.byKey(const Key('order.cta.history')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('cancelled order shows the cancelled header, fact row '
      'and matching hint copy', (tester) async {
    await _useTallSurface(tester);
    final order = _order(
      id: 'ord-cancelled',
      state: 'cancelled',
      provider: 'payme',
      cancelledAt: DateTime.utc(2025, 6, 12),
    );
    final api = _StubBillingApi(singleOrder: order);

    await tester.pumpWidget(_wrap(
      orderId: order.id,
      overrides: [billingApiProvider.overrideWithValue(api)],
    ));
    await _settle(tester);

    expect(find.text('To\'lov bekor qilingan'), findsOneWidget);
    expect(find.byKey(const Key('order.fact.cancelled')), findsOneWidget);
    expect(
      find.textContaining('bekor qilingan'),
      findsAtLeastNWidgets(1),
    );
    // Cancelled orders are terminal — no resume CTA.
    expect(find.byKey(const Key('order.cta.resume')), findsNothing);
    expect(find.byKey(const Key('order.cta.history')), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'when the order is genuinely missing, the screen surfaces a '
      'localized empty state (not a hard error)', (tester) async {
    final api = _StubBillingApi(singleOrder: null);

    await tester.pumpWidget(_wrap(
      orderId: 'ord-ghost',
      overrides: [billingApiProvider.overrideWithValue(api)],
    ));
    await _settle(tester);

    expect(find.byKey(const Key('order.notfound')), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Buyurtma topilmadi'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('an API error renders the localized error state with a '
      'retry button', (tester) async {
    final api = _StubBillingApi(errorOnGet: true);

    await tester.pumpWidget(_wrap(
      orderId: 'ord-broken',
      overrides: [billingApiProvider.overrideWithValue(api)],
    ));
    await _settle(tester);

    expect(find.byKey(const Key('order.error')), findsOneWidget);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Buyurtmani yuklab bo\'lmadi'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('Russian locale localizes header copy and hint',
      (tester) async {
    await _useTallSurface(tester);
    final order = _order(
      id: 'ord-ru',
      state: 'paid',
      provider: 'payme',
      planCode: 'parent_pro',
    );
    final api = _StubBillingApi(singleOrder: order);

    await tester.pumpWidget(_wrap(
      orderId: order.id,
      overrides: [billingApiProvider.overrideWithValue(api)],
      locale: const Locale('ru'),
    ));
    await _settle(tester);

    expect(find.text('Платёж завершён'), findsOneWidget);
    expect(
      find.textContaining('Квитанция'),
      findsAtLeastNWidgets(1),
      reason: 'Russian receipt hint copy is rendered in the hint card',
    );
    // Russian plan name resolves via SubscriptionPlanLabels — the
    // brand keeps the Latin "Premium" wording in both locales.
    expect(find.text('Premium'), findsAtLeastNWidgets(1));

    await _disposeTree(tester);
  });

  testWidgets('order id row exposes a copy button that pushes to clipboard',
      (tester) async {
    final order = _order(id: 'ord-copy-me');
    final api = _StubBillingApi(singleOrder: order);

    final messages = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      messages.add(call);
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(_wrap(
      orderId: order.id,
      overrides: [billingApiProvider.overrideWithValue(api)],
    ));
    await _settle(tester);

    expect(find.byKey(const Key('order.fact.id')), findsOneWidget);
    await tester.tap(find.byKey(const Key('order.fact.id.copy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final copyCall = messages.firstWhere(
      (m) => m.method == 'Clipboard.setData',
      orElse: () => const MethodCall('none'),
    );
    expect(copyCall.method, 'Clipboard.setData');
    expect(
      (copyCall.arguments as Map?)?['text'],
      order.id,
    );
    // Snackbar confirmation surfaces.
    expect(find.text('Buyurtma raqami nusxalandi'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('refresh action invalidates the provider and re-fetches',
      (tester) async {
    final order = _order(id: 'ord-refresh');
    final api = _StubBillingApi(singleOrder: order);

    await tester.pumpWidget(_wrap(
      orderId: order.id,
      overrides: [billingApiProvider.overrideWithValue(api)],
    ));
    await _settle(tester);

    final initialCalls = api.getCalls;
    await tester.tap(find.byKey(const Key('order.refresh')));
    await _settle(tester);
    expect(api.getCalls, greaterThan(initialCalls));

    await _disposeTree(tester);
  });

  testWidgets('detail screen reads cached page first, skipping the network',
      (tester) async {
    final cachedOrder = _order(id: 'ord-cached', state: 'paid');
    // Stub returns null on getOrder so the only way to get data is the
    // cached list page provider override.
    final api = _StubBillingApi(singleOrder: null);

    final container = ProviderContainer(overrides: [
      preferencesProvider.overrideWithValue(Preferences.inMemory()),
      billingApiProvider.overrideWithValue(api),
      paymentOrdersFirstPageProvider.overrideWith((_) async {
        return PaymentOrderPage(items: [cachedOrder], hasMore: false);
      }),
    ]);
    addTearDown(container.dispose);
    // Warm up the cache so the family provider's `ref.read` sees an
    // AsyncData state on first invocation. Without this prep, the
    // cache lookup falls through to the API on the first build —
    // which is fine in production (the cache hits on the *second*
    // visit) but defeats the test we're trying to write.
    await container.read(paymentOrdersFirstPageProvider.future);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('uz'),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L.supportedLocales,
        routerConfig: _router(cachedOrder.id),
      ),
    ));
    await _settle(tester);

    // Header rendered from the cached order — proves the cache hit.
    expect(find.byKey(const Key('order.body')), findsOneWidget);
    expect(find.text('To\'lov yakunlandi'), findsOneWidget);
    expect(api.getCalls, 0,
        reason: 'cache hit means we never call the network for getOrder');

    await _disposeTree(tester);
  });
}
