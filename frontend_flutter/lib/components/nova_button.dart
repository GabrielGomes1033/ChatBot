import 'package:flutter/material.dart';

import '../theme/colors.dart';

enum NovaButtonTone {
  primary,
  secondary,
  ghost,
}

class NovaButton extends StatelessWidget {
  const NovaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.tone = NovaButtonTone.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;
  final NovaButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: isLoading
          ? const SizedBox(
              key: ValueKey('loading'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
    );

    final Widget button;
    switch (tone) {
      case NovaButtonTone.primary:
        button = FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: colors.primary.withValues(alpha: 0.55),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: child,
        );
      case NovaButtonTone.secondary:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textPrimary,
            side: BorderSide(color: colors.border),
            backgroundColor: colors.surface.withValues(alpha: 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: child,
        );
      case NovaButtonTone.ghost:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: colors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: child,
        );
    }

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class NovaPillIconButton extends StatelessWidget {
  const NovaPillIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.size = 48,
    this.iconSize = 20,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final button = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected
            ? colors.primarySoft
            : colors.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: selected ? colors.primary : colors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow
                .withValues(alpha: context.isNovaDark ? 0.36 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: iconSize,
          color: selected ? colors.primary : colors.textPrimary,
        ),
        splashRadius: size / 2,
      ),
    );

    if (tooltip == null || tooltip!.trim().isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip, child: button);
  }
}
