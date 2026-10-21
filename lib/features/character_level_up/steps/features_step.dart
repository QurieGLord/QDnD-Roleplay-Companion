import '../../../core/magic/spellbook_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/spell_details_sheet.dart';
import '../../../core/ui/sheet_drag_region.dart';
import '../../../core/utils/spell_utils.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/spell.dart';
import '../../../core/models/spell_slots_table.dart';
import '../../../core/constants/ranger_options.dart';
import '../../../ui/widgets/expressive_choice_selector.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../core/services/feature_service.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/services/character_data_service.dart';
import '../../../core/progression/advancement_choice_catalog.dart';
import '../../../core/progression/advancement_choice.dart';
import '../../../core/progression/proficiency_identity.dart';
import '../../../core/progression/resource_growth.dart';
import '../../../core/progression/pact_slot_growth.dart';
import '../widgets/advancement_choice_card.dart';
import '../widgets/advancement_selection.dart';
import '../widgets/advancement_layout.dart';
import '../../../core/progression/character_class_rules.dart';

enum FeaturesStepContent { combined, features, magic }

class FeaturesStep extends StatefulWidget {
  final FeaturesStepContent content;
  final Character character;
  final CharacterClassRules? rules;
  final bool pinningRules;
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
  final Function(Set<String> featureIds) onOptionalFeaturesChanged;
  final ValueChanged<Set<String>>? onSkillProficienciesChanged;
  final Function(List<String> spells) onSpellsSelected;
  final Function(List<String> spells) onMasterySpellsSelected;
  final Function(List<String> spells) onSignatureSpellsSelected;

  const FeaturesStep({
    super.key,
    this.content = FeaturesStepContent.combined,
    required this.character,
    this.rules,
    this.pinningRules = false,
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
    required this.onOptionalFeaturesChanged,
    this.onSkillProficienciesChanged,
    required this.onSpellsSelected,
    required this.onMasterySpellsSelected,
    required this.onSignatureSpellsSelected,
  });

  @override
  State<FeaturesStep> createState() => _FeaturesStepState();
}

