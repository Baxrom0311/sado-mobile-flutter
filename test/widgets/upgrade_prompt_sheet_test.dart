import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/billing_interceptor.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/upgrade_prompt_sheet.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => UpgradePromptSheet.show(
                    ctx,
                    notice: const PlanLimitNotice(
                      metric: 'exercises_per_day',
                      limit: 3,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/subscription',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('SUBSCRIPTION_STUB')),
          ),
        ),
      ],
    );

Widget _wrap({Locale locale = const Locale('uz')}) {
  return MaterialApp.router(
    theme: AppTheme.light,
    locale: locale,
    localizationsDelegates: const [
      L.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L.supportedLocales,
    routerConfig: _router(),
  );
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('UpgradePromptSheet renders title, mascot, body and CTAs',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await _openSheet(tester);

    expect(find.text('Bepul reja chegarasi'), findsOneWidget);
    expect(find.byKey(const Key('planLimit.upgradeCta')), findsOneWidget);
    expect(find.byKey(const Key('planLimit.dismiss')), findsOneWidget);
    expect(
      find.textContaining('Bugungi mashq chegarasiga'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('planLimit.dismiss')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Bepul reja chegarasi'), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('UpgradePromptSheet upgrade CTA dismisses and routes',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await _openSheet(tester);

    await tester.tap(find.byKey(const Key('planLimit.upgradeCta')));
    // Sheet pops, then a post-frame callback navigates.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('SUBSCRIPTION_STUB'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('UpgradePromptSheet picks the AI body for ai_analysis metric',
      (tester) async {
    Widget app = MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('uz'),
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () => UpgradePromptSheet.show(
                ctx,
                notice: const PlanLimitNotice(
                  metric: 'ai_analysis',
                  limit: 5,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.textContaining('intellekt tahlillari', findRichText: true),
      findsOneWidget,
    );

    // Dismiss and clean up.
    await tester.tap(find.byKey(const Key('planLimit.dismiss')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _disposeTree(tester);
  });

  testWidgets(
      'UpgradePromptSheet falls back to the generic body for an unknown metric',
      (tester) async {
    Widget app = MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('uz'),
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () => UpgradePromptSheet.show(
                ctx,
                notice: const PlanLimitNotice(
                  metric: 'something_new',
                  limit: 0,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.textContaining('Bepul rejada bu amal', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('planLimit.dismiss')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _disposeTree(tester);
  });
}
