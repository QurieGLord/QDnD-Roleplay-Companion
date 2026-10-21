import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/core/progression/level_up_draft.dart';
import 'package:qd_and_d/core/progression/level_up_commit.dart';
import 'package:qd_and_d/core/progression/progression_catalog_stamp.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/imported_progression_service.dart';
import 'package:qd_and_d/core/services/import_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'journal_service_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-late-library-');
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
  test('Fingerprint ignores map insertion order, not changed definitions', () {
    expect(
        ProgressionCatalogStamp.fingerprint({
          'a': 1,
          'b': {'x': 2, 'y': 3}
        }),
        ProgressionCatalogStamp.fingerprint({
          'b': {'y': 3, 'x': 2},
          'a': 1
        }));
    expect(ProgressionCatalogStamp.fingerprint({'a': 1}),
        isNot(ProgressionCatalogStamp.fingerprint({'a': 2})));
  });
  test(
      'Late FC5 import extends discovery without rewriting an already played hero',
      () async {
    final c = fixtures.hero()
      ..currentHp = 0
      ..maxHp = 30
      ..temporaryHp = 7
      ..armorClass = 19
      ..spellSlots = [6]
      ..maxSpellSlots = [4]
      ..goldPieces = 450;
    c.journalNotes.add(JournalNote(id: 'old-note', title: 'A saved story'));
    await StorageService.saveCharacter(c);
    final before = QdndBundleCodec.characterToJson(c);
    final stamp = ProgressionCatalogStamp.capture();
    final result = await ImportService.importCompendiumXmlContentDetailed(
        '''<compendium version="5"><spell><name>Late Library Beacon</name><level>1</level><school>V</school><classes>Wizard</classes><text>A newly available reference.</text></spell></compendium>''',
        sourceName: 'Late source');
    expect(result.parseResult.spells, isNotEmpty);
    expect(
        SpellService.getAllSpells()
            .any((s) => s.nameEn == 'Late Library Beacon'),
        isTrue);
    expect(stamp.isCurrent(), isFalse);
    expect(QdndBundleCodec.characterToJson(c), before);
    expect(QdndBundleCodec.characterToJson(StorageService.getCharacter(c.id)!),
        before);
    final afterImport = ProgressionCatalogStamp.capture();
    await StorageService.deleteSource(result.sourceId);
    await ImportService.reloadImportedContentServices();
    expect(afterImport.isCurrent(), isFalse);
    expect(QdndBundleCodec.characterToJson(c), before);
  });
  test(
      'A changed source rejects confirmation inside the queue, without a partial level',
      () async {
    final c = fixtures.hero();
    await StorageService.saveCharacter(c);
    final before = QdndBundleCodec.characterToJson(c);
    final draft = LevelUpDraft.begin(c, classId: 'fighter')..chooseHealth(6);
    final stamp = ProgressionCatalogStamp.capture();
    final gate = Completer<void>();
    final previous =
        GameplayActionsService.serializeCharacter(c, () => gate.future);
    var writes = 0;
    final commit = LevelUpCommit.apply(c,
        baseline: draft,
        result: draft.preview,
        validateContext: stamp.verifyContent, write: (_) async {
      writes++;
    });
    final rejected = expectLater(commit, throwsStateError);
    await SpellService.reload();
    gate.complete();
    await previous;
    await rejected;
    expect(writes, 0);
    expect(QdndBundleCodec.characterToJson(c), before);
  });
  test(
      'Direct definition mutation is caught by content verification without hashing every frame',
      () {
    final spell = SpellService.getAllSpells().first;
    final original = spell.descriptionEn;
    final stamp = ProgressionCatalogStamp.capture();
    try {
      spell.descriptionEn = 'A changed rule definition';
      expect(stamp.isCurrent(), isTrue);
      expect(stamp.verifyContent(), isFalse);
    } finally {
      spell.descriptionEn = original;
    }
    expect(stamp.verifyContent(), isTrue);
  });
  test(
      'A same-name class with another hit die remains a separate source variant',
      () {
    final base = CharacterDataService.getClassById('paladin')!;
    final variant = ClassData(
        id: 'paladin',
        name: base.name,
        description: base.description,
        hitDie: 12,
        primaryAbilities: base.primaryAbilities,
        savingThrowProficiencies: base.savingThrowProficiencies,
        armorProficiencies: base.armorProficiencies,
        weaponProficiencies: base.weaponProficiencies,
        skillProficiencies: base.skillProficiencies,
        subclasses: base.subclasses,
        subclassLevel: base.subclassLevel,
        spellcasting: base.spellcasting,
        features: base.features,
        sourceId: 'variant-book',
        rulesMetadata: {
          'declaredFields': ['hitDie']
        });
    final assessment = ImportedProgressionService.assessClass(base, variant);
    expect(assessment.relation, ClassLibraryRelation.competingVariant);
    expect(assessment.differences, contains('hitDie'));
    final catalog = ImportedProgressionService.overlayImportedClasses(
        assetClasses: [base], importedClasses: [variant]);
    expect(catalog, hasLength(2));
    expect(catalog.first.hitDie, 10);
    expect(catalog.last.hitDie, 12);
    expect(catalog.map((c) => c.id).toSet(), hasLength(2));
    expect(variant.id, 'paladin');
  });
}
