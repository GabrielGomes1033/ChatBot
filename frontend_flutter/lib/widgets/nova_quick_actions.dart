import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../widgets/glass_container.dart';
import 'home/chat_shell_widgets.dart' show NovaConversationAction;

class NovaQuickActions extends StatelessWidget {
  const NovaQuickActions({
    super.key,
    required this.actions,
    required this.onActionTap,
    this.compact = false,
  });

  final List<NovaConversationAction> actions;
  final ValueChanged<NovaConversationAction> onActionTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Próximo passo',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: compact ? 11.5 : 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: actions
              .take(4)
              .map(
                (action) => GestureDetector(
                  onTap: () => onActionTap(action),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: compact ? 220 : 260,
                    ),
                    child: GlassContainer(
                      borderRadius: 18,
                      blur: 18,
                      opacity: context.isNovaDark ? 0.16 : 0.28,
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 12 : 14,
                        vertical: compact ? 10 : 11,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            action.icon ?? Icons.bolt_rounded,
                            size: compact ? 15 : 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              action.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: compact ? 12.5 : 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
