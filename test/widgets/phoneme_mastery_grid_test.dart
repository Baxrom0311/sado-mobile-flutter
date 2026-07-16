import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/domain/speech_profile/phoneme_mastery.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/widgets/phoneme_mastery_grid.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      locale: const Locale('uz'),
      home: Scaffold(
        body: SizedBox(width: 600, child: child),
      ),
    );

void main() {
  group('PhonemeMasteryGrid', () {
    testWidgets('renders nothing when given an empty list', (tester) async {
      await tester.pumpWidget(_wrap(const PhonemeMasteryGrid(phonemes: [])));
      await tester.pump();

      // Sanity check: the empty-list short-circuit returns a SizedBox.shrink
      // — there should be no glyph text rendered.
      expect(find.text('r'), findsNothing);
    });

    testWidgets('renders one tile per phoneme with its accuracy percent',
        (tester) async {
      await tester.pumpWidget(_wrap(const PhonemeMasteryGrid(phonemes: [
        PhonemeMastery(
            phoneme: 'r', sampleCount: 4, weakCount: 3, accuracy: 0.25),
        PhonemeMastery(
            phoneme: 'k', sampleCount: 2, weakCount: 0, accuracy: 0.95),
      ])));
      // Tween starts at 0; pump frames so it settles to the final value.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('r'), findsOneWidget);
      expect(find.text('k'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('95%'), findsOneWidget);
    });

    testWidgets('color mapping mirrors mastery buckets', (tester) async {
      // struggling → danger
      expect(
        PhonemeMasteryGrid.colorFor(PhonemeMasteryLevel.struggling),
        AppColors.danger,
      );
      // developing → warning
      expect(
        PhonemeMasteryGrid.colorFor(PhonemeMasteryLevel.developing),
        AppColors.warning,
      );
      // mastered → success
      expect(
        PhonemeMasteryGrid.colorFor(PhonemeMasteryLevel.mastered),
        AppColors.success,
      );
    });

    testWidgets(
        'tiles become tappable when onPhonemeTap is provided and route '
        'the parent into a per-phoneme drill', (tester) async {
      PhonemeMastery? tapped;
      await tester.pumpWidget(_wrap(PhonemeMasteryGrid(
        phonemes: const [
          PhonemeMastery(
              phoneme: 'r', sampleCount: 4, weakCount: 3, accuracy: 0.25),
        ],
        onPhonemeTap: (p) => tapped = p,
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // The InkWell wraps the tile when a tap handler is wired up;
      // tapping anywhere on the tile triggers the callback.
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(tapped?.phoneme, 'r');
    });

    testWidgets(
        'tiles render as static chips (no InkWell) when no tap handler '
        'is provided', (tester) async {
      await tester.pumpWidget(_wrap(const PhonemeMasteryGrid(
        phonemes: [
          PhonemeMastery(
              phoneme: 'r', sampleCount: 4, weakCount: 3, accuracy: 0.25),
        ],
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.byType(InkWell), findsNothing);
    });
  });
}
