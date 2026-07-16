import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/billing_api.dart';
import 'package:sado_mobile/data/local/preferences.dart';
import 'package:sado_mobile/data/models/subscription_plan.dart';
import 'package:sado_mobile/features/subscription/widgets/payment_method_sheet.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

/// Widget-test harness for the [PaymentMethodSheet]. Mounts the sheet
/// directly on top of a minimal [MaterialApp] so we don't depend on
/// the larger app shell or the live billing API.
///
/// The sheet renders the [ParrotMascot], which keeps a perpetual
/// blink/breathe animation running while mounted. That means
/// [WidgetTester.pumpAndSettle] is not safe here — it would loop
/// forever waiting for the mascot's controllers to idle. Every test
/// uses explicit `pump(Duration)` calls instead so we drive the state
/// machine deterministically.
class _ProbeApp extends StatelessWidget {
  const _ProbeApp({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(Preferences.inMemory()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('uz'),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L.supportedLocales,
        home: Scaffold(body: SafeArea(child: child)),
      ),
    );
  }
}

const _testPlan = SubscriptionPlan(
  id: 'parent_pro',
  nameUz: 'Premium',
  nameRu: 'Премиум',
  priceUzs: 39000,
  limits: SubscriptionLimits(
    exercisesPerDay: -1,
    aiAnalysesPerMonth: -1,
    maxChildren: 5,
  ),
  features: ['all_exercises', 'full_ai_analysis'],
);

