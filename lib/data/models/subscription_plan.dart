// Subscription / billing models for the SADO Premium upgrade surface.
//
// These mirror the API plan defined in `sado-api/PROJECT_BRIEF.md`. The
// fields are intentionally permissive — the live `/billing/plans`
// endpoint may not be deployed yet on every environment, so the mobile
// app falls back to a curated static list (see `BillingApi.fallback`)
// while the backend rolls out. When the API is live the same code path
// hydrates `SubscriptionPlan` from JSON without further changes.

import 'package:flutter/foundation.dart';

@immutable
class SubscriptionPlan {
  final String id;
  final String nameUz;
  final String nameRu;
  final String? descriptionUz;
  final String? descriptionRu;
  final int priceUzs;
  final double priceUsd;
  final String billingPeriod; // 'monthly' | 'yearly'
  final SubscriptionLimits limits;
  final List<String> features;
  final bool isActive;
  final int sortOrder;

  const SubscriptionPlan({
    required this.id,
    required this.nameUz,
    required this.nameRu,
    this.descriptionUz,
    this.descriptionRu,
    required this.priceUzs,
    this.priceUsd = 0,
    this.billingPeriod = 'monthly',
    required this.limits,
    required this.features,
    this.isActive = true,
    this.sortOrder = 0,
  });

  bool get isFree => priceUzs == 0;
  bool get isPaid => priceUzs > 0;

  String name(String locale) => locale == 'ru' ? nameRu : nameUz;
  String? description(String locale) =>
      locale == 'ru' ? descriptionRu : descriptionUz;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        // The API uses `code` as the canonical short id (`free`,
        // `parent_pro`, …) and exposes it both as `id` (UUID) and `code`
        // on the wire. We prefer `code` because the rest of the mobile
        // codebase keys behaviour off short slugs (`isFree`, recommended
        // plan, etc.).
        id: (json['code'] as String?) ?? (json['id'] as String),
        nameUz: (json['name_uz'] as String?) ??
            (json['name'] as String?) ??
            (json['code'] as String?) ??
            (json['id'] as String),
        nameRu: (json['name_ru'] as String?) ??
            (json['name'] as String?) ??
            (json['code'] as String?) ??
            (json['id'] as String),
        descriptionUz: json['description_uz'] as String?,
        descriptionRu: json['description_ru'] as String?,
        priceUzs: ((json['price_uzs'] as num?) ??
                ((json['price_tiyin'] as num?) ?? 0) / 100)
            .toInt(),
        priceUsd: ((json['price_usd'] as num?) ?? 0).toDouble(),
        billingPeriod:
            (json['billing_period'] as String?) ?? 'monthly',
        limits: SubscriptionLimits.fromJson(
          _coerceLimits(json),
        ),
        features: _coerceFeatureList(json['features']),
        isActive: (json['is_active'] as bool?) ?? true,
        sortOrder: ((json['sort_order'] as num?) ?? 0).toInt(),
      );

  /// The API ships limits inside the `features` JSONB column on the
  /// plan, while older fixtures kept a dedicated `limits` map. Accept
  /// both so wire-format drift doesn't break parsing.
  static Map<String, dynamic> _coerceLimits(Map<String, dynamic> json) {
    final limits = json['limits'];
    if (limits is Map) {
      return Map<String, dynamic>.from(limits);
    }
    final features = json['features'];
    if (features is Map) {
      // The server-side `features` dict carries quotas under
      // canonical keys (`max_assessments_per_day`, `max_children`, …).
      return <String, dynamic>{
        'exercises_per_day': features['max_exercises_per_day'] ??
            features['max_assessments_per_day'] ??
            features['exercises_per_day'],
        'ai_analyses_per_month': features['max_ai_analyses_per_month'] ??
            features['ai_analyses_per_month'],
        'max_children': features['max_children'],
        'max_patients': features['max_patients'],
        'max_users': features['max_users'],
      };
    }
    return const <String, dynamic>{};
  }

  /// `features` may be a `List<String>` (legacy fixtures) or a
  /// `Map<String, Any>` (new API). Flatten to a list of feature flags
  /// so the UI keeps treating it uniformly.
  static List<String> _coerceFeatureList(Object? raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is Map) {
      return raw.entries
          .where((e) => e.value == true)
          .map((e) => e.key.toString())
          .toList();
    }
    return const <String>[];
  }
}

@immutable
class SubscriptionLimits {
  /// `-1` means unlimited.
  final int exercisesPerDay;
  final int aiAnalysesPerMonth;
  final int maxChildren;
  final int maxPatients;
  final int maxUsers;

