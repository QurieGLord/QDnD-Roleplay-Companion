import 'package:flutter/material.dart';
import '../../core/models/race_data.dart';
import '../../core/models/class_data.dart';
import '../../core/models/background_data.dart';

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

  // Step 4: Skills
  List<String> selectedSkills = [];

  // Step 4: Equipment
  String? selectedEquipmentPackage; // 'standard', 'alternative', or 'custom'
  Map<String, int> customEquipmentQuantities = {}; // Item ID -> Quantity for custom equipment

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

  bool get isStepFeaturesValid => true; // Placeholder: Add validation logic if class requires spell selection

  bool _validateAbilityScores() {
    return abilityScores.values.every((score) => score >= 3 && score <= 18);
  }

  bool _validateSkills() {
    if (selectedClass == null) return false;
    return selectedSkills.length == selectedClass!.skillProficiencies.choose;
  }

  SpellLimits getSpellLimits() {
    if (selectedClass == null) return SpellLimits(0, 0);
    
    // Level 1 Limits for standard SRD classes
    // Note: This logic can be moved to a service or JSON later
    switch (selectedClass!.id) {
      case 'bard':
        return SpellLimits(2, 4); // 2 Cantrips, 4 Known
      case 'cleric':
        return SpellLimits(3, 999); // 3 Cantrips, All Lvl 1 available (Prepared)
      case 'druid':
        return SpellLimits(2, 999); // 2 Cantrips, All Lvl 1 available (Prepared)
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
    notifyListeners();
  }
}

class SpellLimits {
  final int cantrips;
  final int spellsKnown; // If 999, it means "All Available/Prepared"

  SpellLimits(this.cantrips, this.spellsKnown);
}