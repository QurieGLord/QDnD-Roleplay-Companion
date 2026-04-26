import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/models/compendium_source.dart';
import 'package:qd_and_d/core/models/condition.dart';
import 'package:qd_and_d/core/models/death_saves.dart';
import 'package:qd_and_d/core/models/item.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/core/models/quest.dart';
import 'package:qd_and_d/core/models/race_data.dart';
import 'package:qd_and_d/core/models/spell.dart';
import 'package:qd_and_d/core/models/background_data.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_export_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_file_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_import_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_schema.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('qdnd_bundle_test_');
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
    await SpellService.reload();
    await ItemService.reload();
    await CharacterDataService.reload();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  group('QDND bundle export/import', () {
    test('roundtrips a rich character without losing supported state',
        () async {
      final character = _richCharacter();
      await StorageService.saveSpells([_astralSpark()]);
      await SpellService.reload();

      final bundleFile = File('${tempDir.path}/rich.qdnd');
      final exportResult = await QdndBundleExportService.exportCharacterToFile(
        character,
        bundleFile,
        options: const QdndBundleExportOptions(
          includeUserCreatedContent: true,
        ),
      );

      expect(exportResult.manifest['schemaVersion'], 1);
      expect(exportResult.manifest['files'], contains('journal/notes.json'));
      expect(exportResult.manifest['files'], contains('journal/quests.json'));

      await _clearStorageBoxes();
      await SpellService.reload();
      await ItemService.reload();
      await CharacterDataService.reload();

      final importResult = await QdndBundleImportService.importFile(bundleFile);
      final imported = importResult.character;

      expect(imported.id, isNot(character.id));
      expect(imported.name, character.name);
      expect(imported.level, 4);
      expect(imported.classes.map((c) => c.toJson()),
          character.classes.map((c) => c.toJson()));
      expect(imported.currentHp, 27);
      expect(imported.temporaryHp, 5);
      expect(imported.exhaustionLevel, 1);
      expect(imported.activeConditions, contains(ConditionType.frightened));
      expect(imported.deathSaves.successes, 1);
      expect(imported.proficientSkills, containsAll(['arcana', 'insight']));
      expect(imported.expertSkills, ['arcana']);
      expect(imported.savingThrowProficiencies, contains('wisdom'));
      expect(imported.goldPieces, 42);
      expect(imported.inventory.single.nameEn, 'Crimson Blade');
      expect(imported.inventory.single.isEquipped, isTrue);
      expect(imported.inventory.single.isAttuned, isTrue);
      expect(imported.knownSpells, hasLength(1));
      expect(imported.preparedSpells, imported.knownSpells);
      expect(imported.concentratingOn, imported.knownSpells.single);
      expect(
          imported.features
              .singleWhere((f) => f.id == 'rage')
              .resourcePool!
              .currentUses,
          1);
      expect(imported.journalNotes.single.title, 'Moon Gate');
      expect(imported.quests.single.objectives.single.isCompleted, isTrue);
      expect(importResult.missingDependencyCount, 0);
    });

    test('remaps embedded IDs and preserves relationships', () async {
      final character = _richCharacter();
      await StorageService.saveSpells([_astralSpark()]);
      await SpellService.reload();

      final bundleFile = File('${tempDir.path}/remap.qdnd');
      await QdndBundleExportService.exportCharacterToFile(
        character,
        bundleFile,
        options: const QdndBundleExportOptions(
          includeUserCreatedContent: true,
        ),
      );

      await _clearStorageBoxes();
      await SpellService.reload();

      final result = await QdndBundleImportService.importFile(bundleFile);
      final imported = result.character;
      final remappedSpellId = imported.knownSpells.single;

      expect(remappedSpellId, isNot('astral_spark'));
      expect(imported.preparedSpells.single, remappedSpellId);
      expect(imported.concentratingOn, remappedSpellId);
      expect(StorageService.getAllSpells().map((s) => s.id),
          contains(remappedSpellId));
    });

    test('does not embed reference-only protected library content by default',
        () async {
      final character = _protectedReferenceCharacter();
      await _saveProtectedLibrary();
      await SpellService.reload();
      await ItemService.reload();

      final exportResult =
          await QdndBundleExportService.exportCharacter(character);
      final bundleText = utf8.decode(exportResult.bytes, allowMalformed: true);
      final manifest = exportResult.manifest;

      expect(bundleText, isNot(contains(_protectedText)));
      expect(manifest['dependencies'], isNotEmpty);
      expect(
        (manifest['dependencies'] as List).map((d) => d['exportPolicy']),
        everyElement('referenceOnly'),
      );

      final spellsFile = _jsonFile(exportResult.bytes, 'content/spells.json');
      expect(spellsFile['spells'], isEmpty);
    });

    test('imports with missing dependencies using diagnostics and snapshots',
        () async {
      final character = _protectedReferenceCharacter();
      await _saveProtectedLibrary();
      final bundleFile = File('${tempDir.path}/missing_dependency.qdnd');
      await QdndBundleExportService.exportCharacterToFile(
          character, bundleFile);

      await _clearStorageBoxes();
      await SpellService.reload();
      await ItemService.reload();
      await CharacterDataService.reload();

      final result = await QdndBundleImportService.importFile(bundleFile);

      expect(result.character.name, character.name);
      expect(result.missingDependencyCount, greaterThan(0));
      expect(result.diagnostics.map((d) => d.code),
          contains('missing_dependency'));
      expect(result.character.inventory.single.descriptionEn, isEmpty);
      expect(StorageService.getAllSpells().single.nameEn, 'Astral Spark');
      expect(StorageService.getAllSpells().single.descriptionEn,
          contains('Requires local content library'));
    });

    test('resolves existing local dependency on import', () async {
      final character = _protectedReferenceCharacter();
      await _saveProtectedLibrary();
      final bundleFile = File('${tempDir.path}/resolved_dependency.qdnd');
      await QdndBundleExportService.exportCharacterToFile(
          character, bundleFile);

      await _clearStorageBoxes();
      await StorageService.saveSource(
        CompendiumSource(
          id: 'local-source',
          name: 'Local Crimson Library',
          importedAt: DateTime.now(),
          itemCount: 1,
          spellCount: 1,
          featCount: 1,
        ),
      );
      await StorageService.saveSpells([
        _astralSpark(id: 'local_astral_spark', sourceId: 'local-source'),
      ]);
      await StorageService.saveItems([
        _crimsonBlade(
          id: 'local_crimson_blade',
          sourceId: 'local-source',
          description: 'Local item text',
        ),
      ]);
      await StorageService.saveFeats([
        _crimsonFeature(
          id: 'local_crimson_surge',
          sourceId: 'local-source',
          description: 'Local feature text',
        ),
      ]);
      await SpellService.reload();
      await ItemService.reload();
      await CharacterDataService.reload();

      final result = await QdndBundleImportService.importFile(bundleFile);

      expect(result.resolvedDependencyCount, greaterThan(0));
      expect(result.missingDependencyCount, 0);
      expect(result.character.knownSpells.single, 'local_astral_spark');
      expect(result.character.inventory.single.id, 'local_crimson_blade');
      expect(
          result.character.inventory.single.descriptionEn, 'Local item text');
      expect(
        result.diagnostics.map((d) => d.code),
        isNot(contains('missing_dependency')),
      );
    });

    test('export does not mutate the original character', () async {
      final character = _richCharacter();
      await StorageService.saveSpells([_astralSpark()]);
      await SpellService.reload();
      final before = jsonEncode(_stableCharacterProbe(character));

      await QdndBundleExportService.exportCharacter(
        character,
        options: const QdndBundleExportOptions(
          includeUserCreatedContent: true,
        ),
      );

      expect(jsonEncode(_stableCharacterProbe(character)), before);
    });

    test('rejects malformed bundles safely', () async {
      await expectLater(
        QdndBundleImportService.importBytes(_zipBytes({
          'character.json': '{}',
        })),
        throwsA(isA<QdndBundleException>()
            .having((e) => e.code, 'code', 'missing_manifest')),
      );

      await expectLater(
        QdndBundleImportService.importBytes(_zipBytes({
          'manifest.json': jsonEncode({
            'format': 'qdnd.bundle',
            'schemaVersion': 999,
          }),
          'character.json': '{}',
        })),
        throwsA(isA<QdndBundleException>()
            .having((e) => e.code, 'code', 'unsupported_schema')),
      );

      await expectLater(
        QdndBundleImportService.importBytes(_zipBytes({
          'manifest.json': jsonEncode({
            'format': 'qdnd.bundle',
            'schemaVersion': 1,
          }),
          '../evil.txt': 'nope',
        })),
        throwsA(isA<QdndBundleException>()
            .having((e) => e.code, 'code', 'unsafe_path')),
      );
    });

    test('runs feature hydration after import for known mechanics', () async {
      final character = Character(
        id: 'bundle-monk',
        name: 'Hydrated Monk',
        race: 'Human',
        characterClass: 'Monk',
        level: 2,
        maxHp: 17,
        currentHp: 17,
        abilityScores: AbilityScores(
          strength: 10,
          dexterity: 16,
          constitution: 14,
          intelligence: 10,
          wisdom: 16,
          charisma: 8,
        ),
        spellSlots: List.filled(9, 0),
        maxSpellSlots: List.filled(9, 0),
        features: [
          CharacterFeature(
            id: 'fc5_class_monk_ki',
            nameEn: 'Ki',
            nameRu: 'Ki',
            descriptionEn:
                'Your access to this energy is represented by ki points.',
            descriptionRu:
                'Your access to this energy is represented by ki points.',
            type: FeatureType.passive,
            minLevel: 2,
            associatedClass: 'Monk',
          ),
          CharacterFeature(
            id: 'fc5_class_monk_flurry_of_blows',
            nameEn: 'Flurry of Blows',
            nameRu: 'Flurry of Blows',
            descriptionEn:
                'You can spend 1 ki point to make two unarmed strikes as a bonus action.',
            descriptionRu:
                'You can spend 1 ki point to make two unarmed strikes as a bonus action.',
            type: FeatureType.passive,
            minLevel: 2,
            associatedClass: 'Monk',
          ),
        ],
      );

      final result = await QdndBundleImportService.importBytes(
        (await QdndBundleExportService.exportCharacter(character)).bytes,
      );

      final ki = result.character.features.singleWhere((f) => f.id == 'ki');
      expect(ki.resourcePool, isNotNull);
      expect(ki.resourcePool!.maxUses, 2);

      final flurry = result.character.features.singleWhere(
        (f) => f.nameEn == 'Flurry of Blows',
      );
      expect(flurry.usageCostId, 'ki');
      expect(flurry.actionEconomy, 'bonus_action');
    });

    test('imports selected QDND PlatformFile through path and bytes fallback',
        () async {
      final character = _richCharacter();
      final bundleFile = File('${tempDir.path}/picked.qdnd');
      final exportResult = await QdndBundleExportService.exportCharacterToFile(
        character,
        bundleFile,
      );

      final fromPath = await QdndBundleFileService.importPlatformFile(
        PlatformFile(
          name: 'picked.qdnd',
          path: bundleFile.path,
          size: await bundleFile.length(),
        ),
      );
      expect(fromPath.character.name, character.name);

      await _clearStorageBoxes();
      final fromBytes = await QdndBundleFileService.importPlatformFile(
        PlatformFile(
          name: 'picked.qdnd',
          size: exportResult.bytes.length,
          bytes: exportResult.bytes,
        ),
      );
      expect(fromBytes.character.name, character.name);

      await _clearStorageBoxes();
      final fromStream = await QdndBundleFileService.importPlatformFile(
        PlatformFile(
          name: 'picked.qdnd',
          size: exportResult.bytes.length,
          readStream: Stream.value(exportResult.bytes),
        ),
      );
      expect(fromStream.character.name, character.name);

      await expectLater(
        QdndBundleFileService.readPlatformFile(
          PlatformFile(
            name: 'picked.txt',
            size: exportResult.bytes.length,
            bytes: exportResult.bytes,
          ),
        ),
        throwsA(isA<QdndBundleException>()
            .having((e) => e.code, 'code', 'unsupported_file_type')),
      );
    });

    test('roundtrips local media through media manifest', () async {
      final avatar = File('${tempDir.path}/avatar.bin')
        ..writeAsBytesSync([1, 2, 3]);
      final noteImage = File('${tempDir.path}/note.bin')
        ..writeAsBytesSync([4, 5, 6]);
      final questImage = File('${tempDir.path}/quest.bin')
        ..writeAsBytesSync([7, 8, 9]);
      final itemImage = File('${tempDir.path}/item.bin')
        ..writeAsBytesSync([10, 11, 12]);
      final character = _richCharacter()
        ..avatarPath = avatar.path
        ..journalNotes.single.imagePath = noteImage.path
        ..quests.single.imagePath = questImage.path
        ..inventory.single.customImagePath = itemImage.path;

      final exportResult = await QdndBundleExportService.exportCharacter(
        character,
      );
      final mediaManifest =
          _jsonFile(exportResult.bytes, 'media/manifest.json');
      expect(mediaManifest['entries'], hasLength(4));
      expect(
        (mediaManifest['entries'] as List).map((e) => e['bundlePath']),
        everyElement(startsWith('media/')),
      );

      await _clearStorageBoxes();
      final importResult =
          await QdndBundleImportService.importBytes(exportResult.bytes);
      final imported = importResult.character;

      expect(imported.avatarPath, isNot(avatar.path));
      expect(File(imported.avatarPath!).readAsBytesSync(), [1, 2, 3]);
      expect(
        File(imported.journalNotes.single.imagePath!).readAsBytesSync(),
        [4, 5, 6],
      );
      expect(
        File(imported.quests.single.imagePath!).readAsBytesSync(),
        [7, 8, 9],
      );
      expect(
        File(imported.inventory.single.customImagePath!).readAsBytesSync(),
        [10, 11, 12],
      );
    });

    test('missing local media produces export warning without crashing',
        () async {
      final character = _richCharacter()
        ..avatarPath = '${tempDir.path}/missing-avatar.bin';

      final exportResult = await QdndBundleExportService.exportCharacter(
        character,
      );

      expect(exportResult.diagnostics.map((entry) => entry.code),
          contains('media_missing'));
      final mediaManifest =
          _jsonFile(exportResult.bytes, 'media/manifest.json');
      expect(mediaManifest['entries'], isEmpty);
    });
  });
}

