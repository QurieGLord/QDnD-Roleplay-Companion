import 'package:flutter/material.dart';
import '../../core/models/race_data.dart';
import '../../core/models/class_data.dart';
import '../../core/models/background_data.dart';
import '../../core/services/feature_service.dart';
import '../../core/services/spell_service.dart';

class CharacterCreationState extends ChangeNotifier {
  // Step 1: Basic Info
  String name = '';
  String? avatarPath;
  String? alignment; // Lawful Good, Neutral, Chaotic Evil, etc.

  // Physical appearance
  String? age;
  String? gender;
  String? height;
  String? weight;
  String? eyes;
  String? hair;
  String? skin;

  // Personality traits
  String? personalityTraits;
  String? ideals;
  String? bonds;
  String? flaws;
  String? appearanceDescription;
  String? backstory;

  // Step 2: Race & Class
  RaceData? selectedRace;
  SubraceData? selectedSubrace;
  ClassData? selectedClass;
  SubclassData? selectedSubclass;

  // Step 3: Ability Scores
  Map<String, int> abilityScores = {
    'strength': 10,
    'dexterity': 10,
    'constitution': 10,
    'intelligence': 10,
    'wisdom': 10,
    'charisma': 10,
  };
  String allocationMethod = 'standard_array';

  // HP Selection
  String hpSelectionMethod = 'max'; // 'max', 'average', 'roll'
  int? rolledHp; // Stored when user rolls for HP

  // Step 3.5: Features & Spells (New)
  List<String> selectedSpells = []; // IDs of selected spells
  Map<String, String> selectedFeatureOptions =
      {}; // featureId (e.g. 'fighting_style') -> optionId
  Set<String> selectedExpertise = {}; // IDs of skills selected for expertise

  // Step 4: Skills
  List<String> selectedSkills = [];

  // Step 4: Equipment
  String? selectedEquipmentPackage; // 'standard', 'alternative', or 'custom'
  Map<String, int> customEquipmentQuantities =
      {}; // Item ID -> Quantity for custom equipment

  // Step 5: Background
  BackgroundData? selectedBackground;

  // Step 6: Skills
  // (selectedSkills уже определен выше)

  // Step 7: Review
  // (все данные уже есть)

  // Validation
  bool get isStep1Valid => name.isNotEmpty;
  bool get isStep2Valid => selectedRace != null && selectedClass != null;
  bool get isStep3Valid => _validateAbilityScores();
  bool get isStep4Valid => selectedBackground != null;
  bool get isStep5Valid => _validateSkills();
  bool get isStep6Valid => true; // Review всегда валиден если дошли до него

  bool get isStepFeaturesValid {
    if (selectedClass == null) return false;

    final classId = selectedClass!.id.toLowerCase();
    final subclassId = selectedSubclass?.id.toLowerCase() ?? '';

    // Fighter: Fighting Style (Level 1)
    if (classId == 'fighter' || classId == 'воин') {
      bool hasFightingStyle = selectedFeatureOptions.values
          .any((v) => v.contains('fighting-style'));
      if (!hasFightingStyle) return false;
    }

    // Sorcerer: Draconic Bloodline (Level 1)
    if ((classId == 'sorcerer' || classId == 'чародей') &&
        (subclassId.contains('draconic') || subclassId.contains('дракон'))) {
      bool hasAncestry = selectedFeatureOptions.values
          .any((v) => v.contains('dragon-ancestor'));
      if (!hasAncestry) return false;
    }

    // Ranger: Favored Enemy and Natural Explorer (Level 1)
    if (classId == 'ranger' || classId == 'следопыт') {
      bool hasFavoredEnemy =
          selectedFeatureOptions.containsKey('favored_enemy');
      bool hasNaturalExplorer =
          selectedFeatureOptions.containsKey('natural_explorer');
      if (!hasFavoredEnemy || !hasNaturalExplorer) return false;
    }

    return true;
  }

  bool _validateAbilityScores() {
    return abilityScores.values.every((score) => score >= 3 && score <= 18);
  }

  bool _validateSkills() {
    if (selectedClass == null) return false;
    bool skillsValid =
        selectedSkills.length == selectedClass!.skillProficiencies.choose;

    if (!skillsValid) return false;

    // Data-driven Expertise Validation (Level 1)
    if (requiredExpertiseCount > 0) {
      if (selectedExpertise.length != requiredExpertiseCount) return false;
    }

    return true;
  }

  int get requiredExpertiseCount {
    if (selectedClass == null) {
      return 0;
    }

    final lvl1Features = FeatureService.getFeaturesForLevel(
      classId: selectedClass!.id,
      level: 1,
    );

    final hasExpertise = lvl1Features.any((f) {
      final id = f.id.toLowerCase();
      final name = f.nameEn.toLowerCase();
      return id.contains('expertise') || name.contains('expertise');
    });

    return hasExpertise ? 2 : 0;
  }

