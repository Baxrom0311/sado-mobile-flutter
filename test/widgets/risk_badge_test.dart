import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/risk_badge.dart';

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
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('RiskLevel.fromApi', () {
    test('maps green and low to RiskLevel.low', () {
      expect(RiskLevel.fromApi('green'), RiskLevel.low);
      expect(RiskLevel.fromApi('low'), RiskLevel.low);
    });

    test('maps yellow and medium to RiskLevel.medium', () {
      expect(RiskLevel.fromApi('yellow'), RiskLevel.medium);
      expect(RiskLevel.fromApi('medium'), RiskLevel.medium);
    });

    test('maps red and high to RiskLevel.high', () {
      expect(RiskLevel.fromApi('red'), RiskLevel.high);
      expect(RiskLevel.fromApi('high'), RiskLevel.high);
    });

    test('null and unknown strings degrade to RiskLevel.unknown', () {
      expect(RiskLevel.fromApi(null), RiskLevel.unknown);
      expect(RiskLevel.fromApi(''), RiskLevel.unknown);
      expect(RiskLevel.fromApi('something_new'), RiskLevel.unknown);
    });

    test('icons differ between buckets so they stay visually distinct', () {
      final icons = {
        RiskLevel.low.icon,
        RiskLevel.medium.icon,
        RiskLevel.high.icon,
        RiskLevel.unknown.icon,
      };
      expect(icons.length, 4);
    });

    test('colors differ between buckets so they stay visually distinct', () {
      final colors = {
        RiskLevel.low.color.toARGB32(),
        RiskLevel.medium.color.toARGB32(),
        RiskLevel.high.color.toARGB32(),
        RiskLevel.unknown.color.toARGB32(),
      };
      expect(colors.length, 4);
    });
  });

  group('RiskBadge widget', () {
    testWidgets('renders the localized Uzbek label for each known risk',
        (tester) async {
      for (final entry in {
        RiskLevel.low: 'Xavf past',
        RiskLevel.medium: "Xavf o'rtacha",
        RiskLevel.high: 'Xavf yuqori',
        RiskLevel.unknown: 'Xavf aniqlanmadi',
      }.entries) {
        await tester.pumpWidget(_wrap(RiskBadge(level: entry.key)));
        expect(
          find.text(entry.value),
          findsOneWidget,
          reason: 'expected "${entry.value}" for ${entry.key}',
        );
      }
    });

    testWidgets('renders the Russian label when locale=ru', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RiskBadge(level: RiskLevel.high),
          locale: const Locale('ru'),
        ),
      );
      expect(find.text('Высокий риск'), findsOneWidget);
    });

    testWidgets('factory fromApi maps the raw API string correctly',
        (tester) async {
      await tester.pumpWidget(
        _wrap(RiskBadge.fromApi(risk: 'green')),
      );
      expect(find.text('Xavf past'), findsOneWidget);
    });

    testWidgets('honors a caller-supplied label override', (tester) async {
      await tester.pumpWidget(
        _wrap(const RiskBadge(level: RiskLevel.low, label: 'Custom!')),
      );
      expect(find.text('Custom!'), findsOneWidget);
      expect(find.text('Xavf past'), findsNothing);
    });

    testWidgets(
        'small variant lays out tighter than large for the same content',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const RiskBadge(level: RiskLevel.low, size: RiskBadgeSize.small)),
      );
      final smallSize = tester.getSize(find.byType(RiskBadge));

      await tester.pumpWidget(
        _wrap(const RiskBadge(level: RiskLevel.low, size: RiskBadgeSize.large)),
      );
      final largeSize = tester.getSize(find.byType(RiskBadge));

      expect(largeSize.width, greaterThan(smallSize.width));
      expect(largeSize.height, greaterThan(smallSize.height));
    });
  });

  group('RiskDot widget', () {
    testWidgets('paints with a non-zero size', (tester) async {
      await tester.pumpWidget(
        _wrap(const RiskDot(level: RiskLevel.high, size: 18)),
      );
      final size = tester.getSize(find.byType(RiskDot));
      expect(size.width, 18);
      expect(size.height, 18);
    });

    testWidgets('factory fromApi resolves the API string', (tester) async {
      await tester.pumpWidget(
        _wrap(RiskDot.fromApi(risk: 'red')),
      );
      // The dot is painted with the high-risk color, which is the danger color
      // from the design tokens.
      final container =
          tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, RiskLevel.high.color);
    });
  });
}
