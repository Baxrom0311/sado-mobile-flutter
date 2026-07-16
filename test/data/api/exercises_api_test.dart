import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/api/exercises_api.dart';

/// Captures the wire-level details of a single Dio request so we can
/// assert on method + path + query without standing up a real server.
class _Captured {
  String? method;
  String? path;
  Map<String, dynamic>? query;
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
        ..query = Map<String, dynamic>.from(options.queryParameters);
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: statusCode,
        data: response,
      ));
    },
  ));
  return dio;
}

Map<String, dynamic> _exerciseJson({
  String id = 'ex-1',
  String title = 'A-A-A',
  String category = 'articulation',
  String ageGroup = '4-5',
  String difficulty = 'easy',
  int durationMinutes = 5,
}) =>
    {
      'id': id,
      'title': title,
      'description': 'Tovushni mashq qilamiz',
      'category': category,
      'age_group': ageGroup,
      'difficulty': difficulty,
      'language': 'uz',
      'duration_minutes': durationMinutes,
      'is_active': true,
    };

void main() {
  group('ExercisesApi', () {
    test('list with no filters issues GET /exercises with empty query',
        () async {
      final cap = _Captured();
      final api = ExercisesApi(_stubDio(
        captured: cap,
        response: {
          'items': [_exerciseJson()],
          'next_cursor': null,
          'has_more': false,
        },
      ));

      final res = await api.list();

      expect(cap.method, 'GET');
      expect(cap.path, '/exercises');
      // None of the optional filters should appear on the wire when null —
      // otherwise the API would receive `category=null` literally.
      expect(cap.query, isEmpty);
      expect(res.items, hasLength(1));
      expect(res.hasMore, isFalse);
      expect(res.nextCursor, isNull);
    });

    test('list propagates category, age_group and cursor', () async {
      final cap = _Captured();
      final api = ExercisesApi(_stubDio(
        captured: cap,
        response: {
          'items': [
            _exerciseJson(category: 'breathing', ageGroup: '5-6'),
          ],
          'next_cursor': 'page-2',
          'has_more': true,
        },
      ));

      final res = await api.list(
        category: 'breathing',
        ageGroup: '5-6',
        cursor: 'page-1',
      );

      expect(cap.query?['category'], 'breathing');
      expect(cap.query?['age_group'], '5-6');
      expect(cap.query?['cursor'], 'page-1');
      expect(res.nextCursor, 'page-2');
      expect(res.hasMore, isTrue);
      expect(res.items.first.category, 'breathing');
      expect(res.items.first.ageGroup, '5-6');
    });

    test('list propagates difficulty filter to the wire', () async {
      final cap = _Captured();
      final api = ExercisesApi(_stubDio(
        captured: cap,
        response: {
          'items': [_exerciseJson(difficulty: 'medium')],
          'has_more': false,
        },
      ));

      await api.list(difficulty: 'medium');

      expect(cap.query?['difficulty'], 'medium');
      // No other filter should leak through when only difficulty was set.
      expect(cap.query?.containsKey('category'), isFalse);
      expect(cap.query?.containsKey('age_group'), isFalse);
    });

    test('list omits the difficulty key entirely when null is passed',
        () async {
      final cap = _Captured();
      final api = ExercisesApi(_stubDio(
        captured: cap,
        response: {
          'items': const [],
          'has_more': false,
        },
      ));

      await api.list(category: 'fluency');

      expect(cap.query?['category'], 'fluency');
      // The API treats a missing `difficulty` key as "any". Sending the
      // literal string "null" would scope the query to a non-existent
      // bucket, so we must not serialise it at all.
      expect(cap.query?.containsKey('difficulty'), isFalse);
    });

    test('list defaults has_more to false when the field is missing',
        () async {
      final cap = _Captured();
      final api = ExercisesApi(_stubDio(
        captured: cap,
        response: {
          'items': [_exerciseJson()],
          // No has_more — older deployments may omit it.
        },
      ));

      final res = await api.list();

      expect(res.hasMore, isFalse);
    });

    test('list parses optional fields including a phoneme array '
        '(modern wire format)', () async {
      final cap = _Captured();
      final api = ExercisesApi(_stubDio(
        captured: cap,
        response: {
          'items': [
            {
              ..._exerciseJson(),
              'audio_example_path': '/storage/example.m4a',
              'image_path': '/storage/cover.png',
              'instructions': 'Bolaga tovushni takrorlatish',
              // Backend stores `target_phonemes` as Postgres TEXT[] which
              // serialises to a JSON array. The model must accept this
              // shape natively.
              'target_phonemes': ['a', 'o'],
            },
          ],
          'has_more': false,
        },
      ));

      final res = await api.list();
      final ex = res.items.single;

      expect(ex.audioExamplePath, '/storage/example.m4a');
      expect(ex.imagePath, '/storage/cover.png');
      expect(ex.instructions, contains('takror'));
      expect(ex.targetPhonemes, ['a', 'o']);
    });

    test('list also tolerates the legacy comma-separated phoneme string '
        'so older API revisions / cached payloads keep working',
        () async {
      final api = ExercisesApi(_stubDio(
        captured: _Captured(),
        response: {
          'items': [
            {
              ..._exerciseJson(),
              'target_phonemes': 'a, o, u',
            },
          ],
          'has_more': false,
        },
      ));

      final res = await api.list();

      expect(res.items.single.targetPhonemes, ['a', 'o', 'u']);
    });

    test('get fetches a single exercise by id', () async {
      final cap = _Captured();
      final api = ExercisesApi(_stubDio(
        captured: cap,
        response: _exerciseJson(id: 'ex-42', title: 'O-O-O'),
      ));

      final ex = await api.get('ex-42');

      expect(cap.method, 'GET');
      expect(cap.path, '/exercises/ex-42');
      expect(ex.id, 'ex-42');
      expect(ex.title, 'O-O-O');
    });
  });
}