  // GLOBAL STRICT MODE WIZARD VALIDATION
  bool isStepValid(int step) {
    switch (step) {
      case 0:
        return name.trim().isNotEmpty;
      case 1:
        return selectedRace != null && selectedClass != null;
      case 2:
        return _validateAbilityScores();
      case 3:
        return _validateFeaturesAndSpells();
      case 4:
        return true; // Equipment step currently doesn't have strict requirements to block
      case 5:
        return selectedBackground != null;
      case 6:
        return _validateSkills();
      case 7:
        return true; // Review step
      default:
        return false;
    }
  }

  bool _validateFeaturesAndSpells() {
    if (selectedClass == null) return false;

    // Subclass Validation (if granted at level 1)
    if (selectedClass!.subclassLevel == 1 && selectedSubclass == null) {
      return false;
    }

    // Optional Features Validation (e.g. Fighting Style, Draconic Ancestry)
    // For now, if there are ANY feature options available, ensure they are selected
    // Note: We only strictly block if we know an option is REQUIRED.
    // Standard DnD: Ranger Favored Enemy / Natural Explorer are mandatory at lvl 1
    final classIdLower = selectedClass!.id.toLowerCase();
    if (classIdLower == 'ranger' || classIdLower == 'следопыт') {
      if (!selectedFeatureOptions.containsKey('favored_enemy')) return false;
      if (!selectedFeatureOptions.containsKey('natural_explorer')) return false;
    }
    if (classIdLower == 'sorcerer' || classIdLower == 'чародей') {
      // Must choose Draconic Ancestry if that subclass is selected
      if (selectedSubclass?.id == 'draconic_bloodline' &&
          !selectedFeatureOptions.containsKey('draconic_ancestry')) {
        return false;
      }
    }

    // Spellcasting Validation
    if (selectedClass!.spellcasting != null) {
      final cantripLimit = getSpellLimits().cantrips;
      final spellLimit = getSpellLimits().spellsKnown;

      int selectedCantripsCount = 0;
      int selectedLvl1Count = 0;

      // Spells tracking in State currently only holds an array of Strings `selectedSpells`
      // For accurate strict validation at level 1, we must separate Cantrips from Level 1 spells using the SpellService
      if (selectedSpells.isNotEmpty) {
        final classId = selectedClass!.id;
        final classSpells = SpellService.getSpellsForClass(classId);
        for (var id in selectedSpells) {
          final targetSpell = classSpells.firstWhere((s) => s.id == id,
              orElse: () => throw Exception('Spell not found'));
          if (targetSpell.level == 0) {
            selectedCantripsCount++;
          } else if (targetSpell.level == 1) {
            selectedLvl1Count++;
          }
        }
      }

      if (cantripLimit > 0 && selectedCantripsCount != cantripLimit) {
        return false;
      }

      // Prepared casters (Cleric/Druid) don't strictly *learn* spells at creation in our UI the same way,
      // so we use a loose check, but Wizards/Bards/Sorcs/Warlocks MUST learn their required spells.
      if (spellLimit > 0 &&
          spellLimit < 999 &&
          selectedLvl1Count != spellLimit) {
        return false;
      }
    }

    return true;
  }

  SpellLimits getSpellLimits() {
    if (selectedClass == null) return SpellLimits(0, 0);

    // Level 1 Limits for standard SRD classes
    // Note: This logic can be moved to a service or JSON later
    final classId = selectedClass!.id.toLowerCase();
    switch (classId) {
      case 'bard':
        return SpellLimits(2, 4); // 2 Cantrips, 4 Known
      case 'cleric':
        return SpellLimits(
            3, 999); // 3 Cantrips, All Lvl 1 available (Prepared)
      case 'druid':
        return SpellLimits(
            2, 999); // 2 Cantrips, All Lvl 1 available (Prepared)
      case 'sorcerer':
        return SpellLimits(4, 2); // 4 Cantrips, 2 Known
      case 'warlock':
        return SpellLimits(2, 2); // 2 Cantrips, 2 Known
      case 'wizard':
        return SpellLimits(3, 6); // 3 Cantrips, 6 in Spellbook
      default:
        // Paladin, Ranger, Fighter, etc. usually don't have spells at lvl 1
        // But for safety/custom classes, we can allow 0 or generic
        if (selectedClass!.spellcasting != null) {
          return SpellLimits(2, 2); // Generic fallback
        }
        return SpellLimits(0, 0);
    }
  }

