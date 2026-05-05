import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'glass_container.dart';
import 'home/chat_shell_widgets.dart' show NovaModuleSnapshot;

class NovaModulesPanel extends StatelessWidget {
  const NovaModulesPanel({
    super.key,
    required this.modules,
    required this.onModuleTap,
    this.compact = false,
    this.spotlight = false,
  });

  final List<NovaModuleSnapshot> modules;
  final ValueChanged<NovaModuleSnapshot> onModuleTap;
  final bool compact;
  final bool spotlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;

    return GlassContainer(
      borderRadius: 30,
      blur: 20,
      opacity: context.isNovaDark ? 0.16 : 0.26,
      borderColor: spotlight
          ? colors.primary.withValues(alpha: context.isNovaDark ? 0.38 : 0.20)
          : null,
      padding: EdgeInsets.all(compact ? 16 : 20),
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
                'Fluxos prontos',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Módulos ativos',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: compact ? 16.8 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cada módulo abre um fluxo específico da NOVA sem poluir o chat.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: compact ? 12.6 : 13.2,
              height: 1.45,
            ),
          ),
          SizedBox(height: compact ? 14 : 16),
          ...modules.map(
            (module) => Padding(
              padding: EdgeInsets.only(bottom: compact ? 8 : 10),
              child: GestureDetector(
                onTap: () => onModuleTap(module),
                child: Container(
                  padding: EdgeInsets.all(compact ? 12 : 14),
                  decoration: BoxDecoration(
                    gradient: module.active && spotlight
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colors.primarySoft.withValues(alpha: 0.30),
                              Colors.white.withValues(
                                alpha: context.isNovaDark ? 0.10 : 0.24,
                              ),
                            ],
                          )
                        : null,
                    color: module.active
                        ? (spotlight
                            ? null
                            : colors.primarySoft.withValues(alpha: 0.26))
                        : Colors.white.withValues(
                            alpha: context.isNovaDark ? 0.08 : 0.44,
                          ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color:
                          module.active ? colors.primary : colors.glassBorder,
                    ),
                    boxShadow: module.active && spotlight
                        ? [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: compact ? 38 : 42,
                        height: compact ? 38 : 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primarySoft.withValues(alpha: 0.22),
                        ),
                        child: Icon(
                          module.icon,
                          size: compact ? 20 : 24,
                          color: module.active
                              ? colors.primary
                              : colors.textSecondary,
                        ),
                      ),
                      SizedBox(width: compact ? 10 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    module.title,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: compact ? 13.8 : 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  module.metric,
                                  style: TextStyle(
                                    color: module.active
                                        ? colors.primary
                                        : colors.textSecondary,
                                    fontSize: compact ? 11.4 : 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              module.description,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: compact ? 12.2 : 12.8,
                                height: 1.45,
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
          ),
        ],
      ),
    );
  }
}
