import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/character.dart';

class HpManagerCard extends StatelessWidget {
  final Character character;
  final VoidCallback onCharacterUpdated;

  const HpManagerCard({
    super.key,
    required this.character,
    required this.onCharacterUpdated,
  });

  void _showDamageDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take Damage'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Damage Amount',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final damage = int.tryParse(controller.text);
              if (damage != null && damage > 0) {
                Navigator.pop(context);
                await character.takeDamage(damage);
                onCharacterUpdated();
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showHealDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Heal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Healing Amount',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final healing = int.tryParse(controller.text);
              if (healing != null && healing > 0) {
                Navigator.pop(context);
                await character.heal(healing);
                onCharacterUpdated();
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showTempHpDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Temporary HP'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Temp HP Amount',
            border: OutlineInputBorder(),
            helperText: 'Temp HP doesn\'t stack',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final tempHp = int.tryParse(controller.text);
              if (tempHp != null && tempHp > 0) {
                Navigator.pop(context);
                character.addTemporaryHp(tempHp);
                onCharacterUpdated();
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Read current HP values directly from character
    final currentHp = character.currentHp;
    final maxHp = character.maxHp;
    final temporaryHp = character.temporaryHp;

    final hpPercentage = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

    Color getHpColor() {
      if (hpPercentage > 0.5) return Colors.green;
      if (hpPercentage > 0.25) return Colors.orange;
      return Colors.red;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hit Points',
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  '$currentHp / $maxHp',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: getHpColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // HP Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: hpPercentage,
                minHeight: 24,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(getHpColor()),
              ),
            ),

            // Temporary HP indicator
            if (temporaryHp > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield,
                      size: 16,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Temp HP: $temporaryHp',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showDamageDialog(context),
                    icon: const Icon(Icons.remove),
                    label: const Text('Damage'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showHealDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Heal'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showTempHpDialog(context),
                    icon: const Icon(Icons.shield),
                    label: const Text('Temp'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
