import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/subscription_plan.dart';
import 'package:sado_mobile/features/subscription/widgets/usage_card.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('uz')}) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    localizationsDelegates: const [
      L.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L.supportedLocales,
    home: Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets(
      'SubscriptionUsageCard renders the title, every metric and the '
      'period chip in Uzbek', (tester) async {
    final usage = SubscriptionUsage(
      periodStart: DateTime.utc(2025, 6, 13),
      periodEnd: DateTime.utc(2025, 6, 14),
      metrics: const [
        UsageMetric(
          metric: 'assessments_per_day',
          limit: 3,
          used: 2,
          remaining: 1,
        ),
        UsageMetric(
          metric: 'ai_analysis',
          limit: -1,
          used: 12,
        ),
        UsageMetric(
          metric: 'children_total',
          limit: 1,
          used: 0,
          remaining: 1,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(
      SubscriptionUsageCard(usage: usage, locale: 'uz'),
    ));
    await _settle(tester);

    expect(find.text('Joriy davr foydalanuvi'), findsOneWidget);
    expect(find.text('Kunlik baholashlar'), findsOneWidget);
    expect(find.text('AI tahlillari'), findsOneWidget);
    expect(find.text('Bolalar profili'), findsOneWidget);
    // Used / limit chip.
    expect(find.text('2 / 3'), findsOneWidget);
    // Unlimited chip.
    expect(find.text('Cheksiz'), findsOneWidget);
    // Remaining sentence — pluralised form for >1.
    expect(find.textContaining('1 ta qoldi'), findsWidgets);
    // Period chip.
    expect(find.textContaining('Davr'), findsOneWidget);
    // Surface key is stable for downstream tests.
    expect(find.byKey(const Key('subscription.usageCard')), findsOneWidget);
  });

  testWidgets('SubscriptionUsageCard renders Russian copy when locale=ru',
      (tester) async {
    const usage = SubscriptionUsage(
      metrics: [
        UsageMetric(
          metric: 'assessments_per_day',
          limit: 3,
          used: 2,
          remaining: 1,
        ),
      ],
    );
    await tester.pumpWidget(_wrap(
      const SubscriptionUsageCard(usage: usage, locale: 'ru'),
      locale: const Locale('ru'),
    ));
    await _settle(tester);

    expect(find.text('Использование за период'), findsOneWidget);
    expect(find.text('Оценок в день'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets(
      'SubscriptionUsageCard surfaces the upgrade hint and CTA when a '
      'metric is exhausted', (tester) async {
    var pressed = 0;
    const usage = SubscriptionUsage(
      metrics: [
        UsageMetric(
          metric: 'children_total',
          limit: 1,
          used: 1,
          remaining: 0,
        ),
      ],
    );
    await tester.pumpWidget(_wrap(
      SubscriptionUsageCard(
        usage: usage,
        locale: 'uz',
        onUpgrade: () => pressed++,
      ),
    ));
    await _settle(tester);

    expect(find.textContaining('Limitga yetdingiz'), findsOneWidget);
    final cta =
        find.byKey(const Key('subscription.usageCard.exhausted.cta'));
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    await tester.pump();
    expect(pressed, 1);
  });

  testWidgets(
      'SubscriptionUsageCard hides the upgrade CTA when no callback is '
      'provided', (tester) async {
    const usage = SubscriptionUsage(
      metrics: [
        UsageMetric(
          metric: 'children_total',
          limit: 1,
          used: 1,
          remaining: 0,
        ),
      ],
    );
    await tester.pumpWidget(_wrap(
      const SubscriptionUsageCard(usage: usage, locale: 'uz'),
    ));
    await _settle(tester);

    expect(
      find.byKey(const Key('subscription.usageCard.exhausted.cta')),
      findsNothing,
    );
  });

  testWidgets(
      'SubscriptionUsageCard renders the empty placeholder when no '
      'metrics are available', (tester) async {
    await tester.pumpWidget(_wrap(
      const SubscriptionUsageCard(
        usage: SubscriptionUsage.empty,
        locale: 'uz',
      ),
    ));
    await _settle(tester);

    expect(
      find.byKey(const Key('subscription.usageCard.empty')),
      findsOneWidget,
    );
    expect(find.text('Foydalanuv tez orada paydo bo\'ladi'), findsOneWidget);
  });

  testWidgets(
      'SubscriptionUsageCard hero variant renders mascot and speech '
      'bubble for free users', (tester) async {
    const usage = SubscriptionUsage(
      metrics: [
        UsageMetric(metric: 'assessments_per_day', limit: 3, used: 1),
      ],
    );
    await tester.pumpWidget(_wrap(
      const SubscriptionUsageCard(
        usage: usage,
        locale: 'uz',
        heroVariant: true,
      ),
    ));
    await _settle(tester);

    expect(
      find.byKey(const Key('subscription.usageCard.hero')),
      findsOneWidget,
    );
    // Mascot speech bubble copy.
    expect(
      find.textContaining('Tez-tez mashq'),
      findsOneWidget,
    );
  });

  test(
      'UsageMetric.progress never explodes for degenerate values '
      '(NaN / negative / overflow)', () {
    const zeroLimit = UsageMetric(metric: 'foo', limit: 0, used: 5);
    expect(zeroLimit.progress, 0); // limit 0 short-circuits to 0
    const negativeUsed = UsageMetric(metric: 'foo', limit: 3, used: -1);
    expect(negativeUsed.progress, 0);
    const overflowed = UsageMetric(metric: 'foo', limit: 3, used: 99);
    expect(overflowed.progress, 1);
  });
}
