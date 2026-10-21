import '../models/character.dart';
import '../models/class_data.dart';
import '../models/spell_slots_table.dart';
import 'character_class_context.dart';
import '../magic/spell_preparation_rules.dart';

/// Read-only, explicit spellcasting source. Learning circles are the class's
/// own progression, never the shared slots of a multiclass character.
class ClassSpellcastingProfile {
  const ClassSpellcastingProfile._(
      {required this.classId,
      required this.classLevel,
      required this.characterLevel,
      required this.ability,
      required this.modifier,
      required this.attackBonus,
      required this.saveDC,
      required this.learningCircle,
      required this.isPact,
      required this.preparation,
      required this.progression});
  final String classId, ability;
  final int classLevel,
      characterLevel,
      modifier,
      attackBonus,
      saveDC,
      learningCircle;
  final bool isPact;
  final String progression;
  final SpellPreparationRules? preparation;

  static ClassSpellcastingProfile? resolve(Character hero, String classId,
      {ClassData? definition}) {
    final owner = CharacterClassContext(hero, classId);
    if (owner.entry == null) return null;
    final data = definition ?? owner.definition;
    if (data == null) {
      throw StateError('The class spellcasting source is unavailable.');
    }
    final casting = data.spellcasting;
    final subclass =
        owner.subclass?.toLowerCase().replaceAll(RegExp('[_-]+'), ' ');
    final third = casting == null &&
        data.sourceId == null &&
        data.rulesMetadata['origin'] == 'bundled' &&
        ((classId == 'fighter' && subclass == 'eldritch knight') ||
            (classId == 'rogue' && subclass == 'arcane trickster'));
    if (casting == null && !third) return null;
    if (data.rulesEdition != '2014') {
      throw UnsupportedError(
          'This spellcasting profile needs explicit supported rules.');
    }
    final ability =
        third ? 'intelligence' : casting!.ability.trim().toLowerCase();
    final score = hero.abilityScores.toJson()[ability];
    if (score is! int) {
      throw FormatException(
          'Unknown spellcasting ability: ${casting?.ability}');
    }
    final rawType = third ? 'third' : casting!.type.trim().toLowerCase();
    final type = rawType == 'pact_magic' ? 'pact' : rawType;
    if (!{'full', 'half', 'third', 'pact'}.contains(type)) {
      throw FormatException(
          'Unknown spellcasting progression: ${casting?.type}');
    }
    if (owner.level < 1 || owner.level > 20) {
      throw StateError('Invalid class level for spellcasting.');
    }
    final modifier = hero.abilityScores.getModifier(score);
    final attack = hero.proficiencyBonus + modifier;
    final slots = SpellSlotsTable.getSlots(owner.level, type);
    return ClassSpellcastingProfile._(
        classId: classId,
        classLevel: owner.level,
        characterLevel: hero.level,
        ability: ability,
        modifier: modifier,
        attackBonus: attack,
        saveDC: 8 + attack,
        learningCircle: slots.length,
        isPact: type == 'pact',
        preparation: SpellPreparationRules.resolve(data),
        progression: type);
  }
}
