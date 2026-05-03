import 'package:flutter/material.dart';

import '../../components/nova_input.dart';
import '../../components/nova_modal.dart';
import '../../theme/colors.dart';

class NovaCapabilityBadge extends StatelessWidget {
  const NovaCapabilityBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase().trim();
    late Color bg;
    late Color fg;
    late String label;

    if (s == 'completo') {
      bg = const Color(0x1A30D158);
      fg = const Color(0xFF1E9B46);
      label = 'Completo';
    } else if (s == 'indisponivel') {
      bg = const Color(0x1AE5484D);
      fg = const Color(0xFFBE2F35);
      label = 'Indisponível';
    } else {
      bg = const Color(0x1AF2A100);
      fg = const Color(0xFFAD6A00);
      label = 'Parcial';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class NovaAuditLevelBadge extends StatelessWidget {
  const NovaAuditLevelBadge({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final l = level.toLowerCase();
    Color bg;
    Color fg;
    String label;

    if (l == 'bom') {
      bg = const Color(0x1A30D158);
      fg = const Color(0xFF1E9B46);
      label = 'BOM';
    } else if (l == 'critico') {
      bg = const Color(0x1AE5484D);
      fg = const Color(0xFFBE2F35);
      label = 'CRÍTICO';
    } else {
      bg = const Color(0x1AF2A100);
      fg = const Color(0xFFAD6A00);
      label = 'ATENÇÃO';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class NovaAuditTimelineRow extends StatelessWidget {
  const NovaAuditTimelineRow({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final score = (item['score'] is num)
        ? (item['score'] as num).toInt()
        : int.tryParse(item['score']?.toString() ?? '0') ?? 0;
    final safeScore = score.clamp(0, 100);
    final when = item['audit_time']?.toString() ?? '-';
    final nivel = item['nivel']?.toString() ?? 'atencao';
    final achados = (item['achados_total'] is num)
        ? (item['achados_total'] as num).toInt()
        : int.tryParse(item['achados_total']?.toString() ?? '0') ?? 0;

    Color barColor;
    if (safeScore >= 85) {
      barColor = const Color(0xFF27E8A0);
    } else if (safeScore >= 65) {
      barColor = const Color(0xFFFFD36C);
    } else {
      barColor = const Color(0xFFFF6B6B);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  when,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                '$safeScore/100',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: safeScore / 100.0,
              minHeight: 8,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'nível: $nivel • achados: $achados',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class NovaPanelDialog extends StatelessWidget {
  const NovaPanelDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return NovaModalFrame(
      title: title,
      actions: actions,
      child: child,
    );
  }
}

class NovaFieldLabel extends StatelessWidget {
  const NovaFieldLabel(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return Text(
      value,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}

class NovaInput extends StatelessWidget {
  const NovaInput({
    super.key,
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return NovaInputField(
      controller: controller,
      hintText: hintText,
      maxLines: maxLines,
      obscureText: obscureText,
    );
  }
}
