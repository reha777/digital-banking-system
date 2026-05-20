import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF0066FF);
  static const Color darkBackground = Color(0xFF161622);
  static const Color darkSurface = Color(0xFF1E1E2C);
  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1E1F2F);
  static const Color textMuted = Color(0xFF85889A);
  static const Color border = Color(0xFFE7E9F0);
  static const Color error = Color(0xFFE5484D);

  static ThemeData get light {
    return _base(
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      surfaceColor: surface,
      textColor: textDark,
      mutedColor: textMuted,
      borderColor: border,
    );
  }

  static ThemeData get dark {
    return _base(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      surfaceColor: darkSurface,
      textColor: Colors.white,
      mutedColor: const Color(0xFFA4A7B7),
      borderColor: const Color(0xFF303244),
    );
  }

  static ThemeData _base({
    required Brightness brightness,
    required Color scaffoldBackgroundColor,
    required Color surfaceColor,
    required Color textColor,
    required Color mutedColor,
    required Color borderColor,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        error: error,
        surface: surfaceColor,
      ),
      fontFamily: 'Arial',
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          color: textColor,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: textColor,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
        bodyMedium: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: mutedColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        labelStyle: TextStyle(color: mutedColor, fontSize: 12),
        errorStyle: const TextStyle(color: error, fontSize: 11, height: 1.3),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: error, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
