import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/magic/class_action_state.dart';
import 'package:qd_and_d/core/magic/companion_state.dart';
import 'package:qd_and_d/core/magic/magic_slots.dart';
import 'package:qd_and_d/core/magic/spell_use.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/condition.dart';
import 'package:qd_and_d/core/progression/character_class_rules.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/class_session_actions_service.dart';
import 'package:qd_and_d/core/services/feature_slot_actions_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/services/spell_cast_actions_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'multiclass_magic_flow_test.dart' as flow;

void acquire(Character c, String id) =>
    c.features.add(FeatureService.getFeatureById(id)!.copyForCharacter());
String rangerDigest(Character c) =>
    CharacterClassRules.resolve(c.classes.singleWhere((v) => v.id == 'ranger'))
        .snapshot['digest'];
Future<int> awareness(Character c,
        {MagicPool pool = MagicPool.shared,
        int circle = 1,
        bool ruling = false,
        Future<void> Function(Character)? write}) =>
    FeatureSlotActionsService.primevalAwareness(c,
        classId: 'ranger',
        featureId: 'primeval-awareness',
        pool: pool,
        circle: circle,
        locale: 'ru',
        expectedRulesDigest: rangerDigest(c),
        tableRuling: ruling,
        write: write ?? (_) async {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-class-actions-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await SpellService.loadSpells();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  test(
      'Hunter mark casts once with concentration, retargets for free, and dropping cannot clear an unrelated spell',
      () async {
    final c = flow.mixed({'ranger': 3}),
        mark = SpellService.getSpellById('hunters-mark')!;
    c.spellSlots = [2];
    c.maxSpellSlots = [3];
    flow.learn(c, mark, 'class:ranger');
    final option = SpellUse.options(c, mark).single;
    await SpellCastActionsService.cast(c, mark, option,
        locale: 'ru', write: (_) async {});
    expect(c.spellSlots, [1]);
    expect(c.concentratingOn, mark.id);
    expect(c.isHuntersMarkActive, true);
    await ClassSessionActionsService.huntersMark(c,
        target: 'Вожак', write: (_) async {});
    expect(c.huntersMarkTarget, 'Вожак');
    expect(c.spellSlots, [1]);
    c.concentratingOn = 'another-spell';
    await ClassSessionActionsService.huntersMark(c,
        drop: true, write: (_) async {});
    expect(c.concentratingOn, 'another-spell');
    expect(c.isHuntersMarkActive, false);
    expect(
        await ClassSessionActionsService.huntersMark(c,
            target: 'Late text', write: (_) async {}),
        false);
  });
  test(
      'Replacing concentration clears a mark atomically; failure restores cost, target, concentration and log',
      () async {
    final c = flow.mixed({'ranger': 3, 'wizard': 3});
    c.spellSlots = [2];
    c.maxSpellSlots = [4];
    final mark = SpellService.getSpellById('hunters-mark')!,
        spell = SpellService.getSpellById('detect-magic')!;
    c.concentratingOn = mark.id;
    c.isHuntersMarkActive = true;
    c.huntersMarkTarget = 'Огр';
    flow.learn(c, spell, 'class:wizard', prepared: true);
    final option = SpellUse.options(c, spell)
            .firstWhere((o) => o.method == SpellUseMethod.sharedSlot),
        before = jsonEncode(c.toJson());
    await expectLater(
        SpellCastActionsService.cast(c, spell, option,
            locale: 'ru', expectedConcentration: mark.id, write: (_) async {
          throw StateError('disk');
        }),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
    await SpellCastActionsService.cast(c, spell, option,
        locale: 'ru', expectedConcentration: mark.id, write: (_) async {});
    expect(c.isHuntersMarkActive, false);
    expect(c.huntersMarkTarget, isNull);
    expect(c.concentratingOn, spell.id);
  });
  test(
      'Rage ends mark concentration, and hidden/retarget failures never leave changed values',
      () async {
    final c = flow.mixed({'barbarian': 3, 'rogue': 1});
    acquire(c, 'rage');
    c.concentratingOn = 'hunters-mark';
    c.isHuntersMarkActive = true;
    c.huntersMarkTarget = 'Огр';
    final before = jsonEncode(c.toJson());
    await expectLater(
        ClassSessionActionsService.huntersMark(c, target: 'Другой',
            write: (_) async {
          throw StateError('disk');
        }),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
    await expectLater(
        ClassSessionActionsService.hidden(c, true, write: (_) async {
          throw StateError('disk');
        }),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
    await ClassSessionActionsService.rage(c, 'rage', true,
        expectedConcentration: 'hunters-mark', write: (_) async {});
    expect(c.concentratingOn, isNull);
    expect(c.isHuntersMarkActive, false);
    expect(c.huntersMarkTarget, isNull);
  });
  test(
      'Primeval Awareness uses one selected slot and log, leaves concentration, and needs explicit Pact ruling',
      () async {
    final c = flow.mixed({'ranger': 3, 'warlock': 3});
    acquire(c, 'primeval-awareness');
    flow.slots(c, shared: 6, maxShared: 4, pact: 2, circle: 2);
    c.concentratingOn = 'other';
    expect(await awareness(c), 1);
    expect(c.spellSlots, [5]);
    expect(c.concentratingOn, 'other');
    expect(c.combatState.combatLog, hasLength(1));
    final before = jsonEncode(c.toJson());
    await expectLater(
        awareness(c, pool: MagicPool.pact, circle: 2), throwsStateError);
    expect(jsonEncode(c.toJson()), before);
    expect(
        await awareness(c, pool: MagicPool.pact, circle: 2, ruling: true), 2);
    expect(MagicSlots.read(c).pact!.current, 1);
  });
  test(
      'Queued last slot, failed write, stale owner and incapacitation are checked before spending',
      () async {
    final c = flow.mixed({'ranger': 3});
    acquire(c, 'primeval-awareness');
    c.spellSlots = [1];
    c.maxSpellSlots = [3];
    final before = jsonEncode(c.toJson());
    await expectLater(
        awareness(c, write: (_) async {
          throw StateError('disk');
        }),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
    final gate = Completer<void>();
    final first = awareness(c, write: (_) async => gate.future);
    final second = awareness(c);
    final secondCheck = expectLater(second, throwsStateError);
    gate.complete();
    await first;
    await secondCheck;
    expect(c.spellSlots, [0]);
    expect(c.combatState.combatLog, hasLength(1));
    c.spellSlots = [2];
    c.activeConditions = [ConditionType.incapacitated];
    await expectLater(awareness(c), throwsStateError);
    expect(c.spellSlots, [2]);
  });
  test(
      'Intervention failure is persisted until long rest; success requires player-managed readiness',
      () async {
    final c = flow.mixed({'cleric': 10});
    acquire(c, 'divine-intervention');
    final failed = await ClassSessionActionsService.divineIntervention(c,
        locale: 'ru',
        rollPercentile: () => 100,
        write: StorageService.saveCharacter);
    expect(failed.success, false);
    expect(ClassActionState.interventionAttempted(c), true);
    await expectLater(
        ClassSessionActionsService.divineIntervention(c,
            locale: 'ru', rollPercentile: () => 1, write: (_) async {}),
        throwsStateError);
    c.shortRest();
    expect(ClassActionState.interventionAttempted(c), true);
    c.longRest();
    expect(ClassActionState.interventionAttempted(c), false);
    final success = await ClassSessionActionsService.divineIntervention(c,
        locale: 'en',
        rollPercentile: () => 10,
        write: StorageService.saveCharacter);
    expect(success.success, true);
    c.longRest();
    expect(c.divineInterventionUsed, true);
    await ClassSessionActionsService.resetDivineIntervention(c,
        write: (_) async {});
    expect(c.divineInterventionUsed, false);
  });
  test(
      'Own cleric level governs Intervention; failed writes and unsupported cooldown payloads are preserved',
      () async {
    final c = flow.mixed({'cleric': 10, 'fighter': 10});
    acquire(c, 'divine-intervention');
    final before = jsonEncode(c.toJson());
    await expectLater(
        ClassSessionActionsService.divineIntervention(c,
            locale: 'en',
            rollPercentile: () => 1,
            write: (_) async {
              throw StateError('disk');
            }),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
    final result = await ClassSessionActionsService.divineIntervention(c,
        locale: 'en', rollPercentile: () => 11, write: (_) async {});
    expect(result.success, false);
    expect(result.roll, 11);
    final cap = flow.mixed({'cleric': 20});
    acquire(cap, 'divine-intervention');
    final automatic = await ClassSessionActionsService.divineIntervention(cap,
        locale: 'en',
        rollPercentile: () => throw StateError('Should not roll'),
        write: (_) async {});
    expect(automatic.success, true);
    expect(automatic.roll, isNull);
    final future = flow.mixed({'cleric': 10});
    acquire(future, 'divine-intervention');
    future.magicData = {
      'version': 1,
      'classActions': {'version': 2}
    };
    final futureBefore = jsonEncode(future.toJson());
    await expectLater(
        ClassSessionActionsService.divineIntervention(future,
            locale: 'en', write: (_) async {}),
        throwsFormatException);
    expect(jsonEncode(future.toJson()), futureBefore);
  });
  test(
      'Cooldown survives codec and actual restart while Pact-only transfer retains separate payment',
      () async {
    final c = flow.mixed({'cleric': 10, 'warlock': 3});
    acquire(c, 'divine-intervention');
    flow.slots(c, shared: 2, pact: 3, circle: 2);
    await ClassSessionActionsService.divineIntervention(c,
        locale: 'en',
        rollPercentile: () => 100,
        write: StorageService.saveCharacter);
    final transferred =
        QdndBundleCodec.characterFromJson(QdndBundleCodec.characterToJson(c));
    expect(ClassActionState.interventionAttempted(transferred), true);
    expect(MagicSlots.read(transferred).pact!.current, 3);
    await Hive.close();
    await StorageService.init();
    final restored = StorageService.getCharacter(c.id)!;
    expect(ClassActionState.interventionAttempted(restored), true);
    expect(MagicSlots.read(restored).pact!.current, 3);
    await GameplayActionsService.rest(restored, short: false);
    expect(ClassActionState.interventionAttempted(restored), false);
  });
  test(
      'Companion and Wild Shape coexist; zero companion HP never changes the form or hero HP',
      () async {
    final c = flow.mixed({'ranger': 3, 'druid': 2});
    c.isWildShaped = true;
    c.beastName = 'Медведь';
    c.beastCurrentHp = 34;
    c.beastMaxHp = 34;
    expect(CompanionState.read(c), isNull);
    await ClassSessionActionsService.editCompanion(
        c, const CompanionState(name: 'Волк', current: 6, maximum: 4),
        expected: null, write: (_) async {});
    await ClassSessionActionsService.changeCompanionHealth(c, 6,
        healing: false, write: (_) async {});
    expect(CompanionState.read(c)!.current, 0);
    expect(c.isWildShaped, true);
    expect(c.beastCurrentHp, 34);
    expect(c.beastName, 'Медведь');
    c.longRest();
    expect(CompanionState.read(c)!.current, 0);
    final restored =
        QdndBundleCodec.characterFromJson(QdndBundleCodec.characterToJson(c));
    expect(CompanionState.read(restored)!.name, 'Волк');
    expect(restored.beastCurrentHp, 34);
  });
  test(
      'Legacy companion reading is read-only; edits and healing preserve overfill and rollback on failure',
      () async {
    final c = flow.mixed({'ranger': 3});
    c.beastName = 'Волк';
    c.beastCurrentHp = 6;
    c.beastMaxHp = 4;
    final before = jsonEncode(c.toJson());
    expect(CompanionState.read(c)!.current, 6);
    expect(jsonEncode(c.toJson()), before);
    await expectLater(
        ClassSessionActionsService.changeCompanionHealth(c, 1, healing: false,
            write: (_) async {
          throw StateError('disk');
        }),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
    await ClassSessionActionsService.changeCompanionHealth(c, 1,
        healing: true, write: (_) async {});
    expect(CompanionState.read(c)!.current, 6);
    final opened = CompanionState.read(c);
    await ClassSessionActionsService.changeCompanionHealth(c, 2,
        healing: false, write: StorageService.saveCharacter);
    await expectLater(
        ClassSessionActionsService.editCompanion(
            c, const CompanionState(name: 'Старое', current: 6, maximum: 4),
            expected: opened, write: (_) async {}),
        throwsStateError);
    await Hive.close();
    await StorageService.init();
    expect(CompanionState.read(StorageService.getCharacter(c.id)!)!.current, 4);
  });
  test(
      'Unknown companion state cannot be replaced; unrelated future-compatible class fields survive changes',
      () async {
    final c = flow.mixed({'ranger': 3});
    c.magicData = {
      'version': 1,
      'classActions': {
        'version': 1,
        'companion': {'version': 2},
        'other': {'keep': true}
      }
    };
    final before = jsonEncode(c.toJson());
    expect(() => CompanionState.read(c), throwsFormatException);
    await expectLater(
        ClassSessionActionsService.editCompanion(
            c, const CompanionState(name: 'Волк', current: 1, maximum: 4),
            expected: null, write: (_) async {}),
        throwsFormatException);
    expect(jsonEncode(c.toJson()), before);
    c.magicData = {
      'version': 1,
      'classActions': {
        'version': 1,
        'other': {'keep': true}
      }
    };
    await ClassSessionActionsService.editCompanion(
        c, const CompanionState(name: 'Волк', current: 1, maximum: 4),
        expected: null, write: (_) async {});
    expect((c.magicData['classActions'] as Map)['other'], {'keep': true});
  });
  test(
      'Rage helpers require acquired own-level features rather than total character level',
      () async {
    final c = flow.mixed({'barbarian': 2, 'fighter': 18});
    c.isRaging = true;
    acquire(c, 'reckless-attack');
    await ClassSessionActionsService.helpers(c,
        reckless: true, write: (_) async {});
    expect(c.isReckless, true);
    await expectLater(
        ClassSessionActionsService.helpers(c,
            frenzied: true, write: (_) async {}),
        throwsStateError);
    final noFeature = flow.mixed({'barbarian': 3})..isRaging = true;
    await expectLater(
        ClassSessionActionsService.helpers(noFeature,
            reckless: true, write: (_) async {}),
        throwsStateError);
  });
}
