import 'package:flutter/material.dart';
import '../design_system/tokens.dart';

class AppTheme {
  /// Dark Theme Definition (The primary Premium OLED Black theme)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackgroundPrimary,
      primaryColor: AppColors.darkAccentPrimary,
      cardColor: AppColors.darkSurfacePrimary,
      dividerColor: AppColors.darkBorderSubtle,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkAccentPrimary,
        secondary: AppColors.darkAccentSecondary,
        surface: AppColors.darkSurfacePrimary,
        error: AppColors.statusError,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.display.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        headlineMedium: AppTypography.sectionHeading.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        titleMedium: AppTypography.cardHeading.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        bodyLarge: AppTypography.body.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        bodyMedium: AppTypography.secondaryBody.copyWith(
          color: AppColors.darkTextSecondary,
        ),
        labelLarge: AppTypography.button.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        bodySmall: AppTypography.caption.copyWith(
          color: AppColors.darkTextTertiary,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.darkSurfacePrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
          side: BorderSide(color: AppColors.darkBorderSubtle, width: 0.5),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Light Theme Definition
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackgroundPrimary,
      primaryColor: AppColors.lightAccentPrimary,
      cardColor: AppColors.lightBackgroundSecondary,
      dividerColor: AppColors.lightBorderSubtle,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightAccentPrimary,
        secondary: AppColors.lightAccentSecondary,
        surface: AppColors.lightBackgroundSecondary,
        error: AppColors.statusError,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.display.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        headlineMedium: AppTypography.sectionHeading.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        titleMedium: AppTypography.cardHeading.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        bodyLarge: AppTypography.body.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        bodyMedium: AppTypography.secondaryBody.copyWith(
          color: AppColors.lightTextSecondary,
        ),
        labelLarge: AppTypography.button.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        bodySmall: AppTypography.caption.copyWith(
          color: AppColors.lightTextTertiary,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.lightBackgroundSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
          side: BorderSide(color: AppColors.lightBorderSubtle, width: 0.5),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightBackgroundSecondary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
