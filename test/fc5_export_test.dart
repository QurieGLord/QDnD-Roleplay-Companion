import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/background_data.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/models/compendium_source.dart';
import 'package:qd_and_d/core/models/item.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/core/models/race_data.dart';
import 'package:qd_and_d/core/models/spell.dart';
import 'package:qd_and_d/core/services/fc5_export_service.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/import_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('fc5_export_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => tempDir.path,
    );

    await StorageService.init();
    await FeatureService.init();
  });

  setUp(() async {
    await _clearStorageBoxes();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  group('FC5ExportService', () {
    test('exports parser-compatible XML and roundtrips key fields', () async {
      final character = Character(
        id: 'fc5-export-rich',
        name: 'Astral Rowan',
        race: 'Elf',
        characterClass: 'Cleric',
        subclass: 'Life Domain',
        level: 3,
        maxHp: 27,
        currentHp: 19,
        temporaryHp: 4,
        abilityScores: AbilityScores(
          strength: 10,
          dexterity: 14,
          constitution: 13,
          intelligence: 12,
          wisdom: 16,
          charisma: 8,
        ),
        background: 'Acolyte',
        spellSlots: const [2, 1, 0, 0, 0, 0, 0, 0, 0],
        maxSpellSlots: const [4, 2, 0, 0, 0, 0, 0, 0, 0],
        proficientSkills: const ['insight', 'religion'],
        expertSkills: const ['insight'],
        savingThrowProficiencies: const ['wisdom', 'charisma'],
        knownSpells: const ['astral_spark', 'cure_wounds'],
        preparedSpells: const ['astral_spark'],
        maxPreparedSpells: 1,
        inventory: [
          Item(
            id: 'crimson_mace',
            nameEn: 'Crimson Mace',
            nameRu: 'Crimson Mace',
            descriptionEn: 'Synthetic test weapon.',
            descriptionRu: 'Synthetic test weapon.',
            type: ItemType.weapon,
            rarity: ItemRarity.common,
            quantity: 1,
            weight: 4,
            valueInCopper: 500,
            isEquipped: true,
            isAttuned: true,
            weaponProperties: WeaponProperties(
              damageDice: '1d6',
              damageType: DamageType.bludgeoning,
            ),
          ),
        ],
        features: [
          CharacterFeature(
            id: 'channel-divinity',
            nameEn: 'Channel Divinity',
            nameRu: 'Channel Divinity',
            descriptionEn: 'Synthetic channel option state.',
            descriptionRu: 'Synthetic channel option state.',
            type: FeatureType.resourcePool,
            minLevel: 2,
            associatedClass: 'Cleric',
            resourcePool: ResourcePool(
              currentUses: 1,
              maxUses: 1,
              recoveryType: RecoveryType.shortRest,
            ),
          ),
        ],
        journalNotes: [
          JournalNote(
            id: 'note-astral',
            title: 'Quest: Astral Bell',
            content: 'Find the bell under the violet bridge.',
          ),
        ],
        classes: [
          CharacterClass(
            id: 'cleric',
            name: 'Cleric',
            level: 3,
            subclass: 'Life Domain',
            isPrimary: true,
          ),
        ],
        copperPieces: 3,
        silverPieces: 4,
        goldPieces: 25,
        platinumPieces: 1,
      );

      final result = await FC5ExportService.exportCharacter(character);
      XmlDocument.parse(result.xml);

      final parsed = FC5Parser.parseCharacter(result.xml);

      expect(parsed.name, character.name);
      expect(parsed.race, 'Elf');
      expect(parsed.background, 'Acolyte');
      expect(parsed.characterClass, 'Cleric');
      expect(parsed.subclass, 'Life Domain');
      expect(parsed.level, 3);
      expect(parsed.maxHp, 27);
      expect(parsed.currentHp, 19);
      expect(parsed.temporaryHp, 4);
      expect(parsed.abilityScores.wisdom, 16);
      expect(parsed.maxSpellSlots[0], 4);
      expect(parsed.spellSlots[0], 2);
      expect(
          parsed.savingThrowProficiencies, containsAll(['wisdom', 'charisma']));
      expect(parsed.proficientSkills, containsAll(['insight', 'religion']));
      expect(parsed.expertSkills, contains('insight'));
      expect(parsed.knownSpells, containsAll(['astral_spark', 'cure_wounds']));
      expect(parsed.preparedSpells, contains('astral_spark'));
      expect(parsed.inventory.single.nameEn, 'Crimson Mace');
      expect(parsed.inventory.single.isEquipped, isTrue);
      expect(parsed.inventory.single.isAttuned, isTrue);
      expect(parsed.goldPieces, 25);
      expect(parsed.journalNotes.single.title, 'Quest: Astral Bell');
      expect(parsed.features.map((feature) => feature.nameEn),
          contains('Channel Divinity'));
    });

    test('roundtrips exported avatar and note imageData through FC5 import',
        () async {
      final avatarBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
        'AAAADUlEQVR42mP8z8BQDwAFgwJ/luzJ6wAAAABJRU5ErkJggg==',
      );
      final noteBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
        'AAAADUlEQVR42mP8z8BQDwAFgwJ/luzJ6wAAAABJRU5ErkJggg==',
      );
      final avatarFile = File('${tempDir.path}/avatar.png')
        ..writeAsBytesSync(avatarBytes);
      final noteFile = File('${tempDir.path}/note.jpg')
        ..writeAsBytesSync(noteBytes);

      final character = Character(
        id: 'fc5-export-media',
        name: 'Media Rowan',
        avatarPath: avatarFile.path,
        race: 'Human',
        characterClass: 'Fighter',
        level: 2,
        maxHp: 18,
        currentHp: 17,
        abilityScores: AbilityScores(
          strength: 15,
          dexterity: 12,
          constitution: 14,
          intelligence: 10,
          wisdom: 10,
          charisma: 8,
        ),
        spellSlots: const [0, 0, 0, 0, 0, 0, 0, 0, 0],
        maxSpellSlots: const [0, 0, 0, 0, 0, 0, 0, 0, 0],
        journalNotes: [
          JournalNote(
            id: 'media-note',
            title: 'Sketch',
            content: 'A field sketch.',
            imagePath: noteFile.path,
          ),
        ],
        classes: [
          CharacterClass(
            id: 'fighter',
            name: 'Fighter',
            level: 2,
            isPrimary: true,
          ),
        ],
      );

      final exportResult = await FC5ExportService.exportCharacter(character);
      final xmlFile = File('${tempDir.path}/media_roundtrip.xml')
        ..writeAsStringSync(exportResult.xml);

      final importResult = await ImportService.importCharactersFromFC5File(
        xmlFile,
      );
      final imported = importResult.characters.single;

      expect(imported.avatarPath, isNotNull);
      expect(File(imported.avatarPath!).existsSync(), isTrue);
      expect(File(imported.avatarPath!).readAsBytesSync(), avatarBytes);

      final importedNote = imported.journalNotes.single;
      expect(importedNote.imagePath, isNotNull);
      expect(File(importedNote.imagePath!).existsSync(), isTrue);
      expect(File(importedNote.imagePath!).readAsBytesSync(), noteBytes);
      expect(
        importResult.diagnostics.entries.map((entry) => entry.code),
        isNot(contains('skipped_image_data')),
      );
      expect(
        importResult.diagnostics.entries.map((entry) => entry.code),
        isNot(contains('note_image_skipped')),
      );
    });

    test('invalid embedded imageData warns without failing import', () async {
      final xmlFile = File('${tempDir.path}/invalid_media.xml')
        ..writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<pc version="5">
  <character>
    <name>Broken Media</name>
    <imageData encoding="base64" source="avatar">not-base64</imageData>
    <abilities>10,10,10,10,10,10</abilities>
    <hpMax>8</hpMax>
    <hpCurrent>8</hpCurrent>
    <race><name>Human</name></race>
    <class>
      <name>Fighter</name>
      <level>1</level>
    </class>
    <note>
      <name>Broken note</name>
      <text>Still imports.</text>
      <imageData encoding="base64" source="note">%%%</imageData>
    </note>
  </character>
</pc>
''');

      final result = await ImportService.importCharactersFromFC5File(xmlFile);

      expect(result.characters.single.name, 'Broken Media');
      expect(result.characters.single.avatarPath, isNull);
      expect(result.characters.single.journalNotes.single.imagePath, isNull);
      expect(
        result.diagnostics.entries.map((entry) => entry.code),
        contains('image_data_invalid'),
      );
      expect(
        result.diagnostics.entries.map((entry) => entry.code),
        isNot(contains('skipped_image_data')),
      );
    });

    test(
        'imports nested FC5 avatar and note imageData without skipped warnings',
        () async {
      final imageData = base64Encode(_tinyPngBytes());
      final xmlFile = File('${tempDir.path}/nested_media.xml')
        ..writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<pc version="5">
  <character>
    <name>Nested Media</name>
    <portrait>
      <imageData encoding="base64">$imageData</imageData>
    </portrait>
    <abilities>10,10,10,10,10,10</abilities>
    <hpMax>8</hpMax>
    <hpCurrent>8</hpCurrent>
    <race><name>Human</name></race>
    <class>
      <name>Fighter</name>
      <level>1</level>
    </class>
    <note>
      <name>Leosin Erlanthar</name>
      <text>Captured by cultists.</text>
      <image>
        <imageData encoding="base64">$imageData</imageData>
      </image>
    </note>
  </character>
</pc>
''');

      final result = await ImportService.importCharactersFromFC5File(xmlFile);
      final imported = result.characters.single;

      expect(File(imported.avatarPath!).readAsBytesSync(), _tinyPngBytes());
      expect(
        File(imported.journalNotes.single.imagePath!).readAsBytesSync(),
        _tinyPngBytes(),
      );
      expect(
        result.diagnostics.entries.map((entry) => entry.code),
        isNot(contains('unsupported_image_data_location')),
      );
    });

    test('resolves FC5 uid imageData references from document definitions',
        () async {
      final imageData = base64Encode(_tinyPngBytes());
      final xmlFile = File('${tempDir.path}/uid_media.xml')
        ..writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<pc version="5">
  <character>
    <name>UID Media</name>
    <imageData><uid>avatar-1</uid></imageData>
    <abilities>10,10,10,10,10,10</abilities>
    <hpMax>8</hpMax>
    <hpCurrent>8</hpCurrent>
    <race><name>Human</name></race>
    <class>
      <name>Fighter</name>
      <level>1</level>
    </class>
    <item>
      <imageData><uid>item-1</uid></imageData>
      <name>Painted Locket</name>
      <type>G</type>
      <weight>1</weight>
      <value>1</value>
      <text>A locket with a tiny portrait.</text>
    </item>
    <note>
      <name>Leosin Erlanthar</name>
      <text>Captured by cultists.</text>
      <imageData><uid>note-1</uid></imageData>
    </note>
  </character>
  <imageData><uid>avatar-1</uid><encoded>$imageData</encoded></imageData>
  <imageData><uid>item-1</uid><encoded>$imageData</encoded></imageData>
  <imageData><uid>note-1</uid><encoded>$imageData</encoded></imageData>
</pc>
''');

      final result = await ImportService.importCharactersFromFC5File(xmlFile);
      final imported = result.characters.single;
      final codes = result.diagnostics.entries.map((entry) => entry.code);

      expect(File(imported.avatarPath!).readAsBytesSync(), _tinyPngBytes());
      expect(
        File(imported.inventory.single.customImagePath!).readAsBytesSync(),
        _tinyPngBytes(),
      );
      expect(
        File(imported.journalNotes.single.imagePath!).readAsBytesSync(),
        _tinyPngBytes(),
      );
      expect(codes, isNot(contains('unsupported_image_data_location')));
      expect(codes, isNot(contains('image_data_unsupported_format')));
      expect(codes, isNot(contains('image_data_invalid')));
    });
  });
}

List<int> _tinyPngBytes() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR42mP8z8BQDwAFgwJ/luzJ6wAAAABJRU5ErkJggg==',
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
