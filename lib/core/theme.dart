import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// SADO premium design system.
/// Custom palette inspired by friendly kids' learning apps.
/// No Material seedColor — every color is hand-picked.
abstract final class AppColors {
  // Primary — bright leafy green (parrot body, success, primary CTA)
  static const primary = Color(0xFF22C55E);
  static const primaryDark = Color(0xFF16A34A);
  static const primaryLight = Color(0xFFDCFCE7);

  // Secondary — warm orange (mascot beak, XP, energy)
  static const secondary = Color(0xFFFB923C);
  static const secondaryDark = Color(0xFFEA580C);
  static const secondaryLight = Color(0xFFFFEDD5);

  // Accent — sunny yellow (badges, stars, achievements)
  static const accent = Color(0xFFFACC15);
  static const accentLight = Color(0xFFFEF9C3);

  // Tertiary — soft purple (creative, listening)
  static const tertiary = Color(0xFF8B5CF6);
  static const tertiaryLight = Color(0xFFEDE9FE);

  // Sky — info / breathing
  static const sky = Color(0xFF38BDF8);
  static const skyLight = Color(0xFFE0F2FE);

  // Pink — girls, vocabulary
  static const pink = Color(0xFFEC4899);
  static const pinkLight = Color(0xFFFCE7F3);

  // Risk colors
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  // Streak fire
  static const fire = Color(0xFFFF6B35);

  // Surfaces
  static const background = Color(0xFFFAFBFD);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF3F4F6);

  // Text
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  // Borders
  static const border = Color(0xFFE5E7EB);
  static const borderStrong = Color(0xFFD1D5DB);

  // Gradients
  static const homeGradient = [Color(0xFFE9F9EE), Color(0xFFFAFBFD)];
  static const heroGradient = [Color(0xFF22C55E), Color(0xFF16A34A)];
  static const sunsetGradient = [Color(0xFFFB923C), Color(0xFFFACC15)];
  static const skyGradient = [Color(0xFF38BDF8), Color(0xFF8B5CF6)];

  // Category color map
  static Color categoryColor(String category) => switch (category) {
        'articulation' => primary,
        'breathing' => sky,
        'vocabulary' => pink,
        'fluency' => secondary,
        'listening' => tertiary,
        'phonemic_awareness' => accent,
        _ => primary,
      };

  // Difficulty
  static Color difficultyColor(String d) => switch (d) {
        'easy' => success,
        'medium' => warning,
        'hard' => danger,
        _ => textMuted,
      };

  // Risk
  static Color riskColor(String? r) => switch (r) {
        'green' || 'low' => success,
        'yellow' || 'medium' => warning,
        'red' || 'high' => danger,
        _ => textMuted,
      };
}

/// 4px spacing grid.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const huge = 48.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const pill = 999.0;
}

abstract final class AppShadow {
  static List<BoxShadow> soft(Color color, {double opacity = 0.18}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> press(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.25),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static const card = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];
}

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      // Hand-built ColorScheme (NOT fromSeed)
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryLight,
        onSecondaryContainer: AppColors.secondaryDark,
        tertiary: AppColors.tertiary,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.tertiaryLight,
        onTertiaryContainer: AppColors.tertiary,
        error: AppColors.danger,
        onError: Colors.white,
        errorContainer: Color(0xFFFEE2E2),
        onErrorContainer: AppColors.danger,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceMuted,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
        outlineVariant: AppColors.borderStrong,
        shadow: Color(0x33000000),
        scrim: Color(0x80000000),
        inverseSurface: AppColors.textPrimary,
        onInverseSurface: Colors.white,
        inversePrimary: AppColors.primaryLight,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.nunito(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 54),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: GoogleFonts.nunito(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: GoogleFonts.nunito(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: GoogleFonts.nunito(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: AppColors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 70,
        indicatorColor: AppColors.primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            size: 26,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: GoogleFonts.nunito(
          fontSize: 15,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
