import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/api/billing_api.dart';
import 'package:sado_mobile/data/models/subscription_plan.dart';

/// Scripted adapter that returns a queue of pre-baked responses.
/// Each step is either a [_ScriptedResponse] (path, status, body) or
/// a [DioException] to simulate network errors.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._steps);
  final List<Object> _steps;
  final List<RequestOptions> calls = <RequestOptions>[];
  int _idx = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    if (_idx >= _steps.length) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final step = _steps[_idx++];
    if (step is DioException) {
      throw step.copyWith(requestOptions: options);
    }
    final r = step as _ScriptedResponse;
    return ResponseBody.fromString(
      r.body,
      r.status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}

class _ScriptedResponse {
  _ScriptedResponse(this.status, this.body);
  final int status;
  final String body;
}

Dio _dio(_ScriptedAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.test/api/v1',
    contentType: 'application/json',
  ));
  dio.httpClientAdapter = adapter;
  return dio;
}

DioException _notFound(RequestOptions options) => DioException(
      requestOptions: options,
      response: Response(
        requestOptions: options,
        statusCode: 404,
        data: <String, dynamic>{'detail': 'not found'},
      ),
      type: DioExceptionType.badResponse,
    );

void main() {
  group('BillingApi.listPlans', () {
    test(
        'falls back to the curated catalogue when the live endpoint '
        'returns a network error', () async {
      final adapter = _ScriptedAdapter([
        DioException(
          requestOptions: RequestOptions(path: '/billing/plans'),
          type: DioExceptionType.connectionTimeout,
        ),
      ]);
      final api = BillingApi(_dio(adapter));
      final plans = await api.listPlans();
      expect(plans, BillingApi.fallbackPlans);
    });

    test(
        'parses the live wire format with `code` slug and a paginated '
        'envelope', () async {
      final body = jsonEncode(<String, dynamic>{
        'items': [
          <String, dynamic>{
            'id': 'uuid-1',
            'code': 'free',
            'name_uz': 'Bepul',
            'name_ru': 'Бесплатно',
            'price_uzs': 0,
            'is_active': true,
            'features': <String, dynamic>{
              'max_assessments_per_day': 3,
              'max_children': 1,
              'basic_exercises': true,
            },
          },
          <String, dynamic>{
            'id': 'uuid-2',
            'code': 'parent_pro',
            'name_uz': 'Premium',
            'name_ru': 'Премиум',
            'price_uzs': 39000,
            'is_active': true,
            'sort_order': 10,
            'features': <String, dynamic>{
              'max_assessments_per_day': -1,
              'max_children': 5,
              'export_pdf': true,
            },
          },
        ],
      });
      final adapter = _ScriptedAdapter([_ScriptedResponse(200, body)]);
      final api = BillingApi(_dio(adapter));
      final plans = await api.listPlans();
      expect(plans, hasLength(2));
      expect(plans.first.id, 'free');
      expect(plans.last.id, 'parent_pro');
      expect(plans.last.priceUzs, 39000);
      expect(plans.first.limits.exercisesPerDay, 3);
    });

    test('drops inactive plans and sorts by sort_order', () async {
      final body = jsonEncode([
        <String, dynamic>{
          'id': 'uuid-2',
          'code': 'parent_pro',
          'name_uz': 'Premium',
          'name_ru': 'Премиум',
          'price_uzs': 39000,
          'is_active': true,
          'sort_order': 10,
          'features': const <String>[],
        },
        <String, dynamic>{
          'id': 'uuid-1',
          'code': 'free',
          'name_uz': 'Bepul',
          'name_ru': 'Бесплатно',
          'price_uzs': 0,
          'is_active': true,
          'sort_order': 0,
          'features': const <String>[],
        },
        <String, dynamic>{
          'id': 'uuid-3',
          'code': 'discontinued',
          'name_uz': 'Eski',
          'name_ru': 'Старый',
          'price_uzs': 0,
          'is_active': false,
          'sort_order': 20,
          'features': const <String>[],
        },
      ]);
      final adapter = _ScriptedAdapter([_ScriptedResponse(200, body)]);
      final api = BillingApi(_dio(adapter));
      final plans = await api.listPlans();
      expect(plans.map((p) => p.id), ['free', 'parent_pro']);
    });
  });

  group('BillingApi.mySubscription', () {
    test('parses the live wire shape (plan_code / starts_at)', () async {
      final body = jsonEncode(<String, dynamic>{
        'id': 'sub-1',
        'user_id': 'u-1',
        'plan_code': 'parent_pro',
        'status': 'active',
        'starts_at': '2025-01-01T00:00:00Z',
        'expires_at': '2025-02-01T00:00:00Z',
        'auto_renew': true,
        'is_active': true,
        'days_remaining': 14,
      });
      final adapter = _ScriptedAdapter([_ScriptedResponse(200, body)]);
      final api = BillingApi(_dio(adapter));
      final sub = await api.mySubscription();
      expect(sub.planId, 'parent_pro');
      expect(sub.daysRemaining, 14);
      expect(sub.autoRenew, isTrue);
      // The first call goes to the canonical path.
      expect(adapter.calls.first.path, '/billing/subscription');
    });

    test('falls through to /me when the canonical path returns 404',
        () async {
      final fallbackBody = jsonEncode(<String, dynamic>{
        'id': 'sub-legacy',
        'plan_code': 'free',
        'status': 'active',
        'starts_at': '2025-01-01T00:00:00Z',
      });
      final adapter = _ScriptedAdapter([
        _notFound(RequestOptions(path: '/billing/subscription')),
        _ScriptedResponse(200, fallbackBody),
      ]);
      final api = BillingApi(_dio(adapter));
      final sub = await api.mySubscription();
      expect(sub.planId, 'free');
      expect(adapter.calls.map((c) => c.path), [
        '/billing/subscription',
        '/billing/subscription/me',
      ]);
    });

    test('synthesises a free record on a network error', () async {
      final adapter = _ScriptedAdapter([
        DioException(
          requestOptions: RequestOptions(path: '/billing/subscription'),
          type: DioExceptionType.connectionError,
        ),
      ]);
      final api = BillingApi(_dio(adapter));
      final sub = await api.mySubscription();
      expect(sub.planId, 'free');
      expect(sub.id, 'synthetic-free');
    });

    test('synthesises a free record when both candidate paths 404',
        () async {
      final adapter = _ScriptedAdapter([
        _notFound(RequestOptions(path: '/billing/subscription')),
        _notFound(RequestOptions(path: '/billing/subscription/me')),
      ]);
      final api = BillingApi(_dio(adapter));
      final sub = await api.mySubscription();
      expect(sub.planId, 'free');
    });
  });

  group('BillingApi.cancelAutoRenew', () {
    test('parses the updated subscription returned by the API', () async {
      final body = jsonEncode(<String, dynamic>{
        'id': 'sub-1',
        'plan_code': 'parent_pro',
        'status': 'cancelled',
        'starts_at': '2025-01-01T00:00:00Z',
        'expires_at': '2025-02-01T00:00:00Z',
        'auto_renew': false,
        'cancelled_at': '2025-01-15T00:00:00Z',
      });
      final adapter = _ScriptedAdapter([_ScriptedResponse(200, body)]);
      final api = BillingApi(_dio(adapter));
      final sub = await api.cancelAutoRenew();
      expect(sub.autoRenew, isFalse);
      expect(sub.cancelledAt, isNotNull);
      expect(adapter.calls.single.path, '/billing/subscription/cancel');
      expect(adapter.calls.single.method, 'POST');
    });

    test(
        'throws BillingNotImplemented when the cancel endpoint returns 404',
        () async {
      final adapter = _ScriptedAdapter([
        _notFound(RequestOptions(path: '/billing/subscription/cancel')),
      ]);
      final api = BillingApi(_dio(adapter));
      expect(
        () => api.cancelAutoRenew(),
        throwsA(isA<BillingNotImplemented>()),
      );
    });

    test(
        'rethrows on a server error so the caller can show a real '
        'failure snackbar', () async {
      final adapter = _ScriptedAdapter([
        DioException(
          requestOptions:
              RequestOptions(path: '/billing/subscription/cancel'),
          response: Response(
            requestOptions:
                RequestOptions(path: '/billing/subscription/cancel'),
            statusCode: 500,
          ),
          type: DioExceptionType.badResponse,
        ),
      ]);
      final api = BillingApi(_dio(adapter));
      expect(
        () => api.cancelAutoRenew(),
        throwsA(isA<DioException>()),
      );
    });

    test(
        'falls back to mySubscription when the cancel endpoint returns '
        '204 with no body', () async {
      final refreshedBody = jsonEncode(<String, dynamic>{
        'id': 'sub-1',
        'plan_code': 'parent_pro',
        'status': 'cancelled',
        'starts_at': '2025-01-01T00:00:00Z',
        'auto_renew': false,
      });
      final adapter = _ScriptedAdapter([
        _ScriptedResponse(204, ''),
        _ScriptedResponse(200, refreshedBody),
      ]);
      final api = BillingApi(_dio(adapter));
      final sub = await api.cancelAutoRenew();
      expect(sub.autoRenew, isFalse);
      expect(adapter.calls.map((c) => c.path), [
        '/billing/subscription/cancel',
        '/billing/subscription',
      ]);
    });
  });

  group('BillingApi.resumeAutoRenew', () {
    test('parses the updated subscription returned by the API', () async {
      final body = jsonEncode(<String, dynamic>{
        'id': 'sub-1',
        'plan_code': 'parent_pro',
        'status': 'active',
        'starts_at': '2025-01-01T00:00:00Z',
        'expires_at': '2025-02-01T00:00:00Z',
        'auto_renew': true,
      });
      final adapter = _ScriptedAdapter([_ScriptedResponse(200, body)]);
      final api = BillingApi(_dio(adapter));
      final sub = await api.resumeAutoRenew();
      expect(sub.autoRenew, isTrue);
      expect(sub.status, 'active');
      expect(sub.cancelledAt, isNull);
      expect(adapter.calls.single.path, '/billing/subscription/resume');
      expect(adapter.calls.single.method, 'POST');
    });

    test(
        'throws BillingNotImplemented when the resume endpoint returns '
        '404 so the UI can show a friendly coming-soon sheet',
        () async {
      final adapter = _ScriptedAdapter([
        _notFound(RequestOptions(path: '/billing/subscription/resume')),
      ]);
      final api = BillingApi(_dio(adapter));
      expect(
        () => api.resumeAutoRenew(),
        throwsA(isA<BillingNotImplemented>()),
      );
    });

    test(
        'throws BillingNotImplemented when the resume endpoint returns '
        '405 (method not allowed during partial rollout)', () async {
      final adapter = _ScriptedAdapter([
        DioException(
          requestOptions:
              RequestOptions(path: '/billing/subscription/resume'),
          response: Response(
            requestOptions:
                RequestOptions(path: '/billing/subscription/resume'),
            statusCode: 405,
          ),
          type: DioExceptionType.badResponse,
        ),
      ]);
      final api = BillingApi(_dio(adapter));
      expect(
        () => api.resumeAutoRenew(),
        throwsA(isA<BillingNotImplemented>()),
      );
    });

    test(
        'rethrows on a 5xx error so the caller can surface a real '
        'failure snackbar', () async {
      final adapter = _ScriptedAdapter([
        DioException(
          requestOptions:
              RequestOptions(path: '/billing/subscription/resume'),
          response: Response(
            requestOptions:
                RequestOptions(path: '/billing/subscription/resume'),
            statusCode: 500,
          ),
          type: DioExceptionType.badResponse,
        ),
      ]);
      final api = BillingApi(_dio(adapter));
      expect(
        () => api.resumeAutoRenew(),
        throwsA(isA<DioException>()),
      );
    });

    test(
        'falls back to mySubscription when the resume endpoint returns '
        '204 No Content', () async {
      final refreshedBody = jsonEncode(<String, dynamic>{
        'id': 'sub-1',
        'plan_code': 'parent_pro',
        'status': 'active',
        'starts_at': '2025-01-01T00:00:00Z',
        'auto_renew': true,
      });
      final adapter = _ScriptedAdapter([
        _ScriptedResponse(204, ''),
        _ScriptedResponse(200, refreshedBody),
      ]);
      final api = BillingApi(_dio(adapter));
      final sub = await api.resumeAutoRenew();
      expect(sub.autoRenew, isTrue);
      expect(adapter.calls.map((c) => c.path), [
        '/billing/subscription/resume',
        '/billing/subscription',
      ]);
    });
  });

  test(
      'SubscriptionPlan.fallbackPlans is ordered by canonical '
      'sort_order so paid plans are pitched before B2B "contact sales" '
      'tiers', () {
    final orders =
        BillingApi.fallbackPlans.map((p) => p.sortOrder).toList();
    final sorted = [...orders]..sort();
    expect(orders, sorted,
        reason:
            'Catalog must be sorted by sort_order; current sequence: $orders');
  });

  test(
      'SubscriptionPlan.fallbackPlans paid tiers (priceUzs > 0) are '
      'pitched in ascending price so the upgrade screen reads cheapest '
      '→ most expensive', () {
    final paidPrices = BillingApi.fallbackPlans
        .where((p) => p.priceUzs > 0)
        .map((p) => p.priceUzs)
        .toList();
    final sorted = [...paidPrices]..sort();
    expect(paidPrices, sorted, reason: 'Paid plans must be ascending');
  });

  test(
      'SubscriptionPlan.fallbackPlans includes the new logoped_pro and '
      'clinic tiers from the API rollout', () {
    final ids = BillingApi.fallbackPlans.map((p) => p.id).toSet();
    expect(ids, containsAll(<String>['free', 'parent_pro', 'logoped_pro', 'clinic']));
  });

  group('BillingApi.createCheckout', () {
    test(
        'POSTs to /billing/orders with plan_code + provider and parses '
        'the live wire shape', () async {
      final body = jsonEncode(<String, dynamic>{
        'order_id': 'ord-42',
        'provider': 'payme',
        'url': 'https://checkout.paycom.uz/abc123',
        'amount_uzs': 39000,
        'expires_at': '2025-02-01T00:00:00Z',
      });
      final adapter = _ScriptedAdapter([_ScriptedResponse(200, body)]);
      final api = BillingApi(_dio(adapter));
      final session = await api.createCheckout(
        planCode: 'parent_pro',
        provider: 'payme',
      );

      expect(session.url, 'https://checkout.paycom.uz/abc123');
      expect(session.provider, 'payme');
      expect(session.orderId, 'ord-42');
      expect(session.amountUzs, 39000);
      expect(session.expiresAt, isNotNull);
      expect(adapter.calls.single.path, '/billing/orders');
      expect(adapter.calls.single.method, 'POST');
      expect(adapter.calls.single.data, <String, dynamic>{
        'plan_code': 'parent_pro',
        'provider': 'payme',
      });
    });

    test('accepts the legacy `checkout_url` alias', () async {
      final body = jsonEncode(<String, dynamic>{
        'id': 'ord-7',
        'provider': 'click',
        'checkout_url': 'https://my.click.uz/services/pay/xyz',
      });
      final adapter = _ScriptedAdapter([_ScriptedResponse(200, body)]);
      final api = BillingApi(_dio(adapter));
      final session = await api.createCheckout(
        planCode: 'parent_pro',
        provider: 'click',
      );
      expect(session.url, 'https://my.click.uz/services/pay/xyz');
      // `id` is used as the order id when `order_id` is missing — keeps
      // the mobile app talking to older API revisions.
      expect(session.orderId, 'ord-7');
      expect(session.provider, 'click');
    });

    test(
        'throws BillingNotImplemented when the endpoint is not deployed '
        'yet (404)', () async {
      final adapter = _ScriptedAdapter([
        _notFound(RequestOptions(path: '/billing/orders')),
      ]);
      final api = BillingApi(_dio(adapter));
      expect(
        () => api.createCheckout(
          planCode: 'parent_pro',
          provider: 'payme',
        ),
        throwsA(isA<BillingNotImplemented>()),
      );
    });

    test(
        'rethrows on a 5xx server error so the caller can surface a '
        'real failure UI', () async {
      final adapter = _ScriptedAdapter([
        DioException(
          requestOptions: RequestOptions(path: '/billing/orders'),
          response: Response(
            requestOptions: RequestOptions(path: '/billing/orders'),
            statusCode: 500,
          ),
          type: DioExceptionType.badResponse,
        ),
      ]);
      final api = BillingApi(_dio(adapter));
      expect(
        () => api.createCheckout(
          planCode: 'parent_pro',
          provider: 'payme',
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('throws FormatException when the API responds with no url',
        () async {
      final body = jsonEncode(<String, dynamic>{
        'order_id': 'ord-empty',
        'provider': 'payme',
      });
      final adapter = _ScriptedAdapter([_ScriptedResponse(200, body)]);
      final api = BillingApi(_dio(adapter));
      expect(
        () => api.createCheckout(
          planCode: 'parent_pro',
          provider: 'payme',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BillingApi.listOrders', () {
    test('parses the cursor-paginated envelope', () async {
      final body = jsonEncode(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          {
            'id': 'ord-1',
            'plan_code': 'parent_pro',
            'amount_tiyin': 3900000,
            'amount_uzs': 39000,
            'state': 'paid',
            'provider': 'payme',
            'created_at': '2025-01-10T12:00:00Z',
            'paid_at': '2025-01-10T12:01:00Z',
          },
          {
            'id': 'ord-2',
            'plan_code': 'parent_pro',
            'amount_tiyin': 3900000,
            'state': 'cancelled',
            'provider': 'click',
            'created_at': '2025-01-08T09:30:00Z',
            'cancelled_at': '2025-01-08T09:45:00Z',
          },
        ],
        'next_cursor': 'opaque-1',
        'has_more': true,
      });
      final adapter = _ScriptedAdapter([_ScriptedResponse(200, body)]);
      final api = BillingApi(_dio(adapter));

      final page = await api.listOrders(limit: 5);

      expect(page.items, hasLength(2));
      expect(page.nextCursor, 'opaque-1');
      expect(page.hasMore, isTrue);

      final first = page.items.first;
      expect(first.id, 'ord-1');
      expect(first.amountUzs, 39000);
      expect(first.amountTiyin, 3900000);
      expect(first.state, 'paid');
      expect(first.isPaid, isTrue);
      expect(first.isPending, isFalse);
      expect(first.provider, 'payme');
      expect(first.paidAt, isNotNull);

      final second = page.items.last;
      expect(second.isCancelled, isTrue);
      expect(second.cancelledAt, isNotNull);
      expect(second.displayedAt, second.cancelledAt);
      // amount_uzs missing from the wire payload — derive from tiyin.
      expect(second.amountUzs, 39000);
    });

    test('falls back to the empty page when the endpoint returns 404',
        () async {
      final adapter = _ScriptedAdapter([
        _notFound(RequestOptions(path: '/billing/orders')),
      ]);
      final api = BillingApi(_dio(adapter));

      final page = await api.listOrders();

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(identical(page, PaymentOrderPage.empty), isTrue);
    });

    test('rethrows non-fatal errors so the caller can surface a retry state',
        () async {
      final options = RequestOptions(path: '/billing/orders');
      final adapter = _ScriptedAdapter([
        DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 500,
          ),
          type: DioExceptionType.badResponse,
        ),
      ]);
      final api = BillingApi(_dio(adapter));
      expect(api.listOrders(), throwsA(isA<DioException>()));
    });

    test('forwards cursor + limit query params', () async {
      final body = jsonEncode(<String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'has_more': false,
      });
      final adapter = _ScriptedAdapter([_ScriptedResponse(200, body)]);
      final api = BillingApi(_dio(adapter));

      await api.listOrders(cursor: 'next-page', limit: 10);

      expect(adapter.calls, hasLength(1));
      final qp = adapter.calls.single.queryParameters;
      expect(qp['cursor'], 'next-page');
      expect(qp['limit'], 10);
    });
  });

  group('BillingApi.getOrder', () {
    String orderJson({
      String id = 'ord-1',
      String state = 'paid',
      String provider = 'payme',
    }) =>
        jsonEncode(<String, dynamic>{
          'id': id,
          'plan_code': 'parent_pro',
          'amount_tiyin': 3900000,
          'amount_uzs': 39000,
          'state': state,
          'provider': provider,
          'created_at': '2025-06-10T12:00:00Z',
          'paid_at': state == 'paid' ? '2025-06-10T12:01:00Z' : null,
        });

    test('returns null when given an empty id without hitting the network',
        () async {
      final adapter = _ScriptedAdapter([]);
      final api = BillingApi(_dio(adapter));

      final result = await api.getOrder('');

      expect(result, isNull);
      expect(adapter.calls, isEmpty);
    });

    test('parses a single order via the canonical detail route',
        () async {
      final adapter = _ScriptedAdapter([
        _ScriptedResponse(200, orderJson(id: 'ord-1')),
      ]);
      final api = BillingApi(_dio(adapter));

      final order = await api.getOrder('ord-1');

      expect(order, isNotNull);
      expect(order!.id, 'ord-1');
      expect(order.isPaid, isTrue);
      expect(adapter.calls.single.path, '/billing/orders/ord-1');
    });

    test(
        'falls back to a list scan when the detail route returns 404 '
        '(legacy API revision without /billing/orders/{id})', () async {
      final detailOptions = RequestOptions(path: '/billing/orders/ord-9');
      final adapter = _ScriptedAdapter([
        _notFound(detailOptions),
        _ScriptedResponse(
          200,
          jsonEncode(<String, dynamic>{
            'items': <Map<String, dynamic>>[
              jsonDecode(orderJson(id: 'ord-9')) as Map<String, dynamic>,
            ],
            'has_more': false,
          }),
        ),
      ]);
      final api = BillingApi(_dio(adapter));

      final order = await api.getOrder('ord-9');

      expect(order, isNotNull);
      expect(order!.id, 'ord-9');
      // Two calls: failed detail probe + list scan fallback.
      expect(adapter.calls, hasLength(2));
      expect(adapter.calls.first.path, '/billing/orders/ord-9');
      expect(adapter.calls.last.path, '/billing/orders');
    });

    test(
        'returns null when the order is not in the list-scan fallback either',
        () async {
      final detailOptions = RequestOptions(path: '/billing/orders/missing');
      final adapter = _ScriptedAdapter([
        _notFound(detailOptions),
        _ScriptedResponse(
          200,
          jsonEncode(<String, dynamic>{
            'items': <Map<String, dynamic>>[],
            'has_more': false,
          }),
        ),
      ]);
      final api = BillingApi(_dio(adapter));

      final order = await api.getOrder('missing');

      expect(order, isNull);
    });

    test('rethrows on a 5xx error so the caller can surface a retry state',
        () async {
      final options = RequestOptions(path: '/billing/orders/ord-bad');
      final adapter = _ScriptedAdapter([
        DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 500,
          ),
          type: DioExceptionType.badResponse,
        ),
      ]);
      final api = BillingApi(_dio(adapter));

      expect(api.getOrder('ord-bad'), throwsA(isA<DioException>()));
    });
  });
}
