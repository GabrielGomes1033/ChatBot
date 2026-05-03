import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../components/nova_button.dart';
import '../../components/nova_card.dart';
import '../../theme/colors.dart';

class NovaBrainBoard extends StatelessWidget {
  const NovaBrainBoard({
    super.key,
    required this.notes,
    required this.graph,
    required this.suggestions,
    required this.selectedNote,
    required this.backlinks,
    required this.selectedSuggestions,
    required this.loadingNote,
    required this.onRefresh,
    required this.onCreateNote,
    required this.onSelectNote,
  });

  final List<Map<String, dynamic>> notes;
  final Map<String, dynamic> graph;
  final List<Map<String, dynamic>> suggestions;
  final Map<String, dynamic>? selectedNote;
  final List<String> backlinks;
  final List<Map<String, dynamic>> selectedSuggestions;
  final bool loadingNote;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCreateNote;
  final Future<void> Function(String) onSelectNote;

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _clean(dynamic value) => value?.toString().trim() ?? '';

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Widget> _buildNoteTiles(BuildContext context) {
    final colors = context.novaColors;
    return notes
        .map(
          (note) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                onSelectNote(
                  _clean(note['title']).isNotEmpty
                      ? _clean(note['title'])
                      : _clean(note['slug']),
                );
              },
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: colors.surfaceMuted,
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _clean(note['title']).isEmpty
                                ? 'Nota sem título'
                                : _clean(note['title']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _NovaBrainChip(
                          label: '${_asInt(note['backlinks_count'])} backlinks',
                          active: _asInt(note['backlinks_count']) > 0,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _clean(note['excerpt']).isEmpty
                          ? 'Sem resumo ainda.'
                          : _clean(note['excerpt']),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _NovaBrainChip(
                          label: '${_asInt(note['links_count'])} links',
                          active: _asInt(note['links_count']) > 0,
                        ),
                        _NovaBrainChip(
                          label:
                              '${_asInt(note['unlinked_mentions_count'])} sugestões',
                          active: _asInt(note['unlinked_mentions_count']) > 0,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  Widget _buildSummaryCard() {
    final nodes = _asInt(graph['total_nodes']);
    final edges = _asInt(graph['total_edges']);
    final noteCount = _asInt(graph['total_notes']) > 0
        ? _asInt(graph['total_notes'])
        : notes.length;
    final suggestionCount = suggestions.length;

    return NovaCard(
      title: 'OVERVIEW',
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          NovaButton(
            label: 'Nova nota',
            icon: Icons.note_add_outlined,
            tone: NovaButtonTone.secondary,
            onPressed: () {
              onCreateNote();
            },
          ),
          NovaButton(
            label: 'Atualizar',
            icon: Icons.sync_rounded,
            tone: NovaButtonTone.ghost,
            onPressed: () {
              onRefresh();
            },
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _NovaMetricPill(label: 'Notas', value: '$noteCount'),
          _NovaMetricPill(label: 'Nós', value: '$nodes'),
          _NovaMetricPill(label: 'Conexões', value: '$edges'),
          _NovaMetricPill(label: 'Sugestões', value: '$suggestionCount'),
        ],
      ),
    );
  }

  Widget _buildGraphCard(BuildContext context) {
    final colors = context.novaColors;
    final nodes = _mapList(graph['nodes']);
    final edges = _mapList(graph['edges']);
    return NovaCard(
      title: 'GRAFO',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.45,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: colors.surfaceMuted,
                border: Border.all(color: colors.border),
              ),
              child: CustomPaint(
                painter: _BrainGraphPainter(
                  nodes: nodes,
                  edges: edges,
                  edgeColor: colors.primarySoft.withValues(alpha: 0.85),
                  nodeColor: colors.primary,
                  ghostColor: colors.textSecondary,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      nodes.isEmpty
                          ? 'O vault ainda está vazio.'
                          : 'Visão orbital das notas e conexões.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Os nós discretos representam referências citadas que ainda podem virar páginas reais, no mesmo espírito de um graph view premium.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedNoteCard(BuildContext context) {
    final colors = context.novaColors;
    final note = selectedNote;

    if (loadingNote) {
      return const NovaCard(
        title: 'NOTA SELECIONADA',
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }

    if (note == null || note.isEmpty) {
      return NovaCard(
        title: 'NOTA SELECIONADA',
        child: Text(
          'Abra uma nota para ver o conteúdo completo, backlinks e sugestões de conexão.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
      );
    }

    final tags = (note['tags'] is List ? List.from(note['tags']) : const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return NovaCard(
      title: 'NOTA SELECIONADA',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _clean(note['title']).isEmpty
                ? 'Sem título'
                : _clean(note['title']),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .take(6)
                  .map((tag) => _NovaBrainChip(label: '#$tag', active: true))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: colors.surfaceMuted,
              border: Border.all(color: colors.border),
            ),
            child: Text(
              _clean(note['content']).isEmpty
                  ? _clean(note['excerpt'])
                  : _clean(note['content']),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13.8,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _NovaMetricPill(label: 'Backlinks', value: '${backlinks.length}'),
              _NovaMetricPill(
                label: 'Sugestões',
                value: '${selectedSuggestions.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBacklinksCard(BuildContext context) {
    final colors = context.novaColors;
    return NovaCard(
      title: 'BACKLINKS',
      child: backlinks.isEmpty
          ? Text(
              'Nenhuma nota aponta para esta página ainda.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13.5,
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: backlinks
                  .map(
                    (item) => ActionChip(
                      label: Text(item),
                      onPressed: () {
                        onSelectNote(item);
                      },
                      backgroundColor: colors.surfaceMuted,
                      side: BorderSide(color: colors.border),
                      labelStyle: TextStyle(color: colors.textPrimary),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildSuggestionsCard(
    BuildContext context, {
    required List<Map<String, dynamic>> items,
    required String title,
    required String emptyLabel,
  }) {
    final colors = context.novaColors;
    return NovaCard(
      title: title.toUpperCase(),
      child: items.isEmpty
          ? Text(
              emptyLabel,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            )
          : Column(
              children: items
                  .take(6)
                  .map(
                    (item) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: colors.surfaceMuted,
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_clean(item['source'])} -> ${_clean(item['target'])}',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _clean(item['excerpt']).isEmpty
                                ? 'Sugestão de vínculo sem trecho adicional.'
                                : _clean(item['excerpt']),
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12.8,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final leftColumn = ListView(
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 14),
            NovaCard(
              title: 'NOTAS RECENTES',
              child: notes.isEmpty
                  ? Text(
                      'Nenhuma nota no vault ainda.',
                      style: TextStyle(
                        color: context.novaColors.textSecondary,
                        fontSize: 13.5,
                      ),
                    )
                  : Column(
                      children: _buildNoteTiles(context),
                    ),
            ),
          ],
        );

        final rightColumn = ListView(
          children: [
            _buildSelectedNoteCard(context),
            const SizedBox(height: 14),
            _buildBacklinksCard(context),
            const SizedBox(height: 14),
            _buildSuggestionsCard(
              context,
              items: selectedSuggestions,
              title: 'Menções sem Link',
              emptyLabel:
                  'Não encontrei menções claras nesta nota que ainda mereçam um wikilink.',
            ),
            const SizedBox(height: 14),
            _buildSuggestionsCard(
              context,
              items: suggestions,
              title: 'Sugestões Globais',
              emptyLabel: 'Nenhuma sugestão global no momento.',
            ),
            const SizedBox(height: 14),
            _buildGraphCard(context),
          ],
        );

        if (!wide) {
          return ListView(
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 14),
              NovaCard(
                title: 'NOTAS RECENTES',
                child: notes.isEmpty
                    ? Text(
                        'Nenhuma nota no vault ainda.',
                        style: TextStyle(
                          color: context.novaColors.textSecondary,
                          fontSize: 13.5,
                        ),
                      )
                    : Column(children: _buildNoteTiles(context)),
              ),
              const SizedBox(height: 14),
              _buildSelectedNoteCard(context),
              const SizedBox(height: 14),
              _buildBacklinksCard(context),
              const SizedBox(height: 14),
              _buildSuggestionsCard(
                context,
                items: selectedSuggestions,
                title: 'Menções sem Link',
                emptyLabel:
                    'Não encontrei menções claras nesta nota que ainda mereçam um wikilink.',
              ),
              const SizedBox(height: 14),
              _buildSuggestionsCard(
                context,
                items: suggestions,
                title: 'Sugestões Globais',
                emptyLabel: 'Nenhuma sugestão global no momento.',
              ),
              const SizedBox(height: 14),
              _buildGraphCard(context),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: constraints.maxWidth * 0.36,
              child: leftColumn,
            ),
            const SizedBox(width: 16),
            Expanded(child: rightColumn),
          ],
        );
      },
    );
  }
}

class _NovaMetricPill extends StatelessWidget {
  const _NovaMetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colors.surfaceMuted,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NovaBrainChip extends StatelessWidget {
  const _NovaBrainChip({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: active ? colors.primarySoft : colors.surfaceStrong,
        border: Border.all(
          color: active ? colors.primary : colors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? colors.primary : colors.textSecondary,
          fontSize: 11.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BrainGraphPainter extends CustomPainter {
  const _BrainGraphPainter({
    required this.nodes,
    required this.edges,
    required this.edgeColor,
    required this.nodeColor,
    required this.ghostColor,
  });

  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> edges;
  final Color edgeColor;
  final Color nodeColor;
  final Color ghostColor;

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final visibleNodes = nodes.take(18).toList();
    if (visibleNodes.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;
    final positions = <String, Offset>{};
    for (var i = 0; i < visibleNodes.length; i++) {
      final node = visibleNodes[i];
      final angle = (math.pi * 2 * i) / visibleNodes.length;
      final pulse = 0.78 + (i % 3) * 0.09;
      final point = Offset(
        center.dx + math.cos(angle) * radius * pulse,
        center.dy + math.sin(angle) * radius * pulse,
      );
      positions[node['slug']?.toString() ?? 'node-$i'] = point;
    }

    final edgePaint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;

    for (final edge in edges.take(30)) {
      final source = positions[edge['source']?.toString() ?? ''];
      final target = positions[edge['target']?.toString() ?? ''];
      if (source == null || target == null) continue;
      canvas.drawLine(source, target, edgePaint);
    }

    for (var i = 0; i < visibleNodes.length; i++) {
      final node = visibleNodes[i];
      final slug = node['slug']?.toString() ?? 'node-$i';
      final point = positions[slug];
      if (point == null) continue;
      final exists = node['exists'] != false;
      final backlinks = _asInt(node['backlinks_count']);
      final dotRadius =
          exists ? 7.0 + math.min(backlinks.toDouble(), 4.0) : 5.5;

      final glow = Paint()
        ..color = exists
            ? nodeColor.withValues(alpha: 0.35)
            : ghostColor.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(point, dotRadius + 2.5, glow);

      final fill = Paint()..color = exists ? nodeColor : ghostColor;
      canvas.drawCircle(point, dotRadius, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _BrainGraphPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges ||
        oldDelegate.edgeColor != edgeColor ||
        oldDelegate.nodeColor != nodeColor ||
        oldDelegate.ghostColor != ghostColor;
  }
}