  const SubscriptionLimits({
    this.exercisesPerDay = 0,
    this.aiAnalysesPerMonth = 0,
    this.maxChildren = 0,
    this.maxPatients = 0,
    this.maxUsers = 0,
  });

  factory SubscriptionLimits.fromJson(Map<String, dynamic> json) =>
      SubscriptionLimits(
        exercisesPerDay:
            ((json['exercises_per_day'] as num?) ?? 0).toInt(),
        aiAnalysesPerMonth:
            ((json['ai_analyses_per_month'] as num?) ?? 0).toInt(),
        maxChildren: ((json['max_children'] as num?) ?? 0).toInt(),
        maxPatients: ((json['max_patients'] as num?) ?? 0).toInt(),
        maxUsers: ((json['max_users'] as num?) ?? 0).toInt(),
      );
}

/// Status of the user's currently active subscription. Mirrors the API
/// values: `active`, `cancelled`, `expired`, `past_due`. We keep the
/// raw string so unknown values from a future server still survive a
/// round-trip without crashing.
@immutable
class UserSubscription {
  final String id;
  final String planId;
  final String status;
  final DateTime startedAt;
  final DateTime? expiresAt;
  final DateTime? cancelledAt;
  final bool autoRenew;
  final bool isActive;
  final int? daysRemaining;
  final List<String> features;

  const UserSubscription({
    required this.id,
    required this.planId,
    required this.status,
    required this.startedAt,
    this.expiresAt,
    this.cancelledAt,
    this.autoRenew = true,
    this.isActive = true,
    this.daysRemaining,
    this.features = const <String>[],
  });

  bool get isPaid => planId != 'free';
  bool get isCancelledButRunning =>
      status == 'cancelled' && (expiresAt?.isAfter(DateTime.now()) ?? false);
  bool get isExpired => status == 'expired';

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    // The wire format went through a couple of revisions during the
    // billing rollout. Support both `plan_id` (legacy) and `plan_code`
    // (current) plus the equivalent timestamp aliases. This keeps the
    // mobile app talking to staging and prod without per-environment
    // forks.
    final planId = (json['plan_code'] as String?) ??
        (json['plan_id'] as String?) ??
        'free';
    final startedAtRaw =
        (json['starts_at'] as String?) ?? (json['started_at'] as String?);
    return UserSubscription(
      id: (json['id'] as String?) ?? 'subscription-$planId',
      planId: planId,
      status: (json['status'] as String?) ?? 'active',
      startedAt: startedAtRaw != null
          ? DateTime.parse(startedAtRaw).toUtc()
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String).toUtc(),
      cancelledAt: json['cancelled_at'] == null
          ? null
          : DateTime.parse(json['cancelled_at'] as String).toUtc(),
      autoRenew: (json['auto_renew'] as bool?) ?? false,
      isActive: (json['is_active'] as bool?) ?? true,
      daysRemaining: (json['days_remaining'] as num?)?.toInt(),
      features: _flattenFeatures(json['features']),
    );
  }

  /// Synthetic record used when the backend does not yet expose the
  /// billing module — every authenticated user is considered free until
  /// they explicitly upgrade. Keeps the rest of the UI conditional on a
  /// concrete object instead of a nullable.
  static UserSubscription syntheticFree() => UserSubscription(
        id: 'synthetic-free',
        planId: 'free',
        status: 'active',
        startedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        autoRenew: false,
      );

  UserSubscription copyWith({
    String? id,
    String? planId,
    String? status,
    DateTime? startedAt,
    DateTime? expiresAt,
    DateTime? cancelledAt,
    bool? autoRenew,
    bool? isActive,
    int? daysRemaining,
    List<String>? features,
  }) =>
      UserSubscription(
        id: id ?? this.id,
        planId: planId ?? this.planId,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        autoRenew: autoRenew ?? this.autoRenew,
        isActive: isActive ?? this.isActive,
        daysRemaining: daysRemaining ?? this.daysRemaining,
        features: features ?? this.features,
      );

  /// Same logic as on [SubscriptionPlan]: `features` may be a list or a
  /// boolean dict; we normalise to a flat list of enabled flag tokens.
  static List<String> _flattenFeatures(Object? raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is Map) {
      return raw.entries
          .where((e) => e.value == true)
          .map((e) => e.key.toString())
          .toList();
    }
    return const <String>[];
  }
}

