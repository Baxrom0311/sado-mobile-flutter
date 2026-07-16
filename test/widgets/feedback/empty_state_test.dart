import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/feedback/empty_state.dart';
import 'package:sado_mobile/widgets/parrot_mascot.dart';

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
    home: Scaffold(body: child),
  );
}

void main() {
  group('EmptyState', () {
    testWidgets('renders title, body and the parrot mascot', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(
          title: 'Hali bola qo\'shilmagan',
          body: 'Boshlash uchun birinchi bolangizni qo\'shing',
        ),
      ));
      // Initial frame + the fade-in tween.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Hali bola qo\'shilmagan'), findsOneWidget);
      expect(
        find.text('Boshlash uchun birinchi bolangizni qo\'shing'),
        findsOneWidget,
      );
      expect(find.byType(ParrotMascot), findsOneWidget);
    });

    testWidgets('hides the body when null', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(title: 'Bo\'sh'),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Bo\'sh'), findsOneWidget);
      // Only the title text widget — no extra body row beneath it.
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('shows the CTA only when both label and onCta are provided',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        EmptyState(
          title: 'Mashqlar topilmadi',
          body: 'Tez orada qo\'shiladi',
          ctaLabel: 'Qayta urinish',
          ctaIcon: Icons.refresh_rounded,
          onCta: () => taps++,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      final cta = find.text('Qayta urinish');
      expect(cta, findsOneWidget);

      await tester.tap(cta);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('CTA is hidden when onCta is null even with a label',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(
          title: 'Bo\'sh',
          ctaLabel: 'Qayta urinish',
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Qayta urinish'), findsNothing);
    });

    testWidgets('uses the requested mood on the mascot', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(
          title: 'Hech narsa topilmadi',
          mood: ParrotMood.sad,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      final mascot = tester.widget<ParrotMascot>(find.byType(ParrotMascot));
      expect(mascot.mood, ParrotMood.sad);
    });
  });
}
