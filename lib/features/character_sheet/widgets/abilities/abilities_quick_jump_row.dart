import 'package:flutter/material.dart';

import 'abilities_shell_tokens.dart';
import 'abilities_tap_feedback.dart';

class AbilitiesQuickJumpItem {
  const AbilitiesQuickJumpItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class AbilitiesQuickJumpRow extends StatelessWidget {
  const AbilitiesQuickJumpRow({
    super.key,
    required this.items,
  });

  final List<AbilitiesQuickJumpItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      key: const Key('abilities_quick_jump'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          for (final item in items) ...[
            AbilitiesTapFeedback(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(
                AbilitiesShellTokens.pillRadius,
              ),
              color: colorScheme.surfaceContainerHigh,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon,
                        size: 18, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            if (item != items.last)
              const SizedBox(width: AbilitiesShellTokens.compactSpacing),
          ],
        ],
      ),
    );
  }
}