/// Pumps a few frames so async work (the checkout future) and the
/// entrance animations resolve, without waiting on the mascot's
/// continuous repaint.
Future<void> _drive(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  // Larger surface so the sheet's full content fits without overflow
  // diagnostics on the default 800x600 test viewport.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets(
    'PaymentMethodSheet renders the picker with both providers, plan '
    'name and the security note',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_ProbeApp(
        child: PaymentMethodSheet(
          plan: _testPlan,
          planDisplayName: 'Premium',
          checkoutOverride: ({required planCode, required provider}) async {
            fail('checkout should not fire until the user picks a provider');
          },
        ),
      ));
      await _drive(tester);

      expect(find.byKey(const Key('payment.picker')), findsOneWidget);
      expect(find.byKey(const Key('payment.picker.payme')), findsOneWidget);
      expect(find.byKey(const Key('payment.picker.click')), findsOneWidget);
      expect(find.text('Payme'), findsOneWidget);
      expect(find.text('Click'), findsOneWidget);
      expect(find.textContaining('Premium'), findsWidgets);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.byKey(const Key('payment.picker.close')), findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'tapping Payme transitions through Loading → Ready and shows the URL',
    (tester) async {
      useTallSurface(tester);
      Map<String, String>? captured;
      Future<CheckoutSession> checkout(
          {required String planCode, required String provider}) async {
        captured = {'planCode': planCode, 'provider': provider};
        // Tiny delay so the loading state is observable.
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return const CheckoutSession(
          url: 'https://checkout.paycom.uz/test-token',
          provider: 'payme',
          orderId: 'ord-1',
        );
      }

      await tester.pumpWidget(_ProbeApp(
        child: PaymentMethodSheet(
          plan: _testPlan,
          planDisplayName: 'Premium',
          checkoutOverride: checkout,
        ),
      ));
      await _drive(tester);

      await tester.tap(find.byKey(const Key('payment.picker.payme')));
      await tester.pump();
      expect(find.byKey(const Key('payment.loading')), findsOneWidget);

      // Drive past the 30ms delay and the Ready entrance animation.
      await _drive(tester);
      await _drive(tester);

      expect(find.byKey(const Key('payment.ready')), findsOneWidget);
      expect(find.byKey(const Key('payment.ready.url')), findsOneWidget);
      expect(
        find.text('https://checkout.paycom.uz/test-token'),
        findsOneWidget,
      );
      expect(captured, {'planCode': 'parent_pro', 'provider': 'payme'});

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'tapping Copy URL stores the link on the device clipboard and '
    'surfaces the confirmation snackbar',
    (tester) async {
      useTallSurface(tester);
      String? clipboardCaptured;
      Future<void> copyOverride(String url) async {
        clipboardCaptured = url;
      }

      await tester.pumpWidget(_ProbeApp(
        child: PaymentMethodSheet(
          plan: _testPlan,
          planDisplayName: 'Premium',
          checkoutOverride: ({required planCode, required provider}) async =>
              const CheckoutSession(
            url: 'https://my.click.uz/checkout/abc',
            provider: 'click',
          ),
          clipboardOverride: copyOverride,
        ),
      ));
      await _drive(tester);

      await tester.tap(find.byKey(const Key('payment.picker.click')));
      await _drive(tester);
      await _drive(tester);

      await tester.tap(find.byKey(const Key('payment.ready.copy')));
      await _drive(tester);

      expect(clipboardCaptured, 'https://my.click.uz/checkout/abc');
      expect(find.byType(SnackBar), findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'BillingNotImplemented degrades the sheet to the friendly '
    '"coming soon" state instead of an error',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_ProbeApp(
        child: PaymentMethodSheet(
          plan: _testPlan,
          planDisplayName: 'Premium',
          checkoutOverride: ({required planCode, required provider}) async {
            throw const BillingNotImplemented(
              'checkout endpoint not deployed',
            );
          },
        ),
      ));
      await _drive(tester);
      await tester.tap(find.byKey(const Key('payment.picker.payme')));
      await _drive(tester);
      await _drive(tester);

      expect(find.byKey(const Key('payment.comingSoon')), findsOneWidget);
      expect(
        find.byKey(const Key('payment.comingSoon.close')),
        findsOneWidget,
      );
      // Picker is no longer visible after the degrade.
      expect(find.byKey(const Key('payment.picker')), findsNothing);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'a generic API failure shows the error state with a working Retry CTA',
    (tester) async {
      useTallSurface(tester);
      var calls = 0;
      Future<CheckoutSession> checkout(
          {required String planCode, required String provider}) async {
        calls += 1;
        if (calls == 1) {
          throw StateError('boom');
        }
        return const CheckoutSession(
          url: 'https://checkout.paycom.uz/retried',
          provider: 'payme',
        );
      }

      await tester.pumpWidget(_ProbeApp(
        child: PaymentMethodSheet(
          plan: _testPlan,
          planDisplayName: 'Premium',
          checkoutOverride: checkout,
        ),
      ));
      await _drive(tester);

      await tester.tap(find.byKey(const Key('payment.picker.payme')));
      await _drive(tester);
      await _drive(tester);

      expect(find.byKey(const Key('payment.error')), findsOneWidget);
      expect(find.byKey(const Key('payment.error.retry')), findsOneWidget);

      // Retry kicks the same provider back through the loading path
      // and resolves to Ready on the second call.
      await tester.tap(find.byKey(const Key('payment.error.retry')));
      await _drive(tester);
      await _drive(tester);
      expect(find.byKey(const Key('payment.ready')), findsOneWidget);
      expect(calls, 2);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'production clipboard path uses the platform channel when no '
    'override is passed',
    (tester) async {
      useTallSurface(tester);
      // Mock the system clipboard so the test doesn't depend on the
      // host platform implementation.
      String? clipboardText;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>?;
          clipboardText = args?['text']?.toString();
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboardText ?? ''};
        }
        return null;
      });
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(_ProbeApp(
        child: PaymentMethodSheet(
          plan: _testPlan,
          planDisplayName: 'Premium',
          checkoutOverride: ({required planCode, required provider}) async =>
              const CheckoutSession(
            url: 'https://checkout.paycom.uz/prod',
            provider: 'payme',
          ),
        ),
      ));
      await _drive(tester);
      await tester.tap(find.byKey(const Key('payment.picker.payme')));
      await _drive(tester);
      await _drive(tester);
      await tester.tap(find.byKey(const Key('payment.ready.copy')));
      await _drive(tester);

      expect(clipboardText, 'https://checkout.paycom.uz/prod');

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'tapping Open in browser hands the URL to the platform launcher '
    'and confirms the handoff with a snackbar (without dismissing '
    'the sheet — the user has not paid yet)',
    (tester) async {
      useTallSurface(tester);
      String? launchedUrl;
      Future<bool> launcher(String url) async {
        launchedUrl = url;
        return true;
      }

      await tester.pumpWidget(_ProbeApp(
        child: PaymentMethodSheet(
          plan: _testPlan,
          planDisplayName: 'Premium',
          checkoutOverride: ({required planCode, required provider}) async =>
              const CheckoutSession(
            url: 'https://checkout.paycom.uz/launch-me',
            provider: 'payme',
          ),
          launcherOverride: launcher,
        ),
      ));
      await _drive(tester);
      await tester.tap(find.byKey(const Key('payment.picker.payme')));
      await _drive(tester);
      await _drive(tester);

      // The Open CTA is the primary action on the ready view.
      expect(find.byKey(const Key('payment.ready.open')), findsOneWidget);
      await tester.tap(find.byKey(const Key('payment.ready.open')));
      await _drive(tester);

      expect(launchedUrl, 'https://checkout.paycom.uz/launch-me');
      expect(find.byType(SnackBar), findsOneWidget);
      // Sheet stays open — the user hasn't actually paid yet.
      expect(find.byKey(const Key('payment.ready')), findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'when the launcher refuses (no browser, parental lock) the sheet '
    'auto-falls back to the clipboard and surfaces the localized '
    '"open failed" snackbar so the user is never blocked',
    (tester) async {
      useTallSurface(tester);
      String? clipboardCaptured;
      Future<bool> launcher(String url) async => false;
      Future<void> copyOverride(String url) async {
        clipboardCaptured = url;
      }

      await tester.pumpWidget(_ProbeApp(
        child: PaymentMethodSheet(
          plan: _testPlan,
          planDisplayName: 'Premium',
          checkoutOverride: ({required planCode, required provider}) async =>
              const CheckoutSession(
            url: 'https://checkout.paycom.uz/no-browser',
            provider: 'payme',
          ),
          launcherOverride: launcher,
          clipboardOverride: copyOverride,
        ),
      ));
      await _drive(tester);
      await tester.tap(find.byKey(const Key('payment.picker.payme')));
      await _drive(tester);
      await _drive(tester);
      await tester.tap(find.byKey(const Key('payment.ready.open')));
      await _drive(tester);

      expect(clipboardCaptured, 'https://checkout.paycom.uz/no-browser');
      expect(find.byType(SnackBar), findsOneWidget);
      // Sheet stays open so the user can try copying explicitly.
      expect(find.byKey(const Key('payment.ready')), findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'production launcher path uses the real ExternalUrlLauncher when '
    'no override is passed (here we just assert the CTA is wired and '
    'enabled — the platform plugin itself is exercised in the '
    'ExternalUrlLauncher unit tests)',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_ProbeApp(
        child: PaymentMethodSheet(
          plan: _testPlan,
          planDisplayName: 'Premium',
          checkoutOverride: ({required planCode, required provider}) async =>
              const CheckoutSession(
            url: 'https://checkout.paycom.uz/wired',
            provider: 'payme',
          ),
        ),
      ));
      await _drive(tester);
      await tester.tap(find.byKey(const Key('payment.picker.payme')));
      await _drive(tester);
      await _drive(tester);

      final openButton = find.byKey(const Key('payment.ready.open'));
      expect(openButton, findsOneWidget);
      // Sanity-check the localized label so a future ARB rename can't
      // silently lose the primary CTA copy.
      expect(find.text('Brauzerda ochish'), findsOneWidget);
    },
  );
}
