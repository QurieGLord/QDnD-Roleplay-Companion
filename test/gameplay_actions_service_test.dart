import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/combat_state.dart';
import 'package:qd_and_d/core/models/condition.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'gameplay_state_reliability_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd_session_actions_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await CharacterDataService.loadAllData();
    await FeatureService.init();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
  });
  setUp(() async {
    await Hive.box<Character>('characters').clear();
  });

  test(
      'Shared Channel Divinity spends excess in sequence without changing capacity',
      () async {
    final c = fixtures.hero('channel-excess', 'cleric');
    c.setChannelDivinityCharges(6);
    final max = c.getMaxChannelDivinityCharges();
    await StorageService.saveCharacter(c);
    final results = await Future.wait([
      for (var i = 0; i < 3; i++) GameplayActionsService.spendChannelDivinity(c)
    ]);
    expect(results.every((v) => v), isTrue);
    expect(c.channelDivinityCharges, 3);
    expect(c.getMaxChannelDivinityCharges(), max);
    for (final f in c.channelDivinityResources) {
      expect(f.resourcePool!.currentUses, 3);
    }
  });

  test('Failed shared Channel Divinity spend restores all representations',
      () async {
    final c = fixtures.hero('channel-failed', 'cleric');
    c.setChannelDivinityCharges(6);
    await StorageService.saveCharacter(c);
    await Hive.box<Character>('characters').close();
    try {
      await expectLater(
          GameplayActionsService.spendChannelDivinity(c), throwsA(anything));
      expect(c.channelDivinityCharges, 6);
      for (final f in c.channelDivinityResources) {
        expect(f.resourcePool!.currentUses, 6);
      }
    } finally {
      await StorageService.init();
    }
  });

  test(
      'Sacred Weapon activation is one paid action and can end with no charges',
      () async {
    final c = fixtures.hero('sacred-once', 'paladin');
    final resource = c.channelDivinityResource!;
    c.setChannelDivinityCharges(2);
    await StorageService.saveCharacter(c);
    final results = await Future.wait([
      GameplayActionsService.activateResource(c, resource,
          activateSacredWeapon: true),
      GameplayActionsService.activateResource(c, resource,
          activateSacredWeapon: true),
    ]);
    expect(results.where((r) => r.spent).length, 1);
    expect(c.channelDivinityCharges, 1);
    expect(c.isSacredWeaponActive, isTrue);
    c.setChannelDivinityCharges(0);
    expect(await GameplayActionsService.endSacredWeapon(c), isTrue);
    expect(c.channelDivinityCharges, 0);
    expect(c.isSacredWeaponActive, isFalse);
  });

  test(
      'Failed Sacred Weapon activation restores both the effect and its reserve',
      () async {
    final c = fixtures.hero('sacred-failed', 'paladin');
    final resource = c.channelDivinityResource!;
    c.setChannelDivinityCharges(1);
    await StorageService.saveCharacter(c);
    await Hive.box<Character>('characters').close();
    try {
      await expectLater(
          GameplayActionsService.activateResource(c, resource,
              activateSacredWeapon: true),
          throwsA(anything));
      expect(c.channelDivinityCharges, 1);
      expect(c.isSacredWeaponActive, isFalse);
      expect(resource.resourcePool!.currentUses, 1);
    } finally {
      await StorageService.init();
    }
  });

  test(
      'queued slot clicks never lose uses, and above-normal edits survive rest',
      () async {
    final c = fixtures.hero('slots', 'wizard');
    await StorageService.saveCharacter(c);
    await GameplayActionsService.editSpellSlot(c, 1, 6);
    await Future.wait([
      for (int i = 0; i < 3; i++)
        GameplayActionsService.changeSpellSlot(c, 1, -1)
    ]);
    expect(c.spellSlots[0], 3);
    await GameplayActionsService.editSpellSlot(c, 1, 6);
    await GameplayActionsService.changeSpellSlot(c, 1, -1);
    await GameplayActionsService.rest(c, short: false);
    expect(c.spellSlots[0], 5);
    await GameplayActionsService.editSpellSlot(c, 9, 6);
    expect(c.maxSpellSlots[8], 0);
    await GameplayActionsService.changeSpellSlot(c, 9, -1);
    expect(c.spellSlots[8], 5);
  });

  test(
      'health damage handles temp HP, exact form zero and concentration log together',
      () async {
    final c = fixtures.hero('form', 'druid')
      ..currentHp = 17
      ..temporaryHp = 3
      ..isWildShaped = true
      ..beastCurrentHp = 4
      ..beastMaxHp = 8
      ..concentratingOn = 'focus';
    c.combatState.startCombat(10);
    await StorageService.saveCharacter(c);
    await GameplayActionsService.changeHealth(c, 7, healing: false);
    expect(c.currentHp, 17);
    expect(c.temporaryHp, 0);
    expect(c.beastCurrentHp, 0);
    expect(c.isWildShaped, isFalse);
    expect(c.concentratingOn, 'focus');
    expect(c.combatState.combatLog.map((e) => e.type),
        [CombatLogType.damage, CombatLogType.concentrationCheck]);
    expect(c.combatState.totalDamageTaken, 7);
  });

  test(
      'direct HP edit preserves marks; healing resets saves only on recovering from zero',
      () async {
    final c = fixtures.hero('health', 'fighter')
      ..activeConditions = [ConditionType.poisoned]
      ..exhaustionLevel = 2;
    c.deathSaves.successes = 1;
    c.deathSaves.failures = 2;
    await StorageService.saveCharacter(c);
    await GameplayActionsService.editHealth(c,
        current: 31, maximum: 20, temporary: 7);
    await GameplayActionsService.changeHealth(c, 3, healing: true);
    expect(c.currentHp, 31);
    expect(c.deathSaves.successes, 1);
    expect(c.deathSaves.failures, 2);
    await GameplayActionsService.rest(c, short: false);
    expect(c.currentHp, 31);
    expect(c.temporaryHp, 7);
    expect(c.activeConditions, [ConditionType.poisoned]);
    expect(c.exhaustionLevel, 2);
    await GameplayActionsService.editHealth(c,
        current: 0, maximum: 20, temporary: 0);
    await GameplayActionsService.changeHealth(c, 5, healing: true);
    expect(c.currentHp, 5);
    expect(c.deathSaves.successes, 0);
    expect(c.deathSaves.failures, 0);
  });

  test('manual and calculated armor modes are explicit and persisted',
      () async {
    final c = fixtures.hero('armor', 'monk');
    await StorageService.saveCharacter(c);
    await GameplayActionsService.editArmorClass(c, automatic: false, value: 19);
    c.recalculateAC();
    expect(c.armorClass, 19);
    await GameplayActionsService.editArmorClass(c, automatic: true, value: 19);
    expect(c.armorClass, c.calculatedArmorClass);
    expect(c.usesAutomaticArmorClass, isTrue);
  });

  test(
      'resource edit targets owned data and does not change another hero/template',
      () async {
    final c = fixtures.hero('resource-one', 'monk');
    final other = fixtures.hero('resource-two', 'monk');
    final f = c.features.firstWhere((f) => f.resourcePool != null);
    final copy = f.copyForCharacter();
    final originalOther = other.features
        .firstWhere((x) => x.id == f.id && x.resourcePool != null)
        .resourcePool!
        .currentUses;
    await StorageService.saveCharacter(c);
    await GameplayActionsService.editResource(c, copy, 15);
    await GameplayActionsService.changeResource(c, f, -1);
    expect(f.resourcePool!.currentUses, 14);
    expect(copy.resourcePool!.currentUses, isNot(15));
    expect(
        other.features
            .firstWhere((x) => x.id == f.id)
            .resourcePool!
            .currentUses,
        originalOther);
    expect(FeatureService.getFeatureById(f.id)!.resourcePool!.currentUses,
        isNot(14));
  });

  test(
      'resource activations and their healing are serialized, spent only when affordable and persisted together',
      () async {
    final c = fixtures.hero('second-wind', 'fighter')
      ..currentHp = 0
      ..maxHp = 100;
    c.deathSaves.failures = 2;
    c.combatState.startCombat(10);
    final feature = c.features.firstWhere((f) => f.id == 'second-wind');
    feature.resourcePool!.currentUses = 2;
    await StorageService.saveCharacter(c);
    final results = await Future.wait([
      for (var i = 0; i < 3; i++)
        GameplayActionsService.spendResource(c, feature, healing: 5)
    ]);
    expect(results, [true, true, false]);
    expect(feature.resourcePool!.currentUses, 0);
    expect(c.currentHp, 10);
    expect(c.deathSaves.failures, 0);
    expect(
        c.combatState.combatLog
            .where((e) => e.type == CombatLogType.healing)
            .length,
        2);
    expect(StorageService.getCharacter(c.id)!.currentHp, 10);
  });
  test(
      'failed resource activation restores reserve, healing, death saves and combat log',
      () async {
    final c = fixtures.hero('second-wind-failed', 'fighter')..currentHp = 0;
    c.deathSaves.failures = 2;
    c.combatState.startCombat(10);
    final feature = c.features.firstWhere((f) => f.id == 'second-wind');
    feature.resourcePool!.currentUses = 6;
    await StorageService.saveCharacter(c);
    final log = c.combatState.toJson(), timestamp = c.updatedAt;
    await Hive.box<Character>('characters').close();
    try {
      await expectLater(
          GameplayActionsService.spendResource(c, feature, healing: 5),
          throwsA(anything));
      expect(feature.resourcePool!.currentUses, 6);
      expect(c.currentHp, 0);
      expect(c.deathSaves.failures, 2);
      expect(c.combatState.toJson(), log);
      expect(c.updatedAt, timestamp);
    } finally {
      await StorageService.init();
    }
    expect(await GameplayActionsService.changeResource(c, feature, 0), false);
    final restored = StorageService.getCharacter(c.id)!;
    final restoredFeature =
        restored.features.firstWhere((f) => f.id == 'second-wind');
    expect(
        await GameplayActionsService.spendResource(restored, restoredFeature,
            healing: 5),
        true);
    expect(restoredFeature.resourcePool!.currentUses, 5);
  });
  test(
      'activation feedback measures actual healing at the cap, overfill and in another form',
      () async {
    final c = fixtures.hero('healing-feedback', 'fighter')
      ..maxHp = 100
      ..currentHp = 98;
    final feature = c.features.firstWhere((f) => f.id == 'second-wind');
    feature.resourcePool!.currentUses = 6;
    await StorageService.saveCharacter(c);
    expect(
        await GameplayActionsService.activateResource(c, feature, healing: 5),
        (spent: true, healed: 2));
    expect(c.currentHp, 100);
    expect(
        await GameplayActionsService.activateResource(c, feature, healing: 5),
        (spent: true, healed: 0));
    c.currentHp = 102;
    expect(
        await GameplayActionsService.activateResource(c, feature, healing: 5),
        (spent: true, healed: 0));
    expect(c.currentHp, 102);
    c.isWildShaped = true;
    c.beastCurrentHp = 1;
    c.beastMaxHp = 4;
    expect(
        await GameplayActionsService.activateResource(c, feature, healing: 5),
        (spent: true, healed: 3));
    expect(c.beastCurrentHp, 4);
    expect(c.currentHp, 102);
    expect(feature.resourcePool!.currentUses, 2);
  });
  test('CD direct edits use the visible authority and synchronize on action',
      () async {
    final c = fixtures.hero('cd', 'cleric');
    c.channelDivinityCharges = 0;
    final f = c.channelDivinityResource!;
    f.resourcePool!.currentUses = 6;
    await StorageService.saveCharacter(c);
    expect(GameplayActionsService.resourceCurrent(c, f), 0);
    expect(await GameplayActionsService.changeResource(c, f, -1), isFalse);
    expect(f.resourcePool!.currentUses, 6);
    await GameplayActionsService.editResource(c, f, 6);
    await GameplayActionsService.changeResource(c, f, -1);
    expect(c.channelDivinityCharges, 5);
    expect(
        c.channelDivinityResources
            .every((f) => f.resourcePool!.currentUses == 5),
        isTrue);
  });

  test(
      'missing Arcanum stays missing until explicit restoration; restored extras can be spent',
      () async {
    final c = fixtures.hero('arcanum', 'warlock', level: 11);
    c.features.removeWhere((f) => f.id.startsWith('mystic-arcanum'));
    await StorageService.saveCharacter(c);
    expect(GameplayActionsService.arcanumFeature(c, 6), isNull);
    expect(await GameplayActionsService.changeArcanum(c, 6, -1), isFalse);
    expect(GameplayActionsService.arcanumFeature(c, 6), isNull);
    await GameplayActionsService.changeArcanum(c, 6, 1);
    await GameplayActionsService.editArcanum(c, 6, 6);
    await GameplayActionsService.changeArcanum(c, 6, -1);
    expect(
        GameplayActionsService.arcanumFeature(c, 6)!.resourcePool!.currentUses,
        5);
    expect(GameplayActionsService.arcanumFeature(c, 7), isNull);
  });

  test('failed writes roll back actions and do not poison queued later actions',
      () async {
    final c = fixtures.hero('failure', 'cleric')
      ..isWildShaped = true
      ..beastCurrentHp = 2
      ..beastMaxHp = 4
      ..isRaging = true
      ..isFrenzied = true
      ..exhaustionLevel = 1
      ..temporaryHp = 3;
    c.combatState.startCombat(10);
    await StorageService.saveCharacter(c);
    final before = c.combatState.toJson();
    final slots = List<int>.from(c.spellSlots);
    final cd = c.channelDivinityCharges;
    final timestamp = c.updatedAt;
    await Hive.box<Character>('characters').close();
    try {
      await expectLater(
          GameplayActionsService.changeHealth(c, 100, healing: false),
          throwsA(anything));
      expect(c.isWildShaped, isTrue);
      expect(c.beastCurrentHp, 2);
      expect(c.temporaryHp, 3);
      expect(c.isRaging, isTrue);
      expect(c.isFrenzied, isTrue);
      expect(c.exhaustionLevel, 1);
      expect(c.combatState.toJson(), before);
      await expectLater(
          GameplayActionsService.editSpellSlot(c, 1, 6), throwsA(anything));
      expect(c.spellSlots, slots);
      await expectLater(
          GameplayActionsService.editResource(c, c.channelDivinityResource!, 6),
          throwsA(anything));
      expect(c.channelDivinityCharges, cd);
      await expectLater(
          GameplayActionsService.rest(c, short: false), throwsA(anything));
      expect(c.updatedAt, timestamp);
    } finally {
      await Hive.openBox<Character>('characters');
    }
    // A no-op is still queued, and must complete despite preceding failures.
    expect(await GameplayActionsService.changeSpellSlot(c, 1, 0), isFalse);
  });
}
