import 'package:flutter/material.dart';

import '../theme/colors.dart';

class NovaChatBubble extends StatelessWidget {
  const NovaChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.maxWidth,
    this.compact = false,
  });

  final String text;
  final bool isUser;
  final double maxWidth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final bubble = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 18,
        vertical: compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: isUser ? colors.userBubble : colors.assistantBubble,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(24),
          topRight: const Radius.circular(24),
          bottomLeft: Radius.circular(isUser ? 24 : 12),
          bottomRight: Radius.circular(isUser ? 12 : 24),
        ),
        border: Border.all(
          color: isUser
              ? colors.primary
                  .withValues(alpha: context.isNovaDark ? 0.55 : 0.18)
              : colors.assistantStroke,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(
              alpha: context.isNovaDark ? 0.26 : 0.09,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isUser ? Colors.white : colors.textPrimary,
          fontSize: compact ? 14 : 15,
          height: 1.55,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    if (isUser) {
      return bubble;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 36 : 40,
          height: compact ? 36 : 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: colors.brandSurface,
            border: Border.all(color: colors.border.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: colors.brandGlow,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            'N',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 17 : 18,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(child: bubble),
      ],
    );
  }
}
