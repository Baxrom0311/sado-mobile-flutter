import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/api_client.dart';
import '../data/api/billing_api.dart';
import '../data/models/subscription_plan.dart';

/// Provider tree for the Subscription / Premium upgrade surface.
///
/// The API rollout for billing is in progress on the backend side —
/// `BillingApi` already gracefully degrades to a curated static plan
/// list, so the upgrade screen renders identically in every
/// environment. When `/billing/plans` and `/billing/subscription/me`
/// go live the existing providers light up automatically.

final billingApiProvider = Provider<BillingApi>(
  (ref) => BillingApi(ref.watch(dioProvider)),
);

/// Active plan catalog. Always resolves — falls back to a curated list
/// when the live endpoint isn't reachable. Cached for the session so
/// flipping to the upgrade screen feels instant on the second visit.
final subscriptionPlansProvider =
    FutureProvider<List<SubscriptionPlan>>((ref) async {
  final api = ref.watch(billingApiProvider);
  return api.listPlans();
});

/// The currently signed-in user's subscription. Synthesises a free
/// record when no live subscription is reported by the API.
final mySubscriptionProvider =
    FutureProvider<UserSubscription>((ref) async {
  final api = ref.watch(billingApiProvider);
  return api.mySubscription();
});

/// Current-period usage envelope (assessments today, AI analyses this
/// month, children created, …). Falls back to an empty record when the
/// `/billing/usage` endpoint isn't live yet so the UI can render a
/// graceful "coming soon" state instead of a hard error.
final subscriptionUsageProvider =
    FutureProvider<SubscriptionUsage>((ref) async {
  final api = ref.watch(billingApiProvider);
  return api.usage();
});

/// Paginated history of payment orders. Drives the "Billing history"
/// screen. The first page is cached for the session so flipping into
/// the screen feels instant on the second visit; pull-to-refresh
/// invalidates the provider.
final paymentOrdersFirstPageProvider =
    FutureProvider<PaymentOrderPage>((ref) async {
  final api = ref.watch(billingApiProvider);
  return api.listOrders();
});

/// Fetch a single payment order by id. Backs the order-detail screen
/// reachable from a history-row tap.
///
/// Resolution strategy:
///
///  1. Look in the cached first-page list — flipping from the history
///     screen to the detail screen is instant when the order is
///     already paged in.
///  2. Fall back to `BillingApi.getOrder(id)` which itself tries the
///     dedicated `/billing/orders/{id}` route then a list scan.
///
/// Resolves to `null` when the order is genuinely no longer
/// reachable (deleted server-side, or the user navigated to a stale
/// deep-link). The screen renders a calm "not found" empty state in
/// that case rather than a hard error.
final paymentOrderProvider =
    FutureProvider.family<PaymentOrder?, String>((ref, id) async {
  if (id.isEmpty) return null;

  // Cache lookup first — keeps the navigation feel snappy.
  final cached = ref.read(paymentOrdersFirstPageProvider).maybeWhen(
        data: (page) {
          for (final o in page.items) {
            if (o.id == id) return o;
          }
          return null;
        },
        orElse: () => null,
      );
  if (cached != null) return cached;

  final api = ref.watch(billingApiProvider);
  return api.getOrder(id);
});

/// Thin convenience derivation: `true` when the user is on the free
/// plan (or no plan resolved yet — be conservative). Drives the
/// "Upgrade to Premium" entry points on the home/settings surfaces so
/// they hide for already-premium users.
final isOnFreePlanProvider = Provider<bool>((ref) {
  final sub = ref.watch(mySubscriptionProvider);
  return sub.maybeWhen(
    data: (s) => s.planId == 'free',
    orElse: () => true,
  );
});
