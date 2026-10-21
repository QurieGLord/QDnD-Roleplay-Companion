// Positive state and migration contracts for the current-cycle changes.
// This standalone test file lives in /tmp; product files are never edited here.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/models/compendium_source.dart';
import 'package:qd_and_d/core/models/item.dart';
import 'package:qd_and_d/core/models/spell.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_export_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_import_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_schema.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/spellcasting_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';

Character pc({
  String className = 'Barbarian',
  List<CharacterFeature>? features,
}) =>
    Character(
      id: 'cycle-native-pc',
      name: 'Cycle Native',
      race: 'Human',
      characterClass: className,
      level: 3,
      maxHp: 30,
      currentHp: 23,
      temporaryHp: 5,
      abilityScores: AbilityScores(
        strength: 14,
        dexterity: 14,
        constitution: 14,
        intelligence: 14,
        wisdom: 14,
        charisma: 14,
      ),
      spellSlots: const [6, 0, 0, 0, 0, 0, 0, 0, 0],
      maxSpellSlots: const [4, 0, 0, 0, 0, 0, 0, 0, 0],
      armorClass: 19,
      armorClassOverride: 19,
      usesAutomaticArmorClass: false,
      features: features,
      classes: [
        CharacterClass(
          id: className.toLowerCase(),
          name: className,
          level: 3,
          isPrimary: true,
        ),
      ],
    );
CharacterFeature resource(
  String id,
  String name,
  String associatedClass, {
  String? sourceId,
  RecoveryType recovery = RecoveryType.manual,
  int current = 6,
  int maximum = 4,
}) =>
    CharacterFeature(
      id: id,
      nameEn: name,
      nameRu: name,
      descriptionEn: 'Loaded source description',
      descriptionRu: 'Загруженное описание',
      type: FeatureType.resourcePool,
      minLevel: 1,
      associatedClass: associatedClass,
      sourceId: sourceId,
      resourcePool: ResourcePool(
        currentUses: current,
        maxUses: maximum,
        recoveryType: recovery,
        calculationFormula: 'level',
      ),
    );
ResourcePool pool(Character c, String name) => c.features
    .singleWhere(
      (f) =>
          f.resourcePool != null &&
          f.nameEn.toLowerCase() == name.toLowerCase(),
    )
    .resourcePool!;
void expectSixFour(ResourcePool p) {
  expect(p.currentUses, 6);
  expect(p.maxUses, 4);
}

