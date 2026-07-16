import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/widgets/child_avatar.dart';

void main() {
  group('ChildAvatar.initialsOf', () {
    test('returns ? for empty / whitespace-only input', () {
      expect(ChildAvatar.initialsOf(''), '?');
      expect(ChildAvatar.initialsOf('   '), '?');
    });

    test('returns a single uppercase letter for a one-word name', () {
      expect(ChildAvatar.initialsOf('aziza'), 'A');
      expect(ChildAvatar.initialsOf('Bekzod'), 'B');
    });

    test('returns the first + last word initials for multi-word names', () {
      expect(ChildAvatar.initialsOf('Aziza Karimova'), 'AK');
      expect(ChildAvatar.initialsOf('Bekzod Bakhriddin Aliev'), 'BA');
    });

    test('handles tabs and multiple spaces between words', () {
      expect(ChildAvatar.initialsOf('  Aziza\t Karimova  '), 'AK');
    });

    test('preserves Cyrillic letters (no Latin coercion)', () {
      // The Russian "Анна" must initial to "А" (U+0410), not "A" (U+0041).
      final initial = ChildAvatar.initialsOf('Анна');
      expect(initial, 'А');
      expect(initial.codeUnitAt(0), 0x0410);
    });
  });

  group('ChildAvatar.paletteOf', () {
    test('same name → same palette across calls (deterministic)', () {
      final a = ChildAvatar.paletteOf('Aziza');
      final b = ChildAvatar.paletteOf('Aziza');
      expect(a, equals(b));
    });

    test('different names usually pick different palettes', () {
      // Not strictly guaranteed by hashing, but with our 7-color palette
      // these two names land on different buckets — locked in to catch
      // accidental hash regressions.
      final a = ChildAvatar.paletteOf('Aziza');
      final b = ChildAvatar.paletteOf('Bekzod');
      expect(a, isNot(equals(b)));
    });

    test('male / female hint forces a fixed brand palette', () {
      final boy = ChildAvatar.paletteOf('whatever', gender: 'male');
      final girl = ChildAvatar.paletteOf('whatever', gender: 'female');
      // Boys get the sky-blue gradient, girls get the pink — both must
      // disagree with the name-derived palette so the visual cue lands.
      expect(boy, isNot(equals(girl)));
      expect(boy.length, 2);
      expect(girl.length, 2);
    });
  });

  testWidgets('renders the initials and accepts all sizes', (tester) async {
    for (final size in ChildAvatarSize.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ChildAvatar(name: 'Aziza Karimova', size: size),
            ),
          ),
        ),
      );
      // Each size renders the two-letter initials.
      expect(find.text('AK'), findsOneWidget);
    }
  });

  testWidgets('showRing wraps the avatar with a soft white ring',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChildAvatar(name: 'Aziza', showRing: true),
          ),
        ),
      ),
    );

    // Two Containers in the subtree: the inner gradient circle + the
    // outer ring. Without `showRing` only the inner one is created.
    final containerCount = tester
        .widgetList<Container>(find.descendant(
          of: find.byType(ChildAvatar),
          matching: find.byType(Container),
        ))
        .length;
    expect(containerCount, 2);
  });

  testWidgets('heroTag wraps the avatar in a Hero for route flights',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChildAvatar(
              name: 'Aziza',
              heroTag: 'child-avatar-42',
            ),
          ),
        ),
      ),
    );

    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'child-avatar-42');
    // The flight overlay needs a Material ancestor for crisp text — we
    // wrap the inner avatar in a transparent Material so the gradient
    // circle keeps its rounded edges through the entire transition.
    expect(
      find.descendant(
        of: find.byType(Hero),
        matching: find.byType(Material),
      ),
      findsOneWidget,
    );
  });

  testWidgets('omitting heroTag does not introduce a Hero wrapper',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: ChildAvatar(name: 'Aziza')),
        ),
      ),
    );
    expect(find.byType(Hero), findsNothing);
  });
}
