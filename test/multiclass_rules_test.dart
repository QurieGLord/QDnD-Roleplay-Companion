import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/progression/multiclass_rules.dart';
import 'journal_service_test.dart' as fixtures;

void main() {
  test(
      'Entry requirements distinguish OR from AND, and an unknown class stays unknown',
      () {
    final a = AbilityScores(
        strength: 8,
        dexterity: 13,
        constitution: 12,
        intelligence: 12,
        wisdom: 12,
        charisma: 13);
    expect(MulticlassRules.eligible('fighter', a), true);
    expect(MulticlassRules.eligible('monk', a), false);
    expect(MulticlassRules.eligible('paladin', a), false);
    a.wisdom = 13;
    expect(MulticlassRules.eligible('monk', a), true);
    expect(MulticlassRules.eligible('unrecognized-homebrew', a), isNull);
    expect(MulticlassRules.prerequisites, hasLength(12));
  });
  test(
      'The current class also needs its prerequisites when entering another class',
      () {
    final c = fixtures.hero();
    c.classes.single.id = 'paladin';
    c.abilityScores = AbilityScores(
        strength: 12,
        dexterity: 14,
        constitution: 10,
        intelligence: 13,
        wisdom: 10,
        charisma: 13);
    expect(MulticlassRules.unmet(c, 'wizard'), ['paladin']);
  });
  test('Entry grants cannot accidentally award the full creation proficiencies',
      () {
    expect(MulticlassRules.entryTraining, hasLength(12));
    expect(MulticlassRules.entryTraining['fighter'],
        isNot(contains('armor:heavy')));
    expect(MulticlassRules.entryTraining['paladin'],
        isNot(contains('armor:heavy')));
    expect(MulticlassRules.entryTraining['sorcerer'], isEmpty);
    expect(
        MulticlassRules.entryTraining.values
            .expand((v) => v)
            .any((v) => v.startsWith('save:') || v.startsWith('equipment:')),
        false);
  });
  test(
      'Hit-die growth belongs to the chosen class and preserves spent dice and extras',
      () {
    final c = fixtures.hero();
    c.classes = [
      CharacterClass(id: 'fighter', name: 'Fighter', level: 4, isPrimary: true),
      CharacterClass(id: 'wizard', name: 'Wizard', level: 3)
    ];
    c.level = 7;
    c.hitDice = [6, 0];
    expect(MulticlassRules.advanceHitDice(c, 'wizard'), [6, 1]);
    expect(MulticlassRules.advanceHitDice(c, 'rogue'), [6, 0, 1]);
    expect(c.hitDice, [6, 0]);
    c.hitDice = [3];
    expect(() => MulticlassRules.advanceHitDice(c, 'wizard'), throwsStateError);
  });
}
