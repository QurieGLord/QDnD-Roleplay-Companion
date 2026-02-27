import 'package:flutter/material.dart';
import '../../../core/models/character.dart';
import '../../../core/models/condition.dart';

class ConditionsCard extends StatelessWidget {
  final Character character;
  final VoidCallback onCharacterUpdated;

  const ConditionsCard({
    super.key,
    required this.character,
    required this.onCharacterUpdated,
  });

  void _showAddConditionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Condition'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ConditionType.values.length,
            itemBuilder: (context, index) {
              final condition = ConditionType.values[index];
              final isActive = character.activeConditions.contains(condition);

              return ListTile(
                leading: Icon(
                  isActive ? Icons.check_circle : Icons.circle_outlined,
                  color: isActive ? Colors.green : null,
                ),
                title: Text(condition.displayName),
                subtitle: Text(
                  condition.getDescription('en'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: isActive
                    ? null
                    : () {
                        character.addCondition(condition);
                        onCharacterUpdated();
                        Navigator.pop(context);
                      },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showConditionDetails(BuildContext context, ConditionType condition) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(condition.displayName),
        content: SingleChildScrollView(
          child: Text(condition.getDescription('en')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              character.removeCondition(condition);
              onCharacterUpdated();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete),
            label: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasConditions = character.activeConditions.isNotEmpty;

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
                  'Conditions',
                  style: theme.textTheme.titleLarge,
                ),
                FilledButton.icon(
                  onPressed: () => _showAddConditionDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasConditions)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No active conditions',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: character.activeConditions.map((condition) {
                  return InputChip(
                    avatar: Icon(
                      _getConditionIcon(condition),
                      size: 18,
                    ),
                    label: Text(condition.displayName),
                    onPressed: () => _showConditionDetails(context, condition),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      character.removeCondition(condition);
                      onCharacterUpdated();
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getConditionIcon(ConditionType condition) {
    switch (condition) {
      case ConditionType.blinded:
        return Icons.visibility_off;
      case ConditionType.charmed:
        return Icons.favorite;
      case ConditionType.deafened:
        return Icons.hearing_disabled;
      case ConditionType.frightened:
        return Icons.sentiment_very_dissatisfied;
      case ConditionType.grappled:
        return Icons.back_hand;
      case ConditionType.incapacitated:
        return Icons.do_not_disturb;
      case ConditionType.invisible:
        return Icons.visibility_off;
      case ConditionType.paralyzed:
        return Icons.severe_cold;
      case ConditionType.petrified:
        return Icons.cookie;
      case ConditionType.poisoned:
        return Icons.medication;
      case ConditionType.prone:
        return Icons.airline_seat_flat;
      case ConditionType.restrained:
        return Icons.link;
      case ConditionType.stunned:
        return Icons.blur_on;
      case ConditionType.unconscious:
        return Icons.bedtime;
    }
  }
}
