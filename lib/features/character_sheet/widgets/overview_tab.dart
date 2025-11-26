import 'package:flutter/material.dart';
import '../../../core/models/character.dart';
import '../../../core/models/item.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/widgets/dice_roller_modal.dart';
import '../../combat/combat_tracker_screen.dart';

class OverviewTab extends StatelessWidget {
  final Character character;
  final VoidCallback? onCharacterUpdated;

  const OverviewTab({
    super.key,
    required this.character,
    this.onCharacterUpdated,
  });

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
                        Icons.shield_outlined,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'VITAL STATS',
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
                      child: _buildStatCard(
                        context,
                        'Hit Points',
                        '${character.currentHp}/${character.maxHp}',
                        Icons.favorite,
                        colorScheme.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Armor Class',
                        '${character.armorClass}',
                        Icons.shield,
                        colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Speed',
                        '${character.speed} ft',
                        Icons.directions_run,
                        colorScheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Initiative',
                        character.formatModifier(character.initiativeBonus),
                        Icons.flash_on,
                        colorScheme.primary,
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

                _buildStatCard(
                  context,
                  'Proficiency Bonus',
                  '+${character.proficiencyBonus}',
                  Icons.star,
                  colorScheme.primary,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Attacks & Weapons Section
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
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.sports_martial_arts,
                        color: colorScheme.onTertiaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'ATTACKS & WEAPONS',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.tertiary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildAttacksList(context),
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
                        Icons.bolt,
                        color: colorScheme.onPrimaryContainer,
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
                            onCharacterUpdated?.call();
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
                            onCharacterUpdated?.call();
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
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CombatTrackerScreen(
                          character: character,
                        ),
                      ),
                    );
                    // Trigger parent rebuild after returning from combat
                    onCharacterUpdated?.call();
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
        
        const SizedBox(height: 80), // Bottom padding
      ],
    );
  }

  Widget _buildAttacksList(BuildContext context) {
    final weapons = character.inventory.where((i) => i.isEquipped && i.type == ItemType.weapon).toList();
    final colorScheme = Theme.of(context).colorScheme;

    if (weapons.isEmpty) {
      // Unarmed Strike
      final strMod = character.abilityScores.strengthModifier;
      final hitBonus = strMod + character.proficiencyBonus;
      final damage = 1 + strMod; // 1 damage + STR
      return _buildAttackCard(context, 'Unarmed Strike', hitBonus, '$damage', 'Bludgeoning', icon: Icons.back_hand);
    }

    return Column(
      children: weapons.map((weapon) {
        final strMod = character.abilityScores.strengthModifier;
        final dexMod = character.abilityScores.dexterityModifier;
        
        // Simplified Finesse logic: use best of STR/DEX
        final mod = (dexMod > strMod) ? dexMod : strMod; 
        
        final hitBonus = mod + character.proficiencyBonus;
        final damageDice = weapon.weaponProperties?.damageDice ?? '1d4';
        final damageType = weapon.weaponProperties?.damageType.name ?? 'Physical';
        
        // Format damage string: e.g., "1d8 + 3"
        final damageModStr = mod != 0 ? (mod > 0 ? ' + $mod' : ' - ${mod.abs()}') : '';
        
        return _buildAttackCard(context, weapon.getName('en'), hitBonus, '$damageDice$damageModStr', damageType);
      }).toList(),
    );
  }

  Widget _buildAttackCard(BuildContext context, String name, int hitBonus, String damage, String type, {IconData icon = Icons.sports_martial_arts}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(type, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          // Hit Button
          InkWell(
            onTap: () => showDiceRoller(context, title: 'Attack Roll ($name)', modifier: hitBonus),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('HIT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colorScheme.onPrimary.withOpacity(0.8))),
                  Text(character.formatModifier(hitBonus), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onPrimary)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Damage Button
          InkWell(
            onTap: () {
               showDiceRoller(context, title: 'Damage ($name)', modifier: 0);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.tertiary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('DMG', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colorScheme.onTertiary.withOpacity(0.8))),
                  Text(damage, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onTertiary, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color, {bool isHighlighted = false, VoidCallback? onTap}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: isHighlighted ? 2 : 1,
      color: isHighlighted ? colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: isHighlighted ? colorScheme.onPrimaryContainer : color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isHighlighted ? colorScheme.onPrimaryContainer.withOpacity(0.7) : colorScheme.onSurface.withOpacity(0.6),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isHighlighted ? colorScheme.onPrimaryContainer : color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
