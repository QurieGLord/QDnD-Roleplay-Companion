import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/character_data_service.dart';
import '../../../core/services/feature_service.dart';
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
  List<int> _newSpellSlots = [];
  List<int> _oldSpellSlots = [];
  bool _hasNewSpellSlots = false;
  
  // Selections
  final Map<String, String> _selectedOptions = {};
  
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
      _classData = CharacterDataService.getClassById(widget.character.characterClass)!;
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
       if (f.associatedSubclass == null || f.associatedSubclass!.isEmpty) return true;
       // If character has no subclass yet, exclude subclass features (unless we are at subclass level, handled by selection step?)
       // Actually, features map usually contains all possibilities. 
       // FeatureService.getFeaturesForLevel handles filtering. We should duplicate that logic or trust the UI to filter?
       // The UI `FeaturesStep` might filter options. 
       // But wait, `FeatureService` returns *available* features.
       
       // If character has a subclass, check match
       if (widget.character.subclass != null) {
          return f.associatedSubclass!.toLowerCase() == widget.character.subclass!.toLowerCase();
       }
       
       // If no subclass selected yet, we might be at the level where we choose it.
       // In that case, we might want to show them? Or wait until choice?
       // Usually features for a subclass are added *after* choice.
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
    
    _newFeatures = allFeatures;

    // 5. Calculate Spell Slots
    if (_classData.spellcasting != null) {
      _oldSpellSlots = List.from(widget.character.maxSpellSlots);
      
      // Determine Caster Type logic
      String casterType = 'full'; // Default
      if (_classData.id == 'paladin' || _classData.id == 'ranger') casterType = 'half';
      // TODO: better caster type detection from ClassData
      
      final newSlots = SpellSlotsTable.getSlots(_nextLevel, casterType);
      
      // Compare
      if (newSlots.length > _oldSpellSlots.length) {
        _hasNewSpellSlots = true;
      } else {
        for (int i = 0; i < newSlots.length; i++) {
          if (newSlots[i] > (_oldSpellSlots.length > i ? _oldSpellSlots[i] : 0)) {
            _hasNewSpellSlots = true;
            break;
          }
        }
      }
      _newSpellSlots = newSlots;
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
      final subclass = _classData.subclasses.firstWhere((s) => s.id == subclassId);
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

    // 4. Add Features
    // We explicitly call addFeaturesToCharacter once to capture all strictly available features
    FeatureService.addFeaturesToCharacter(char);
    
    // Explicitly reload features to catch subclass features if subclass was just set
    if (_selectedOptions.containsKey('subclass')) {
       FeatureService.addFeaturesToCharacter(char);
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
        title: Text('${l10n.levelUpTitle}: ${_classData.getName(locale)} $_nextLevel'),
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
            newFeatures: _newFeatures,
            newSpellSlots: _newSpellSlots,
            oldSpellSlots: _oldSpellSlots,
            classData: _classData,
            nextLevel: _nextLevel,
            onOptionSelected: (featureId, optionId) {
              setState(() {
                _selectedOptions[featureId] = optionId;
              });
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