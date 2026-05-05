import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'glass_container.dart';

class NovaMetalLogo extends StatelessWidget {
  const NovaMetalLogo({
    super.key,
    this.size = 88,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.brandSurface.withValues(alpha: 0.92),
        border: Border.all(
          color: const Color(0xE6E6EDF4),
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59FFFFFF),
            blurRadius: 18,
          ),
          BoxShadow(
            color: Color(0x40007AFF),
            blurRadius: 28,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/Logo-Nova.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.18),
          ),
        ),
      ),
    );
  }
}

class NovaSidebarBio extends StatelessWidget {
  const NovaSidebarBio({
    super.key,
    required this.statusLabel,
    required this.contextText,
    this.onOpenMemory,
    this.compact = false,
    this.spotlight = false,
  });

  final String statusLabel;
  final String contextText;
  final VoidCallback? onOpenMemory;
  final bool compact;
  final bool spotlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;

    return GlassContainer(
      borderRadius: 30,
      blur: 22,
      opacity: context.isNovaDark ? 0.16 : 0.28,
      borderColor: spotlight
          ? colors.primary.withValues(alpha: context.isNovaDark ? 0.40 : 0.22)
          : null,
      padding: EdgeInsets.all(compact ? 18 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (spotlight) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primarySoft.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Núcleo NOVA',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: compact ? 12 : 14),
          ],
          NovaMetalLogo(
            size: compact ? 76 : (spotlight ? 98 : 92),
          ),
          SizedBox(height: compact ? 14 : 18),
          Text(
            'NOVA',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: compact ? 24 : 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            'Assistente inteligente para organizar ideias, gerar códigos, analisar documentos e transformar seus projetos em produtos reais.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: compact ? 13.0 : 13.8,
              height: 1.55,
            ),
          ),
          SizedBox(height: compact ? 14 : 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SidebarPill(
                label: statusLabel,
                active: true,
                compact: compact,
              ),
              _SidebarPill(
                label: 'Memória pronta',
                active: false,
                compact: compact,
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 14),
          if (spotlight)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 14,
                vertical: compact ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: context.isNovaDark ? 0.06 : 0.36,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.glassBorder),
              ),
              child: Text(
                contextText,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: compact ? 12.2 : 12.8,
                  height: 1.45,
                ),
              ),
            )
          else
            Text(
              contextText,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: compact ? 12.2 : 12.8,
                height: 1.45,
              ),
            ),
          if (onOpenMemory != null) ...[
            SizedBox(height: compact ? 14 : 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenMemory,
                icon: const Icon(Icons.auto_awesome_motion_rounded),
                label: Text(
                  compact ? 'Abrir memória' : 'Abrir memória e notas',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarPill extends StatelessWidget {
  const _SidebarPill({
    required this.label,
    required this.active,
    this.compact = false,
  });

  final String label;
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: active
            ? colors.primarySoft.withValues(alpha: 0.34)
            : Colors.white.withValues(alpha: context.isNovaDark ? 0.08 : 0.44),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? colors.primary : colors.glassBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? colors.primary : colors.textSecondary,
          fontSize: compact ? 11.6 : 12.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
