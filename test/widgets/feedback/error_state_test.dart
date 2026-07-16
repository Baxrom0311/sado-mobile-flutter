import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/feedback/error_state.dart';
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
  group('ErrorState', () {
    testWidgets('falls back to the localized errorTitle/tryAgainLater/retry '
        'copy when nothing is overridden', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        ErrorState(onRetry: () => taps++),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      // Default Uzbek copy from app_uz.arb.
      expect(find.text('Nimadir noto\'g\'ri ketdi'), findsOneWidget);
      expect(find.text('Keyinroq urinib ko\'ring'), findsOneWidget);

      final retry = find.text('Qayta urinish');
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('translates the default copy when locale=ru', (tester) async {
      await tester.pumpWidget(_wrap(
        ErrorState(onRetry: () {}),
        locale: const Locale('ru'),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Что-то пошло не так'), findsOneWidget);
      expect(find.text('Попробуйте позже'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('hides the retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(_wrap(const ErrorState()));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Qayta urinish'), findsNothing);
    });

    testWidgets('uses the sad parrot mascot', (tester) async {
      await tester.pumpWidget(_wrap(const ErrorState()));
      await tester.pump(const Duration(milliseconds: 400));

      final mascot = tester.widget<ParrotMascot>(find.byType(ParrotMascot));
      expect(mascot.mood, ParrotMood.sad);
    });

    testWidgets('caller-provided overrides win over defaults', (tester) async {
      await tester.pumpWidget(_wrap(
        ErrorState(
          title: 'Bola topilmadi',
          body: 'Iltimos, qayta tanlang',
          retryLabel: 'Yangilash',
          onRetry: () {},
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Bola topilmadi'), findsOneWidget);
      expect(find.text('Iltimos, qayta tanlang'), findsOneWidget);
      expect(find.text('Yangilash'), findsOneWidget);
      // Default localized title should NOT also appear.
      expect(find.text('Nimadir noto\'g\'ri ketdi'), findsNothing);
    });
  });
}
