import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/spell.dart';
import '../../../core/constants/ranger_options.dart';
import '../../../ui/widgets/expressive_choice_selector.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../core/services/feature_service.dart';
import '../../../core/services/spell_service.dart';

class FeaturesStep extends StatefulWidget {
  final Character character;
  final List<CharacterFeature> newFeatures;
  final List<CharacterFeature> landOptions;
  final List<int> newSpellSlots;
  final List<int> oldSpellSlots;
  final VoidCallback onNext;
  final ClassData classData;
  final int nextLevel;
  final int spellsToLearnCount;
  final Function(String featureId, String optionId) onOptionSelected;
  final Function(Set<String> expertSkills) onExpertiseChanged;
  final Function(List<String> spells) onSpellsSelected;
  final Function(List<String> spells) onMasterySpellsSelected;
  final Function(List<String> spells) onSignatureSpellsSelected;

  const FeaturesStep({
    super.key,
    required this.character,
    required this.newFeatures,
    this.landOptions = const [],
    required this.newSpellSlots,
    required this.oldSpellSlots,
    required this.onNext,
    required this.classData,
    required this.nextLevel,
    required this.spellsToLearnCount,
    required this.onOptionSelected,
    required this.onExpertiseChanged,
    required this.onSpellsSelected,
    required this.onMasterySpellsSelected,
    required this.onSignatureSpellsSelected,
  });

  @override
  State<FeaturesStep> createState() => _FeaturesStepState();
}

class _FeaturesStepState extends State<FeaturesStep> {
  final Map<String, String> _selections = {}; // featureId -> string ID
  final Set<String> _selectedExpertise = {};
  final Set<String> _selectedSpells = {};
  final Set<String> _selectedMasterySpells = {};
  final Set<String> _selectedSignatureSpells = {};

