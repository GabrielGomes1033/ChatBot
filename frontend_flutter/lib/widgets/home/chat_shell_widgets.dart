import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../components/nova_button.dart';
import '../../components/nova_card.dart';
import '../../components/nova_chat_bubble.dart';
import '../../theme/colors.dart';
import '../../widgets/nova_chat_input.dart';

enum NovaAssistantState {
  idle,
  thinking,
  responding,
  suggesting,
  executing,
}

extension NovaAssistantStateX on NovaAssistantState {
  String get label => switch (this) {
        NovaAssistantState.idle => 'Idle',
        NovaAssistantState.thinking => 'Pensando',
        NovaAssistantState.responding => 'Respondendo',
        NovaAssistantState.suggesting => 'Sugerindo',
        NovaAssistantState.executing => 'Executando',
      };

  String get hint => switch (this) {
        NovaAssistantState.idle => 'Pronta para agir quando voce quiser.',
        NovaAssistantState.thinking =>
          'A NOVA esta entendendo o contexto antes de agir.',
        NovaAssistantState.responding =>
          'A NOVA esta montando a melhor resposta para agora.',
        NovaAssistantState.suggesting =>
          'A NOVA ja separou os proximos passos mais uteis.',
        NovaAssistantState.executing =>
          'A NOVA esta executando algo por voce com contexto.',
      };

  IconData get icon => switch (this) {
        NovaAssistantState.idle => Icons.auto_awesome_rounded,
        NovaAssistantState.thinking => Icons.psychology_alt_rounded,
        NovaAssistantState.responding => Icons.chat_bubble_outline_rounded,
        NovaAssistantState.suggesting => Icons.flash_on_rounded,
        NovaAssistantState.executing => Icons.play_circle_fill_rounded,
      };
}

class NovaConversationAction {
  const NovaConversationAction({
    required this.label,
    required this.prompt,
    this.primary = false,
    this.icon,
  });

  final String label;
  final String prompt;
  final bool primary;
  final IconData? icon;
}

class NovaModuleSnapshot {
  const NovaModuleSnapshot({
    required this.title,
    required this.description,
    required this.metric,
    required this.icon,
    this.active = false,
  });

  final String title;
  final String description;
  final String metric;
  final IconData icon;
  final bool active;
}

