import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/spell.dart';
import '../../core/models/character.dart';
import '../../core/services/spell_service.dart';
import '../../core/services/spell_eligibility_service.dart';
import '../../core/utils/spell_utils.dart';
import '../../shared/widgets/spell_details_sheet.dart';

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

  void _showSpellDetails(Spell spell) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SpellDetailsSheet(
        spell: spell,
        character: widget.character,
        onToggleKnown: () => _toggleKnownSpell(spell, AppLocalizations.of(context)!),
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
        widget.character!.preparedSpells.remove(spell.id);
      } else {
        widget.character!.knownSpells.add(spell.id);
      }
    });

    await widget.character!.save();

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

  Widget _buildEligibilityIcon(SpellEligibilityResult eligibility) {
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
                            label: Text(SpellUtils.getLocalizedClassName(context, className)),
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
                            label: Text(SpellUtils.getLocalizedSchool(l10n, school)),
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
                                    color: SpellUtils.getSchoolColor(spell.school, colorScheme),
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
                                    Expanded(child: Text(SpellUtils.getLocalizedSchool(l10n, spell.school))),
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
}

enum SpellAvailabilityFilter {
  all,
  canLearnNow,
  availableToClass,
}