  void toggleSpell(String spellId) {
    if (selectedSpells.contains(spellId)) {
      selectedSpells.remove(spellId);
    } else {
      selectedSpells.add(spellId);
    }
    notifyListeners();
  }

  void selectFeatureOption(String featureId, String optionId) {
    selectedFeatureOptions[featureId] = optionId;
    notifyListeners();
  }

  void toggleExpertise(String skillId) {
    if (selectedExpertise.contains(skillId)) {
      selectedExpertise.remove(skillId);
    } else {
      selectedExpertise.add(skillId);
    }
    notifyListeners();
  }

  void updateName(String newName) {
    name = newName;
    notifyListeners();
  }

  void updateAlignment(String? newAlignment) {
    alignment = newAlignment;
    notifyListeners();
  }

  void updateAvatarPath(String? newAvatarPath) {
    avatarPath = newAvatarPath;
    notifyListeners();
  }

  // Physical appearance updaters
  void updateAge(String? value) {
    age = value;
    notifyListeners();
  }

  void updateGender(String? value) {
    gender = value;
    notifyListeners();
  }

  void updateHeight(String? value) {
    height = value;
    notifyListeners();
  }

  void updateWeight(String? value) {
    weight = value;
    notifyListeners();
  }

  void updateEyes(String? value) {
    eyes = value;
    notifyListeners();
  }

  void updateHair(String? value) {
    hair = value;
    notifyListeners();
  }

  void updateSkin(String? value) {
    skin = value;
    notifyListeners();
  }

  // Personality traits updaters
  void updatePersonalityTraits(String? value) {
    personalityTraits = value;
    notifyListeners();
  }

  void updateIdeals(String? value) {
    ideals = value;
    notifyListeners();
  }

  void updateBonds(String? value) {
    bonds = value;
    notifyListeners();
  }

  void updateFlaws(String? value) {
    flaws = value;
    notifyListeners();
  }

  void updateAppearanceDescription(String? value) {
    appearanceDescription = value;
    notifyListeners();
  }

  void updateBackstory(String? value) {
    backstory = value;
    notifyListeners();
  }

  void updateRace(RaceData race) {
    selectedRace = race;
    selectedSubrace = null;
    notifyListeners();
  }

  void updateClass(ClassData classData) {
    selectedClass = classData;
    selectedSubclass = null;
    selectedSkills.clear();
    notifyListeners();
  }

  void updateSubclass(SubclassData? subclass) {
    selectedSubclass = subclass;
    notifyListeners();
  }

  void updateAbilityScore(String ability, int value) {
    abilityScores[ability] = value;
    notifyListeners();
  }

  void updateHpSelectionMethod(String method) {
    hpSelectionMethod = method;
    notifyListeners();
  }

  void updateRolledHp(int? hp) {
    rolledHp = hp;
    notifyListeners();
  }

  void toggleSkill(String skill) {
    if (selectedSkills.contains(skill)) {
      selectedSkills.remove(skill);
    } else {
      if (selectedClass != null &&
          selectedSkills.length < selectedClass!.skillProficiencies.choose) {
        selectedSkills.add(skill);
      }
    }
    notifyListeners();
  }

  void updateEquipmentPackage(String? package) {
    selectedEquipmentPackage = package;
    // Clear custom equipment when switching to standard/alternative
    if (package != 'custom') {
      customEquipmentQuantities.clear();
    }
    notifyListeners();
  }

  void addCustomEquipment(String itemId, {int quantity = 1}) {
    customEquipmentQuantities[itemId] = quantity;
    notifyListeners();
  }

  void removeCustomEquipment(String itemId) {
    customEquipmentQuantities.remove(itemId);
    notifyListeners();
  }

  void clearCustomEquipment() {
    customEquipmentQuantities.clear();
    notifyListeners();
  }

  void updateBackground(BackgroundData background) {
    selectedBackground = background;
    notifyListeners();
  }

  void reset() {
    name = '';
    avatarPath = null;
    alignment = null;
    selectedRace = null;
    selectedSubrace = null;
    selectedClass = null;
    selectedSubclass = null;
    abilityScores = {
      'strength': 10,
      'dexterity': 10,
      'constitution': 10,
      'intelligence': 10,
      'wisdom': 10,
      'charisma': 10,
    };
    selectedSkills.clear();
    selectedEquipmentPackage = null;
    customEquipmentQuantities.clear();
    selectedBackground = null;
    selectedFeatureOptions.clear();
    selectedExpertise.clear();
    notifyListeners();
  }
}

class SpellLimits {
  final int cantrips;
  final int spellsKnown; // If 999, it means "All Available/Prepared"

  SpellLimits(this.cantrips, this.spellsKnown);
}
