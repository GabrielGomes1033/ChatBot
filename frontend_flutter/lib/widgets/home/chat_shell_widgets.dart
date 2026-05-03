import 'package:flutter/material.dart';

import '../../components/nova_button.dart';
import '../../components/nova_card.dart';
import '../../components/nova_chat_bubble.dart';
import '../../theme/colors.dart';

class NovaChatLine {
  const NovaChatLine({
    required this.fromUser,
    required this.text,
  });

  final bool fromUser;
  final String text;
}

class NovaTopBar extends StatelessWidget {
  const NovaTopBar({
    super.key,
    required this.onOpenQuickMenu,
    required this.onOpenUsersDialog,
    required this.onPickQuickPhoto,
    this.compact = true,
    this.compressed = false,
  });

  final VoidCallback onOpenQuickMenu;
  final VoidCallback onOpenUsersDialog;
  final VoidCallback onPickQuickPhoto;
  final bool compact;
  final bool compressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final controlSize = compressed ? 44.0 : 48.0;

    return Row(
      children: [
        NovaPillIconButton(
          icon: Icons.widgets_rounded,
          onPressed: onOpenQuickMenu,
          size: controlSize,
          tooltip: 'Abrir painel rápido',
        ),
        const SizedBox(width: 12),
        Expanded(
          child: NovaCard(
            style: NovaCardStyle.glass,
            radius: 26,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _NovaLogoBadge(size: controlSize - 4),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'NOVA',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: compact ? 16 : 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Assistente inteligente para trabalho, pesquisa e operação.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: compact ? 11.5 : 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            NovaPillIconButton(
              icon: Icons.group_outlined,
              onPressed: onOpenUsersDialog,
              size: controlSize,
              tooltip: 'Usuários',
            ),
            const SizedBox(width: 8),
            NovaPillIconButton(
              icon: Icons.camera_alt_outlined,
              onPressed: onPickQuickPhoto,
              size: controlSize,
              tooltip: 'Analisar imagem',
            ),
          ],
        ),
      ],
    );
  }
}

class NovaChatTimeline extends StatelessWidget {
  const NovaChatTimeline({
    super.key,
    required this.chat,
    required this.compact,
    this.wide = false,
  });

  final List<NovaChatLine> chat;
  final bool compact;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final bubbleMaxWidth =
        wide ? 620.0 : (compact ? viewportWidth * 0.82 : 520.0);
    final userBubbleMaxWidth =
        wide ? 580.0 : (compact ? viewportWidth * 0.78 : 500.0);

    return NovaCard(
      style: NovaCardStyle.glass,
      radius: 30,
      padding: EdgeInsets.zero,
      expandChild: true,
      child: ListView.builder(
        reverse: true,
        padding: EdgeInsets.fromLTRB(
          compact ? 14 : 18,
          compact ? 16 : 20,
          compact ? 14 : 18,
          compact ? 16 : 20,
        ),
        itemCount: chat.length,
        itemBuilder: (context, index) {
          final item = chat[chat.length - 1 - index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: item.fromUser
                ? Align(
                    alignment: Alignment.centerRight,
                    child: NovaChatBubble(
                      text: item.text,
                      isUser: true,
                      maxWidth: userBubbleMaxWidth,
                      compact: compact,
                    ),
                  )
                : NovaChatBubble(
                    text: item.text,
                    isUser: false,
                    maxWidth: bubbleMaxWidth,
                    compact: compact,
                  ),
          );
        },
      ),
    );
  }
}

class NovaWorkspaceRail extends StatelessWidget {
  const NovaWorkspaceRail({
    super.key,
    required this.greeting,
    required this.systemStatus,
    required this.apiBaseUrl,
    required this.wakeWord,
    required this.voiceEnabled,
    required this.speechReady,
    required this.autonomyEnabled,
    required this.continuousWake,
    required this.examples,
    required this.jarvisMode,
    required this.toolsTotal,
    required this.memoryItems,
    required this.brainItems,
    required this.brainNotesTotal,
    required this.brainSuggestionsTotal,
    required this.toolNames,
    required this.voicePhase,
    required this.onOpenBrainDialog,
    this.compressed = false,
  });

