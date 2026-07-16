import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/api/children_api.dart';

/// Captures the most recent request the API issued so we can assert on
/// method + path + body. We don't use a real network — we install a Dio
/// interceptor that short-circuits every request.
class _CapturedRequest {
  String? method;
  String? path;
  Map<String, dynamic>? body;
}

Dio _stubDio({
  required _CapturedRequest captured,
  Map<String, dynamic>? response,
  int statusCode = 200,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      captured
        ..method = options.method
        ..path = options.path
        ..body = options.data is Map<String, dynamic>
            ? Map<String, dynamic>.from(options.data as Map<String, dynamic>)
            : null;
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: statusCode,
        data: response ?? const <String, dynamic>{},
      ));
    },
  ));
  return dio;
}

Map<String, dynamic> _childPayload({
  String name = 'Aziz',
  String birthDate = '2019-04-01',
  String gender = 'male',
}) =>
    {
      'id': 'child-1',
      'name': name,
      'birth_date': birthDate,
      'gender': gender,
      'parent_id': 'parent-1',
      'created_at': '2024-01-01T00:00:00Z',
    };

void main() {
  group('ChildrenApi', () {
    test('patch sends only the supplied fields', () async {
      final captured = _CapturedRequest();
      final api = ChildrenApi(_stubDio(
        captured: captured,
        response: _childPayload(name: 'Aziza', gender: 'female'),
      ));

      final updated = await api.patch(
        'child-1',
        name: 'Aziza',
        gender: 'female',
      );

      expect(captured.method, 'PUT');
      expect(captured.path, '/children/child-1');
      // Only the provided keys should be on the wire — birth_date / kindergarten_id
      // must not be sent when they're null.
      expect(captured.body, {'name': 'Aziza', 'gender': 'female'});
      expect(updated.name, 'Aziza');
      expect(updated.gender, 'female');
    });

    test('patch with all nulls sends an empty body', () async {
      final captured = _CapturedRequest();
      final api = ChildrenApi(_stubDio(
        captured: captured,
        response: _childPayload(),
      ));

      await api.patch('child-1');

      expect(captured.method, 'PUT');
      expect(captured.body, isEmpty);
    });

    test('delete issues DELETE /children/{id}', () async {
      final captured = _CapturedRequest();
      final api = ChildrenApi(_stubDio(
        captured: captured,
        response: const <String, dynamic>{},
      ));

      await api.delete('child-7');

      expect(captured.method, 'DELETE');
      expect(captured.path, '/children/child-7');
    });

    test('create sends required fields', () async {
      final captured = _CapturedRequest();
      final api = ChildrenApi(_stubDio(
        captured: captured,
        response: _childPayload(),
      ));

      await api.create(
        name: 'Aziz',
        birthDate: '2019-04-01',
        gender: 'male',
      );

      expect(captured.method, 'POST');
      expect(captured.path, '/children');
      expect(captured.body, {
        'name': 'Aziz',
        'birth_date': '2019-04-01',
        'gender': 'male',
      });
    });
  });
}
