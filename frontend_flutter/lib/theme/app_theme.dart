import 'package:flutter/material.dart';

import 'colors.dart';

class AppTheme {
  static ThemeData get lightTheme =>
      _buildTheme(palette: NovaColors.light, brightness: Brightness.light);

  static ThemeData get darkTheme =>
      _buildTheme(palette: NovaColors.dark, brightness: Brightness.dark);

  static ThemeData _buildTheme({
    required NovaColors palette,
    required Brightness brightness,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.primary,
      onPrimary: Colors.white,
      secondary: palette.primary,
      onSecondary: Colors.white,
      error: const Color(0xFFD92D20),
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
    );

    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: palette.textPrimary,
        height: 1.45,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: palette.textPrimary,
        height: 1.5,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: palette.textSecondary,
        height: 1.45,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      extensions: [palette],
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      dividerColor: palette.border,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        shadowColor: palette.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        hintStyle: TextStyle(color: palette.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          backgroundColor: palette.surface.withValues(alpha: 0.68),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: palette.surfaceMuted,
        selectedColor: palette.primarySoft,
        side: BorderSide(color: palette.border),
        labelStyle: TextStyle(color: palette.textPrimary),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textSecondary,
        textColor: palette.textPrimary,
      ),
    );
  }
}