const _protectedText = 'PROTECTED FULL TEXT DO NOT EMBED';

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

Character _richCharacter() {
  return Character(
    id: 'rich-original',
    name: 'Crimson Ledger',
    avatarPath: '/user/avatar.png',
    race: 'Human',
    characterClass: 'Barbarian',
    subclass: 'Path of the Crimson Star',
    level: 4,
    maxHp: 34,
    currentHp: 27,
    temporaryHp: 5,
    abilityScores: AbilityScores(
      strength: 16,
      dexterity: 14,
      constitution: 15,
      intelligence: 10,
      wisdom: 12,
      charisma: 8,
    ),
    background: 'Wandering Archivist',
    spellSlots: [0, 1, 0, 0, 0, 0, 0, 0, 0],
    maxSpellSlots: [0, 1, 0, 0, 0, 0, 0, 0, 0],
    armorClass: 15,
    speed: 35,
    initiative: 2,
    proficientSkills: const ['arcana', 'insight'],
    expertSkills: const ['arcana'],
    savingThrowProficiencies: const ['strength', 'wisdom'],
    personalityTraits: 'Records omens in red ink.',
    ideals: 'Memory must survive.',
    bonds: 'The Moon Gate map.',
    flaws: 'Never leaves a sealed door alone.',
    backstory: 'A synthetic hero for bundle tests.',
    appearance: 'Scarlet cloak',
    age: '31',
    gender: 'Nonbinary',
    height: '5 ft 9 in',
    weight: '160 lb',
    eyes: 'Amber',
    hair: 'Black',
    skin: 'Bronze',
    appearanceDescription: 'Ink-stained fingers.',
    knownSpells: const ['astral_spark'],
    preparedSpells: const ['astral_spark'],
    maxPreparedSpells: 1,
    concentratingOn: 'astral_spark',
    features: [
      CharacterFeature(
        id: 'rage',
        nameEn: 'Rage',
        nameRu: 'Rage',
        descriptionEn: 'Enter a rage as a bonus action.',
        descriptionRu: 'Enter a rage as a bonus action.',
        type: FeatureType.resourcePool,
        minLevel: 1,
        associatedClass: 'Barbarian',
        resourcePool: ResourcePool(
          currentUses: 1,
          maxUses: 2,
          recoveryType: RecoveryType.longRest,
        ),
      ),
    ],
    inventory: [
      _crimsonBlade(),
    ],
    deathSaves: DeathSaves(successes: 1),
    activeConditions: [ConditionType.frightened],
    hitDice: const [3],
    maxHitDice: 4,
    copperPieces: 9,
    silverPieces: 8,
    goldPieces: 42,
    platinumPieces: 1,
    journalNotes: [
      JournalNote(
        id: 'note-moon-gate',
        title: 'Moon Gate',
        content: 'Opens when the crimson bell rings.',
        category: NoteCategory.story,
        tags: const ['quest'],
        isPinned: true,
      ),
    ],
    quests: [
      Quest(
        id: 'quest-red-road',
        title: 'Red Road',
        description: 'Find the lost mile marker.',
        objectives: [
          QuestObjective(
            description: 'Recover the brass compass.',
            isCompleted: true,
          ),
        ],
      ),
    ],
    classes: [
      CharacterClass(
        id: 'barbarian',
        name: 'Barbarian',
        level: 4,
        subclass: 'Path of the Crimson Star',
        isPrimary: true,
      ),
    ],
    exhaustionLevel: 1,
    isRaging: true,
  );
}

