import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

class InventoryStatusBar extends StatelessWidget {
  final double currentWeight;
  final double maxWeight;
  final int attunedCount;
  final int maxAttuned;

  const InventoryStatusBar({
    super.key,
    required this.currentWeight,
    required this.maxWeight,
    required this.attunedCount,
    this.maxAttuned = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final weightPercent = (currentWeight / maxWeight).clamp(0.0, 1.0);
    Color weightColor = Colors.green;
    if (weightPercent > 1.0) {
      weightColor = colorScheme.error;
    } else if (weightPercent > 0.8) {
      weightColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // Weight Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.encumbrance.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.secondary,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '${currentWeight.toStringAsFixed(1)} / ${maxWeight.toStringAsFixed(0)} ${l10n.weightUnit}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: weightPercent > 1.0
                      ? colorScheme.error
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: weightPercent,
            color: weightColor,
            backgroundColor: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),

          const SizedBox(height: 16),

          // Attunement Row
          Row(
            children: [
              Text(
                l10n.attunement.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.secondary,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Row(
                children: List.generate(maxAttuned, (index) {
                  final isFilled = index < attunedCount;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      isFilled
                          ? Icons.auto_awesome
                          : Icons.auto_awesome_outlined,
                      size: 16,
                      color: isFilled
                          ? colorScheme.primary
                          : colorScheme.outline.withOpacity(0.5),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
