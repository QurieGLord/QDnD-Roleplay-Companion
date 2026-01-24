import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/spell.dart';
import '../../../core/models/combat_state.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/services/spellcasting_service.dart';

class CombatSpellcasterSheet extends StatefulWidget {
  final Character character;
  final VoidCallback onStateChange;

  const CombatSpellcasterSheet({
    super.key,
    required this.character,
    required this.onStateChange,
  });

  @override
  State<CombatSpellcasterSheet> createState() => _CombatSpellcasterSheetState();
}

class _CombatSpellcasterSheetState extends State<CombatSpellcasterSheet> {
  final _uuid = const Uuid();

  List<Spell> _getDisplaySpells(String locale) {
    final type = SpellcastingService.getSpellcastingType(widget.character.characterClass);
    final allKnown = widget.character.knownSpells
        .map((id) => SpellService.getSpellById(id))
        .whereType<Spell>()
        .toList();

    List<Spell> displaySpells = [];

    // 1. Always add Cantrips (Level 0)
    displaySpells.addAll(allKnown.where((s) => s.level == 0));

    // 2. Add Leveled Spells based on caster type
    if (type == 'prepared') {
      // Prepared casters (Wizard, Cleric, etc) -> Show Prepared Spells
      final prepared = widget.character.preparedSpells
          .map((id) => SpellService.getSpellById(id))
          .whereType<Spell>()
          .toList();
      displaySpells.addAll(prepared);
    } else {
      // Known casters (Bard, Sorcerer, etc) -> Show All Known Leveled Spells
      displaySpells.addAll(allKnown.where((s) => s.level > 0));
    }

    // Deduplicate just in case
    final uniqueIds = <String>{};
    final uniqueSpells = <Spell>[];
    for (var s in displaySpells) {
      if (uniqueIds.add(s.id)) {
        uniqueSpells.add(s);
      }
    }

    // Sort: Level (asc), then Name (asc)
    uniqueSpells.sort((a, b) {
      if (a.level != b.level) return a.level.compareTo(b.level);
      return a.getName(locale).compareTo(b.getName(locale));
    });

    return uniqueSpells;
  }

  Future<void> _castSpell(Spell spell, AppLocalizations l10n, String locale) async {
    // 1. Cantrip -> Just Log
    if (spell.level == 0) {
      _addLog(l10n, 'Cast ${spell.getName(locale)} (Cantrip)');
      return;
    }

    // 2. Leveled Spell -> Choose Slot
    final availableSlots = <int>[];
    for (int i = spell.level; i <= widget.character.maxSpellSlots.length; i++) {
      if (i <= widget.character.spellSlots.length && widget.character.spellSlots[i - 1] > 0) {
        availableSlots.add(i);
      }
    }

    if (availableSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noSlotsAvailable),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.castAction(spell.getName(locale))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableSlots.map((level) {
            return ListTile(
              title: Text(l10n.levelSlot(level)),
              trailing: level > spell.level 
                  ? Chip(label: Text(l10n.upcast), backgroundColor: Theme.of(context).colorScheme.tertiaryContainer) 
                  : null,
              onTap: () async {
                Navigator.pop(context);
                await _consumeSlotAndLog(spell, level, l10n, locale);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _consumeSlotAndLog(Spell spell, int level, AppLocalizations l10n, String locale) async {
    // Consume slot
    setState(() {
       widget.character.useSpellSlot(level);
    });
    
    // Log
    final msg = level > spell.level 
        ? 'Cast ${spell.getName(locale)} (Lvl $level)'
        : 'Cast ${spell.getName(locale)} (Lvl ${spell.level})';
    
    _addLog(l10n, msg);
  }

  void _addLog(AppLocalizations l10n, String message) {
    final entry = CombatLogEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      type: CombatLogType.other,
      description: message,
      round: widget.character.combatState.currentRound,
    );
    
    widget.character.combatState.addLogEntry(entry);
    widget.onStateChange(); // Save and update parent
    
    // In a sheet, showing a SnackBar might be hidden by the sheet itself in some contexts, 
    // but usually fine.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1000),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // Close sheet after cast?
    // User didn't specify, but often convenient. 
    // Let's keep it open so user can see slots updated or cast another (e.g. Bonus Action).
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final spells = _getDisplaySpells(locale);
    final isPactMagic = SpellcastingService.getSpellcastingType(widget.character.characterClass) == 'pact_magic';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // --- HANDLE ---
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // --- TITLE ---
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.castSpell, style: theme.textTheme.titleLarge),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // --- SLOTS HEADER ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.magic.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.primary)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: widget.character.maxSpellSlots.asMap().entries.map((entry) {
                            final index = entry.key;
                            final max = entry.value;
                            final level = index + 1;
                            if (max <= 0) return const SizedBox.shrink();
                            
                            final current = index < widget.character.spellSlots.length ? widget.character.spellSlots[index] : 0;
                            final isEmpty = current == 0;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isEmpty ? colorScheme.errorContainer.withOpacity(0.5) : colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isEmpty ? colorScheme.error : (isPactMagic ? Colors.purple : colorScheme.primary),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Lvl $level: $current/$max',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isEmpty ? colorScheme.error : colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),

              // --- SPELLS LIST ---
              Expanded(
                child: spells.isEmpty
                  ? Center(
                      child: Text(l10n.noSpellsLearned, style: TextStyle(color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: spells.length,
                      itemBuilder: (context, index) {
                        final spell = spells[index];
                        final isCantrip = spell.level == 0;
                        // Check if can cast (has slots)
                        bool canCast = isCantrip;
                        if (!canCast) {
                           // Check if any slot >= spell level is available
                           for (int i = spell.level; i <= widget.character.spellSlots.length; i++) {
                             if (widget.character.spellSlots[i-1] > 0) {
                               canCast = true;
                               break;
                             }
                           }
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16, // Slightly larger for sheet
                            backgroundColor: isCantrip ? Colors.grey : (isPactMagic ? Colors.purple : colorScheme.primary),
                            child: Text(
                              isCantrip ? '0' : '${spell.level}', 
                              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)
                            ),
                          ),
                          title: Text(spell.getName(locale), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            isCantrip ? l10n.cantrips : '${l10n.levelShort} ${spell.level}',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.flash_on),
                            color: canCast ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.1),
                            onPressed: canCast ? () => _castSpell(spell, l10n, locale) : null,
                          ),
                          onTap: canCast ? () => _castSpell(spell, l10n, locale) : null,
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}