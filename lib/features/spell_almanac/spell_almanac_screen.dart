import 'package:flutter/material.dart';
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

  List<Spell> _getFilteredSpells() {
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
        return spell.nameEn.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            spell.nameRu.toLowerCase().contains(_searchQuery.toLowerCase());
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
                            spell.nameEn,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${spell.school}${spell.level == 0 ? ' Cantrip' : ' • Level ${spell.level}'}',
                            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Eligibility badge (if character provided)
                if (eligibility != null) ...[
                  const SizedBox(height: 16),
                  _buildEligibilityBadge(eligibility),
                ],

                const SizedBox(height: 24),

                // Stats
                _buildInfoRow('Casting Time', spell.castingTime),
                _buildInfoRow('Range', spell.range),
                _buildInfoRow('Duration', spell.duration),
                _buildInfoRow('Components', spell.components.join(', ')),
                if (spell.materialComponents != null)
                  _buildInfoRow('Materials', spell.materialComponents!),
                if (spell.concentration || spell.ritual)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (spell.concentration)
                          const Chip(
                            label: Text('Concentration'),
                            avatar: Icon(Icons.timelapse, size: 16),
                          ),
                        if (spell.ritual)
                          const Chip(
                            label: Text('Ritual'),
                            avatar: Icon(Icons.book, size: 16),
                          ),
                      ],
                    ),
                  ),

                const Divider(height: 32),

                // Description
                Text(
                  spell.descriptionEn,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),

                if (spell.atHigherLevels != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'At Higher Levels',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    spell.atHigherLevels!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],

                const SizedBox(height: 16),
                Text(
                  'Classes: ${spell.availableToClasses.join(', ')}',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),

                // Add/Remove from Known Spells button (if character provided and eligible)
                if (widget.character != null && eligibility != null && eligibility.canLearn) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        _toggleKnownSpell(spell);
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        widget.character!.knownSpells.contains(spell.id)
                            ? Icons.remove_circle_outline
                            : Icons.add_circle_outline,
                      ),
                      label: Text(
                        widget.character!.knownSpells.contains(spell.id)
                            ? 'Remove from Known Spells'
                            : 'Add to Known Spells',
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

  void _toggleKnownSpell(Spell spell) async {
    if (widget.character == null) return;

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
                ? 'Removed "${spell.nameEn}" from known spells'
                : 'Added "${spell.nameEn}" to known spells',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildEligibilityBadge(SpellEligibilityResult eligibility) {
    final colorScheme = Theme.of(context).colorScheme;

    if (eligibility.canLearn) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 8),
            Text('Available to Learn', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else if (eligibility.canLearnAtLevel != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock, color: Colors.orange, size: 16),
            const SizedBox(width: 8),
            Text(
              'Available at Level ${eligibility.canLearnAtLevel}',
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.5),
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
                eligibility.reason,
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

  void _showFilters() {
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
                    Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),

                    // Availability filter (if character provided)
                    if (widget.character != null) ...[
                      Text('Availability for ${widget.character!.name}', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('All Spells'),
                            selected: _availabilityFilter == SpellAvailabilityFilter.all,
                            onSelected: (selected) {
                              setModalState(() => _availabilityFilter = SpellAvailabilityFilter.all);
                              setState(() => _availabilityFilter = SpellAvailabilityFilter.all);
                            },
                          ),
                          FilterChip(
                            label: const Text('Can Learn Now'),
                            selected: _availabilityFilter == SpellAvailabilityFilter.canLearnNow,
                            onSelected: (selected) {
                              setModalState(() => _availabilityFilter = SpellAvailabilityFilter.canLearnNow);
                              setState(() => _availabilityFilter = SpellAvailabilityFilter.canLearnNow);
                            },
                          ),
                          FilterChip(
                            label: const Text('Available to Class'),
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
                    Text('Class', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All Classes'),
                          selected: _filterClass == null,
                          onSelected: (selected) {
                            setModalState(() => _filterClass = null);
                            setState(() => _filterClass = null);
                          },
                        ),
                        ...allClasses.map((className) {
                          return FilterChip(
                            label: Text(className),
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
                    Text('Level', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All Levels'),
                          selected: _filterLevel == null,
                          onSelected: (selected) {
                            setModalState(() => _filterLevel = null);
                            setState(() => _filterLevel = null);
                          },
                        ),
                        ...List.generate(10, (i) {
                          return FilterChip(
                            label: Text(i == 0 ? 'Cantrips' : 'Level $i'),
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
                    Text('School', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All Schools'),
                          selected: _filterSchool == null,
                          onSelected: (selected) {
                            setModalState(() => _filterSchool = null);
                            setState(() => _filterSchool = null);
                          },
                        ),
                        ...allSchools.map((school) {
                          return FilterChip(
                            label: Text(school),
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
                            title: const Text('Concentration'),
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
                            title: const Text('Ritual'),
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
                          child: const Text('Clear All'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Apply'),
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
    final filteredSpells = _getFilteredSpells();
    final groupedSpells = _groupSpellsByLevel(filteredSpells);
    final sortedLevels = groupedSpells.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.character != null ? 'Spell Almanac - ${widget.character!.name}' : 'Spell Almanac'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
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
                hintText: 'Search spells...',
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
                  '${filteredSpells.length} spell${filteredSpells.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
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
                    label: const Text('Clear filters'),
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
                        Icon(Icons.search_off, size: 64, color: colorScheme.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('No spells found', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Try adjusting your filters', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
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
                                    level == 0 ? 'CANTRIPS' : 'LEVEL $level',
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
                                  '${spells.length} spell${spells.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
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
                                title: Text(spell.nameEn),
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
                                    Expanded(child: Text(spell.school)),
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
