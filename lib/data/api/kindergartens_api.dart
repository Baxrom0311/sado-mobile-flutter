import 'package:dio/dio.dart';

import '../models/models.dart';

/// Read-only access to the kindergarten directory.
///
/// The API uses the standard cursor-paginated `{items, next_cursor, has_more}`
/// envelope. The list endpoint accepts an optional `q` query parameter for
/// case-insensitive name + address search, plus a `region_id` filter for
/// scoping results to a particular region.
class KindergartensApi {
  KindergartensApi(this._dio);
  final Dio _dio;

  /// List kindergartens, optionally filtered by free-text search [query]
  /// and / or [regionId]. Pass [cursor] to fetch the next page.
  Future<PaginatedResponse<Kindergarten>> list({
    String? query,
    String? regionId,
    String? cursor,
    int? limit,
  }) async {
    final res = await _dio.get('/kindergartens', queryParameters: {
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (regionId != null) 'region_id': regionId,
      if (cursor != null) 'cursor': cursor,
      if (limit != null) 'limit': limit,
    });
    final data = res.data as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((e) => Kindergarten.fromJson(e as Map<String, dynamic>))
        .toList();
    return PaginatedResponse(
      items: items,
      nextCursor: data['next_cursor'] as String?,
      hasMore: (data['has_more'] as bool?) ?? false,
    );
  }

  /// Fetch a single kindergarten by id. Used to resolve the name of an
  /// already-attached kindergarten when only the id is known (e.g. when
  /// editing a child record).
  Future<Kindergarten> get(String id) async {
    final res = await _dio.get('/kindergartens/$id');
    return Kindergarten.fromJson(res.data as Map<String, dynamic>);
  }
}
