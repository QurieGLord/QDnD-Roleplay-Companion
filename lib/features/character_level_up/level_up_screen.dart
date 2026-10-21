import '../../../core/magic/magic_slots.dart';
import '../../../core/progression/legacy_spell_allocation.dart';
import '../../../shared/widgets/magic_allocation_sheet.dart';
import '../../../core/services/qdnd_bundle_codec.dart';
import '../../../core/magic/spellbook_state.dart';
import 'steps/legacy_spell_sources_step.dart';
import '../../../core/progression/spell_learning_plan.dart';
import '../../../core/magic/class_spell_grants.dart';
import 'steps/class_magic_step.dart';
import 'steps/entry_training_step.dart';
import '../../../core/models/character_class.dart';
import '../../../core/progression/multiclass_rules.dart';
import '../../../core/progression/magic_slot_growth.dart';
import 'widgets/class_advancement_picker.dart';
import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/feature_service.dart';
import '../../../core/utils/localization_helper.dart';
import 'steps/hp_increase_step.dart';
import 'widgets/class_rules_review.dart';
import 'widgets/advancement_layout.dart';
import '../../../core/ui/sheet_drag_region.dart';
import 'steps/features_step.dart';
import 'steps/asi_step.dart';
import 'steps/summary_step.dart';
import '../../../core/progression/level_up_draft.dart';
import '../../../core/progression/character_class_rules.dart';
import '../../../core/progression/level_up_commit.dart';
import '../../../core/progression/resource_growth.dart';
import '../../../core/progression/advancement_choice_catalog.dart';
import '../../../core/progression/advancement_choice.dart';
import '../../../core/progression/feature_evolution.dart';
import '../../../core/progression/proficiency_identity.dart';
import '../../../core/progression/progression_catalog_stamp.dart';

class LevelUpScreen extends StatefulWidget {
  final Character character;
  final String? classId;
  final ClassData? newClass;
  final bool tableRuling;

