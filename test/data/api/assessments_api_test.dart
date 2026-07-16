import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/api/assessments_api.dart';

class _Captured {
  String? method;
  String? path;
  Map<String, dynamic>? query;
  dynamic body;
  String? contentType;
}

Dio _stubDio({
  required _Captured captured,
  required Object response,
  int statusCode = 200,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      captured
        ..method = options.method
        ..path = options.path
        ..query = Map<String, dynamic>.from(options.queryParameters)
        ..body = options.data
        ..contentType = options.contentType;
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: statusCode,
        data: response,
      ));
    },
  ));
  return dio;
}

Map<String, dynamic> _assessmentJson({
  String id = 'asm-1',
  String childId = 'child-1',
  String? exerciseId = 'ex-1',
  String status = 'completed',
  String? overallRisk = 'green',
  double? score = 0.82,
}) =>
    {
      'id': id,
      'child_id': childId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      'status': status,
      if (overallRisk != null) 'overall_risk': overallRisk,
      if (score != null) 'score': score,
      'created_at': '2024-06-01T12:30:00Z',
    };

void main() {
  group('AssessmentsApi', () {
    test('list with no filter issues GET /assessments with empty query',
        () async {
      final cap = _Captured();
      final api = AssessmentsApi(_stubDio(
        captured: cap,
        response: {
          'items': [_assessmentJson()],
          'next_cursor': null,
          'has_more': false,
        },
      ));

      final res = await api.list();

      expect(cap.method, 'GET');
      expect(cap.path, '/assessments');
      // child_id must NOT appear on the wire when the caller didn't filter.
      expect(cap.query?.containsKey('child_id'), isFalse);
      expect(res.items.single.id, 'asm-1');
      expect(res.hasMore, isFalse);
    });

    test('list with childId scopes the query to that child', () async {
      final cap = _Captured();
      final api = AssessmentsApi(_stubDio(
        captured: cap,
        response: {
          'items': [_assessmentJson(childId: 'child-7')],
          'has_more': false,
        },
      ));

      final res = await api.list(childId: 'child-7');

      expect(cap.query?['child_id'], 'child-7');
      expect(res.items.single.childId, 'child-7');
    });

    test('list parses the score as a double even when the wire sends an int',
        () async {
      final cap = _Captured();
      final api = AssessmentsApi(_stubDio(
        captured: cap,
        response: {
          'items': [
            {
              ..._assessmentJson(),
              // Some responses serialize 1.0 as `1` — the model must handle it.
              'score': 1,
            },
          ],
          'has_more': false,
        },
      ));

      final res = await api.list();

      expect(res.items.single.score, 1.0);
      expect(res.items.single.score, isA<double>());
    });

    test('list tolerates missing optional fields (null score / risk)',
        () async {
      final cap = _Captured();
      final api = AssessmentsApi(_stubDio(
        captured: cap,
        response: {
          'items': [
            _assessmentJson(
              status: 'pending',
              overallRisk: null,
              score: null,
              exerciseId: null,
            ),
          ],
          'has_more': false,
        },
      ));

      final res = await api.list();
      final a = res.items.single;

      expect(a.status, 'pending');
      expect(a.overallRisk, isNull);
      expect(a.score, isNull);
      expect(a.exerciseId, isNull);
    });

    test('get fetches a single assessment by id', () async {
      final cap = _Captured();
      final api = AssessmentsApi(_stubDio(
        captured: cap,
        response: _assessmentJson(id: 'asm-42'),
      ));

      final a = await api.get('asm-42');

      expect(cap.method, 'GET');
      expect(cap.path, '/assessments/asm-42');
      expect(a.id, 'asm-42');
    });

    test('create without audio still posts the required FormData fields',
        () async {
      // The create() multipart helper is harder to inspect than a JSON
      // body — but we can at least verify that the `child_id` and
      // `exercise_id` fields make it through, that the request hits
      // POST /assessments, and that the `audio` part is omitted when
      // the caller didn't supply a path.
      final cap = _Captured();
      final api = AssessmentsApi(_stubDio(
        captured: cap,
        response: _assessmentJson(),
      ));

      await api.create(childId: 'child-3', exerciseId: 'ex-9');

      expect(cap.method, 'POST');
      expect(cap.path, '/assessments');
      final body = cap.body;
      expect(body, isA<FormData>());
      final form = body as FormData;
      final fieldMap = {for (final f in form.fields) f.key: f.value};
      expect(fieldMap['child_id'], 'child-3');
      expect(fieldMap['exercise_id'], 'ex-9');
      // No audio path supplied → no `audio` multipart file.
      expect(form.files, isEmpty);
    });
  });
}
