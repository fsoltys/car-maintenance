
import 'package:flutter/material.dart';

// Color constants based on the provided palette
class AppColors {
  static const Color bgMain = Color(0xFF120911);
  static const Color bgSurface = Color(0xFF1E1019);
  static const Color bgSurfaceAlt = Color(0xFF291726);

  static const Color accentPrimary = Color(0xFFEF4444);
  static const Color accentSecondary = Color(0xFF818CF8);

  static const Color textPrimary = Color(0xFFEAEAEA);
  static const Color textSecondary = Color(0xFFC7C7C7);
  static const Color textMuted = Color(0xFF8B8B8B);
  static const Color textOnAccent = Color(0xFF111111);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
}

class AppTheme {
  static const _fontFamily = 'Lato';

  static final ThemeData darkTheme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgMain,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.accentPrimary,
        onPrimary: AppColors.textOnAccent,
        secondary: AppColors.accentSecondary,
        onSecondary: AppColors.textOnAccent,
        error: AppColors.error,
        onError: AppColors.textPrimary,
        background: AppColors.bgMain,
        onBackground: AppColors.textPrimary,
        surface: AppColors.bgSurface,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: const TextTheme(
        // Display
        displayLarge: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 32,
          color: AppColors.textPrimary,
        ),
        // H1
        headlineLarge: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 24,
          color: AppColors.textPrimary,
        ),
        // H2
        headlineMedium: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: AppColors.textPrimary,
        ),
        // H3
        headlineSmall: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
        // Body L
        bodyLarge: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
        // Body M
        bodyMedium: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        // Body S
        bodySmall: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
        // Button
        labelLarge: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            foregroundColor: AppColors.textPrimary, // Corrected text color
            backgroundColor: AppColors.accentPrimary,
            textStyle: const TextStyle(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            )),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.accentPrimary, width: 2),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.bgSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgMain,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(
            color: AppColors.accentSecondary.withOpacity(0.4),
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(
            color: AppColors.accentSecondary.withOpacity(0.4),
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(
            color: AppColors.accentSecondary,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2.0,
          ),
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontFamily: _fontFamily,
        ),
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontFamily: _fontFamily,
        ),
      ));
}
