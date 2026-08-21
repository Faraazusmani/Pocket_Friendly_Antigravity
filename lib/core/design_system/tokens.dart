import 'package:flutter/material.dart';

/// Semantic color tokens for the Pocket Friendly application,
/// supporting both light and dark modes with premium palettes.
class AppColors {
  // --- Dark Mode Palette (Primary Benchmark: Premium OLED Black) ---
  static const Color darkBackgroundPrimary = Color(0xFF000000); // OLED black
  static const Color darkBackgroundSecondary = Color(
    0xFF0C0C0E,
  ); // Near-black charcoal
  static const Color darkSurfacePrimary = Color(0xFF16161A); // Layered card
  static const Color darkSurfaceSecondary = Color(
    0xFF22222A,
  ); // Elevated surface
  static const Color darkSurfaceElevated = Color(
    0xFF2C2C35,
  ); // Sheets & Overlays

  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA0A0AB); // Muted silver
  static const Color darkTextTertiary = Color(0xFF71717A); // Deep zinc
  static const Color darkBorderSubtle = Color(0xFF27272A); // Hairline border

  static const Color darkAccentPrimary = Color(0xFF0F62FE); // Rich IBM blue
  static const Color darkAccentSecondary = Color(
    0xFF008A2E,
  ); // Restrained green

  // --- Light Mode Palette ---
  static const Color lightBackgroundPrimary = Color(0xFFF8F9FA); // Off-white
  static const Color lightBackgroundSecondary = Color(0xFFFFFFFF); // Pure white
  static const Color lightSurfacePrimary = Color(0xFFE9ECEF); // Soft grey card
  static const Color lightSurfaceSecondary = Color(0xFFDEE2E6);
  static const Color lightSurfaceElevated = Color(0xFFCED4DA);

  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF495057);
  static const Color lightTextTertiary = Color(0xFF6C757D);
  static const Color lightBorderSubtle = Color(0xFFE5E5E5);

  static const Color lightAccentPrimary = Color(0xFF0F62FE);
  static const Color lightAccentSecondary = Color(0xFF008A2E);

  // --- Common Semantic Status Colors ---
  static const Color statusSuccess = Color(0xFF10B981);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusError = Color(0xFFEF4444);
  static const Color statusInfo = Color(0xFF3B82F6);
}

/// Tokenized spacing scale to avoid hardcoded layout margins and paddings.
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// Tokenized corner radius values for cards, buttons, and sheets.
class AppRadius {
  static const double small = 6.0;
  static const double medium = 12.0;
  static const double large = 18.0;
  static const double sheet = 24.0;
  static const double pill = 999.0;
}

/// Tokenized borders that dynamically adapt to theme brightness.
class AppBorders {
  static InputBorder focusedUnderline(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return UnderlineInputBorder(
      borderSide: BorderSide(
        color: isDark ? AppColors.darkAccentPrimary : AppColors.lightAccentPrimary,
      ),
    );
  }

  static InputBorder focusedOutline(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlineInputBorder(
      borderSide: BorderSide(
        color: isDark ? AppColors.darkAccentPrimary : AppColors.lightAccentPrimary,
      ),
    );
  }
}

/// Motion duration tokens for standardizing transitions and animations.
class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration emphasized = Duration(milliseconds: 350);

  static const Curve curveStandard = Curves.easeInOutCubic;
  static const Curve curveEmphasized = Curves.fastOutSlowIn;
}

/// Custom typography definitions supporting Hanken/Host Grotesk semantics.
/// Font styling utilizes native fallback with correct letter spacing.
class AppTypography {
  static const String fontFamily = 'HankenGrotesk';

  static TextStyle get display => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
  );

  static TextStyle get largeAmount => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: -0.5,
  );

  static TextStyle get sectionHeading => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static TextStyle get cardHeading => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get body => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );

  static TextStyle get secondaryBody => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  static TextStyle get caption => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  static TextStyle get label => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static TextStyle get button => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static TextStyle get numericData => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
