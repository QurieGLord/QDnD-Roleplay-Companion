import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/spell.dart';
import '../../core/models/character.dart';
import '../../core/services/spell_service.dart';
import '../../core/services/spell_eligibility_service.dart';

/// Spell Almanac with smart filtering and level grouping
class SpellAlmanacScreen extends StatefulWidget {
  final Character? character; // Optional: for smart filtering

  const SpellAlmanacScreen({super.key, this.character});

  @override
  State<SpellAlmanacScreen> createState() => _SpellAlmanacScreenState();
}

class _SpellAlmanacScreenState extends State<SpellAlmanacScreen> {
  String _searchQuery = '';
  int? _filterLevel;
  String? _filterSchool;
  String? _filterClass;
  bool? _filterConcentration;
  bool? _filterRitual;
  SpellAvailabilityFilter _availabilityFilter = SpellAvailabilityFilter.all;

  List<Spell> _getFilteredSpells(String locale) {
    List<Spell> spells = SpellService.getAllSpells();

    // 1. Apply availability filter (if character provided)
    if (widget.character != null) {
      switch (_availabilityFilter) {
        case SpellAvailabilityFilter.canLearnNow:
          spells = SpellEligibilityService.getLearnableSpells(widget.character!, spells);
          break;
        case SpellAvailabilityFilter.availableToClass:
          spells = SpellEligibilityService.getAvailableSpells(widget.character!, spells);
          break;
        case SpellAvailabilityFilter.all:
          // No filtering
          break;
      }
    }

    // 2. Apply search
    if (_searchQuery.isNotEmpty) {
      spells = spells.where((spell) {
        return spell.getName(locale).toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // 3. Apply class filter
    if (_filterClass != null) {
      spells = spells.where((spell) =>
        spell.availableToClasses.any((c) => c.toLowerCase() == _filterClass!.toLowerCase())
      ).toList();
    }

    // 4. Apply level filter
    if (_filterLevel != null) {
      spells = spells.where((spell) => spell.level == _filterLevel).toList();
    }

    // 5. Apply school filter
    if (_filterSchool != null) {
      spells = spells.where((spell) => spell.school == _filterSchool).toList();
    }

    // 6. Apply concentration filter
    if (_filterConcentration != null) {
      spells = spells.where((spell) => spell.concentration == _filterConcentration).toList();
    }

    // 7. Apply ritual filter
    if (_filterRitual != null) {
      spells = spells.where((spell) => spell.ritual == _filterRitual).toList();
    }

    return spells;
  }

  /// Group spells by level for display
  Map<int, List<Spell>> _groupSpellsByLevel(List<Spell> spells) {
    final grouped = <int, List<Spell>>{};
    for (var spell in spells) {
      grouped.putIfAbsent(spell.level, () => []).add(spell);
    }
    return grouped;
  }

  Color _getSchoolColor(String school) {
    final lower = school.toLowerCase();
    if (lower.contains('abj')) return Colors.blue;
    if (lower.contains('con')) return Colors.purple;
    if (lower.contains('div')) return Colors.cyan;
    if (lower.contains('enc')) return Colors.pink;
    if (lower.contains('evo')) return Colors.red;
    if (lower.contains('ill')) return Colors.indigo;
    if (lower.contains('nec')) return Colors.grey;
    if (lower.contains('tra')) return Colors.green;
    return Theme.of(context).colorScheme.primary;
  }

  String _getLocalizedSchool(AppLocalizations l10n, String school) {
    final lower = school.toLowerCase();
    if (lower.contains('abjur')) return l10n.schoolAbjuration;
    if (lower.contains('conjur')) return l10n.schoolConjuration;
    if (lower.contains('divin')) return l10n.schoolDivination;
    if (lower.contains('enchant')) return l10n.schoolEnchantment;
    if (lower.contains('evoc')) return l10n.schoolEvocation;
    if (lower.contains('illus')) return l10n.schoolIllusion;
    if (lower.contains('necro')) return l10n.schoolNecromancy;
    if (lower.contains('trans')) return l10n.schoolTransmutation;
    return school;
  }

  String _getLocalizedValue(AppLocalizations l10n, String value) {
    var lower = value.toLowerCase().trim();
    
    // Casting Time
    if (lower.contains('1 action') || lower == '1 action') return '1 ${l10n.actionTypeAction.toLowerCase()}';
    if (lower.contains('1 bonus action')) return '1 ${l10n.actionTypeBonus.toLowerCase()}';
    if (lower.contains('1 reaction')) return '1 ${l10n.actionTypeReaction.toLowerCase()}';
    if (lower.contains('minutes')) return value.replaceAll('minutes', 'мин.');
    if (lower.contains('minute')) return value.replaceAll('minute', 'мин.');
    if (lower.contains('hours')) return value.replaceAll('hours', 'ч.');
    if (lower.contains('hour')) return value.replaceAll('hour', 'ч.');

    // Range
    if (lower == 'self') return 'На себя';
    if (lower == 'touch') return 'Касание';
    if (lower.contains('feet')) return value.replaceAll('feet', 'фт.');
    if (lower.contains('foot')) return value.replaceAll('foot', 'фт.');
    if (lower.contains('radius')) return value.replaceAll('radius', 'радиус').replaceAll('feet', 'фт.');

    // Duration
    if (lower == 'instantaneous') return 'Мгновенная';
    if (lower == 'until dispelled') return 'Пока не рассеется';
    if (lower == 'special') return 'Особое';
    
    // Handle "Concentration, up to X" pattern
    if (lower.contains('concentration')) {
       // Remove "Concentration, " prefix from value to process the rest
       var rest = value.replaceAll(RegExp(r'Concentration,\s*', caseSensitive: false), '');
       
       // Handle "up to" in the remaining part
       if (rest.toLowerCase().contains('up to')) {
         rest = rest.replaceAll(RegExp(r'up to', caseSensitive: false), 'вплоть до');
       }
       
       // Localize time units in the remaining part
       rest = _getLocalizedValue(l10n, rest);
       
       return '${l10n.concentration}, $rest';
    }
    
    // Handle simple "up to" without concentration (rare but possible)
    if (lower.contains('up to')) {
      value = value.replaceAll(RegExp(r'up to', caseSensitive: false), 'вплоть до');
      // Recursive call to handle units
      return _getLocalizedValue(l10n, value);
    }

    if (lower.contains('round')) return value.replaceAll('round', 'раунд');

    // Components
    // Often handled by simple list join, but we can localize V, S, M if needed.
    // In Russian usually V, S, M are V, S, M or В, С, М. Let's assume standard VSM for now or transliterate.
    
    return value;
  }
  
  String _getLocalizedClassName(BuildContext context, String className) {
    // This is a simple mapping. In a real app, you might want to fetch from CharacterDataService if available.
    final l10n = AppLocalizations.of(context)!;
    // We don't have direct class name keys in l10n yet, but we can try to map standard names.
    // Or we can assume the className is English and map it manually here for now, 
    // or add keys to ARB.
    
    switch (className.toLowerCase()) {
      case 'barbarian': return 'Варвар';
      case 'bard': return 'Бард';
      case 'cleric': return 'Жрец';
      case 'druid': return 'Друид';
      case 'fighter': return 'Воин';
      case 'monk': return 'Монах';
      case 'paladin': return 'Паладин';
      case 'ranger': return 'Следопыт';
      case 'rogue': return 'Плут';
      case 'sorcerer': return 'Чародей';
      case 'warlock': return 'Колдун';
      case 'wizard': return 'Волшебник';
      case 'artificer': return 'Изобретатель';
      default: return className;
    }
  }

  void _showSpellDetails(Spell spell) {
    final eligibility = widget.character != null
        ? SpellEligibilityService.checkEligibility(widget.character!, spell)
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          final colorScheme = Theme.of(context).colorScheme;
          final l10n = AppLocalizations.of(context)!;
          final locale = Localizations.localeOf(context).languageCode;

          return Container(
            padding: const EdgeInsets.all(24),
            child: ListView(
              controller: scrollController,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getSchoolColor(spell.school),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          spell.level == 0 ? '∞' : '${spell.level}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spell.getName(locale),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_getLocalizedSchool(l10n, spell.school)}${spell.level == 0 ? ' • ${l10n.cantrips}' : ' • ${l10n.levelLabel(spell.level)}'}',
                            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Eligibility badge (if character provided)
                if (eligibility != null) ...[
                  const SizedBox(height: 16),
                  _buildEligibilityBadge(eligibility, l10n),
                ],

                const SizedBox(height: 24),

                // Stats
                _buildInfoRow(l10n.castingTime, _getLocalizedValue(l10n, spell.castingTime)),
                _buildInfoRow(l10n.range, _getLocalizedValue(l10n, spell.range)),
                _buildInfoRow(l10n.duration, _getLocalizedValue(l10n, spell.duration)),
                _buildInfoRow(l10n.components, spell.components.join(', ')),
                if (spell.getMaterialComponents(locale) != null)
                  _buildInfoRow(l10n.materials, spell.getMaterialComponents(locale)!),
                if (spell.concentration || spell.ritual)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (spell.concentration)
                          Chip(
                            label: Text(l10n.concentration),
                            avatar: const Icon(Icons.timelapse, size: 16),
                          ),
                        if (spell.ritual)
                          Chip(
                            label: Text(l10n.ritual),
                            avatar: const Icon(Icons.book, size: 16),
                          ),
                      ],
                    ),
                  ),

                const Divider(height: 32),

                // Description
                Text(
                  spell.getDescription(locale),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),

                if (spell.getAtHigherLevels(locale) != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.atHigherLevels,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    spell.getAtHigherLevels(locale)!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],

                const SizedBox(height: 16),
                Text(
                  '${l10n.classes}: ${spell.availableToClasses.map((c) => _getLocalizedClassName(context, c)).join(', ')}',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),

                // Add/Remove from Known Spells button (if character provided and eligible)
                if (widget.character != null && eligibility != null && eligibility.canLearn) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        _toggleKnownSpell(spell, l10n);
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        widget.character!.knownSpells.contains(spell.id)
                            ? Icons.remove_circle_outline
                            : Icons.add_circle_outline,
                      ),
                      label: Text(
                        widget.character!.knownSpells.contains(spell.id)
                            ? l10n.removeFromKnown
                            : l10n.addToKnown,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.character!.knownSpells.contains(spell.id)
                            ? colorScheme.error
                            : colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _toggleKnownSpell(Spell spell, AppLocalizations l10n) async {
    if (widget.character == null) return;
    final locale = Localizations.localeOf(context).languageCode;

    final isKnown = widget.character!.knownSpells.contains(spell.id);

    setState(() {
      if (isKnown) {
        widget.character!.knownSpells.remove(spell.id);
        // Also remove from prepared spells if it was prepared
        widget.character!.preparedSpells.remove(spell.id);
      } else {
        widget.character!.knownSpells.add(spell.id);
      }
    });

    // Save to storage
    await widget.character!.save();

    // Show snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isKnown
                ? l10n.removedFromKnown(spell.getName(locale))
                : l10n.addedToKnown(spell.getName(locale)),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildEligibilityBadge(SpellEligibilityResult eligibility, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;

    if (eligibility.canLearn) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 8),
            Text(l10n.availableToLearn, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else if (eligibility.canLearnAtLevel != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock, color: Colors.orange, size: 16),
            const SizedBox(width: 8),
            Text(
              l10n.availableAtLevel(eligibility.canLearnAtLevel!),
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.error),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, color: colorScheme.error, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                eligibility.reason, // Reason might come from service, hard to localize unless service returns key
                style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showFilters(AppLocalizations l10n) {
    final allClasses = ['Wizard', 'Cleric', 'Druid', 'Bard', 'Sorcerer', 'Paladin', 'Ranger', 'Warlock'];
    final allSchools = ['Abjuration', 'Conjuration', 'Divination', 'Enchantment', 'Evocation', 'Illusion', 'Necromancy', 'Transmutation'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.filters, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),

                    // Availability filter (if character provided)
                    if (widget.character != null) ...[
                      Text('${l10n.filterAvailability} (${widget.character!.name})', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: Text(l10n.filterAllSpells),
                            selected: _availabilityFilter == SpellAvailabilityFilter.all,
                            onSelected: (selected) {
                              setModalState(() => _availabilityFilter = SpellAvailabilityFilter.all);
                              setState(() => _availabilityFilter = SpellAvailabilityFilter.all);
                            },
                          ),
                          FilterChip(
                            label: Text(l10n.filterCanLearnNow),
                            selected: _availabilityFilter == SpellAvailabilityFilter.canLearnNow,
                            onSelected: (selected) {
                              setModalState(() => _availabilityFilter = SpellAvailabilityFilter.canLearnNow);
                              setState(() => _availabilityFilter = SpellAvailabilityFilter.canLearnNow);
                            },
                          ),
                          FilterChip(
                            label: Text(l10n.filterAvailableToClass),
                            selected: _availabilityFilter == SpellAvailabilityFilter.availableToClass,
                            onSelected: (selected) {
                              setModalState(() => _availabilityFilter = SpellAvailabilityFilter.availableToClass);
                              setState(() => _availabilityFilter = SpellAvailabilityFilter.availableToClass);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Class filter
                    Text(l10n.filterClass, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: Text(l10n.filterAllClasses),
                          selected: _filterClass == null,
                          onSelected: (selected) {
                            setModalState(() => _filterClass = null);
                            setState(() => _filterClass = null);
                          },
                        ),
                        ...allClasses.map((className) {
                          return FilterChip(
                            label: Text(_getLocalizedClassName(context, className)),
                            selected: _filterClass == className,
                            onSelected: (selected) {
                              setModalState(() => _filterClass = selected ? className : null);
                              setState(() => _filterClass = selected ? className : null);
                            },
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Level filter
                    Text(l10n.filterLevel, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: Text(l10n.filterAllLevels),
                          selected: _filterLevel == null,
                          onSelected: (selected) {
                            setModalState(() => _filterLevel = null);
                            setState(() => _filterLevel = null);
                          },
                        ),
                        ...List.generate(10, (i) {
                          return FilterChip(
                            label: Text(i == 0 ? l10n.cantrips : '${l10n.levelShort} $i'),
                            selected: _filterLevel == i,
                            onSelected: (selected) {
                              setModalState(() => _filterLevel = selected ? i : null);
                              setState(() => _filterLevel = selected ? i : null);
                            },
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // School filter
                    Text(l10n.filterSchool, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: Text(l10n.filterAllSchools),
                          selected: _filterSchool == null,
                          onSelected: (selected) {
                            setModalState(() => _filterSchool = null);
                            setState(() => _filterSchool = null);
                          },
                        ),
                        ...allSchools.map((school) {
                          return FilterChip(
                            label: Text(_getLocalizedSchool(l10n, school)),
                            selected: _filterSchool == school,
                            onSelected: (selected) {
                              setModalState(() => _filterSchool = selected ? school : null);
                              setState(() => _filterSchool = selected ? school : null);
                            },
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Concentration & Ritual
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: Text(l10n.concentration),
                            tristate: true,
                            value: _filterConcentration,
                            onChanged: (value) {
                              setModalState(() => _filterConcentration = value);
                              setState(() => _filterConcentration = value);
                            },
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            title: Text(l10n.ritual),
                            tristate: true,
                            value: _filterRitual,
                            onChanged: (value) {
                              setModalState(() => _filterRitual = value);
                              setState(() => _filterRitual = value);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _filterLevel = null;
                              _filterSchool = null;
                              _filterClass = null;
                              _filterConcentration = null;
                              _filterRitual = null;
                              _availabilityFilter = SpellAvailabilityFilter.all;
                            });
                            setState(() {
                              _filterLevel = null;
                              _filterSchool = null;
                              _filterClass = null;
                              _filterConcentration = null;
                              _filterRitual = null;
                              _availabilityFilter = SpellAvailabilityFilter.all;
                            });
                          },
                          child: Text(l10n.clearAll),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.apply),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    final filteredSpells = _getFilteredSpells(locale);
    final groupedSpells = _groupSpellsByLevel(filteredSpells);
    final sortedLevels = groupedSpells.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.character != null ? '${l10n.spellAlmanacTitle} - ${widget.character!.name}' : l10n.spellAlmanacTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilters(l10n),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchSpells,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Results count + active filters summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  l10n.spellsCount(filteredSpells.length),
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_hasActiveFilters())
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _filterLevel = null;
                        _filterSchool = null;
                        _filterClass = null;
                        _filterConcentration = null;
                        _filterRitual = null;
                        _availabilityFilter = SpellAvailabilityFilter.all;
                      });
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: Text(l10n.clearFilters),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Spell list GROUPED BY LEVEL
          Expanded(
            child: filteredSpells.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: colorScheme.onSurface.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(l10n.noSpellsFound, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(l10n.tryAdjustingFilters, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedLevels.length,
                    itemBuilder: (context, levelIndex) {
                      final level = sortedLevels[levelIndex];
                      final spells = groupedSpells[level]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Level header
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    level == 0 ? l10n.cantrips.toUpperCase() : '${l10n.levelShort} $level'.toUpperCase(),
                                    style: TextStyle(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.spellsCount(spells.length),
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Spells in this level
                          ...spells.map((spell) {
                            final eligibility = widget.character != null
                                ? SpellEligibilityService.checkEligibility(widget.character!, spell)
                                : null;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _getSchoolColor(spell.school),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      spell.level == 0 ? '∞' : '${spell.level}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(spell.getName(locale)),
                                subtitle: Row(
                                  children: [
                                    if (spell.concentration)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: Icon(Icons.timelapse, size: 14),
                                      ),
                                    if (spell.ritual)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: Icon(Icons.book, size: 14),
                                      ),
                                    Expanded(child: Text(_getLocalizedSchool(l10n, spell.school))),
                                  ],
                                ),
                                trailing: eligibility != null ? _buildEligibilityIcon(eligibility) : null,
                                onTap: () => _showSpellDetails(spell),
                              ),
                            );
                          }),

                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget? _buildEligibilityIcon(SpellEligibilityResult eligibility) {
    if (eligibility.canLearn) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 20);
    } else if (eligibility.canLearnAtLevel != null) {
      return const Icon(Icons.lock_clock, color: Colors.orange, size: 20);
    } else {
      return const Icon(Icons.block, color: Colors.red, size: 20);
    }
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _filterLevel != null ||
        _filterSchool != null ||
        _filterClass != null ||
        _filterConcentration != null ||
        _filterRitual != null ||
        (widget.character != null && _availabilityFilter != SpellAvailabilityFilter.all);
  }
}

// ============================================================
// FILTER ENUMS
// ============================================================

enum SpellAvailabilityFilter {
  all,                // Show all spells
  canLearnNow,        // Show only spells available at current level
  availableToClass,   // Show all spells for character's class (current + future)
}