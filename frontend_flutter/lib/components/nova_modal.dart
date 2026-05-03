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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: colors.glass,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colors.border.withValues(
                    alpha: context.isNovaDark ? 0.82 : 0.94,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(
                      alpha: context.isNovaDark ? 0.42 : 0.14,
                    ),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 10, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: size.width < 460 ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        ...actions,
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
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
      ),
    );
  }
}
