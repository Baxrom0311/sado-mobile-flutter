import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Deterministic, child-friendly avatar built from the child's name.
///
/// Behaviour:
/// * Picks 1–2 letter initials from the name (Unicode-safe — uses runes so
///   non-Latin scripts like Cyrillic/Uzbek work correctly).
/// * Picks a color pair from the brand palette based on a stable hash of
///   the name, so the same child always gets the same colors across
///   screens (children list, home strip, child detail header).
/// * Optionally accepts a [gender] hint that biases the palette toward
///   the brand's blue/pink accents — keeps the existing visual language
///   without losing the determinism of the name-based hash.
///
/// Use [size] to switch between the predefined display sizes; the inner
/// font size and border radius scale with the avatar so the widget reads
/// well in dense list rows as well as hero cards.
enum ChildAvatarSize { sm, md, lg, xl }

class ChildAvatar extends StatelessWidget {
  const ChildAvatar({
    super.key,
    required this.name,
    this.gender,
    this.size = ChildAvatarSize.md,
    this.showRing = false,
    this.heroTag,
  });

  final String name;

  /// Optional API gender string ("male" / "female"). When provided, the
  /// palette is tilted toward the blue/pink end so the avatars in the UI
  /// keep the secondary gender cue. Falls back to a name-based palette
  /// when null or unrecognised.
  final String? gender;

  final ChildAvatarSize size;

  /// Adds a soft outer ring matching the avatar color. Useful when the
  /// avatar sits on top of a colored hero card.
  final bool showRing;

  /// When set, the avatar is wrapped in a [Hero] with the given tag so
  /// route transitions can fly the avatar from a list/grid card to the
  /// child detail header. Use a stable tag (e.g. `'child-avatar-$id'`)
  /// on both ends. Leave `null` on screens where the avatar is decorative
  /// or where two instances might be on screen simultaneously to avoid
  /// duplicate-Hero asserts.
  final Object? heroTag;

  static const _palettes = <List<Color>>[
    [AppColors.primary, AppColors.primaryDark],
    [AppColors.secondary, AppColors.secondaryDark],
    [AppColors.tertiary, Color(0xFF7C3AED)],
    [AppColors.sky, Color(0xFF1E78C8)],
    [AppColors.pink, Color(0xFFE85D8A)],
    [Color(0xFFFFB347), Color(0xFFEB8B16)],
    [Color(0xFF22C9A0), Color(0xFF0E8C72)],
  ];

  static const _malePalette = <Color>[AppColors.sky, Color(0xFF1E78C8)];
  static const _femalePalette = <Color>[AppColors.pink, Color(0xFFE85D8A)];

  /// Visible to tests. Returns up to two uppercase letters; falls back to
  /// `?` when the name is empty.
  static String initialsOf(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return '?';
    final parts =
        cleaned.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.length == 1) {
      final runes = parts.first.runes.toList();
      if (runes.isEmpty) return '?';
      return String.fromCharCode(runes.first).toUpperCase();
    }
    final first = String.fromCharCode(parts.first.runes.first);
    final last = String.fromCharCode(parts.last.runes.first);
    return (first + last).toUpperCase();
  }

  /// Visible to tests. Stable hash → palette pick.
  static List<Color> paletteOf(String name, {String? gender}) {
    if (gender == 'male') return _malePalette;
    if (gender == 'female') return _femalePalette;
    final cleaned = name.trim();
    if (cleaned.isEmpty) return _palettes.first;
    var hash = 0;
    for (final r in cleaned.toLowerCase().runes) {
      hash = (hash * 31 + r) & 0x7fffffff;
    }
    return _palettes[hash % _palettes.length];
  }

  double get _diameter => switch (size) {
        ChildAvatarSize.sm => 36,
        ChildAvatarSize.md => 56,
        ChildAvatarSize.lg => 72,
        ChildAvatarSize.xl => 96,
      };

  double get _fontSize => switch (size) {
        ChildAvatarSize.sm => 14,
        ChildAvatarSize.md => 20,
        ChildAvatarSize.lg => 26,
        ChildAvatarSize.xl => 34,
      };

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(name, gender: gender);
    final initials = initialsOf(name);
    final d = _diameter;

    Widget avatar = Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: palette.last.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: _fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );

    if (showRing) {
      avatar = Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          shape: BoxShape.circle,
        ),
        child: avatar,
      );
    }
    if (heroTag != null) {
      // Wrapping in [Material] (transparent) keeps text rendering crisp
      // during the flight overlay — the default Hero flight reparents
      // the child into an [Overlay] that lacks the surrounding Material
      // ancestor. The default rectTween animates the size and position,
      // which is exactly what we want when growing a small list-row
      // avatar into a hero header on the detail screen.
      avatar = Hero(
        tag: heroTag!,
        child: Material(
          type: MaterialType.transparency,
          child: avatar,
        ),
      );
    }
    return avatar;
  }
}