List<int> oldBundle(Map<String, dynamic> state) {
  final characterBytes = utf8.encode(
    jsonEncode({'schemaVersion': 1, 'character': state}),
  );
  final manifestBytes = utf8.encode(
    jsonEncode({
      'format': 'qdnd.bundle',
      'schemaVersion': 1,
      'checksums': {
        'character.json': QdndBundleHashes.bytesHash(characterBytes),
      },
    }),
  );
  final archive = Archive()
    ..addFile(ArchiveFile.bytes('character.json', characterBytes))
    ..addFile(ArchiveFile.bytes('manifest.json', manifestBytes));
  return ZipEncoder().encode(archive);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd_cycle_native_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => dir.path,
    );
    await StorageService.init();
    await FeatureService.init();
    await SpellService.loadSpells();
    await ItemService.loadItems();
    await CharacterDataService.loadAllData();
  });
  setUp(() async {
    await Hive.box<Character>('characters').clear();
    await Hive.box<Spell>('spells_library').clear();
    await Hive.box<Item>('items_library').clear();
    await Hive.box<CharacterFeature>('feats_library').clear();
    await Hive.box<CompendiumSource>('compendium_sources').clear();
    await SpellService.reload();
    await ItemService.reload();
    await CharacterDataService.reload();
  });
  tearDownAll(() async {
    await Hive.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });
  for (final spec in [('Barbarian', 'rage', 'Rage'), ('Monk', 'ki', 'Ki')]) {
    test(
      'native ${spec.$3}: known mechanics preserve manual 6/4 and recovery through hydration',
      () async {
        final original = pc(
          className: spec.$1,
          features: [resource(spec.$2, spec.$3, spec.$1)],
        );
        final builtin = FeatureService.getFeatureById(spec.$2);
        expect(
          builtin,
          isNotNull,
        ); // This is deliberately a known mechanic, not a text-only feature.
        final beforeBuiltin = builtin!.resourcePool!.toJson();
        final exported = await QdndBundleExportService.exportCharacter(
          original,
        );
        final result = await QdndBundleImportService.importBytes(
          exported.bytes,
        );
        final imported = pool(result.character, spec.$3);
        expectSixFour(imported);
        expect(imported.recoveryType, RecoveryType.manual);
        expect(imported.calculationFormula, 'level');
        imported.use(1);
        expect(imported.currentUses, 5);
        expect(imported.maxUses, 4);
        expectSixFour(pool(original, spec.$3));
        expect(builtin.resourcePool!.toJson(), beforeBuiltin);
        result.character.longRest();
        expect(
          imported.currentUses,
          5,
        ); // Manual recovery remains player-managed.
        expect(result.character.armorClass, 19);
        expect(result.character.armorClassOverride, 19);
      },
    );
  }
  test(
      'native resolved library template does not replace the stored manual numeric pool',
      () async {
    final template = resource(
      'cycle_external_ki',
      'Ki',
      'Monk',
      sourceId: 'cycle-source',
      current: 99,
      maximum: 99,
      recovery: RecoveryType.shortRest,
    );
    await StorageService.saveFeats([template]);
    await CharacterDataService.reload();
    final original = pc(
      className: 'Monk',
      features: [
        resource(
          'cycle_external_ki',
          'Ki',
          'Monk',
          sourceId: 'cycle-source',
          recovery: RecoveryType.manual,
        ),
      ],
    );
    final exported = await QdndBundleExportService.exportCharacter(original);
    final result = await QdndBundleImportService.importBytes(exported.bytes);
    expect(result.resolvedDependencyCount, 1);
    expect(result.missingDependencyCount, 0);
    final imported = pool(result.character, 'Ki');
    expectSixFour(imported);
    expect(imported.recoveryType, RecoveryType.manual);
    expect(template.resourcePool!.currentUses, 99);
    expect(template.resourcePool!.maxUses, 99);
  });
  test(
      'legacy native JSON pins saved AC 19; load and save do not replace it with calculated 12',
      () async {
    final state = QdndBundleCodec.characterToJson(pc(className: 'Wizard'));
    for (final key in [
      'armorClassOverride',
      'usesAutomaticArmorClass',
      'isFrenzied',
      'isReckless',
      'isHidden',
      'isSacredWeaponActive',
    ]) {
      state.remove(key);
    }
    final result = await QdndBundleImportService.importBytes(oldBundle(state));
    final imported = result.character;
    expect(imported.calculatedArmorClass, 12);
    expect(imported.armorClass, 19);
    expect(imported.armorClassOverride, 19);
    expect(imported.usesAutomaticArmorClass, isFalse);
    expect(imported.isFrenzied, isFalse);
    expect(imported.isHidden, isFalse);
    await imported.save();
    expect(StorageService.getCharacter(imported.id)!.armorClass, 19);
    imported.recalculateAC();
    expect(imported.armorClass, 19);
  });
  test(
      'explicit automatic mode with null override stays automatic across actual native import',
      () async {
    final state = QdndBundleCodec.characterToJson(pc(className: 'Wizard'));
    state['armorClass'] = 12;
    state['armorClassOverride'] = null;
    state['usesAutomaticArmorClass'] = true;
    final result = await QdndBundleImportService.importBytes(oldBundle(state));
    final imported = result.character;
    expect(imported.armorClass, 12);
    expect(imported.armorClassOverride, isNull);
    expect(imported.usesAutomaticArmorClass, isTrue);
    imported.abilityScores = imported.abilityScores.copyWith(dexterity: 18);
    imported.recalculateAC();
    expect(imported.armorClass, 14);
    final json = QdndBundleCodec.characterToJson(imported);
    expect(json['armorClassOverride'], isNull);
    expect(json['usesAutomaticArmorClass'], isTrue);
  });
  test(
      'new persisted flags survive native export/import and end Frenzy exactly once',
      () async {
    final original = pc()
      ..isRaging = true
      ..isFrenzied = true
      ..isReckless = true
      ..isHidden = true
      ..isSacredWeaponActive = true
      ..exhaustionLevel = 2;
    final exported = await QdndBundleExportService.exportCharacter(original);
    final imported =
        (await QdndBundleImportService.importBytes(exported.bytes)).character;
    expect(imported.isRaging, isTrue);
    expect(imported.isFrenzied, isTrue);
    expect(imported.isReckless, isTrue);
    expect(imported.isHidden, isTrue);
    expect(imported.isSacredWeaponActive, isTrue);
    expect(imported.exhaustionLevel, 2);
    imported.endRage();
    expect(imported.exhaustionLevel, 3);
    expect(imported.isFrenzied, isFalse);
    imported.endRage();
    expect(imported.exhaustionLevel, 3);
    expect(original.isFrenzied, isTrue);
    expect(original.exhaustionLevel, 2);
  });
  test(
      'known spell cost and over-cap slots stay local and persist through native transfer',
      () async {
    final spell = SpellService.getAllSpells().firstWhere((s) => s.level == 1);
    final original = pc(className: 'Wizard')
      ..knownSpells = [spell.id]
      ..preparedSpells = [spell.id];
    final imported = (await QdndBundleImportService.importBytes(
      (await QdndBundleExportService.exportCharacter(original)).bytes,
    ))
        .character;
    expect(imported.knownSpells, [spell.id]);
    expect(imported.preparedSpells, [spell.id]);
    expect(
      SpellcastingService.applyCast(imported, spell, slotLevel: 1),
      isTrue,
    );
    expect(imported.spellSlots.first, 5);
    expect(imported.maxSpellSlots.first, 4);
    expect(original.spellSlots.first, 6);
    await imported.save();
    expect(StorageService.getCharacter(imported.id)!.spellSlots.first, 5);
    imported.longRest();
    expect(imported.spellSlots.first, 5);
  });
  test(
      'local codec duplicate preserves source snapshots and creates independent nested state',
      () async {
    final feature = resource(
      'cycle_custom_pool',
      'Custom Pool',
      'Barbarian',
      sourceId: 'cycle-source',
    )
      ..consumption = FeatureConsumption(
        resourceId: 'cycle_custom_pool',
        amount: 1,
      )
      ..options = ['option-a'];
    final original = pc(features: [feature])
      ..isFrenzied = true
      ..isHidden = true;
    original.inventory = [
      Item(
        id: 'cycle_source_item',
        nameEn: 'Source Item',
        nameRu: 'Источник',
        descriptionEn: 'Loaded local item text',
        descriptionRu: 'Локальный текст',
        type: ItemType.gear,
        rarity: ItemRarity.common,
        sourceId: 'cycle-source',
        customImagePath: '/tmp/local-snapshot-image.png',
      ),
    ];
    final duplicate = QdndBundleCodec.cloneCharacter(original)
      ..id = 'cycle-copy';
    final copied = duplicate.features.single;
    expect(copied.sourceId, 'cycle-source');
    expect(copied.descriptionEn, original.features.single.descriptionEn);
    expect(
      duplicate.inventory.single.descriptionEn,
      original.inventory.single.descriptionEn,
    );
    expect(
      duplicate.inventory.single.customImagePath,
      '/tmp/local-snapshot-image.png',
    );
    copied.resourcePool!.use(1);
    copied.options!.add('option-b');
    copied.consumption!.amount = 3;
    duplicate.inventory.single.quantity = 7;
    expectSixFour(original.features.single.resourcePool!);
    expect(original.features.single.options, ['option-a']);
    expect(original.features.single.consumption!.amount, 1);
    expect(original.inventory.single.quantity, 1);
    expect(duplicate.isFrenzied, isTrue);
    expect(duplicate.isHidden, isTrue);
  });
  // Keep the migration test last: reopening the box deliberately invalidates StorageService's cached box handle.
  test(
      'pre-change Hive binary migrates, re-saves and reopens with manual AC/pool and safe new defaults',
      () async {
    final legacy = pc(features: [resource('rage', 'Rage', 'Barbarian')])
      ..isRaging = true
      ..exhaustionLevel = 2;
    final writer = BinaryWriterImpl(Hive);
    _LegacyCharacterWriter().write(writer, legacy);
    final loaded = CharacterAdapter().read(
      BinaryReaderImpl(writer.toBytes(), Hive),
    );
    expect(loaded.armorClass, 19);
    expect(loaded.armorClassOverride, 19);
    expect(loaded.usesAutomaticArmorClass, isFalse);
    expectSixFour(pool(loaded, 'Rage'));
    expect(loaded.isRaging, isTrue);
    expect(loaded.exhaustionLevel, 2);
    expect(loaded.isFrenzied, isFalse);
    expect(loaded.isReckless, isFalse);
    expect(loaded.isHidden, isFalse);
    expect(loaded.isSacredWeaponActive, isFalse);
    await StorageService.saveCharacter(loaded);
    await loaded.save();
    await Hive.box<Character>('characters').close();
    final reopened = await Hive.openBox<Character>('characters');
    final persisted = reopened.get(loaded.id)!;
    expect(persisted.armorClass, 19);
    expect(persisted.armorClassOverride, 19);
    expect(persisted.usesAutomaticArmorClass, isFalse);
    expectSixFour(pool(persisted, 'Rage'));
    expect(persisted.isRaging, isTrue);
    expect(persisted.isFrenzied, isFalse);
    persisted.isFrenzied = true;
    persisted.isReckless = true;
    persisted.isHidden = true;
    persisted.isSacredWeaponActive = true;
    await persisted.save();
    await reopened.close();
    final secondOpen = await Hive.openBox<Character>('characters');
    final newPersisted = secondOpen.get(loaded.id)!;
    expect(newPersisted.isFrenzied, isTrue);
    expect(newPersisted.isReckless, isTrue);
    expect(newPersisted.isHidden, isTrue);
    expect(newPersisted.isSacredWeaponActive, isTrue);
    expect(newPersisted.armorClass, 19);
    expectSixFour(pool(newPersisted, 'Rage'));
  });
}