Character _protectedReferenceCharacter() {
  return Character(
    id: 'protected-original',
    name: 'Reference Walker',
    race: 'Human',
    characterClass: 'Fighter',
    level: 3,
    maxHp: 28,
    currentHp: 28,
    abilityScores: AbilityScores(
      strength: 15,
      dexterity: 12,
      constitution: 14,
      intelligence: 10,
      wisdom: 10,
      charisma: 10,
    ),
    spellSlots: List.filled(9, 0),
    maxSpellSlots: List.filled(9, 0),
    knownSpells: const ['protected_astral_spark'],
    preparedSpells: const ['protected_astral_spark'],
    features: [
      _crimsonFeature(
        id: 'protected_crimson_surge',
        sourceId: 'protected-source',
        description: _protectedText,
      ),
    ],
    inventory: [
      _crimsonBlade(
        id: 'protected_crimson_blade',
        sourceId: 'protected-source',
        description: _protectedText,
      ),
    ],
  );
}

Future<void> _saveProtectedLibrary() async {
  await StorageService.saveSource(
    CompendiumSource(
      id: 'protected-source',
      name: 'Protected Crimson Library',
      importedAt: DateTime.now(),
      itemCount: 1,
      spellCount: 1,
      featCount: 1,
    ),
  );
  await StorageService.saveSpells([
    _astralSpark(
      id: 'protected_astral_spark',
      sourceId: 'protected-source',
      description: _protectedText,
    ),
  ]);
  await StorageService.saveItems([
    _crimsonBlade(
      id: 'protected_crimson_blade',
      sourceId: 'protected-source',
      description: _protectedText,
    ),
  ]);
  await StorageService.saveFeats([
    _crimsonFeature(
      id: 'protected_crimson_surge',
      sourceId: 'protected-source',
      description: _protectedText,
    ),
  ]);
}