  final String greeting;
  final String systemStatus;
  final String apiBaseUrl;
  final String wakeWord;
  final bool voiceEnabled;
  final bool speechReady;
  final bool autonomyEnabled;
  final bool continuousWake;
  final List<String> examples;
  final String jarvisMode;
  final int toolsTotal;
  final List<String> memoryItems;
  final List<String> brainItems;
  final int brainNotesTotal;
  final int brainSuggestionsTotal;
  final List<String> toolNames;
  final String voicePhase;
  final VoidCallback onOpenBrainDialog;
  final bool compressed;

  @override
  Widget build(BuildContext context) {
    final gap = compressed ? 12.0 : 14.0;
    final colors = context.novaColors;

    return NovaCard(
      style: NovaCardStyle.glass,
      radius: 32,
      padding: EdgeInsets.all(compressed ? 18 : 20),
      expandChild: true,
      child: ListView(
        children: [
          NovaCard(
            style: NovaCardStyle.brand,
            radius: 28,
            padding: EdgeInsets.fromLTRB(
              compressed ? 16 : 20,
              compressed ? 16 : 18,
              compressed ? 16 : 20,
              compressed ? 16 : 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 1.28,
                    child: Image.asset(
                      'assets/Logo-Nova.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: compressed ? 14 : 18),
                Text(
                  greeting,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compressed ? 28 : 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Uma experiência mais calma, clara e premium para conversar, organizar contexto e operar a sua rotina.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
          NovaCard(
            title: 'STATUS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  systemStatus,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _NovaInfoPill(
                      label: voiceEnabled ? 'Voz ativa' : 'Voz desligada',
                      active: voiceEnabled,
                    ),
                    _NovaInfoPill(
                      label: speechReady ? 'Microfone pronto' : 'Microfone off',
                      active: speechReady,
                    ),
                    _NovaInfoPill(
                      label: autonomyEnabled
                          ? 'Autonomia ligada'
                          : 'Autonomia off',
                      active: autonomyEnabled,
                    ),
                    _NovaInfoPill(
                      label: continuousWake ? 'Wake contínuo' : 'Push-to-talk',
                      active: continuousWake,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
          NovaCard(
            title: 'AMBIENTE',
            child: Column(
              children: [
                _NovaMetricRow(label: 'API', value: apiBaseUrl),
                const SizedBox(height: 10),
                _NovaMetricRow(label: 'Wake word', value: wakeWord),
                const SizedBox(height: 10),
                _NovaMetricRow(label: 'Modo', value: jarvisMode),
              ],
            ),
          ),
          SizedBox(height: gap),
          NovaCard(
            title: 'CAPACIDADES',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _NovaInfoPill(
                      label: '$toolsTotal ferramentas',
                      active: toolsTotal > 0,
                    ),
                    _NovaInfoPill(
                      label: 'Voz $voicePhase',
                      active: voicePhase.toLowerCase() != 'planned',
                    ),
                    _NovaInfoPill(
                      label:
                          memoryItems.isEmpty ? 'Sem memória' : 'Memória ativa',
                      active: memoryItems.isNotEmpty,
                    ),
                  ],
                ),
                if (toolNames.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    toolNames.take(4).join(' • '),
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: gap),
          NovaCard(
            title: 'MEMÓRIA',
            style: NovaCardStyle.muted,
            child: memoryItems.isEmpty
                ? Text(
                    'Quando a conversa evolui, a NOVA começa a guardar contexto útil aqui para reduzir repetição e aumentar precisão.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  )
                : Column(
                    children: memoryItems
                        .take(4)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NovaBulletText(
                              text: item,
                              icon: Icons.memory_rounded,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          SizedBox(height: gap),
          NovaCard(
            title: 'BRAIN VAULT',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _NovaInfoPill(
                      label: '$brainNotesTotal notas',
                      active: brainNotesTotal > 0,
                    ),
                    _NovaInfoPill(
                      label: '$brainSuggestionsTotal sugestões',
                      active: brainSuggestionsTotal > 0,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  brainItems.isEmpty
                      ? 'As conexões e notas do vault aparecem aqui conforme a NOVA aprende com projetos e contexto.'
                      : brainItems.take(3).join('\n'),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                NovaButton(
                  label: 'Abrir vault',
                  icon: Icons.hub_outlined,
                  tone: NovaButtonTone.secondary,
                  expanded: true,
                  onPressed: onOpenBrainDialog,
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
          NovaCard(
            title: 'EXEMPLOS',
            style: NovaCardStyle.muted,
            child: Column(
              children: examples
                  .take(5)
                  .map(
                    (example) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NovaBulletText(
                        text: example,
                        icon: Icons.subdirectory_arrow_right_rounded,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class NovaComposer extends StatelessWidget {
  const NovaComposer({
    super.key,
    required this.messageController,
    required this.composerAttachmentName,
    required this.speechReady,
    required this.isListening,
    required this.sending,
    required this.onPickComposerAttachment,
    required this.onToggleListening,
    required this.onInitSpeech,
    required this.onSendMessage,
    this.compact = true,
    this.compressed = false,
  });

  final TextEditingController messageController;
  final String? composerAttachmentName;
  final bool speechReady;
  final bool isListening;
  final bool sending;
  final VoidCallback onPickComposerAttachment;
  final VoidCallback onToggleListening;
  final VoidCallback onInitSpeech;
  final VoidCallback onSendMessage;
  final bool compact;
  final bool compressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final composerHeight = compressed ? 66.0 : 74.0;

    return NovaCard(
      style: NovaCardStyle.glass,
      radius: 30,
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        height: composerHeight,
        child: Row(
          children: [
            NovaPillIconButton(
              icon: Icons.add_rounded,
              onPressed: onPickComposerAttachment,
              tooltip: 'Anexar arquivo',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.border),
                ),
                child: Center(
                  child: TextField(
                    controller: messageController,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: compact ? 15 : 16,
                      height: 1.45,
                    ),
                    cursorColor: colors.primary,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: composerAttachmentName == null
                          ? 'Escreva sua próxima pergunta...'
                          : 'Anexo selecionado: $composerAttachmentName',
                      hintStyle: TextStyle(
                        color: colors.textSecondary,
                        fontSize: compact ? 14 : 15,
                      ),
                    ),
                    onSubmitted: (_) => onSendMessage(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            NovaPillIconButton(
              icon: isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              onPressed: speechReady ? onToggleListening : onInitSpeech,
              selected: isListening,
              tooltip: isListening ? 'Parar escuta' : 'Ativar microfone',
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 58,
              height: 58,
              child: FilledButton(
                onPressed: sending ? null : onSendMessage,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: sending
                      ? const SizedBox(
                          key: ValueKey('spinner'),
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.1,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          key: ValueKey('send'),
                          size: 22,
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

class NovaGridBackground extends StatelessWidget {
  const NovaGridBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.background,
            colors.surfaceMuted
                .withValues(alpha: context.isNovaDark ? 0.42 : 0.96),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: _NovaGlowOrb(
              size: 240,
              color: colors.brandGlow.withValues(alpha: 0.85),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: _NovaGlowOrb(
              size: 280,
              color: colors.primarySoft.withValues(alpha: 0.95),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white
                          .withValues(alpha: context.isNovaDark ? 0.02 : 0.32),
                      Colors.transparent,
                      colors.overlay,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NovaLogoBadge extends StatelessWidget {
  const _NovaLogoBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.brandSurface,
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(color: colors.brandGlow.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: colors.brandGlow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: Image.asset(
          'assets/Logo-Nova.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
    );
  }
}

class _NovaInfoPill extends StatelessWidget {
  const _NovaInfoPill({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: active ? colors.primarySoft : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? colors.primary : colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? colors.primary : colors.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NovaMetricRow extends StatelessWidget {
  const _NovaMetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _NovaBulletText extends StatelessWidget {
  const _NovaBulletText({
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(icon, size: 16, color: colors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _NovaGlowOrb extends StatelessWidget {
  const _NovaGlowOrb({
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
              color.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