  List<Spell> _availableSpells = [];
  List<Spell> _masteryOptionsLvl1 = [];
  List<Spell> _masteryOptionsLvl2 = [];
  List<Spell> _signatureOptions = [];

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
      if (mounted) {
        setState(() {
          _spellsLoaded = true;
        });
      }
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
      if (classId.toLowerCase() == 'paladin' ||
          classId.toLowerCase() == 'ranger') {
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

    // Populate Wizard High Level Features Options
    final classIdLower = classId.toLowerCase();
    if (classIdLower == 'wizard' || classIdLower == 'волшебник') {
      final knownWizardSpells =
          allClassSpells.where((s) => knownIds.contains(s.id)).toList();

      _masteryOptionsLvl1 =
          knownWizardSpells.where((s) => s.level == 1).toList();
      _masteryOptionsLvl2 =
          knownWizardSpells.where((s) => s.level == 2).toList();
      _signatureOptions = knownWizardSpells.where((s) => s.level == 3).toList();
    }

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
      case 'acrobatics':
        return l10n.skillAcrobatics;
      case 'animal_handling':
        return l10n.skillAnimalHandling;
      case 'arcana':
        return l10n.skillArcana;
      case 'athletics':
        return l10n.skillAthletics;
      case 'deception':
        return l10n.skillDeception;
      case 'history':
        return l10n.skillHistory;
      case 'insight':
        return l10n.skillInsight;
      case 'intimidation':
        return l10n.skillIntimidation;
      case 'investigation':
        return l10n.skillInvestigation;
      case 'medicine':
        return l10n.skillMedicine;
      case 'nature':
        return l10n.skillNature;
      case 'perception':
        return l10n.skillPerception;
      case 'performance':
        return l10n.skillPerformance;
      case 'persuasion':
        return l10n.skillPersuasion;
      case 'religion':
        return l10n.skillReligion;
      case 'sleight_of_hand':
        return l10n.skillSleightOfHand;
      case 'stealth':
        return l10n.skillStealth;
      case 'survival':
        return l10n.skillSurvival;
      default:
        return skillId;
    }
  }

  static const Map<String, List<String>> _classStyles = {
    'fighter': [
      'archery',
      'defense',
      'dueling',
      'great_weapon',
      'protection',
      'two_weapon'
    ],
    'paladin': ['defense', 'dueling', 'great_weapon', 'protection'],
    'ranger': ['archery', 'defense', 'dueling', 'two_weapon'],
  };

  List<Map<String, String>> _getFightingStyles(BuildContext context) {
    final classId = widget.classData.id.toLowerCase();
    final availableIds = _classStyles[classId] ?? _classStyles['fighter']!;
    final l10n = AppLocalizations.of(context)!;
    final List<Map<String, String>> result = [];

    for (var styleId in availableIds) {
      final localized =
          LocalizationHelper.getLocalizedFightingStyle(styleId, l10n);
      result.add({
        'id': styleId,
        'name': localized.name,
        'desc': localized.description,
      });
    }
    return result;
  }

  String _getLocalizedSchool(AppLocalizations l10n, String school) {
    switch (school.toLowerCase()) {
      case 'abjuration':
        return l10n.schoolAbjuration;
      case 'conjuration':
        return l10n.schoolConjuration;
      case 'divination':
        return l10n.schoolDivination;
      case 'enchantment':
        return l10n.schoolEnchantment;
      case 'evocation':
        return l10n.schoolEvocation;
      case 'illusion':
        return l10n.schoolIllusion;
      case 'necromancy':
        return l10n.schoolNecromancy;
      case 'transmutation':
        return l10n.schoolTransmutation;
      default:
        return school;
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
            widget.newSpellSlots.asMap().entries.any((e) =>
                e.value >
                (widget.oldSpellSlots.length > e.key
                    ? widget.oldSpellSlots[e.key]
                    : 0)));

    bool needsFightingStyle =
        widget.newFeatures.any((f) => f.id.contains('fighting-style'));
    bool needsSubclass = widget.nextLevel == widget.classData.subclassLevel;
    if (widget.classData.id.toLowerCase() == 'ranger' ||
        widget.classData.id.toLowerCase() == 'sleDopyt' ||
        widget.classData.id.toLowerCase() == 'следопыт') {
      needsSubclass = widget.nextLevel == 3;
    }
    bool needsLandChoice = widget.landOptions.isNotEmpty;

    bool needsExpertise = false;
    int expertiseCount = 2;
    final classId = widget.classData.id.toLowerCase();
    if (classId == 'bard' || classId == 'бард') {
      if (widget.nextLevel == 3 || widget.nextLevel == 10) {
        needsExpertise = true;
      }
    }
    if (classId == 'rogue' || classId == 'плут') {
      if (widget.nextLevel == 6) needsExpertise = true;
    }

    // Warlock Pact Boon (Level 3)
    bool needsPactBoon =
        (classId == 'warlock' || classId == 'колдун') && widget.nextLevel == 3;

    // Wizard Spell Mastery (Level 18)
    bool needsSpellMastery = (classId == 'wizard' || classId == 'волшебник') &&
        widget.nextLevel == 18;

    // Wizard Signature Spells (Level 20)
    bool needsSignatureSpells =
        (classId == 'wizard' || classId == 'волшебник') &&
            widget.nextLevel == 20;

    // Ranger Features (Levels 6, 10, 14)
    bool needsFavoredEnemy = (classId == 'ranger' || classId == 'следопыт') &&
        (widget.nextLevel == 6 || widget.nextLevel == 14);
    bool needsNaturalExplorer =
        (classId == 'ranger' || classId == 'следопыт') &&
            (widget.nextLevel == 6 || widget.nextLevel == 10);

    // Ranger Hunter Tactic (Level 3, 7, 11, 15)
    bool isHunter = widget.character.subclass?.toLowerCase() == 'hunter' ||
        _selections['subclass'] == 'hunter';
    bool needsHunterTactic = (classId == 'ranger' || classId == 'следопыт') &&
        isHunter &&
        [3, 7, 11, 15].contains(widget.nextLevel);

    // Spell Selection Validation
    // Valid if we DON'T need spells OR if we have selected enough
    // IMPORTANT: If we have NO available spells to pick from, we shouldn't block validation.
    bool effectiveNeedsSpells =
        widget.spellsToLearnCount > 0 && _availableSpells.isNotEmpty;
    bool spellsSatisfied = !effectiveNeedsSpells ||
        _selectedSpells.length == widget.spellsToLearnCount;

    bool allChoicesMade = spellsSatisfied;
    if (needsFightingStyle && !_selections.containsKey('fighting_style')) {
      allChoicesMade = false;
    }
    if (needsSubclass && !_selections.containsKey('subclass')) {
      allChoicesMade = false;
    }
    if (needsExpertise && _selectedExpertise.length != expertiseCount) {
      allChoicesMade = false;
    }
    if (needsPactBoon && !_selections.containsKey('pact_boon')) {
      allChoicesMade = false;
    }
    if (needsLandChoice && !_selections.containsKey('land_terrain')) {
      allChoicesMade = false;
    }
    if (needsFavoredEnemy && !_selections.containsKey('favored_enemy')) {
      allChoicesMade = false;
    }
    if (needsNaturalExplorer && !_selections.containsKey('natural_explorer')) {
      allChoicesMade = false;
    }
    if (needsHunterTactic && !_selections.containsKey('hunter_tactic')) {
      allChoicesMade = false;
    }

    // Spell Mastery Validation: Exactly 1 from Level 1 and 1 from Level 2
    if (needsSpellMastery) {
      final selectedLvl1 = _selectedMasterySpells
          .where((id) => _masteryOptionsLvl1.any((s) => s.id == id))
          .length;
      final selectedLvl2 = _selectedMasterySpells
          .where((id) => _masteryOptionsLvl2.any((s) => s.id == id))
          .length;
      if (selectedLvl1 != 1 || selectedLvl2 != 1) {
        allChoicesMade = false;
      }
    }

    // Signature Spells Validation: Exactly 2 from Level 3
    if (needsSignatureSpells) {
      if (_selectedSignatureSpells.length != 2) {
        allChoicesMade = false;
      }
    }

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
                if (widget.newFeatures.isEmpty &&
                    !hasSpellChanges &&
                    !needsSubclass &&
                    !needsExpertise &&
                    !needsPactBoon &&
                    !needsLandChoice &&
                    !effectiveNeedsSpells)
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
                              Icon(Icons.auto_fix_high,
                                  color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                l10n.spellSlotsIncreased,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
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
                  _buildSectionHeader(
                      context, _getSubclassTitle(l10n, widget.classData.id)),
                  _buildSubclassChoice(context),
                  const SizedBox(height: 16),
                ],

                // 2.5 Land Choice (Circle of the Land)
                if (needsLandChoice) ...[
                  _buildSectionHeader(
                      context,
                      locale == 'ru'
                          ? 'КРУГ ЗЕМЛИ: МЕСТНОСТЬ'
                          : 'CIRCLE OF THE LAND: TERRAIN'),
                  _buildLandChoice(context, locale),
                  const SizedBox(height: 16),
                ],

                // 3. Fighting Style (Important Choice)
                if (needsFightingStyle) ...[
                  _buildSectionHeader(context, l10n.chooseFightingStyle),
                  // Filter the generic feature out from general list below?
                  // The general list iterates newFeatures. We handle fighting style specifically.
                  // We'll skip it in the loop below.
                  ...widget.newFeatures
                      .where((f) => f.id.contains('fighting-style'))
                      .map((feature) {
                    return _buildFightingStyleChoice(context, feature, l10n);
                  }),
                  const SizedBox(height: 16),
                ],

                // 3.5 Pact Boon (Important Choice)
                if (needsPactBoon) ...[
                  _buildSectionHeader(context,
                      locale == 'ru' ? "ПРЕДМЕТ ДОГОВОРА" : "PACT BOON"),
                  _buildPactBoonChoice(context, locale),
                  const SizedBox(height: 16),
                ],

                // 3.6 Wizard Spell Mastery (Level 18)
                if (needsSpellMastery) ...[
                  _buildSectionHeader(
                      context,
                      locale == 'ru'
                          ? "ЗАКЛИНАТЕЛЬНОЕ МАСТЕРСТВО"
                          : "SPELL MASTERY"),
                  _buildSpellMasterySelection(context, locale, l10n),
                  const SizedBox(height: 16),
                ],

                // 3.7 Wizard Signature Spells (Level 20)
                if (needsSignatureSpells) ...[
                  _buildSectionHeader(
                      context,
                      locale == 'ru'
                          ? "ФИРМЕННЫЕ ЗАКЛИНАНИЯ"
                          : "SIGNATURE SPELLS"),
                  _buildSignatureSpellsSelection(context, locale, l10n),
                  const SizedBox(height: 16),
                ],

                // 3.8 Ranger Favored Enemy
                if (needsFavoredEnemy) ...[
                  _buildSectionHeader(context,
                      locale == 'ru' ? "ИЗБРАННЫЙ ВРАГ" : "FAVORED ENEMY"),
                  _buildFavoredEnemyChoice(context, locale, l10n),
                  const SizedBox(height: 16),
                ],

                // 3.9 Ranger Natural Explorer
                if (needsNaturalExplorer) ...[
                  _buildSectionHeader(
                      context,
                      locale == 'ru'
                          ? "ИССЛЕДОВАТЕЛЬ ПРИРОДЫ"
                          : "NATURAL EXPLORER"),
                  _buildNaturalExplorerChoice(context, locale, l10n),
                  const SizedBox(height: 16),
                ],

                // 3.10 Ranger Hunter Tactic
                if (needsHunterTactic) ...[
                  _buildSectionHeader(context,
                      locale == 'ru' ? "ТАКТИКА ОХОТНИКА" : "HUNTER'S PREY"),
                  _buildHunterTacticChoice(context, locale, l10n),
                  const SizedBox(height: 16),
                ],

                // 4. Expertise (Important Choice)
                if (needsExpertise) ...[
                  _buildSectionHeader(context, l10n.expertise),
                  _buildExpertiseSelection(context, expertiseCount, l10n),
                  const SizedBox(height: 16),
                ],

                // 5. Other Class Features
                if (widget.newFeatures.any((f) {
                  if (f.id.contains('fighting-style') ||
                      f.id.contains('pact-boon')) {
                    return false;
                  }
                  final safeId = f.id.toLowerCase().replaceAll('_', '-');
                  final tactics = [
                    'colossus-slayer',
                    'giant-killer',
                    'horde-breaker',
                    'escape-the-horde',
                    'multiattack-defense',
                    'steel-will',
                    'volley',
                    'whirlwind-attack',
                    'evasion',
                    'stand-against-the-tide',
                    'uncanny-dodge'
                  ];
                  if (tactics.contains(safeId) ||
                      tactics.any((t) => safeId.contains(t))) {
                    return false;
                  }
                  return true;
                })) ...[
                  _buildSectionHeader(context, l10n.classFeatures),
                  ...widget.newFeatures.where((f) {
                    if (f.id.contains('fighting-style') ||
                        f.id.contains('pact-boon')) {
                      return false;
                    }
                    final safeId = f.id.toLowerCase().replaceAll('_', '-');
                    final tactics = [
                      'colossus-slayer',
                      'giant-killer',
                      'horde-breaker',
                      'escape-the-horde',
                      'multiattack-defense',
                      'steel-will',
                      'volley',
                      'whirlwind-attack',
                      'evasion',
                      'stand-against-the-tide',
                      'uncanny-dodge'
                    ];
                    if (tactics.contains(safeId) ||
                        tactics.any((t) => safeId.contains(t))) {
                      return false;
                    }
                    return true;
                  }).map((feature) {
                    return _buildFeatureCard(context, feature);
                  }),
                  const SizedBox(height: 16),
                ],

                // 6. Spell Selection (NOW AT THE BOTTOM)
                if (effectiveNeedsSpells) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildSectionHeader(
                      context, l10n.spellsStepTitle.toUpperCase()),
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
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child:
                  Text(allChoicesMade ? l10n.continueLabel : l10n.makeChoices),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpellSelection(
      BuildContext context, AppLocalizations l10n, String locale) {
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
                  l10n.chooseSkills(count,
                      ''), // Assuming this string works for generic "Choose X"
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selectedCount == count
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$selectedCount / $count',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selectedCount == count
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
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
          physics:
              const NeverScrollableScrollPhysics(), // Nested inside the main ListView
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
              initiallyExpanded:
                  index == levels.length - 1, // Open highest level by default
              shape: const Border(), // Remove borders
              children: spells.map((spell) {
                final isSelected = _selectedSpells.contains(spell.id);
                final canSelect = isSelected || selectedCount < count;

                return _buildSpellCard(
                    context, spell, isSelected, canSelect, locale, l10n);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSpellCard(BuildContext context, Spell spell, bool isSelected,
      bool isEnabled, String locale, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final cardColor = isEnabled
        ? (isSelected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final textColor = isEnabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: isSelected ? 2 : 0,
      color: isSelected ? null : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: isEnabled
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedSpells.remove(spell.id);
                  } else {
                    _selectedSpells.add(spell.id);
                  }
                  widget.onSpellsSelected(_selectedSpells.toList());
                });
              }
            : null,
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
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
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
                          color: isSelected
                              ? theme.colorScheme.primary
                              : textColor,
                        ),
                      ),
                      Text(
                        _getLocalizedSchool(l10n, spell.school),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: theme.colorScheme.primary)
                else if (isEnabled)
                  Icon(Icons.add_circle_outline,
                      color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... (Existing helpers: _buildExpertiseSelection, _buildSubclassChoice, _buildFightingStyleChoice, _getSubclassTitle, _buildSectionHeader, _getFeatureTypeLabel, _buildFeatureCard, _buildSpellSlotGrid)
  Widget _buildExpertiseSelection(
      BuildContext context, int count, AppLocalizations l10n) {
    // ... same as before
    final proficientSkills = widget.character.proficientSkills;
    final existingExpertise = widget.character.expertSkills;
    final candidates =
        proficientSkills.where((s) => !existingExpertise.contains(s)).toList();
    final selectedCount = _selectedExpertise.length;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.expertise} ($selectedCount/$count)',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(l10n.chooseSkills(count, ''),
                style: Theme.of(context).textTheme.bodySmall),
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
                  onSelected: canSelect
                      ? (selected) {
                          setState(() {
                            if (selected) {
                              _selectedExpertise.add(skillId);
                            } else {
                              _selectedExpertise.remove(skillId);
                            }
                            widget.onExpertiseChanged(_selectedExpertise);
                          });
                        }
                      : null,
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
      children: [
        RadioGroup<String>(
          groupValue: _selections['subclass'] ?? '',
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selections['subclass'] = value;
              widget.onOptionSelected('subclass', value);
            });
          },
          child: Column(
            children: widget.classData.subclasses.map((subclass) {
              final isSelected = _selections['subclass'] == subclass.id;
              final colorScheme = Theme.of(context).colorScheme;
              return Card(
                elevation: isSelected ? 4 : 1,
                color: isSelected ? colorScheme.primaryContainer : null,
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    // Handled by RadioGroup, but InkWell can still provide visual feedback
                    // or if RadioGroup is not used, this would be the selection logic.
                    // For RadioGroup, the RadioListTile's onChanged handles it.
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Radio<String>(
                          value: subclass.id,
                          activeColor: colorScheme.primary,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(subclass.getName(locale),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isSelected
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurface)),
                              const SizedBox(height: 4),
                              Text(subclass.getDescription(locale),
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected
                                          ? colorScheme.onPrimaryContainer
                                              .withValues(alpha: 0.8)
                                          : colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.check_circle,
                                  color: colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFightingStyleChoice(
      BuildContext context, CharacterFeature feature, AppLocalizations l10n) {
    // ... same as before

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFeatureCard(context, feature),
        const SizedBox(height: 8),
        Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(l10n.chooseFightingStyle,
                style: const TextStyle(fontWeight: FontWeight.bold))),
        RadioGroup<String>(
          groupValue: _selections['fighting_style'] ?? '',
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selections['fighting_style'] = value;
              widget.onOptionSelected('fighting_style', value);
            });
          },
          child: Column(
              children: _getFightingStyles(context).map((style) {
            final isSelected = _selections['fighting_style'] == style['id'];
            return Card(
              elevation: isSelected ? 4 : 1,
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
              child: RadioListTile<String>(
                value: style['id']!,
                title: Text(style['name']!,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(style['desc']!),
                secondary: const Icon(Icons.sports_martial_arts),
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPactBoonChoice(BuildContext context, String locale) {
    final boons = [
      {
        'id': 'pact_of_the_blade',
        'nameEn': 'Pact of the Blade',
        'nameRu': 'Договор клинка',
        'descEn':
            'You can use your action to create a pact weapon in your empty hand.',
        'descRu':
            'Вы можете использовать действие, чтобы создать пакт-оружие в своей пустой руке.',
        'icon': Icons.shield_outlined,
      },
      {
        'id': 'pact_of_the_chain',
        'nameEn': 'Pact of the Chain',
        'nameRu': 'Договор цепи',
        'descEn':
            'You learn the find familiar spell and can cast it as a ritual.',
        'descRu':
            'Вы изучаете заклинание поиск фамильяра и можете накладывать его как ритуал.',
        'icon': Icons.link,
      },
      {
        'id': 'pact_of_the_tome',
        'nameEn': 'Pact of the Tome',
        'nameRu': 'Договор гримуара',
        'descEn': 'Your patron gives you a grimoire called a Book of Shadows.',
        'descRu':
            'Ваш покровитель дарует вам гримуар, называемый Книгой Теней.',
        'icon': Icons.menu_book,
      },
      {
        'id': 'pact_of_the_talisman',
        'nameEn': 'Pact of the Talisman',
        'nameRu': 'Договор талисмана',
        'descEn':
            'Your patron gives you an amulet, a talisman that can aid the wearer.',
        'descRu':
            'Ваш покровитель дает вам амулет, талисман, который может помочь владельцу.',
        'icon': Icons.workspace_premium,
      },
    ];

    return Column(
      children: [
        RadioGroup<String>(
          groupValue: _selections['pact_boon'] ?? '',
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selections['pact_boon'] = value;
              widget.onOptionSelected('pact_boon', value);
            });
          },
          child: Column(
              children: boons.map((boon) {
            final id = boon['id'] as String;
            final name = locale == 'ru'
                ? boon['nameRu'] as String
                : boon['nameEn'] as String;
            final desc = locale == 'ru'
                ? boon['descRu'] as String
                : boon['descEn'] as String;
            final icon = boon['icon'] as IconData;
            final isSelected = _selections['pact_boon'] == id;
            final colorScheme = Theme.of(context).colorScheme;

            return Card(
              elevation: isSelected ? 4 : 1,
              color: isSelected ? colorScheme.primaryContainer : null,
              margin: const EdgeInsets.only(bottom: 8),
              child: RadioListTile<String>(
                value: id,
                title: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(desc),
                secondary:
                    Icon(icon, color: isSelected ? colorScheme.primary : null),
                activeColor: colorScheme.primary,
              ),
            );
          }).toList()),
        )
      ],
    );
  }

  Widget _buildLandChoice(BuildContext context, String locale) {
    return Column(
      children: [
        RadioGroup<String>(
          groupValue: _selections['land_terrain'] ?? '',
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selections['land_terrain'] = value;
              widget.onOptionSelected('land_terrain', value);
            });
          },
          child: Column(
              children: widget.landOptions.map((feature) {
            final isSelected = _selections['land_terrain'] == feature.id;
            final colorScheme = Theme.of(context).colorScheme;

            return Card(
              elevation: isSelected ? 4 : 1,
              color: isSelected ? colorScheme.primaryContainer : null,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Radio<String>(
                      value: feature.id,
                      activeColor: colorScheme.primary,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(feature.getName(locale),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isSelected
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurface)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList()),
        )
      ],
    );
  }

  Widget _buildFavoredEnemyChoice(
      BuildContext context, String locale, AppLocalizations l10n) {
    final feature = FeatureService.getFeatureById('favored-enemy') ??
        CharacterFeature(
            id: 'favored-enemy',
            nameEn: 'Favored Enemy',
            nameRu: 'Избранный враг',
            descriptionEn: 'Choose a type of favored enemy.',
            descriptionRu: 'Выберите тип избранного врага.',
            type: FeatureType.passive,
            minLevel: 1);

    final existingEnemies = widget.character.favoredEnemies;
    final availableEnemies = RangerOptions.favoredEnemies.entries
        .where((e) => !existingEnemies.contains(e.key))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFeatureCard(context, feature),
        const SizedBox(height: 8),
        ExpressiveChoiceSelector<String>(
          value: _selections['favored_enemy'],
          items: availableEnemies.map((e) => e.key).toList(),
          placeholder: l10n.choose,
          title: feature.getName(locale),
          labelBuilder: (key) {
            return locale == 'ru'
                ? RangerOptions.favoredEnemies[key]!['ru']!
                : RangerOptions.favoredEnemies[key]!['en']!;
          },
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selections['favored_enemy'] = value;
                widget.onOptionSelected('favored_enemy', value);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildNaturalExplorerChoice(
      BuildContext context, String locale, AppLocalizations l10n) {
    final feature = FeatureService.getFeatureById('natural-explorer') ??
        CharacterFeature(
            id: 'natural-explorer',
            nameEn: 'Natural Explorer',
            nameRu: 'Исследователь природы',
            descriptionEn: 'Choose a terrain type.',
            descriptionRu: 'Выберите тип местности.',
            type: FeatureType.passive,
            minLevel: 1);

    final existingTerrains = widget.character.naturalExplorers;
    final availableTerrains = RangerOptions.naturalExplorers.entries
        .where((e) => !existingTerrains.contains(e.key))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFeatureCard(context, feature),
        const SizedBox(height: 8),
        ExpressiveChoiceSelector<String>(
          value: _selections['natural_explorer'],
          items: availableTerrains.map((e) => e.key).toList(),
          placeholder: l10n.choose,
          title: feature.getName(locale),
          labelBuilder: (key) {
            return locale == 'ru'
                ? RangerOptions.naturalExplorers[key]!['ru']!
                : RangerOptions.naturalExplorers[key]!['en']!;
          },
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selections['natural_explorer'] = value;
                widget.onOptionSelected('natural_explorer', value);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildHunterTacticChoice(
      BuildContext context, String locale, AppLocalizations l10n) {
    List<Map<String, String>> tactics = [];
    if (widget.nextLevel == 3) {
      tactics = [
        {
          'id': 'colossus-slayer',
          'en': 'Colossus Slayer',
          'ru': 'Убийца колоссов',
          'descEn': 'Your tenacity can wear down the most potent foes.',
          'descRu': 'Ваше упорство может измотать самых сильных врагов.'
        },
        {
          'id': 'giant-killer',
          'en': 'Giant Killer',
          'ru': 'Убийца великанов',
          'descEn':
              'When a Large or larger creature hits or misses you with a melee attack...',
          'descRu':
              'Когда существо Большого или большего размера попадает или промахивается по вам...'
        },
        {
          'id': 'horde-breaker',
          'en': 'Horde Breaker',
          'ru': 'Сокрушитель орд',
          'descEn':
              'Once on each of your turns when you make a weapon attack...',
          'descRu':
              'Один раз в каждый ваш ход, когда вы совершаете атаку оружием...'
        },
      ];
    } else if (widget.nextLevel == 7) {
      tactics = [
        {
          'id': 'escape-the-horde',
          'en': 'Escape the Horde',
          'ru': 'Побег от орды',
          'descEn':
              'Opportunity attacks against you are made with disadvantage.',
          'descRu': 'Провоцированные атаки по вам совершаются с помехой.'
        },
        {
          'id': 'multiattack-defense',
          'en': 'Multiattack Defense',
          'ru': 'Защита от мультиатаки',
          'descEn':
              'When a creature hits you with an attack, you gain a +4 bonus to AC.',
          'descRu':
              'Когда существо попадает по вам атакой, вы получаете бонус +4 к КД.'
        },
        {
          'id': 'steel-will',
          'en': 'Steel Will',
          'ru': 'Стальная воля',
          'descEn':
              'You have advantage on saving throws against being frightened.',
          'descRu': 'У вас есть преимущество на спасброски от испуга.'
        },
      ];
    } else if (widget.nextLevel == 11) {
      tactics = [
        {
          'id': 'volley',
          'en': 'Volley',
          'ru': 'Залп',
          'descEn':
              'You can use your action to make a ranged attack against any number of creatures.',
          'descRu':
              'Вы можете использовать действие, чтобы совершить дальнобойную атаку по любому количеству существ.'
        },
        {
          'id': 'whirlwind-attack',
          'en': 'Whirlwind Attack',
          'ru': 'Атака вихрем',
          'descEn':
              'You can use your action to make a melee attack against any number of creatures.',
          'descRu':
              'Вы можете использовать действие, чтобы совершить рукопашную атаку по любому количеству существ.'
        },
      ];
    } else if (widget.nextLevel == 15) {
      tactics = [
        {
          'id': 'evasion',
          'en': 'Evasion',
          'ru': 'Увертливость',
          'descEn':
              'You can nimbly dodge out of the way of certain area effects.',
          'descRu':
              'Вы можете ловко уклоняться от некоторых эффектов по площади.'
        },
        {
          'id': 'stand-against-the-tide',
          'en': 'Stand Against the Tide',
          'ru': 'Против течения',
          'descEn': 'When a hostile creature misses you with a melee attack...',
          'descRu':
              'Когда враждебное существо промахивается по вам рукопашной атакой...'
        },
        {
          'id': 'uncanny-dodge',
          'en': 'Uncanny Dodge',
          'ru': 'Невероятное уклонение',
          'descEn':
              'When an attacker that you can see hits you with an attack, you can use your reaction to halve the attack\'s damage.',
          'descRu':
              'Когда атакующий, которого вы видите, попадает по вам атакой, вы можете реакцией уменьшить урон вдвое.'
        },
      ];
    }

    return Column(
      children: [
        RadioGroup<String>(
          groupValue: _selections['hunter_tactic'] ?? '',
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selections['hunter_tactic'] = value;
              widget.onOptionSelected('hunter_tactic', value);
            });
          },
          child: Column(
              children: tactics.map((tactic) {
            final id = tactic['id']!;
            final name = locale == 'ru' ? tactic['ru']! : tactic['en']!;
            final desc = locale == 'ru' ? tactic['descRu']! : tactic['descEn']!;
            final isSelected = _selections['hunter_tactic'] == id;
            final colorScheme = Theme.of(context).colorScheme;

            return Card(
              elevation: isSelected ? 4 : 1,
              color: isSelected ? colorScheme.primaryContainer : null,
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selections['hunter_tactic'] = id;
                    widget.onOptionSelected('hunter_tactic', id);
                  });
                },
                child: Row(
                  children: [
                    Radio<String>(
                      value: id,
                      activeColor: colorScheme.primary,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(desc),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList()),
        )
      ],
    );
  }

  Widget _buildSpellMasterySelection(
      BuildContext context, String locale, AppLocalizations l10n) {
    final feature = FeatureService.getFeatureById('spell-mastery') ??
        CharacterFeature(
            id: 'dummy',
            nameEn: 'Spell Mastery',
            nameRu: 'Мастерство заклинаний',
            descriptionEn: '',
            descriptionRu: '',
            type: FeatureType.passive,
            minLevel: 18);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Info
        _buildFeatureCard(context, feature),
        const SizedBox(height: 12),
        Text(
            locale == 'ru'
                ? "Выберите по одному заклинанию 1-го и 2-го уровней из своей книги:"
                : "Choose one 1st-level and one 2nd-level spell from your spellbook:",
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        // Level 1
        Text(l10n.levelLabel(1),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        ..._masteryOptionsLvl1.map((spell) {
          final isSelected = _selectedMasterySpells.contains(spell.id);
          // Can select if none from level 1 are selected yet
          final currentLvl1Selected = _selectedMasterySpells
              .any((id) => _masteryOptionsLvl1.any((s) => s.id == id));
          final canSelect = isSelected || !currentLvl1Selected;

          return _buildSelectionSpellCard(
              context, spell, isSelected, canSelect, locale, l10n, (selected) {
            setState(() {
              if (selected) {
                // Remove existing lvl 1 selection first
                _selectedMasterySpells.removeWhere(
                    (id) => _masteryOptionsLvl1.any((s) => s.id == id));
                _selectedMasterySpells.add(spell.id);
              } else {
                _selectedMasterySpells.remove(spell.id);
              }
              widget.onMasterySpellsSelected(_selectedMasterySpells.toList());
            });
          });
        }),
        const SizedBox(height: 12),
        // Level 2
        Text(l10n.levelLabel(2),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        ..._masteryOptionsLvl2.map((spell) {
          final isSelected = _selectedMasterySpells.contains(spell.id);
          final currentLvl2Selected = _selectedMasterySpells
              .any((id) => _masteryOptionsLvl2.any((s) => s.id == id));
          final canSelect = isSelected || !currentLvl2Selected;

          return _buildSelectionSpellCard(
              context, spell, isSelected, canSelect, locale, l10n, (selected) {
            setState(() {
              if (selected) {
                _selectedMasterySpells.removeWhere(
                    (id) => _masteryOptionsLvl2.any((s) => s.id == id));
                _selectedMasterySpells.add(spell.id);
              } else {
                _selectedMasterySpells.remove(spell.id);
              }
              widget.onMasterySpellsSelected(_selectedMasterySpells.toList());
            });
          });
        }),
      ],
    );
  }

  Widget _buildSignatureSpellsSelection(
      BuildContext context, String locale, AppLocalizations l10n) {
    final feature = FeatureService.getFeatureById('signature-spell') ??
        CharacterFeature(
            id: 'dummy',
            nameEn: 'Signature Spells',
            nameRu: 'Фирменные заклинания',
            descriptionEn: '',
            descriptionRu: '',
            type: FeatureType.passive,
            minLevel: 20);
    final count = _selectedSignatureSpells.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Info
        _buildFeatureCard(context, feature),
        const SizedBox(height: 12),
        Text(
            locale == 'ru'
                ? "Выберите два заклинания 3-го уровня ($count / 2):"
                : "Choose two 3rd-level spells ($count / 2):",
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        ..._signatureOptions.map((spell) {
          final isSelected = _selectedSignatureSpells.contains(spell.id);
          final canSelect = isSelected || count < 2;

          return _buildSelectionSpellCard(
              context, spell, isSelected, canSelect, locale, l10n, (selected) {
            setState(() {
              if (selected) {
                _selectedSignatureSpells.add(spell.id);
              } else {
                _selectedSignatureSpells.remove(spell.id);
              }
              widget
                  .onSignatureSpellsSelected(_selectedSignatureSpells.toList());
            });
          });
        }),
      ],
    );
  }

  Widget _buildSelectionSpellCard(
      BuildContext context,
      Spell spell,
      bool isSelected,
      bool isEnabled,
      String locale,
      AppLocalizations l10n,
      Function(bool) onToggle) {
    final theme = Theme.of(context);
    final cardColor = isEnabled
        ? (isSelected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final textColor = isEnabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: isSelected ? 2 : 0,
      color: isSelected ? null : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: isEnabled ? () => onToggle(!isSelected) : null,
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
                    Icons.auto_awesome,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
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
                          color: isSelected
                              ? theme.colorScheme.primary
                              : textColor,
                        ),
                      ),
                      Text(
                        _getLocalizedSchool(l10n, spell.school),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: theme.colorScheme.primary)
                else if (isEnabled)
                  Icon(Icons.add_circle_outline,
                      color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getSubclassTitle(AppLocalizations l10n, String classId) {
    switch (classId.toLowerCase()) {
      case 'barbarian':
      case 'варвар':
        return l10n.primalPath;
      case 'bard':
      case 'бард':
        return l10n.bardCollege;
      case 'cleric':
      case 'жрец':
        return l10n.divineDomain;
      case 'druid':
      case 'друид':
        return l10n.druidCircle;
      case 'fighter':
      case 'воин':
        return l10n.martialArchetype;
      case 'monk':
      case 'монах':
        return l10n.monasticTradition;
      case 'paladin':
      case 'паладин':
        return l10n.sacredOath;
      case 'ranger':
      case 'следопыт':
        return l10n.rangerArchetype;
      case 'rogue':
      case 'плут':
        return l10n.roguishArchetype;
      case 'sorcerer':
      case 'чародей':
        return l10n.sorcerousOrigin;
      case 'warlock':
      case 'колдун':
        return l10n.otherworldlyPatron;
      case 'wizard':
      case 'волшебник':
        return l10n.arcaneTradition;
      default:
        return l10n.selectSubclass;
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
              letterSpacing: 1.0)),
    );
  }

  String _getFeatureTypeLabel(AppLocalizations l10n, FeatureType type) {
    switch (type) {
      case FeatureType.passive:
        return l10n.featureTypePassive;
      case FeatureType.action:
        return l10n.featureTypeAction;
      case FeatureType.bonusAction:
        return l10n.featureTypeBonusAction;
      case FeatureType.reaction:
        return l10n.featureTypeReaction;
      default:
        return l10n.featureTypeOther;
    }
  }

  Widget _buildFeatureCard(BuildContext context, CharacterFeature feature) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    IconData icon = Icons.star;
    if (feature.iconName != null) {
      switch (feature.iconName) {
        case 'healing':
          icon = Icons.favorite;
          break;
        case 'visibility':
          icon = Icons.visibility;
          break;
        case 'flash_on':
          icon = Icons.flash_on;
          break;
        case 'swords':
          icon = Icons.shield;
          break;
        case 'auto_fix_high':
          icon = Icons.auto_fix_high;
          break;
        case 'health_and_safety':
          icon = Icons.health_and_safety;
          break;
        case 'auto_awesome':
          icon = Icons.auto_awesome;
          break;
      }
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon,
                      color: Theme.of(context).colorScheme.onPrimaryContainer)),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(feature.getName(locale),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(_getFeatureTypeLabel(l10n, feature.type).toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.outline))
                  ]))
            ]),
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
      int oldCount =
          i < widget.oldSpellSlots.length ? widget.oldSpellSlots[i] : 0;
      if (newCount > oldCount) {
        levelRows.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(children: [
              SizedBox(
                  width: 50,
                  child: Text(l10n.lvlShort(level),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(width: 16),
              ...List.generate(
                  oldCount,
                  (_) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.0),
                      child: Icon(Icons.circle, size: 16, color: Colors.grey))),
              if (oldCount > 0)
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(Icons.arrow_forward,
                        size: 16, color: Colors.grey)),
              ...List.generate(
                  newCount - oldCount,
                  (_) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Icon(Icons.circle,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary)))
            ])));
      }
    }
    return Column(children: levelRows);
  }
}
