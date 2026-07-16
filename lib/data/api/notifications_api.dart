import 'package:dio/dio.dart';

import '../models/models.dart';

class NotificationsApi {
  NotificationsApi(this._dio);
  final Dio _dio;

  Future<PaginatedResponse<AppNotification>> list() async {
    final res = await _dio.get('/notifications');
    final data = res.data as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    return PaginatedResponse(
      items: items,
      nextCursor: data['next_cursor'] as String?,
      hasMore: (data['has_more'] as bool?) ?? false,
    );
  }

  Future<void> markRead(String id) =>
      _dio.post('/notifications/$id/read');

  Future<void> markAllRead() => _dio.post('/notifications/read-all');
}
