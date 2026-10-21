// Positive acceptance tests for the agreed current-state cycle.
// Domain/Hive coverage: real built-in FeatureService records for all 12 classes.
// These tests do not claim to cover every class-widget editor or complete progression.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/models/condition.dart';
import 'package:qd_and_d/core/models/spell_slots_table.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/features/character_sheet/widgets/abilities/abilities_tab_logic.dart';

const classIds = [
  'barbarian',
  'bard',
  'cleric',
  'druid',
  'fighter',
  'monk',
  'paladin',
  'ranger',
  'rogue',
  'sorcerer',
  'warlock',
  'wizard',
];

Character hero(
  String id,
  String classId, {
  int level = 8,
  List<CharacterClass>? classes,
}) {
  final data = CharacterDataService.getClassById(classId)!;
  final slots = data.spellcasting == null
      ? <int>[]
      : List<int>.from(
          SpellSlotsTable.getSlots(level, data.spellcasting!.type),
        );
  final c = Character(
    id: id,
    name: 'Cycle $id',
    race: 'human',
    characterClass: classId,
    subclass: data.subclasses.first.id,
    level: level,
    maxHp: 30,
    currentHp: 30,
    abilityScores: AbilityScores(
      strength: 16,
      dexterity: 14,
      constitution: 16,
      intelligence: 16,
      wisdom: 16,
      charisma: 18,
    ),
    spellSlots: List<int>.from(slots),
    maxSpellSlots: List<int>.from(slots),
    classes: classes,
  );
  FeatureService.addFeaturesToCharacter(c);
  return c;
}

List<ResourcePool> pools(Character c) =>
    c.features.map((f) => f.resourcePool).whereType<ResourcePool>().toList();

void markEffects(Character c) {
  c.activeConditions = [ConditionType.poisoned, ConditionType.petrified];
  c.exhaustionLevel = 3;
  c.temporaryHp = 7;
  c.concentratingOn = 'hunters-mark';
  c.isHuntersMarkActive = true;
  c.huntersMarkTarget = 'Audit target';
  c.isHiddenInPlainSight = true;
  c.isRaging = true;
  c.isFrenzied = true;
  c.isWildShaped = true;
  c.beastName = 'Audit beast';
  c.beastMaxHp = 20;
  c.beastCurrentHp = 16;
  c.relentlessRageSaveDc = 20;
}

