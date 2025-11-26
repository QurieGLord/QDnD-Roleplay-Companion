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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // COMBAT DASHBOARD
        Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.security, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text('COMBAT DASHBOARD', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. HP Bar
                _buildHpBar(context),
                const SizedBox(height: 20),

                // 2. Vital Stats Grid
                Row(
                  children: [
                    Expanded(child: _buildStatCard(context, 'AC', '${character.armorClass}', Icons.shield_outlined, colorScheme.secondary)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(context, 'INIT', character.formatModifier(character.initiativeBonus), Icons.flash_on, colorScheme.tertiary, onTap: () => showDiceRoller(context, title: 'Initiative', modifier: character.initiativeBonus))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(context, 'SPEED', '${character.speed}', Icons.directions_run, colorScheme.surfaceTint)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(context, 'PROF', '+${character.proficiencyBonus}', Icons.school, colorScheme.outline)),
                  ],
                ),

                const SizedBox(height: 24),
                
                // 3. Attacks
                Text('WEAPONS & ATTACKS', style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                _buildAttacksList(context),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // REST & ACTIONS
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _showRestDialog(context, short: true),
                icon: const Icon(Icons.coffee, size: 18),
                label: const Text('Short Rest'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _showRestDialog(context, short: false),
                icon: const Icon(Icons.hotel, size: 18),
                label: const Text('Long Rest'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        FilledButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CombatTrackerScreen(character: character),
              ),
            );
            onCharacterUpdated?.call();
          },
          icon: const Icon(Icons.sports_martial_arts),
          label: const Text('Enter Combat Mode'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildHpBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hpPercent = (character.currentHp / character.maxHp).clamp(0.0, 1.0);
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Hit Points', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
            RichText(
              text: TextSpan(
                style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
                children: [
                  TextSpan(text: '${character.currentHp}', style: TextStyle(fontSize: 24, color: hpPercent < 0.3 ? colorScheme.error : colorScheme.primary)),
                  TextSpan(text: '/${character.maxHp}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16)),
                  if (character.temporaryHp > 0)
                    TextSpan(text: ' +${character.temporaryHp}', style: TextStyle(color: colorScheme.tertiary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: hpPercent,
            minHeight: 12,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: hpPercent < 0.3 ? colorScheme.error : (hpPercent > 0.5 ? colorScheme.primary : Colors.amber),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colorScheme.onSurface)),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttacksList(BuildContext context) {
    final weapons = character.inventory.where((i) => i.isEquipped && i.type == ItemType.weapon).toList();
    final colorScheme = Theme.of(context).colorScheme;

    if (weapons.isEmpty) {
      final strMod = character.abilityScores.strengthModifier;
      final hitBonus = strMod + character.proficiencyBonus;
      final damage = 1 + strMod;
      return _buildAttackRow(context, 'Unarmed Strike', hitBonus, '$damage', 'Bludgeoning', icon: Icons.back_hand);
    }

    return Column(
      children: weapons.map((weapon) {
        final strMod = character.abilityScores.strengthModifier;
        final dexMod = character.abilityScores.dexterityModifier;
        final mod = (dexMod > strMod) ? dexMod : strMod;
        final hitBonus = mod + character.proficiencyBonus;
        final damageDice = weapon.weaponProperties?.damageDice ?? '1d4';
        final damageType = weapon.weaponProperties?.damageType.name ?? 'Physical';
        final damageModStr = mod != 0 ? (mod > 0 ? ' + $mod' : ' - ${mod.abs()}') : '';
        
        return _buildAttackRow(context, weapon.getName('en'), hitBonus, '$damageDice$damageModStr', damageType);
      }).toList(),
    );
  }

  Widget _buildAttackRow(BuildContext context, String name, int hitBonus, String damage, String type, {IconData icon = Icons.sports_martial_arts}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(type, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          // Hit
          InkWell(
            onTap: () => showDiceRoller(context, title: 'Attack ($name)', modifier: hitBonus),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Text('HIT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer.withOpacity(0.7))),
                  Text(character.formatModifier(hitBonus), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Dmg
          InkWell(
            onTap: () => showDiceRoller(context, title: 'Damage ($name)', modifier: 0),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Text('DMG', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colorScheme.onSecondaryContainer.withOpacity(0.7))),
                  Text(damage, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSecondaryContainer, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRestDialog(BuildContext context, {required bool short}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(short ? Icons.coffee : Icons.hotel), const SizedBox(width: 12), Text(short ? 'Short Rest' : 'Long Rest')]),
        content: Text(short ? 'Recover short-rest features and spend Hit Dice?' : 'Recover all HP, spell slots, and features?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Rest')),
        ],
      ),
    );

    if (confirmed == true) {
      if (short) character.shortRest(); else character.longRest();
      await StorageService.saveCharacter(character);
      onCharacterUpdated?.call();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rested successfully'), duration: Duration(seconds: 2)));
    }
  }
}