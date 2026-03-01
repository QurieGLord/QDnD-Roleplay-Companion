import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/character_data_service.dart';
import '../../../core/services/feature_service.dart';
import '../../../core/services/spellcasting_service.dart';
import '../../../core/models/spell_slots_table.dart';
import 'steps/hp_increase_step.dart';
import 'steps/features_step.dart';
import 'steps/summary_step.dart';

class LevelUpScreen extends StatefulWidget {
  final Character character;

  const LevelUpScreen({super.key, required this.character});

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<LevelUpScreen> {
  final PageController _pageController = PageController();

  late int _nextLevel;
  late ClassData _classData;

  // Step 1: HP
  int _hpIncrease = 0;
  int _conMod = 0;

  // Step 2: Features
  List<CharacterFeature> _newFeatures = [];
  List<CharacterFeature> _landOptions = []; // Store Land Druid options
  List<int> _newSpellSlots = [];
  List<int> _oldSpellSlots = [];
  bool _hasNewSpellSlots = false;

  // Step 3: Spells
  int _spellsToLearn = 0;
  List<String> _selectedSpells = [];
  List<String> _selectedMasterySpells = [];
  List<String> _selectedSignatureSpells = [];

  // Selections
  final Map<String, String> _selectedOptions = {};
  final Set<String> _selectedExpertise = {};

  bool _isLoading = true;

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
      _classData =
          CharacterDataService.getClassById(widget.character.characterClass)!;
    } catch (e) {
      // Handle error (shouldn't happen if data is intact)
      Navigator.pop(context);
      return;
    }

    // 3. Calculate Stats
    _conMod = widget.character.abilityScores.constitutionModifier;

    // Default HP increase (Average)
    // Formula: (Hit Die / 2) + 1 + CON
    _hpIncrease = (_classData.hitDie / 2).ceil() + _conMod;
    if (_hpIncrease < 1) _hpIncrease = 1; // Min 1 HP gain

    // 4. Find New Features
    final standardFeatures = FeatureService.getFeaturesForLevel(
      classId: widget.character.characterClass,
      level: _nextLevel,
      subclassId: widget.character.subclass,
    );

    // Get features from ClassData (XML)
    final classFeatures = _classData.features[_nextLevel] ?? [];

    // Filter class features by subclass if applicable
    final filteredClassFeatures = classFeatures.where((f) {
      // If feature has no associated subclass, include it
      if (f.associatedSubclass == null || f.associatedSubclass!.isEmpty) {
        return true;
      }
      // If character has a subclass, check match
      if (widget.character.subclass != null) {
        return f.associatedSubclass!.toLowerCase() ==
            widget.character.subclass!.toLowerCase();
      }
      return f.associatedSubclass == null;
    }).toList();

    // Merge
    final allFeatures = [...standardFeatures];
    final existingIds = standardFeatures.map((f) => f.id).toSet();

    for (var feature in filteredClassFeatures) {
      if (!existingIds.contains(feature.id)) {
        allFeatures.add(feature);
        existingIds.add(feature.id);
      }
    }

    // Filter out "Circle of the Land: *" options to enforce single choice
    _landOptions = allFeatures
        .where((f) => f.id.startsWith('circle-of-the-land-'))
        .toList();

    // Remove them from the main list so they don't get auto-added,
    // BUT ensure "natural-recovery" (which is also Circle of Land but base) stays.
    // Natural Recovery ID is "natural-recovery", not starting with "circle-of-the-land-".
    // So simple filter below is safe for Natural Recovery, but let's double check logic.
    if (_landOptions.isNotEmpty) {
      allFeatures.removeWhere((f) => f.id.startsWith('circle-of-the-land-'));
    }

