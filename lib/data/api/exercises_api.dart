import 'package:dio/dio.dart';

import '../models/models.dart';

class ExercisesApi {
  ExercisesApi(this._dio);
  final Dio _dio;

  Future<PaginatedResponse<Exercise>> list({
    String? category,
    String? ageGroup,
    String? difficulty,
    String? cursor,
  }) async {
    final res = await _dio.get('/exercises', queryParameters: {
      if (category != null) 'category': category,
      if (ageGroup != null) 'age_group': ageGroup,
      if (difficulty != null) 'difficulty': difficulty,
      if (cursor != null) 'cursor': cursor,
    });
    final data = res.data as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
    return PaginatedResponse(
      items: items,
      nextCursor: data['next_cursor'] as String?,
      hasMore: (data['has_more'] as bool?) ?? false,
    );
  }

  Future<Exercise> get(String id) async {
    final res = await _dio.get('/exercises/$id');
    return Exercise.fromJson(res.data as Map<String, dynamic>);
  }
}
