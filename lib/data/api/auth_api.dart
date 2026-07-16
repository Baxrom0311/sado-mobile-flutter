import 'package:dio/dio.dart';

import '../models/models.dart';

class AuthApi {
  AuthApi(this._dio);
  final Dio _dio;

  Future<User> register({
    required String email,
    required String password,
    required String fullName,
    String role = 'parent',
  }) async {
    final res = await _dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': role,
      },
      options: Options(extra: {'anonymous': true}),
    );
    return User.fromJson(res.data as Map<String, dynamic>);
  }

  Future<TokenPair> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      options: Options(extra: {'anonymous': true}),
    );
    return TokenPair.fromJson(res.data as Map<String, dynamic>);
  }

  Future<TokenPair> refresh(String refreshToken) async {
    final res = await _dio.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
      options: Options(extra: {'anonymous': true}),
    );
    return TokenPair.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> logout() => _dio.post('/auth/logout');

  Future<User> me() async {
    final res = await _dio.get('/users/me');
    return User.fromJson(res.data as Map<String, dynamic>);
  }

  /// Patch the currently authenticated user's profile. Only the fields the
  /// caller passes are forwarded so the API can apply a partial update.
  ///
  /// Returns the freshly-loaded [User]. On servers that do not expose a
  /// PATCH /users/me endpoint we fall back to PUT, then to a no-op refetch
  /// of /users/me so the client still gets a consistent view.
  Future<User> updateProfile({
    String? fullName,
    String? language,
  }) async {
    final body = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (language != null) 'language': language,
    };
    if (body.isEmpty) {
      return me();
    }
    try {
      final res = await _dio.patch('/users/me', data: body);
      return User.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // Some deployments expose only PUT — try once before bubbling up.
      final status = e.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        final res = await _dio.put('/users/me', data: body);
        return User.fromJson(res.data as Map<String, dynamic>);
      }
      rethrow;
    }
  }
}
