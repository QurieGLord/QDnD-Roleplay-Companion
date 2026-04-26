import 'dart:io';

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
import 'package:qd_and_d/core/services/fc5_compendium_identity_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/import_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('fc5_duplicate_test_');
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

  test('skips exact duplicate FC5 compendium source and cleans fingerprint',
      () async {
    final file = File('${tempDir.path}/crimson_compendium.xml')
      ..writeAsStringSync(_compendiumXml);
    final fingerprint = FC5CompendiumIdentityService.fingerprintXml(
      _compendiumXml,
    );

    final first = await ImportService.importCompendiumFileDetailed(file);
    expect(StorageService.getAllSources(), hasLength(1));
    expect(
        StorageService.getSourceIdForFingerprint(fingerprint), first.sourceId);
    expect(StorageService.getAllItems().where(_from(first.sourceId)),
        hasLength(1));
    expect(StorageService.getAllSpells().where(_from(first.sourceId)),
        hasLength(1));
    expect(StorageService.getAllRaces().where(_from(first.sourceId)),
        hasLength(1));
    expect(StorageService.getAllClasses().where(_from(first.sourceId)),
        hasLength(1));
    expect(StorageService.getAllBackgrounds().where(_from(first.sourceId)),
        hasLength(1));
    expect(StorageService.getAllFeats().where(_from(first.sourceId)),
        hasLength(1));

    await expectLater(
      ImportService.importCompendiumFileDetailed(file),
      throwsA(
        isA<ImportServiceException>()
            .having(
              (error) => error.diagnostics.entries.map((entry) => entry.code),
              'diagnostic codes',
              contains('duplicate_source'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('already been imported'),
            ),
      ),
    );

    expect(StorageService.getAllSources(), hasLength(1));
    expect(StorageService.getAllItems().where(_from(first.sourceId)),
        hasLength(1));
    expect(StorageService.getAllSpells().where(_from(first.sourceId)),
        hasLength(1));
    expect(StorageService.getAllRaces().where(_from(first.sourceId)),
        hasLength(1));
    expect(StorageService.getAllClasses().where(_from(first.sourceId)),
        hasLength(1));
    expect(StorageService.getAllBackgrounds().where(_from(first.sourceId)),
        hasLength(1));
    expect(StorageService.getAllFeats().where(_from(first.sourceId)),
        hasLength(1));

    await StorageService.deleteSource(first.sourceId);
    await ImportService.reloadImportedContentServices();
    expect(StorageService.getAllSources(), isEmpty);
    expect(StorageService.getSourceIdForFingerprint(fingerprint), isNull);
    expect(StorageService.getAllItems().where(_from(first.sourceId)), isEmpty);
    expect(StorageService.getAllSpells().where(_from(first.sourceId)), isEmpty);
    expect(StorageService.getAllRaces().where(_from(first.sourceId)), isEmpty);
    expect(
        StorageService.getAllClasses().where(_from(first.sourceId)), isEmpty);
    expect(StorageService.getAllBackgrounds().where(_from(first.sourceId)),
        isEmpty);
    expect(StorageService.getAllFeats().where(_from(first.sourceId)), isEmpty);

    final second = await ImportService.importCompendiumFileDetailed(file);
    expect(second.sourceId, isNot(first.sourceId));
    expect(StorageService.getAllSources(), hasLength(1));
  });
}

bool Function(dynamic entity) _from(String sourceId) {
  return (entity) => entity.sourceId == sourceId;
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

const _compendiumXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<compendium>
  <item>
    <name>Crimson Lantern</name>
    <type>G</type>
    <weight>1</weight>
    <value>12</value>
    <text>A synthetic lantern for duplicate import tests.</text>
  </item>
  <spell>
    <name>Astral Spark</name>
    <level>1</level>
    <school>Evocation</school>
    <time>1 action</time>
    <range>60 feet</range>
    <duration>Instantaneous</duration>
    <components>V,S</components>
    <classes>Wizard</classes>
    <text>A synthetic spark.</text>
  </spell>
  <race>
    <name>Starborn</name>
    <size>M</size>
    <speed>30</speed>
    <ability>cha +2</ability>
    <trait>
      <name>Starlit Step</name>
      <text>A synthetic open trait.</text>
    </trait>
  </race>
  <class>
    <name>Crimson Knight</name>
    <hd>10</hd>
    <spellAbility>cha</spellAbility>
    <numSkills>2</numSkills>
    <autolevel level="1">
      <feature>
        <name>Crimson Guard</name>
        <text>A synthetic class feature.</text>
      </feature>
    </autolevel>
    <autolevel level="3" subclass="Ruby Oath">
      <feature>
        <name>Ruby Resolve</name>
        <text>A synthetic subclass feature.</text>
      </feature>
    </autolevel>
  </class>
  <background>
    <name>Sky Archivist</name>
    <proficiency>Arcana, History</proficiency>
    <trait>
      <name>Library Key</name>
      <text>A synthetic background feature.</text>
    </trait>
  </background>
  <feat>
    <name>Crimson Adept</name>
    <text>A synthetic feat.</text>
  </feat>
</compendium>
''';
