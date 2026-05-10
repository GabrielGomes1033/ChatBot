import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/colors.dart';

class NovaModalFrame extends StatelessWidget {
  const NovaModalFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final size = MediaQuery.sizeOf(context);
    final maxWidth = size.width < 420 ? size.width * 0.97 : size.width * 0.94;
    final targetWidth = maxWidth > 920 ? 920.0 : maxWidth;
    final targetHeight = size.height * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: targetWidth,
          maxHeight: targetHeight,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -34,
              left: 44,
              child: _NovaModalOrb(
                size: size.width < 560 ? 120 : 168,
                color: colors.primarySoft.withValues(
                  alpha: context.isNovaDark ? 0.28 : 0.70,
                ),
              ),
            ),
            Positioned(
              right: -28,
              bottom: 20,
              child: _NovaModalOrb(
                size: size.width < 560 ? 132 : 190,
                color: colors.glassHighlight.withValues(
                  alpha: context.isNovaDark ? 0.08 : 0.28,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(
                          alpha: context.isNovaDark ? 0.10 : 0.38,
                        ),
                        colors.surface.withValues(
                          alpha: context.isNovaDark ? 0.18 : 0.56,
                        ),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: colors.glassBorder.withValues(
                        alpha: context.isNovaDark ? 0.84 : 0.98,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(
                          alpha: context.isNovaDark ? 0.42 : 0.14,
                        ),
                        blurRadius: 38,
                        offset: const Offset(0, 18),
                      ),
                      BoxShadow(
                        color: colors.glassHighlight.withValues(
                          alpha: context.isNovaDark ? 0.08 : 0.30,
                        ),
                        blurRadius: 8,
                        offset: const Offset(-2, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 20, 12, 16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final stackActions = actions.isNotEmpty &&
                                constraints.maxWidth < 520;
                            final closeButton = Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(
                                  alpha: context.isNovaDark ? 0.08 : 0.46,
                                ),
                                border: Border.all(color: colors.glassBorder),
                              ),
                              child: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: colors.textSecondary,
                                ),
                              ),
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: stackActions ? 2 : 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: size.width < 460 ? 20 : 24,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ),
                                    if (!stackActions) ...actions,
                                    closeButton,
                                  ],
                                ),
                                if (stackActions) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: actions,
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      Divider(height: 1, color: colors.glassBorder),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NovaModalOrb extends StatelessWidget {
  const _NovaModalOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: color.a * 0.24),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