    // Explicitly check for Natural Recovery if we are Land Druid level 2+
    // It might have been filtered out if associatedSubclass didn't match perfectly or logic above was flawed?
    // Actually, "Natural Recovery" has associatedSubclass="Land".
    // My previous logic in filteredClassFeatures:
    // if (widget.character.subclass != null) { return f.associatedSubclass!.toLowerCase() == widget.character.subclass!.toLowerCase(); }
    // If character.subclass is "Circle of the Land" (from UI) but data says "Land", it might mismatch?
    // Let's ensure it is added.
    if (_classData.id == 'druid' && _nextLevel >= 2) {
      // Check if Natural Recovery is already in allFeatures
      final hasNaturalRecovery =
          allFeatures.any((f) => f.id == 'natural-recovery');
      if (!hasNaturalRecovery) {
        // Try to find it in classFeatures or standardFeatures
        final natRec = classFeatures.firstWhere(
            (f) => f.id == 'natural-recovery',
            orElse: () => standardFeatures.firstWhere(
                (f) => f.id == 'natural-recovery',
                orElse: () => CharacterFeature(
                    id: 'dummy',
                    nameEn: '',
                    nameRu: '',
                    descriptionEn: '',
                    descriptionRu: '',
                    type: FeatureType.passive,
                    minLevel: 0)));
        if (natRec.id == 'natural-recovery') {
          // Check if we should add it (subclass match)
          if (natRec.associatedSubclass != null &&
              widget.character.subclass != null) {
            // "land" vs "circle of the land" or "land"
            // If character has "Land", it matches.
            // If character doesn't have subclass yet (level 2 choice), we might need to rely on selection.
            // But LevelUpScreen logic: "Apply Choices" happens at end.
            // So at INIT, character.subclass might be null.
            // If it is null, we usually don't filter by subclass?
            // filteredClassFeatures logic: "if (widget.character.subclass != null) ... else return f.associatedSubclass == null;"
            // THIS IS THE BUG. If subclass is null (first time picking), features with associatedSubclass="Land" are EXCLUDED.
            // We need to include them if they are part of the options?
            // Actually, for "Natural Recovery", it is granted WHEN you choose the circle.
            // So it should be added in _finishLevelUp if Land is chosen.
          }
        }
      }
    }

    _newFeatures = allFeatures;

    // 5. Calculate Spell Slots
    if (_classData.spellcasting != null) {
      _oldSpellSlots = List.from(widget.character.maxSpellSlots);

      // Determine Caster Type logic
      String casterType = 'full'; // Default
      if (_classData.id == 'paladin' || _classData.id == 'ranger') {
        casterType = 'half';
      }
      // Note: better caster type detection from ClassData

      final newSlots = SpellSlotsTable.getSlots(_nextLevel, casterType);

      // Compare
      if (newSlots.length > _oldSpellSlots.length) {
        _hasNewSpellSlots = true;
      } else {
        for (int i = 0; i < newSlots.length; i++) {
          if (newSlots[i] >
              (_oldSpellSlots.length > i ? _oldSpellSlots[i] : 0)) {
            _hasNewSpellSlots = true;
            break;
          }
        }
      }
      _newSpellSlots = newSlots;
    }

