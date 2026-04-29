import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qd_and_d/core/models/background_data.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/models/compendium_source.dart';
import 'package:qd_and_d/core/models/item.dart';
import 'package:qd_and_d/core/models/race_data.dart';
import 'package:qd_and_d/core/models/spell.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/fc5_content_identity_service.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/import_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('fc5_identity_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => tempDir.path,
    );

    await StorageService.init();
    await FeatureService.init();
    await SpellService.loadSpells();
    await ItemService.loadItems();
    await CharacterDataService.loadAllData();
  });

  setUp(() async {
    await _clearStorageBoxes();
    await ImportService.reloadImportedContentServices();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  test('dedupes built-in and same-batch FC5 content semantically', () async {
    final parsed = await FC5Parser.parseCompendium(
      _duplicateCompendiumXml,
      sourceId: 'identity_test',
    );
    final deduped = FC5CompendiumDeduplicationService.dedupe(parsed);

    expect(deduped.parseResult.items, isEmpty);
    expect(deduped.parseResult.spells, isEmpty);
    expect(deduped.parseResult.races, isEmpty);
    expect(deduped.parseResult.backgrounds, isEmpty);
    expect(deduped.parseResult.classes, isEmpty);
    expect(deduped.parseResult.feats, hasLength(1));

    expect(deduped.stats.items, 1);
    expect(deduped.stats.spells, 1);
    expect(deduped.stats.races, 1);
    expect(deduped.stats.backgrounds, 1);
    expect(deduped.stats.feats, 1);
    expect(deduped.stats.subclasses, 1);
    expect(deduped.stats.classes, 1);
    expect(
      deduped.parseResult.diagnostics.entries.map((entry) => entry.code),
      contains('duplicates_skipped'),
    );
  });

  test('aggregates subclass-complete class nodes into base class overlays',
      () async {
    final parsed = await FC5Parser.parseCompendium(
      _subclassClassXml,
      sourceId: 'class_overlay_test',
    );

    expect(parsed.classes, hasLength(1));
    final paladin = parsed.classes.single;
    expect(paladin.name['en'], 'Paladin');
    expect(paladin.name['ru'], 'Паладин');
    expect(paladin.subclasses, hasLength(2));
    expect(paladin.features[1], hasLength(1));
    expect(paladin.features[1]!.single.associatedSubclass, isNull);
    expect(paladin.features[3], hasLength(2));
    expect(
      paladin.features[3]!.map((feature) => feature.associatedSubclass),
      everyElement(isNotNull),
    );
  });

  final fixtureZip = File('/home/alexgrig/Downloads/Компендиум.zip');
  test(
    'aggregates real Classes.xml from supplied compendium ZIP',
    () async {
      final archive = ZipDecoder().decodeBytes(await fixtureZip.readAsBytes());
      final classesEntry = archive.files.firstWhere(
        (entry) => entry.name.endsWith('/Classes.xml'),
      );
      final xml = utf8.decode(classesEntry.readBytes() ?? const []);
      final parsed = await FC5Parser.parseCompendium(
        xml,
        sourceId: 'real_classes_fixture',
      );

      expect(parsed.classes.length, inInclusiveRange(12, 13));
      expect(
        parsed.classes.map((classData) => classData.name['en']),
        containsAll(['Paladin', 'Fighter', 'Cleric', 'Druid']),
      );
      expect(
        parsed.classes.map((classData) => classData.name.values),
        everyElement(everyElement(isNot(contains(':')))),
      );

      final paladin = parsed.classes.firstWhere(
        (classData) => classData.name['en'] == 'Paladin',
      );
      expect(
        paladin.subclasses.any(
          (subclass) =>
              subclass.name.values.any((name) => name.contains('покор')),
        ),
        isTrue,
      );
    },
    skip: fixtureZip.existsSync()
        ? false
        : 'Local supplied compendium ZIP is not available.',
  );
}

Future<void> _clearStorageBoxes() async {
  await Hive.box<Character>('characters').clear();
  await Hive.box<Item>('items_library').clear();
  await Hive.box<Spell>('spells_library').clear();
  await Hive.box<CompendiumSource>('compendium_sources').clear();
  await Hive.box('settings').clear();
  await Hive.box<RaceData>('races_library').clear();
  await Hive.box<ClassData>('classes_library').clear();
  await Hive.box<BackgroundData>('backgrounds_library').clear();
  await Hive.box<CharacterFeature>('feats_library').clear();
}

const _duplicateCompendiumXml = '''
<compendium>
  <item>
    <name>Длинный меч</name>
    <type>M</type>
    <dmg1>1d8</dmg1>
    <dmg2>1d10</dmg2>
    <dmgType>S</dmgType>
    <text>Duplicate SRD weapon.</text>
  </item>
  <spell>
    <name>Брызги кислоты</name>
    <level>0</level>
    <school>C</school>
    <time>1 действие</time>
    <range>60 футов</range>
    <components>V,S</components>
    <duration>Мгновенно</duration>
    <classes>Чародей, Волшебник</classes>
    <text>Duplicate SRD spell.</text>
  </spell>
  <race>
    <name>Человек</name>
    <size>M</size>
    <speed>30</speed>
    <ability>str +1</ability>
    <trait><name>Гибкость</name><text>Duplicate SRD race.</text></trait>
  </race>
  <background>
    <name>Прислужник</name>
    <proficiency>Insight, Religion</proficiency>
    <trait><name>Приют верующих</name><text>Duplicate SRD background.</text></trait>
  </background>
  <class>
    <name>Паладин: Клятва преданности</name>
    <hd>10</hd>
    <spellAbility>Charisma</spellAbility>
    <autolevel level="1">
      <feature><name>Божественное чувство</name><text>Duplicate built-in feature.</text></feature>
    </autolevel>
    <autolevel level="3">
      <feature><name>Клятва преданности: Священное оружие</name><text>Duplicate built-in subclass.</text></feature>
    </autolevel>
  </class>
  <feat><name>Crimson Adept</name><text>First custom feat.</text></feat>
  <feat><name>Crimson Adept</name><text>Duplicate custom feat.</text></feat>
</compendium>
''';

const _subclassClassXml = '''
<compendium>
  <class>
    <name>Paladin: Oath of Ash</name>
    <hd>10</hd>
    <spellAbility>Charisma</spellAbility>
    <autolevel level="1">
      <feature><name>Shared Training</name><text>Base class feature.</text></feature>
    </autolevel>
    <autolevel level="3">
      <feature><name>Oath of Ash: Ember Rite</name><text>Subclass feature.</text></feature>
    </autolevel>
  </class>
  <class>
    <name>Paladin: Oath of Dawn</name>
    <hd>10</hd>
    <spellAbility>Charisma</spellAbility>
    <autolevel level="1">
      <feature><name>Shared Training</name><text>Base class feature.</text></feature>
    </autolevel>
    <autolevel level="3">
      <feature><name>Oath of Dawn: First Light</name><text>Subclass feature.</text></feature>
    </autolevel>
  </class>
</compendium>
''';