  const LevelUpScreen(
      {super.key,
      required this.character,
      this.classId,
      this.newClass,
      this.tableRuling = false});

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<LevelUpScreen> {
  final PageController _pageController = PageController();

  late int _nextLevel;
  late ClassData _classData;
  late CharacterClassRules _rules;
  bool _pinningRules = false;
  String? _classSubclass;
  CharacterClassRules? _reviewedRules;
  bool _needsRuleReview = false;
  late LevelUpDraft _draft;
  late ProgressionCatalogStamp _catalog;
  int _hpDieValue = 1;
  bool _saving = false;
  int _currentStep = 0;
  String? _error;
  String? _entrySkill, _entryInstrument;
  Map<String, List<String>> _magicSelections = {};
  Map<String, int>? _manualSpellCounts;
  String? _replaceOld, _replaceNew;
  Map<String, String> _legacySources = {};
  Map<String, String> _automaticLegacySources = {};
  List<String> get _legacyChoices => _legacySpellIds
      .where((id) => !_automaticLegacySources.containsKey(id))
      .toList();
  List<String> get _legacySpellIds {
    final book = SpellbookState.read(widget.character.spellbookData);
    return _draft.classPreview.classes.length > 1
        ? {
            ...book.unassignedKnown(widget.character),
            ...book.unassignedPrepared(widget.character)
          }.toList()
        : [];
  }

  bool get _hasEntryTrainingStep =>
      widget.newClass != null &&
      {'bard', 'ranger', 'rogue'}.contains(_classData.id);

  // Step 1: HP
  int _hpIncrease = 0;
  int _conMod = 0;

  // Step 2: Features
  List<CharacterFeature> _newFeatures = [];
  List<CharacterFeature> _landOptions = []; // Store Land Druid options

  // Selections
  final Map<String, String> _selectedOptions = {};
  final Set<String> _selectedOptionalFeatureIds = {};
  final Set<String> _selectedExpertise = {};
  final Set<String> _selectedNewSkills = {};

  bool _hasAsi = false;
  Map<String, int> _asiAllocations = {};

  bool _isLoading = true;
  bool _showFeatureStep = true;

  @override
  void initState() {
    super.initState();
    _initializeLevelUp();
  }

  Future<void> _initializeLevelUp() async {
    // 1. Calculate levels
    _nextLevel = widget.character.level + 1;

    // 2. Get Class Data
    try {
      final selectedClass = widget.newClass != null
          ? CharacterClass(
              id: widget.newClass!.id,
              name: widget.newClass!.getName('en'),
              level: 0)
          : widget.character.classes.firstWhere(
              (c) =>
                  widget.classId != null ? c.id == widget.classId : c.isPrimary,
              orElse: () => widget.character.classes.first);
      if (widget.newClass != null &&
          !widget.tableRuling &&
          MulticlassRules.unmet(widget.character, selectedClass.id)
              .isNotEmpty) {
        throw StateError('prerequisites');
      }
      _pinningRules =
          selectedClass.rulesSnapshot == null || _reviewedRules != null;
      _rules = _reviewedRules ??
          (widget.newClass != null
              ? CharacterClassRules.capture(widget.newClass!)
              : CharacterClassRules.resolve(selectedClass));
      _classData = _rules.data;
      _classSubclass = selectedClass.subclass ??
          (selectedClass.isPrimary ? widget.character.subclass : null);
      if (!{'unknown', '2014'}.contains(_classData.rulesEdition)) {
        setState(() {
          _isLoading = false;
          _error = 'edition';
        });
        return;
      }
      if (classNeedsRuleReview(_classData)) {
        setState(() {
          _needsRuleReview = true;
          _isLoading = false;
        });
        return;
      }
      if (!_classData.declares('hitDie')) throw StateError('missing-hit-die');
      if (_classData.hitDie < 1 || _classData.hitDie > 1000) {
        throw StateError('hit-die');
      }
      _draft = LevelUpDraft.begin(widget.character,
          classId: selectedClass.id,
          newClassName: widget.newClass?.getName('en'));
      _catalog = ProgressionCatalogStamp.capture();
      _automaticLegacySources =
          LegacySpellAllocation.unambiguous(widget.character);
      _legacySources = {..._automaticLegacySources, ..._legacySources};
      try {
        MagicSlots.read(widget.character);
      } catch (_) {
        setState(() {
          _isLoading = false;
          _error = 'magicAllocation';
        });
        return;
      }
      _nextLevel = _draft.classLevelAfter;
    } catch (e) {
      // Handle error (shouldn't happen if data is intact)
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'source';
        });
      }
      return;
    }

    // 3. Calculate Stats
    _conMod = widget.character.abilityScores.constitutionModifier;

    // Default HP increase (Average)
    // Formula: (Hit Die / 2) + 1 + CON
    _hpIncrease = (_classData.hitDie ~/ 2) + 1 + _conMod;
    _hpDieValue = (_classData.hitDie ~/ 2) + 1;
    if (_hpIncrease < 1) _hpIncrease = 1; // Min 1 HP gain

    // 4. Find New Features
    final allFeatures = _rules.atLevel(_nextLevel, _classSubclass);
    _landOptions = _classData.id == 'druid'
        ? _rules.definitions
            .where((f) =>
                f.id.startsWith('circle-of-the-land-') &&
                f.minLevel == _nextLevel)
            .toList()
        : [];
    if (_landOptions.isNotEmpty) {
      allFeatures.removeWhere((f) => f.id.startsWith('circle-of-the-land-'));
    }

    if (widget.newClass != null &&
        widget.character.features.any((f) =>
            f.id == 'barbarian-unarmored-defense' ||
            f.id == 'monk-unarmored-defense')) {
      allFeatures.removeWhere((f) =>
          f.id == 'barbarian-unarmored-defense' ||
          f.id == 'monk-unarmored-defense');
    }
    _newFeatures = allFeatures;
    _hasAsi = _newFeatures.any(
      (f) => f.id.contains('ability-score-improvement'),
    );

    final visibleFeatures = _featuresForPage;
    final choices = AdvancementChoiceCatalog(_rules.definitions).forLevel(
        classId: _classData.id, level: _nextLevel, features: visibleFeatures);
    _showFeatureStep = visibleFeatures.isNotEmpty ||
        choices.isNotEmpty ||
        _landOptions.isNotEmpty ||
        _nextLevel == _classData.subclassLevel &&
            (_classData.declares('subclassLevel') ||
                _classData.subclasses.isNotEmpty) ||
        _classData.id == 'bard' && [3, 10].contains(_nextLevel) ||
        _classData.id == 'rogue' && [1, 6].contains(_nextLevel) ||
        _classData.id == 'ranger' && [6, 10, 14].contains(_nextLevel);

    setState(() {
      _isLoading = false;
    });
  }

  void _onHpRolled(int roll) {
    setState(() {
      _hpDieValue = roll;
      _hpIncrease = roll + _conMod;
      if (_hpIncrease < 1) _hpIncrease = 1;
    });
    _nextPage();
  }

  void _onHpAverageTaken() {
    setState(() {
      // Formula: (Hit Die / 2) + 1 + CON
      // Example d10: (10/2) + 1 = 6.
      int avgBase = (_classData.hitDie / 2).floor() + 1;
      _hpDieValue = avgBase;
      _hpIncrease = avgBase + _conMod;
      if (_hpIncrease < 1) _hpIncrease = 1;
    });
    _nextPage();
  }

  void _applyPrimalChampion(Character char) {
    final hasPrimalChampion = _newFeatures.any(
      (feature) => feature.id == 'primal-champion',
    );
    if (!hasPrimalChampion) return;

    final oldConMod = char.abilityScores.constitutionModifier;

    int increaseTo24(int value) =>
        value >= 24 ? value : (value + 4).clamp(0, 24);

    char.abilityScores = char.abilityScores.copyWith(
      strength: increaseTo24(char.abilityScores.strength),
      constitution: increaseTo24(char.abilityScores.constitution),
    );

    final newConMod = char.abilityScores.constitutionModifier;
    if (newConMod > oldConMod) {
      final hpBuf = (newConMod - oldConMod) * char.level;
      char.maxHp += hpBuf;
      // Current HP is preserved; development does not heal.
    }
  }

  void _nextPage() => _goTo(_currentStep + 1);

  Character _calculateResult() {
    if (_error == 'catalog' || !_catalog.isCurrent()) {
      throw StateError('catalogChanged');
    }
    if (_legacySources.values.any((source) =>
        source != 'manual' &&
        !widget.character.classes.any((c) => source == 'class:${c.id}'))) {
      throw StateError('Invalid spell source.');
    }
    if (!_legacySpellIds.every(_legacySources.containsKey)) {
      throw StateError('legacy-spell-sources');
    }
    final learning = _learningPlan;
    learning.validate(_magicSelections,
        replaceOld: _replaceOld, replaceNew: _replaceNew);
    if (_hasAsi &&
        (_asiAllocations.values.fold<int>(0, (sum, n) => sum + n) != 2 ||
            _asiAllocations.values.any((n) => n < 0 || n > 2))) {
      throw StateError('Incomplete ability score choice.');
    }
    final expertiseRequired =
        _classData.id == 'bard' && [3, 10].contains(_nextLevel) ||
            _classData.id == 'rogue' && [1, 6].contains(_nextLevel);
    if (expertiseRequired &&
        (_selectedExpertise.length != 2 ||
            _selectedExpertise.any((id) =>
                !ProficiencyIdentity.contains([
                      ...widget.character.proficientSkills,
                      ..._selectedNewSkills,
                      if (_entrySkill != null) _entrySkill!
                    ], id) &&
                    !(id == 'thieves-tools' && _classData.id == 'rogue') ||
                ProficiencyIdentity.contains(
                    widget.character.expertSkills, id)))) {
      throw StateError('Incomplete expertise choice.');
    }
    final char = _draft.classPreview;
    if (widget.newClass != null) {
      if (!widget.tableRuling &&
          MulticlassRules.unmet(widget.character, _classData.id).isNotEmpty) {
        throw StateError('prerequisites');
      }
      final entry = char.classes.singleWhere((c) => c.id == _classData.id);
      entry.entryProficiencies = [
        for (final token
            in MulticlassRules.entryTraining[_classData.id] ?? <String>[])
          if (!token.contains('choose')) token,
        if (_entryInstrument?.trim().isNotEmpty ?? false)
          'instrument:${_entryInstrument!.trim()}'
      ];
      if (_hasEntryTrainingStep) {
        final candidates = (_classData.id == 'bard'
                ? AdvancementChoiceCatalog.skillIds
                : _classData.skillProficiencies.from)
            .where((id) => !ProficiencyIdentity.contains(
                widget.character.proficientSkills, id))
            .toList();
        if (candidates.isNotEmpty &&
            (_entrySkill == null || !candidates.contains(_entrySkill))) {
          throw StateError('entry-skill');
        }
        if (_classData.id == 'bard' &&
            (_entryInstrument?.trim().isEmpty ?? true)) {
          throw StateError('entry-instrument');
        }
        if (_entrySkill != null) {
          char.proficientSkills =
              {...char.proficientSkills, _entrySkill!}.toList();
        }
      }
    }
    _rules.attachTo(char.classes.singleWhere((c) => c.id == _draft.classId));
    final previousCdMaximum = widget.character.getMaxChannelDivinityCharges();
    final previousCd = widget.character.editableChannelDivinityCharges;
    // Class and overall levels were advanced once in the detached draft.
    char.hitDice =
        MulticlassRules.advanceHitDice(widget.character, _classData.id);
    char.maxHitDice = widget.character.maxHitDice + 1;

    // 2.5 Apply Ability Score Improvements and Retroactive HP
    if (_hasAsi && _asiAllocations.isNotEmpty) {
      final oldConMod = char.abilityScores.constitutionModifier;

      char.abilityScores = char.abilityScores.copyWith(
        strength:
            char.abilityScores.strength + (_asiAllocations['strength'] ?? 0),
        dexterity:
            char.abilityScores.dexterity + (_asiAllocations['dexterity'] ?? 0),
        constitution: char.abilityScores.constitution +
            (_asiAllocations['constitution'] ?? 0),
        intelligence: char.abilityScores.intelligence +
            (_asiAllocations['intelligence'] ?? 0),
        wisdom: char.abilityScores.wisdom + (_asiAllocations['wisdom'] ?? 0),
        charisma:
            char.abilityScores.charisma + (_asiAllocations['charisma'] ?? 0),
      );

      final newConMod = char.abilityScores.constitutionModifier;
      if (newConMod > oldConMod) {
        final hpBuf = (newConMod - oldConMod) * char.level;
        char.maxHp += hpBuf;
        // Current HP is preserved; development does not heal.
      }
    }

    // 3. Apply Choices
    if (_selectedOptions.containsKey('subclass')) {
      final subclassId = _selectedOptions['subclass'];
      final subclass = _classData.subclasses.firstWhere(
        (s) => s.id == subclassId,
      );
      final classEntry =
          char.classes.singleWhere((c) => c.id == _draft.classId);
      classEntry.subclass = subclass.id;
      if (classEntry.isPrimary) char.subclass = subclass.getName('en');
    }

    if (_selectedOptions.containsKey('fighting_style')) {
      final styleId = _selectedOptions['fighting_style']!;
      final l10n = AppLocalizations.of(context)!;
      final locFeat = LocalizationHelper.getLocalizedFightingStyle(
        styleId,
        l10n,
      );

      // Add as a pseudo-feature
      char.features.add(
        CharacterFeature(
          id: 'fs_$styleId',
          nameEn: locFeat.name,
          nameRu: locFeat.name,
          descriptionEn: locFeat.description,
          descriptionRu: locFeat.description,
          type: FeatureType.passive,
          minLevel: _nextLevel,
          associatedClass: _classData.id,
        ),
      );
    }

    // Ranger Options
    if (_selectedOptions.containsKey('favored_enemy')) {
      char.favoredEnemies.add(_selectedOptions['favored_enemy']!);
    }
    if (_selectedOptions.containsKey('natural_explorer')) {
      char.naturalExplorers.add(_selectedOptions['natural_explorer']!);
    }
    final tacticTiers = [
      ['colossus', 'giant', 'horde'],
      ['escape', 'multiattack', 'steel'],
      ['volley', 'whirlwind'],
      ['evasion', 'stand', 'uncanny'],
    ];

    if (_selectedOptions.containsKey('hunter_tactic')) {
      final chosenIdStr =
          (_selectedOptions['hunter_tactic'] as String).toLowerCase();

      // Find the active tier for this tactic
      List<String>? activeTier;
      for (final tier in tacticTiers) {
        if (tier.any((kw) => chosenIdStr.contains(kw))) {
          activeTier = tier;
          break;
        }
      }

      if (activeTier != null) {
        // Surgically remove ONLY from char.features for the matching tier
        char.features.removeWhere((f) {
          final fId = (f.id).toLowerCase();
          return activeTier!.any(
            (kw) =>
                fId.contains(kw) ||
                fId.replaceAll('-', '').replaceAll('_', '').contains(kw),
          );
        });

        // Add the new valid tactic object directly
        _newFeatures.removeWhere((f) {
          final fId = (f.id).toLowerCase();
          return activeTier!.any(
            (kw) =>
                fId.contains(kw) ||
                fId.replaceAll('-', '').replaceAll('_', '').contains(kw),
          );
        });

        // 1. First try the standard FeatureService just in case
        CharacterFeature? fullyLoadedTactic = _rules.feature(
          chosenIdStr,
        );

        // 2. If not found, look inside the FeatureService's loaded cache
        // Some tactic IDs have prefix issues or slight mismatches from what is saved in features_step
        if (fullyLoadedTactic == null) {
          final allFeatures = _rules.definitions;
          for (final f in allFeatures) {
            final fId = (f.id).toLowerCase();
            if (fId == chosenIdStr ||
                fId.endsWith(chosenIdStr) ||
                fId.contains(chosenIdStr)) {
              fullyLoadedTactic = f;
              break;
            }
          }
        }

        // 3. Fallback: Search in _newFeatures in case it was already dynamically added
        if (fullyLoadedTactic == null) {
          try {
            fullyLoadedTactic = _newFeatures.firstWhere(
              (f) => (f.id).toLowerCase() == chosenIdStr,
            );
          } catch (_) {}
        }

        if (fullyLoadedTactic != null) {
          if (!char.features.any((f) => f.id == fullyLoadedTactic!.id)) {
            char.features.add(fullyLoadedTactic.copyForCharacter());
          }
        } else {
          debugPrint('CRITICAL ERROR: Tactic NOT FOUND anywhere: $chosenIdStr');
        }
      }
    } else {
      // If we are passing a level without a tactic choice, we shouldn't strip anything.
      // E.g. at level 4 we don't choose, so we don't strip level 3.
      // The previous logic was aggressively stripping.
    }

    // Circle of the Land Selection
    if (_selectedOptions.containsKey('land_terrain')) {
      final terrainId = _selectedOptions['land_terrain'];
      final feature = _landOptions.firstWhere(
        (f) => f.id == terrainId,
        orElse: () => _landOptions.first,
      );
      char.features.add(feature.copyForCharacter());

      // Also add base "Natural Recovery" if not present
      if (!char.features.any((f) => f.id == 'natural-recovery')) {
        final natRec = _rules.feature('natural-recovery');
        if (natRec != null) char.features.add(natRec.copyForCharacter());
      }
    }

    char.proficientSkills =
        {...char.proficientSkills, ..._selectedNewSkills}.toList();
    if (_selectedExpertise.isNotEmpty) {
      char.expertSkills =
          {...char.expertSkills, ..._selectedExpertise}.toList();
    }
    // Variant features are applied only after a valid explicit selection.
    final definitions = [
      ..._rules.definitions,
      ..._classData.features.values.expand((f) => f)
    ];
    final selectedSubclassFeatures = _selectedOptions.containsKey('subclass')
        ? _rules.atLevel(_nextLevel, _selectedOptions['subclass'])
        : <CharacterFeature>[];
    final choices = AdvancementChoiceCatalog(definitions).forLevel(
        classId: _classData.id,
        level: _nextLevel,
        features: [..._newFeatures, ...selectedSubclassFeatures]);
    for (final choice in choices) {
      if (choice.kind == AdvancementChoiceKind.skillProficiency) {
        // Validate against the original, before applying the new skill set.
        if (!choice.isSatisfied(
            _selectedNewSkills, widget.character, _nextLevel)) {
          throw StateError('Incomplete skill choice.');
        }
      } else {
        final selected = choice.options
            .map((o) => o.id)
            .where(_selectedOptionalFeatureIds.contains)
            .toList();
        choice.applyTo(char, selected, _nextLevel);
      }
    }
    if (_selectedOptions.containsKey('pact_boon')) {
      final id = _selectedOptions['pact_boon']!.replaceAll('_', '-');
      final definition = _rules.feature(id);
      if (definition == null) throw StateError('Missing Pact Boon definition.');
      if (!char.hasFeatureId(id)) {
        char.features.add(definition.copyForCharacter());
      }
    }

    // 4. Add Features
    // We explicitly call addFeaturesToCharacter once to capture all strictly available features
    // IMPORTANT: FeaturesService might still try to add the land features if we don't handle them carefully.
    // Ideally we should rely on _newFeatures logic, but addFeaturesToCharacter recalculates from scratch.
    // We need to temporarily "hide" the land options from FeatureService or filter them post-add.
    // Actually, FeatureService.addFeaturesToCharacter uses getFeaturesForCharacter which checks subclass.
    // Since subclass IS "Land", it will add them ALL.
    // We must manually add ONLY the features in _newFeatures and our choices, instead of calling FeatureService.addFeaturesToCharacter.
    // OR we let FeatureService add them and then remove the unwanted ones.
    // Cleaner: Iterate _newFeatures and add them.

    // Adding standard features manually to avoid auto-adding all land options
    for (var feature in _newFeatures) {
      if (feature.isOptional &&
          !_selectedOptionalFeatureIds.contains(feature.id)) {
        continue;
      }
      if (feature.id.toLowerCase().contains('slayer') ||
          feature.id.toLowerCase().contains('killer') ||
          feature.id.toLowerCase().contains('horde')) {
        debugPrint(
          'DIAGNOSTICS: _newFeatures loop is trying to add tactic: ${feature.id}',
        );
      }
      // Check duplication
      if (!char.features
          .any((f) => f.id == feature.id && f.minLevel >= feature.minLevel)) {
        FeatureEvolution.acquire(char.features, feature,
            referenceFor: _rules.feature);
        if (feature.id.toLowerCase().contains('slayer') ||
            feature.id.toLowerCase().contains('killer') ||
            feature.id.toLowerCase().contains('horde')) {
          debugPrint(
            'DIAGNOSTICS: _newFeatures loop SUCCESSFULLY ADDED tactic: ${feature.id}',
          );
        }
      }
    }

    // NOTE: FeatureService.addFeaturesToCharacter(char) is dangerous here for Druids.
    // We will skip it and rely on _newFeatures which we filtered.

    // Explicitly reload features to catch subclass features if subclass was just set
    if (_selectedOptions.containsKey('subclass')) {
      final newSubclassId = _selectedOptions['subclass']!;

      // Fetch subclass features specifically for this newly chosen subclass at the current level
      final subclassFeatures = _rules
          .atLevel(_nextLevel, newSubclassId)
          .where((f) => f.associatedSubclass != null)
          .toList();

      // --- UNIVERSAL DATA-DRIVEN PRUNING LOGIC ---
      // 1. Build a pool of all known optional feature IDs for this subclass.
      // This allows the system to remain agnostic of specific classes or features (OCP).
      final Set<String> optionalFeaturesPool = {};
      for (var feature in subclassFeatures) {
        if (feature.options != null && feature.options!.isNotEmpty) {
          optionalFeaturesPool.addAll(feature.options!);
        }
      }

      // 2. Iterate and add features, filtering out unselected options.
      for (var feature in subclassFeatures) {
        final fId = feature.id;
        if (feature.isOptional && !_selectedOptionalFeatureIds.contains(fId)) {
          continue;
        }

        // If the feature is known to be an option (it exists in our pool),
        // we ONLY add it if the user explicitly selected its exact ID.
        if (optionalFeaturesPool.contains(fId)) {
          if (!_selectedOptions.values.contains(fId)) {
            continue; // Skip because it wasn't selected
          }
        }

        if (!char.features.any((f) => f.id == feature.id)) {
          char.features.add(feature.copyForCharacter());
        }
      }

      // Note: Druid Land choice is handled separately above
    }

    _applyPrimalChampion(char);
    _draft.chooseHealth(_hpDieValue, abilityScores: char.abilityScores);
    char.maxHp = _draft.preview.maxHp;
    char.currentHp = widget.character.currentHp;
    if (_classData.id == 'sorcerer' &&
        char.hasFeatureId('draconic-resilience')) {
      char.maxHp++;
    }
    final previousPools = {
      for (final feature in widget.character.features)
        if (feature.resourcePool != null) FeatureEvolution.key(feature): feature
    };
    FeatureService.updateFeatureMaxUses(char);
    for (final feature in char.features) {
      final pool = feature.resourcePool;
      final before = previousPools[FeatureEvolution.key(feature)];
      if (pool != null && before != null) {
        final previousPool = before.resourcePool!;
        final oldDefinitions = _classData.features.entries
            .where((entry) => entry.key <= _draft.classLevelBefore)
            .expand((entry) => entry.value)
            .where((f) => f.id == before.id)
            .toList()
          ..sort((a, b) => b.minLevel.compareTo(a.minLevel));
        final declaredReference =
            oldDefinitions.firstOrNull ?? _rules.feature(before.id);
        final oldReference = previousPool.calculationFormula != null
            ? FeatureService.tryCalculateMaxUses(
                widget.character, previousPool.calculationFormula,
                classId: before.associatedClass)
            : declaredReference?.resourcePool?.maxUses;
        final legacySorcery = before.sourceId == null &&
            {
              'sorcerer_points',
              'sorcery_points',
              'sorcery-points',
              'font-of-magic',
              'font_of_magic'
            }.contains(before.id) &&
            widget.character.classLevel('sorcerer') >= 2;
        final previousReference = legacySorcery
            ? widget.character.classLevel('sorcerer')
            : oldReference;
        final newReference =
            legacySorcery ? char.classLevel('sorcerer') : pool.maxUses;
        pool.maxUses = previousReference == null
            ? previousPool.maxUses
            : ResourceGrowth.remaining(
                current: previousPool.maxUses,
                oldMaximum: previousReference,
                newMaximum: newReference);
        pool.currentUses = ResourceGrowth.remaining(
            current: previousPool.currentUses,
            oldMaximum: previousPool.maxUses,
            newMaximum: pool.maxUses);
      } else if (pool != null) {
        pool.currentUses = pool.maxUses;
      }
    }
    if (char.channelDivinityResources.isNotEmpty) {
      char.setChannelDivinityCharges(ResourceGrowth.remaining(
          current: previousCd,
          oldMaximum: previousCdMaximum,
          newMaximum: char.getMaxChannelDivinityCharges()));
    }
    char.recalculateAC();

    final book = SpellbookState.read(char.spellbookData);
    for (final id in _legacySpellIds) {
      final source = _legacySources[id]!;
      book.setKnown(source, id, true);
      if (widget.character.preparedSpells.contains(id)) {
        book.setPrepared(source, id, true);
      }
    }
    char.spellbookData = book.toJson();
    learning.apply(char, _magicSelections,
        replaceOld: _replaceOld, replaceNew: _replaceNew);
    ClassSpellGrants.apply(char, _classData.id);
    MagicSlotGrowth.advance(widget.character, char);

    return char;
  }

  Future<void> _finishLevelUp() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = _calculateResult();
      await LevelUpCommit.apply(widget.character,
          baseline: _draft,
          result: result,
          validateContext: _catalog.verifyContent);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is StateError && error.message == 'catalogChanged'
              ? 'catalog'
              : 'save';
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<CharacterFeature> get _featuresForPage => _newFeatures.where((feature) {
        if (feature.options?.isNotEmpty == true) return true;
        if (feature.id.contains('ability-score-improvement')) return false;
        if (_classData.id == 'wizard' &&
            [18, 20].contains(_nextLevel) &&
            (feature.id.contains('spell-mastery') ||
                feature.id.contains('signature-spell'))) {
          return false;
        }
        return true;
      }).toList();

  Character get _magicContext {
    final char = _draft.classPreview;
    final entry = char.classes.singleWhere((c) => c.id == _classData.id);
    _rules.attachTo(entry);
    if (_selectedOptions['subclass'] != null) {
      entry.subclass = _selectedOptions['subclass'];
    }
    final boon = _selectedOptions['pact_boon']?.replaceAll('_', '-');
    if (boon != null) {
      final feature = _rules.feature(boon);
      if (feature != null && !char.hasFeatureId(boon)) {
        char.features.add(feature.copyForCharacter());
      }
    }
    for (final id in _selectedOptionalFeatureIds) {
      final f = _rules.feature(id);
      if (f != null && !char.hasFeatureId(id)) {
        char.features.add(f.copyForCharacter());
      }
    }
    final terrain = _selectedOptions['land_terrain'];
    if (terrain != null) {
      final f = _rules.feature(terrain);
      if (f != null && !char.hasFeatureId(terrain)) {
        char.features.add(f.copyForCharacter());
      }
    }
    return char;
  }

  Character get _learningBefore {
    final before = QdndBundleCodec.cloneCharacter(widget.character),
        book = SpellbookState.read(widget.character.spellbookData);
    for (final id in _legacySpellIds) {
      final source = _legacySources[id];
      if (source == null) continue;
      book.setKnown(source, id, true);
      if (widget.character.preparedSpells.contains(id)) {
        book.setPrepared(source, id, true);
      }
    }
    before.spellbookData = book.toJson();
    return before;
  }

  SpellLearningPlan get _learningPlan => SpellLearningPlan.forAdvance(
      _learningBefore, _magicContext, _classData.id,
      pending: [...?_magicSelections['normal'], ...?_magicSelections['secret']],
      manualCounts: _manualSpellCounts);
  bool get _hasMagicStep =>
      _classData.spellcasting != null ||
      _learningPlan.choices.isNotEmpty ||
      _learningPlan.needsManualCounts;

  Character get _choiceCharacter {
    final char = _draft.classPreview;
    char.subclass = _classSubclass;
    if (_entrySkill != null) {
      char.proficientSkills = {...char.proficientSkills, _entrySkill!}.toList();
    }
    return char;
  }

  FeaturesStep _choices(FeaturesStepContent content) => FeaturesStep(
        key: ValueKey(content),
        content: content,
        character:
            _choiceCharacter, // Own subclass; other classes never leak into choices.
        newFeatures: content == FeaturesStepContent.features
            ? _featuresForPage
            : _newFeatures,
        landOptions: _landOptions, // Pass land options
        newSpellSlots: const [],
        oldSpellSlots: const [],
        classData: _classData,
        rules: _rules,
        pinningRules: _pinningRules,
        nextLevel: _nextLevel,
        spellsToLearnCount: 0,
        onOptionSelected: (featureId, optionId) {
          setState(() {
            _selectedOptions[featureId] = optionId;
          });
        },
        onExpertiseChanged: (expertSkills) {
          setState(() {
            _selectedExpertise.clear();
            _selectedExpertise.addAll(expertSkills);
          });
        },
        onSkillProficienciesChanged: (skills) {
          setState(() {
            _selectedNewSkills
              ..clear()
              ..addAll(skills);
          });
        },
        onOptionalFeaturesChanged: (featureIds) {
          setState(() {
            _selectedOptionalFeatureIds
              ..clear()
              ..addAll(featureIds);
          });
        },
        onSpellsSelected: (_) {},
        onMasterySpellsSelected: (_) {},
        onSignatureSpellsSelected: (_) {},
        onNext: _nextPage,
      );

  void _goTo(int index) {
    FocusScope.of(context).unfocus();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
      return;
    }
    _pageController.animateToPage(index,
        duration: Duration(
            milliseconds:
                300 + 50 * ((index - _currentStep).abs() - 1).clamp(0, 3)),
        curve: Curves.easeInOutCubic);
  }

  Future<void> _chooseClass() async {
    final target = await chooseAdvancementClass(context, widget.character);
    if (!mounted || target == null) return;
    final exists = widget.character.classes.any((c) => c.id == target.data.id);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => LevelUpScreen(
            character: widget.character,
            classId: target.data.id,
            newClass: exists ? null : target.data,
            tableRuling: target.tableRuling)));
  }

  void _showRules() {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final l10n = AppLocalizations.of(context)!;
    showResponsiveSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.advancementRulesTitle,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(_classData.getName(ru ? 'ru' : 'en'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(_pinningRules
                      ? (ru
                          ? 'Эти правила класса сохранятся с героем после подтверждения повышения. Удаление книги их не заменит.'
                          : 'These class rules will be saved with your character when you confirm. Removing a book will not replace them.')
                      : (ru
                          ? 'Используются сохранённые правила класса. Подключение новых книг не меняет их автоматически.'
                          : 'Uses your character’s saved class rules. New books do not change them automatically.')),
                  const SizedBox(height: 12),
                  Text('D&D ${_classData.rulesEdition}',
                      style: Theme.of(context).textTheme.labelLarge),
                ])));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_needsRuleReview) {
      return Scaffold(
          appBar: AppBar(),
          body: ClassRulesReview(
              data: _classData,
              onResolved: (data) {
                setState(() {
                  _reviewedRules = CharacterClassRules.capture(data);
                  _needsRuleReview = false;
                  _isLoading = true;
                });
                _initializeLevelUp();
              }));
    }

    if (_error == 'magicAllocation') {
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      return Scaffold(
          appBar: AppBar(),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(ru
                        ? 'Сначала уточни запасы старого листа: общие ячейки и Магию договора. Повышение ещё не применено.'
                        : 'First resolve the older sheet’s shared and Pact pools. Advancement has not been applied.'),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: () async {
                          final changed = await showMagicAllocationSheet(
                              context, widget.character);
                          if (mounted && changed) {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            _initializeLevelUp();
                          }
                        },
                        child: Text(
                            ru ? 'Уточнить запасы' : 'Resolve spell pools')),
                  ]))));
    }
    if (_error == 'source' || _error == 'multiclass' || _error == 'edition') {
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      return Scaffold(
          appBar: AppBar(),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error == 'edition'
                      ? (ru
                          ? 'Повышение по этой редакции правил пока недоступно. Изменения не применены.'
                          : 'This rules edition is not yet supported for levelling. No changes have been applied.')
                      : _error == 'multiclass'
                          ? (ru
                              ? 'Повышение для сочетания этих классов ещё не готово. Герой не изменён.'
                              : 'Development for this combination of classes is not yet supported. The character has not changed.')
                          : ru
                              ? 'Для повышения не хватает данных класса или уровни классов не согласованы. Герой не изменён.'
                              : 'Class data is missing or class levels disagree. The character has not changed.'))));
    }
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;

    final route = [
      if (_legacyChoices.isNotEmpty)
        locale == 'ru' ? 'Чьи заклинания?' : 'Spell origins',
      if (_hasEntryTrainingStep) locale == 'ru' ? 'Владения' : 'Proficiencies',
      locale == 'ru' ? 'ОЗ' : 'HP',
      if (_showFeatureStep) l10n.advancementRouteFeatures,
      if (_hasMagicStep) l10n.advancementRouteMagic,
      if (_hasAsi) l10n.advancementRouteAbilities,
      l10n.advancementRouteReview
    ];
    return PopScope(
        canPop: !_saving && _currentStep == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !_saving && _currentStep > 0) _goTo(_currentStep - 1);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Row(children: [
              Expanded(
                  child: Text(_classData.getName(locale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              Text('${_draft.classLevelBefore} → ${_draft.classLevelAfter}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.primary)),
            ]),
            actions: [
              IconButton(
                  key: const ValueKey('advancement-choose-class'),
                  tooltip: locale == 'ru'
                      ? 'Выбрать класс повышения'
                      : 'Choose advancement class',
                  icon: const Icon(Icons.swap_horiz_rounded),
                  onPressed: _saving ? null : _chooseClass),
              IconButton(
                  tooltip: l10n.advancementRulesTitle,
                  icon: const Icon(Icons.auto_stories_outlined),
                  onPressed: _saving ? null : _showRules),
              if (_currentStep > 0)
                IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: l10n.cancel,
                    onPressed: _saving ? null : () => Navigator.pop(context)),
            ],
            leading: IconButton(
              icon: Icon(
                  _currentStep == 0 ? Icons.close : Icons.arrow_back_rounded),
              onPressed: _saving
                  ? null
                  : () {
                      if (_currentStep == 0) {
                        Navigator.pop(context);
                      } else {
                        _goTo(_currentStep - 1);
                      }
                    },
            ),
          ),
          body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(children: [
                    AdvancementRoute(
                        labels: route,
                        current: _currentStep,
                        enabled: !_saving,
                        onBackTo: _goTo),
                    Expanded(
                        child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) =>
                          setState(() => _currentStep = index),
                      physics:
                          const NeverScrollableScrollPhysics(), // Disable swipe
                      children: [
                        if (_legacyChoices.isNotEmpty)
                          LegacySpellSourcesStep(
                              before: widget.character,
                              preview: _magicContext,
                              ids: _legacyChoices,
                              selected: _legacySources,
                              onChanged: (v) => setState(() => _legacySources =
                                  {..._automaticLegacySources, ...v}),
                              onNext: _nextPage),
                        if (_hasEntryTrainingStep)
                          EntryTrainingStep(
                              hero: widget.character,
                              data: _classData,
                              skill: _entrySkill,
                              instrument: _entryInstrument,
                              onSkill: (v) => setState(() => _entrySkill = v),
                              onInstrument: (v) =>
                                  setState(() => _entryInstrument = v),
                              onNext: _nextPage),
                        HpIncreaseStep(
                          hitDie: _classData.hitDie,
                          conMod: _conMod,
                          onRoll: _onHpRolled,
                          onAverage: _onHpAverageTaken,
                          currentHp: widget.character.currentHp,
                          maximumHp: widget.character.maxHp,
                          additionalHpLabel: _rules
                              .feature('draconic-resilience')
                              ?.getName(locale),
                          additionalHp: _classData.id == 'sorcerer' &&
                                  widget.character
                                      .hasFeatureId('draconic-resilience')
                              ? 1
                              : 0,
                        ),
                        if (_showFeatureStep)
                          _choices(FeaturesStepContent.features),
                        if (_hasMagicStep)
                          ClassMagicStep(
                              key: const ValueKey(FeaturesStepContent.magic),
                              plan: _learningPlan,
                              selected: _magicSelections,
                              onChanged: (v) =>
                                  setState(() => _magicSelections = v),
                              onNext: _nextPage,
                              replaceOld: _replaceOld,
                              replaceNew: _replaceNew,
                              onReplace: (a, b) => setState(() {
                                    _replaceOld = a;
                                    _replaceNew = b;
                                  }),
                              manualCounts: _manualSpellCounts,
                              onManualCounts: (v) =>
                                  setState(() => _manualSpellCounts = v)),
                        if (_hasAsi)
                          AsiStep(
                            currentScores: widget.character.abilityScores,
                            onAllocationChanged: (allocs) {
                              setState(() => _asiAllocations = allocs);
                            },
                            onNext: _nextPage,
                          ),
                        SummaryStep(
                          character: widget.character,
                          nextLevel: _draft.characterLevelAfter,
                          hpIncrease: _hpIncrease,
                          newFeatures: _newFeatures
                              .where((feature) =>
                                  !feature.isOptional ||
                                  _selectedOptionalFeatureIds
                                      .contains(feature.id))
                              .toList(growable: false),
                          onConfirm: _finishLevelUp,
                          previewBuilder: _calculateResult,
                          saving: _saving,
                          unavailableMessage: (_error == 'catalog' ||
                                  !_catalog.isCurrent())
                              ? (locale == 'ru'
                                  ? 'Источники изменились во время выбора. Закрой повышение и открой его заново, чтобы проверить обновлённые варианты. Герой не изменён.'
                                  : 'Sources changed during development. Close and reopen it to review the updated choices. Your character is unchanged.')
                              : null,
                          error: _error == 'save'
                              ? (locale == 'ru'
                                  ? 'Не удалось сохранить повышение. Герой сохранён в прежнем состоянии. Можно повторить попытку.'
                                  : 'Could not save development. The original character is preserved. You can retry.')
                              : null,
                        ),
                      ],
                    )),
                  ]))),
        ));
  }
}
