import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/api/billing_interceptor.dart';

/// Minimal scripted adapter mirroring the pattern from
/// `test/data/api/auth_interceptor_test.dart`.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._steps);
  final List<Object> _steps;
  int _idx = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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
    return step as ResponseBody;
  }
}

ResponseBody _paymentRequired(String body) {
  return ResponseBody.fromString(
    body,
    402,
    headers: {
      'content-type': ['application/json'],
    },
  );
}

ResponseBody _ok() {
  return ResponseBody.fromString(
    '{"ok":true}',
    200,
    headers: {
      'content-type': ['application/json'],
    },
  );
}

void main() {
  group('PlanLimitNotice.fromResponseData', () {
    test('parses the canonical envelope shape with extra metric/limit', () {
      final notice = PlanLimitNotice.fromResponseData({
        'detail': 'PLAN_LIMIT_EXCEEDED',
        'extra': {'metric': 'exercises_per_day', 'limit': 3},
      });
      expect(notice, isNotNull);
      expect(notice!.metric, 'exercises_per_day');
      expect(notice.limit, 3);
      expect(notice.message, 'PLAN_LIMIT_EXCEEDED');
    });

    test('accepts a flat metric/limit shape without an extra wrapper', () {
      final notice = PlanLimitNotice.fromResponseData({
        'metric': 'ai_analysis',
        'limit': 5,
      });
      expect(notice, isNotNull);
      expect(notice!.metric, 'ai_analysis');
      expect(notice.limit, 5);
    });

    test('returns null on a body without a metric token', () {
      expect(
        PlanLimitNotice.fromResponseData({'detail': 'something else'}),
        isNull,
      );
    });

    test('returns null on a non-map payload', () {
      expect(PlanLimitNotice.fromResponseData('plain string'), isNull);
      expect(PlanLimitNotice.fromResponseData(null), isNull);
    });

    test('coerces a missing limit field to 0', () {
      final notice = PlanLimitNotice.fromResponseData({
        'extra': {'metric': 'children_total'},
      });
      expect(notice!.limit, 0);
    });
  });

  group('BillingInterceptor', () {
    test('fires the callback with a parsed notice on a 402', () async {
      final notices = <PlanLimitNotice>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _ScriptedAdapter([
        _paymentRequired(
          '{"detail":"limit","extra":{"metric":"exercises_per_day","limit":3}}',
        ),
      ]);
      dio.interceptors.add(BillingInterceptor(onPlanLimit: notices.add));

      Object? thrown;
      try {
        await dio.get('/exercises');
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<DioException>());
      expect(notices, hasLength(1));
      expect(notices.single.metric, 'exercises_per_day');
      expect(notices.single.limit, 3);
    });

    test('ignores non-402 errors', () async {
      final notices = <PlanLimitNotice>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _ScriptedAdapter([
        ResponseBody.fromString(
          '{"detail":"server"}',
          500,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      ]);
      dio.interceptors.add(BillingInterceptor(onPlanLimit: notices.add));

      Object? thrown;
      try {
        await dio.get('/whatever');
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<DioException>());
      expect(notices, isEmpty);
    });

    test('forwards a generic notice when the 402 body is unparseable',
        () async {
      final notices = <PlanLimitNotice>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _ScriptedAdapter([
        _paymentRequired('"plain text payload"'),
      ]);
      dio.interceptors.add(BillingInterceptor(onPlanLimit: notices.add));

      try {
        await dio.get('/exercises');
      } on DioException catch (_) {/* expected */}
      expect(notices, hasLength(1));
      expect(notices.single.metric, 'unknown');
      expect(notices.single.limit, 0);
    });

    test('does nothing on success responses', () async {
      final notices = <PlanLimitNotice>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _ScriptedAdapter([_ok()]);
      dio.interceptors.add(BillingInterceptor(onPlanLimit: notices.add));

      final res = await dio.get('/ping');
      expect(res.statusCode, 200);
      expect(notices, isEmpty);
    });

    test('listener exceptions never mask the original DioException',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _ScriptedAdapter([
        _paymentRequired(
          '{"extra":{"metric":"ai_analysis","limit":5}}',
        ),
      ]);
      dio.interceptors.add(BillingInterceptor(
        onPlanLimit: (_) => throw StateError('boom'),
      ));

      Object? thrown;
      try {
        await dio.get('/something');
      } catch (e) {
        thrown = e;
      }
      // The original DioException must still propagate even though the
      // listener threw — otherwise per-call sites can't show their own
      // inline error UI.
      expect(thrown, isA<DioException>());
      expect((thrown as DioException).response?.statusCode, 402);
    });
  });
}
