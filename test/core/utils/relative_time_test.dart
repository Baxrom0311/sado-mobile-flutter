import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/utils/relative_time.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

/// Pumps an empty MaterialApp configured with the project's L10n delegates
/// and returns the resolved [L] for the locale provided. Lets us run pure
/// formatter logic against the actual ARB-backed strings without spinning
/// up a real screen.
Future<L> _resolveL(WidgetTester tester, Locale locale) async {
  late L resolved;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      home: Builder(
        builder: (context) {
          resolved = L.of(context)!;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return resolved;
}

void main() {
  // Anchor "now" so every assertion is deterministic regardless of CI clock.
  final now = DateTime(2026, 6, 11, 12, 0, 0);

  testWidgets('"today" wins for same-day inputs (uz)', (tester) async {
    final l = await _resolveL(tester, const Locale('uz'));
    expect(formatRelativeDate(l, now, now: now), 'Bugun');
    expect(
      formatRelativeDate(l, now.subtract(const Duration(hours: 5)), now: now),
      'Bugun',
    );
  });

  testWidgets('"yesterday" wins for the day before', (tester) async {
    final l = await _resolveL(tester, const Locale('uz'));
    final yest = now.subtract(const Duration(days: 1));
    expect(formatRelativeDate(l, yest, now: now), 'Kecha');
  });

  testWidgets('< 7 days uses the localized "N kun oldin" plural',
      (tester) async {
    final l = await _resolveL(tester, const Locale('uz'));
    final three = now.subtract(const Duration(days: 3));
    expect(formatRelativeDate(l, three, now: now), '3 kun oldin');
  });

  testWidgets('< 30 days collapses to "N hafta oldin"', (tester) async {
    final l = await _resolveL(tester, const Locale('uz'));
    final twoWeeks = now.subtract(const Duration(days: 14));
    expect(formatRelativeDate(l, twoWeeks, now: now), '2 hafta oldin');
  });

  testWidgets('< 12 months collapses to "N oy oldin"', (tester) async {
    final l = await _resolveL(tester, const Locale('uz'));
    final twoMonths = now.subtract(const Duration(days: 65));
    expect(formatRelativeDate(l, twoMonths, now: now), '2 oy oldin');
  });

  testWidgets('> 1 year falls back to dd.MM.yyyy', (tester) async {
    final l = await _resolveL(tester, const Locale('uz'));
    final old = DateTime(2024, 3, 7);
    expect(formatRelativeDate(l, old, now: now), '07.03.2024');
  });

  testWidgets('Russian locale also returns localized copy', (tester) async {
    final l = await _resolveL(tester, const Locale('ru'));
    expect(formatRelativeDate(l, now, now: now), 'Сегодня');
    final yest = now.subtract(const Duration(days: 1));
    expect(formatRelativeDate(l, yest, now: now), 'Вчера');
  });
}
