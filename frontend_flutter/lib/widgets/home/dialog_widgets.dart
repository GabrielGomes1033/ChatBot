import 'package:flutter/material.dart';

import '../../components/nova_input.dart';
import '../../components/nova_modal.dart';
import '../../theme/colors.dart';
import '../glass_container.dart';

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

class NovaDialogContent extends StatelessWidget {
  const NovaDialogContent({
    super.key,
    required this.maxWidth,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final double maxWidth;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final gutter = viewportWidth < 360 ? 28.0 : 40.0;
    final availableWidth =
        viewportWidth > gutter ? viewportWidth - gutter : viewportWidth;
    final resolvedMaxWidth =
        availableWidth < maxWidth ? availableWidth : maxWidth;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
        child: child,
      ),
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

class NovaPanelSection extends StatelessWidget {
  const NovaPanelSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 22,
      blur: 16,
      opacity: context.isNovaDark ? 0.12 : 0.22,
      padding: padding,
      child: child,
    );
  }
}

class NovaFloatingMenuShell extends StatelessWidget {
  const NovaFloatingMenuShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final size = MediaQuery.sizeOf(context);
    final width = size.width < 460
        ? size.width * 0.94
        : (size.width < 760
            ? size.width * 0.90
            : (size.width < 1180 ? size.width * 0.84 : 980.0));
    final maxHeight = size.height * 0.84;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              maxHeight: maxHeight,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -32,
                  left: width * 0.14,
                  child: _NovaFloatingOrb(
                    size: size.width < 560 ? 110 : 150,
                    color: colors.primarySoft.withValues(
                      alpha: context.isNovaDark ? 0.34 : 0.72,
                    ),
                  ),
                ),
                Positioned(
                  right: -28,
                  bottom: 34,
                  child: _NovaFloatingOrb(
                    size: size.width < 560 ? 120 : 180,
                    color: colors.glassHighlight.withValues(
                      alpha: context.isNovaDark ? 0.10 : 0.34,
                    ),
                  ),
                ),
                GlassContainer(
                  borderRadius: 30,
                  blur: 24,
                  opacity: context.isNovaDark ? 0.18 : 0.34,
                  padding: EdgeInsets.fromLTRB(
                    size.width < 560 ? 18 : 24,
                    size.width < 560 ? 18 : 24,
                    size.width < 560 ? 18 : 24,
                    size.width < 560 ? 20 : 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: size.width < 560 ? 24 : 30,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: size.width < 560 ? 13.5 : 14.5,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(
                                alpha: context.isNovaDark ? 0.08 : 0.46,
                              ),
                              border: Border.all(color: colors.glassBorder),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.close_rounded,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Divider(
                        height: 1,
                        color: colors.glassBorder.withValues(
                          alpha: context.isNovaDark ? 0.30 : 0.78,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Flexible(
                        child: SingleChildScrollView(
                          child: child,
                        ),
                      ),
                    ],
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

class NovaFloatingMenuActionCard extends StatelessWidget {
  const NovaFloatingMenuActionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.description,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return GlassContainer(
      borderRadius: 24,
      blur: 16,
      opacity: context.isNovaDark ? 0.14 : 0.24,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary.withValues(alpha: 0.82),
                        Color.lerp(colors.primary, Colors.white, 0.28)!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.20),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (description != null && description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NovaFloatingOrb extends StatelessWidget {
  const _NovaFloatingOrb({
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
              color.withValues(alpha: color.a * 0.25),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
