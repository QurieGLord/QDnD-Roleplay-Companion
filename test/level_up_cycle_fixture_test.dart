import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/magic/spellbook_state.dart';
import 'package:qd_and_d/core/progression/character_class_rules.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/features/character_level_up/cycle_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-levelup-cycle-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await SpellService.loadSpells();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await ItemService.loadItems();
  });
  setUp(() async {
    await Hive.box<Character>('characters').clear();
    await Hive.box('settings').clear();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('Twelve playable level-one heroes have only acquired rules and magic',
      () {
    final heroes = buildLevelUpCycleCharacters();
    expect(heroes.length, 12);
    expect(heroes.map((c) => c.id).toSet().length, 12);
    expect(heroes.map((c) => c.characterClass).toSet(), {
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
    });
    const hitPoints = {
      'barbarian': 14,
      'bard': 10,
      'cleric': 10,
      'druid': 10,
      'fighter': 12,
      'monk': 10,
      'paladin': 12,
      'ranger': 12,
      'rogue': 10,
      'sorcerer': 9,
      'warlock': 10,
      'wizard': 8
    };
    const spellCounts = {
      'bard': (2, 4),
      'cleric': (3, null),
      'druid': (2, null),
      'sorcerer': (4, 2),
      'warlock': (2, 2),
      'wizard': (3, 6)
    };
    for (final c in heroes) {
      final id = c.characterClass;
      expect(c.level, 1, reason: id);
      expect(c.classes.single.level, 1);
      expect(c.maxHp, hitPoints[id], reason: id);
      expect(c.currentHp, c.maxHp);
      expect(c.hitDice, [1]);
      expect(c.maxHitDice, 1);
      expect(c.proficientSkills.toSet().length, c.proficientSkills.length);
      expect(c.expertSkills.every(c.proficientSkills.contains), true);
      final rules = CharacterClassRules.resolve(c.classes.single);
      expect(rules.data.id, id);
      expect(c.subclass,
          {'cleric': 'life', 'sorcerer': 'draconic', 'warlock': 'fiend'}[id]);
      expect(c.features.every((f) => f.minLevel <= 1), true, reason: id);
      for (final f in c.features) {
        if (f.resourcePool != null) {
          expect(f.resourcePool!.currentUses, f.resourcePool!.maxUses);
        }
      }
      final book = SpellbookState.read(c.spellbookData);
      expect(book.unassignedKnown(c), isEmpty, reason: id);
      expect(book.unassignedPrepared(c), isEmpty, reason: id);
      expect(book.sources.every((s) => s == 'class:$id'), true);
      expect(c.wildShapeCharges, 0);
      expect(c.channelDivinityCharges, 0);
      final counts = spellCounts[id];
      if (counts == null) {
        expect(c.knownSpells, isEmpty);
        expect(c.spellSlots, isEmpty);
      } else {
        final spells =
            c.knownSpells.map((s) => SpellService.getSpellById(s)!).toList();
        expect(spells.where((s) => s.level == 0).length, counts.$1, reason: id);
        if (counts.$2 != null) {
          expect(spells.where((s) => s.level == 1).length, counts.$2,
              reason: id);
        }
        expect(
            spells.every((s) =>
                s.level <= 1 &&
                s.availableToClasses.any((v) => v.toLowerCase() == id)),
            true);
        expect(c.spellSlots, id == 'warlock' ? [1] : [2]);
        expect(c.maxSpellSlots, c.spellSlots);
        expect(c.preparedSpells.every(c.knownSpells.contains), true);
      }
    }
    final fighter = heroes.singleWhere((c) => c.characterClass == 'fighter');
    expect(fighter.hasFeatureId('fighter-fighting-style-defense'), true);
    expect(fighter.armorClass, 19);
    expect(heroes.singleWhere((c) => c.characterClass == 'sorcerer').armorClass,
        15);
  });

  test('Inventory and resource changes cannot affect another hero or template',
      () {
    final heroes = buildLevelUpCycleCharacters();
    final bard = heroes.singleWhere((c) => c.characterClass == 'bard');
    final rogue = heroes.singleWhere((c) => c.characterClass == 'rogue');
    bard.inventory.singleWhere((i) => i.id == 'leather_armor').isEquipped =
        false;
    expect(
        rogue.inventory.singleWhere((i) => i.id == 'leather_armor').isEquipped,
        true);
    final rage = heroes.first.features.firstWhere((f) => f.id == 'rage');
    rage.resourcePool!.currentUses = 0;
    expect(
        buildLevelUpCycleCharacters()
            .first
            .features
            .firstWhere((f) => f.id == 'rage')
            .resourcePool!
            .currentUses,
        2);
  });

  test('Interrupted seeding resumes without replacing a tester edit', () async {
    final first = buildLevelUpCycleCharacters().first;
    first.name = 'Мой варвар';
    first.level = 2;
    first.classes.single.level = 2;
    first.currentHp = 3;
    await StorageService.saveCharacter(first);
    await StorageService.saveSetting('locale_code', 'en');
    await seedLevelUpCycle();
    expect(StorageService.getAllCharacters().length, 12);
    final restored = StorageService.getCharacter(first.id)!;
    expect(restored.name, 'Мой варвар');
    expect(restored.level, 2);
    expect(restored.currentHp, 3);
    expect(StorageService.getSetting('locale_code'), 'en');
  });

  test('A real storage restart preserves progress and deliberate deletions',
      () async {
    await seedLevelUpCycle();
    final hero = StorageService.getAllCharacters().first;
    hero.level = 4;
    hero.classes.single.level = 4;
    hero.currentHp = 0;
    await StorageService.saveCharacter(hero);
    final deleted = StorageService.getAllCharacters().last.id;
    await StorageService.deleteCharacter(deleted);
    await Hive.close();
    await StorageService.init();
    await seedLevelUpCycle();
    expect(StorageService.getAllCharacters().length, 11);
    expect(StorageService.getCharacter(deleted), isNull);
    expect(StorageService.getCharacter(hero.id)!.level, 4);
    expect(StorageService.getCharacter(hero.id)!.currentHp, 0);
    expect(StorageService.getSetting('locale_code'), 'ru');
  });
}
