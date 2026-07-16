import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants.dart';
import 'billing_interceptor.dart';

const _storage = FlutterSecureStorage();

Future<String?> getAccessToken() => _storage.read(key: 'access_token');
Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');

Future<void> saveTokens({
  required String access,
  required String refresh,
}) async {
  await _storage.write(key: 'access_token', value: access);
  await _storage.write(key: 'refresh_token', value: refresh);
}

Future<void> clearTokens() => _storage.deleteAll();

/// Resolves a media path returned by the API (which may be either a fully
/// qualified URL, a path beginning with `/`, or just a relative path) into an
/// absolute URL the audio player / image cache can fetch.
///
/// Returns `null` for null / empty input.
String? resolveMediaUrl(String? path) {
  if (path == null) return null;
  final trimmed = path.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  // Strip the `/api/v1` suffix from the base when the API returns absolute
  // paths like `/storage/...` that live at the host root rather than under
  // the API prefix.
  final base = AppConstants.apiBaseUrl;
  final apiPrefix = RegExp(r'/api/v\d+/?$');
  final host = base.replaceFirst(apiPrefix, '');
  if (trimmed.startsWith('/')) {
    return '$host$trimmed';
  }
  return '$host/$trimmed';
}

/// Callback invoked by the auth interceptor when the refresh-token flow has
/// failed (or there was no refresh token). Implementations should update
/// any in-memory auth state so the router redirects to /login.
typedef OnSessionExpired = void Function();

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json'},
  ));

  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      onSessionExpired: () {
        // Lazily defer the import: read AuthNotifier without creating a cycle
        // at provider-build time. We import via dynamic invocation through
        // the ref only when an actual 401-after-refresh-fail occurs.
        try {
          // ignore: avoid_dynamic_calls
          ref.read(_sessionGuardProvider.notifier).expire();
        } catch (_) {/* best effort */}
      },
    ),
  );
  // Billing interceptor — translates HTTP 402 PaymentRequired into a
  // structured [PlanLimitNotice] event the shell can react to. Keeps
  // the responsibility off every per-screen catch site so the upgrade
  // prompt is consistent everywhere.
  dio.interceptors.add(
    BillingInterceptor(
      onPlanLimit: (notice) {
        try {
          ref.read(planLimitEventProvider.notifier).announce(notice);
        } catch (_) {/* best effort */}
      },
    ),
  );
  return dio;
});

/// Internal counter that bumps every time the session is forcibly expired.
/// `auth_provider` listens to it and transitions to `unauthenticated`.
class _SessionGuard extends StateNotifier<int> {
  _SessionGuard() : super(0);
  void expire() => state = state + 1;
}

final _sessionGuardProvider =
    StateNotifierProvider<_SessionGuard, int>((ref) => _SessionGuard());

/// Public, read-only view of the session-expired counter so the auth
/// notifier can listen without depending on private symbols.
final sessionExpiredEventProvider = Provider<int>(
  (ref) => ref.watch(_sessionGuardProvider),
);

/// Auth interceptor for Dio.
///
/// * Adds `Authorization: Bearer <token>` to every authenticated request.
/// * On 401, attempts a single refresh using the saved refresh token.
/// * On refresh failure: clears tokens and notifies the app via
///   [onSessionExpired] so the router can redirect to /login.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required Dio dio, required this.onSessionExpired})
      : _dio = dio;

  final Dio _dio;
  final OnSessionExpired onSessionExpired;
  bool _isRefreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['anonymous'] == true) {
      return handler.next(options);
    }
    final token = await getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.extra['anonymous'] == true ||
        _isRefreshing) {
      return handler.next(err);
    }

    _isRefreshing = true;
    try {
      final refresh = await getRefreshToken();
      if (refresh == null) {
        await clearTokens();
        onSessionExpired();
        return handler.next(err);
      }

      final res = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(extra: {'anonymous': true}),
      );

      final newAccess = res.data['access_token'] as String;
      final newRefresh = res.data['refresh_token'] as String;
      await saveTokens(access: newAccess, refresh: newRefresh);

      // Retry original request
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccess';
      final retryRes = await _dio.fetch(opts);
      handler.resolve(retryRes);
    } on DioException {
      await clearTokens();
      onSessionExpired();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}
