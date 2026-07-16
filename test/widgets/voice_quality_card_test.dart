import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/voice_quality_card.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('uz')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      L.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('uz'), Locale('ru')],
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  testWidgets('renders nothing for null voice quality', (tester) async {
    await tester.pumpWidget(_wrap(const VoiceQualityCard(voiceQuality: null)));
    expect(find.byType(SizedBox), findsWidgets);
    // Title should NOT appear because the card collapses.
    expect(find.text('Ovoz sifati'), findsNothing);
  });

  testWidgets('renders nothing for an entirely empty voice quality',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const VoiceQualityCard(voiceQuality: VoiceQuality())),
    );
    expect(find.text('Ovoz sifati'), findsNothing);
  });

  testWidgets(
      'renders title, subtitle and one tile per available metric in Uzbek',
      (tester) async {
    const vq = VoiceQuality(
      jitterLocalPct: 0.6,
      shimmerLocalPct: 2.5,
      hnrDb: 22.0,
      speechRateWpm: 130,
    );
    await tester.pumpWidget(_wrap(const VoiceQualityCard(voiceQuality: vq)));

    expect(find.text('Ovoz sifati'), findsOneWidget);
    expect(find.text('Klinik o\'lchovlar bo\'yicha tahlil'), findsOneWidget);
    expect(find.text('Jitter'), findsOneWidget);
    expect(find.text('Shimmer'), findsOneWidget);
    expect(find.text('HNR'), findsOneWidget);
    expect(find.text('Nutq tezligi'), findsOneWidget);
    expect(find.text('Bola ovozi sog\'lom diapazonda'), findsOneWidget);
  });

  testWidgets('formats numerics with the right unit and precision',
      (tester) async {
    const vq = VoiceQuality(
      jitterLocalPct: 0.62,
      shimmerLocalPct: 2.51,
      hnrDb: 22.4,
      speechRateWpm: 129.6,
    );
    await tester.pumpWidget(_wrap(const VoiceQualityCard(voiceQuality: vq)));
    // Two-decimal percent.
    expect(find.text('0.62%'), findsOneWidget);
    expect(find.text('2.51%'), findsOneWidget);
    // One-decimal dB.
    expect(find.text('22.4 dB'), findsOneWidget);
    // Zero-decimal WPM, rounded.
    expect(find.text('130 so\'z/daq'), findsOneWidget);
  });

  testWidgets('omits a tile when its metric is missing', (tester) async {
    // Only jitter — the other three tiles must NOT render.
    const vq = VoiceQuality(jitterLocalPct: 0.6);
    await tester.pumpWidget(_wrap(const VoiceQualityCard(voiceQuality: vq)));
    expect(find.text('Jitter'), findsOneWidget);
    expect(find.text('Shimmer'), findsNothing);
    expect(find.text('HNR'), findsNothing);
    expect(find.text('Nutq tezligi'), findsNothing);
  });

  testWidgets('headline switches to "needs attention" when overall is abnormal',
      (tester) async {
    const vq = VoiceQuality(
      jitterLocalPct: 0.5,
      shimmerLocalPct: 2.0,
      hnrDb: 4.0, // abnormal
      speechRateWpm: 140,
    );
    await tester.pumpWidget(_wrap(const VoiceQualityCard(voiceQuality: vq)));
    expect(
      find.text('Logoped bilan maslahatlashish tavsiya etiladi'),
      findsOneWidget,
    );
  });

  testWidgets('renders Russian copy when locale is ru', (tester) async {
    const vq = VoiceQuality(
      jitterLocalPct: 0.6,
      shimmerLocalPct: 2.5,
      hnrDb: 22.0,
      speechRateWpm: 130,
    );
    await tester.pumpWidget(_wrap(
      const VoiceQualityCard(voiceQuality: vq),
      locale: const Locale('ru'),
    ));
    expect(find.text('Качество голоса'), findsOneWidget);
    expect(find.text('Анализ по клиническим показателям'), findsOneWidget);
    expect(find.text('Темп речи'), findsOneWidget);
    expect(find.text('130 сл/мин'), findsOneWidget);
  });

  testWidgets('exposes a status semantics label so a11y readers can find it',
      (tester) async {
    const vq = VoiceQuality(
      jitterLocalPct: 0.6,
      shimmerLocalPct: 2.5,
      hnrDb: 22.0,
      speechRateWpm: 140,
    );
    await tester.pumpWidget(_wrap(const VoiceQualityCard(voiceQuality: vq)));
    final semantics = tester.getSemantics(find.byType(VoiceQualityCard));
    expect(semantics.label, contains('Ovoz sifati'));
    expect(semantics.label, contains('Me\'yorda'));
  });
}