/// One quota tracked by the API for the current billing period.
///
/// `limit < 0` is the canonical "unlimited" sentinel. When the API
/// reports an unlimited metric we surface a friendly "∞" badge instead
/// of a progress bar so the UI never has to do a degenerate divide-by-
/// zero.
@immutable
class UsageMetric {
  /// Raw token from the API (`assessments_per_day`, `ai_analysis`,
  /// `children_total`, …). The UI maps known tokens to localized copy
  /// and falls back to a humanized string for unknown values.
  final String metric;

  /// Cap from the user's plan. `-1` means unlimited.
  final int limit;

  /// How much of the period the user has consumed.
  final int used;

  /// Always `max(0, limit - used)` for capped metrics, `null` for
  /// unlimited. The API also sends this so we keep its value verbatim
  /// when present.
  final int? remaining;

  /// Calendar boundary at which the counter resets. `null` for
  /// "lifetime" caps (e.g. max_children).
  final DateTime? periodEnd;

  const UsageMetric({
    required this.metric,
    required this.limit,
    required this.used,
    this.remaining,
    this.periodEnd,
  });

  bool get isUnlimited => limit < 0;

  /// Fraction of the cap used, clamped to `[0, 1]`. Returns `0` for
  /// unlimited metrics (the UI paints them with a different visual so
  /// the value isn't surfaced).
  double get progress {
    if (isUnlimited || limit == 0) return 0;
    final raw = used / limit;
    if (raw.isNaN || raw < 0) return 0;
    if (raw > 1) return 1;
    return raw;
  }

  /// `true` if the user has hit (or exceeded) their cap for this
  /// metric. Drives the "Upgrade" hint colour.
  bool get isExhausted => !isUnlimited && limit > 0 && used >= limit;

