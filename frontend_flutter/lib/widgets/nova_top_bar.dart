import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'glass_container.dart';
import 'home/chat_shell_widgets.dart'
    show NovaAssistantState, NovaAssistantStateX;
import 'nova_sidebar_bio.dart';

class NovaTopBar extends StatelessWidget {
  const NovaTopBar({
    super.key,
    required this.onMenuTap,
    required this.onUserTap,
    required this.status,
    required this.contextText,
    this.userLabel = 'Usuário',
  });

  final VoidCallback onMenuTap;
  final VoidCallback onUserTap;
  final NovaAssistantState status;
  final String contextText;
  final String userLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 620;
        final veryNarrow = constraints.maxWidth < 430;
        final wide = constraints.maxWidth >= 780;
        final ultra = constraints.maxWidth >= 920;
        final controlSize =
            ultra ? 48.0 : (veryNarrow ? 40.0 : (narrow ? 42.0 : 46.0));
        final logoSize =
            ultra ? 56.0 : (veryNarrow ? 42.0 : (narrow ? 46.0 : 52.0));
        final horizontalPadding = ultra ? 18.0 : (veryNarrow ? 10.0 : 14.0);
        final verticalPadding = ultra ? 14.0 : (narrow ? 10.0 : 12.0);

        Widget identityBlock() {
          return Row(
            children: [
              NovaMetalLogo(size: logoSize),
              SizedBox(width: narrow ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ultra) ...[
                      Text(
                        'Sessão ativa',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      'NOVA',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: ultra ? 18.8 : (narrow ? 16.2 : 18),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                    SizedBox(height: narrow ? 3 : 4),
                    Text(
                      contextText,
                      maxLines: veryNarrow ? 3 : (narrow ? 2 : (wide ? 2 : 1)),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: ultra ? 13.0 : (narrow ? 12.1 : 12.8),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return GlassContainer(
          borderRadius: ultra ? 32 : 28,
          blur: ultra ? 24 : 22,
          opacity: context.isNovaDark ? 0.16 : 0.30,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TopCircleButton(
                          icon: Icons.grid_view_rounded,
                          onTap: onMenuTap,
                          tooltip: 'Menu rápido',
                          size: controlSize,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: identityBlock()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _StatusPill(
                              state: status,
                              compact: veryNarrow,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _TopCircleButton(
                          icon: Icons.person_outline_rounded,
                          onTap: onUserTap,
                          tooltip: userLabel,
                          size: controlSize,
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    _TopCircleButton(
                      icon: Icons.grid_view_rounded,
                      onTap: onMenuTap,
                      tooltip: 'Menu rápido',
                      size: controlSize,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: identityBlock()),
                    const SizedBox(width: 12),
                    _StatusPill(state: status),
                    const SizedBox(width: 10),
                    _TopCircleButton(
                      icon: Icons.person_outline_rounded,
                      onTap: onUserTap,
                      tooltip: userLabel,
                      size: controlSize,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 46,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white
                .withValues(alpha: context.isNovaDark ? 0.08 : 0.50),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Icon(
            icon,
            color: colors.textPrimary,
            size: size < 42 ? 19 : 22,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.state,
    this.compact = false,
  });

  final NovaAssistantState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final color = switch (state) {
      NovaAssistantState.idle => colors.primary,
      NovaAssistantState.thinking => const Color(0xFF7A8DFF),
      NovaAssistantState.responding => const Color(0xFF4FA4FF),
      NovaAssistantState.suggesting => const Color(0xFF22C55E),
      NovaAssistantState.executing => const Color(0xFFFFA726),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        state.label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 11.2 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
