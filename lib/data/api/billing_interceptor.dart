import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Information surfaced when the API rejects a request because the
/// caller's subscription quota has been exhausted (HTTP 402 Payment
/// Required). The brief mandates this status code with structured
/// `extra.metric` / `extra.limit` fields, so we model it as a typed
/// value object the UI can react to without re-parsing JSON.
@immutable
class PlanLimitNotice {
  const PlanLimitNotice({
    required this.metric,
    required this.limit,
    this.message,
  });

  /// Free-form metric token from the API (`exercises_per_day`,
  /// `ai_analysis`, `children_total`, …). Unknown values fall through to
  /// the generic copy so a future server addition never crashes the UI.
  final String metric;

  /// The cap that was hit. `0` if the API didn't include the field.
  final int limit;

  /// Optional human-readable detail from the API. We display it as a
  /// secondary line under the canned upgrade copy.
  final String? message;

  PlanLimitNotice copyWith({String? metric, int? limit, String? message}) =>
      PlanLimitNotice(
        metric: metric ?? this.metric,
        limit: limit ?? this.limit,
        message: message ?? this.message,
      );

  /// Parse a Dio 402 response body. The brief uses
  /// `{ "detail": "...", "extra": { "metric": ..., "limit": ... } }` —
  /// we accept both that shape and a flatter `{ "metric": ..., "limit": ... }`
  /// in case the API drops the envelope in the future.
  static PlanLimitNotice? fromResponseData(Object? data) {
    if (data is! Map) return null;
    final extra = data['extra'];
    final source = extra is Map ? extra : data;
    final metric = (source['metric'] as String?)?.trim();
    if (metric == null || metric.isEmpty) return null;
    final limit = ((source['limit'] as num?) ?? 0).toInt();
    final message = (data['detail'] as String?) ??
        (source['message'] as String?) ??
        (data['message'] as String?);
    return PlanLimitNotice(
      metric: metric,
      limit: limit,
      message: message?.trim().isEmpty == true ? null : message,
    );
  }
}

/// Minimal state holder broadcasting [PlanLimitNotice] events to the
/// shell. Mirrors the pattern used by `sessionExpiredEventProvider` —
/// the interceptor pushes events via the provided callback, the
/// notifier bumps a state object, and the listener (in `ShellScreen`)
/// surfaces the upgrade sheet exactly once per event.
class PlanLimitEventNotifier extends StateNotifier<PlanLimitEvent?> {
  PlanLimitEventNotifier() : super(null);

  /// Counter increment guarantees `==` returns false for two consecutive
  /// notices with the same payload, so a Riverpod `listen` callback
  /// fires every time even when the user retried into the same wall.
  int _seq = 0;

  void announce(PlanLimitNotice notice) {
    _seq += 1;
    state = PlanLimitEvent(seq: _seq, notice: notice);
  }

  /// Cleared by the listener once the sheet has been presented so
  /// re-listening doesn't replay an already-handled event after a
  /// hot-reload or test rebuild.
  void clear() {
    state = null;
  }
}

/// Wrapper around [PlanLimitNotice] that adds a monotonically
/// increasing sequence number so [PlanLimitEventNotifier]
/// listeners can detect repeated events.
@immutable
class PlanLimitEvent {
  const PlanLimitEvent({required this.seq, required this.notice});
  final int seq;
  final PlanLimitNotice notice;

  @override
  bool operator ==(Object other) =>
      other is PlanLimitEvent && other.seq == seq && other.notice == notice;

  @override
  int get hashCode => Object.hash(seq, notice);
}

final planLimitEventProvider =
    StateNotifierProvider<PlanLimitEventNotifier, PlanLimitEvent?>(
  (ref) => PlanLimitEventNotifier(),
);

/// Dio interceptor that detects HTTP 402 responses, parses the
/// structured plan-limit envelope, and forwards the notice to the
/// supplied callback. The original [DioException] is then forwarded
/// onward unchanged so per-call sites can still render their own
/// fallback (e.g. a snackbar) without us swallowing the error.
class BillingInterceptor extends Interceptor {
  BillingInterceptor({required this.onPlanLimit});

  final void Function(PlanLimitNotice notice) onPlanLimit;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 402) {
      final notice =
          PlanLimitNotice.fromResponseData(err.response?.data) ??
              const PlanLimitNotice(metric: 'unknown', limit: 0);
      try {
        onPlanLimit(notice);
      } catch (_) {/* never let listener errors mask the original */}
    }
    handler.next(err);
  }
}
