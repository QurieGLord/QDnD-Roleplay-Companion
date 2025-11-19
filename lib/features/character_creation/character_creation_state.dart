import 'package:flutter/material.dart';
import '../../core/models/race_data.dart';
import '../../core/models/class_data.dart';
import '../../core/models/background_data.dart';

class CharacterCreationState extends ChangeNotifier {
  // Step 1: Basic Info
  String name = '';
  String? avatarPath;
  String? alignment; // Lawful Good, Neutral, Chaotic Evil, etc.

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

  // Step 4: Skills
  List<String> selectedSkills = [];

  // Step 4: Equipment
  String? selectedEquipmentPackage; // 'standard', 'alternative', or 'custom'
  List<String> customEquipmentIds = []; // Item IDs for custom equipment selection

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

  bool _validateAbilityScores() {
    return abilityScores.values.every((score) => score >= 3 && score <= 18);
  }

  bool _validateSkills() {
    if (selectedClass == null) return false;
    return selectedSkills.length == selectedClass!.skillProficiencies.choose;
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
      customEquipmentIds.clear();
    }
    notifyListeners();
  }

  void addCustomEquipment(String itemId) {
    if (!customEquipmentIds.contains(itemId)) {
      customEquipmentIds.add(itemId);
      notifyListeners();
    }
  }

  void removeCustomEquipment(String itemId) {
    customEquipmentIds.remove(itemId);
    notifyListeners();
  }

  void clearCustomEquipment() {
    customEquipmentIds.clear();
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
    customEquipmentIds.clear();
    selectedBackground = null;
    notifyListeners();
  }
}
