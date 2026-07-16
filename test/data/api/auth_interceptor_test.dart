import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/api/api_client.dart';

/// Minimal mock that replays a queued response or error per request.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._steps);

  final List<Object> _steps; // either ResponseBody or DioException
  int _idx = 0;
  final calledPaths = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calledPaths.add(options.path);
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

ResponseBody _ok(Map<String, dynamic> body) {
  return ResponseBody.fromString(
    '{${body.entries.map((e) => '"${e.key}":"${e.value}"').join(',')}}',
    200,
    headers: {
      'content-type': ['application/json'],
    },
  );
}

ResponseBody _unauthorized() {
  return ResponseBody.fromString(
    '{"detail":"unauth"}',
    401,
    headers: {
      'content-type': ['application/json'],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Stub the flutter_secure_storage method channel so the interceptor's
  // calls to getAccessToken / getRefreshToken complete without a platform.
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'read':
        case 'readAll':
          return null;
        case 'write':
        case 'delete':
        case 'deleteAll':
        case 'containsKey':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('AuthInterceptor', () {
    test('fires onSessionExpired when refresh response is 401', () async {
      // No tokens stored: the interceptor will hit the early-return path
      // ("no refresh token") and call onSessionExpired immediately.
      var expired = 0;

      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _ScriptedAdapter([_unauthorized()]);
      dio.interceptors.add(AuthInterceptor(
        dio: dio,
        onSessionExpired: () => expired++,
      ));

      Object? thrown;
      try {
        await dio.get('/whatever');
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<DioException>());
      expect(expired, 1);
    });

    test('does not fire when request succeeds', () async {
      var expired = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _ScriptedAdapter([
        _ok({'ok': 'true'}),
      ]);
      dio.interceptors.add(AuthInterceptor(
        dio: dio,
        onSessionExpired: () => expired++,
      ));

      final res = await dio.get('/ping');
      expect(res.statusCode, 200);
      expect(expired, 0);
    });
  });
}
