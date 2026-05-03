import 'package:flutter/material.dart';

@immutable
class NovaColors extends ThemeExtension<NovaColors> {
  const NovaColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceStrong,
    required this.primary,
    required this.primarySoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.shadow,
    required this.glass,
    required this.userBubble,
    required this.assistantBubble,
    required this.assistantStroke,
    required this.brandSurface,
    required this.brandGlow,
    required this.overlay,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceStrong;
  final Color primary;
  final Color primarySoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color shadow;
  final Color glass;
  final Color userBubble;
  final Color assistantBubble;
  final Color assistantStroke;
  final Color brandSurface;
  final Color brandGlow;
  final Color overlay;

  static const NovaColors light = NovaColors(
    background: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF0F1F4),
    surfaceStrong: Color(0xFFE7E8EC),
    primary: Color(0xFF007AFF),
    primarySoft: Color(0x1A007AFF),
    textPrimary: Color(0xFF1D1D1F),
    textSecondary: Color(0xFF6E6E73),
    border: Color(0xFFD2D2D7),
    shadow: Color(0x16000000),
    glass: Color(0xD9FFFFFF),
    userBubble: Color(0xFF007AFF),
    assistantBubble: Color(0xFFF2F2F5),
    assistantStroke: Color(0xFFD9DADE),
    brandSurface: Color(0xFF0B0B0F),
    brandGlow: Color(0x22007AFF),
    overlay: Color(0x121D1D1F),
  );

  static const NovaColors dark = NovaColors(
    background: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceMuted: Color(0xFF111113),
    surfaceStrong: Color(0xFF2C2C2E),
    primary: Color(0xFF0A84FF),
    primarySoft: Color(0x290A84FF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8E8E93),
    border: Color(0xFF3A3A3C),
    shadow: Color(0x5A000000),
    glass: Color(0xC91C1C1E),
    userBubble: Color(0xFF0A84FF),
    assistantBubble: Color(0xFF2C2C2E),
    assistantStroke: Color(0xFF3A3A3C),
    brandSurface: Color(0xFF050608),
    brandGlow: Color(0x2E0A84FF),
    overlay: Color(0x16FFFFFF),
  );

  @override
  NovaColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceStrong,
    Color? primary,
    Color? primarySoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? shadow,
    Color? glass,
    Color? userBubble,
    Color? assistantBubble,
    Color? assistantStroke,
    Color? brandSurface,
    Color? brandGlow,
    Color? overlay,
  }) {
    return NovaColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
      glass: glass ?? this.glass,
      userBubble: userBubble ?? this.userBubble,
      assistantBubble: assistantBubble ?? this.assistantBubble,
      assistantStroke: assistantStroke ?? this.assistantStroke,
      brandSurface: brandSurface ?? this.brandSurface,
      brandGlow: brandGlow ?? this.brandGlow,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  NovaColors lerp(ThemeExtension<NovaColors>? other, double t) {
    if (other is! NovaColors) return this;
    return NovaColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      assistantBubble: Color.lerp(assistantBubble, other.assistantBubble, t)!,
      assistantStroke: Color.lerp(assistantStroke, other.assistantStroke, t)!,
      brandSurface: Color.lerp(brandSurface, other.brandSurface, t)!,
      brandGlow: Color.lerp(brandGlow, other.brandGlow, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
    );
  }
}

extension NovaThemeX on BuildContext {
  NovaColors get novaColors => Theme.of(this).extension<NovaColors>()!;

  bool get isNovaDark => Theme.of(this).brightness == Brightness.dark;
}
