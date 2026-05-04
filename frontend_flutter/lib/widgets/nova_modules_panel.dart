import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'glass_container.dart';
import 'home/chat_shell_widgets.dart' show NovaModuleSnapshot;

class NovaModulesPanel extends StatelessWidget {
  const NovaModulesPanel({
    super.key,
    required this.modules,
    required this.onModuleTap,
  });

  final List<NovaModuleSnapshot> modules;
  final ValueChanged<NovaModuleSnapshot> onModuleTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;

    return GlassContainer(
      borderRadius: 30,
      blur: 20,
      opacity: context.isNovaDark ? 0.16 : 0.26,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Módulos ativos',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cada módulo abre um fluxo específico da NOVA sem poluir o chat.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13.2,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          ...modules.map(
            (module) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onModuleTap(module),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: module.active
                        ? colors.primarySoft.withValues(alpha: 0.26)
                        : Colors.white.withValues(
                            alpha: context.isNovaDark ? 0.08 : 0.44,
                          ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color:
                          module.active ? colors.primary : colors.glassBorder,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primarySoft.withValues(alpha: 0.22),
                        ),
                        child: Icon(
                          module.icon,
                          color: module.active
                              ? colors.primary
                              : colors.textSecondary,
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
                                    module.title,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14.5,
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
                                    fontSize: 12,
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
                                fontSize: 12.8,
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
