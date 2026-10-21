import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/features/character_sheet/widgets/expandable_character_card.dart';
import 'package:qd_and_d/features/character_level_up/level_up_screen.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/spell_slots_table.dart';
import 'package:qd_and_d/core/progression/character_class_rules.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/features/expressive_cycle/cycle_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-expressive-cycle-');
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

  test(
      'Exactly twelve independent level-twenty sheets have real late rules and full reserves',
      () {
    final roster = buildExpressiveCycleCharacters();
    expect(roster.length, 12);
    stdout.writeln('CYCLE_ROSTER ${jsonEncode([
          for (final c in roster)
            {
              'class': c.characterClass,
              'name': c.name,
              'subclass': c.subclass,
              'level': c.level,
              'hp': c.maxHp,
              'ac': c.armorClass,
              'spells': c.knownSpells.length,
              'features': c.features.length,
              'slots': c.maxSpellSlots,
              'scores': c.abilityScores.toJson(),
            }
        ])}');
    expect(roster.map((c) => c.characterClass).toSet().length, 12);
    expect(roster.map((c) => c.id).toSet().length, 12);
    for (final c in roster) {
      expect(c.level, 20, reason: c.characterClass);
      expect(c.classes.single.level, 20);
      expect(c.subclass, isNotEmpty);
      final rules = CharacterClassRules.resolve(c.classes.single);
      expect(rules.data.subclasses.any((s) => s.id == c.subclass), isTrue);
      expect(c.currentHp, c.maxHp);
      expect(c.maxHp, greaterThan(100));
      expect(c.hitDice, [20]);
      expect(c.features.map((f) => f.id).toSet().length, c.features.length);
      expect(c.knownSpells.toSet().length, c.knownSpells.length);
      expect(c.preparedSpells.every(c.knownSpells.contains), isTrue);
      expect(c.knownSpells.every((s) => SpellService.getSpellById(s) != null),
          isTrue);
      expect(
          c.maxSpellSlots,
          SpellSlotsTable.getSlots(
              20, rules.data.spellcasting?.type ?? 'none'));
      expect(c.spellSlots, c.maxSpellSlots);
      for (final f in c.features) {
        if (f.resourcePool != null) {
          expect(f.resourcePool!.currentUses, f.resourcePool!.maxUses,
              reason: f.id);
        }
      }
      expect(c.expertSkills.toSet().length, c.expertSkills.length);
      expect(c.expertSkills.every(c.proficientSkills.contains), isTrue);
      expect(c.journalNotes, isNotEmpty);
      expect(c.quests.single.objectives.length, 3);
      expect(c.journalData['entities'], hasLength(3));
    }
    Character hero(String id) =>
        roster.singleWhere((c) => c.characterClass == id);
    expect(hero('barbarian').abilityScores.strength, 24);
    expect(hero('barbarian').abilityScores.constitution, 24);
    expect(hero('fighter').hasFeatureId('extra-attack-3'), isTrue);
    expect(
        hero('fighter')
            .features
            .singleWhere((f) => f.id == 'action-surge-2-uses')
            .resourcePool!
            .maxUses,
        2);
    expect(
        hero('bard')
            .features
            .singleWhere((f) => f.id == 'bardic-inspiration-d12')
            .resourcePool!
            .maxUses,
        5);
    expect(
        hero('sorcerer')
            .features
            .where((f) => f.id.startsWith('metamagic-') && f.isOptional)
            .length,
        4);
    expect(
        hero('warlock')
            .features
            .where((f) => f.id.startsWith('eldritch-invocation-'))
            .length,
        8);
    expect(
        hero('warlock')
            .features
            .where((f) => f.id.startsWith('mystic-arcanum-'))
            .length,
        4);
    expect(
        hero('warlock')
            .knownSpells
            .where((s) => (SpellService.getSpellById(s)?.level ?? 0) > 5)
            .length,
        4);
    expect(hero('warlock').maxSpellSlots, [0, 0, 0, 0, 4]);
    expect(
        hero('wizard')
            .knownSpells
            .where((s) => SpellService.getSpellById(s)!.level > 0)
            .length,
        44);
    expect(
        hero('wizard')
            .spellMasterySpells
            .map((s) => SpellService.getSpellById(s)!.level),
        [1, 2]);
    expect(
        hero('wizard')
            .signatureSpells
            .map((s) => SpellService.getSpellById(s)!.level),
        [3, 3]);
    for (final parent in [
      'hunters-prey',
      'defensive-tactics',
      'multiattack',
      'superior-hunters-defense'
    ]) {
      final options = CharacterClassRules.resolve(hero('ranger').classes.single)
          .feature(parent)!
          .options!;
      expect(
          hero('ranger').features.where((f) => options.contains(f.id)).length,
          1);
    }
    expect(
        hero('druid')
            .features
            .where((f) => f.id.startsWith('circle-of-the-land-'))
            .length,
        1);
  });

  testWidgets('A level-twenty badge cannot open a fictitious level twenty-one',
      (tester) async {
    final hero = buildExpressiveCycleCharacters().first;
    late AppLocalizations l;
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l = AppLocalizations.of(context)!;
          return Scaffold(
              body: SingleChildScrollView(
                  child: ExpandableCharacterCard(
                      character: hero,
                      isExpanded: false,
                      onDicePressed: () {})));
        })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${l.levelShort} 20'));
    await tester.pumpAndSettle();
    expect(find.byType(LevelUpScreen), findsNothing);
    expect(hero.level, 20);
    expect(tester.takeException(), isNull);
  });

  test(
      'One hero and a fresh fixture cannot share equipment or resource objects',
      () {
    final first = buildExpressiveCycleCharacters(),
        second = buildExpressiveCycleCharacters();
    first.first.features
        .firstWhere((f) => f.resourcePool != null)
        .resourcePool!
        .currentUses = 0;
    expect(
        second.first.features
            .firstWhere((f) => f.resourcePool != null)
            .resourcePool!
            .currentUses,
        greaterThan(0));
    first.first.inventory.first.isEquipped = false;
    expect(second.first.inventory.first.isEquipped, isTrue);
    first.first.journalNotes.first.content = 'Edited';
    expect(second.first.journalNotes.first.content, isNot('Edited'));
  });

  test(
      'Interrupted seeding, restart and deliberate deletion never reset tester changes',
      () async {
    final first = buildExpressiveCycleCharacters().first..currentHp = 7;
    await StorageService.saveCharacter(first);
    await seedExpressiveCycle();
    expect(StorageService.getAllCharacters().length, 12);
    expect(StorageService.getCharacter(first.id)!.currentHp, 7);
    final deleted = StorageService.getAllCharacters().last.id;
    await StorageService.deleteCharacter(deleted);
    await Hive.close();
    await StorageService.init();
    await seedExpressiveCycle();
    expect(StorageService.getAllCharacters().length, 11);
    expect(StorageService.getCharacter(first.id)!.currentHp, 7);
    expect(StorageService.getCharacter(deleted), isNull);
    expect(StorageService.getSetting('locale_code'), 'ru');
  });
}