Spell _astralSpark({
  String id = 'astral_spark',
  String? sourceId,
  String description = 'A synthetic open spark leaps between stars.',
}) {
  return Spell(
    id: id,
    nameEn: 'Astral Spark',
    nameRu: 'Astral Spark',
    level: 1,
    school: 'Evocation',
    castingTime: '1 action',
    range: '60 feet',
    duration: 'Instantaneous',
    concentration: false,
    ritual: false,
    components: const ['V', 'S'],
    descriptionEn: description,
    descriptionRu: description,
    availableToClasses: const ['Wizard'],
    sourceId: sourceId,
  );
}

Item _crimsonBlade({
  String id = 'crimson_blade',
  String? sourceId,
  String description = 'A synthetic open blade.',
}) {
  return Item(
    id: id,
    nameEn: 'Crimson Blade',
    nameRu: 'Crimson Blade',
    descriptionEn: description,
    descriptionRu: description,
    type: ItemType.weapon,
    rarity: ItemRarity.uncommon,
    quantity: 2,
    weight: 3,
    valueInCopper: 1200,
    isEquipped: true,
    isAttuned: true,
    isMagical: true,
    iconName: 'sword',
    sourceId: sourceId,
    weaponProperties: WeaponProperties(
      damageDice: '1d8',
      damageType: DamageType.slashing,
      weaponTags: const ['versatile'],
      versatileDamageDice: '1d10',
    ),
  );
}

CharacterFeature _crimsonFeature({
  String id = 'crimson_surge',
  String? sourceId,
  String description = 'A synthetic open surge.',
}) {
  return CharacterFeature(
    id: id,
    nameEn: 'Crimson Surge',
    nameRu: 'Crimson Surge',
    descriptionEn: description,
    descriptionRu: description,
    type: FeatureType.action,
    minLevel: 3,
    associatedClass: 'Fighter',
    actionEconomy: 'action',
    sourceId: sourceId,
  );
}

Map<String, dynamic> _stableCharacterProbe(Character character) => {
      'id': character.id,
      'knownSpells': character.knownSpells,
      'preparedSpells': character.preparedSpells,
      'concentratingOn': character.concentratingOn,
      'features': character.features.map((f) => f.toJson()).toList(),
      'inventory': character.inventory.map((i) => i.toJson()).toList(),
    };

Map<String, dynamic> _jsonFile(Uint8List bytes, String path) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final file = archive.find(path);
  if (file == null) {
    fail('Bundle file $path not found');
  }
  return jsonDecode(utf8.decode(file.readBytes()!)) as Map<String, dynamic>;
}

Uint8List _zipBytes(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
