import 'package:dio/dio.dart';

import '../models/models.dart';

class ChildrenApi {
  ChildrenApi(this._dio);
  final Dio _dio;

  Future<PaginatedResponse<Child>> list({String? cursor}) async {
    final res = await _dio.get('/children', queryParameters: {
      if (cursor != null) 'cursor': cursor,
    });
    final data = res.data as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((e) => Child.fromJson(e as Map<String, dynamic>))
        .toList();
    return PaginatedResponse(
      items: items,
      nextCursor: data['next_cursor'] as String?,
      hasMore: (data['has_more'] as bool?) ?? false,
    );
  }

  Future<Child> get(String id) async {
    final res = await _dio.get('/children/$id');
    return Child.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Child> create({
    required String name,
    required String birthDate,
    required String gender,
    String? kindergartenId,
  }) async {
    final res = await _dio.post('/children', data: {
      'name': name,
      'birth_date': birthDate,
      'gender': gender,
      if (kindergartenId != null) 'kindergarten_id': kindergartenId,
    });
    return Child.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Child> update(String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/children/$id', data: data);
    return Child.fromJson(res.data as Map<String, dynamic>);
  }

  /// Patch a subset of fields (name, birth_date, gender, kindergarten_id).
  /// Server-side this calls the same PUT but lets us only send what changed.
  Future<Child> patch(
    String id, {
    String? name,
    String? birthDate,
    String? gender,
    String? kindergartenId,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (birthDate != null) body['birth_date'] = birthDate;
    if (gender != null) body['gender'] = gender;
    if (kindergartenId != null) body['kindergarten_id'] = kindergartenId;
    return update(id, body);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/children/$id');
  }
}
