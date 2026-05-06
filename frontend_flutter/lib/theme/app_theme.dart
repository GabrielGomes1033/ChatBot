import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

class AppTheme {
  static ThemeData get lightTheme =>
      _buildTheme(palette: NovaPalette.light, brightness: Brightness.light);

  static ThemeData get darkTheme =>
      _buildTheme(palette: NovaPalette.dark, brightness: Brightness.dark);

  static ThemeData _buildTheme({
    required NovaPalette palette,
    required Brightness brightness,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    );
    final bodyFonts = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
    final displayFonts = GoogleFonts.soraTextTheme(base.textTheme);

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

    final textTheme = bodyFonts.copyWith(
      displaySmall: displayFonts.displaySmall?.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
      ),
      headlineMedium: displayFonts.headlineMedium?.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineSmall: displayFonts.headlineSmall?.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: displayFonts.titleLarge?.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: bodyFonts.titleMedium?.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: bodyFonts.bodyLarge?.copyWith(
        color: palette.textPrimary,
        height: 1.45,
      ),
      bodyMedium: bodyFonts.bodyMedium?.copyWith(
        color: palette.textPrimary,
        height: 1.5,
      ),
      bodySmall: bodyFonts.bodySmall?.copyWith(
        color: palette.textSecondary,
        height: 1.45,
      ),
      labelLarge: bodyFonts.labelLarge?.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      extensions: [palette],
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      dividerColor: palette.glassBorder,
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
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Color.lerp(
          palette.surface,
          palette.glass,
          brightness == Brightness.dark ? 0.36 : 0.52,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color.lerp(
          palette.brandSurface,
          palette.surfaceStrong,
          brightness == Brightness.dark ? 0.22 : 0.14,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: palette.glassBorder.withValues(
              alpha: brightness == Brightness.dark ? 0.36 : 0.72,
            ),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        shadowColor: palette.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface.withValues(
          alpha: brightness == Brightness.dark ? 0.32 : 0.56,
        ),
        hintStyle: TextStyle(color: palette.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: palette.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: palette.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: palette.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.glassBorder),
          backgroundColor: palette.glass.withValues(
            alpha: brightness == Brightness.dark ? 0.24 : 0.42,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: palette.surfaceMuted.withValues(
          alpha: brightness == Brightness.dark ? 0.82 : 0.78,
        ),
        selectedColor: palette.primarySoft,
        side: BorderSide(color: palette.glassBorder),
        labelStyle: TextStyle(color: palette.textPrimary),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textSecondary,
        textColor: palette.textPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface.withValues(
          alpha: brightness == Brightness.dark ? 0.84 : 0.88,
        ),
        indicatorColor: palette.primarySoft.withValues(
          alpha: brightness == Brightness.dark ? 0.38 : 0.22,
        ),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? palette.primary : palette.textSecondary,
            size: selected ? 24 : 22,
          );
        }),
      ),
    );
  }
}