class NovaChatLine {
  NovaChatLine({
    required this.fromUser,
    required this.text,
    this.summary,
    this.explanation,
    this.actions = const [],
    this.suggestions = const [],
    this.state = NovaAssistantState.idle,
    this.highlight = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final bool fromUser;
  final String text;
  final String? summary;
  final String? explanation;
  final List<NovaConversationAction> actions;
  final List<NovaConversationAction> suggestions;
  final NovaAssistantState state;
  final bool highlight;
  final DateTime timestamp;
}

class NovaTopBar extends StatelessWidget {
  const NovaTopBar({
    super.key,
    required this.onOpenQuickMenu,
    required this.onOpenUsersDialog,
    required this.onPickQuickPhoto,
    required this.contextLabel,
    required this.assistantState,
    this.compact = true,
    this.compressed = false,
  });

  final VoidCallback onOpenQuickMenu;
  final VoidCallback onOpenUsersDialog;
  final VoidCallback onPickQuickPhoto;
  final String contextLabel;
  final NovaAssistantState assistantState;
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
          tooltip: 'Abrir painel rapido',
        ),
        const SizedBox(width: 12),
        Expanded(
          child: NovaCard(
            style: NovaCardStyle.glass,
            radius: 26,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _NovaLogoBadge(size: controlSize - 2),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'NOVA',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: compact ? 16.5 : 17.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.18,
                              ),
                            ),
                          ),
                          _NovaAssistantStatePill(
                            state: assistantState,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contextLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: compact ? 11.5 : 12.5,
                          height: 1.35,
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
              tooltip: 'Usuarios',
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
    required this.assistantState,
    required this.showLiveState,
    required this.onActionSelected,
    this.wide = false,
  });

  final List<NovaChatLine> chat;
  final bool compact;
  final bool wide;
  final NovaAssistantState assistantState;
  final bool showLiveState;
  final ValueChanged<NovaConversationAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final bubbleMaxWidth =
        wide ? 660.0 : (compact ? viewportWidth * 0.82 : 560.0);
    final userBubbleMaxWidth =
        wide ? 600.0 : (compact ? viewportWidth * 0.78 : 520.0);
    final totalItems = chat.length + (showLiveState ? 1 : 0);

    return NovaCard(
      style: NovaCardStyle.glass,
      radius: 32,
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
        itemCount: totalItems,
        itemBuilder: (context, index) {
          if (showLiveState && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _NovaTimelineEntrance(
                index: index,
                child: _NovaAssistantLiveCard(
                  state: assistantState,
                  compact: compact,
                ),
              ),
            );
          }

          final adjustedIndex = showLiveState ? index - 1 : index;
          final item = chat[chat.length - 1 - adjustedIndex];
          final child = item.fromUser
              ? Align(
                  alignment: Alignment.centerRight,
                  child: NovaChatBubble(
                    text: item.text,
                    isUser: true,
                    maxWidth: userBubbleMaxWidth,
                    compact: compact,
                  ),
                )
              : _NovaAssistantMessageCard(
                  line: item,
                  compact: compact,
                  maxWidth: bubbleMaxWidth,
                  onActionSelected: onActionSelected,
                );

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _NovaTimelineEntrance(
              index: adjustedIndex + (showLiveState ? 1 : 0),
              child: child,
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
    required this.briefing,
    required this.systemStatus,
    required this.wakeWord,
    required this.voiceEnabled,
    required this.speechReady,
    required this.autonomyEnabled,
    required this.continuousWake,
    required this.examples,
    required this.memoryItems,
    required this.brainItems,
    required this.brainNotesTotal,
    required this.assistantState,
    required this.priorityActions,
    required this.onActionSelected,
    required this.onOpenBrainDialog,
    this.compressed = false,
  });

  final String greeting;
  final String briefing;
  final String systemStatus;
  final String wakeWord;
  final bool voiceEnabled;
  final bool speechReady;
  final bool autonomyEnabled;
  final bool continuousWake;
  final List<String> examples;
  final List<String> memoryItems;
  final List<String> brainItems;
  final int brainNotesTotal;
  final NovaAssistantState assistantState;
  final List<NovaConversationAction> priorityActions;
  final ValueChanged<NovaConversationAction> onActionSelected;
  final VoidCallback onOpenBrainDialog;
  final bool compressed;

  @override
  Widget build(BuildContext context) {
    final gap = 12.0;
    final colors = context.novaColors;
    final voiceReady = voiceEnabled && speechReady;
    final hasMemories = memoryItems.isNotEmpty;
    final hasVaultNotes = brainItems.isNotEmpty || brainNotesTotal > 0;

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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _NovaGlowOrb(
                        size: compressed ? 120 : 140,
                        color: colors.primarySoft.withValues(
                          alpha: context.isNovaDark ? 0.64 : 0.90,
                        ),
                      ),
                      _NovaLogoBadge(size: compressed ? 88 : 104),
                    ],
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
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  briefing,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                _NovaAssistantStatePill(state: assistantState),
                if (priorityActions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: priorityActions
                        .take(3)
                        .map(
                          (action) => _NovaActionChip(
                            action: action,
                            compact: true,
                            onTap: () => onActionSelected(action),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: gap),
          NovaCard(
            title: 'Agora',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _friendlySystemStatus(systemStatus),
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
                      label: voiceReady ? 'Voz pronta' : 'Texto pronto',
                      active: voiceReady,
                    ),
                    _NovaInfoPill(
                      label: autonomyEnabled
                          ? 'Fluxo autonomo'
                          : 'Controle manual',
                      active: autonomyEnabled,
                    ),
                    _NovaInfoPill(
                      label: continuousWake
                          ? 'Escuta continua'
                          : 'Toque para falar',
                      active: continuousWake,
                    ),
                    _NovaInfoPill(
                      label: hasMemories
                          ? 'NOVA lembra'
                          : 'Memoria pronta para aprender',
                      active: hasMemories,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
          _NovaExpandableSection(
            title: 'Seu jeito',
            summary:
                'Ajuste a personalidade operacional da NOVA para combinar com o ritmo do seu dia.',
            child: Column(
              children: [
                _NovaMetricRow(
                  label: 'Chame por',
                  value:
                      '"${wakeWord.trim().isEmpty ? 'Nova' : wakeWord.trim()}"',
                ),
                const SizedBox(height: 10),
                _NovaMetricRow(
                  label: 'Conversa',
                  value: voiceEnabled
                      ? (continuousWake
                          ? 'Natural, com iniciativa e maos livres'
                          : 'Direta, com voz sob demanda')
                      : 'Focada em texto e clareza',
                ),
                const SizedBox(height: 10),
                _NovaMetricRow(
                  label: 'Ritmo',
                  value: autonomyEnabled
                      ? 'A NOVA sugere e executa quando faz sentido.'
                      : 'Voce confirma cada etapa importante.',
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
          _NovaExpandableSection(
            title: 'NOVA lembra',
            style: NovaCardStyle.muted,
            summary: hasMemories
                ? 'A NOVA ja guardou ${memoryItems.length} ponto${memoryItems.length == 1 ? '' : 's'} do seu contexto para reduzir repeticao.'
                : 'Conforme voce usa a NOVA, preferencias e contexto importante aparecem aqui.',
            child: hasMemories
                ? Column(
                    children: memoryItems
                        .take(4)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NovaBulletText(
                              text: item,
                              icon: Icons.favorite_outline_rounded,
                            ),
                          ),
                        )
                        .toList(),
                  )
                : Text(
                    'Projetos, preferencias e padroes do seu jeito de trabalhar vao ganhar destaque aqui.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
          ),
          SizedBox(height: gap),
          _NovaExpandableSection(
            title: 'Notas e ideias',
            summary: hasVaultNotes
                ? '$brainNotesTotal nota${brainNotesTotal == 1 ? '' : 's'} pronta${brainNotesTotal == 1 ? '' : 's'} para retomar.'
                : 'Decisoes, aprendizados e descobertas vao ficar organizados nesse espaco.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _NovaInfoPill(
                      label: hasVaultNotes
                          ? '$brainNotesTotal salvas'
                          : 'Espaco pronto',
                      active: hasVaultNotes,
                    ),
                    _NovaInfoPill(
                      label: hasVaultNotes
                          ? 'Retomar com contexto'
                          : 'Comece a registrar',
                      active: hasVaultNotes,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (brainItems.isEmpty)
                  Text(
                    'Use o vault para registrar decisoes importantes, insights e referencias do que a NOVA precisa levar adiante.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  )
                else
                  Column(
                    children: brainItems
                        .take(3)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NovaBulletText(
                              text: item,
                              icon: Icons.auto_awesome_outlined,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 14),
                NovaButton(
                  label: 'Abrir notas',
                  icon: Icons.hub_outlined,
                  tone: NovaButtonTone.secondary,
                  expanded: true,
                  onPressed: onOpenBrainDialog,
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
          _NovaExpandableSection(
            title: 'Peça assim',
            style: NovaCardStyle.muted,
            summary:
                'Alguns exemplos para comecar com clareza e colocar a NOVA em modo operacional.',
            initiallyExpanded: false,
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

class NovaContextPanel extends StatelessWidget {
  const NovaContextPanel({
    super.key,
    required this.assistantState,
    required this.focusTitle,
    required this.focusDescription,
    required this.insights,
    required this.actions,
    required this.modules,
    required this.documents,
    required this.historyItems,
    required this.onActionSelected,
    required this.onOpenBrainDialog,
    this.compressed = false,
  });

  final NovaAssistantState assistantState;
  final String focusTitle;
  final String focusDescription;
  final List<String> insights;
  final List<NovaConversationAction> actions;
  final List<NovaModuleSnapshot> modules;
  final List<String> documents;
  final List<String> historyItems;
  final ValueChanged<NovaConversationAction> onActionSelected;
  final VoidCallback onOpenBrainDialog;
  final bool compressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;

    return NovaCard(
      style: NovaCardStyle.glass,
      radius: 32,
      padding: EdgeInsets.all(compressed ? 18 : 20),
      expandChild: true,
      child: ListView(
        children: [
          NovaCard(
            style: NovaCardStyle.standard,
            radius: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        focusTitle,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    _NovaAssistantStatePill(
                      state: assistantState,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  focusDescription,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _NovaPanelSectionCard(
            title: 'Insights',
            child: Column(
              children: insights
                  .take(4)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NovaBulletText(
                        text: item,
                        icon: Icons.insights_rounded,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _NovaPanelSectionCard(
            title: 'Acoes automaticas',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: actions
                      .take(4)
                      .map(
                        (action) => _NovaActionChip(
                          action: action,
                          compact: true,
                          onTap: () => onActionSelected(action),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                NovaButton(
                  label: 'Abrir memoria e notas',
                  icon: Icons.auto_awesome_motion_rounded,
                  tone: NovaButtonTone.secondary,
                  expanded: true,
                  onPressed: onOpenBrainDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _NovaPanelSectionCard(
            title: 'Modulos',
            child: Column(
              children: modules
                  .map(
                    (module) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NovaModuleCard(module: module),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _NovaPanelSectionCard(
            title: 'Documentos',
            child: documents.isEmpty
                ? Text(
                    'Anexos, notas e referencias recentes vao aparecer aqui.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  )
                : Column(
                    children: documents
                        .take(4)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NovaBulletText(
                              text: item,
                              icon: Icons.description_outlined,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),
          _NovaPanelSectionCard(
            title: 'Historico',
            child: historyItems.isEmpty
                ? Text(
                    'As ultimas movimentacoes da conversa vao aparecer aqui.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  )
                : Column(
                    children: historyItems
                        .take(4)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NovaBulletText(
                              text: item,
                              icon: Icons.history_rounded,
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

String _friendlySystemStatus(String status) {
  final normalized = status.trim().toLowerCase();

  if (normalized.contains('online') ||
      normalized.contains('ready') ||
      normalized.contains('ok') ||
      normalized.contains('conectada')) {
    return 'Tudo pronto para pensar junto, sugerir caminhos e executar quando fizer sentido.';
  }

  if (normalized.contains('offline') || normalized.contains('disconnected')) {
    return 'A base da NOVA segue disponivel, mas alguns recursos externos podem demorar um pouco mais.';
  }

  if (normalized.contains('erro') || normalized.contains('error')) {
    return 'Alguns recursos precisam de atencao. Ainda assim, a NOVA pode continuar organizando seu contexto.';
  }

  return 'Seu espaco operacional esta pronto para ajudar no que vier a seguir.';
}

class _NovaExpandableSection extends StatefulWidget {
  const _NovaExpandableSection({
    required this.title,
    required this.summary,
    required this.child,
    this.style = NovaCardStyle.standard,
    this.initiallyExpanded = false,
  });

  final String title;
  final String summary;
  final Widget child;
  final NovaCardStyle style;
  final bool initiallyExpanded;

  @override
  State<_NovaExpandableSection> createState() => _NovaExpandableSectionState();
}

class _NovaExpandableSectionState extends State<_NovaExpandableSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;

    return NovaCard(
      style: widget.style,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.summary,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    turns: _expanded ? 0.5 : 0,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colors.glass.withValues(
                          alpha: context.isNovaDark ? 0.20 : 0.44,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: widget.child,
                    )
                  : const SizedBox.shrink(),
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
    return NovaChatInput(
      controller: messageController,
      onSend: onSendMessage,
      onMic: speechReady ? onToggleListening : onInitSpeech,
      onAdd: onPickComposerAttachment,
      attachmentName: composerAttachmentName,
      isListening: isListening,
      sending: sending,
      compact: compact || compressed,
    );
  }
}

class NovaGridBackground extends StatefulWidget {
  const NovaGridBackground({super.key});

  @override
  State<NovaGridBackground> createState() => _NovaGridBackgroundState();
}

class _NovaGridBackgroundState extends State<NovaGridBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Offset _pointer = const Offset(0.72, 0.18);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final size = MediaQuery.sizeOf(context);

    return MouseRegion(
      onHover: (event) {
        final dx =
            (event.localPosition.dx / math.max(size.width, 1)).clamp(0.0, 1.0);
        final dy =
            (event.localPosition.dy / math.max(size.height, 1)).clamp(0.0, 1.0);
        setState(() => _pointer = Offset(dx, dy));
      },
      onExit: (_) => setState(() => _pointer = const Offset(0.72, 0.18)),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          final topAlignment = Alignment.lerp(
            const Alignment(-1.0, -0.8),
            Alignment(_pointer.dx * 2 - 1, (_pointer.dy * 1.4) - 1),
            0.38,
          )!;
          final rightAlignment = Alignment.lerp(
            const Alignment(1.2, -0.7),
            const Alignment(0.5, -0.15),
            t,
          )!;
          final bottomAlignment = Alignment.lerp(
            const Alignment(-0.6, 1.1),
            const Alignment(0.2, 0.8),
            t,
          )!;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.lerp(
                  Alignment.topLeft,
                  const Alignment(-0.2, -1.0),
                  t,
                )!,
                end: Alignment.lerp(
                  Alignment.bottomRight,
                  const Alignment(1.0, 0.35),
                  t,
                )!,
                colors: [
                  colors.backgroundStart,
                  colors.backgroundEnd,
                ],
              ),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: topAlignment,
                  child: _NovaGlowOrb(
                    size: 360,
                    color: Colors.white.withValues(
                      alpha: context.isNovaDark ? 0.08 : 0.28,
                    ),
                  ),
                ),
                Align(
                  alignment: rightAlignment,
                  child: _NovaGlowOrb(
                    size: 320,
                    color: colors.primarySoft.withValues(
                      alpha: context.isNovaDark ? 0.42 : 0.88,
                    ),
                  ),
                ),
                Align(
                  alignment: bottomAlignment,
                  child: _NovaGlowOrb(
                    size: 360,
                    color: colors.brandGlow.withValues(
                      alpha: context.isNovaDark ? 0.34 : 0.42,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.lerp(
                            Alignment.topLeft,
                            const Alignment(-0.6, -0.2),
                            t,
                          )!,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(
                              alpha: context.isNovaDark ? 0.02 : 0.16,
                            ),
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
        },
      ),
    );
  }
}

class _NovaTimelineEntrance extends StatelessWidget {
  const _NovaTimelineEntrance({
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final safeIndex = index.clamp(0, 5);
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (safeIndex * 28)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      child: child,
      builder: (context, value, builtChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: builtChild,
          ),
        );
      },
    );
  }
}

class _NovaAssistantMessageCard extends StatelessWidget {
  const _NovaAssistantMessageCard({
    required this.line,
    required this.compact,
    required this.maxWidth,
    required this.onActionSelected,
  });

  final NovaChatLine line;
  final bool compact;
  final double maxWidth;
  final ValueChanged<NovaConversationAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final summary = (line.summary?.trim().isNotEmpty == true
        ? line.summary!.trim()
        : line.text.trim());
    final explanation = (line.explanation?.trim().isNotEmpty == true
        ? line.explanation!.trim()
        : line.text.trim());
    final actions = [
      ...line.actions,
      ...line.suggestions.where(
        (item) => !line.actions
            .map((existing) => existing.label.toLowerCase())
            .contains(item.label.toLowerCase()),
      ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: NovaCard(
        style: line.highlight ? NovaCardStyle.brand : NovaCardStyle.standard,
        radius: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 42 : 46,
                  height: compact ? 42 : 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                      alpha: context.isNovaDark ? 0.08 : 0.52,
                    ),
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/Logo-Nova.png',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'NOVA',
                              style: TextStyle(
                                color: line.highlight
                                    ? Colors.white
                                    : colors.textPrimary,
                                fontSize: compact ? 14.5 : 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _NovaAssistantStatePill(
                            state: line.state,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        style: TextStyle(
                          color: line.highlight
                              ? Colors.white
                              : colors.textPrimary,
                          fontSize: compact ? 16 : 17,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (explanation.isNotEmpty &&
                explanation.toLowerCase() != summary.toLowerCase()) ...[
              const SizedBox(height: 12),
              Text(
                explanation,
                style: TextStyle(
                  color: line.highlight
                      ? Colors.white.withValues(alpha: 0.82)
                      : colors.textSecondary,
                  fontSize: compact ? 13.5 : 14.2,
                  height: 1.55,
                ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Proximo passo',
                style: TextStyle(
                  color: line.highlight
                      ? Colors.white.withValues(alpha: 0.72)
                      : colors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: actions
                    .take(4)
                    .map(
                      (action) => _NovaActionChip(
                        action: action,
                        onTap: () => onActionSelected(action),
                        invertColors: line.highlight,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _formatTime(line.timestamp),
              style: TextStyle(
                color: line.highlight
                    ? Colors.white.withValues(alpha: 0.58)
                    : colors.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NovaAssistantLiveCard extends StatelessWidget {
  const _NovaAssistantLiveCard({
    required this.state,
    required this.compact,
  });

  final NovaAssistantState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 420 : 520),
      child: NovaCard(
        style: NovaCardStyle.standard,
        radius: 26,
        child: Row(
          children: [
            _NovaPulseOrb(color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NOVA esta ${state.label.toLowerCase()}...',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: compact ? 15 : 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.hint,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NovaPanelSectionCard extends StatelessWidget {
  const _NovaPanelSectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      style: NovaCardStyle.standard,
      radius: 26,
      title: title.toUpperCase(),
      child: child,
    );
  }
}

class _NovaAssistantStatePill extends StatelessWidget {
  const _NovaAssistantStatePill({
    required this.state,
    this.compact = false,
  });

  final NovaAssistantState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final baseColor = switch (state) {
      NovaAssistantState.idle => colors.primary,
      NovaAssistantState.thinking => const Color(0xFF7A8DFF),
      NovaAssistantState.responding => const Color(0xFF4FA4FF),
      NovaAssistantState.suggesting => const Color(0xFF22C55E),
      NovaAssistantState.executing => const Color(0xFFFFA726),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: context.isNovaDark ? 0.20 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: baseColor.withValues(alpha: context.isNovaDark ? 0.60 : 0.34),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            state.icon,
            size: compact ? 14 : 16,
            color: baseColor,
          ),
          const SizedBox(width: 6),
          Text(
            state.label,
            style: TextStyle(
              color: baseColor,
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NovaActionChip extends StatefulWidget {
  const _NovaActionChip({
    required this.action,
    required this.onTap,
    this.compact = false,
    this.invertColors = false,
  });

  final NovaConversationAction action;
  final VoidCallback onTap;
  final bool compact;
  final bool invertColors;

  @override
  State<_NovaActionChip> createState() => _NovaActionChipState();
}

class _NovaActionChipState extends State<_NovaActionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final primary = widget.action.primary;
    final textColor = widget.invertColors
        ? Colors.white
        : (primary ? Colors.white : colors.textPrimary);
    final background = widget.invertColors
        ? Colors.white.withValues(alpha: primary ? 0.20 : 0.12)
        : (primary
            ? colors.primary
            : Colors.white.withValues(alpha: context.isNovaDark ? 0.10 : 0.56));
    final border = widget.invertColors
        ? Colors.white.withValues(alpha: 0.24)
        : (primary ? colors.primary : colors.glassBorder);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _hovered ? 1.02 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 12 : 14,
              vertical: widget.compact ? 10 : 11,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: (widget.invertColors ? Colors.black : colors.shadow)
                      .withValues(alpha: _hovered ? 0.16 : 0.08),
                  blurRadius: _hovered ? 18 : 12,
                  offset: Offset(0, _hovered ? 10 : 6),
                ),
                if (primary)
                  BoxShadow(
                    color: colors.primary
                        .withValues(alpha: _hovered ? 0.34 : 0.22),
                    blurRadius: _hovered ? 24 : 16,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.action.icon ??
                      (primary
                          ? Icons.arrow_forward_rounded
                          : Icons.bolt_rounded),
                  size: widget.compact ? 15 : 16,
                  color: textColor,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    widget.action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: widget.compact ? 12.5 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NovaModuleCard extends StatefulWidget {
  const _NovaModuleCard({required this.module});

  final NovaModuleSnapshot module;

  @override
  State<_NovaModuleCard> createState() => _NovaModuleCardState();
}

class _NovaModuleCardState extends State<_NovaModuleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final active = widget.module.active;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active
              ? colors.primarySoft
                  .withValues(alpha: context.isNovaDark ? 0.18 : 0.26)
              : Colors.white
                  .withValues(alpha: context.isNovaDark ? 0.08 : 0.42),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? colors.primary : colors.glassBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: _hovered ? 0.18 : 0.08),
              blurRadius: _hovered ? 20 : 12,
              offset: Offset(0, _hovered ? 10 : 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? colors.primary.withValues(alpha: 0.14)
                    : colors.glass.withValues(
                        alpha: context.isNovaDark ? 0.14 : 0.48,
                      ),
              ),
              child: Icon(
                widget.module.icon,
                color: active ? colors.primary : colors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.module.title,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        widget.module.metric,
                        style: TextStyle(
                          color: active ? colors.primary : colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.module.description,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NovaPulseOrb extends StatefulWidget {
  const _NovaPulseOrb({required this.color});

  final Color color;

  @override
  State<_NovaPulseOrb> createState() => _NovaPulseOrbState();
}

class _NovaPulseOrbState extends State<_NovaPulseOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final size = 14 + (t * 4);
        return Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.16 + (t * 0.22)),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.28 + (t * 0.18)),
                  blurRadius: 18 + (t * 10),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ),
          ),
        );
      },
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
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: context.isNovaDark ? 0.08 : 0.52),
        shape: BoxShape.circle,
        border: Border.all(color: colors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(
              alpha: context.isNovaDark ? 0.28 : 0.10,
            ),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: colors.glassHighlight.withValues(
              alpha: context.isNovaDark ? 0.06 : 0.42,
            ),
            blurRadius: 18,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/Logo-Nova.png',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.18),
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
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: active
            ? colors.primarySoft
            : Colors.white.withValues(alpha: context.isNovaDark ? 0.08 : 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? colors.primary : colors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(
              alpha: context.isNovaDark ? 0.24 : 0.06,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
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

String _formatTime(DateTime value) {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
