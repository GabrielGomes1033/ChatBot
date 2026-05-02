import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    return notes
        .map(
          (note) => InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              onSelectNote(
                _clean(note['title']).isNotEmpty
                    ? _clean(note['title'])
                    : _clean(note['slug']),
              );
            },
            child: Ink(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xAA0E1821),
                border: Border.all(color: const Color(0xFF1F3948)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _clean(note['title']).isEmpty
                              ? 'Nota sem titulo'
                              : _clean(note['title']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF4FBFF),
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
                  const SizedBox(height: 8),
                  Text(
                    _clean(note['excerpt']).isEmpty
                        ? 'Sem resumo ainda.'
                        : _clean(note['excerpt']),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB8CAD6),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                            '${_asInt(note['unlinked_mentions_count'])} sugestoes',
                        active: _asInt(note['unlinked_mentions_count']) > 0,
                      ),
                    ],
                  ),
                ],
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
    return _NovaBrainPanelCard(
      title: 'Vault',
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () {
              onCreateNote();
            },
            icon: const Icon(Icons.note_add_outlined, size: 16),
            label: const Text('Nova nota'),
            style: _brainActionStyle(),
          ),
          OutlinedButton.icon(
            onPressed: () {
              onRefresh();
            },
            icon: const Icon(Icons.sync_rounded, size: 16),
            label: const Text('Atualizar'),
            style: _brainActionStyle(),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _NovaMetricPill(label: 'Notas', value: '$noteCount'),
          _NovaMetricPill(label: 'Nos', value: '$nodes'),
          _NovaMetricPill(label: 'Conexoes', value: '$edges'),
          _NovaMetricPill(label: 'Sugestoes', value: '$suggestionCount'),
        ],
      ),
    );
  }

  ButtonStyle _brainActionStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFD6F7FF),
      side: const BorderSide(color: Color(0xFF1F607A)),
      backgroundColor: const Color(0x330B2C3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildGraphCard() {
    final nodes = _mapList(graph['nodes']);
    final edges = _mapList(graph['edges']);
    return _NovaBrainPanelCard(
      title: 'Grafo do Conhecimento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.45,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF09131A),
                    Color(0xFF101F29),
                  ],
                ),
                border: Border.all(color: const Color(0xFF1E4355)),
              ),
              child: CustomPaint(
                painter: _BrainGraphPainter(nodes: nodes, edges: edges),
                child: Center(
                  child: Text(
                    nodes.isEmpty
                        ? 'O vault ainda esta vazio.'
                        : 'Visao orbital das notas e conexoes.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0x99E8F7FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Os nos fantasmas representam links citados em notas que ainda nao viraram paginas reais, no mesmo espirito do graph view do Obsidian.',
            style: TextStyle(
              color: Colors.blueGrey.shade100,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedNoteCard() {
    final note = selectedNote;
    if (loadingNote) {
      return const _NovaBrainPanelCard(
        title: 'Nota Selecionada',
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }
    if (note == null || note.isEmpty) {
      return const _NovaBrainPanelCard(
        title: 'Nota Selecionada',
        child: Text(
          'Abra uma nota para ver conteudo completo, backlinks e sugestoes de conexao.',
          style: TextStyle(
            color: Color(0xFFB1C3CF),
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
      );
    }

    final tags = (note['tags'] is List ? List.from(note['tags']) : const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return _NovaBrainPanelCard(
      title: 'Nota Selecionada',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _clean(note['title']).isEmpty
                ? 'Sem titulo'
                : _clean(note['title']),
            style: const TextStyle(
              color: Color(0xFFF4FBFF),
              fontSize: 20,
              fontWeight: FontWeight.w700,
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xAA0E1821),
              border: Border.all(color: const Color(0xFF1F3948)),
            ),
            child: Text(
              _clean(note['content']).isEmpty
                  ? _clean(note['excerpt'])
                  : _clean(note['content']),
              style: const TextStyle(
                color: Color(0xFFE7F5FF),
                fontSize: 13.5,
                height: 1.5,
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
                label: 'Sugestoes',
                value: '${selectedSuggestions.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBacklinksCard() {
    return _NovaBrainPanelCard(
      title: 'Backlinks',
      child: backlinks.isEmpty
          ? const Text(
              'Nenhuma nota aponta para esta pagina ainda.',
              style: TextStyle(
                color: Color(0xFFB1C3CF),
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
                      backgroundColor: const Color(0xFF0E2431),
                      side: const BorderSide(color: Color(0xFF1D5166)),
                      labelStyle: const TextStyle(color: Color(0xFFDFF8FF)),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildSuggestionsCard({
    required List<Map<String, dynamic>> items,
    required String title,
    required String emptyLabel,
  }) {
    return _NovaBrainPanelCard(
      title: title,
      child: items.isEmpty
          ? Text(
              emptyLabel,
              style: const TextStyle(
                color: Color(0xFFB1C3CF),
                fontSize: 13.5,
                height: 1.45,
              ),
            )
          : Column(
              children: items
                  .take(6)
                  .map(
                    (item) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: const Color(0xAA0E1821),
                        border: Border.all(color: const Color(0xFF1F3948)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_clean(item['source'])} -> ${_clean(item['target'])}',
                            style: const TextStyle(
                              color: Color(0xFFF4FBFF),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _clean(item['excerpt']).isEmpty
                                ? 'Sugestao de vinculo sem trecho adicional.'
                                : _clean(item['excerpt']),
                            style: const TextStyle(
                              color: Color(0xFFB8CAD6),
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
            _NovaBrainPanelCard(
              title: 'Notas Recentes',
              child: notes.isEmpty
                  ? const Text(
                      'Nenhuma nota no vault ainda.',
                      style: TextStyle(
                        color: Color(0xFFB1C3CF),
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
            _buildSelectedNoteCard(),
            const SizedBox(height: 14),
            _buildBacklinksCard(),
            const SizedBox(height: 14),
            _buildSuggestionsCard(
              items: selectedSuggestions,
              title: 'Mencoes sem Link',
              emptyLabel:
                  'Nao encontrei mencoes claras nesta nota que ainda merecam um wikilink.',
            ),
            const SizedBox(height: 14),
            _buildSuggestionsCard(
              items: suggestions,
              title: 'Sugestoes Globais',
              emptyLabel: 'Nenhuma sugestao global no momento.',
            ),
            const SizedBox(height: 14),
            _buildGraphCard(),
          ],
        );

        if (!wide) {
          return ListView(
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 14),
              _NovaBrainPanelCard(
                title: 'Notas Recentes',
                child: notes.isEmpty
                    ? const Text(
                        'Nenhuma nota no vault ainda.',
                        style: TextStyle(
                          color: Color(0xFFB1C3CF),
                          fontSize: 13.5,
                        ),
                      )
                    : Column(children: _buildNoteTiles(context)),
              ),
              const SizedBox(height: 14),
              _buildSelectedNoteCard(),
              const SizedBox(height: 14),
              _buildBacklinksCard(),
              const SizedBox(height: 14),
              _buildSuggestionsCard(
                items: selectedSuggestions,
                title: 'Mencoes sem Link',
                emptyLabel:
                    'Nao encontrei mencoes claras nesta nota que ainda merecam um wikilink.',
              ),
              const SizedBox(height: 14),
              _buildSuggestionsCard(
                items: suggestions,
                title: 'Sugestoes Globais',
                emptyLabel: 'Nenhuma sugestao global no momento.',
              ),
              const SizedBox(height: 14),
              _buildGraphCard(),
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

class _NovaBrainPanelCard extends StatelessWidget {
  const _NovaBrainPanelCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xD9121C24),
            Color(0xD90D171E),
          ],
        ),
        border: Border.all(color: const Color(0xFF223947)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF83D9FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Flexible(child: trailing!),
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xAA10212B),
        border: Border.all(color: const Color(0xFF1D5166)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF4FBFF),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CB4C1),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: active ? const Color(0x3321D8FF) : const Color(0x220C1620),
        border: Border.all(
          color: active ? const Color(0xFF2BAFD6) : const Color(0xFF31444E),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFFDDF8FF) : const Color(0xFF98A9B3),
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
  });

  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> edges;

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
      ..color = const Color(0x5537C6F8)
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
        ..color = exists ? const Color(0x6621D8FF) : const Color(0x44A6B3BC)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(point, dotRadius + 2.5, glow);

      final fill = Paint()
        ..color = exists ? const Color(0xFF45D7FF) : const Color(0xFF8E9AA2);
      canvas.drawCircle(point, dotRadius, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _BrainGraphPainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.edges != edges;
  }
}
