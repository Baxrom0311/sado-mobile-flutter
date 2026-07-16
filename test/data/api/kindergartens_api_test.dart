import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/api/kindergartens_api.dart';

class _Captured {
  String? method;
  String? path;
  Map<String, dynamic>? query;
}

Dio _stubDio({
  required _Captured captured,
  required Map<String, dynamic> response,
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
        statusCode: 200,
        data: response,
      ));
    },
  ));
  return dio;
}

Map<String, dynamic> _kindergartenJson({
  String id = 'kg-1',
  String name = 'MTM #1',
  String? address = 'Toshkent shahri',
}) =>
    {
      'id': id,
      'name': name,
      if (address != null) 'address': address,
    };

void main() {
  group('KindergartensApi', () {
    test('list passes the trimmed query as `q`', () async {
      final cap = _Captured();
      final api = KindergartensApi(_stubDio(
        captured: cap,
        response: {
          'items': [_kindergartenJson(name: 'Quyosh bog\'chasi')],
          'next_cursor': null,
          'has_more': false,
        },
      ));

      final res = await api.list(query: '  quyosh  ', limit: 30);

      expect(cap.method, 'GET');
      expect(cap.path, '/kindergartens');
      expect(cap.query?['q'], 'quyosh');
      expect(cap.query?['limit'], 30);
      expect(res.items, hasLength(1));
      expect(res.items.first.name, 'Quyosh bog\'chasi');
      expect(res.hasMore, isFalse);
    });

    test('list omits empty / whitespace-only queries from the wire',
        () async {
      final cap = _Captured();
      final api = KindergartensApi(_stubDio(
        captured: cap,
        response: const {
          'items': [],
          'next_cursor': null,
          'has_more': false,
        },
      ));

      await api.list(query: '   ');

      // Whitespace-only queries should NOT be sent — otherwise the API would
      // return zero results for any user who hasn't started typing yet.
      expect(cap.query?.containsKey('q'), isFalse);
    });

    test('list propagates region filter and cursor', () async {
      final cap = _Captured();
      final api = KindergartensApi(_stubDio(
        captured: cap,
        response: const {
          'items': [],
          'next_cursor': 'next-page',
          'has_more': true,
        },
      ));

      final res = await api.list(
        regionId: 'region-7',
        cursor: 'page-2',
      );

      expect(cap.query?['region_id'], 'region-7');
      expect(cap.query?['cursor'], 'page-2');
      expect(res.nextCursor, 'next-page');
      expect(res.hasMore, isTrue);
    });

    test('get fetches a single kindergarten by id', () async {
      final cap = _Captured();
      final api = KindergartensApi(_stubDio(
        captured: cap,
        response: _kindergartenJson(id: 'kg-42', name: 'Bahor MTM'),
      ));

      final k = await api.get('kg-42');

      expect(cap.method, 'GET');
      expect(cap.path, '/kindergartens/kg-42');
      expect(k.id, 'kg-42');
      expect(k.name, 'Bahor MTM');
    });

    test('list parses items with missing optional fields', () async {
      final cap = _Captured();
      final api = KindergartensApi(_stubDio(
        captured: cap,
        response: {
          'items': [
            // No address, no region — both nullable on the model.
            {'id': 'kg-9', 'name': 'Yulduzcha'},
          ],
          'has_more': false,
        },
      ));

      final res = await api.list();

      expect(res.items.first.name, 'Yulduzcha');
      expect(res.items.first.address, isNull);
      expect(res.items.first.regionId, isNull);
    });
  });
}
