import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/api/auth_api.dart';

class _Captured {
  String? method;
  String? path;
  dynamic body;
  Map<String, dynamic> extra = const {};
}

/// Stub Dio that records every request and replays a queued response.
/// Use [responses] to script multi-step flows (e.g. PATCH-fails-then-PUT).
Dio _stubDio({
  required _Captured captured,
  required List<_StubReply> responses,
}) {
  var i = 0;
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      // Capture the *latest* request — the assertions look at the final one
      // unless the test queues replies that record themselves explicitly.
      captured
        ..method = options.method
        ..path = options.path
        ..body = options.data
        ..extra = Map<String, dynamic>.from(options.extra);

      if (i >= responses.length) {
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 500,
            ),
          ),
        );
        return;
      }

      final reply = responses[i++];
      if (reply.error != null) {
        handler.reject(DioException(
          requestOptions: options,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: reply.error,
          ),
        ));
        return;
      }
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: reply.statusCode,
        data: reply.data,
      ));
    },
  ));
  return dio;
}

class _StubReply {
  const _StubReply.ok(this.data, {this.statusCode = 200}) : error = null;
  const _StubReply.fail(int status)
      : data = null,
        statusCode = status,
        error = status;
  final Object? data;
  final int statusCode;
  final int? error;
}

// statusCode is referenced via the `_StubReply.ok(..., statusCode: …)` ctor
// — the analyzer sees it as unused because no test currently overrides the
// default 200, so we silence the unused_element_parameter lint here.
// ignore_for_file: unused_element_parameter

Map<String, dynamic> _userJson({
  String id = 'user-1',
  String fullName = 'Hilola',
  String role = 'parent',
  String language = 'uz',
}) =>
    {
      'id': id,
      'email': 'parent@sado.uz',
      'full_name': fullName,
      'role': role,
      'language': language,
      'is_active': true,
      'is_verified': true,
      'created_at': '2024-01-01T00:00:00Z',
    };

void main() {
  group('AuthApi', () {
    test('login posts credentials anonymously and parses the token pair',
        () async {
      final cap = _Captured();
      final api = AuthApi(_stubDio(
        captured: cap,
        responses: [
          _StubReply.ok(const {
            'access_token': 'A',
            'refresh_token': 'R',
            'expires_in': 3600,
          }),
        ],
      ));

      final tokens = await api.login(
        email: 'parent@sado.uz',
        password: 'demo1234',
      );

      expect(cap.method, 'POST');
      expect(cap.path, '/auth/login');
      // The interceptor must skip the auth header for the login call.
      expect(cap.extra['anonymous'], isTrue);
      expect(cap.body, {
        'email': 'parent@sado.uz',
        'password': 'demo1234',
      });
      expect(tokens.accessToken, 'A');
      expect(tokens.refreshToken, 'R');
      expect(tokens.expiresIn, 3600);
    });

    test('register sends snake_case full_name + role and is anonymous',
        () async {
      final cap = _Captured();
      final api = AuthApi(_stubDio(
        captured: cap,
        responses: [_StubReply.ok(_userJson(role: 'teacher'))],
      ));

      final user = await api.register(
        email: 'teacher@sado.uz',
        password: 'demo1234',
        fullName: 'Hilola Karimova',
        role: 'teacher',
      );

      expect(cap.path, '/auth/register');
      expect(cap.extra['anonymous'], isTrue);
      expect(cap.body, {
        'email': 'teacher@sado.uz',
        'password': 'demo1234',
        'full_name': 'Hilola Karimova',
        'role': 'teacher',
      });
      expect(user.role, 'teacher');
    });

    test('refresh sends the refresh_token anonymously', () async {
      final cap = _Captured();
      final api = AuthApi(_stubDio(
        captured: cap,
        responses: [
          _StubReply.ok(const {
            'access_token': 'A2',
            'refresh_token': 'R2',
            'expires_in': 3600,
          }),
        ],
      ));

      final tokens = await api.refresh('R1');

      expect(cap.path, '/auth/refresh');
      expect(cap.extra['anonymous'], isTrue);
      expect(cap.body, {'refresh_token': 'R1'});
      expect(tokens.accessToken, 'A2');
    });

    test('me fetches /users/me and parses the user', () async {
      final cap = _Captured();
      final api = AuthApi(_stubDio(
        captured: cap,
        responses: [_StubReply.ok(_userJson(fullName: 'Hilola'))],
      ));

      final user = await api.me();

      expect(cap.method, 'GET');
      expect(cap.path, '/users/me');
      expect(user.fullName, 'Hilola');
    });

    test('updateProfile with no fields short-circuits to GET /users/me',
        () async {
      // When the caller passes nothing to update we should not issue a
      // PATCH/PUT — that would either fail validation or wipe fields.
      final cap = _Captured();
      final api = AuthApi(_stubDio(
        captured: cap,
        responses: [_StubReply.ok(_userJson())],
      ));

      final user = await api.updateProfile();

      expect(cap.method, 'GET');
      expect(cap.path, '/users/me');
      expect(user.email, 'parent@sado.uz');
    });

    test('updateProfile sends only supplied fields via PATCH /users/me',
        () async {
      final cap = _Captured();
      final api = AuthApi(_stubDio(
        captured: cap,
        responses: [
          _StubReply.ok(_userJson(fullName: 'Hilola K.', language: 'ru')),
        ],
      ));

      final user = await api.updateProfile(
        fullName: 'Hilola K.',
        language: 'ru',
      );

      expect(cap.method, 'PATCH');
      expect(cap.path, '/users/me');
      expect(cap.body, {'full_name': 'Hilola K.', 'language': 'ru'});
      expect(user.language, 'ru');
    });

    test('updateProfile falls back to PUT when the server replies 405',
        () async {
      // First call (PATCH) → 405. Then we expect the API to retry as a
      // PUT to the same path with the same body.
      final cap = _Captured();
      final api = AuthApi(_stubDio(
        captured: cap,
        responses: [
          const _StubReply.fail(405),
          _StubReply.ok(_userJson(fullName: 'Hilola K.')),
        ],
      ));

      final user = await api.updateProfile(fullName: 'Hilola K.');

      // The captured request reflects the *last* call, which should be PUT.
      expect(cap.method, 'PUT');
      expect(cap.path, '/users/me');
      expect(cap.body, {'full_name': 'Hilola K.'});
      expect(user.fullName, 'Hilola K.');
    });

    test('updateProfile rethrows on non-recoverable PATCH errors', () async {
      final cap = _Captured();
      final api = AuthApi(_stubDio(
        captured: cap,
        responses: [const _StubReply.fail(403)],
      ));

      await expectLater(
        api.updateProfile(fullName: 'X'),
        throwsA(isA<DioException>()),
      );
      // We did NOT fall back to PUT for a 403 — only 404/405 trigger that.
      expect(cap.method, 'PATCH');
    });
  });
}
