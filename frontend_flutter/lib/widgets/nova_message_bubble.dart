import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'glass_container.dart';
import 'home/chat_shell_widgets.dart' show NovaConversationAction;

class NovaMessageBubble extends StatelessWidget {
  const NovaMessageBubble({
    super.key,
    required this.fromUser,
    required this.text,
    required this.timestamp,
    this.summary,
    this.viewLabel,
    this.onViewTap,
    this.copyLabel,
    this.onCopyTap,
    this.actions = const [],
    this.onActionTap,
    this.isLive = false,
  });

  final bool fromUser;
  final String text;
  final String? summary;
  final DateTime timestamp;
  final String? viewLabel;
  final VoidCallback? onViewTap;
  final String? copyLabel;
  final VoidCallback? onCopyTap;
  final List<NovaConversationAction> actions;
  final ValueChanged<NovaConversationAction>? onActionTap;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final messageText = fromUser
        ? text
        : (text.trim().isNotEmpty ? text.trim() : (summary?.trim() ?? ''));
    final preferredMaxWidth = fromUser ? 560.0 : 660.0;
    final relativeMaxWidth =
        fromUser ? viewportWidth * 0.84 : viewportWidth * 0.88;
    final bubbleMaxWidth = relativeMaxWidth < preferredMaxWidth
        ? relativeMaxWidth
        : preferredMaxWidth;

    final bubble = GlassContainer(
      borderRadius: 28,
      blur: 18,
      opacity: fromUser
          ? (context.isNovaDark ? 0.10 : 0.16)
          : (context.isNovaDark ? 0.16 : 0.30),
      padding: const EdgeInsets.all(16),
      borderColor: fromUser ? colors.primary.withValues(alpha: 0.42) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!fromUser) ...[
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.brandSurface.withValues(alpha: 0.92),
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/Logo-Nova.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLive ? 'NOVA pensando...' : 'NOVA',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            messageText,
            style: TextStyle(
              color: fromUser ? colors.textPrimary : colors.textPrimary,
              fontSize: fromUser ? 14.8 : 15.2,
              height: 1.55,
              fontWeight: fromUser ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          if (!fromUser && (onViewTap != null || onCopyTap != null)) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final chipMaxWidth =
                    constraints.maxWidth < 320 ? constraints.maxWidth : 280.0;
                final expandChip = constraints.maxWidth < 360;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (onViewTap != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: chipMaxWidth),
                        child: _buildActionChip(
                          context: context,
                          icon: Icons.code_rounded,
                          label: (viewLabel?.trim().isNotEmpty ?? false)
                              ? viewLabel!.trim()
                              : 'Ver codigo',
                          onTap: onViewTap!,
                          emphasized: false,
                          expand: expandChip,
                        ),
                      ),
                    if (onCopyTap != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: chipMaxWidth),
                        child: _buildActionChip(
                          context: context,
                          icon: Icons.content_copy_rounded,
                          label: (copyLabel?.trim().isNotEmpty ?? false)
                              ? copyLabel!.trim()
                              : 'Copiar codigo',
                          onTap: onCopyTap!,
                          emphasized: true,
                          expand: expandChip,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _formatTime(timestamp),
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: bubbleMaxWidth,
        ),
        child: bubble,
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hours = value.hour.toString().padLeft(2, '0');
    final minutes = value.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  Widget _buildActionChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool emphasized,
    bool expand = false,
  }) {
    final colors = context.novaColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: emphasized
              ? colors.primarySoft.withValues(alpha: 0.16)
              : Colors.white.withValues(
                  alpha: context.isNovaDark ? 0.08 : 0.42,
                ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: emphasized
                ? colors.primary.withValues(alpha: 0.28)
                : colors.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: emphasized ? colors.primary : colors.textPrimary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: expand ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: emphasized ? colors.primary : colors.textPrimary,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
