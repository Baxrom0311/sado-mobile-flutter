import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/children/widgets/kindergarten_picker_sheet.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';

/// Renders the picker bare (not as a modal) under a real MaterialApp so the
/// L10n delegates resolve and Riverpod overrides apply.
Widget _wrap({
  required List<Kindergarten> Function(String query) onSearch,
  String? selectedId,
}) {
  return ProviderScope(
    overrides: [
      kindergartensSearchProvider.overrideWith((ref, query) async {
        return onSearch(query);
      }),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      locale: const Locale('uz'),
      // Wrap in a Scaffold + Material so InkWells have a host, and force a
      // fixed-size viewport that matches a phone so the sheet's
      // ConstrainedBox does not collapse to zero.
      home: Scaffold(
        body: KindergartenPickerSheet(
          selectedId: selectedId,
          // Drop debounce so search results appear synchronously in tests.
          debounce: Duration.zero,
        ),
      ),
    ),
  );
}

Kindergarten _kg(String id, String name, {String? address}) =>
    Kindergarten(id: id, name: name, address: address);

void main() {
  testWidgets(
      'KindergartenPickerSheet renders the title, search field and initial results',
      (tester) async {
    await tester.pumpWidget(_wrap(onSearch: (q) {
      return [
        _kg('1', 'Quyosh', address: 'Toshkent'),
        _kg('2', 'Bahor'),
        _kg('3', 'Yulduzcha'),
      ];
    }));
    await tester.pumpAndSettle();

    expect(find.text('Bog\'chani tanlang'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.text('Quyosh'), findsOneWidget);
    expect(find.text('Bahor'), findsOneWidget);
    expect(find.text('Yulduzcha'), findsOneWidget);
    // Address subtitle shown when present.
    expect(find.text('Toshkent'), findsOneWidget);
  });

  testWidgets('typing updates the search query and re-fetches results',
      (tester) async {
    final queries = <String>[];
    await tester.pumpWidget(_wrap(onSearch: (q) {
      queries.add(q);
      if (q == 'qu') {
        return [_kg('1', 'Quyosh')];
      }
      return [
        _kg('1', 'Quyosh'),
        _kg('2', 'Bahor'),
      ];
    }));
    await tester.pumpAndSettle();

    expect(queries, contains(''));
    expect(find.text('Bahor'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'qu');
    await tester.pumpAndSettle();

    expect(queries.last, 'qu');
    expect(find.text('Quyosh'), findsOneWidget);
    expect(find.text('Bahor'), findsNothing);
  });

  testWidgets('empty search results show the localized empty state',
      (tester) async {
    await tester.pumpWidget(_wrap(onSearch: (_) => const []));
    // ParrotMascot has an indefinite breathing animation, so we cannot use
    // pumpAndSettle here — it would never converge. Instead pump just long
    // enough for the EmptyState's fade-in / slide animations to complete.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Hech narsa topilmadi'), findsOneWidget);
    expect(find.text('Boshqa kalit so\'z bilan urinib ko\'ring'),
        findsOneWidget);
  });

  testWidgets('tapping a result pops the sheet with selected', (tester) async {
    KindergartenPickerResult? popped;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kindergartensSearchProvider.overrideWith((ref, q) async {
            return [_kg('kg-7', 'Bahor MTM')];
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: const [
            L.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L.supportedLocales,
          locale: const Locale('uz'),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    popped = await showKindergartenPickerSheet(context: ctx);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Bahor MTM'), findsOneWidget);

    await tester.tap(find.text('Bahor MTM'));
    await tester.pumpAndSettle();

    expect(popped, isNotNull);
    expect(popped!.isCleared, isFalse);
    expect(popped!.kindergarten?.id, 'kg-7');
  });

  testWidgets(
      'clear button is shown when selectedId is set and pops with cleared',
      (tester) async {
    KindergartenPickerResult? popped;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kindergartensSearchProvider.overrideWith((ref, q) async {
            return [_kg('kg-7', 'Bahor MTM')];
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: const [
            L.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L.supportedLocales,
          locale: const Locale('uz'),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    popped = await showKindergartenPickerSheet(
                      context: ctx,
                      selectedId: 'kg-7',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final clearLabel = find.text('Bog\'chani olib tashlash');
    expect(clearLabel, findsOneWidget);

    await tester.tap(clearLabel);
    await tester.pumpAndSettle();

    expect(popped, isNotNull);
    expect(popped!.isCleared, isTrue);
    expect(popped!.kindergarten, isNull);
  });

  test('KindergartenPickerResult helpers are correct', () {
    final selected = KindergartenPickerResult.selected(
      _kg('kg-1', 'Test'),
    );
    final cleared = KindergartenPickerResult.cleared();

    expect(selected.isCleared, isFalse);
    expect(selected.kindergarten?.id, 'kg-1');
    expect(cleared.isCleared, isTrue);
    expect(cleared.kindergarten, isNull);
  });
}
