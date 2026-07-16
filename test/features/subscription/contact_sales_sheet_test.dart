import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/subscription_plan.dart';
import 'package:sado_mobile/data/services/external_url_launcher.dart';
import 'package:sado_mobile/features/subscription/widgets/contact_sales_sheet.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

class _RecordingLauncher implements ExternalUrlLauncher {
  String? lastOpenUrl;
  String? lastMailtoAddress;
  String? lastMailtoSubject;
  String? lastMailtoBody;
  String? lastTel;
  bool nextOpen = true;
  bool nextMailto = true;
  bool nextTel = true;

  @override
  Future<bool> open(String url) async {
    lastOpenUrl = url;
    return nextOpen;
  }

  @override
  Future<bool> openMailto(
    String address, {
    String? subject,
    String? body,
  }) async {
    lastMailtoAddress = address;
    lastMailtoSubject = subject;
    lastMailtoBody = body;
    return nextMailto;
  }

  @override
  Future<bool> openTel(String phone) async {
    lastTel = phone;
    return nextTel;
  }
}

Widget _host({
  required SubscriptionPlan plan,
  required String planDisplayName,
  required ExternalUrlLauncher launcher,
  Locale locale = const Locale('uz'),
}) {
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
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            key: const Key('open'),
            onPressed: () => ContactSalesSheet.show(
              context,
              plan: plan,
              planDisplayName: planDisplayName,
              launcher: launcher,
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open')));
  await tester.pump();
  // Sheet entrance + fade-in animation finishes well under 400ms.
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const logoped = SubscriptionPlan(
    id: 'logoped_pro',
    nameUz: 'Logoped',
    nameRu: 'Логопед',
    descriptionUz: 'desc uz',
    descriptionRu: 'desc ru',
    priceUzs: 149000,
    priceUsd: 12,
    limits: SubscriptionLimits(
      exercisesPerDay: -1,
      aiAnalysesPerMonth: -1,
      maxChildren: -1,
      maxPatients: 50,
    ),
    features: ['patient_management'],
    sortOrder: 20,
  );

  testWidgets(
      'ContactSalesSheet renders the title, plan-name intro and copy CTAs',
      (tester) async {
    await tester.pumpWidget(_host(
      plan: logoped,
      planDisplayName: 'Logoped',
      launcher: _RecordingLauncher(),
    ));
    await _openSheet(tester);

    expect(find.byKey(const Key('contactSales.title')), findsOneWidget);
    // Intro mentions the plan name so the user knows what they're
    // contacting sales about.
    expect(
      find.textContaining('Logoped reja'),
      findsOneWidget,
    );
    // Both contact rows render with their localized labels.
    expect(find.byKey(const Key('contactSales.email.label')), findsOneWidget);
    expect(find.byKey(const Key('contactSales.phone.label')), findsOneWidget);
    expect(find.byKey(const Key('contactSales.email.value')), findsOneWidget);
    expect(find.byKey(const Key('contactSales.phone.value')), findsOneWidget);
    expect(find.byKey(const Key('contactSales.email.copy')), findsOneWidget);
    expect(find.byKey(const Key('contactSales.phone.copy')), findsOneWidget);
    // CTAs.
    expect(find.byKey(const Key('contactSales.email.cta')), findsOneWidget);
    expect(find.byKey(const Key('contactSales.phone.cta')), findsOneWidget);
    expect(find.byKey(const Key('contactSales.close')), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'tapping the email CTA fires openMailto with subject + body filled',
      (tester) async {
    final launcher = _RecordingLauncher();
    await tester.pumpWidget(_host(
      plan: logoped,
      planDisplayName: 'Logoped',
      launcher: launcher,
    ));
    await _openSheet(tester);

    await tester.tap(find.byKey(const Key('contactSales.email.cta')));
    await tester.pump();

    expect(launcher.lastMailtoAddress, 'sales@sado.uz');
    expect(launcher.lastMailtoSubject, contains('Logoped'));
    expect(launcher.lastMailtoBody, contains('Logoped'));
    // The phone intent should NOT have been fired.
    expect(launcher.lastTel, isNull);

    await _disposeTree(tester);
  });

  testWidgets(
      'tapping the phone CTA fires openTel with the support number',
      (tester) async {
    final launcher = _RecordingLauncher();
    await tester.pumpWidget(_host(
      plan: logoped,
      planDisplayName: 'Logoped',
      launcher: launcher,
    ));
    await _openSheet(tester);

    await tester.tap(find.byKey(const Key('contactSales.phone.cta')));
    await tester.pump();

    expect(launcher.lastTel, '+998 71 200 00 00');
    // Email intent should NOT have been fired.
    expect(launcher.lastMailtoAddress, isNull);

    await _disposeTree(tester);
  });

  testWidgets(
      'when openMailto fails, the email is copied to the clipboard '
      'and a Copied snack is shown',
      (tester) async {
    // Capture clipboard writes via the platform channel mock so the
    // assertion is platform-independent.
    final List<String> copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final launcher = _RecordingLauncher()..nextMailto = false;
    await tester.pumpWidget(_host(
      plan: logoped,
      planDisplayName: 'Logoped',
      launcher: launcher,
    ));
    await _openSheet(tester);

    await tester.tap(find.byKey(const Key('contactSales.email.cta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(copied, contains('sales@sado.uz'));
    // Localized "Copied" snack surfaces to confirm the fallback.
    expect(find.text('Nusxa olindi'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
      'tapping the email row copy icon writes the email to the clipboard',
      (tester) async {
    final List<String> copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final launcher = _RecordingLauncher();
    await tester.pumpWidget(_host(
      plan: logoped,
      planDisplayName: 'Logoped',
      launcher: launcher,
    ));
    await _openSheet(tester);

    await tester.tap(find.byKey(const Key('contactSales.email.copy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(copied, contains('sales@sado.uz'));

    await _disposeTree(tester);
  });

  testWidgets('tapping Close dismisses the sheet', (tester) async {
    final launcher = _RecordingLauncher();
    await tester.pumpWidget(_host(
      plan: logoped,
      planDisplayName: 'Logoped',
      launcher: launcher,
    ));
    await _openSheet(tester);
    expect(find.byKey(const Key('contactSales.title')), findsOneWidget);

    await tester.tap(find.byKey(const Key('contactSales.close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('contactSales.title')), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('renders Russian copy when locale is ru', (tester) async {
    await tester.pumpWidget(_host(
      plan: logoped,
      planDisplayName: 'Логопед',
      launcher: _RecordingLauncher(),
      locale: const Locale('ru'),
    ));
    await _openSheet(tester);

    // Sheet title localizes to "Тариф для специалистов".
    expect(find.text('Тариф для специалистов'), findsOneWidget);
    // Intro mentions the localized plan name.
    expect(find.textContaining('Логопед'), findsWidgets);

    await _disposeTree(tester);
  });
}
