import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
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

  String _getDamageTypeLabel(AppLocalizations l10n, String type) {
    switch (type.toLowerCase()) {
      case 'slashing':
        return l10n.damageTypeSlashing;
      case 'piercing':
        return l10n.damageTypePiercing;
      case 'bludgeoning':
        return l10n.damageTypeBludgeoning;
      case 'acid':
        return l10n.damageTypeAcid;
      case 'cold':
        return l10n.damageTypeCold;
      case 'fire':
        return l10n.damageTypeFire;
      case 'force':
        return l10n.damageTypeForce;
      case 'lightning':
        return l10n.damageTypeLightning;
      case 'necrotic':
        return l10n.damageTypeNecrotic;
      case 'poison':
        return l10n.damageTypePoison;
      case 'psychic':
        return l10n.damageTypePsychic;
      case 'radiant':
        return l10n.damageTypeRadiant;
      case 'thunder':
        return l10n.damageTypeThunder;
      default:
        return l10n.damageTypePhysical;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // COMBAT DASHBOARD
        Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                    Text(l10n.combatStats.toUpperCase(),
                        style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. HP Bar
                _buildHpBar(context, l10n),
                const SizedBox(height: 20),

                // 2. Vital Stats Grid
                Row(
                  children: [
                    Expanded(
                        child: _buildStatCard(
                            context,
                            l10n.armorClassAC,
                            '${character.armorClass}',
                            Icons.shield_outlined,
                            colorScheme.secondary)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildStatCard(
                            context,
                            l10n.initiativeINIT,
                            character.formatModifier(character.initiativeBonus),
                            Icons.flash_on,
                            colorScheme.tertiary,
                            onTap: () => showDiceRoller(context,
                                title: l10n.rollInitiative,
                                modifier: character.initiativeBonus))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildStatCard(
                            context,
                            l10n.speedSPEED,
                            '${character.speed}',
                            Icons.directions_run,
                            colorScheme.surfaceTint)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildStatCard(
                            context,
                            l10n.proficiencyPROF,
                            '+${character.proficiencyBonus}',
                            Icons.school,
                            colorScheme.outline)),
                  ],
                ),

                const SizedBox(height: 24),

                // 3. Attacks
                Text(l10n.weaponsAttacks,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                _buildAttacksList(context, l10n),
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
                label: Text(l10n.shortRest),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _showRestDialog(context, short: false),
                icon: const Icon(Icons.hotel, size: 18),
                label: Text(l10n.longRest),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
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
          label: Text(l10n.startCombat),
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

  Widget _buildHpBar(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final hpPercent = (character.currentHp / character.maxHp).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.hitPoints,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant)),
            RichText(
              text: TextSpan(
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
                children: [
                  TextSpan(
                      text: '${character.currentHp}',
                      style: TextStyle(
                          fontSize: 24,
                          color: hpPercent < 0.3
                              ? colorScheme.error
                              : colorScheme.primary)),
                  TextSpan(
                      text: '/${character.maxHp}',
                      style: TextStyle(
                          color: colorScheme.onSurfaceVariant, fontSize: 16)),
                  if (character.temporaryHp > 0)
                    TextSpan(
                        text: ' +${character.temporaryHp}',
                        style: TextStyle(color: colorScheme.tertiary)),
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
            color: hpPercent < 0.3
                ? colorScheme.error
                : (hpPercent > 0.5 ? colorScheme.primary : Colors.amber),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value,
      IconData icon, Color color,
      {VoidCallback? onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: colorScheme.onSurface)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttacksList(BuildContext context, AppLocalizations l10n) {
    final weapons = character.inventory
        .where((i) => i.isEquipped && i.type == ItemType.weapon)
        .toList();
    final locale = Localizations.localeOf(context).languageCode;

    if (weapons.isEmpty) {
      final strMod = character.abilityScores.strengthModifier;
      final hitBonus = strMod + character.proficiencyBonus;
      final damage = 1 + strMod;
      return _buildAttackCard(context, l10n.unarmedStrike, hitBonus, '$damage',
          l10n.damageTypeBludgeoning,
          icon: Icons.back_hand);
    }

    return Column(
      children: weapons.map((weapon) {
        final strMod = character.abilityScores.strengthModifier;
        final dexMod = character.abilityScores.dexterityModifier;
        final bool isRanged = weapon.weaponProperties?.range != null;
        final bool isFinesse =
            weapon.weaponProperties?.weaponTags.contains('finesse') ?? false;
        final mod =
            (isRanged || (isFinesse && dexMod > strMod)) ? dexMod : strMod;

        final hitBonus = mod + character.proficiencyBonus;
        final damageDice = weapon.weaponProperties?.damageDice ?? '1d4';

        final rawDamageType =
            weapon.weaponProperties?.damageType.name ?? 'physical';
        final damageType = _getDamageTypeLabel(l10n, rawDamageType);

        final damageModStr =
            mod != 0 ? (mod > 0 ? ' + $mod' : ' - ${mod.abs()}') : '';

        return _buildAttackCard(context, weapon.getName(locale), hitBonus,
            '$damageDice$damageModStr', damageType);
      }).toList(),
    );
  }

  Widget _buildAttackCard(BuildContext context, String name, int hitBonus,
      String damage, String type,
      {IconData icon = Icons.sports_martial_arts}) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name and Type
            Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: colorScheme.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    type.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                // Attack Roll Button
                Expanded(
                  child: Material(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => showDiceRoller(context,
                          title: '${l10n.spellAttack} ($name)',
                          modifier: hitBonus),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Text(
                              l10n.hit.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                  color: colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.6)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              character.formatModifier(hitBonus),
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: colorScheme.onPrimaryContainer),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Damage Roll Button
                Expanded(
                  child: Material(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => showDiceRoller(context,
                          title: '${l10n.damage} ($name)',
                          modifier:
                              0), // Modifier 0 because dice formula handles it
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Text(
                              l10n.dmg.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                  color: colorScheme.onSecondaryContainer
                                      .withValues(alpha: 0.6)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              damage,
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: colorScheme.onSecondaryContainer),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRestDialog(BuildContext context,
      {required bool short}) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          Icon(short ? Icons.coffee : Icons.hotel),
          const SizedBox(width: 12),
          Text(short ? l10n.shortRest : l10n.longRest)
        ]),
        content:
            Text(short ? l10n.shortRestDescription : l10n.longRestDescription),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.rest)),
        ],
      ),
    );

    if (confirmed == true) {
      if (short) {
        character.shortRest();
      } else {
        character.longRest();
      }
      await StorageService.saveCharacter(character);
      onCharacterUpdated?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.restedSuccess),
            duration: const Duration(seconds: 2)));
      }
    }
  }
}
