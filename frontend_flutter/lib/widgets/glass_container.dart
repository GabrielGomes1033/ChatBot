import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/colors.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding = const EdgeInsets.all(16),
    this.blur = 18,
    this.opacity = 0.25,
    this.borderColor,
    this.childAlignment,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final double opacity;
  final Color? borderColor;
  final AlignmentGeometry? childAlignment;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final isDark = context.isNovaDark;
    final highlight = colors.glassHighlight.withValues(
      alpha: isDark ? 0.18 : 0.68,
    );
    final outerShadow = colors.shadow.withValues(
      alpha: isDark ? 0.46 : 0.12,
    );
    final upperTint = isDark
        ? colors.glass.withValues(alpha: opacity + 0.05)
        : Colors.white.withValues(alpha: opacity + 0.10);
    final lowerTint = isDark
        ? colors.surface.withValues(alpha: opacity + 0.04)
        : colors.surface.withValues(alpha: opacity + 0.18);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
        ),
        child: Container(
          padding: padding,
          alignment: childAlignment,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                upperTint,
                lowerTint,
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? colors.glassBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: outerShadow,
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: highlight,
                blurRadius: 10,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
