import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/spell.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/models/character.dart';

class SpellsStep extends StatefulWidget {
  final Character character;
  final int nextLevel;
  final int spellsToLearnCount;
  final Function(List<String>) onSpellsSelected;
  final VoidCallback onNext;

  const SpellsStep({
    super.key,
    required this.character,
    required this.nextLevel,
    required this.spellsToLearnCount,
    required this.onSpellsSelected,
    required this.onNext,
  });

  @override
  State<SpellsStep> createState() => _SpellsStepState();
}

class _SpellsStepState extends State<SpellsStep> {
  final Set<String> _selectedSpells = {};
  List<Spell> _availableSpells = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableSpells();
  }

  Future<void> _loadAvailableSpells() async {
    final classId = widget.character.characterClass;
    
    // 1. Get all spells for class
    final allClassSpells = SpellService.getSpellsForClass(classId);
    
    // 2. Determine Max Slot Level at Next Level
    // (Logic omitted for brevity, focusing on availability)
    
    // Heuristic for now (until we refactor Slot Logic into Service):
    // Standard Full Caster Progression:
    // Lvl 1-2: 1st
    // Lvl 3-4: 2nd
    // Lvl 5-6: 3rd
    // ...
    // Formula: ceil(Level / 2) for Full Casters.
    
    // TODO: Pass maxSpellLevel from parent for 100% accuracy.
    // For now, let's assume filtering happens via "Known Spells" logic (users can pick what they want, but usually valid ones).
    // Actually, restricting is better.
    
    // Let's just load ALL class spells for now, and rely on the user or visual cues.
    // Or filter by (Level <= 9).
    
    // Filter out already known spells
    final knownIds = widget.character.knownSpells.toSet();
    
    _availableSpells = allClassSpells.where((s) {
      if (knownIds.contains(s.id)) return false;
      if (s.level == 0) return true; // Cantrips always available? (Usually handled separately)
      return true; // Filter by level later if needed
    }).toList();

    // Sort by Level then Name
    _availableSpells.sort((a, b) {
      if (a.level != b.level) return a.level.compareTo(b.level);
      return a.nameEn.compareTo(b.nameEn);
    });

    setState(() {
      _isLoading = false;
    });
  }

  void _toggleSpell(String spellId) {
    setState(() {
      if (_selectedSpells.contains(spellId)) {
        _selectedSpells.remove(spellId);
      } else {
        if (_selectedSpells.length < widget.spellsToLearnCount) {
          _selectedSpells.add(spellId);
        }
      }
      widget.onSpellsSelected(_selectedSpells.toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Group by Level
    final spellsByLevel = <int, List<Spell>>{};
    for (var s in _availableSpells) {
      spellsByLevel.putIfAbsent(s.level, () => []).add(s);
    }
    final sortedLevels = spellsByLevel.keys.toList()..sort();

    final remaining = widget.spellsToLearnCount - _selectedSpells.length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surfaceContainer,
          child: Column(
            children: [
              Text(
                'Learn New Spells',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Select ${widget.spellsToLearnCount} new spells to add to your repertoire.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _selectedSpells.length / widget.spellsToLearnCount,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 8),
              Text(
                remaining > 0 ? 'Choose $remaining more' : 'All selected!',
                style: TextStyle(
                  color: remaining > 0 ? theme.colorScheme.primary : theme.colorScheme.tertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: sortedLevels.length,
            itemBuilder: (context, index) {
              final level = sortedLevels[index];
              final spells = spellsByLevel[level]!;
              
              return ExpansionTile(
                initiallyExpanded: index == 0, // Expand lowest level by default
                title: Text(
                  level == 0 ? l10n.cantrips : l10n.levelLabel(level),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                children: spells.map((spell) {
                  final isSelected = _selectedSpells.contains(spell.id);
                  final isDisabled = !isSelected && remaining <= 0;
                  
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: isDisabled ? null : (_) => _toggleSpell(spell.id),
                    title: Text(spell.getName(locale)),
                    subtitle: Text(
                      spell.school, // Should be localized ideally
                      style: theme.textTheme.bodySmall,
                    ),
                    secondary: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton(
            onPressed: remaining == 0 ? widget.onNext : null,
            child: Text(l10n.continueLabel),
          ),
        ),
      ],
    );
  }
}
