import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/exercises/widgets/child_picker_sheet.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

Widget _wrap(Widget body) {
  return MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: const [
      L.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L.supportedLocales,
    locale: const Locale('uz'),
    home: Scaffold(body: body),
  );
}

Child _child(String id, {String name = 'Test', String gender = 'female'}) =>
    Child(
      id: id,
      name: name,
      birthDate: DateTime(2020, 1, 1),
      gender: gender,
      parentId: 'p1',
      createdAt: DateTime(2024, 1, 1),
    );

void main() {
  group('ChildPickerSheet', () {
    testWidgets('renders the title, body and one tile per child',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ChildPickerSheet(
          children: [
            _child('a', name: 'Aziza'),
            _child('b', name: 'Bobur', gender: 'male'),
          ],
          selectedId: 'a',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Bolani tanlang'), findsOneWidget);
      expect(find.text('Aziza'), findsOneWidget);
      expect(find.text('Bobur'), findsOneWidget);
    });

    testWidgets('marks the currently-selected child with a filled radio',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ChildPickerSheet(
          children: [
            _child('a', name: 'Aziza'),
            _child('b', name: 'Bobur', gender: 'male'),
          ],
          selectedId: 'b',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsOneWidget,
      );
    });

    testWidgets('tapping a tile pops the sheet with the chosen id',
        (tester) async {
      String? popped;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              popped = await showChildPickerSheet(
                context: context,
                children: [
                  _child('a', name: 'Aziza'),
                  _child('b', name: 'Bobur', gender: 'male'),
                ],
                selectedId: 'a',
              );
            },
            child: const Text('open'),
          );
        }),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // Pick "Bobur"
      await tester.tap(find.text('Bobur'));
      await tester.pumpAndSettle();

      expect(popped, 'b');
    });

    testWidgets('shows "add child" CTA only when onAddChild is provided',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ChildPickerSheet(
          children: [_child('a', name: 'Aziza')],
          selectedId: 'a',
          onAddChild: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Yangi bola qo\'shish'), findsOneWidget);
    });

    testWidgets('hides "add child" CTA when onAddChild is null',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ChildPickerSheet(
          children: [_child('a', name: 'Aziza')],
          selectedId: 'a',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Yangi bola qo\'shish'), findsNothing);
    });
  });
}
