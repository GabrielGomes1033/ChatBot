import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/colors.dart';

enum NovaCardStyle {
  standard,
  muted,
  glass,
  brand,
}

class NovaCard extends StatelessWidget {
  const NovaCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.style = NovaCardStyle.standard,
    this.expandChild = false,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double radius;
  final NovaCardStyle style;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;

    final Color background = switch (style) {
      NovaCardStyle.standard => colors.surface.withValues(
          alpha: context.isNovaDark ? 0.96 : 0.98,
        ),
      NovaCardStyle.muted => colors.surfaceMuted.withValues(
          alpha: context.isNovaDark ? 0.94 : 0.98,
        ),
      NovaCardStyle.glass => colors.glass,
      NovaCardStyle.brand => colors.brandSurface,
    };

    final Color borderColor = switch (style) {
      NovaCardStyle.brand => colors.brandGlow.withValues(alpha: 0.9),
      _ => colors.border.withValues(alpha: context.isNovaDark ? 0.74 : 0.92),
    };

    final shadowColor = style == NovaCardStyle.brand
        ? colors.brandGlow
        : colors.shadow.withValues(alpha: context.isNovaDark ? 0.32 : 0.10);

    final inner = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: style == NovaCardStyle.brand ? 30 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );

    if (style != NovaCardStyle.glass) {
      return inner;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: inner,
      ),
    );
  }
}
