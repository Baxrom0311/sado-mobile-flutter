import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/api/billing_api.dart';
import 'package:sado_mobile/data/models/subscription_plan.dart';

/// Reused scripted Dio adapter — mirrors the helper in
/// `billing_api_test.dart` so usage-specific assertions can stay
/// focused on the behaviour we care about.
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
  group('UsageMetric', () {
    test('parses a typical paginated metric envelope', () {
      final m = UsageMetric.fromJson(<String, dynamic>{
        'metric': 'assessments_per_day',
        'limit': 3,
        'used': 2,
        'remaining': 1,
        'period_end': '2025-06-13T00:00:00Z',
      });
      expect(m.metric, 'assessments_per_day');
      expect(m.limit, 3);
      expect(m.used, 2);
      expect(m.remaining, 1);
      expect(m.periodEnd, isNotNull);
      expect(m.isUnlimited, isFalse);
      expect(m.isExhausted, isFalse);
      expect(m.progress, closeTo(2 / 3, 1e-9));
    });

    test('treats negative limit as unlimited and progress as 0', () {
      const m = UsageMetric(metric: 'ai_analysis', limit: -1, used: 12);
      expect(m.isUnlimited, isTrue);
      expect(m.isExhausted, isFalse);
      expect(m.progress, 0);
    });

    test('isExhausted flips at the cap and clamps progress to 1', () {
      const m = UsageMetric(metric: 'children_total', limit: 1, used: 5);
      expect(m.isExhausted, isTrue);
      expect(m.progress, 1);
    });

    test('synthesises remaining when API omits it', () {
      final m = UsageMetric.fromJson(<String, dynamic>{
        'metric': 'children_total',
        'limit': 5,
        'used': 2,
      });
      expect(m.remaining, 3);
    });

    test('accepts legacy `count` alias for used', () {
      final m = UsageMetric.fromJson(<String, dynamic>{
        'metric': 'assessments_per_day',
        'limit': 3,
        'count': 2,
      });
      expect(m.used, 2);
      expect(m.remaining, 1);
    });

    test('parses `resets_at` as a fallback for the period boundary', () {
      final m = UsageMetric.fromJson(<String, dynamic>{
        'metric': 'assessments_per_day',
        'limit': 3,
        'used': 1,
        'resets_at': '2025-06-14T00:00:00Z',
      });
      expect(m.periodEnd, isNotNull);
      expect(m.periodEnd!.year, 2025);
      expect(m.periodEnd!.month, 6);
      expect(m.periodEnd!.day, 14);
    });

    test('value equality + hashCode round-trip', () {
      const a = UsageMetric(
        metric: 'assessments_per_day',
        limit: 3,
        used: 2,
        remaining: 1,
      );
      const b = UsageMetric(
        metric: 'assessments_per_day',
        limit: 3,
        used: 2,
        remaining: 1,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('SubscriptionUsage', () {
    test('parses the canonical {metrics: [...]} envelope', () {
      final usage = SubscriptionUsage.fromJson(<String, dynamic>{
        'period_start': '2025-06-13T00:00:00Z',
        'period_end': '2025-06-14T00:00:00Z',
        'plan_code': 'free',
        'enforced': true,
        'metrics': [
          <String, dynamic>{
            'metric': 'assessments_per_day',
            'limit': 3,
            'used': 2,
          },
          <String, dynamic>{
            'metric': 'children_total',
            'limit': 1,
            'used': 1,
          },
        ],
      });
      expect(usage.metrics, hasLength(2));
      expect(usage.planCode, 'free');
      expect(usage.enforced, isTrue);
      expect(usage.periodStart, isNotNull);
      expect(usage.periodEnd, isNotNull);
      expect(usage.metric('assessments_per_day')?.used, 2);
      expect(usage.metric('children_total')?.isExhausted, isTrue);
      expect(usage.metric('does_not_exist'), isNull);
    });

    test('parses inlined `{metric_token: {...}}` map shape', () {
      final usage = SubscriptionUsage.fromJson(<String, dynamic>{
        'metrics': <String, dynamic>{
          'assessments_per_day': <String, dynamic>{
            'limit': 3,
            'used': 1,
          },
          'ai_analysis': <String, dynamic>{
            'limit': -1,
            'used': 42,
          },
        },
      });
      expect(usage.metrics, hasLength(2));
      expect(usage.metric('ai_analysis')?.isUnlimited, isTrue);
    });

    test('returns empty when the metrics field is missing', () {
      final usage = SubscriptionUsage.fromJson(<String, dynamic>{});
      expect(usage.isEmpty, isTrue);
    });
  });

  group('BillingApi.usage', () {
    test('returns an empty record on a network error', () async {
      final adapter = _ScriptedAdapter([
        DioException(
          requestOptions: RequestOptions(path: '/billing/usage'),
          type: DioExceptionType.connectionError,
        ),
      ]);
      final api = BillingApi(_dio(adapter));
      final usage = await api.usage();
      expect(usage.isEmpty, isTrue);
    });

    test('parses the live wire format', () async {
      final body = jsonEncode(<String, dynamic>{
        'period_start': '2025-06-13T00:00:00Z',
        'period_end': '2025-06-14T00:00:00Z',
        'metrics': [
          <String, dynamic>{
            'metric': 'assessments_per_day',
            'limit': 3,
            'used': 2,
            'remaining': 1,
          },
        ],
      });
      final adapter = _ScriptedAdapter([_ScriptedResponse(200, body)]);
      final api = BillingApi(_dio(adapter));
      final usage = await api.usage();
      expect(usage.metrics, hasLength(1));
      expect(usage.metrics.single.used, 2);
      expect(adapter.calls.single.path, '/billing/usage');
    });

    test('falls through to the legacy `/subscription/usage` path', () async {
      final body = jsonEncode(<String, dynamic>{
        'metrics': [
          <String, dynamic>{
            'metric': 'children_total',
            'limit': 1,
            'used': 0,
          },
        ],
      });
      final adapter = _ScriptedAdapter([
        _notFound(RequestOptions(path: '/billing/usage')),
        _ScriptedResponse(200, body),
      ]);
      final api = BillingApi(_dio(adapter));
      final usage = await api.usage();
      expect(usage.metrics, hasLength(1));
      expect(adapter.calls.map((c) => c.path), [
        '/billing/usage',
        '/billing/subscription/usage',
      ]);
    });

    test('returns empty when every candidate path 404s', () async {
      final adapter = _ScriptedAdapter([
        _notFound(RequestOptions(path: '/billing/usage')),
        _notFound(RequestOptions(path: '/billing/subscription/usage')),
        _notFound(RequestOptions(path: '/subscriptions/usage')),
      ]);
      final api = BillingApi(_dio(adapter));
      final usage = await api.usage();
      expect(usage.isEmpty, isTrue);
    });
  });
}
