import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/models/subscription_plan.dart';
import 'package:sado_mobile/data/models/subscription_plan_labels.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

/// Loads `L` for [locale] from the generated AppLocalizations bundle.
/// Using the real loader avoids any drift between this test and the
/// shipped ARB files.
Future<L> _loadLabels(String locale) async {
  return L.delegate.load(Locale(locale));
}

Widget _harness({required Locale locale, required Widget child}) {
  return MaterialAppLocalizationsHarness(locale: locale, child: child);
}

/// Tiny harness that wraps a child widget with the localization
/// delegates needed by [L]. Used by the `BuildContext` extension
/// tests below to materialise a real context.
class MaterialAppLocalizationsHarness extends StatelessWidget {
  const MaterialAppLocalizationsHarness({
    super.key,
    required this.locale,
    required this.child,
  });

  final Locale locale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xFF000000),
      locale: locale,
      supportedLocales: L.supportedLocales,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      builder: (context, _) => child,
    );
  }
}

void main() {
  group('SubscriptionPlanLabels.normalise', () {
    test('null and whitespace-only inputs collapse to empty', () {
      expect(SubscriptionPlanLabels.normalise(null), '');
      expect(SubscriptionPlanLabels.normalise('   '), '');
    });

    test('uppercase / mixed case slugs are lower-cased', () {
      expect(SubscriptionPlanLabels.normalise('Logoped_Pro'),
          SubscriptionPlanLabels.logopedPro);
      expect(SubscriptionPlanLabels.normalise('  CLINIC '),
          SubscriptionPlanLabels.clinic);
    });
  });

  group('SubscriptionPlanLabels.name', () {
    test('returns localised Uzbek strings for every known plan code',
        () async {
      final l = await _loadLabels('uz');
      expect(SubscriptionPlanLabels.name(l, 'free'), 'Bepul');
      expect(SubscriptionPlanLabels.name(l, 'parent_pro'), 'Premium');
      expect(SubscriptionPlanLabels.name(l, 'logoped'), 'Logoped');
      expect(SubscriptionPlanLabels.name(l, 'logoped_pro'), 'Logoped');
      expect(SubscriptionPlanLabels.name(l, 'clinic'), 'Klinika');
      expect(SubscriptionPlanLabels.name(l, 'clinic_basic'), 'Klinika');
      expect(SubscriptionPlanLabels.name(l, 'clinic_premium'),
          'Klinika Premium');
    });

    test('returns localised Russian strings for every known plan code',
        () async {
      final l = await _loadLabels('ru');
      expect(SubscriptionPlanLabels.name(l, 'free'), 'Бесплатно');
      expect(SubscriptionPlanLabels.name(l, 'parent_pro'), 'Premium');
      expect(SubscriptionPlanLabels.name(l, 'logoped_pro'), 'Логопед');
      expect(SubscriptionPlanLabels.name(l, 'clinic'), 'Клиника');
      expect(SubscriptionPlanLabels.name(l, 'clinic_premium'),
          'Клиника Премиум');
    });

    test('humanises unknown slugs instead of leaking raw snake_case',
        () async {
      final l = await _loadLabels('uz');
      expect(SubscriptionPlanLabels.name(l, 'parent_lite'), 'Parent Lite');
      expect(SubscriptionPlanLabels.name(l, 'mystery'), 'Mystery');
    });

    test('falls back to the placeholder for empty input', () async {
      final l = await _loadLabels('uz');
      // Uz placeholder.
      expect(SubscriptionPlanLabels.name(l, ''), 'Reja');
      expect(SubscriptionPlanLabels.name(l, null), 'Reja');
    });
  });

  group('SubscriptionPlanLabels.tagline', () {
    test('returns the localised tagline for known plans', () async {
      final l = await _loadLabels('uz');
      expect(SubscriptionPlanLabels.tagline(l, 'free'),
          'Boshlash uchun ajoyib reja');
      expect(SubscriptionPlanLabels.tagline(l, 'parent_pro'),
          contains('Cheksiz'));
      expect(SubscriptionPlanLabels.tagline(l, 'clinic_premium'),
          contains('premium'));
    });

    test('returns empty string for unknown codes (UI hides the row)',
        () async {
      final l = await _loadLabels('uz');
      expect(SubscriptionPlanLabels.tagline(l, 'parent_lite'), '');
      expect(SubscriptionPlanLabels.tagline(l, ''), '');
    });
  });

  group('SubscriptionPlanLabels.nameForPlan', () {
    test(
        'prefers the API-provided name when it differs from the canonical '
        'fallback (custom server plans win)', () async {
      final l = await _loadLabels('uz');
      const plan = SubscriptionPlan(
        id: 'parent_lite',
        nameUz: 'Lite Reja',
        nameRu: 'Lite план',
        priceUzs: 19000,
        limits: SubscriptionLimits(),
        features: <String>[],
      );
      expect(SubscriptionPlanLabels.nameForPlan(l, plan, 'uz'), 'Lite Reja');
      expect(SubscriptionPlanLabels.nameForPlan(l, plan, 'ru'), 'Lite план');
    });

    test(
        'falls back to the canonical localised name when the API ships '
        'the plan id as its own name (no human label)', () async {
      final l = await _loadLabels('uz');
      const plan = SubscriptionPlan(
        id: 'parent_pro',
        nameUz: 'parent_pro',
        nameRu: 'parent_pro',
        priceUzs: 39000,
        limits: SubscriptionLimits(),
        features: <String>[],
      );
      expect(SubscriptionPlanLabels.nameForPlan(l, plan, 'uz'), 'Premium');
    });
  });

  group('SubscriptionPlanLabelContext extension', () {
    testWidgets('subscriptionPlanName resolves through BuildContext',
        (tester) async {
      String? rendered;
      await tester.pumpWidget(
        _harness(
          locale: const Locale('uz'),
          child: Builder(
            builder: (context) {
              rendered = context.subscriptionPlanName('logoped_pro');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(rendered, 'Logoped');
    });
  });
}