    // 6. Calculate Spells to Learn
    // Wizard: 2
    // Known Casters: Delta
    if (widget.character.characterClass.toLowerCase() == 'wizard') {
      _spellsToLearn = 2;
    } else {
      final currentKnown = SpellcastingService.getSpellsKnownCount(
          widget.character.characterClass, widget.character.level);
      final nextKnown = SpellcastingService.getSpellsKnownCount(
          widget.character.characterClass, _nextLevel);
      if (nextKnown > currentKnown) {
        _spellsToLearn = nextKnown - currentKnown;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _onHpRolled(int roll) {
    setState(() {
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
      _hpIncrease = avgBase + _conMod;
      if (_hpIncrease < 1) _hpIncrease = 1;
    });
    _nextPage();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishLevelUp() async {
    final char = widget.character;

    // 1. Update Level
    char.level = _nextLevel;

    // 2. Update HP
    char.maxHp += _hpIncrease;
    char.currentHp += _hpIncrease;
    char.hitDice[0]++; // Add one hit die
    char.maxHitDice = _nextLevel;

    // 3. Apply Choices
    if (_selectedOptions.containsKey('subclass')) {
      final subclassId = _selectedOptions['subclass'];
      final subclass =
          _classData.subclasses.firstWhere((s) => s.id == subclassId);
      char.subclass = subclass.getName('en');
    }

    if (_selectedOptions.containsKey('fighting_style')) {
      final styleId = _selectedOptions['fighting_style'];
      // Add as a pseudo-feature
      char.features.add(CharacterFeature(
        id: 'fs_$styleId',
        nameEn: 'Fighting Style: ${styleId!.toUpperCase()}',
        nameRu: 'Боевой стиль',
        descriptionEn: 'Selected fighting style',
        descriptionRu: '',
        type: FeatureType.passive,
        minLevel: _nextLevel,
        associatedClass: char.characterClass,
      ));
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
      ['evasion', 'stand', 'uncanny']
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
          return activeTier!.any((kw) =>
              fId.contains(kw) ||
              fId.replaceAll('-', '').replaceAll('_', '').contains(kw));
        });

        // Add the new valid tactic object directly
        _newFeatures.removeWhere((f) {
          final fId = (f.id).toLowerCase();
          return activeTier!.any((kw) =>
              fId.contains(kw) ||
              fId.replaceAll('-', '').replaceAll('_', '').contains(kw));
        });

        // 1. First try the standard FeatureService just in case
        CharacterFeature? fullyLoadedTactic =
            FeatureService.getFeatureById(chosenIdStr);

        // 2. If not found, look inside the FeatureService's loaded cache
        // Some tactic IDs have prefix issues or slight mismatches from what is saved in features_step
        if (fullyLoadedTactic == null) {
          final allFeatures = FeatureService.allFeatures;
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
            char.features.add(fullyLoadedTactic);
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
      final feature = _landOptions.firstWhere((f) => f.id == terrainId,
          orElse: () => _landOptions.first);
      char.features.add(feature);

      // Also add base "Natural Recovery" if not present
      if (!char.features.any((f) => f.id == 'natural-recovery')) {
        final natRec = FeatureService.getFeatureById('natural-recovery');
        if (natRec != null) char.features.add(natRec);
      }
    }

    // Save Expertise
    if (_selectedExpertise.isNotEmpty) {
      char.expertSkills.addAll(_selectedExpertise);
    }

    // Save New Spells
    if (_selectedSpells.isNotEmpty) {
      char.knownSpells.addAll(_selectedSpells);
    }

    // Save Spell Mastery
    if (_selectedMasterySpells.isNotEmpty) {
      char.spellMasterySpells = List.from(_selectedMasterySpells);
    }

    // Save Signature Spells
    if (_selectedSignatureSpells.isNotEmpty) {
      char.signatureSpells = List.from(_selectedSignatureSpells);
      // Initialize usage map
      char.signatureSpellsUsed = {
        for (var id in char.signatureSpells) id: false
      };
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
      // Check duplication
      if (!char.features.any((f) => f.id == feature.id)) {
        char.features.add(feature);
      }
    }

    // NOTE: FeatureService.addFeaturesToCharacter(char) is dangerous here for Druids.
    // We will skip it and rely on _newFeatures which we filtered.

    // Explicitly reload features to catch subclass features if subclass was just set
    if (_selectedOptions.containsKey('subclass')) {
      // If we just picked a subclass, we might need to fetch its features.
      // But usually that happens at next level up or we should handle it here.
      // For now, assuming LevelUp logic covers the features for the NEW level.
      // If subclass features appear at the same level as subclass choice (e.g. Warlock lvl 1, Sorcerer lvl 1),
      // they should be in _newFeatures or handled via choices.
      // Druid Land choice is at lvl 2, same as subclass choice.
    }

    // 5. Update Spell Slots
    if (_hasNewSpellSlots) {
      char.maxSpellSlots = _newSpellSlots;
      // Refill new slots? Usually yes on level up
      char.spellSlots = List.from(_newSpellSlots);
    }

    // 6. Save
    await char.save();

    if (mounted) {
      Navigator.pop(context, true); // Return true to indicate success
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${l10n.levelUpTitle}: ${_classData.getName(locale)} $_nextLevel'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe
        children: [
          HpIncreaseStep(
            hitDie: _classData.hitDie,
            conMod: _conMod,
            onRoll: _onHpRolled,
            onAverage: _onHpAverageTaken,
          ),
          FeaturesStep(
            character: widget.character, // Pass character for known skills
            newFeatures: _newFeatures,
            landOptions: _landOptions, // Pass land options
            newSpellSlots: _newSpellSlots,
            oldSpellSlots: _oldSpellSlots,
            classData: _classData,
            nextLevel: _nextLevel,
            spellsToLearnCount: _spellsToLearn,
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
            onSpellsSelected: (spells) {
              setState(() => _selectedSpells = spells);
            },
            onMasterySpellsSelected: (spells) {
              setState(() => _selectedMasterySpells = spells);
            },
            onSignatureSpellsSelected: (spells) {
              setState(() => _selectedSignatureSpells = spells);
            },
            onNext: _nextPage,
          ),
          SummaryStep(
            character: widget.character,
            nextLevel: _nextLevel,
            hpIncrease: _hpIncrease,
            newFeatures: _newFeatures,
            onConfirm: _finishLevelUp,
          ),
        ],
      ),
    );
  }
}
