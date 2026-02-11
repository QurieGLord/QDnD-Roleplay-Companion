import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/spell.dart';
import '../../../core/services/feature_service.dart';
import '../../../core/services/spell_service.dart';

class FeaturesStep extends StatefulWidget {
  final Character character;
  final List<CharacterFeature> newFeatures;
  final List<int> newSpellSlots;
  final List<int> oldSpellSlots;
  final VoidCallback onNext;
  final ClassData classData;
  final int nextLevel;
  final int spellsToLearnCount;
  final Function(String featureId, String optionId) onOptionSelected;
  final Function(Set<String> expertSkills) onExpertiseChanged;
  final Function(List<String> spells) onSpellsSelected;

  const FeaturesStep({
    Key? key,
    required this.character,
    required this.newFeatures,
    required this.newSpellSlots,
    required this.oldSpellSlots,
    required this.onNext,
    required this.classData,
    required this.nextLevel,
    required this.spellsToLearnCount,
    required this.onOptionSelected,
    required this.onExpertiseChanged,
    required this.onSpellsSelected,
  }) : super(key: key);

  @override
  State<FeaturesStep> createState() => _FeaturesStepState();
}

class _FeaturesStepState extends State<FeaturesStep> {
  final Map<String, String> _selections = {}; // featureId -> optionId
  final Set<String> _selectedExpertise = {};
  final Set<String> _selectedSpells = {};
  List<Spell> _availableSpells = [];
  bool _spellsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableSpells();
  }

  Future<void> _loadAvailableSpells() async {
    // If no spells to learn according to parent, we might still check if we *should* have them?
    // But usually parent logic prevails.
    if (widget.spellsToLearnCount <= 0) {
      if (mounted) setState(() { _spellsLoaded = true; });
      return;
    }

    final classId = widget.character.characterClass;
    final allClassSpells = SpellService.getSpellsForClass(classId);
    
    // Determine Max Slot Level logic
    int maxSlotLevel = 0;
    if (widget.newSpellSlots.isNotEmpty) {
       for (int i = 0; i < widget.newSpellSlots.length; i++) {
         if (widget.newSpellSlots[i] > 0) maxSlotLevel = i + 1;
       }
    } else {
       // Fallback heuristics
       maxSlotLevel = (widget.nextLevel / 2).ceil();
       if (classId.toLowerCase() == 'paladin' || classId.toLowerCase() == 'ranger') {
          maxSlotLevel = (widget.nextLevel / 2).ceil(); 
       }
       if (classId.toLowerCase() == 'warlock') {
          maxSlotLevel = (widget.nextLevel / 2).ceil(); 
          if (maxSlotLevel > 5) maxSlotLevel = 5;
       }
    }

    final knownIds = widget.character.knownSpells.toSet();
    
    _availableSpells = allClassSpells.where((s) {
      if (knownIds.contains(s.id)) return false;
      if (s.level == 0) return true; 
      return s.level <= maxSlotLevel;
    }).toList();

    _availableSpells.sort((a, b) {
      if (a.level != b.level) return a.level.compareTo(b.level);
      return a.nameEn.compareTo(b.nameEn);
    });

    if (mounted) {
      setState(() {
        _spellsLoaded = true;
      });
    }
  }

  String _getLocalizedSkill(BuildContext context, String skillId) {
    final l10n = AppLocalizations.of(context)!;
    switch (skillId.toLowerCase()) {
      case 'acrobatics': return l10n.skillAcrobatics;
      case 'animal_handling': return l10n.skillAnimalHandling;
      case 'arcana': return l10n.skillArcana;
      case 'athletics': return l10n.skillAthletics;
      case 'deception': return l10n.skillDeception;
      case 'history': return l10n.skillHistory;
      case 'insight': return l10n.skillInsight;
      case 'intimidation': return l10n.skillIntimidation;
      case 'investigation': return l10n.skillInvestigation;
      case 'medicine': return l10n.skillMedicine;
      case 'nature': return l10n.skillNature;
      case 'perception': return l10n.skillPerception;
      case 'performance': return l10n.skillPerformance;
      case 'persuasion': return l10n.skillPersuasion;
      case 'religion': return l10n.skillReligion;
      case 'sleight_of_hand': return l10n.skillSleightOfHand;
      case 'stealth': return l10n.skillStealth;
      case 'survival': return l10n.skillSurvival;
      default: return skillId;
    }
  }

  static const Map<String, String> _styleIdMap = {
    'archery': 'fighting-style-archery',
    'defense': 'fighting-style-defense',
    'dueling': 'fighting-style-dueling',
    'great_weapon': 'fighting-style-great-weapon-fighting',
    'protection': 'fighting-style-protection',
    'two_weapon': 'fighting-style-two-weapon-fighting',
  };

  static const Map<String, List<String>> _classStyles = {
    'fighter': ['archery', 'defense', 'dueling', 'great_weapon', 'protection', 'two_weapon'],
    'paladin': ['defense', 'dueling', 'great_weapon', 'protection'],
    'ranger': ['archery', 'defense', 'dueling', 'two_weapon'],
  };

  List<Map<String, String>> _getFightingStyles(BuildContext context) {
    final classId = widget.classData.id.toLowerCase();
    final availableIds = _classStyles[classId] ?? _classStyles['fighter']!;
    final locale = Localizations.localeOf(context).languageCode;
    final List<Map<String, String>> result = [];

    for (var styleId in availableIds) {
      final featureId = _styleIdMap[styleId];
      if (featureId != null) {
        final feature = FeatureService.getFeatureById(featureId);
        if (feature != null) {
          result.add({
            'id': styleId,
            'name': feature.getName(locale),
            'desc': feature.getDescription(locale),
          });
        } else {
           result.add({'id': styleId, 'name': styleId.toUpperCase(), 'desc': 'Description not found'});
        }
      }
    }
    return result;
  }

  String _getLocalizedSchool(AppLocalizations l10n, String school) {
    switch (school.toLowerCase()) {
      case 'abjuration': return l10n.schoolAbjuration;
      case 'conjuration': return l10n.schoolConjuration;
      case 'divination': return l10n.schoolDivination;
      case 'enchantment': return l10n.schoolEnchantment;
      case 'evocation': return l10n.schoolEvocation;
      case 'illusion': return l10n.schoolIllusion;
      case 'necromancy': return l10n.schoolNecromancy;
      case 'transmutation': return l10n.schoolTransmutation;
      default: return school;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    
    final hasSpellChanges = widget.newSpellSlots.isNotEmpty && 
        (widget.newSpellSlots.length > widget.oldSpellSlots.length || 
         widget.newSpellSlots.asMap().entries.any((e) => e.value > (widget.oldSpellSlots.length > e.key ? widget.oldSpellSlots[e.key] : 0)));

    bool needsFightingStyle = widget.newFeatures.any((f) => f.id.contains('fighting-style'));
    bool needsSubclass = widget.nextLevel == widget.classData.subclassLevel;
    
    bool needsExpertise = false;
    int expertiseCount = 2;
    final classId = widget.classData.id.toLowerCase();
    if (classId == 'bard' || classId == 'бард') {
      if (widget.nextLevel == 3 || widget.nextLevel == 10) needsExpertise = true;
    }
    if (classId == 'rogue' || classId == 'плут') {
      if (widget.nextLevel == 6) needsExpertise = true;
    }

    // Spell Selection Validation
    // Valid if we DON'T need spells OR if we have selected enough
    // IMPORTANT: If we have NO available spells to pick from, we shouldn't block validation.
    bool effectiveNeedsSpells = widget.spellsToLearnCount > 0 && _availableSpells.isNotEmpty;
    bool spellsSatisfied = !effectiveNeedsSpells || _selectedSpells.length == widget.spellsToLearnCount;

    bool allChoicesMade = spellsSatisfied;
    if (needsFightingStyle && !_selections.containsKey('fighting_style')) allChoicesMade = false;
    if (needsSubclass && !_selections.containsKey('subclass')) allChoicesMade = false;
    if (needsExpertise && _selectedExpertise.length != expertiseCount) allChoicesMade = false;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            l10n.newAbilities,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.unlocksAtLevel(widget.nextLevel),
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              children: [
                if (widget.newFeatures.isEmpty && !hasSpellChanges && !needsSubclass && !needsExpertise && !effectiveNeedsSpells)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(l10n.noNewFeaturesAtLevel),
                    ),
                  ),

                // 1. Spell Slots Increase (Top, just informational)
                if (hasSpellChanges) ...[
                  _buildSectionHeader(context, l10n.magic),
                  Card(
                    elevation: 2,
                    color: colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_fix_high, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                l10n.spellSlotsIncreased,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSpellSlotGrid(context, l10n),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. Subclass Selection (Important Choice)
                if (needsSubclass) ...[
                  _buildSectionHeader(context, _getSubclassTitle(l10n, widget.classData.id)),
                  _buildSubclassChoice(context),
                  const SizedBox(height: 16),
                ],
                
                // 3. Fighting Style (Important Choice)
                if (needsFightingStyle) ...[
                   _buildSectionHeader(context, l10n.chooseFightingStyle),
                   // Filter the generic feature out from general list below? 
                   // The general list iterates newFeatures. We handle fighting style specifically.
                   // We'll skip it in the loop below.
                   ...widget.newFeatures.where((f) => f.id.contains('fighting-style')).map((feature) {
                      return _buildFightingStyleChoice(context, feature, l10n);
                   }).toList(),
                   const SizedBox(height: 16),
                ],

                // 4. Expertise (Important Choice)
                if (needsExpertise) ...[
                  _buildSectionHeader(context, l10n.expertise),
                  _buildExpertiseSelection(context, expertiseCount, l10n),
                  const SizedBox(height: 16),
                ],

                // 5. Other Class Features
                if (widget.newFeatures.any((f) => !f.id.contains('fighting-style'))) ...[
                  _buildSectionHeader(context, l10n.classFeatures),
                  ...widget.newFeatures.where((f) => !f.id.contains('fighting-style')).map((feature) {
                    return _buildFeatureCard(context, feature);
                  }).toList(),
                  const SizedBox(height: 16),
                ],

                // 6. Spell Selection (NOW AT THE BOTTOM)
                if (effectiveNeedsSpells) ...[
                  const Divider(), 
                  const SizedBox(height: 16),
                  _buildSectionHeader(context, l10n.spellsStepTitle.toUpperCase()),
                  _buildSpellSelection(context, l10n, locale),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: allChoicesMade ? widget.onNext : null,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(allChoicesMade ? l10n.continueLabel : l10n.makeChoices),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpellSelection(BuildContext context, AppLocalizations l10n, String locale) {
    if (!_spellsLoaded) return const Center(child: CircularProgressIndicator());
    
    // Group spells by level
    final spellsByLevel = <int, List<Spell>>{};
    for (var s in _availableSpells) {
      spellsByLevel.putIfAbsent(s.level, () => []).add(s);
    }
    final levels = spellsByLevel.keys.toList()..sort();
    
    final count = widget.spellsToLearnCount;
    final selectedCount = _selectedSpells.length;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Expanded(
                 child: Text(
                  l10n.chooseSkills(count, ''), // Assuming this string works for generic "Choose X"
                  style: theme.textTheme.bodyMedium,
                 ),
               ),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(
                   color: selectedCount == count ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                   borderRadius: BorderRadius.circular(16),
                 ),
                 child: Text(
                   '$selectedCount / $count',
                   style: TextStyle(
                     fontWeight: FontWeight.bold,
                     color: selectedCount == count ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                   ),
                 ),
               ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Spells List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Nested inside the main ListView
          itemCount: levels.length,
          itemBuilder: (context, index) {
            final level = levels[index];
            final spells = spellsByLevel[level]!;
            
            return ExpansionTile(
              key: PageStorageKey('lvl_$level'),
              title: Text(
                level == 0 ? l10n.cantrips : l10n.levelLabel(level),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              initiallyExpanded: index == levels.length - 1, // Open highest level by default
              shape: const Border(), // Remove borders
              children: spells.map((spell) {
                final isSelected = _selectedSpells.contains(spell.id);
                final canSelect = isSelected || selectedCount < count;
                
                return _buildSpellCard(context, spell, isSelected, canSelect, locale, l10n);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSpellCard(
    BuildContext context, 
    Spell spell, 
    bool isSelected, 
    bool isEnabled, 
    String locale,
    AppLocalizations l10n
  ) {
    final theme = Theme.of(context);
    final cardColor = isEnabled 
        ? (isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest)
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);
    final textColor = isEnabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withOpacity(0.4);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: isSelected ? 2 : 0,
      color: isSelected ? null : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
            ? BorderSide(color: theme.colorScheme.primary, width: 2) 
            : BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: isEnabled ? () {
          setState(() {
            if (isSelected) {
              _selectedSpells.remove(spell.id);
            } else {
              _selectedSpells.add(spell.id);
            }
            widget.onSpellsSelected(_selectedSpells.toList());
          });
        } : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.6,
            child: Row(
              children: [
                 Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.auto_fix_high, 
                      color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spell.getName(locale),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isSelected ? theme.colorScheme.primary : textColor,
                          ),
                        ),
                        Text(
                          _getLocalizedSchool(l10n, spell.school),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: theme.colorScheme.primary)
                  else if (isEnabled)
                     Icon(Icons.add_circle_outline, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... (Existing helpers: _buildExpertiseSelection, _buildSubclassChoice, _buildFightingStyleChoice, _getSubclassTitle, _buildSectionHeader, _getFeatureTypeLabel, _buildFeatureCard, _buildSpellSlotGrid)
  Widget _buildExpertiseSelection(BuildContext context, int count, AppLocalizations l10n) {
    // ... same as before
    final proficientSkills = widget.character.proficientSkills;
    final existingExpertise = widget.character.expertSkills;
    final candidates = proficientSkills.where((s) => !existingExpertise.contains(s)).toList();
    final selectedCount = _selectedExpertise.length;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.expertise} ($selectedCount/$count)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(l10n.chooseSkills(count, ''), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: candidates.map((skillId) {
                final isSelected = _selectedExpertise.contains(skillId);
                final canSelect = isSelected || selectedCount < count;
                return FilterChip(
                  label: Text(_getLocalizedSkill(context, skillId)),
                  selected: isSelected,
                  onSelected: canSelect ? (selected) {
                    setState(() {
                      if (selected) _selectedExpertise.add(skillId);
                      else _selectedExpertise.remove(skillId);
                      widget.onExpertiseChanged(_selectedExpertise);
                    });
                  } : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubclassChoice(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
      children: widget.classData.subclasses.map((subclass) {
        final isSelected = _selections['subclass'] == subclass.id;
        final colorScheme = Theme.of(context).colorScheme;
        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected ? colorScheme.primaryContainer : null,
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              setState(() {
                _selections['subclass'] = subclass.id;
                widget.onOptionSelected('subclass', subclass.id);
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Radio<String>(
                    value: subclass.id,
                    groupValue: _selections['subclass'],
                    onChanged: (value) {
                      setState(() {
                        _selections['subclass'] = value!;
                        widget.onOptionSelected('subclass', value);
                      });
                    },
                    activeColor: colorScheme.primary,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subclass.getName(locale), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface)),
                        const SizedBox(height: 4),
                        Text(subclass.getDescription(locale), style: TextStyle(fontSize: 14, color: isSelected ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8) : colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (isSelected) Padding(padding: const EdgeInsets.only(left: 8.0), child: Icon(Icons.check_circle, color: colorScheme.primary)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFightingStyleChoice(BuildContext context, CharacterFeature feature, AppLocalizations l10n) {
    // ... same as before
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFeatureCard(context, feature),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.only(left: 8.0, bottom: 8.0), child: Text(l10n.chooseFightingStyle, style: const TextStyle(fontWeight: FontWeight.bold))),
        ..._getFightingStyles(context).map((style) {
          final isSelected = _selections['fighting_style'] == style['id'];
          return Card(
            elevation: isSelected ? 4 : 1,
            color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
            margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
            child: RadioListTile<String>(
              value: style['id']!,
              groupValue: _selections['fighting_style'],
              onChanged: (value) {
                setState(() {
                  _selections['fighting_style'] = value!;
                  widget.onOptionSelected('fighting_style', value);
                });
              },
              title: Text(style['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(style['desc']!),
              secondary: Icon(Icons.sports_martial_arts),
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
      ],
    );
  }

  String _getSubclassTitle(AppLocalizations l10n, String classId) {
    switch (classId.toLowerCase()) {
      case 'barbarian': case 'варвар': return l10n.primalPath;
      case 'bard': case 'бард': return l10n.bardCollege;
      case 'cleric': case 'жрец': return l10n.divineDomain;
      case 'druid': case 'друид': return l10n.druidCircle;
      case 'fighter': case 'воин': return l10n.martialArchetype;
      case 'monk': case 'монах': return l10n.monasticTradition;
      case 'paladin': case 'паладин': return l10n.sacredOath;
      case 'ranger': case 'следопыт': return l10n.rangerArchetype;
      case 'rogue': case 'плут': return l10n.roguishArchetype;
      case 'sorcerer': case 'чародей': return l10n.sorcerousOrigin;
      case 'warlock': case 'колдун': return l10n.otherworldlyPatron;
      case 'wizard': case 'волшебник': return l10n.arcaneTradition;
      default: return l10n.selectSubclass;
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary, letterSpacing: 1.0)),
    );
  }

  String _getFeatureTypeLabel(AppLocalizations l10n, FeatureType type) {
    switch (type) {
      case FeatureType.passive: return l10n.featureTypePassive;
      case FeatureType.action: return l10n.featureTypeAction;
      case FeatureType.bonusAction: return l10n.featureTypeBonusAction;
      case FeatureType.reaction: return l10n.featureTypeReaction;
      default: return l10n.featureTypeOther;
    }
  }

  Widget _buildFeatureCard(BuildContext context, CharacterFeature feature) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    IconData icon = Icons.star;
    if (feature.iconName != null) {
       switch(feature.iconName) {
         case 'healing': icon = Icons.favorite; break;
         case 'visibility': icon = Icons.visibility; break;
         case 'flash_on': icon = Icons.flash_on; break;
         case 'swords': icon = Icons.shield; break;
         case 'auto_fix_high': icon = Icons.auto_fix_high; break;
         case 'health_and_safety': icon = Icons.health_and_safety; break;
         case 'auto_awesome': icon = Icons.auto_awesome; break;
       }
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(feature.getName(locale), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(_getFeatureTypeLabel(l10n, feature.type).toUpperCase(), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline))]))]),
            const SizedBox(height: 12),
            Text(feature.getDescription(locale)),
          ],
        ),
      ),
    );
  }

  Widget _buildSpellSlotGrid(BuildContext context, AppLocalizations l10n) {
    List<Widget> levelRows = [];
    for (int i = 0; i < widget.newSpellSlots.length; i++) {
      int level = i + 1;
      int newCount = widget.newSpellSlots[i];
      int oldCount = i < widget.oldSpellSlots.length ? widget.oldSpellSlots[i] : 0;
      if (newCount > oldCount) {
        levelRows.add(Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(children: [SizedBox(width: 50, child: Text(l10n.lvlShort(level), style: const TextStyle(fontWeight: FontWeight.bold))), const SizedBox(width: 16), ...List.generate(oldCount, (_) => const Padding(padding: EdgeInsets.symmetric(horizontal: 2.0), child: Icon(Icons.circle, size: 16, color: Colors.grey))), if (oldCount > 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey)), ...List.generate(newCount - oldCount, (_) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2.0), child: Icon(Icons.circle, size: 16, color: Theme.of(context).colorScheme.primary)))])));
      }
    }
    return Column(children: levelRows);
  }
}