void expectEffects(Character c) {
  expect(c.activeConditions, [ConditionType.poisoned, ConditionType.petrified]);
  expect(c.exhaustionLevel, 3);
  expect(c.temporaryHp, 7);
  expect(c.concentratingOn, 'hunters-mark');
  expect(c.isHuntersMarkActive, true);
  expect(c.huntersMarkTarget, 'Audit target');
  expect(c.isHiddenInPlainSight, true);
  expect(c.isRaging, true);
  expect(c.isFrenzied, true);
  expect(c.isWildShaped, true);
  expect(c.beastName, 'Audit beast');
  expect(c.beastMaxHp, 20);
  expect(c.beastCurrentHp, 16);
  expect(c.relentlessRageSaveDc, 20);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late Box<Character> box;
  Future<Character> persistReload(Character c) async {
    await c.save();
    await box.flush();
    await box.close();
    box = await Hive.openBox<Character>('characters');
    return box.get(c.id)!;
  }

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('qdnd_cycle_reliability_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => temp.path,
    );
    await StorageService.init();
    box = Hive.box<Character>('characters');
    await FeatureService.init();
    await CharacterDataService.loadAllData();
  });
  setUp(() async {
    await box.clear();
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  group('ResourcePool actual remainder', () {
    test(
      'manual above-normal value is spent arithmetically and rests preserve it',
      () {
        final p = ResourcePool(
          currentUses: 2,
          maxUses: 4,
          recoveryType: RecoveryType.shortRest,
        );
        p.setCurrentUses(6);
        expect(p.currentUses, 6);
        p.use(1);
        expect(p.currentUses, 5);
        p.restoreFull();
        expect(p.currentUses, 5);
        p.setCurrentUses(2);
        p.restoreFull();
        expect(p.currentUses, 4);
        p.setCurrentUses(0);
        p.restoreFull();
        expect(p.currentUses, 4);
      },
    );
    test(
        'zero, full and overspend never become negative; invalid costs are no-ops',
        () {
      for (final current in [0, 2, 4, 6]) {
        final p = ResourcePool(
          currentUses: current,
          maxUses: 4,
          recoveryType: RecoveryType.longRest,
        );
        p.use(0);
        p.use(-2);
        expect(p.currentUses, current);
        p.use(100);
        expect(p.currentUses, 0);
      }
    });
    test('explicit restoration and manual adjustment preserve real extras', () {
      final p = ResourcePool(
        currentUses: 6,
        maxUses: 4,
        recoveryType: RecoveryType.manual,
      );
      p.restore(1);
      expect(p.currentUses, 7);
      p.restore(0);
      p.restore(-3);
      expect(p.currentUses, 7);
      p.setCurrentUses(-1);
      expect(p.currentUses, 0);
    });
  });

  group('New built-in metadata and serialization compatibility', () {
    test(
      'actual loaded standard short-rest records are short-rest resources',
      () {
        for (final id in [
          'ki',
          'second-wind',
          'action-surge-1-use',
          'bardic-inspiration-d8',
          'channel-divinity-1-rest',
          'channel-divinity',
        ]) {
          expect(
            FeatureService.getFeatureById(id)!.resourcePool!.recoveryType,
            RecoveryType.shortRest,
            reason: id,
          );
        }
        expect(
          FeatureService.getFeatureById('rage')!.resourcePool!.recoveryType,
          RecoveryType.longRest,
        );
      },
    );
    test(
      'both enum encodings preserve declared recovery and above-normal values',
      () {
        for (final type in RecoveryType.values) {
          for (final encoding in [type.name, type.toString()]) {
            final p = ResourcePool.fromJson({
              'currentUses': 6,
              'maxUses': 4,
              'recoveryType': encoding,
            });
            expect(p.recoveryType, type);
            expect(p.currentUses, 6);
            expect(ResourcePool.fromJson(p.toJson()).currentUses, 6);
          }
        }
      },
    );
    // Intentionally separate: enum parsing cannot infer that a persisted
    // RecoveryType.longRest field on an old built-in Ki record was erroneous.
    // Root replaces this skip with the real metadata-repair boundary, once chosen.
    test(
      'legacy Ki with stale long-rest metadata recovers after explicit repair',
      () async {
        var c = hero('legacy-ki', 'monk');
        final f = c.features.firstWhere((f) => f.id == 'ki');
        f.resourcePool!.recoveryType = RecoveryType.longRest;
        f.resourcePool!.currentUses = 0;
        await box.put(c.id, c);
        c = await persistReload(c);
        FeatureService.repairBuiltInResourceRecovery(c);
        c.shortRest();
        c = await persistReload(c);
        expect(
          c.features.firstWhere((f) => f.id == 'ki').resourcePool!.currentUses,
          c.level,
        );
      },
    );
  });

  group('Real built-in current-state cycle for every class', () {
    for (final classId in classIds) {
      for (final baseline in ['zero', 'below', 'full', 'above']) {
        test(
          '$classId: $baseline remainder survives spend, rest and Hive reopen',
          () async {
            var c = hero('$classId-$baseline', classId);
            await box.put(c.id, c);
            int initial(int norm) => switch (baseline) {
                  'zero' => 0,
                  'below' => math.max(0, norm - 1),
                  'full' => norm,
                  _ => norm + 2,
                };
            final resourceExpectations = <String, int>{};
            for (final f in c.features.where((f) => f.resourcePool != null)) {
              f.resourcePool!.setCurrentUses(initial(f.resourcePool!.maxUses));
              resourceExpectations[f.id] = initial(f.resourcePool!.maxUses);
            }
            final slotIndex = c.maxSpellSlots.indexWhere((n) => n > 0);
            if (slotIndex >= 0) {
              c.setSpellSlotCount(
                slotIndex + 1,
                initial(c.maxSpellSlots[slotIndex]),
              );
            }
            c = await persistReload(c);
            for (final f in c.features.where((f) => f.resourcePool != null)) {
              expect(
                f.resourcePool!.currentUses,
                resourceExpectations[f.id],
                reason: '$classId saved ${f.id}',
              );
              f.resourcePool!.use(1);
              resourceExpectations[f.id] = math.max(
                0,
                resourceExpectations[f.id]! - 1,
              );
            }
            int? expectedSlot;
            if (slotIndex >= 0) {
              expectedSlot = math.max(0, c.spellSlots[slotIndex] - 1);
              c.useSpellSlot(slotIndex + 1);
            }
            c = await persistReload(c);
            for (final f in c.features.where((f) => f.resourcePool != null)) {
              expect(
                f.resourcePool!.currentUses,
                resourceExpectations[f.id],
                reason: '$classId spent ${f.id}',
              );
            }
            final cdBeforeRest = c.channelDivinityResources.fold(
                c.channelDivinityCharges,
                (int current, f) =>
                    math.max(current, resourceExpectations[f.id]!));
            final cdAfterRest = math.max(
                cdBeforeRest,
                c.channelDivinityResource?.resourcePool?.maxUses ??
                    c.getMaxChannelDivinityCharges());
            c.shortRest();
            for (final f in c.features.where((f) => f.resourcePool != null)) {
              final p = f.resourcePool!;
              if (Character.isChannelDivinityResource(f)) {
                resourceExpectations[f.id] = cdAfterRest;
              } else if (p.recoveryType == RecoveryType.shortRest) {
                resourceExpectations[f.id] = math.max(
                  resourceExpectations[f.id]!,
                  p.maxUses,
                );
              }
              expect(
                p.currentUses,
                resourceExpectations[f.id],
                reason: '$classId short ${f.id}',
              );
            }
            if (slotIndex >= 0) {
              if (classId == 'warlock') {
                expectedSlot = math.max(
                  expectedSlot!,
                  c.maxSpellSlots[slotIndex],
                );
              }
              expect(
                c.spellSlots[slotIndex],
                expectedSlot,
                reason: 'short-rest slots for $classId',
              );
            }
            c = await persistReload(c);
            c.longRest();
            c = await persistReload(c);
            for (final f in c.features.where((f) => f.resourcePool != null)) {
              final p = f.resourcePool!;
              if (Character.isChannelDivinityResource(f)) {
                resourceExpectations[f.id] = cdAfterRest;
              } else if (p.recoveryType == RecoveryType.shortRest ||
                  p.recoveryType == RecoveryType.longRest) {
                resourceExpectations[f.id] = math.max(
                  resourceExpectations[f.id]!,
                  p.maxUses,
                );
              }
              expect(
                p.currentUses,
                resourceExpectations[f.id],
                reason: '$classId long ${f.id}',
              );
            }
            if (slotIndex >= 0) {
              expect(
                c.spellSlots[slotIndex],
                math.max(expectedSlot!, c.maxSpellSlots[slotIndex]),
              );
            }
            expect(c.level, 8);
            expect(c.classes.single.level, 8);
          },
        );
      }
      test(
        '$classId: rest preserves all manually marked effects across reopen',
        () async {
          var c = hero('marked-$classId', classId);
          markEffects(c);
          await box.put(c.id, c);
          c.arcaneRecoveryUsed = true;
          c.naturalRecoveryUsed = true;
          c.signatureSpellsUsed = {'signature-a': true};
          c.shortRest();
          c = await persistReload(c);
          expectEffects(c);
          expect(c.arcaneRecoveryUsed, true);
          expect(c.naturalRecoveryUsed, true);
          expect(c.signatureSpellsUsed['signature-a'], false);
          c.longRest();
          c = await persistReload(c);
          expectEffects(c);
          expect(c.arcaneRecoveryUsed, false);
          expect(c.naturalRecoveryUsed, false);
        },
      );
    }
  });

  group('Explicit recovery dispatch', () {
    for (final current in [2, 6]) {
      test(
        'rest dispatch preserves manual/dawn/recharge/perTurn resources at current$current',
        () async {
          var c = hero('recovery-types-$current', 'fighter');
          for (final type in RecoveryType.values) {
            c.features.add(
              CharacterFeature(
                id: 'cycle-custom-${type.name}',
                nameEn: 'Cycle ${type.name}',
                nameRu: 'Cycle ${type.name}',
                descriptionEn: '',
                descriptionRu: '',
                type: FeatureType.resourcePool,
                minLevel: 1,
                resourcePool: ResourcePool(
                  currentUses: current,
                  maxUses: 4,
                  recoveryType: type,
                ),
              ),
            );
          }
          await box.put(c.id, c);
          c.shortRest();
          c = await persistReload(c);
          for (final type in RecoveryType.values) {
            final p = c.features
                .firstWhere((f) => f.id == 'cycle-custom-${type.name}')
                .resourcePool!;
            expect(
              p.currentUses,
              type == RecoveryType.shortRest ? math.max(current, 4) : current,
              reason: 'short ${type.name}',
            );
          }
          c.longRest();
          c = await persistReload(c);
          for (final type in RecoveryType.values) {
            final p = c.features
                .firstWhere((f) => f.id == 'cycle-custom-${type.name}')
                .resourcePool!;
            expect(
              p.currentUses,
              [RecoveryType.shortRest, RecoveryType.longRest].contains(type)
                  ? math.max(current, 4)
                  : current,
              reason: 'long ${type.name}',
            );
          }
        },
      );
    }
  });

  group('Independent state and preservation on save', () {
    for (final classId in classIds) {
      test(
        '$classId: assigning built-in features does not share pools or slots',
        () async {
          final a = hero('independent-a', classId),
              b = hero('independent-b', classId);
          await box.put(a.id, a);
          await box.put(b.id, b);
          for (final af in a.features.where((f) => f.resourcePool != null)) {
            final bf = b.features.firstWhere((f) => f.id == af.id);
            final registry = FeatureService.getFeatureById(af.id)!;
            final before = bf.resourcePool!.currentUses,
                registryBefore = registry.resourcePool!.currentUses;
            expect(identical(af.resourcePool, bf.resourcePool), false);
            expect(identical(af.resourcePool, registry.resourcePool), false);
            af.resourcePool!.setCurrentUses(af.resourcePool!.maxUses + 2);
            af.resourcePool!.use(1);
            expect(bf.resourcePool!.currentUses, before);
            expect(registry.resourcePool!.currentUses, registryBefore);
          }
          if (a.spellSlots.isNotEmpty) {
            final old = List<int>.from(b.spellSlots);
            a.setSpellSlotCount(1, 6);
            expect(b.spellSlots, old);
          }
          await a.save();
          await b.save();
        },
      );
    }
    test(
      'save does not grant Primal Champion again or replace pinned AC',
      () async {
        var c = hero('primal-save', 'barbarian', level: 20);
        c.abilityScores.strength = 16;
        c.abilityScores.constitution = 16;
        c.armorClass = 22;
        expect(c.hasFeatureId('primal-champion'), true);
        await box.put(c.id, c);
        for (var i = 0; i < 3; i++) {
          c = await persistReload(c);
        }
        expect(c.abilityScores.strength, 16);
        expect(c.abilityScores.constitution, 16);
        expect(c.maxHp, 30);
        expect(c.armorClass, 22);
        expect(c.armorClassOverride, 22);
      },
    );
    test(
        'AC override survives equipment/stat recalculation until explicitly cleared',
        () async {
      var c = hero('ac-pin', 'fighter');
      c.armorClass = 19;
      await box.put(c.id, c);
      c.abilityScores.dexterity = 18;
      c.recalculateAC();
      c = await persistReload(c);
      expect(c.calculatedArmorClass, 14);
      expect(c.armorClass, 19);
      expect(c.armorClassOverride, 19);
      c.clearArmorClassOverride();
      c = await persistReload(c);
      expect(c.armorClassOverride, isNull);
      expect(c.armorClass, 14);
    });
    test(
      'save preserves multiclass snapshot and extras without levelling',
      () async {
        var c = hero(
          'multiclass-save',
          'fighter',
          level: 5,
          classes: [
            CharacterClass(
              id: 'fighter',
              name: 'Fighter',
              level: 3,
              isPrimary: true,
            ),
            CharacterClass(
              id: 'wizard',
              name: 'Wizard',
              level: 2,
              subclass: 'evocation',
            ),
          ],
        );
        c.armorClass = 21;
        c.setSpellSlotCount(1, 6);
        await box.put(c.id, c);
        c = await persistReload(c);
        expect(c.level, 5);
        expect(c.classes.map((x) => x.level).toList(), [3, 2]);
        expect(c.classes[1].subclass, 'evocation');
        expect(c.spellSlots, [6]);
        expect(c.maxSpellSlots, [0]);
        expect(c.armorClass, 21);
      },
    );
    test(
      'recalculating resource norms never refills spent uses or clips extras',
      () {
        final c = hero('norm', 'bard');
        final f = c.features.firstWhere(
          (f) => f.resourcePool?.calculationFormula != null,
        );
        f.resourcePool!.currentUses = 6;
        c.abilityScores.charisma = 14;
        FeatureService.updateFeatureMaxUses(c);
        expect(f.resourcePool!.maxUses, 2);
        expect(f.resourcePool!.currentUses, 6);
        f.resourcePool!.currentUses = 0;
        c.abilityScores.charisma = 18;
        FeatureService.updateFeatureMaxUses(c);
        expect(f.resourcePool!.maxUses, 4);
        expect(f.resourcePool!.currentUses, 0);
      },
    );
  });

  group('HP, forms, and invalid actions', () {
    test('damage and healing preserve real above-normal HP', () async {
      var c = hero('hp-extras', 'fighter');
      c.currentHp = 36;
      await box.put(c.id, c);
      await c.takeDamage(1);
      expect(c.currentHp, 35);
      await c.heal(3);
      expect(c.currentHp, 35);
      c.longRest();
      c = await persistReload(c);
      expect(c.currentHp, 35);
    });
    test(
      'zero and negative damage or healing cannot create HP or log events',
      () async {
        var c = hero('invalid-hp', 'fighter');
        c.combatState.startCombat(12);
        c.temporaryHp = 5;
        await box.put(c.id, c);
        final stamp = c.updatedAt;
        await c.takeDamage(-10);
        await c.takeDamage(0);
        await c.heal(-10);
        await c.heal(0);
        expect(c.currentHp, 30);
        expect(c.temporaryHp, 5);
        expect(c.updatedAt, stamp);
        expect(c.combatState.combatLog, isEmpty);
        expect(c.combatState.totalDamageTaken, 0);
        expect(c.combatState.totalHealing, 0);
      },
    );
    test(
      'exact beast HP damage exits form without harming the true body',
      () async {
        var c = hero('beast-exact', 'druid');
        c.isWildShaped = true;
        c.beastMaxHp = 10;
        c.beastCurrentHp = 10;
        await box.put(c.id, c);
        await c.takeDamage(10);
        c = await persistReload(c);
        expect(c.isWildShaped, false);
        expect(c.beastCurrentHp, 0);
        expect(c.currentHp, 30);
      },
    );
    test(
      'temporary HP absorbs first and beast overflow reaches true HP',
      () async {
        var c = hero('beast-overflow', 'druid');
        c.temporaryHp = 3;
        c.isWildShaped = true;
        c.beastMaxHp = 10;
        c.beastCurrentHp = 4;
        await box.put(c.id, c);
        await c.takeDamage(9);
        c = await persistReload(c);
        expect(c.temporaryHp, 0);
        expect(c.beastCurrentHp, 0);
        expect(c.isWildShaped, false);
        expect(c.currentHp, 28);
      },
    );
    test(
        'above-normal beast HP survives healing; ending frenzy is an explicit one-time event',
        () async {
      var c = hero('beast-extra', 'druid');
      c.isWildShaped = true;
      c.beastMaxHp = 4;
      c.beastCurrentHp = 6;
      c.isRaging = true;
      c.isFrenzied = true;
      c.exhaustionLevel = 1;
      await box.put(c.id, c);
      await c.takeDamage(1);
      await c.heal(1);
      expect(c.beastCurrentHp, 5);
      c.endRage();
      expect(c.exhaustionLevel, 2);
      c.endRage();
      expect(c.exhaustionLevel, 2);
      c = await persistReload(c);
      expect(c.isRaging, false);
      expect(c.isFrenzied, false);
      expect(c.exhaustionLevel, 2);
    });
    test('healing from zero HP resets death-save counters', () async {
      var c = hero('healing-zero', 'fighter');
      c.currentHp = 0;
      c.deathSaves.successes = 1;
      c.deathSaves.failures = 2;
      c.combatState.startCombat(10);
      c.combatState.markDeathSaveRolledThisRound();
      await box.put(c.id, c);
      await c.heal(1);
      c = await persistReload(c);
      expect(c.currentHp, 1);
      expect(c.deathSaves.successes, 0);
      expect(c.deathSaves.failures, 0);
      expect(c.combatState.lastDeathSaveRound, isNull);
    });
  });

  group('Legacy array shapes and separate scalar resources', () {
    test('short current slot arrays grow safely during long rest', () async {
      var c = hero('short-slots', 'wizard');
      c.spellSlots = [6];
      c.maxSpellSlots = [4, 2, 1];
      await box.put(c.id, c);
      c.longRest();
      c = await persistReload(c);
      expect(c.spellSlots, [6, 2, 1]);
    });
    test(
      'longer current arrays retain table-granted extra slot levels',
      () async {
        var c = hero('long-slots', 'wizard');
        c.spellSlots = [6, 1, 3];
        c.maxSpellSlots = [4, 2];
        await box.put(c.id, c);
        c.longRest();
        c = await persistReload(c);
        expect(c.spellSlots, [6, 2, 3]);
        expect(c.maxSpellSlots, [4, 2]);
      },
    );
    test(
      'manual extra slot at a zero-normal level is spendable and survives rest',
      () async {
        var c = hero('zero-normal-slot', 'fighter');
        await box.put(c.id, c);
        c.setSpellSlotCount(2, 6);
        c.useSpellSlot(2);
        c.longRest();
        c = await persistReload(c);
        expect(c.spellSlots, [0, 5]);
        expect(c.maxSpellSlots, [0, 0]);
      },
    );
    test(
        'rest preserves overflowing Hit Dice and restores rounded-down half below normal',
        () async {
      var c = hero('hitdice-extra', 'fighter', level: 3);
      c.hitDice = [6];
      c.maxHitDice = 3;
      await box.put(c.id, c);
      c.longRest();
      c = await persistReload(c);
      expect(c.hitDice, [6]);
      c.hitDice = [0];
      c.longRest();
      c = await persistReload(c);
      expect(c.hitDice, [1]);
    });
    test('empty legacy Hit Dice arrays do not crash the rest cycle', () async {
      var c = hero('empty-hitdice', 'fighter');
      c.hitDice = [];
      await box.put(c.id, c);
      c.shortRest();
      c.longRest();
      c = await persistReload(c);
      expect(c.hitDice, everyElement(greaterThanOrEqualTo(0)));
    });
    test(
      'Wild Shape and Channel Divinity scalars preserve extras on both rests',
      () async {
        var d = hero('wildshape-scalar', 'druid');
        d.wildShapeCharges = 6;
        await box.put(d.id, d);
        d.wildShapeCharges--;
        d.shortRest();
        d.longRest();
        d = await persistReload(d);
        expect(d.wildShapeCharges, 5);
        d.wildShapeCharges = 0;
        d.shortRest();
        expect(d.wildShapeCharges, 2);
        var c = hero('cd-scalar', 'cleric');
        c.channelDivinityCharges = 6;
        await box.put(c.id, c);
        c.channelDivinityCharges--;
        c.shortRest();
        c.longRest();
        c = await persistReload(c);
        expect(c.channelDivinityCharges, 5);
        c.setChannelDivinityCharges(0);
        c.shortRest();
        expect(c.channelDivinityCharges, 2);
      },
    );
  });
  test(
      'keyword fragments do not hide unrelated standard abilities or homebrew fallback',
      () {
    CharacterFeature feature(String id, String name) => CharacterFeature(
          id: id,
          nameEn: name,
          nameRu: name,
          descriptionEn: '',
          descriptionRu: '',
          type: FeatureType.action,
          minLevel: 1,
        );
    expect(
      AbilitiesTabLogic(hero('aura', 'paladin'))
          .shouldShowInList(feature('aura-of-courage', 'Aura of Courage')),
      true,
    );
    expect(
      AbilitiesTabLogic(hero('peerless', 'bard'))
          .shouldShowInList(feature('peerless-skill', 'Peerless Skill')),
      true,
    );
    final custom = Character(
      id: 'custom',
      name: 'Custom',
      race: 'human',
      characterClass: 'Rune Knight',
      level: 3,
      maxHp: 20,
      currentHp: 20,
      spellSlots: [],
      maxSpellSlots: [],
      abilityScores: AbilityScores(
        strength: 10,
        dexterity: 10,
        constitution: 10,
        intelligence: 10,
        wisdom: 10,
        charisma: 10,
      ),
    );
    expect(
      AbilitiesTabLogic(custom)
          .shouldShowInList(feature('rune-dragon-luck', 'Dragon Luck')),
      true,
    );
  });
}
