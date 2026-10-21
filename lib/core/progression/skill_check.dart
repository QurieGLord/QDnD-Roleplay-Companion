import '../models/character.dart';
import 'proficiency_identity.dart';

class SkillCheck {
  static int trainingBonus(Character character, String skill) {
    if (ProficiencyIdentity.contains(character.expertSkills, skill)) {
      return character.proficiencyBonus * 2;
    }
    if (ProficiencyIdentity.contains(character.proficientSkills, skill)) {
      return character.proficiencyBonus;
    }
    return character.hasFeatureId('jack-of-all-trades')
        ? character.proficiencyBonus ~/ 2
        : 0;
  }
}
