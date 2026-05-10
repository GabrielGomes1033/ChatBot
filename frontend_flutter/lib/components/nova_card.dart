import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../widgets/glass_container.dart';

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

    final inner = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final stackHeader = title != null &&
                    trailing != null &&
                    constraints.maxWidth < 460;
                final titleWidget = title == null
                    ? null
                    : Text(
                        title!,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      );

                if (stackHeader) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget!,
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: trailing!,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (titleWidget != null) Expanded(child: titleWidget),
                    if (trailing != null) trailing!,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
          ],
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );

    switch (style) {
      case NovaCardStyle.standard:
        return GlassContainer(
          borderRadius: radius,
          padding: padding,
          blur: 14,
          opacity: context.isNovaDark ? 0.10 : 0.20,
          child: inner,
        );
      case NovaCardStyle.muted:
        return GlassContainer(
          borderRadius: radius,
          padding: padding,
          blur: 12,
          opacity: context.isNovaDark ? 0.08 : 0.16,
          borderColor: colors.glassHighlight.withValues(
            alpha: context.isNovaDark ? 0.18 : 0.58,
          ),
          child: inner,
        );
      case NovaCardStyle.glass:
        return GlassContainer(
          borderRadius: radius,
          padding: padding,
          blur: 20,
          opacity: context.isNovaDark ? 0.16 : 0.28,
          child: inner,
        );
      case NovaCardStyle.brand:
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.brandSurface,
                    Color.lerp(
                      colors.brandSurface,
                      colors.primary,
                      context.isNovaDark ? 0.16 : 0.22,
                    )!,
                  ],
                ),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: colors.glassHighlight.withValues(
                    alpha: context.isNovaDark ? 0.26 : 0.48,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.brandGlow.withValues(
                      alpha: context.isNovaDark ? 0.32 : 0.26,
                    ),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: colors.glassHighlight.withValues(
                      alpha: context.isNovaDark ? 0.08 : 0.28,
                    ),
                    blurRadius: 8,
                    offset: const Offset(-2, -2),
                  ),
                ],
              ),
              child: inner,
            ),
          ),
        );
    }
  }
}
