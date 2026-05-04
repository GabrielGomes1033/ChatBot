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
    required this.onCameraTap,
    required this.status,
    required this.contextText,
    this.userLabel = 'Usuário',
  });

  final VoidCallback onMenuTap;
  final VoidCallback onUserTap;
  final VoidCallback onCameraTap;
  final NovaAssistantState status;
  final String contextText;
  final String userLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;

    return GlassContainer(
      borderRadius: 28,
      blur: 22,
      opacity: context.isNovaDark ? 0.16 : 0.30,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _TopCircleButton(
            icon: Icons.grid_view_rounded,
            onTap: onMenuTap,
            tooltip: 'Menu rápido',
          ),
          const SizedBox(width: 12),
          const NovaMetalLogo(size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOVA',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contextText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.8,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusPill(state: status),
          const SizedBox(width: 10),
          _TopCircleButton(
            icon: Icons.person_outline_rounded,
            onTap: onUserTap,
            tooltip: userLabel,
          ),
          const SizedBox(width: 8),
          _TopCircleButton(
            icon: Icons.camera_alt_outlined,
            onTap: onCameraTap,
            tooltip: 'Abrir câmera',
          ),
        ],
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white
                .withValues(alpha: context.isNovaDark ? 0.08 : 0.50),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Icon(
            icon,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.state,
  });

  final NovaAssistantState state;

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        state.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
