import 'package:flutter/material.dart';
import '../../../core/models/character.dart';
import '../../../core/models/spell.dart';
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
      if (widget.character.spellSlots[i - 1] > 0) {
        availableSlots.add(i);
      }
    }

    if (availableSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No spell slots available!')),
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

    // Get ALL features (both with and without resource pools)
    final features = widget.character.features.toList();

    // Debug output
    print('🔧 SpellsTab build: character has ${widget.character.features.length} total features');
    for (var f in widget.character.features) {
      print('🔧   - ${f.nameEn} (pool: ${f.resourcePool != null})');
    }

    return Stack(
      children: [
        ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Class Features section
        if (features.isNotEmpty) ...[
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('CLASS FEATURES', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...features.map((feature) {
                    final pool = feature.resourcePool;

                    // Feature with resource pool - show full UI with progress bar
                    if (pool != null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    feature.nameEn,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                  ),
                                ),
                                Text(
                                  '${pool.currentUses}/${pool.maxUses}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: pool.isEmpty ? colorScheme.error : colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: pool.maxUses > 0 ? pool.currentUses / pool.maxUses : 0,
                                    backgroundColor: colorScheme.surfaceContainerHighest,
                                    color: pool.isEmpty ? colorScheme.error : colorScheme.primary,
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: pool.isEmpty
                                      ? null
                                      : () {
                                          setState(() {
                                            pool.use(1);
                                            StorageService.saveCharacter(widget.character);
                                          });
                                        },
                                  tooltip: 'Use',
                                  iconSize: 28,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: pool.isFull
                                      ? null
                                      : () {
                                          setState(() {
                                            pool.restore(1);
                                            StorageService.saveCharacter(widget.character);
                                          });
                                        },
                                  tooltip: 'Restore',
                                  iconSize: 28,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              feature.descriptionEn,
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.7)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }

                    // Feature without resource pool (e.g., Channel Divinity options) - show simple card with usage button
                    // Find the main Channel Divinity pool if this feature uses it
                    final channelDivinity = widget.character.features.firstWhere(
                      (f) => f.id == 'channel_divinity',
                      orElse: () => feature, // Fallback to self if no Channel Divinity found
                    );
                    final hasChannelDivinity = channelDivinity.id == 'channel_divinity' && channelDivinity.resourcePool != null;
                    final canUseChannelDivinity = hasChannelDivinity && channelDivinity.resourcePool!.currentUses > 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.secondary.withOpacity(0.3), width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                          color: colorScheme.surfaceContainerLow,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.bolt, size: 20, color: colorScheme.secondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    feature.nameEn,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                  ),
                                ),
                                if (feature.actionEconomy != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      feature.actionEconomy!.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              feature.descriptionEn,
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.7)),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (hasChannelDivinity) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonalIcon(
                                  onPressed: canUseChannelDivinity
                                      ? () {
                                          setState(() {
                                            channelDivinity.resourcePool!.use(1);
                                            widget.character.save();
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.auto_awesome, size: 18),
                                  label: Text(
                                    canUseChannelDivinity
                                        ? 'Use Channel Divinity (${channelDivinity.resourcePool!.currentUses}/${channelDivinity.resourcePool!.maxUses} available)'
                                        : 'No Channel Divinity charges (${channelDivinity.resourcePool!.currentUses}/${channelDivinity.resourcePool!.maxUses})',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: canUseChannelDivinity ? colorScheme.secondaryContainer : colorScheme.surfaceContainerHighest,
                                    foregroundColor: canUseChannelDivinity ? colorScheme.onSecondaryContainer : colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Spell Slots
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SPELL SLOTS', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...List.generate(9, (i) {
                  final level = i + 1;
                  
                  // Safety check for array bounds
                  if (i >= widget.character.maxSpellSlots.length) return const SizedBox.shrink();
                  
                  final max = widget.character.maxSpellSlots[i];
                  if (max == 0) return const SizedBox.shrink();
                  
                  final curr = i < widget.character.spellSlots.length 
                      ? widget.character.spellSlots[i] 
                      : 0; // Default to 0 if current slots array is shorter

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(width: 60, child: Text('Level $level', style: const TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            children: List.generate(max, (j) {
                              final isUsed = j >= curr;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  if (isUsed) widget.character.restoreSpellSlot(level);
                                  else widget.character.useSpellSlot(level);
                                }),
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: isUsed ? colorScheme.surfaceContainerHighest : colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colorScheme.primary, width: 2),
                                  ),
                                  child: isUsed ? null : Icon(Icons.auto_fix_high, size: 16, color: colorScheme.onPrimaryContainer),
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
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Spellcasting Info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_fix_high, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Spellcasting', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Spellcasting Ability'),
                  Text(SpellcastingService.getSpellcastingAbilityName(widget.character.characterClass), style: const TextStyle(fontWeight: FontWeight.bold))
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Spell Save DC'),
                  Text('${SpellcastingService.getSpellSaveDC(widget.character)}', style: const TextStyle(fontWeight: FontWeight.bold))
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Spell Attack'),
                  Text('+${SpellcastingService.getSpellAttackBonus(widget.character)}', style: const TextStyle(fontWeight: FontWeight.bold))
                ]),
                if (SpellcastingService.getSpellcastingType(widget.character.characterClass) == 'prepared')
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Prepared'),
                    Text('${widget.character.preparedSpells.length}/${widget.character.maxPreparedSpells}', style: const TextStyle(fontWeight: FontWeight.bold))
                  ]),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        if (knownSpells.isEmpty) ...[
          Center(child: Column(children: [
            Icon(Icons.auto_fix_off, size: 64, color: colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No spells learned yet', style: Theme.of(context).textTheme.titleMedium),
          ])),
        ] else ...[
          ...spellsByLevel.keys.toList()..sort(),
        ].map((level) {
          final spells = spellsByLevel[level]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(level == 0 ? 'CANTRIPS' : 'LEVEL $level', style: TextStyle(color: colorScheme.primary)),
              ),
              ...spells.map((spell) {
                final isPrepared = widget.character.preparedSpells.contains(spell.id);
                final canCast = spell.level == 0 || (spell.level <= widget.character.spellSlots.length && widget.character.spellSlots[spell.level - 1] > 0);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: _getSchoolColor(spell.school), shape: BoxShape.circle),
                      child: Center(child: Text(spell.level == 0 ? '∞' : '${spell.level}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                    ),
                    title: Text(spell.nameEn),
                    subtitle: Row(children: [
                      if (spell.concentration) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.timelapse, size: 14)),
                      if (spell.ritual) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.book, size: 14)),
                      Text(spell.school),
                    ]),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Cast button
                        if (isPrepared) IconButton(
                          icon: Icon(Icons.auto_fix_high, color: canCast ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.3)),
                          onPressed: canCast ? () => _showCastSpellDialog(spell) : null,
                          tooltip: 'Cast',
                        ),
                        // Prepare/Unprepare button
                        IconButton(
                          icon: Icon(isPrepared ? Icons.star : Icons.star_outline, color: isPrepared ? Colors.amber : null),
                          onPressed: () {
                            setState(() {
                              if (isPrepared) {
                                widget.character.preparedSpells.remove(spell.id);
                              } else {
                                if (widget.character.preparedSpells.length < widget.character.maxPreparedSpells) {
                                  widget.character.preparedSpells.add(spell.id);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum prepared spells reached!')));
                                  return;
                                }
                              }
                              StorageService.saveCharacter(widget.character);
                            });
                          },
                          tooltip: isPrepared ? 'Unprepare' : 'Prepare',
                        ),
                      ],
                    ),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Spell details - ${spell.nameEn}'))),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),

        // Add bottom padding so content doesn't hide behind FAB
        const SizedBox(height: 80),
      ],
    ),
        // Floating Action Button for Spell Almanac
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SpellAlmanacScreen(character: widget.character),
                ),
              ).then((_) {
                // Rebuild UI after returning from Spell Almanac
                setState(() {});
              });
            },
            icon: const Icon(Icons.library_books),
            label: const Text('Spell Almanac'),
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }
}