  factory UsageMetric.fromJson(Map<String, dynamic> json) {
    final limit = ((json['limit'] as num?) ?? 0).toInt();
    final used = ((json['used'] as num?) ?? (json['count'] as num?) ?? 0)
        .toInt();
    final remainingRaw = json['remaining'];
    final periodEndRaw = (json['period_end'] as String?) ??
        (json['resets_at'] as String?);
    return UsageMetric(
      metric: (json['metric'] as String?) ?? 'unknown',
      limit: limit,
      used: used,
      remaining: remainingRaw is num
          ? remainingRaw.toInt()
          : (limit < 0 ? null : (limit - used).clamp(0, limit)),
      periodEnd: periodEndRaw == null ? null : DateTime.tryParse(periodEndRaw),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'metric': metric,
        'limit': limit,
        'used': used,
        if (remaining != null) 'remaining': remaining,
        if (periodEnd != null) 'period_end': periodEnd!.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is UsageMetric &&
      other.metric == metric &&
      other.limit == limit &&
      other.used == used &&
      other.remaining == remaining &&
      other.periodEnd == periodEnd;

  @override
  int get hashCode =>
      Object.hash(metric, limit, used, remaining, periodEnd);
}

/// Aggregated usage envelope for the current billing period.
///
/// The API (per `PROJECT_BRIEF.md`) returns
/// `{ "metrics": [...], "period_start": "...", "period_end": "..." }`,
/// optionally with the user's plan code and a flag describing whether
/// quota gating is currently enforced server-side.
@immutable
class SubscriptionUsage {
  final List<UsageMetric> metrics;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String? planCode;
  final bool enforced;

  const SubscriptionUsage({
    required this.metrics,
    this.periodStart,
    this.periodEnd,
    this.planCode,
    this.enforced = false,
  });

  bool get isEmpty => metrics.isEmpty;

  /// Look up a single metric by token. Returns `null` if the API has
  /// not surfaced it (which the UI treats as "no quota information for
  /// this metric on this plan").
  UsageMetric? metric(String token) {
    for (final m in metrics) {
      if (m.metric == token) return m;
    }
    return null;
  }

  /// Synthetic, all-empty record used when the endpoint isn't
  /// available yet on this environment. Lets the UI show a graceful
  /// "Usage tracking is on the way" state instead of a hard error.
  static const SubscriptionUsage empty = SubscriptionUsage(metrics: <UsageMetric>[]);

  factory SubscriptionUsage.fromJson(Map<String, dynamic> json) {
    final raw = json['metrics'];
    final List<UsageMetric> parsed;
    if (raw is List) {
      parsed = raw
          .whereType<Map>()
          .map((e) => UsageMetric.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (raw is Map) {
      // Allow `{ "metric_token": { "limit": ..., "used": ... } }` shape
      // in case the server inlines metrics under their token.
      parsed = raw.entries
          .map((e) {
            final v = e.value;
            if (v is! Map) return null;
            final inner = Map<String, dynamic>.from(v);
            inner.putIfAbsent('metric', () => e.key.toString());
            return UsageMetric.fromJson(inner);
          })
          .whereType<UsageMetric>()
          .toList();
    } else {
      parsed = const <UsageMetric>[];
    }
    return SubscriptionUsage(
      metrics: parsed,
      periodStart: _parseDate(json['period_start']),
      periodEnd: _parseDate(json['period_end']),
      planCode: (json['plan_code'] as String?) ?? (json['plan_id'] as String?),
      enforced: (json['enforced'] as bool?) ?? false,
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

/// Result of `POST /billing/orders` — the payload mobile needs to hand
/// the user off to the chosen payment provider (Payme or Click).
///
/// The API returns the third-party checkout URL plus a server-side
/// order id we can echo back when the webhook lands. We treat every
/// field but [url] as optional so older API revisions that only
/// surface the URL still work.
@immutable
class CheckoutSession {
  const CheckoutSession({
    required this.url,
    required this.provider,
    this.orderId,
    this.amountUzs,
    this.expiresAt,
  });

  /// Provider-hosted checkout URL the user opens in their browser.
  /// Always non-empty — the API guarantees this for a 200/201 response.
  final String url;

  /// Canonical provider slug (`payme` or `click`). Mirrors what the
  /// caller passed in but we re-read it from the response so we never
  /// drift from what the server actually created the order for.
  final String provider;

  /// Server-side order id. `null` for legacy responses that only ship
  /// the URL.
  final String? orderId;

  /// Order total in tiyin if surfaced by the API. `null` for legacy.
  final int? amountUzs;

  /// When the checkout link expires. `null` if the API doesn't expose
  /// it; mobile shows a generic "open in browser to pay" hint instead.
  final DateTime? expiresAt;

  factory CheckoutSession.fromJson(Map<String, dynamic> json) {
    // Accept both `url` and the legacy `checkout_url` / `pay_url`
    // aliases so we keep talking to staging revisions of the API
    // without per-environment forks.
    final url = (json['url'] as String?) ??
        (json['checkout_url'] as String?) ??
        (json['pay_url'] as String?) ??
        '';
    if (url.isEmpty) {
      throw const FormatException(
        'CheckoutSession requires a non-empty url field.',
      );
    }
    return CheckoutSession(
      url: url,
      provider: (json['provider'] as String?) ??
          (json['payment_provider'] as String?) ??
          'unknown',
      orderId: (json['order_id'] as String?) ??
          (json['id'] as String?) ??
          (json['order'] is Map
              ? (json['order'] as Map)['id']?.toString()
              : null),
      amountUzs: (json['amount_uzs'] as num?)?.toInt() ??
          (json['amount'] as num?)?.toInt(),
      expiresAt: _parseExpiry(json['expires_at']) ??
          _parseExpiry(json['expiry']),
    );
  }

  static DateTime? _parseExpiry(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

/// Canonical payment-provider slugs accepted by the checkout API.
class PaymentProvider {
  const PaymentProvider._();

  /// Payme — the dominant Uzbek e-wallet / merchant gateway.
  static const String payme = 'payme';

  /// Click — Uzbek card-payment gateway.
  static const String click = 'click';

  static const Set<String> all = <String>{payme, click};
}

/// Canonical state slugs returned by `GET /billing/orders[*].state`.
///
/// The API uses a four-state machine: `created` → `pending` → `paid`
/// (terminal success) or `cancelled` (terminal failure / refund). The
/// mobile app keeps the raw string so an unknown future value still
/// renders rather than crash, and exposes typed helpers
/// ([PaymentOrder.isPaid], [PaymentOrder.isCancelled]) for the most
/// common branches.
class PaymentOrderState {
  const PaymentOrderState._();

  static const String created = 'created';
  static const String pending = 'pending';
  static const String paid = 'paid';
  static const String cancelled = 'cancelled';

  static const Set<String> all = <String>{created, pending, paid, cancelled};

  /// Terminal states never transition again — the UI may render them
  /// without polling for updates.
  static const Set<String> terminal = <String>{paid, cancelled};
}

/// One row in `GET /billing/orders` — a payment attempt the user made
/// against a paid plan.
///
/// Surfaces in the Subscription → Billing history screen so users can
/// audit when they paid, which provider charged them, and whether a
/// transaction succeeded. The mobile model keeps both the original
/// tiyin amount and the rounded UZS amount the API also ships, so the
/// UI can display whichever feels right without re-rounding on every
/// frame.
@immutable
class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.planCode,
    required this.amountUzs,
    required this.amountTiyin,
    required this.state,
    required this.provider,
    required this.createdAt,
    this.paidAt,
    this.cancelledAt,
    this.updatedAt,
    this.userId,
  });

  /// Stable server-side identifier (UUID). Used for "see receipt"
  /// follow-ups in a future revision.
  final String id;

  /// Optional user identifier — the API includes it but the screen
  /// never displays it; we keep it for completeness so future
  /// developer tools (admin inspection, support ping) have it on hand.
  final String? userId;

  /// Plan slug (`parent_pro`, `logoped_pro`, …). Looked up locally
  /// against the cached plan catalogue to render a localised name.
  final String planCode;

  /// Order total in UZS. Already rounded server-side
  /// (`amount_tiyin // 100`).
  final int amountUzs;

  /// Order total in tiyin (1 UZS = 100 tiyin). Kept verbatim so a
  /// future receipt PDF can reproduce the exact figure.
  final int amountTiyin;

  /// Canonical state slug — see [PaymentOrderState].
  final String state;

  /// Provider that handled (or will handle) the transaction. Drives
  /// the badge colour + icon on the history row.
  final String provider;

  /// When the row was created (button press → POST /billing/orders).
  final DateTime createdAt;

  /// When the transaction was settled. `null` for non-terminal rows.
  final DateTime? paidAt;

  /// When the order was cancelled / refunded. `null` for non-cancelled
  /// rows.
  final DateTime? cancelledAt;

  /// Last server-side mutation. Surfaced as a fallback timestamp on
  /// pending rows that have neither `paid_at` nor `cancelled_at`.
  final DateTime? updatedAt;

  bool get isPaid => state == PaymentOrderState.paid;
  bool get isCancelled => state == PaymentOrderState.cancelled;
  bool get isPending =>
      state == PaymentOrderState.created || state == PaymentOrderState.pending;
  bool get isTerminal => PaymentOrderState.terminal.contains(state);

  /// The most informative timestamp to display. Returns:
  ///  * [paidAt] for completed orders,
  ///  * [cancelledAt] for cancelled orders,
  ///  * [updatedAt] (falling back to [createdAt]) for in-flight orders.
  DateTime get displayedAt {
    if (isPaid && paidAt != null) return paidAt!;
    if (isCancelled && cancelledAt != null) return cancelledAt!;
    return updatedAt ?? createdAt;
  }

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    final amountTiyinRaw =
        ((json['amount_tiyin'] as num?) ?? 0).toInt();
    final amountUzsRaw = (json['amount_uzs'] as num?)?.toInt() ??
        (amountTiyinRaw ~/ 100);
    return PaymentOrder(
      id: (json['id'] as String?) ?? '',
      userId: json['user_id'] as String?,
      planCode: (json['plan_code'] as String?) ?? 'unknown',
      amountUzs: amountUzsRaw,
      amountTiyin: amountTiyinRaw,
      state: (json['state'] as String?) ?? PaymentOrderState.created,
      provider: (json['provider'] as String?) ?? 'unknown',
      createdAt: _parseDateOrNow(json['created_at']),
      paidAt: _parseDateOrNull(json['paid_at']),
      cancelledAt: _parseDateOrNull(json['cancelled_at']),
      updatedAt: _parseDateOrNull(json['updated_at']),
    );
  }

  static DateTime _parseDateOrNow(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
    }
    return DateTime.now().toUtc();
  }

  static DateTime? _parseDateOrNull(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  @override
  bool operator ==(Object other) =>
      other is PaymentOrder &&
      other.id == id &&
      other.planCode == planCode &&
      other.amountTiyin == amountTiyin &&
      other.state == state &&
      other.provider == provider &&
      other.createdAt == createdAt &&
      other.paidAt == paidAt &&
      other.cancelledAt == cancelledAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        planCode,
        amountTiyin,
        state,
        provider,
        createdAt,
        paidAt,
        cancelledAt,
        updatedAt,
      );
}

/// Cursor-paginated response wrapper for `GET /billing/orders`.
///
/// The mobile app intentionally fetches a single page on history
/// surface so the screen stays snappy; "Load more" can hydrate
/// additional pages later. We keep the raw cursor in this DTO so the
/// future infinite-scroll lands as a one-line change.
@immutable
class PaymentOrderPage {
  const PaymentOrderPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<PaymentOrder> items;
  final bool hasMore;
  final String? nextCursor;

  bool get isEmpty => items.isEmpty;

  static const PaymentOrderPage empty = PaymentOrderPage(
    items: <PaymentOrder>[],
    hasMore: false,
  );
}

