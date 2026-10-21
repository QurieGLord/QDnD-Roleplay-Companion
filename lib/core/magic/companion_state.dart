import '../models/character.dart';
import '../progression/character_class_context.dart';
import 'class_action_state.dart';

class CompanionState {
  const CompanionState(
      {required this.name, required this.current, required this.maximum});
  final String name;
  final int current, maximum;
  Map<String, dynamic> toJson() =>
      {'version': 1, 'name': name, 'current': current, 'maximum': maximum};
  static CompanionState? read(Character hero) {
    final raw = ClassActionState.companionData(hero);
    if (raw != null) {
      if (raw is! Map ||
          raw['version'] != 1 ||
          raw['name'] is! String ||
          raw['current'] is! int ||
          raw['maximum'] is! int ||
          raw['current'] < 0 ||
          raw['maximum'] < 0) {
        throw const FormatException('Unsupported companion state.');
      }
      return CompanionState(
          name: raw['name'], current: raw['current'], maximum: raw['maximum']);
    }
    // Old fields represented both a companion and Wild Shape. A mixed hero's
    // data is ambiguous and must not be silently assigned to either creature.
    if (CharacterClassContext(hero, 'ranger').entry != null &&
        CharacterClassContext(hero, 'druid').entry == null &&
        !hero.isWildShaped &&
        (hero.beastName?.isNotEmpty ?? false) &&
        hero.beastCurrentHp != null &&
        hero.beastMaxHp != null) {
      return CompanionState(
          name: hero.beastName!,
          current: hero.beastCurrentHp!,
          maximum: hero.beastMaxHp!);
    }
    return null;
  }
}
