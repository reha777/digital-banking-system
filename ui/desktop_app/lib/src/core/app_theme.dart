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
  static const Color success = Color(0xFF168A4A);
  static const Color warning = Color(0xFFE08A00);
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;

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
        titleMedium: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        hoverColor: primary.withValues(alpha: .035),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: mutedColor, fontSize: 12),
        errorStyle: const TextStyle(color: error, fontSize: 11, height: 1.3),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: borderColor.withValues(alpha: .78)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: error, width: 1.4),
        ),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(40),
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: borderColor.withValues(alpha: .72)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: .22),
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: borderColor.withValues(alpha: .75)),
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surfaceColor),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: WidgetStatePropertyAll(
            const Color(0xFF0F172A).withValues(alpha: .2),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium),
              side: BorderSide(color: borderColor.withValues(alpha: .7)),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? const Color(0xFFF3F4F6)
              : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(
          color: brightness == Brightness.dark
              ? const Color(0xFF111827)
              : Colors.white,
          fontSize: 12,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(true),
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(4),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return mutedColor.withValues(alpha: 0.72);
          }
          return mutedColor.withValues(alpha: 0.45);
        }),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          side: BorderSide(color: borderColor),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(44, 46),
          shadowColor: primary.withValues(alpha: .22),
          disabledBackgroundColor: mutedColor.withValues(alpha: .12),
          disabledForegroundColor: mutedColor.withValues(alpha: .72),
          overlayColor: Colors.white.withValues(alpha: .1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          brightness == Brightness.dark
              ? const Color(0xFF242635)
              : const Color(0xFFF1F5FB),
        ),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return primary.withValues(alpha: .055);
          }
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: .09);
          }
          return Colors.transparent;
        }),
        headingTextStyle: TextStyle(
          color: mutedColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .55,
        ),
        dataTextStyle: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        headingRowHeight: 48,
        dataRowMinHeight: 54,
        dataRowMaxHeight: 68,
        horizontalMargin: 18,
        columnSpacing: 24,
        dividerThickness: .7,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(radiusMedium),
          border: Border.all(color: borderColor),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: borderColor,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: primary,
        unselectedLabelColor: mutedColor,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: primary.withValues(alpha: .12),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: Color(0x1A0066FF),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
