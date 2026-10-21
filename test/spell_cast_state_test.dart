import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/models/spell.dart';
import 'package:qd_and_d/core/services/spellcasting_service.dart';

Character caster({String classId = 'wizard'}) => Character(
      id: 'caster',
      name: 'Caster',
      race: 'human',
      characterClass: classId,
      level: 18,
      maxHp: 30,
      currentHp: 30,
      abilityScores: AbilityScores(
        strength: 10,
        dexterity: 14,
        constitution: 14,
        intelligence: 18,
        wisdom: 14,
        charisma: 18,
      ),
      spellSlots: [6, 0, 2, 0, 0, 0],
      maxSpellSlots: [4, 0, 2, 0, 0, 0],
    );

Spell spell(int level) => Spell(
      id: 'spell-$level',
      nameEn: 'Spell $level',
      nameRu: 'Заклинание $level',
      level: level,
      school: 'Evocation',
      castingTime: '1 action',
      range: 'Self',
      duration: 'Instantaneous',
      concentration: false,
      ritual: false,
      components: ['V'],
      descriptionEn: 'Test',
      descriptionRu: 'Проверка',
      availableToClasses: ['wizard', 'warlock'],
    );

void main() {
  test(
      'ordinary casting spends from the actual six of four and keeps the normal limit',
      () {
    final c = caster();
    final s = spell(1);
    expect(SpellcastingService.availableSlotLevels(c, 1), [1, 3]);
    expect(SpellcastingService.applyCast(c, s, slotLevel: 1), true);
    expect(c.spellSlots.first, 5);
    expect(c.maxSpellSlots.first, 4);
    c.longRest();
    expect(c.spellSlots.first, 5);
  });

  test('manually granted slot at a normally absent level is usable', () {
    final c = caster()..setSpellSlotCount(6, 2);
    expect(c.maxSpellSlots[5], 0);
    expect(SpellcastingService.availableSlotLevels(c, 6), [6]);
    expect(SpellcastingService.applyCast(c, spell(6), slotLevel: 6), true);
    expect(c.spellSlots[5], 1);
    c.longRest();
    expect(c.spellSlots[5], 1);
  });

  test(
    'unavailable, undersized and out-of-range costs leave all slots untouched',
    () {
      final c = caster();
      final before = List<int>.from(c.spellSlots);
      for (final level in [-1, 0, 1, 2, 10]) {
        expect(
          SpellcastingService.applyCast(c, spell(3), slotLevel: level),
          false,
        );
        expect(c.spellSlots, before);
      }
    },
  );

  test('cantrips and mastery do not consume an unrelated slot', () {
    final c = caster();
    final s = spell(1);
    c.spellMasterySpells = [s.id];
    expect(SpellcastingService.applyCast(c, spell(0)), true);
    expect(SpellcastingService.applyCast(c, s), true);
    expect(c.spellSlots.first, 6);
    expect(c.signatureSpellsUsed, isEmpty);
  });

  test(
      'signature use is tracked, can use an ordinary slot, and restores on a short rest',
      () {
    final c = caster();
    final s = spell(3);
    c.signatureSpells = [s.id];
    expect(SpellcastingService.canCastWithoutSlot(c, s), true);
    expect(SpellcastingService.applyCast(c, s), true);
    expect(c.signatureSpellsUsed[s.id], true);
    expect(SpellcastingService.applyCast(c, s), false);
    expect(SpellcastingService.applyCast(c, s, slotLevel: 3), true);
    expect(c.spellSlots[2], 1);
    c.shortRest();
    expect(SpellcastingService.canCastWithoutSlot(c, s), true);
    expect(c.spellSlots[2], 1);
  });

  test(
      'Arcanum spends one use from six of one instead of clearing the entire counter',
      () {
    final c = caster(classId: 'warlock');
    c.features.add(
      CharacterFeature(
        id: 'mystic_arcanum_6th',
        nameEn: 'Mystic Arcanum 6th',
        nameRu: 'Таинственный арканум 6',
        descriptionEn: '',
        descriptionRu: '',
        minLevel: 11,
        type: FeatureType.resourcePool,
        resourcePool: ResourcePool(
          currentUses: 6,
          maxUses: 1,
          recoveryType: RecoveryType.longRest,
        ),
      ),
    );
    final pool = c.features.single.resourcePool!;
    expect(SpellcastingService.applyCast(c, spell(6)), true);
    expect(pool.currentUses, 5);
    c.shortRest();
    expect(pool.currentUses, 5);
    c.longRest();
    expect(pool.currentUses, 5);
    pool.setCurrentUses(0);
    expect(SpellcastingService.applyCast(c, spell(6)), false);
    c.longRest();
    expect(pool.currentUses, 1);
  });
}
