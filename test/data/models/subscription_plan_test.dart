import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/models/subscription_plan.dart';

void main() {
  group('UserSubscription.fromJson', () {
    test(
        'parses the live API shape with plan_code / starts_at / '
        'days_remaining / features map', () {
      final sub = UserSubscription.fromJson(<String, dynamic>{
        'id': 'sub-7',
        'user_id': 'user-1',
        'plan_code': 'parent_pro',
        'status': 'active',
        'starts_at': '2025-01-01T00:00:00Z',
        'expires_at': '2025-02-01T00:00:00Z',
        'cancelled_at': null,
        'auto_renew': true,
        'is_active': true,
        'days_remaining': 14,
        'features': <String, dynamic>{
          'export_pdf': true,
          'detailed_progress': true,
          'beta_only': false,
        },
      });

      expect(sub.id, 'sub-7');
      expect(sub.planId, 'parent_pro');
      expect(sub.status, 'active');
      expect(sub.startedAt, DateTime.utc(2025, 1, 1));
      expect(sub.expiresAt, DateTime.utc(2025, 2, 1));
      expect(sub.cancelledAt, isNull);
      expect(sub.autoRenew, isTrue);
      expect(sub.isActive, isTrue);
      expect(sub.daysRemaining, 14);
      expect(sub.isPaid, isTrue);
      expect(sub.features, containsAll(['export_pdf', 'detailed_progress']));
      expect(sub.features, isNot(contains('beta_only')));
    });

    test('still accepts the legacy plan_id / started_at field aliases', () {
      final sub = UserSubscription.fromJson(<String, dynamic>{
        'id': 'sub-legacy',
        'plan_id': 'logoped',
        'status': 'active',
        'started_at': '2024-12-01T00:00:00Z',
        'auto_renew': false,
      });
      expect(sub.planId, 'logoped');
      expect(sub.startedAt, DateTime.utc(2024, 12, 1));
      expect(sub.autoRenew, isFalse);
    });

    test(
        'falls back to the synthetic-free defaults when crucial fields '
        'are missing instead of throwing', () {
      final sub = UserSubscription.fromJson(<String, dynamic>{
        'status': 'active',
      });
      expect(sub.planId, 'free');
      expect(sub.isPaid, isFalse);
      expect(sub.startedAt.millisecondsSinceEpoch, 0);
    });

    test(
        'isCancelledButRunning is true only when status is cancelled '
        'and the period has not yet expired', () {
      final future = DateTime.now().add(const Duration(days: 5));
      final past = DateTime.now().subtract(const Duration(days: 1));
      final running = UserSubscription(
        id: 's',
        planId: 'parent_pro',
        status: 'cancelled',
        startedAt: DateTime(2024),
        expiresAt: future,
      );
      final lapsed = UserSubscription(
        id: 's',
        planId: 'parent_pro',
        status: 'cancelled',
        startedAt: DateTime(2024),
        expiresAt: past,
      );
      expect(running.isCancelledButRunning, isTrue);
      expect(lapsed.isCancelledButRunning, isFalse);
    });

    test('feature list also accepts a List<String> wire format', () {
      final sub = UserSubscription.fromJson(<String, dynamic>{
        'id': 'sub-list',
        'plan_code': 'parent_pro',
        'status': 'active',
        'starts_at': '2025-01-01T00:00:00Z',
        'features': ['export_pdf', 'detailed_progress'],
      });
      expect(sub.features, ['export_pdf', 'detailed_progress']);
    });

    test('copyWith mutates only the supplied fields', () {
      final original = UserSubscription(
        id: 'sub-1',
        planId: 'parent_pro',
        status: 'active',
        startedAt: DateTime.utc(2025, 1, 1),
        autoRenew: true,
      );
      final updated = original.copyWith(autoRenew: false);
      expect(updated.autoRenew, isFalse);
      expect(updated.id, original.id);
      expect(updated.planId, original.planId);
      expect(updated.startedAt, original.startedAt);
    });
  });

  group('SubscriptionPlan.fromJson', () {
    test('prefers the short `code` slug over the UUID `id` for plan id', () {
      final plan = SubscriptionPlan.fromJson(<String, dynamic>{
        'id': 'd0d5...',
        'code': 'parent_pro',
        'name_uz': 'Premium',
        'name_ru': 'Премиум',
        'price_uzs': 39000,
        'limits': <String, dynamic>{
          'exercises_per_day': -1,
          'ai_analyses_per_month': -1,
          'max_children': 5,
        },
        'features': ['export_pdf'],
      });
      expect(plan.id, 'parent_pro');
      expect(plan.priceUzs, 39000);
      expect(plan.limits.maxChildren, 5);
      expect(plan.features, ['export_pdf']);
    });

    test('derives priceUzs from price_tiyin when only tiyin is provided', () {
      final plan = SubscriptionPlan.fromJson(<String, dynamic>{
        'id': 'parent_pro',
        'code': 'parent_pro',
        'name_uz': 'Premium',
        'name_ru': 'Премиум',
        'price_tiyin': 3900000,
        'features': <String, dynamic>{'export_pdf': true},
      });
      // 3 900 000 tiyin / 100 = 39 000 UZS
      expect(plan.priceUzs, 39000);
      // The features dict carries quotas as well; without an explicit
      // limits map the parser returns sensible defaults.
      expect(plan.features, ['export_pdf']);
    });

    test('extracts limits from a server-side features dict when present', () {
      final plan = SubscriptionPlan.fromJson(<String, dynamic>{
        'id': 'free',
        'code': 'free',
        'name_uz': 'Bepul',
        'name_ru': 'Бесплатно',
        'price_uzs': 0,
        'features': <String, dynamic>{
          'max_assessments_per_day': 3,
          'max_ai_analyses_per_month': 5,
          'max_children': 1,
          'basic_exercises': true,
        },
      });
      expect(plan.limits.exercisesPerDay, 3);
      expect(plan.limits.aiAnalysesPerMonth, 5);
      expect(plan.limits.maxChildren, 1);
      expect(plan.features, ['basic_exercises']);
    });

    test('keeps backward compatibility with the older `name` flat field', () {
      final plan = SubscriptionPlan.fromJson(<String, dynamic>{
        'id': 'logoped',
        'name': 'Logoped',
        'price_uzs': 149000,
        'features': const <String>[],
      });
      expect(plan.nameUz, 'Logoped');
      expect(plan.nameRu, 'Logoped');
      expect(plan.id, 'logoped');
    });
  });

  group('PaymentOrder.fromJson', () {
    test('hydrates the canonical wire shape from /billing/orders', () {
      final order = PaymentOrder.fromJson(<String, dynamic>{
        'id': 'ord-1',
        'user_id': 'user-7',
        'plan_code': 'parent_pro',
        'amount_tiyin': 3900000,
        'amount_uzs': 39000,
        'state': 'paid',
        'provider': 'payme',
        'created_at': '2025-01-10T12:00:00Z',
        'paid_at': '2025-01-10T12:01:23Z',
        'updated_at': '2025-01-10T12:01:23Z',
      });
      expect(order.id, 'ord-1');
      expect(order.userId, 'user-7');
      expect(order.planCode, 'parent_pro');
      expect(order.amountUzs, 39000);
      expect(order.amountTiyin, 3900000);
      expect(order.state, PaymentOrderState.paid);
      expect(order.provider, 'payme');
      expect(order.isPaid, isTrue);
      expect(order.isCancelled, isFalse);
      expect(order.isPending, isFalse);
      expect(order.isTerminal, isTrue);
      expect(order.paidAt, DateTime.utc(2025, 1, 10, 12, 1, 23));
      expect(order.displayedAt, order.paidAt);
    });

    test('derives amount_uzs from tiyin when only tiyin is sent', () {
      final order = PaymentOrder.fromJson(<String, dynamic>{
        'id': 'ord-2',
        'plan_code': 'logoped_pro',
        'amount_tiyin': 14900000,
        'state': 'pending',
        'provider': 'click',
        'created_at': '2025-02-01T08:00:00Z',
      });
      expect(order.amountUzs, 149000);
      expect(order.amountTiyin, 14900000);
      expect(order.state, PaymentOrderState.pending);
      expect(order.isPending, isTrue);
      expect(order.isTerminal, isFalse);
      expect(order.paidAt, isNull);
      expect(order.cancelledAt, isNull);
      // Pending rows surface the most recent timestamp; with no paid /
      // cancelled / updated value we fall back to created_at.
      expect(order.displayedAt, DateTime.utc(2025, 2, 1, 8));
    });

    test('cancelled orders surface cancelled_at as the displayed date', () {
      final order = PaymentOrder.fromJson(<String, dynamic>{
        'id': 'ord-3',
        'plan_code': 'parent_pro',
        'amount_tiyin': 3900000,
        'state': 'cancelled',
        'provider': 'payme',
        'created_at': '2025-03-01T07:00:00Z',
        'cancelled_at': '2025-03-01T07:30:00Z',
      });
      expect(order.isCancelled, isTrue);
      expect(order.displayedAt, DateTime.utc(2025, 3, 1, 7, 30));
    });

    test('tolerates missing / unknown fields without throwing', () {
      final order = PaymentOrder.fromJson(<String, dynamic>{
        'plan_code': 'unknown-plan',
      });
      expect(order.id, isEmpty);
      expect(order.amountUzs, 0);
      expect(order.amountTiyin, 0);
      expect(order.state, PaymentOrderState.created);
      expect(order.provider, 'unknown');
      expect(order.isPending, isTrue);
    });
  });

  group('PaymentOrderPage', () {
    test('empty constant is a singleton with no items', () {
      expect(PaymentOrderPage.empty.items, isEmpty);
      expect(PaymentOrderPage.empty.isEmpty, isTrue);
      expect(PaymentOrderPage.empty.hasMore, isFalse);
      expect(PaymentOrderPage.empty.nextCursor, isNull);
    });
  });

  group('PaymentOrderState', () {
    test('terminal set excludes in-flight states', () {
      expect(PaymentOrderState.terminal,
          containsAll([PaymentOrderState.paid, PaymentOrderState.cancelled]));
      expect(PaymentOrderState.terminal,
          isNot(contains(PaymentOrderState.pending)));
      expect(PaymentOrderState.terminal,
          isNot(contains(PaymentOrderState.created)));
    });
  });
}
