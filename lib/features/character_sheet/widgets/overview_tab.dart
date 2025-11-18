import 'package:flutter/material.dart';
import '../../../core/models/character.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/widgets/dice_roller_modal.dart';

class OverviewTab extends StatelessWidget {
  final Character character;

  const OverviewTab({super.key, required this.character});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Combat Stats Section
        Card(
          elevation: 4,
          shadowColor: colorScheme.primary.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.sports_martial_arts,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'COMBAT STATS',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // HP, AC, Speed Grid
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.favorite,
                        label: 'Hit Points',
                        value: '${character.currentHp}/${character.maxHp}',
                        color: colorScheme.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.shield,
                        label: 'Armor Class',
                        value: '${character.armorClass}',
                        color: colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.directions_run,
                        label: 'Speed',
                        value: '${character.speed} ft',
                        color: colorScheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.flash_on,
                        label: 'Initiative',
                        value: character.formatModifier(character.initiativeBonus),
                        color: colorScheme.primary,
                        onTap: () => showDiceRoller(
                          context,
                          title: 'Initiative',
                          modifier: character.initiativeBonus,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _StatCard(
                  icon: Icons.star,
                  label: 'Proficiency Bonus',
                  value: '+${character.proficiencyBonus}',
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Rest & Combat Actions
        Card(
          elevation: 4,
          shadowColor: colorScheme.primary.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.flash_on,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'ACTIONS',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Rest Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.coffee, size: 28),
                                  SizedBox(width: 12),
                                  Text('Short Rest'),
                                ],
                              ),
                              content: const Text(
                                'Take a short rest?\n\n'
                                'Will restore:\n'
                                '• Features that recharge on short rest\n'
                                '• Channel Divinity',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Rest'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true && context.mounted) {
                            character.shortRest();
                            await StorageService.saveCharacter(character);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✨ Rested! Resources restored.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.coffee),
                        label: const Text('Short Rest'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.hotel, size: 28),
                                  SizedBox(width: 12),
                                  Text('Long Rest'),
                                ],
                              ),
                              content: const Text(
                                'Take a long rest?\n\n'
                                'Will restore:\n'
                                '• All HP (including temp HP cleared)\n'
                                '• All spell slots\n'
                                '• All features\n'
                                '• Lay on Hands, Divine Sense, Channel Divinity',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Rest'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true && context.mounted) {
                            character.longRest();
                            await StorageService.saveCharacter(character);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🌙 Fully rested! All resources restored.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.hotel),
                        label: const Text('Long Rest'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Enter Combat Button
                FilledButton.tonalIcon(
                  onPressed: () {
                    // TODO: Combat modal
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Combat tracker - coming in Session 7')),
                    );
                  },
                  icon: const Icon(Icons.sports_martial_arts),
                  label: const Text('Enter Combat'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
