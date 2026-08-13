import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF0066FF);
  static const Color darkBackground = Color(0xFF161622);
  static const Color darkSurface = Color(0xFF171827);
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF171827);
  static const Color textMuted = Color(0xFF85889A);
  static const Color inputBorder = Color(0xFFE7E9F0);
  static const Color error = Color(0xFFE5484D);

  static ThemeData get light {
    return _base(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      textColor: textDark,
      inputFill: lightBackground,
    );
  }

  static ThemeData get dark {
    return _base(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      textColor: Colors.white,
      inputFill: darkBackground,
    );
  }

  static ThemeData _base({
    required Brightness brightness,
    required Color scaffoldBackgroundColor,
    required Color textColor,
    required Color inputFill,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      colorScheme: colorScheme,
      fontFamily: 'Arial',
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: textColor,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: textColor,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: const TextStyle(
          color: textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        labelStyle: const TextStyle(color: textMuted, fontSize: 12),
        errorStyle: const TextStyle(color: error, fontSize: 11, height: 1.3),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: inputBorder),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
