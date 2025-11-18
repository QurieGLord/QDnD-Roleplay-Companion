import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../character_creation_state.dart';

class EquipmentStep extends StatelessWidget {
  const EquipmentStep({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Starting Equipment',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your class determines your starting equipment. This feature will be implemented in the full inventory system.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        // Equipment Package Selection
        if (state.selectedClass != null) ...[
          Text(
            'Choose Equipment Package',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: RadioGroup<String>(
              groupValue: state.selectedEquipmentPackage ?? 'standard',
              onChanged: (value) {
                context.read<CharacterCreationState>().updateEquipmentPackage(value);
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: 'standard',
                    title: Text('Standard Package'),
                    subtitle: Text('Recommended starting equipment for your class'),
                    secondary: Icon(Icons.check_circle_outline),
                  ),
                  Divider(height: 1),
                  RadioListTile<String>(
                    value: 'alternative',
                    title: Text('Alternative Package'),
                    subtitle: Text('Different equipment options'),
                    secondary: Icon(Icons.swap_horiz),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Class-based Equipment Preview
        if (state.selectedClass != null) ...[
          Text(
            'Default ${state.selectedClass!.name['en']} Equipment',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _buildEquipmentCategory(
            context,
            'Weapons',
            Icons.diamond,
            _getDefaultWeapons(state.selectedClass!.id),
          ),

          _buildEquipmentCategory(
            context,
            'Armor',
            Icons.shield,
            _getDefaultArmor(state.selectedClass!.id),
          ),

          _buildEquipmentCategory(
            context,
            'Tools & Gear',
            Icons.handyman,
            _getDefaultTools(state.selectedClass!.id),
          ),

          const SizedBox(height: 16),

          // Info Card
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This is a preview of typical starting equipment. The actual inventory system will allow you to choose between equipment packages or starting gold.',
                      style: TextStyle(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEquipmentCategory(
    BuildContext context,
    String title,
    IconData icon,
    List<String> items,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 6,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  List<String> _getDefaultWeapons(String classId) {
    switch (classId) {
      case 'fighter':
        return ['Longsword', 'Shield', '2 Handaxes'];
      case 'wizard':
        return ['Quarterstaff', 'Dagger'];
      case 'rogue':
        return ['Rapier', 'Shortbow with 20 arrows', '2 Daggers'];
      case 'cleric':
        return ['Mace', 'Shield'];
      case 'ranger':
        return ['Longbow with 20 arrows', '2 Shortswords'];
      default:
        return ['Simple weapon', 'Backup weapon'];
    }
  }

  List<String> _getDefaultArmor(String classId) {
    switch (classId) {
      case 'fighter':
        return ['Chain mail', 'Shield'];
      case 'wizard':
        return ['No armor'];
      case 'rogue':
        return ['Leather armor'];
      case 'cleric':
        return ['Scale mail', 'Shield'];
      case 'ranger':
        return ['Leather armor'];
      default:
        return ['Light armor or no armor'];
    }
  }

  List<String> _getDefaultTools(String classId) {
    switch (classId) {
      case 'fighter':
        return ['Explorer\'s Pack', 'Bedroll', 'Rations (10 days)'];
      case 'wizard':
        return ['Spellbook', 'Component pouch', 'Scholar\'s Pack'];
      case 'rogue':
        return ['Thieves\' tools', 'Burglar\'s Pack', 'Crowbar'];
      case 'cleric':
        return ['Holy symbol', 'Priest\'s Pack', 'Prayer book'];
      case 'ranger':
        return ['Explorer\'s Pack', 'Rope (50 feet)', 'Hunting trap'];
      default:
        return ['Adventurer\'s Pack', 'Rope', 'Torch (10)'];
    }
  }
}