class _FeaturesStepState extends State<FeaturesStep>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  List<CharacterFeature> get _definitions =>
      widget.rules?.definitions ?? FeatureService.allFeatures;
  CharacterFeature? _feature(String id) => widget.rules == null
      ? FeatureService.getFeatureById(id)
      : widget.rules!.feature(id);
  List<CharacterFeature> _featuresAt(int level, String? subclass) =>
      widget.rules?.atLevel(level, subclass) ??
      CharacterDataService.getFeaturesForLevel(
          classId: widget.classData.id, level: level, subclassId: subclass);

  final Map<String, String> _selections = {}; // featureId -> string ID
  final Set<String> _selectedExpertise = {};
  final Set<String> _selectedOptionalFeatures = {};
  final Map<String, Set<String>> _genericSelections = {};
  final Set<String> _selectedSpells = {};
  final Set<String> _selectedMasterySpells = {};
  final Set<String> _selectedSignatureSpells = {};

  List<Spell> _availableSpells = [];
  List<Spell> _masteryOptionsLvl1 = [];
  List<Spell> _masteryOptionsLvl2 = [];
  List<Spell> _signatureOptions = [];

  bool _spellsLoaded = false;
  final TextEditingController _spellSearch = TextEditingController();
  String _spellQuery = '';
  @override
  void dispose() {
    _spellSearch.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadAvailableSpells();
  }

  Future<void> _loadAvailableSpells() async {
    // If no spells to learn according to parent, we might still check if we *should* have them?
    // But usually parent logic prevails.
    if (widget.spellsToLearnCount <= 0 && widget.classData.id != 'wizard') {
      if (mounted) {
        setState(() {
          _spellsLoaded = true;
        });
      }
      return;
    }

    final classId = widget.classData.id;
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

    // Learning belongs to this class, not the combined multiclass slot pool.
    final casterType = widget.classData.spellcasting?.type;
    if (casterType != null) {
      maxSlotLevel =
          SpellSlotsTable.getMaxSlotLevel(widget.nextLevel, casterType);
    }
    final book = SpellbookState.read(widget.character.spellbookData);
    final knownIds = book.ids('class:${widget.classData.id}', 'known');
    if (widget.character.classes.length == 1) {
      knownIds.addAll(book.unassignedKnown(widget.character));
    }

    _availableSpells = allClassSpells.where((s) {
      if (knownIds.contains(s.id)) return false;
      if (s.level == 0) return false;
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
    // Normalize: replace hyphens with underscores to match switch cases
    switch (skillId.toLowerCase().replaceAll('-', '_')) {
      case 'thieves_tools':
        return l10n.localeName.startsWith('ru')
            ? 'Воровские инструменты'
            : 'Thieves’ tools';
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
      'two_weapon',
    ],
    'paladin': ['defense', 'dueling', 'great_weapon', 'protection'],
    'ranger': ['archery', 'defense', 'dueling', 'two_weapon'],
  };

  List<Map<String, String>> _getFightingStyles(BuildContext context) {
    final classId = widget.classData.id.toLowerCase();
    final availableIds = _classStyles[classId] ?? _classStyles['fighter']!;
    final l10n = AppLocalizations.of(context)!;
    final List<Map<String, String>> result = [];
    final characterFeatures =
        widget.character.features.map((e) => e.id).toSet();

    for (var styleId in availableIds) {
      // Check if character already has this fighting style in any form
      // E.g. fs_$styleId, $classId-fighting-style-$styleId, fighting-style-$styleId, fighting-style-$normalizedStyle
      final normalizedStyle = styleId.replaceAll('_', '-');
      final hasIt = characterFeatures.contains('fs_$styleId') ||
          characterFeatures.contains('fs_$normalizedStyle') ||
          characterFeatures.any(
            (id) =>
                id.endsWith('-$styleId') || id.endsWith('-$normalizedStyle'),
          );

      if (hasIt) continue; // Skip styles the character already has

      final localized = LocalizationHelper.getLocalizedFightingStyle(
        styleId,
        l10n,
      );
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

  void _selectChoice(String key, String value) {
    setState(() {
      if (key == 'subclass' && _selections[key] != value) {
        _selections.clear();
        _genericSelections.clear();
        _selectedExpertise.clear();
        _selectedOptionalFeatures.clear();
      }
      _selections[key] = value;
      widget.onOptionSelected(key, value);
    });
  }

  List<CharacterFeature> _getSelectedSubclassPreviewFeatures() {
    final selectedSubclassId = _selections['subclass'];
    if (selectedSubclassId == null || selectedSubclassId.isEmpty) {
      return const [];
    }

    final landOptionIds =
        widget.landOptions.map((feature) => feature.id).toSet();

    return _featuresAt(widget.nextLevel, selectedSubclassId).where((feature) {
      if (feature.associatedSubclass == null) return false;
      if (landOptionIds.contains(feature.id)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final showFeatures = widget.content != FeaturesStepContent.magic;
    final showMagic = widget.content != FeaturesStepContent.features;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    final hasSpellChanges = widget.newSpellSlots.isNotEmpty &&
        (widget.newSpellSlots.length > widget.oldSpellSlots.length ||
            widget.newSpellSlots.asMap().entries.any(
                  (e) =>
                      e.value >
                      (widget.oldSpellSlots.length > e.key
                          ? widget.oldSpellSlots[e.key]
                          : 0),
                ));

    final Set<String> optionalFeaturesPool = {};
    for (var feature in widget.newFeatures) {
      if (feature.options != null && feature.options!.isNotEmpty) {
        optionalFeaturesPool.addAll(feature.options!);
      }
    }

    bool needsFightingStyle = widget.newFeatures.any(
      (f) => f.id.contains('fighting-style'),
    );
    bool needsSubclass = widget.nextLevel == widget.classData.subclassLevel &&
        (widget.classData.declares('subclassLevel') ||
            widget.classData.subclasses.isNotEmpty);
    if (widget.classData.id.toLowerCase() == 'ranger' ||
        widget.classData.id.toLowerCase() == 'sleDopyt' ||
        widget.classData.id.toLowerCase() == 'следопыт') {
      needsSubclass = widget.nextLevel == 3;
    }
    final selectedSubclassPreviewFeatures = needsSubclass
        ? _getSelectedSubclassPreviewFeatures()
        : const <CharacterFeature>[];
    bool needsLandChoice = widget.landOptions.isNotEmpty &&
        ({'land', 'circle of the land', 'circle of land', 'круг земли'}
                .contains(widget.character.subclass?.toLowerCase()) ||
            _selections['subclass'] == 'land');
    final optionalImportedFeatures = widget.newFeatures.where((feature) {
      if (!feature.isOptional) return false;
      if (feature.id.contains('fighting-style') ||
          feature.id.contains('pact-boon')) {
        return false;
      }
      if (optionalFeaturesPool.contains(feature.id)) return false;
      if (feature.options != null && feature.options!.isNotEmpty) return false;
      return true;
    }).toList(growable: false);

    bool needsExpertise = false;
    int expertiseCount = 2;
    final classId = widget.classData.id.toLowerCase();
    if (classId == 'bard' || classId == 'бард') {
      if (widget.nextLevel == 3 || widget.nextLevel == 10) {
        needsExpertise = true;
      }
    }
    if (classId == 'rogue' || classId == 'плут') {
      if ([1, 6].contains(widget.nextLevel)) needsExpertise = true;
    }

    final requiredExpertiseCount = expertiseCount;

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

    needsFightingStyle = showFeatures && needsFightingStyle;
    needsSubclass = showFeatures && needsSubclass;
    needsLandChoice = showFeatures && needsLandChoice;
    needsExpertise = showFeatures && needsExpertise;
    needsPactBoon = showFeatures && needsPactBoon;
    needsFavoredEnemy = showFeatures && needsFavoredEnemy;
    needsNaturalExplorer = showFeatures && needsNaturalExplorer;
    needsHunterTactic = showFeatures && needsHunterTactic;
    needsSpellMastery = showMagic && needsSpellMastery;
    needsSignatureSpells = showMagic && needsSignatureSpells;

    // Spell Selection Validation
    // Valid if we DON'T need spells OR if we have selected enough
    // Missing spell content remains an incomplete choice and must not grant a level.
    bool effectiveNeedsSpells = showMagic && widget.spellsToLearnCount > 0;
    bool spellsSatisfied = !effectiveNeedsSpells ||
        _selectedSpells.length == widget.spellsToLearnCount;

    final genericChoices = !showFeatures
        ? <AdvancementChoice>[]
        : AdvancementChoiceCatalog([
            ..._definitions,
            ...widget.classData.features.values.expand((features) => features),
          ]).forLevel(classId: classId, level: widget.nextLevel, features: [
            ...widget.newFeatures,
            ...selectedSubclassPreviewFeatures
          ]);
    bool allChoicesMade = spellsSatisfied &&
        genericChoices.every((choice) => choice.isSatisfied(
            _genericSelections[choice.id] ?? {},
            widget.character,
            widget.nextLevel));
    if (needsFightingStyle && !_selections.containsKey('fighting_style')) {
      allChoicesMade = false;
    }
    if (needsSubclass && !_selections.containsKey('subclass')) {
      allChoicesMade = false;
    }
    if (needsExpertise && _selectedExpertise.length != requiredExpertiseCount) {
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

    final pending = <String>[
      for (final choice in genericChoices)
        if (!choice.isSatisfied(_genericSelections[choice.id] ?? {},
            widget.character, widget.nextLevel))
          '${_feature(choice.id)?.getName(locale) ?? l10n.makeChoices}: ${(_genericSelections[choice.id] ?? {}).length}/${choice.count}',
      if (needsSubclass && !_selections.containsKey('subclass'))
        _getSubclassTitle(l10n, widget.classData.id),
      if (needsFightingStyle && !_selections.containsKey('fighting_style'))
        l10n.chooseFightingStyle,
      if (needsExpertise && _selectedExpertise.length != requiredExpertiseCount)
        '${l10n.expertise}: ${_selectedExpertise.length}/$requiredExpertiseCount',
      if (!spellsSatisfied)
        '${locale == 'ru' ? 'Заклинания' : 'Spells'}: ${_selectedSpells.length}/${widget.spellsToLearnCount}',
    ];
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            AdvancementHeading(
              title: widget.content == FeaturesStepContent.magic
                  ? (effectiveNeedsSpells ||
                          needsSpellMastery ||
                          needsSignatureSpells
                      ? l10n.spells
                      : l10n.advancementSlotsTitle)
                  : l10n.advancementFeaturesTitle,
              subtitle: widget.content == FeaturesStepContent.magic
                  ? (effectiveNeedsSpells
                      ? l10n.advancementSpellsHint
                      : l10n.advancementSlotsHint)
                  : l10n.advancementFeaturesHint,
            ),
            if (showFeatures) ...[
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

              // 2. Subclass Selection (Important Choice)
              if (needsSubclass) ...[
                _buildSectionHeader(
                  context,
                  _getSubclassTitle(l10n, widget.classData.id),
                ),
                _buildSubclassChoice(context),
                if (selectedSubclassPreviewFeatures.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader(
                    context,
                    locale == 'ru' ? 'УМЕНИЯ ПОДКЛАССА' : 'SUBCLASS FEATURES',
                  ),
                  ...selectedSubclassPreviewFeatures.map(
                    (feature) => _buildFeatureCard(context, feature),
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // 2.5 Land Choice (Circle of the Land)
              if (needsLandChoice) ...[
                _buildSectionHeader(
                  context,
                  locale == 'ru'
                      ? 'КРУГ ЗЕМЛИ: МЕСТНОСТЬ'
                      : 'CIRCLE OF THE LAND: TERRAIN',
                ),
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
                  return _buildFightingStyleChoice(
                    context,
                    feature,
                    l10n,
                  );
                }),
                const SizedBox(height: 16),
              ],

              // 3.5 Pact Boon (Important Choice)
              if (needsPactBoon) ...[
                _buildSectionHeader(
                  context,
                  locale == 'ru' ? "ПРЕДМЕТ ДОГОВОРА" : "PACT BOON",
                ),
                _buildPactBoonChoice(context, locale),
                const SizedBox(height: 16),
              ],

              // 3.8 Ranger Favored Enemy
              if (needsFavoredEnemy) ...[
                _buildSectionHeader(
                  context,
                  locale == 'ru' ? "ИЗБРАННЫЙ ВРАГ" : "FAVORED ENEMY",
                ),
                _buildFavoredEnemyChoice(context, locale, l10n),
                const SizedBox(height: 16),
              ],

              // 3.9 Ranger Natural Explorer
              if (needsNaturalExplorer) ...[
                _buildSectionHeader(
                  context,
                  locale == 'ru' ? "ИССЛЕДОВАТЕЛЬ ПРИРОДЫ" : "NATURAL EXPLORER",
                ),
                _buildNaturalExplorerChoice(context, locale, l10n),
                const SizedBox(height: 16),
              ],

              // 3.10 Ranger Hunter Tactic
              if (needsHunterTactic) ...[
                _buildSectionHeader(
                  context,
                  locale == 'ru' ? "ТАКТИКА ОХОТНИКА" : "HUNTER'S PREY",
                ),
                _buildHunterTacticChoice(context, locale, l10n),
                const SizedBox(height: 16),
              ],

              for (final choice in genericChoices)
                AdvancementChoiceCard(
                    key: ValueKey('progression-choice-${choice.id}'),
                    choice: choice,
                    character: widget.character,
                    classLevel: widget.nextLevel,
                    title: _feature(choice.id)?.getName(locale) ??
                        widget.newFeatures
                            .where((f) => f.id == choice.id)
                            .firstOrNull
                            ?.getName(locale) ??
                        l10n.makeChoices,
                    selected: _genericSelections[choice.id] ?? {},
                    labelFor: (option) =>
                        choice.kind == AdvancementChoiceKind.skillProficiency
                            ? _getLocalizedSkill(context, option.id)
                            : option.feature!.getName(locale),
                    onChanged: (values) {
                      setState(() => _genericSelections[choice.id] = values);
                      widget.onOptionalFeaturesChanged({
                        ..._selectedOptionalFeatures,
                        for (final group in genericChoices.where(
                            (c) => c.kind == AdvancementChoiceKind.feature))
                          ...?_genericSelections[group.id],
                      });
                      widget.onSkillProficienciesChanged?.call({
                        for (final group in genericChoices.where((c) =>
                            c.kind == AdvancementChoiceKind.skillProficiency))
                          ...?_genericSelections[group.id],
                      });
                    }),
              // 4. Expertise (Important Choice)
              if (needsExpertise) ...[
                _buildSectionHeader(context, l10n.expertise),
                _buildExpertiseSelection(
                  context,
                  requiredExpertiseCount,
                  l10n,
                ),
                const SizedBox(height: 16),
              ],

              // 5. Other Class Features
              if (widget.newFeatures.any((f) {
                if (f.id.contains('fighting-style') ||
                    f.id.contains('pact-boon')) {
                  return false;
                }

                if (optionalFeaturesPool.contains(f.id)) {
                  return false;
                }

                if (f.isOptional) {
                  return false;
                }

                if (f.options != null && f.options!.isNotEmpty) {
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

                  if (optionalFeaturesPool.contains(f.id)) {
                    return false;
                  }

                  if (f.isOptional) {
                    return false;
                  }

                  if (f.options != null && f.options!.isNotEmpty) {
                    return false;
                  }

                  return true;
                }).map((feature) {
                  return _buildFeatureCard(context, feature);
                }),
                const SizedBox(height: 16),
              ],

              if (optionalImportedFeatures.isNotEmpty) ...[
                _buildSectionHeader(context, l10n.optionalFeaturesLabel),
                ...optionalImportedFeatures.map(
                  (feature) => _buildOptionalFeatureCard(context, feature),
                ),
                const SizedBox(height: 16),
              ],
            ],
            if (showMagic) ...[
              // 3.6 Wizard Spell Mastery (Level 18)
              if (needsSpellMastery) ...[
                _buildSectionHeader(
                  context,
                  locale == 'ru'
                      ? "ЗАКЛИНАТЕЛЬНОЕ МАСТЕРСТВО"
                      : "SPELL MASTERY",
                ),
                _buildSpellMasterySelection(context, locale, l10n),
                const SizedBox(height: 16),
              ],

              // 3.7 Wizard Signature Spells (Level 20)
              if (needsSignatureSpells) ...[
                _buildSectionHeader(
                  context,
                  locale == 'ru' ? "ФИРМЕННЫЕ ЗАКЛИНАНИЯ" : "SIGNATURE SPELLS",
                ),
                _buildSignatureSpellsSelection(context, locale, l10n),
                const SizedBox(height: 16),
              ],

              if (hasSpellChanges)
                Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Material(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                            shape: const Border(),
                            collapsedShape: const Border(),
                            leading: Icon(Icons.auto_fix_high_rounded,
                                color: colorScheme.primary),
                            title: Text(
                                locale == 'ru'
                                    ? 'Как изменятся ячейки'
                                    : 'Spell slot changes',
                                style: theme.textTheme.titleSmall),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            children: [_buildSpellSlotGrid(context, l10n)]))),
              // Class-specific spell learning.
              if (effectiveNeedsSpells) ...[
                const SizedBox(height: 8),
                if (widget.content == FeaturesStepContent.combined)
                  _buildSectionHeader(context, l10n.spellsStepTitle),
                _buildSpellSelection(context, l10n, locale),
                const SizedBox(height: 16),
              ],
            ],
          ],
        ),
      ),
      AdvancementFooter(
        label: l10n.continueLabel,
        hint: pending.isNotEmpty
            ? pending.first
            : !allChoicesMade
                ? (l10n.advancementCompleteChoices)
                : null,
        onPressed: allChoicesMade ? widget.onNext : null,
      ),
    ]);
  }

  Widget _buildSpellSelection(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
  ) {
    if (!_spellsLoaded) return const Center(child: CircularProgressIndicator());

    // Group spells by level
    final spellsByLevel = <int, List<Spell>>{};
    final query = _spellQuery.toLowerCase().replaceAll('ё', 'е').trim();
    for (var s in _availableSpells.where((s) =>
        query.isEmpty ||
        s.nameRu.toLowerCase().replaceAll('ё', 'е').contains(query) ||
        s.nameEn.toLowerCase().contains(query))) {
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
                  l10n.advancementChooseSpells(count),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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

        TextField(
            key: const ValueKey('advancement-spell-search'),
            controller: _spellSearch,
            autofocus: false,
            decoration: InputDecoration(
                hintText: l10n.searchSpells,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _spellQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.advancementClearSearch,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _spellSearch.clear();
                          setState(() => _spellQuery = '');
                        }),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLow,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                        color:
                            theme.colorScheme.primary.withValues(alpha: .5))),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none)),
            onChanged: (value) => setState(() => _spellQuery = value)),
        const SizedBox(height: 12),
        if (levels.isEmpty)
          Padding(
              padding: const EdgeInsets.all(20),
              child: Text(l10n.noSpellsFound)),
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
              key: ValueKey('lvl_$level:$_spellQuery'),
              title: Text(
                level == 0 ? l10n.cantrips : l10n.levelLabel(level),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              initiallyExpanded: query.isNotEmpty || index == levels.length - 1,
              shape: const Border(), // Remove borders
              children: spells.map((spell) {
                final isSelected = _selectedSpells.contains(spell.id);
                final canSelect = isSelected || count > 0;

                return _buildSpellCard(
                  context,
                  spell,
                  isSelected,
                  canSelect,
                  locale,
                  l10n,
                );
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
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    void details() => showResponsiveSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SpellDetailsSheet(spell: spell));
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
            checked: isSelected,
            enabled: isEnabled,
            child: Material(
              color: isSelected
                  ? colors.secondaryContainer.withValues(alpha: .7)
                  : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  key: ValueKey('advancement-spell-${spell.id}'),
                  onLongPress: details,
                  onTap: !isEnabled
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            final next = toggleAdvancementSelection(
                                _selectedSpells,
                                spell.id,
                                widget.spellsToLearnCount);
                            _selectedSpells
                              ..clear()
                              ..addAll(next);
                            widget.onSpellsSelected(_selectedSpells.toList());
                          });
                        },
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                      child: Row(children: [
                        Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.auto_fix_high_outlined,
                            size: 24,
                            color: colors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(spell.getName(locale),
                                  style: theme.textTheme.titleSmall),
                              const SizedBox(height: 4),
                              Text(
                                  '${_getLocalizedSchool(l10n, spell.school)} · ${SpellUtils.getLocalizedValue(l10n, spell.castingTime)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant)),
                            ])),
                        IconButton(
                            tooltip: l10n.advancementDetails,
                            onPressed: details,
                            icon: Icon(Icons.info_outline_rounded,
                                size: 20, color: colors.onSurfaceVariant)),
                      ]))),
            )));
  }

  Set<String> _getAllProficientSkills() {
    final skills = widget.character.proficientSkills
        .map(ProficiencyIdentity.normalize)
        .toSet();
    skills.addAll(_genericSelections['bonus-proficiencies'] ?? {});
    if (widget.character.background != null) {
      try {
        final bg = CharacterDataService.getBackgroundById(
          widget.character.background!,
        );
        if (bg != null) {
          skills
              .addAll(bg.skillProficiencies.map(ProficiencyIdentity.normalize));
        }
      } catch (_) {}
    }
    if (widget.classData.id == 'rogue') skills.add('thieves-tools');
    return skills;
  }

  Widget _buildExpertiseSelection(
    BuildContext context,
    int count,
    AppLocalizations l10n,
  ) {
    // ... same as before
    final proficientSkills = _getAllProficientSkills();
    final existingExpertise = widget.character.expertSkills;

    // Normalize all skill IDs to a consistent format (underscores)
    // then deduplicate to remove duplicates caused by mixed formats
    final normalizedExisting = existingExpertise
        .map((s) => s.toLowerCase().replaceAll('-', '_'))
        .toSet();
    final seen = <String>{};
    final candidates = proficientSkills
        .map((s) => s.toLowerCase().replaceAll('-', '_'))
        .where((s) => !normalizedExisting.contains(s) && seen.add(s))
        .toList();
    final selectedCount = _selectedExpertise.length;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.expertise} ($selectedCount/$count)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chooseSkills(count, ''),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: candidates.map((skillId) {
                final isSelected = _selectedExpertise.contains(skillId);
                final canSelect = isSelected || count > 0;
                return FilterChip(
                  key: ValueKey('advancement-expertise-$skillId'),
                  label: Text(_getLocalizedSkill(context, skillId)),
                  selected: isSelected,
                  onSelected: canSelect
                      ? (selected) {
                          setState(() {
                            final next = toggleAdvancementSelection(
                                _selectedExpertise, skillId, count);
                            _selectedExpertise
                              ..clear()
                              ..addAll(next);
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
            _selectChoice('subclass', value);
          },
          child: Column(
            children: widget.classData.subclasses.map((subclass) {
              final isSelected = _selections['subclass'] == subclass.id;
              final colorScheme = Theme.of(context).colorScheme;
              return Card(
                elevation: 0,
                color: isSelected ? colorScheme.primaryContainer : null,
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _selectChoice('subclass', subclass.id),
                  borderRadius: BorderRadius.circular(22),
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
                              Text(
                                subclass.getName(locale),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isSelected
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subclass.getDescription(locale),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected
                                      ? colorScheme.onPrimaryContainer
                                          .withValues(alpha: 0.8)
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.check_circle,
                              color: colorScheme.primary,
                            ),
                          ),
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
    BuildContext context,
    CharacterFeature feature,
    AppLocalizations l10n,
  ) {
    // ... same as before

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFeatureCard(context, feature),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            l10n.chooseFightingStyle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
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
                elevation: 0,
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                child: RadioListTile<String>(
                  value: style['id']!,
                  title: Text(
                    style['name']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(style['desc']!),
                  secondary: const Icon(Icons.sports_martial_arts),
                ),
              );
            }).toList(),
          ),
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
        'icon': Icons.shield,
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

    // Filter out boons the character already possesses
    final characterFeatures =
        widget.character.features.map((e) => e.id).toSet();
    final filteredBoons = boons.where((boon) {
      final dashedId = (boon['id'] as String).replaceAll('_', '-');
      return !characterFeatures.contains(dashedId) &&
          !characterFeatures.contains(boon['id'] as String);
    }).toList();

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
            children: filteredBoons.map((boon) {
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
                elevation: 0,
                color: isSelected ? colorScheme.primaryContainer : null,
                margin: const EdgeInsets.only(bottom: 8),
                child: RadioListTile<String>(
                  value: id,
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(desc),
                  secondary: Icon(
                    icon,
                    color: isSelected ? colorScheme.primary : null,
                  ),
                  activeColor: colorScheme.primary,
                ),
              );
            }).toList(),
          ),
        ),
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
            _selectChoice('land_terrain', value);
          },
          child: Column(
            children: widget.landOptions.map((feature) {
              final isSelected = _selections['land_terrain'] == feature.id;
              final colorScheme = Theme.of(context).colorScheme;

              return Card(
                elevation: 0,
                color: isSelected ? colorScheme.primaryContainer : null,
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _selectChoice('land_terrain', feature.id),
                  borderRadius: BorderRadius.circular(22),
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
                              Text(
                                feature.getName(locale),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isSelected
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildFavoredEnemyChoice(
    BuildContext context,
    String locale,
    AppLocalizations l10n,
  ) {
    final feature = _feature('favored-enemy') ??
        CharacterFeature(
          id: 'favored-enemy',
          nameEn: 'Favored Enemy',
          nameRu: 'Избранный враг',
          descriptionEn: 'Choose a type of favored enemy.',
          descriptionRu: 'Выберите тип избранного врага.',
          type: FeatureType.passive,
          minLevel: 1,
        );

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
    BuildContext context,
    String locale,
    AppLocalizations l10n,
  ) {
    final feature = _feature('natural-explorer') ??
        CharacterFeature(
          id: 'natural-explorer',
          nameEn: 'Natural Explorer',
          nameRu: 'Исследователь природы',
          descriptionEn: 'Choose a terrain type.',
          descriptionRu: 'Выберите тип местности.',
          type: FeatureType.passive,
          minLevel: 1,
        );

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
    BuildContext context,
    String locale,
    AppLocalizations l10n,
  ) {
    List<Map<String, String>> tactics = [];
    if (widget.nextLevel == 3) {
      tactics = [
        {
          'id': 'colossus-slayer',
          'en': 'Colossus Slayer',
          'ru': 'Убийца колоссов',
          'descEn': 'Your tenacity can wear down the most potent foes.',
          'descRu': 'Ваше упорство может измотать самых сильных врагов.',
        },
        {
          'id': 'giant-killer',
          'en': 'Giant Killer',
          'ru': 'Убийца великанов',
          'descEn':
              'When a Large or larger creature hits or misses you with a melee attack...',
          'descRu':
              'Когда существо Большого или большего размера попадает или промахивается по вам...',
        },
        {
          'id': 'horde-breaker',
          'en': 'Horde Breaker',
          'ru': 'Сокрушитель орд',
          'descEn':
              'Once on each of your turns when you make a weapon attack...',
          'descRu':
              'Один раз в каждый ваш ход, когда вы совершаете атаку оружием...',
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
          'descRu': 'Провоцированные атаки по вам совершаются с помехой.',
        },
        {
          'id': 'multiattack-defense',
          'en': 'Multiattack Defense',
          'ru': 'Защита от мультиатаки',
          'descEn':
              'When a creature hits you with an attack, you gain a +4 bonus to AC.',
          'descRu':
              'Когда существо попадает по вам атакой, вы получаете бонус +4 к КД.',
        },
        {
          'id': 'steel-will',
          'en': 'Steel Will',
          'ru': 'Стальная воля',
          'descEn':
              'You have advantage on saving throws against being frightened.',
          'descRu': 'У вас есть преимущество на спасброски от испуга.',
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
              'Вы можете использовать действие, чтобы совершить дальнобойную атаку по любому количеству существ.',
        },
        {
          'id': 'whirlwind-attack',
          'en': 'Whirlwind Attack',
          'ru': 'Атака вихрем',
          'descEn':
              'You can use your action to make a melee attack against any number of creatures.',
          'descRu':
              'Вы можете использовать действие, чтобы совершить рукопашную атаку по любому количеству существ.',
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
              'Вы можете ловко уклоняться от некоторых эффектов по площади.',
        },
        {
          'id': 'stand-against-the-tide',
          'en': 'Stand Against the Tide',
          'ru': 'Против течения',
          'descEn': 'When a hostile creature misses you with a melee attack...',
          'descRu':
              'Когда враждебное существо промахивается по вам рукопашной атакой...',
        },
        {
          'id': 'uncanny-dodge',
          'en': 'Uncanny Dodge',
          'ru': 'Невероятное уклонение',
          'descEn':
              'When an attacker that you can see hits you with an attack, you can use your reaction to halve the attack\'s damage.',
          'descRu':
              'Когда атакующий, которого вы видите, попадает по вам атакой, вы можете реакцией уменьшить урон вдвое.',
        },
      ];
    }

    // Filter out tactics the character already possesses
    final characterFeatures =
        widget.character.features.map((e) => e.id).toSet();
    final filteredTactics = tactics.where((tactic) {
      return !characterFeatures.contains(tactic['id']);
    }).toList();

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
            children: filteredTactics.map((tactic) {
              final id = tactic['id']!;
              final name = locale == 'ru' ? tactic['ru']! : tactic['en']!;
              final desc =
                  locale == 'ru' ? tactic['descRu']! : tactic['descEn']!;
              final isSelected = _selections['hunter_tactic'] == id;
              final colorScheme = Theme.of(context).colorScheme;

              return Card(
                elevation: 0,
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
                            vertical: 12.0,
                            horizontal: 8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSpellMasterySelection(
    BuildContext context,
    String locale,
    AppLocalizations l10n,
  ) {
    final feature = _feature('spell-mastery') ??
        CharacterFeature(
          id: 'dummy',
          nameEn: 'Spell Mastery',
          nameRu: 'Мастерство заклинаний',
          descriptionEn: '',
          descriptionRu: '',
          type: FeatureType.passive,
          minLevel: 18,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Info
        _buildFeatureCard(context, feature),
        const SizedBox(height: 12),
        Text(
          l10n.spellMasterySelectionHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        // Level 1
        Text(
          l10n.levelLabel(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        ..._masteryOptionsLvl1.map((spell) {
          final isSelected = _selectedMasterySpells.contains(spell.id);

          return _buildSelectionSpellCard(
            context,
            spell,
            isSelected,
            true,
            locale,
            l10n,
            (selected) {
              setState(() {
                if (selected) {
                  // Remove existing lvl 1 selection first
                  _selectedMasterySpells.removeWhere(
                    (id) => _masteryOptionsLvl1.any((s) => s.id == id),
                  );
                  _selectedMasterySpells.add(spell.id);
                } else {
                  _selectedMasterySpells.remove(spell.id);
                }
                widget.onMasterySpellsSelected(_selectedMasterySpells.toList());
              });
            },
          );
        }),
        const SizedBox(height: 12),
        // Level 2
        Text(
          l10n.levelLabel(2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        ..._masteryOptionsLvl2.map((spell) {
          final isSelected = _selectedMasterySpells.contains(spell.id);

          return _buildSelectionSpellCard(
            context,
            spell,
            isSelected,
            true,
            locale,
            l10n,
            (selected) {
              setState(() {
                if (selected) {
                  _selectedMasterySpells.removeWhere(
                    (id) => _masteryOptionsLvl2.any((s) => s.id == id),
                  );
                  _selectedMasterySpells.add(spell.id);
                } else {
                  _selectedMasterySpells.remove(spell.id);
                }
                widget.onMasterySpellsSelected(_selectedMasterySpells.toList());
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildSignatureSpellsSelection(
    BuildContext context,
    String locale,
    AppLocalizations l10n,
  ) {
    final feature = _feature('signature-spell') ??
        CharacterFeature(
          id: 'dummy',
          nameEn: 'Signature Spells',
          nameRu: 'Фирменные заклинания',
          descriptionEn: '',
          descriptionRu: '',
          type: FeatureType.passive,
          minLevel: 20,
        );
    final count = _selectedSignatureSpells.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Info
        _buildFeatureCard(context, feature),
        const SizedBox(height: 12),
        Text(
          l10n.signatureSpellsSelectionHint(count),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ..._signatureOptions.map((spell) {
          final isSelected = _selectedSignatureSpells.contains(spell.id);

          return _buildSelectionSpellCard(
            context,
            spell,
            isSelected,
            true,
            locale,
            l10n,
            (selected) {
              setState(() {
                final next = toggleAdvancementSelection(
                    _selectedSignatureSpells, spell.id, 2);
                _selectedSignatureSpells
                  ..clear()
                  ..addAll(next);
                widget.onSignatureSpellsSelected(
                  _selectedSignatureSpells.toList(),
                );
              });
            },
          );
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
    Function(bool) onToggle,
  ) {
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
        borderRadius: BorderRadius.circular(22),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
      ),
      child: InkWell(
        onTap: isEnabled ? () => onToggle(!isSelected) : null,
        borderRadius: BorderRadius.circular(22),
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
                  Icon(
                    Icons.add_circle_outline,
                    color: theme.colorScheme.outline,
                  ),
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
      child: Text(
        title == title.toUpperCase() && title.isNotEmpty
            ? title[0] + title.substring(1).toLowerCase()
            : title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
          letterSpacing: 0,
        ),
      ),
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Icon(icon, size: 24, color: colors.primary),
            title: Text(feature.getName(locale),
                style: Theme.of(context).textTheme.titleSmall),
            subtitle: Text(_getFeatureTypeLabel(l10n, feature.type),
                style: Theme.of(context).textTheme.bodySmall),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(feature.getDescription(locale),
                      style: Theme.of(context).textTheme.bodyMedium))
            ],
          ),
        ));
  }

  Widget _buildOptionalFeatureCard(
    BuildContext context,
    CharacterFeature feature,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _selectedOptionalFeatures.contains(feature.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedOptionalFeatures.add(feature.id);
            } else {
              _selectedOptionalFeatures.remove(feature.id);
            }
            widget.onOptionalFeaturesChanged({
              ..._selectedOptionalFeatures,
              for (final entry in _genericSelections.entries)
                if (entry.key != 'bonus-proficiencies') ...entry.value,
            });
          });
        },
        secondary: Icon(
          Icons.tune_rounded,
          color: selected ? colorScheme.primary : colorScheme.outline,
        ),
        title: Text(
          feature.getName(locale),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          feature.getDescription(locale),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildSpellSlotGrid(BuildContext context, AppLocalizations l10n) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final colors = Theme.of(context).colorScheme;
    final before = widget.character;
    var afterCurrent = <int>[];
    var afterMaximum = widget.newSpellSlots;
    if (widget.classData.spellcasting?.type == 'pact') {
      final oldNorm = SpellSlotsTable.getPactSlots(widget.nextLevel - 1);
      final nextNorm = SpellSlotsTable.getPactSlots(widget.nextLevel);
      final changed = PactSlotGrowth.move(
          current: before.spellSlots,
          maximum: before.maxSpellSlots,
          oldCircle: oldNorm.length,
          newCircle: nextNorm.length,
          oldNorm: oldNorm.last,
          newNorm: nextNorm.last);
      afterCurrent = changed.current;
      afterMaximum = changed.maximum;
    } else {
      afterCurrent = [
        for (var i = 0; i < afterMaximum.length; i++)
          ResourceGrowth.remaining(
              current: i < before.spellSlots.length ? before.spellSlots[i] : 0,
              oldMaximum:
                  i < before.maxSpellSlots.length ? before.maxSpellSlots[i] : 0,
              newMaximum: afterMaximum[i])
      ];
    }
    return Column(children: [
      for (var i = 0; i < afterMaximum.length; i++)
        if (afterMaximum[i] !=
            (i < before.maxSpellSlots.length ? before.maxSpellSlots[i] : 0))
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(
                    child: Text(ru ? '${i + 1} круг' : 'Spell level ${i + 1}',
                        style: Theme.of(context).textTheme.bodyMedium)),
                Text(
                    '${i < before.spellSlots.length ? before.spellSlots[i] : 0}/${i < before.maxSpellSlots.length ? before.maxSpellSlots[i] : 0}',
                    style: TextStyle(color: colors.onSurfaceVariant)),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: colors.onSurfaceVariant)),
                Text('${afterCurrent[i]}/${afterMaximum[i]}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: colors.primary)),
              ]))
    ]);
  }
}
