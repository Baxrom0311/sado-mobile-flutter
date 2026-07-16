import 'package:dio/dio.dart';

import '../models/subscription_plan.dart';

/// Thin wrapper around the (eventual) `/billing/...` API.
///
/// The mobile app is already expected to ship with a Premium upgrade
/// surface even though the API rollout for billing is still in flight.
/// To keep the screen functional in every environment we:
///
///  * Try the live endpoint first.
///  * Treat `404`, `5xx`, network failures, or shape mismatches as a
///    signal that billing isn't enabled yet, and return the curated
///    [fallbackPlans] so the UX still renders the value-prop.
///  * Surface only "fatal" errors (auth, malformed config) so the
///    provider can show a real error state if needed.
class BillingApi {
  BillingApi(this._dio);
  final Dio _dio;

  /// Fetch all active plans. Falls back to [fallbackPlans] on any
  /// transport / shape error so the screen always has something to
  /// render.
  Future<List<SubscriptionPlan>> listPlans() async {
    try {
      final res = await _dio.get(
        '/billing/plans',
        options: Options(extra: {'anonymous': true}),
      );
      final data = res.data;
      final List rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map<String, dynamic>) {
        rawList = (data['items'] as List?) ?? const [];
      } else {
        rawList = const [];
      }
      if (rawList.isEmpty) return fallbackPlans;
      return rawList
          .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
          .where((p) => p.isActive)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } on DioException {
      return fallbackPlans;
    } catch (_) {
      return fallbackPlans;
    }
  }

  /// The current user's active subscription, if any. Returns a
  /// synthetic "free" record when the endpoint isn't available so the
  /// screen can still highlight the active tier without nullable
  /// gymnastics.
  Future<UserSubscription> mySubscription() async {
    try {
      // The live API serves the canonical record at
      // `/billing/subscription`. Older fixtures used `/me`; we try
      // both so the mobile app keeps working on either revision.
      final res = await _safeGet([
        '/billing/subscription',
        '/billing/subscription/me',
      ]);
      final data = res?.data;
      if (data is Map<String, dynamic> &&
          (data.containsKey('plan_code') ||
              data.containsKey('plan_id'))) {
        return UserSubscription.fromJson(data);
      }
      return UserSubscription.syntheticFree();
    } on DioException {
      return UserSubscription.syntheticFree();
    } catch (_) {
      return UserSubscription.syntheticFree();
    }
  }

  /// Disable auto-renew on the currently-active subscription.
  ///
  /// Returns the updated [UserSubscription]. When the cancel endpoint
  /// is not yet deployed, throws a [BillingNotImplemented] so the
  /// caller can surface a friendly "coming soon" sheet instead of a
  /// raw error toast.
  Future<UserSubscription> cancelAutoRenew() async {
    try {
      final res = await _dio.post('/billing/subscription/cancel');
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return UserSubscription.fromJson(data);
      }
      // Some servers return 204 with no body — refresh the record.
      return await mySubscription();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405 || code == 501) {
        throw const BillingNotImplemented(
          'Cancel endpoint is not deployed yet on this environment.',
        );
      }
      rethrow;
    }
  }

  /// Re-enable auto-renew on a subscription that the user previously
  /// cancelled but whose paid period hasn't ended yet. The mirror of
  /// [cancelAutoRenew]: `POST /billing/subscription/resume` returns
  /// the updated [UserSubscription] (or 204 No Content, in which case
  /// we refresh via [mySubscription]).
  ///
  /// Throws [BillingNotImplemented] on `404`/`405`/`501` so the UI
  /// can surface a friendly "coming soon" sheet instead of a hard
  /// error — matches the behaviour of [cancelAutoRenew] and keeps
  /// the screen consistent on environments where the billing module
  /// is still rolling out.
  Future<UserSubscription> resumeAutoRenew() async {
    try {
      final res = await _dio.post('/billing/subscription/resume');
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return UserSubscription.fromJson(data);
      }
      return await mySubscription();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405 || code == 501) {
        throw const BillingNotImplemented(
          'Resume endpoint is not deployed yet on this environment.',
        );
      }
      rethrow;
    }
  }

  /// Current-period usage envelope for the signed-in user.
  ///
  /// Returns the raw metrics from the API when available. When the
  /// endpoint isn't deployed yet (404/405/501) we return
  /// [SubscriptionUsage.empty] so the UI can render a graceful
  /// "tracking on the way" state instead of a hard error. Network
  /// failures are also tolerated for the same reason — usage info is
  /// purely informational and should never block other surfaces.
  Future<SubscriptionUsage> usage() async {
    try {
      final res = await _safeGet([
        '/billing/usage',
        '/billing/subscription/usage',
        '/subscriptions/usage',
      ]);
      final data = res?.data;
      if (data is Map<String, dynamic>) {
        return SubscriptionUsage.fromJson(data);
      }
      return SubscriptionUsage.empty;
    } on DioException {
      return SubscriptionUsage.empty;
    } catch (_) {
      return SubscriptionUsage.empty;
    }
  }

  /// Initiate a checkout session for [planCode] via [provider]
  /// (`payme` or `click`). The API responds with a third-party
  /// checkout URL the mobile app hands to the user (currently via
  /// clipboard + browser; native deep-link will follow when
  /// `url_launcher` lands).
  ///
  /// Throws:
  ///  * [BillingNotImplemented] when the endpoint isn't deployed yet
  ///    on this environment (`404` / `405` / `501`). The UI surfaces
  ///    the existing "Coming soon" sheet on this signal so the user
  ///    still gets a calm, branded experience rather than a raw error.
  ///  * [DioException] on any other transport / server failure so the
  ///    caller can render an error state with retry.
  ///  * [FormatException] when the API responds 2xx but without a
  ///    usable `url` field (defensive — should never happen in
  ///    practice but keeps the contract explicit).
  Future<CheckoutSession> createCheckout({
    required String planCode,
    required String provider,
  }) async {
    assert(
      PaymentProvider.all.contains(provider),
      'createCheckout: unsupported provider "$provider".',
    );
    try {
      final res = await _dio.post(
        '/billing/orders',
        data: <String, dynamic>{
          'plan_code': planCode,
          'provider': provider,
        },
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return CheckoutSession.fromJson(data);
      }
      throw const FormatException(
        'Unexpected /billing/orders response shape.',
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405 || code == 501) {
        throw const BillingNotImplemented(
          'Checkout endpoint is not deployed yet on this environment.',
        );
      }
      rethrow;
    }
  }

  /// Fetch a single payment order by id.
  ///
  /// First tries `GET /billing/orders/{id}` (the canonical detail
  /// route). Older API revisions during the rollout shipped only the
  /// list endpoint, so we transparently fall back to scanning the
  /// first page of `listOrders` when the dedicated route returns
  /// `404`/`405`/`501`.
  ///
  /// Returns `null` when the order genuinely cannot be found in any
  /// known surface so the caller can render a friendly "no longer
  /// available" empty state instead of a hard error toast.
  Future<PaymentOrder?> getOrder(String id) async {
    if (id.isEmpty) return null;
    try {
      final res = await _dio.get('/billing/orders/$id');
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return PaymentOrder.fromJson(data);
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      // Genuine "no such order" lives at the same surface as "endpoint
      // not deployed yet" on legacy revisions — both fall through to
      // the list-scan branch below before we give up.
      if (code != 404 && code != 405 && code != 501) {
        rethrow;
      }
    } catch (_) {
      // Tolerate shape mismatches the same way list/usage do.
    }

    try {
      final page = await listOrders(limit: 50);
      for (final o in page.items) {
        if (o.id == id) return o;
      }
    } on DioException {
      // If even the list endpoint isn't healthy, surface as not-found
      // so the screen can render a friendly empty state.
    }
    return null;
  }

  /// List the caller's past payment orders, newest first.
  ///
  /// Backed by `GET /billing/orders` which returns the standard
  /// `{items, next_cursor, has_more}` envelope. Pass [cursor] to
  /// fetch the next page.
  ///
  /// On `404` / `405` / `501` we return [PaymentOrderPage.empty] so
  /// the history surface still renders a graceful "no charges yet"
  /// state without throwing — matches how `usage()` and
  /// `mySubscription()` degrade when the billing module isn't
  /// deployed yet on this environment. Other transport errors are
  /// surfaced verbatim so the UI can show an error + retry.
  Future<PaymentOrderPage> listOrders({String? cursor, int? limit}) async {
    try {
      final res = await _dio.get(
        '/billing/orders',
        queryParameters: <String, dynamic>{
          if (cursor != null) 'cursor': cursor,
          if (limit != null) 'limit': limit,
        },
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) return PaymentOrderPage.empty;
      final rawItems = data['items'];
      final List<PaymentOrder> items;
      if (rawItems is List) {
        items = rawItems
            .whereType<Map>()
            .map((e) => PaymentOrder.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        items = const <PaymentOrder>[];
      }
      return PaymentOrderPage(
        items: items,
        nextCursor: data['next_cursor'] as String?,
        hasMore: (data['has_more'] as bool?) ?? false,
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405 || code == 501) {
        return PaymentOrderPage.empty;
      }
      rethrow;
    }
  }

  /// Try a list of paths in order, returning the first 2xx response
  /// or `null` when every candidate returns a non-fatal client error.
  /// Anything that *does* throw (network, 5xx, auth) is propagated so
  /// the caller can decide how to react.
  Future<Response<dynamic>?> _safeGet(List<String> paths) async {
    DioException? lastClientError;
    for (final p in paths) {
      try {
        return await _dio.get(p);
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 404 || code == 405) {
          lastClientError = e;
          continue;
        }
        rethrow;
      }
    }
    if (lastClientError != null) {
      // Exhausted candidates with 404s — treat as "feature not live".
      return null;
    }
    return null;
  }

  /// Curated static plans that mirror the upcoming API contract. Order
  /// matches `sort_order` from `sado-api/PROJECT_BRIEF.md`.
  static const List<SubscriptionPlan> fallbackPlans = [
    SubscriptionPlan(
      id: 'free',
      nameUz: 'Bepul',
      nameRu: 'Бесплатно',
      descriptionUz: 'Boshlash uchun ajoyib reja',
      descriptionRu: 'Отличный план для начала',
      priceUzs: 0,
      priceUsd: 0,
      limits: SubscriptionLimits(
        exercisesPerDay: 3,
        aiAnalysesPerMonth: 5,
        maxChildren: 1,
      ),
      features: ['basic_exercises', 'basic_progress'],
      sortOrder: 0,
    ),
    SubscriptionPlan(
      id: 'parent_pro',
      nameUz: 'Premium',
      nameRu: 'Премиум',
      descriptionUz: 'Cheksiz mashq va to\u2018liq sun\u2019iy intellekt tahlili',
      descriptionRu: 'Безлимит упражнений и полный AI-анализ',
      priceUzs: 39000,
      priceUsd: 3,
      limits: SubscriptionLimits(
        exercisesPerDay: -1,
        aiAnalysesPerMonth: -1,
        maxChildren: 5,
      ),
      features: [
        'all_exercises',
        'full_ai_analysis',
        'detailed_progress',
        'recommendations',
        'export_pdf',
      ],
      sortOrder: 10,
    ),
    SubscriptionPlan(
      id: 'logoped_pro',
      nameUz: 'Logoped',
      nameRu: 'Логопед',
      descriptionUz: 'Mutaxassislar uchun bemorlarni boshqarish',
      descriptionRu: 'Управление пациентами для специалистов',
      priceUzs: 149000,
      priceUsd: 12,
      limits: SubscriptionLimits(
        exercisesPerDay: -1,
        aiAnalysesPerMonth: -1,
        maxChildren: -1,
        maxPatients: 50,
      ),
      features: [
        'patient_management',
        'assign_exercises',
        'therapy_goals',
        'screening_battery',
        'referral_pdf',
        'analytics',
      ],
      sortOrder: 20,
    ),
    SubscriptionPlan(
      id: 'clinic',
      nameUz: 'Klinika',
      nameRu: 'Клиника',
      descriptionUz: 'Bog\u02bbcha va klinikalar uchun tenant rejasi',
      descriptionRu: 'Тариф для садов и клиник',
      // Tenant pricing is bespoke — the catalogue surfaces a 0 price
      // and the subscription screen routes the user to "Contact sales"
      // instead of triggering Payme/Click checkout.
      priceUzs: 0,
      priceUsd: 0,
      limits: SubscriptionLimits(
        exercisesPerDay: -1,
        aiAnalysesPerMonth: -1,
        maxChildren: -1,
        maxPatients: -1,
        maxUsers: 10,
      ),
      features: [
        'tenant_admin',
        'group_screening',
        'all_logoped_features',
        'reports',
      ],
      sortOrder: 30,
    ),
  ];
}

/// Marker exception raised when the mobile app calls an endpoint that
/// is part of the billing roadmap but isn't deployed yet (404/405/501).
/// Surface as a friendly "coming soon" UX rather than a hard error.
class BillingNotImplemented implements Exception {
  const BillingNotImplemented(this.message);
  final String message;

  @override
  String toString() => 'BillingNotImplemented: $message';
}
