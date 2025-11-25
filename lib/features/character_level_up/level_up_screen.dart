import 'package:flutter/material.dart';
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
    // We need to temporarily spoof the level to get NEXT level features
    // A bit hacky, but FeatureService doesn't support "getLevelFeatures" directly yet
    final tempChar = Character(
      id: 'temp',
      name: 'temp',
      race: widget.character.race,
      characterClass: widget.character.characterClass,
      subclass: widget.character.subclass,
      level: _nextLevel,
      maxHp: 0,
      currentHp: 0,
      abilityScores: widget.character.abilityScores,
      spellSlots: [],
      maxSpellSlots: [],
    );
    
    final potentialFeatures = FeatureService.getFeaturesForCharacter(tempChar);
    
    // Filter only features that appear AT this level (minLevel == _nextLevel)
    _newFeatures = potentialFeatures.where((f) => f.minLevel == _nextLevel).toList();

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

    // 3. Add Features
    for (var feature in _newFeatures) {
      // Check duplicates
      if (!char.features.any((f) => f.id == feature.id)) {
        // Need to clone/calculate max uses
        // Using FeatureService helper if available or manual logic
        FeatureService.addFeaturesToCharacter(char); 
        // Note: addFeaturesToCharacter adds ALL available. Since we upped the level, 
        // calling this is the safest way to ensure all logic (resource pools etc) runs.
      }
    }

    // 4. Update Spell Slots
    if (_hasNewSpellSlots) {
      char.maxSpellSlots = _newSpellSlots;
      // Refill new slots? Usually yes on level up
      char.spellSlots = List.from(_newSpellSlots);
    }

    // 5. Save
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Level Up: ${_classData.getName('en')} $_nextLevel'),
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