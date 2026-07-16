import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/billing_api.dart';
import 'package:sado_mobile/data/local/preferences.dart';
import 'package:sado_mobile/data/models/subscription_plan.dart';
import 'package:sado_mobile/features/subscription/subscription_history_screen.dart';
import 'package:sado_mobile/features/subscription/widgets/payment_history_row.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/subscription_provider.dart';
import 'package:sado_mobile/widgets/feedback/empty_state.dart';
import 'package:sado_mobile/widgets/feedback/error_state.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/subscription/history',
      routes: [
        GoRoute(
          path: '/subscription/history',
          builder: (_, __) => const SubscriptionHistoryScreen(),
        ),
        GoRoute(
          path: '/subscription',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('SUBSCRIPTION_CATALOG_STUB')),
          ),
        ),
        GoRoute(
          path: '/subscription/status',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('SUBSCRIPTION_STATUS_STUB')),
          ),
        ),
        GoRoute(
          path: '/subscription/orders/:id',
          builder: (_, state) => Scaffold(
            body: Center(
              child: Text(
                'ORDER_DETAIL_STUB:${state.pathParameters['id']}',
              ),
            ),
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
  _StubBillingApi({required this.page, this.errorOnce = false});

  PaymentOrderPage page;
  bool errorOnce;
  int listCalls = 0;

  @override
  Future<List<SubscriptionPlan>> listPlans() async =>
      BillingApi.fallbackPlans;

  @override
  Future<UserSubscription> mySubscription() async =>
      UserSubscription.syntheticFree();

  @override
  Future<UserSubscription> cancelAutoRenew() async =>
      throw UnimplementedError('history screen never cancels');

  @override
  Future<UserSubscription> resumeAutoRenew() async =>
      throw UnimplementedError('history screen never resumes');

  @override
  Future<SubscriptionUsage> usage() async => SubscriptionUsage.empty;

  @override
  Future<CheckoutSession> createCheckout({
    required String planCode,
    required String provider,
  }) async =>
      throw UnimplementedError('history screen never checks out');

  @override
  Future<PaymentOrderPage> listOrders({String? cursor, int? limit}) async {
    listCalls++;
    if (errorOnce) {
      errorOnce = false;
      throw StateError('boom');
    }
    return page;
  }

  @override
  Future<PaymentOrder?> getOrder(String id) async {
    for (final o in page.items) {
      if (o.id == id) return o;
    }
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
}) {
  final created = createdAt ?? DateTime.utc(2025, 1, 10, 12);
  return PaymentOrder(
    id: id,
    planCode: planCode,
    amountUzs: amountUzs,
    amountTiyin: amountUzs * 100,
    state: state,
    provider: provider,
    createdAt: created,
    paidAt: state == 'paid' ? (paidAt ?? created) : null,
    cancelledAt: state == 'cancelled' ? (cancelledAt ?? created) : null,
    updatedAt: created,
  );
}

void main() {
  testWidgets(
      'SubscriptionHistoryScreen renders the loading skeleton, then the '
      'list of payment rows for a non-empty page', (tester) async {
    await _useTallSurface(tester);
    final api = _StubBillingApi(
      page: PaymentOrderPage(
        items: [
          _order(id: 'ord-1', state: 'paid'),
          _order(
            id: 'ord-2',
            state: 'cancelled',
            provider: 'click',
            createdAt: DateTime.utc(2025, 1, 8),
          ),
        ],
        hasMore: false,
      ),
    );
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));

    // The skeleton ships before the future resolves.
    expect(find.byKey(const Key('history.list')), findsNothing);

    await _settle(tester);

    expect(find.byKey(const Key('history.list')), findsOneWidget);
    expect(find.byKey(const Key('history.header')), findsOneWidget);
    expect(find.byType(PaymentHistoryRow), findsNWidgets(2));
    expect(find.byKey(const Key('history.row.amount')), findsNWidgets(2));

    // Header carries the localized "N ta to'lov" caption.
    expect(find.textContaining(RegExp(r"2 ta to'lov")), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('renders the empty-state when no orders are returned',
      (tester) async {
    final api = _StubBillingApi(page: PaymentOrderPage.empty);
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));
    await _settle(tester);

    expect(find.byKey(const Key('history.empty')), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
    // Empty CTA routes to /subscription.
    final cta = find.text('Premiumni ko\'rish');
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SUBSCRIPTION_CATALOG_STUB'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('shows the error state when listOrders throws and retries',
      (tester) async {
    final api = _StubBillingApi(
      page: PaymentOrderPage(
        items: [_order(id: 'ord-3')],
        hasMore: false,
      ),
      errorOnce: true,
    );
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));
    await _settle(tester);

    expect(find.byType(ErrorState), findsOneWidget);
    expect(api.listCalls, 1);

    // Retry → second call succeeds → list shows up.
    await tester.tap(find.text('Qayta urinish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ErrorState), findsNothing);
    expect(find.byType(PaymentHistoryRow), findsOneWidget);
    expect(api.listCalls, 2);

    await _disposeTree(tester);
  });

  testWidgets('refresh action invalidates the provider', (tester) async {
    final api = _StubBillingApi(
      page: PaymentOrderPage(
        items: [_order(id: 'ord-1')],
        hasMore: false,
      ),
    );
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));
    await _settle(tester);

    expect(api.listCalls, 1);
    await tester.tap(find.byKey(const Key('history.refresh')));
    await _settle(tester);
    expect(api.listCalls, 2);

    await _disposeTree(tester);
  });

  testWidgets('paid row shows the success badge with localized label',
      (tester) async {
    await _useTallSurface(tester);
    final api = _StubBillingApi(
      page: PaymentOrderPage(
        items: [_order(id: 'ord-1', state: 'paid')],
        hasMore: false,
      ),
    );
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));
    await _settle(tester);

    // Status chip + plan label both rendered.
    expect(find.text("To'langan"), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    // Amount label uses the locale-aware decimal formatter.
    expect(find.textContaining('39'), findsWidgets);

    await _disposeTree(tester);
  });

  testWidgets('cancelled row shows the danger badge in Russian locale',
      (tester) async {
    await _useTallSurface(tester);
    final api = _StubBillingApi(
      page: PaymentOrderPage(
        items: [_order(id: 'ord-2', state: 'cancelled', provider: 'click')],
        hasMore: false,
      ),
    );
    await tester.pumpWidget(_wrap(
      overrides: [billingApiProvider.overrideWithValue(api)],
      locale: const Locale('ru'),
    ));
    await _settle(tester);

    expect(find.text('Отменён'), findsOneWidget);
    // The provider label is concatenated into the subtitle line, so we
    // search for "Click " (with trailing space + separator) to disambiguate
    // from any other widget that might render "Click" on its own.
    expect(find.textContaining('Click ·'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'tapping a row navigates to the order-detail route with the id',
      (tester) async {
    await _useTallSurface(tester);
    final api = _StubBillingApi(
      page: PaymentOrderPage(
        items: [_order(id: 'ord-99', state: 'paid')],
        hasMore: false,
      ),
    );
    await tester.pumpWidget(_wrap(overrides: [
      billingApiProvider.overrideWithValue(api),
    ]));
    await _settle(tester);

    expect(find.byType(PaymentHistoryRow), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history.row.ord-99')));
    await _settle(tester);

    expect(find.text('ORDER_DETAIL_STUB:ord-99'), findsOneWidget);

    await _disposeTree(tester);
  });
}
