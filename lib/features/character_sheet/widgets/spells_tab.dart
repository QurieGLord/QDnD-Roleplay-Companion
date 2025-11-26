import 'package:flutter/material.dart';
import '../../../core/models/character.dart';
import '../../../core/models/spell.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/services/spellcasting_service.dart';
import '../../../core/services/storage_service.dart';
import '../../spell_almanac/spell_almanac_screen.dart';

class SpellsTab extends StatefulWidget {
  final Character character;

  const SpellsTab({super.key, required this.character});

  @override
  State<SpellsTab> createState() => _SpellsTabState();
}

class _SpellsTabState extends State<SpellsTab> {
  Color _getSchoolColor(String school) {
    switch (school) {
      case 'Abjuration': return Colors.blue;
      case 'Conjuration': return Colors.purple;
      case 'Divination': return Colors.cyan;
      case 'Enchantment': return Colors.pink;
      case 'Evocation': return Colors.red;
      case 'Illusion': return Colors.indigo;
      case 'Necromancy': return Colors.grey;
      case 'Transmutation': return Colors.green;
      default: return Theme.of(context).colorScheme.primary;
    }
  }

  void _showCastSpellDialog(Spell spell) {
    final colorScheme = Theme.of(context).colorScheme;

    // Cantrips don't use spell slots
    if (spell.level == 0) {
      _castSpell(spell, 0);
      return;
    }

    // Get available spell slot levels (starting from spell's minimum level)
    final availableSlots = <int>[];
    for (int i = spell.level; i <= widget.character.maxSpellSlots.length; i++) {
      // Check bounds for spellSlots array to prevent crash
      if (i <= widget.character.spellSlots.length && widget.character.spellSlots[i - 1] > 0) {
        availableSlots.add(i);
      }
    }

    if (availableSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No spell slots available!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cast ${spell.nameEn}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose spell slot level:', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 16),
            ...availableSlots.map((level) {
              final slotsRemaining = widget.character.spellSlots[level - 1];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text('$level', style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                ),
                title: Text('Level $level Slot'),
                subtitle: Text('$slotsRemaining slot${slotsRemaining > 1 ? 's' : ''} remaining'),
                trailing: level > spell.level
                  ? Chip(label: Text('Upcast', style: TextStyle(fontSize: 10)), backgroundColor: colorScheme.tertiaryContainer)
                  : null,
                onTap: () {
                  Navigator.of(context).pop();
                  _castSpell(spell, level);
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _castSpell(Spell spell, int slotLevel) {
    setState(() {
      // Use spell slot (if not cantrip)
      if (slotLevel > 0) {
        widget.character.useSpellSlot(slotLevel);
      }

      // Show feedback
      final message = slotLevel > spell.level
        ? '${spell.nameEn} cast at level $slotLevel!'
        : slotLevel == 0
          ? '${spell.nameEn} cast!'
          : '${spell.nameEn} cast! (Level $slotLevel slot used)';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final knownSpells = widget.character.knownSpells
        .map((id) => SpellService.getSpellById(id))
        .whereType<Spell>()
        .toList();

    final spellsByLevel = <int, List<Spell>>{};
    for (var spell in knownSpells) {
      spellsByLevel.putIfAbsent(spell.level, () => []).add(spell);
    }

    // Categorize Features
    final features = widget.character.features.toList();
    
    // 1. Resources: Have a resource pool
    final resourceFeatures = features.where((f) => f.resourcePool != null).toList();
    
    // 2. Passives: No pool, type is passive
    final passiveFeatures = features.where((f) => f.resourcePool == null && f.type == FeatureType.passive).toList();
    
    // 3. Actives: No pool, type is NOT passive (Action, Bonus Action, Reaction, etc.)
    final activeFeatures = features.where((f) => f.resourcePool == null && f.type != FeatureType.passive).toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === RESOURCES ===
            if (resourceFeatures.isNotEmpty) ...[
              _buildSectionHeader('RESOURCES'),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: resourceFeatures.map((feature) => _buildResourceFeature(feature)).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // === ACTIVE ABILITIES ===
            if (activeFeatures.isNotEmpty) ...[
              _buildSectionHeader('ACTIVE ABILITIES'),
              ...activeFeatures.map((feature) => _buildActiveFeature(feature)).toList(),
              const SizedBox(height: 16),
            ],

            // === MAGIC (Slots & Stats) ===
            _buildSectionHeader('MAGIC'),
            _buildMagicSection(context),
            const SizedBox(height: 16),

            // === SPELLS LIST ===
            if (knownSpells.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.auto_fix_off, size: 48, color: colorScheme.onSurface.withOpacity(0.3)),
                    const SizedBox(height: 8),
                    Text('No spells learned yet', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5))),
                  ],
                ),
              ))
            else
              ...(spellsByLevel.keys.toList()..sort()).map((level) => _buildSpellLevelGroup(level, spellsByLevel[level]!)).toList(),

            const SizedBox(height: 16),

            // === PASSIVE TRAITS ===
            if (passiveFeatures.isNotEmpty) ...[
              _buildSectionHeader('PASSIVE TRAITS'),
              Card(
                elevation: 1,
                child: ExpansionTile(
                  title: Text('${passiveFeatures.length} Passive Traits'),
                  subtitle: Text(
                    passiveFeatures.map((f) => f.nameEn).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  leading: Icon(Icons.psychology, color: colorScheme.secondary),
                  children: passiveFeatures.map((feature) => ListTile(
                    title: Text(feature.nameEn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(feature.descriptionEn, style: const TextStyle(fontSize: 12)),
                    dense: true,
                    leading: Icon(_getFeatureIcon(feature.iconName), size: 18, color: colorScheme.secondary.withOpacity(0.7)),
                  )).toList(),
                ),
              ),
            ],

            const SizedBox(height: 80), // Bottom padding for FAB
          ],
        ),
        
        // Floating Action Button
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SpellAlmanacScreen(character: widget.character),
                ),
              ).then((_) => setState(() {}));
            },
            icon: const Icon(Icons.library_books),
            label: const Text('Spell Almanac'),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildResourceFeature(CharacterFeature feature) {
    final pool = feature.resourcePool!;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(_getFeatureIcon(feature.iconName), size: 20, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature.nameEn, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              Text('${pool.currentUses}/${pool.maxUses}', 
                style: TextStyle(fontWeight: FontWeight.bold, color: pool.isEmpty ? colorScheme.error : colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pool.maxUses > 0 ? pool.currentUses / pool.maxUses : 0,
                    color: pool.isEmpty ? colorScheme.error : colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: pool.isEmpty ? null : () => setState(() { pool.use(1); widget.character.save(); }),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                iconSize: 24,
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: pool.isFull ? null : () => setState(() { pool.restore(1); widget.character.save(); }),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                iconSize: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFeature(CharacterFeature feature) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Smart check for Channel Divinity usage
    bool usesChannelDivinity = false;
    CharacterFeature? cdPoolFeature;
    
    // Heuristic: Name or Description mentions "Channel Divinity" AND it's an action-type feature
    if (feature.nameEn.contains('Channel Divinity') || feature.descriptionEn.contains('Channel Divinity')) {
      try {
        // Try to find the resource pool feature
        cdPoolFeature = widget.character.features.firstWhere((f) => f.id == 'channel_divinity');
        if (cdPoolFeature.resourcePool != null) {
          usesChannelDivinity = true;
        }
      } catch (_) {
        // No Channel Divinity pool found on character
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getFeatureIcon(feature.iconName), size: 20, color: colorScheme.onSecondaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(feature.nameEn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (feature.actionEconomy != null)
                        Text(
                          feature.actionEconomy!.toUpperCase(),
                          style: TextStyle(fontSize: 10, color: colorScheme.secondary, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              feature.descriptionEn, 
              maxLines: usesChannelDivinity ? 2 : 4, 
              overflow: TextOverflow.ellipsis, 
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)
            ),
            
            if (usesChannelDivinity && cdPoolFeature != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: cdPoolFeature.resourcePool!.currentUses > 0 
                    ? () => setState(() { cdPoolFeature!.resourcePool!.use(1); widget.character.save(); }) 
                    : null,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: Text(
                    cdPoolFeature.resourcePool!.currentUses > 0
                    ? 'Use Channel Divinity (${cdPoolFeature.resourcePool!.currentUses} left)'
                    : 'No Channel Divinity charges'
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMagicSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMagicStat('Ability', SpellcastingService.getSpellcastingAbilityName(widget.character.characterClass).substring(0, 3).toUpperCase()),
                Container(width: 1, height: 30, color: colorScheme.outlineVariant),
                _buildMagicStat('Save DC', '${SpellcastingService.getSpellSaveDC(widget.character)}'),
                Container(width: 1, height: 30, color: colorScheme.outlineVariant),
                _buildMagicStat('Attack', '+${SpellcastingService.getSpellAttackBonus(widget.character)}'),
              ],
            ),
            if (widget.character.maxSpellSlots.any((s) => s > 0)) ...[
              const Divider(height: 32),
              // Slots
              ...List.generate(9, (i) {
                final level = i + 1;
                // Safety checks
                if (i >= widget.character.maxSpellSlots.length) return const SizedBox.shrink();
                final max = widget.character.maxSpellSlots[i];
                if (max == 0) return const SizedBox.shrink();
                
                final curr = i < widget.character.spellSlots.length ? widget.character.spellSlots[i] : 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 40, child: Text('Lvl $level', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: List.generate(max, (j) {
                            final isUsed = j >= curr;
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (isUsed) widget.character.restoreSpellSlot(level);
                                else widget.character.useSpellSlot(level);
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: isUsed ? colorScheme.surfaceContainerHighest : colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isUsed ? colorScheme.outline : colorScheme.primary, 
                                    width: 1.5
                                  ),
                                ),
                                child: isUsed ? null : Icon(Icons.bolt, size: 18, color: colorScheme.onPrimary),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMagicStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
      ],
    );
  }

  Widget _buildSpellLevelGroup(int level, List<Spell> spells) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(level == 0 ? 'CANTRIPS' : 'LEVEL $level', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        ),
        ...spells.map((spell) {
           final isPrepared = widget.character.preparedSpells.contains(spell.id);
           // Bounds check for spell slots
           final canCast = spell.level == 0 || (spell.level <= widget.character.spellSlots.length && widget.character.spellSlots[spell.level - 1] > 0);
           
           return Card(
             margin: const EdgeInsets.only(bottom: 6),
             elevation: 0,
             shape: RoundedRectangleBorder(
               side: BorderSide(color: colorScheme.outlineVariant),
               borderRadius: BorderRadius.circular(12),
             ),
             child: ListTile(
               contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
               dense: true,
               leading: GestureDetector(
                 onTap: () {
                   // Toggle prepare
                   setState(() {
                      if (isPrepared) widget.character.preparedSpells.remove(spell.id);
                      else widget.character.preparedSpells.add(spell.id);
                      widget.character.save();
                   });
                 },
                 child: Icon(
                   isPrepared ? Icons.star : Icons.star_border, 
                   color: isPrepared ? Colors.amber : colorScheme.outline, 
                   size: 24
                 ),
               ),
               title: Text(spell.nameEn, style: const TextStyle(fontWeight: FontWeight.w600)),
               subtitle: Text(spell.school, style: TextStyle(color: colorScheme.secondary, fontSize: 11)),
               trailing: IconButton(
                 icon: const Icon(Icons.auto_fix_high),
                 onPressed: canCast ? () => _showCastSpellDialog(spell) : null,
                 color: canCast ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.2),
                 tooltip: 'Cast Spell',
               ),
               onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(spell.descriptionEn), duration: const Duration(seconds: 2))
               ),
             ),
           );
        }).toList(),
        const SizedBox(height: 8),
      ],
    );
  }

  IconData _getFeatureIcon(String? iconName) {
    switch (iconName) {
      case 'healing': return Icons.favorite;
      case 'visibility': return Icons.visibility;
      case 'flash_on': return Icons.flash_on;
      case 'swords': return Icons.shield;
      case 'auto_fix_high': return Icons.auto_fix_high;
      case 'health_and_safety': return Icons.health_and_safety;
      case 'auto_awesome': return Icons.auto_awesome;
      case 'filter_2': return Icons.filter_2;
      case 'security': return Icons.security;
      case 'back_hand': return Icons.back_hand;
      case 'wifi_tethering': return Icons.wifi_tethering;
      default: return Icons.star;
    }
  }
}