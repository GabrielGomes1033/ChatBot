import 'package:flutter/material.dart';

class NovaColors {
  static const Color appleBlue = Color(0xFF2F8CFF);

  static const Color backgroundStart = Color(0xFFE2E8F0);
  static const Color backgroundEnd = Color(0xFFB7C3D2);

  static const Color textPrimary = Color(0xFF121A24);
  static const Color textSecondary = Color(0xFF5D6876);

  static const Color glassWhite = Color(0x52FFFFFF);
  static const Color glassBorder = Color(0x80FFFFFF);
  static const Color softShadow = Color(0x16040B16);
}

@immutable
class NovaPalette extends ThemeExtension<NovaPalette> {
  const NovaPalette({
    required this.background,
    required this.backgroundStart,
    required this.backgroundEnd,
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
    required this.glassBorder,
    required this.glassHighlight,
    required this.userBubble,
    required this.assistantBubble,
    required this.assistantStroke,
    required this.brandSurface,
    required this.brandGlow,
    required this.overlay,
  });

  final Color background;
  final Color backgroundStart;
  final Color backgroundEnd;
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
  final Color glassBorder;
  final Color glassHighlight;
  final Color userBubble;
  final Color assistantBubble;
  final Color assistantStroke;
  final Color brandSurface;
  final Color brandGlow;
  final Color overlay;

  static const NovaPalette light = NovaPalette(
    background: Color(0xFFE5EBF1),
    backgroundStart: NovaColors.backgroundStart,
    backgroundEnd: NovaColors.backgroundEnd,
    surface: Color(0xFFF7F9FC),
    surfaceMuted: Color(0xFFEAF0F6),
    surfaceStrong: Color(0xFFDDE5EE),
    primary: NovaColors.appleBlue,
    primarySoft: Color(0x332F8CFF),
    textPrimary: NovaColors.textPrimary,
    textSecondary: NovaColors.textSecondary,
    border: Color(0x96FFFFFF),
    shadow: NovaColors.softShadow,
    glass: Color(0x52FFFFFF),
    glassBorder: Color(0xA6FFFFFF),
    glassHighlight: Color(0xD9FFFFFF),
    userBubble: Color(0xFF2F8CFF),
    assistantBubble: Color(0x66FFFFFF),
    assistantStroke: Color(0xADFFFFFF),
    brandSurface: Color(0xCC0A0F17),
    brandGlow: Color(0x5C2F8CFF),
    overlay: Color(0x16FFFFFF),
  );

  static const NovaPalette dark = NovaPalette(
    background: Color(0xFF060B13),
    backgroundStart: Color(0xFF08101A),
    backgroundEnd: Color(0xFF162334),
    surface: Color(0xFF111A26),
    surfaceMuted: Color(0xFF182333),
    surfaceStrong: Color(0xFF223143),
    primary: Color(0xFF4FA4FF),
    primarySoft: Color(0x334FA4FF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA6B1BF),
    border: Color(0x40FFFFFF),
    shadow: Color(0x52000000),
    glass: Color(0x30213042),
    glassBorder: Color(0x52FFFFFF),
    glassHighlight: Color(0x33FFFFFF),
    userBubble: Color(0xFF3D9BFF),
    assistantBubble: Color(0x2E182333),
    assistantStroke: Color(0x47FFFFFF),
    brandSurface: Color(0xCC090D14),
    brandGlow: Color(0x66489EFF),
    overlay: Color(0x12FFFFFF),
  );

  @override
  NovaPalette copyWith({
    Color? background,
    Color? backgroundStart,
    Color? backgroundEnd,
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
    Color? glassBorder,
    Color? glassHighlight,
    Color? userBubble,
    Color? assistantBubble,
    Color? assistantStroke,
    Color? brandSurface,
    Color? brandGlow,
    Color? overlay,
  }) {
    return NovaPalette(
      background: background ?? this.background,
      backgroundStart: backgroundStart ?? this.backgroundStart,
      backgroundEnd: backgroundEnd ?? this.backgroundEnd,
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
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      userBubble: userBubble ?? this.userBubble,
      assistantBubble: assistantBubble ?? this.assistantBubble,
      assistantStroke: assistantStroke ?? this.assistantStroke,
      brandSurface: brandSurface ?? this.brandSurface,
      brandGlow: brandGlow ?? this.brandGlow,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  NovaPalette lerp(ThemeExtension<NovaPalette>? other, double t) {
    if (other is! NovaPalette) return this;
    return NovaPalette(
      background: Color.lerp(background, other.background, t)!,
      backgroundStart: Color.lerp(backgroundStart, other.backgroundStart, t)!,
      backgroundEnd: Color.lerp(backgroundEnd, other.backgroundEnd, t)!,
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
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
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
  NovaPalette get novaColors => Theme.of(this).extension<NovaPalette>()!;

  bool get isNovaDark => Theme.of(this).brightness == Brightness.dark;
}