// Frozen writer from HEAD 4219ca9 character.g.dart, before fields 75..80 existed.
// Only private exhaustion access is replaced by its public getter. Current reader
// must actually decode this old binary and persist it; no field-count-only assertion.
class _LegacyCharacterWriter extends TypeAdapter<Character> {
  @override
  final int typeId = 0;
  @override
  Character read(BinaryReader reader) => throw UnimplementedError();
  @override
  void write(BinaryWriter writer, Character obj) {
    writer
      ..writeByte(75)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.avatarPath)
      ..writeByte(3)
      ..write(obj.race)
      ..writeByte(4)
      ..write(obj.characterClass)
      ..writeByte(5)
      ..write(obj.subclass)
      ..writeByte(6)
      ..write(obj.level)
      ..writeByte(7)
      ..write(obj.maxHp)
      ..writeByte(8)
      ..write(obj.currentHp)
      ..writeByte(9)
      ..write(obj.temporaryHp)
      ..writeByte(10)
      ..write(obj.abilityScores)
      ..writeByte(11)
      ..write(obj.background)
      ..writeByte(12)
      ..write(obj.spellSlots)
      ..writeByte(13)
      ..write(obj.maxSpellSlots)
      ..writeByte(14)
      ..write(obj.armorClass)
      ..writeByte(15)
      ..write(obj.speed)
      ..writeByte(16)
      ..write(obj.initiative)
      ..writeByte(17)
      ..write(obj.proficientSkills)
      ..writeByte(18)
      ..write(obj.savingThrowProficiencies)
      ..writeByte(19)
      ..write(obj.personalityTraits)
      ..writeByte(20)
      ..write(obj.ideals)
      ..writeByte(21)
      ..write(obj.bonds)
      ..writeByte(22)
      ..write(obj.flaws)
      ..writeByte(23)
      ..write(obj.backstory)
      ..writeByte(24)
      ..write(obj.createdAt)
      ..writeByte(25)
      ..write(obj.updatedAt)
      ..writeByte(26)
      ..write(obj.appearance)
      ..writeByte(27)
      ..write(obj.knownSpells)
      ..writeByte(28)
      ..write(obj.preparedSpells)
      ..writeByte(29)
      ..write(obj.maxPreparedSpells)
      ..writeByte(30)
      ..write(obj.features)
      ..writeByte(31)
      ..write(obj.inventory)
      ..writeByte(32)
      ..write(obj.combatState)
      ..writeByte(33)
      ..write(obj.deathSaves)
      ..writeByte(34)
      ..write(obj.activeConditions)
      ..writeByte(35)
      ..write(obj.concentratingOn)
      ..writeByte(36)
      ..write(obj.hitDice)
      ..writeByte(37)
      ..write(obj.maxHitDice)
      ..writeByte(38)
      ..write(obj.age)
      ..writeByte(39)
      ..write(obj.gender)
      ..writeByte(40)
      ..write(obj.height)
      ..writeByte(41)
      ..write(obj.weight)
      ..writeByte(42)
      ..write(obj.eyes)
      ..writeByte(43)
      ..write(obj.hair)
      ..writeByte(44)
      ..write(obj.skin)
      ..writeByte(45)
      ..write(obj.appearanceDescription)
      ..writeByte(46)
      ..write(obj.copperPieces)
      ..writeByte(47)
      ..write(obj.silverPieces)
      ..writeByte(48)
      ..write(obj.goldPieces)
      ..writeByte(49)
      ..write(obj.platinumPieces)
      ..writeByte(50)
      ..write(obj.journalNotes)
      ..writeByte(51)
      ..write(obj.quests)
      ..writeByte(52)
      ..write(obj.classes)
      ..writeByte(53)
      ..write(obj.expertSkills)
      ..writeByte(54)
      ..write(obj.wildShapeCharges)
      ..writeByte(55)
      ..write(obj.naturalRecoveryUsed)
      ..writeByte(56)
      ..write(obj.isWildShaped)
      ..writeByte(57)
      ..write(obj.arcaneRecoveryUsed)
      ..writeByte(58)
      ..write(obj.spellMasterySpells)
      ..writeByte(59)
      ..write(obj.signatureSpells)
      ..writeByte(60)
      ..write(obj.signatureSpellsUsed)
      ..writeByte(61)
      ..write(obj.channelDivinityCharges)
      ..writeByte(62)
      ..write(obj.divineInterventionUsed)
      ..writeByte(63)
      ..write(obj.favoredEnemies)
      ..writeByte(64)
      ..write(obj.naturalExplorers)
      ..writeByte(65)
      ..write(obj.beastName)
      ..writeByte(66)
      ..write(obj.beastMaxHp)
      ..writeByte(67)
      ..write(obj.beastCurrentHp)
      ..writeByte(68)
      ..write(obj.beastIcon)
      ..writeByte(69)
      ..write(obj.isHuntersMarkActive)
      ..writeByte(70)
      ..write(obj.huntersMarkTarget)
      ..writeByte(71)
      ..write(obj.isHiddenInPlainSight)
      ..writeByte(73)
      ..write(obj.relentlessRageSaveDc)
      ..writeByte(74)
      ..write(obj.isRaging)
      ..writeByte(72)
      ..write(obj.exhaustionLevel);
  }
}
