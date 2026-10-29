import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/content/content_catalog.dart';
import 'package:qd_and_d/core/content/shelf_choices.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/fc5_imported_name_normalizer.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/import_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';

// Compendiums compiled by FightClub5eXML tag newer rules in names
// («Barbarian [5.5e]»), or, built with -RemoveVersionTag, only cite them as
// the class's source. Both are taken as found.
String _barbarian(String name, String source) => '''
  <class><name>$name</name><hd>12</hd>
    <proficiency>Strength, Constitution, Athletics, Survival</proficiency>
    <numSkills>2</numSkills>
    <trait><name>Barbarian</name><text>Mighty warriors.</text><text>Source:\t$source</text></trait>
    <autolevel level="1"><feature><name>Weapon Mastery</name><text>Mastery properties of two weapons.</text></feature></autolevel>
    <autolevel level="2"><feature><name>Primal Knowledge</name><text>Another skill.</text></feature></autolevel>
    <autolevel level="3"><feature><name>Primal Path</name><text>Choose a path.</text></feature></autolevel>
  </class>''';

const _tagged = '''<?xml version="1.0" encoding="UTF-8"?>
<compendium version="5">
  <class><name>Paladin [5.5e]</name><hd>10</hd><spellAbility>Charisma</spellAbility>
    <trait><name>Paladin</name><text>Oath-bound.</text></trait>
    <autolevel level="1"><feature><name>Lay On Hands</name><text>A pool of healing.</text></feature></autolevel>
  </class>
  <spell><name>Fireball [5.5e]</name><level>3</level><school>EV</school><time>Action</time>
    <range>150 feet</range><components>V, S, M (a ball of bat guano)</components>
    <duration>Instantaneous</duration>
    <classes>Druid [5.5e] (Circle of the Land), Sorcerer [5.5e], Wizard [5.5e]</classes>
    <text>A bright streak flashes, 2024 wording.</text></spell>
  <item><name>Longsword [5.5e]</name><type>M</type><weight>3</weight><dmg1>1d8</dmg1>
    <dmgType>S</dmgType><text>Mastery: Sap.</text></item>
  <feat><name>Origin: Alert [5.5e]</name><text>Initiative proficiency.</text></feat>
</compendium>''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-edition-tag-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await ItemService.loadItems();
    await SpellService.loadSpells();
    await CharacterDataService.loadAllData();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('an edition tag is the rules edition, not part of the name', () {
    expect(FC5ImportedNameNormalizer.splitEdition('Fireball [5.5e]'),
        (name: 'Fireball', edition: '2024'));
    expect(
        FC5ImportedNameNormalizer.splitEdition(
            'Druid [5.5e] (Circle of the Land)'),
        (name: 'Druid (Circle of the Land)', edition: '2024'));
    expect(FC5ImportedNameNormalizer.splitEdition('Shield [2024]').edition,
        '2024');
    expect(FC5ImportedNameNormalizer.splitEdition('Shield [2014]'),
        (name: 'Shield', edition: '2014'));
    // Other brackets are the name's own.
    expect(FC5ImportedNameNormalizer.splitEdition('Arrows [20]'),
        (name: 'Arrows [20]', edition: null));
  });

  test('tagged entries show plain names and keep their IDs', () async {
    final parsed = await FC5Parser.parseCompendium(
        '<compendium version="5">${_barbarian('Barbarian [5.5e]', 'Player’s Handbook (2024) p. 51')}'
        '${_tagged.split('<compendium version="5">').last}',
        sourceId: 'srd52');
    final barbarian = parsed.classes.firstWhere((c) => c.id.contains('barbarian'));
    expect(barbarian.name, {'en': 'Barbarian', 'ru': 'Варвар'});
    expect(barbarian.rulesEdition, '2024');
    expect(barbarian.rulesPlayable, isFalse);
    // The ID is built from the tagged name, as it always was.
    expect(barbarian.id, endsWith('barbarian_5_5e'));
    final paladin = parsed.classes.firstWhere((c) => c.id.contains('paladin'));
    expect(paladin.name['en'], 'Paladin');
    expect(paladin.spellcasting!.type, 'half');
    final fireball = parsed.spells.single;
    expect((fireball.nameEn, fireball.id.endsWith('fireball_5_5e')),
        ('Fireball', true));
    expect(fireball.availableToClasses,
        containsAll(['sorcerer', 'wizard', 'druid (Circle of the Land)']));
    expect(parsed.items.single.nameEn, 'Longsword');
    expect(parsed.feats.single.nameEn, 'Origin: Alert');
  });

  test('a class citing newer rules is 2024; one citing SRD 5.1 is not',
      () async {
    Future<String> edition(String source) async => (await FC5Parser.parseCompendium(
            '<compendium version="5">${_barbarian('Barbarian', source)}</compendium>',
            sourceId: 'x'))
        .classes
        .single
        .rulesEdition;
    expect(await edition('System Reference Document v5.2.1'), '2024');
    expect(await edition('Player’s Handbook (2024) p. 51'), '2024');
    expect(await edition('System Reference Document 5.1'), 'unknown');
    expect(await edition('Player’s Handbook p. 46'), 'unknown');
  });

  test('2024 classes stay versions beside the built-in ones, never merged',
      () async {
    final before = CharacterDataService.getClassById('barbarian')!;
    final featuresBefore =
        before.features.values.fold<int>(0, (n, row) => n + row.length);
    // As found: one book tagged, one untagged that only cites its source.
    await ImportService.importCompendiumXmlContentDetailed(_tagged,
        sourceName: 'SRD 5.2 tagged');
    await ImportService.importCompendiumXmlContentDetailed(
        '<compendium version="5">${_barbarian('Barbarian', 'System Reference Document v5.2.1')}</compendium>',
        sourceName: 'SRD 5.2 untagged');
    final after = CharacterDataService.getClassById('barbarian')!;
    expect(after.features.values.fold<int>(0, (n, row) => n + row.length),
        featuresBefore);
    expect(after.features.values.expand((r) => r).map((f) => f.nameEn),
        isNot(contains('Weapon Mastery')));

    final choices = shelfChoices(
        CharacterDataService.getAllClasses(), ContentRecords.characterClass,
        usable: (c) => c.rulesPlayable);
    final barbarian =
        choices.singleWhere((c) => c.holds('barbarian', null));
    expect(barbarian.family.records, hasLength(2));
    expect(barbarian.hasVersions, isTrue);
    expect(barbarian.lead.rulesPlayable, isTrue);
    // No «[5.5e]» card of its own.
    expect(
        choices.map((c) => c.lead.getName('en')).where((n) => n.contains('[')),
        isEmpty);
    final paladin = choices.singleWhere((c) => c.holds('paladin', null));
    expect(paladin.lead.id, 'paladin');
  });
}
