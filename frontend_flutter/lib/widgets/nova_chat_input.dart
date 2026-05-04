import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'glass_container.dart';

class NovaChatInput extends StatelessWidget {
  const NovaChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onMic,
    this.onAdd,
    this.attachmentName,
    this.onRemoveAttachment,
    this.isListening = false,
    this.sending = false,
    this.compact = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onMic;
  final VoidCallback? onAdd;
  final String? attachmentName;
  final VoidCallback? onRemoveAttachment;
  final bool isListening;
  final bool sending;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final controlSize = compact ? 40.0 : 46.0;
    final sendSize = compact ? 52.0 : 58.0;
    final hasAttachment =
        attachmentName != null && attachmentName!.trim().isNotEmpty;

    Widget circleButton({
      required IconData icon,
      required VoidCallback? onTap,
      bool active = false,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: controlSize,
          width: controlSize,
          decoration: BoxDecoration(
            color: active
                ? colors.primarySoft
                : Colors.white.withValues(
                    alpha: context.isNovaDark ? 0.10 : 0.58,
                  ),
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? colors.primary : colors.glassBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(
                  alpha: context.isNovaDark ? 0.34 : 0.08,
                ),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: colors.glassHighlight.withValues(
                  alpha: context.isNovaDark ? 0.10 : 0.42,
                ),
                blurRadius: 6,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: active ? colors.primary : colors.textPrimary,
            size: compact ? 22 : 24,
          ),
        ),
      );
    }

    return GlassContainer(
      borderRadius: compact ? 30 : 34,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 8 : 10,
      ),
      blur: 20,
      opacity: context.isNovaDark ? 0.16 : 0.32,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          circleButton(
            icon: Icons.attach_file_rounded,
            onTap: onAdd,
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Container(
              constraints: BoxConstraints(
                minHeight: compact ? 52 : 58,
                maxHeight: hasAttachment
                    ? (compact ? 118 : 132)
                    : (compact ? 92 : 108),
              ),
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 16,
                compact ? 10 : 11,
                compact ? 14 : 16,
                compact ? 10 : 11,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: context.isNovaDark ? 0.10 : 0.44,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.glassBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasAttachment) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primarySoft.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.insert_drive_file_outlined,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              attachmentName!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: compact ? 12.4 : 12.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (onRemoveAttachment != null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: onRemoveAttachment,
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: compact ? 15 : 15.6,
                      height: 1.35,
                    ),
                    cursorColor: colors.primary,
                    decoration: InputDecoration(
                      hintText:
                          'Descreva o próximo passo, peça uma análise ou envie um arquivo...',
                      hintStyle: TextStyle(
                        color: colors.textSecondary,
                        fontSize: compact ? 14 : 14.5,
                        height: 1.3,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          circleButton(
            icon: isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
            onTap: onMic,
            active: isListening,
          ),
          SizedBox(width: compact ? 8 : 10),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: sendSize,
              width: sendSize,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.44),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: sending
                    ? const Center(
                        key: ValueKey('loading'),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward_rounded,
                        key: ValueKey('send'),
                        color: Colors.white,
                        size: 28,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
