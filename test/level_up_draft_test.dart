import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/models/condition.dart';
import 'package:qd_and_d/core/progression/level_up_draft.dart';
import 'package:qd_and_d/core/progression/resource_growth.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'journal_service_test.dart' as fixtures;

void main() {
  test('Selected class advances once while the primary class stays unchanged',
      () {
    final c = fixtures.hero()
      ..level = 7
      ..classes = [
        CharacterClass(
            id: 'fighter', name: 'Fighter', level: 5, isPrimary: true),
        CharacterClass(
            id: 'wizard', name: 'Wizard', level: 2, subclass: 'evoker')
      ];
    final before = QdndBundleCodec.characterToJson(c);
    final draft = LevelUpDraft.begin(c, classId: 'wizard');
    final next = draft.preview;
    expect(next.level, 8);
    expect(next.classes.map((c) => c.level), [5, 3]);
    expect(next.classes.last.subclass, 'evoker');
    expect(next.classes.first.isPrimary, isTrue);
    expect(draft.classLevelBefore, 2);
    expect(draft.classLevelAfter, 3);
    expect(QdndBundleCodec.characterToJson(c), before);
  });
  test('A new class adds level one and retains the original starting class',
      () {
    final c = fixtures.hero();
    final draft =
        LevelUpDraft.begin(c, classId: 'wizard', newClassName: 'Wizard');
    final next = draft.preview;
    expect(next.level, 2);
    expect(next.classes.map((c) => c.level), [1, 1]);
    expect(next.classes.last.isPrimary, isFalse);
    expect(next.characterClass, 'fighter');
    expect(c.classes, hasLength(1));
  });
  for (final current in [0, 18, 30, 42]) {
    test('Health gain preserves current HP $current and other table decisions',
        () {
      final c = fixtures.hero()
        ..currentHp = current
        ..maxHp = 30
        ..temporaryHp = 7
        ..isWildShaped = true
        ..beastCurrentHp = 4
        ..beastMaxHp = 12
        ..activeConditions = [ConditionType.poisoned]
        ..concentratingOn = 'spell'
        ..armorClass = 19;
      final draft = LevelUpDraft.begin(c, classId: 'fighter')..chooseHealth(6);
      final next = draft.preview;
      expect(next.maxHp, 36);
      expect(next.currentHp, current);
      expect(next.temporaryHp, 7);
      expect(next.beastCurrentHp, 4);
      expect(next.beastMaxHp, 12);
      expect(next.isWildShaped, isTrue);
      expect(next.activeConditions, [ConditionType.poisoned]);
      expect(next.concentratingOn, 'spell');
      expect(next.armorClass, 19);
      expect(next.armorClassOverride, 19);
      expect(c.maxHp, 30);
    });
  }
  test(
      'CON change includes previous levels but never heals or accumulates on reselection',
      () {
    final c = fixtures.hero()
      ..level = 4
      ..currentHp = 18
      ..maxHp = 30;
    c.classes.single.level = 4;
    final draft = LevelUpDraft.begin(c, classId: 'fighter');
    draft.chooseHealth(6,
        abilityScores: c.abilityScores.copyWith(constitution: 12));
    expect(draft.preview.maxHp, 41); // 6 + new CON 1 + four prior levels.
    expect(draft.preview.currentHp, 18);
    draft.chooseHealth(6,
        abilityScores: c.abilityScores.copyWith(constitution: 12));
    expect(draft.preview.maxHp, 41);
    draft.chooseHealth(5);
    expect(draft.preview.maxHp, 35);
    expect(draft.preview.abilityScores.constitution, 10);
    expect(c.abilityScores.constitution, 10);
  });
  test(
      'Preview is isolated from the original and cannot mutate the stored draft',
      () {
    final c = fixtures.hero()
      ..spellSlots = [6]
      ..maxSpellSlots = [4]
      ..journalData = {
        'records': {
          'n:a': {
            'manual': ['entity']
          }
        }
      };
    final draft = LevelUpDraft.begin(c, classId: 'fighter');
    final next = draft.preview;
    next.classes.single.level = 20;
    next.spellSlots[0] = 0;
    (next.journalData['records'] as Map).clear();
    expect(c.classes.single.level, 1);
    expect(c.spellSlots, [6]);
    expect(c.journalData['records'], isNotEmpty);
    expect(draft.preview.classes.single.level, 2);
    expect(draft.preview.spellSlots, [6]);
    expect(draft.preview.journalData['records'], isNotEmpty);
  });
  test(
      'Shared slot growth retains spent slots and overfill and gives a new circle its capacity',
      () {
    final c = fixtures.hero()
      ..spellSlots = [1, 6, 0]
      ..maxSpellSlots = [3, 4, 0];
    final draft = LevelUpDraft.begin(c, classId: 'fighter');
    draft.chooseSharedSlotMaximums([4, 5, 2]);
    expect(draft.preview.spellSlots, [2, 7, 2]);
    expect(draft.preview.maxSpellSlots, [4, 5, 2]);
    draft.chooseSharedSlotMaximums([4, 5, 2]);
    expect(draft.preview.spellSlots, [2, 7, 2]);
    draft.chooseSharedSlotMaximums([3, 4, 0]);
    expect(draft.preview.spellSlots, [1, 6, 0]);
    expect(c.spellSlots, [1, 6, 0]);
    expect(c.maxSpellSlots, [3, 4, 0]);
  });
  test('Missing norms never silently delete an explicitly recorded remainder',
      () {
    final c = fixtures.hero()
      ..spellSlots = [6, 2]
      ..maxSpellSlots = [4];
    final draft = LevelUpDraft.begin(c, classId: 'fighter');
    draft.chooseSharedSlotMaximums([4]);
    expect(draft.preview.spellSlots, [6, 2]);
    expect(draft.preview.maxSpellSlots, [4, 0]);
  });
  test(
      'Resource growth preserves consumption across every nonnegative small state',
      () {
    for (var oldMax = 0; oldMax <= 6; oldMax++) {
      for (var current = 0; current <= 10; current++) {
        for (var newMax = oldMax; newMax <= 8; newMax++) {
          final result = ResourceGrowth.remaining(
              current: current, oldMaximum: oldMax, newMaximum: newMax);
          expect(newMax - result, oldMax - current);
          expect(result, greaterThanOrEqualTo(current));
        }
      }
    }
    expect(
        ResourceGrowth.remaining(current: 6, oldMaximum: 4, newMaximum: 0), 6);
    expect(
        () =>
            ResourceGrowth.remaining(current: -1, oldMaximum: 4, newMaximum: 5),
        throwsArgumentError);
  });
  test('A rejected slot choice leaves the previous preview intact', () {
    final c = fixtures.hero()
      ..spellSlots = [1]
      ..maxSpellSlots = [3];
    final draft = LevelUpDraft.begin(c, classId: 'fighter');
    draft.chooseSharedSlotMaximums([4]);
    expect(() => draft.chooseSharedSlotMaximums([-1]), throwsArgumentError);
    expect(draft.preview.spellSlots, [2]);
    expect(draft.preview.maxSpellSlots, [4]);
  });
  test('Changes to the active sheet invalidate an older preview', () {
    final c = fixtures.hero();
    final draft = LevelUpDraft.begin(c, classId: 'fighter');
    expect(draft.isCurrentFor(c), isTrue);
    c.currentHp--;
    expect(draft.isCurrentFor(c), isFalse);
  });
  test(
      'Invalid class sums, duplicate IDs and level 20 are rejected before calculation',
      () {
    final c = fixtures.hero()..level = 5;
    expect(() => LevelUpDraft.begin(c, classId: 'fighter'), throwsStateError);
    c.classes = [
      CharacterClass(id: 'fighter', name: 'Fighter', level: 2),
      CharacterClass(id: 'fighter', name: 'Fighter', level: 3)
    ];
    expect(() => LevelUpDraft.begin(c, classId: 'fighter'), throwsStateError);
    c.level = 20;
    c.classes = [CharacterClass(id: 'fighter', name: 'Fighter', level: 20)];
    expect(() => LevelUpDraft.begin(c, classId: 'fighter'), throwsStateError);
  });
}
