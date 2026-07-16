import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/api/notifications_api.dart';

class _Captured {
  String? method;
  String? path;
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
        ..path = options.path;
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: statusCode,
        data: response,
      ));
    },
  ));
  return dio;
}

Map<String, dynamic> _notificationJson({
  String id = 'n-1',
  String title = 'Yangi natija',
  String body = 'Aziz mashqni tugatdi',
  bool isRead = false,
}) =>
    {
      'id': id,
      'title': title,
      'body': body,
      'is_read': isRead,
      'created_at': '2024-06-01T10:00:00Z',
    };

void main() {
  group('NotificationsApi', () {
    test('list issues GET /notifications and parses the paginated payload',
        () async {
      final cap = _Captured();
      final api = NotificationsApi(_stubDio(
        captured: cap,
        response: {
          'items': [
            _notificationJson(id: 'n-1', isRead: false),
            _notificationJson(id: 'n-2', isRead: true),
          ],
          'next_cursor': 'c-2',
          'has_more': true,
        },
      ));

      final res = await api.list();

      expect(cap.method, 'GET');
      expect(cap.path, '/notifications');
      expect(res.items, hasLength(2));
      expect(res.items.first.id, 'n-1');
      expect(res.items.first.isRead, isFalse);
      expect(res.items.last.isRead, isTrue);
      expect(res.nextCursor, 'c-2');
      expect(res.hasMore, isTrue);
    });

    test('list defaults is_read to false when the field is missing',
        () async {
      final cap = _Captured();
      final api = NotificationsApi(_stubDio(
        captured: cap,
        response: {
          'items': [
            {
              'id': 'n-9',
              'title': 'Foo',
              'body': 'Bar',
              'created_at': '2024-06-01T10:00:00Z',
            },
          ],
          'has_more': false,
        },
      ));

      final res = await api.list();
      expect(res.items.single.isRead, isFalse);
    });

    test('markRead posts to /notifications/{id}/read', () async {
      final cap = _Captured();
      final api = NotificationsApi(_stubDio(
        captured: cap,
        response: const <String, dynamic>{},
      ));

      await api.markRead('n-42');

      expect(cap.method, 'POST');
      expect(cap.path, '/notifications/n-42/read');
    });

    test('markAllRead posts to /notifications/read-all', () async {
      final cap = _Captured();
      final api = NotificationsApi(_stubDio(
        captured: cap,
        response: const <String, dynamic>{},
      ));

      await api.markAllRead();

      expect(cap.method, 'POST');
      expect(cap.path, '/notifications/read-all');
    });
  });
}
