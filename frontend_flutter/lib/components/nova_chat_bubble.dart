import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../widgets/glass_container.dart';

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
    final textWidget = Text(
      text,
      style: TextStyle(
        color: isUser ? Colors.white : colors.textPrimary,
        fontSize: compact ? 14 : 15,
        height: 1.55,
        fontWeight: FontWeight.w500,
      ),
    );

    final bubble = isUser
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 18,
              vertical: compact ? 12 : 14,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary.withValues(alpha: 0.92),
                  Color.lerp(colors.primary, Colors.white, 0.18)!,
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(28),
                topRight: const Radius.circular(28),
                bottomLeft: Radius.circular(isUser ? 28 : 14),
                bottomRight: Radius.circular(isUser ? 14 : 28),
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: textWidget,
          )
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: GlassContainer(
              borderRadius: 28,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 18,
                vertical: compact ? 12 : 14,
              ),
              blur: 14,
              opacity: context.isNovaDark ? 0.12 : 0.28,
              borderColor: colors.assistantStroke,
              child: textWidget,
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
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white
                .withValues(alpha: context.isNovaDark ? 0.08 : 0.52),
            border: Border.all(color: colors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: colors.brandGlow.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/Logo-Nova.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(child: bubble),
      ],
    );
  }
}
