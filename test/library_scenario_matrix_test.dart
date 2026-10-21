import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/models/compendium_source.dart';
import 'package:qd_and_d/core/models/spell.dart';
import 'package:qd_and_d/core/services/catalog_definition_signature.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/import_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';

String spell(String text, {String range = '60 feet'}) =>
    '''<spell><name>Shared Beacon</name><level>1</level><school>V</school><classes>Wizard</classes><range>$range</range><text>$text</text></spell>''';
String book(String body) => '<compendium>$body</compendium>';
Future<CompendiumImportResult> install(String xml) =>
    ImportService.importCompendiumXmlContentDetailed(xml,
        sourceName: 'Same book name');
Matcher rejected(String code) => throwsA(isA<ImportServiceException>().having(
    (e) => e.diagnostics.entries.map((d) => d.code),
    'diagnostics',
    contains(code)));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-library-matrix-');
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
  setUp(() async {
    await Hive.box('settings').clear();
    await Hive.box<Spell>('spells_library').clear();
    await Hive.box<ClassData>('classes_library').clear();
    await Hive.box<CharacterFeature>('feats_library').clear();
    await Hive.box<CompendiumSource>('compendium_sources').clear();
    await ImportService.reloadImportedContentServices();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  test('Same book and spell names retain distinct mechanics and source IDs',
      () async {
    final first = await install(book(spell('Old rule.')));
    final second =
        await install(book(spell('Another rule.', range: '120 feet')));
    final spells = StorageService.getAllSpells();
    expect(spells, hasLength(2));
    expect(spells.map((s) => s.id).toSet(), hasLength(2));
    expect(spells.map((s) => s.sourceId).toSet(),
        {first.sourceId, second.sourceId});
    await StorageService.deleteSource(first.sourceId);
    await ImportService.reloadImportedContentServices();
    final remaining =
        SpellService.getAllSpells().where((s) => s.sourceId != null).single;
    expect(remaining.sourceId, second.sourceId);
    expect(remaining.descriptionEn, 'Another rule.');
    expect(remaining.range, '120 feet');
  });
  test(
      'Identical overlap in independent books survives either book being removed',
      () async {
    final first = await install(book(spell('Shared rule.')));
    final second = await install(book(
        '${spell('Shared rule.')}<feat><name>Other Content</name><text>A separate addition.</text></feat>'));
    expect(StorageService.getAllSpells(), hasLength(2));
    await StorageService.deleteSource(first.sourceId);
    expect(StorageService.getAllSpells().single.sourceId, second.sourceId);
    expect(StorageService.getAllSpells().single.descriptionEn, 'Shared rule.');
    expect(StorageService.getAllFeats(), hasLength(1));
  });
  test(
      'Exact repetitions collapse; distinct same-name FC5 definitions remain variants',
      () async {
    final repeated = await install(book('${spell('Same.')} ${spell('Same.')}'));
    expect(repeated.parseResult.spells, hasLength(1));
    final variants =
        await install(book('${spell('First.')} ${spell('Different.')}'));
    expect(variants.parseResult.spells, hasLength(2));
    expect(variants.parseResult.spells.map((s) => s.id).toSet(), hasLength(2));
    expect(variants.parseResult.diagnostics.entries.map((d) => d.code),
        contains('named_variants_preserved'));
    expect(StorageService.getAllSources(), hasLength(2));
    await StorageService.deleteSource(repeated.sourceId);
    expect(StorageService.getAllSpells().map((s) => s.descriptionEn).toSet(),
        {'First.', 'Different.'});
  });
  test('Conflicting same-name class chassis cannot be silently combined',
      () async {
    final xml = book(
        '<class><name>Fighter</name><hd>10</hd></class><class><name>Fighter</name><hd>12</hd></class>');
    await expectLater(install(xml), rejected('conflicting_class_definition'));
    expect(StorageService.getAllSources(), isEmpty);
    expect(StorageService.getAllClasses(), isEmpty);
  });
  test(
      'Equal feature names in different subclasses retain their different definitions',
      () async {
    String subclass(String name, String rule) =>
        '''<class><name>Paladin: Oath of $name</name><hd>10</hd><spellAbility>Charisma</spellAbility><autolevel level="3"><feature><name>Shared Rite</name><text>$rule</text></feature></autolevel></class>''';
    final result = await install(
        book('${subclass('Ash', 'Embers.')} ${subclass('Dawn', 'Sunlight.')}'));
    final features = result.parseResult.classes.single.features[3]!;
    expect(features, hasLength(2));
    expect(
        features.map((f) => f.descriptionEn).toSet(), {'Embers.', 'Sunlight.'});
    expect(features.every((f) => f.associatedSubclass?.isNotEmpty ?? false),
        isTrue);
  });
  test('Conflicting features in the same class and level reject the source',
      () async {
    String node(String text) =>
        '<class><name>Fighter</name><hd>10</hd><autolevel level="1"><feature><name>Shared Training</name><text>$text</text></feature></autolevel></class>';
    await expectLater(install(book('${node('Old.')} ${node('New.')}')),
        rejected('conflicting_class_feature'));
    expect(StorageService.getAllSources(), isEmpty);
  });
  test(
      'A conflicting repeated ability inside one class node also rejects the book',
      () async {
    final xml = book(
        '<class><name>Fighter</name><hd>10</hd><autolevel level="1"><feature><name>Shared Training</name><text>Old.</text></feature><feature><name>Shared Training</name><text>New.</text></feature></autolevel></class>');
    await expectLater(install(xml), rejected('conflicting_class_feature'));
    expect(StorageService.getAllSources(), isEmpty);
  });
  test(
      'Concurrent duplicate imports install once and a rejected import does not poison the queue',
      () async {
    final xml = book(spell('One installation.'));
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        install(xml).then<Object>((r) => r, onError: (Object e) => e)
    ]);
    expect(results.whereType<CompendiumImportResult>(), hasLength(1));
    expect(results.whereType<ImportServiceException>(), hasLength(1));
    expect(StorageService.getAllSources(), hasLength(1));
    expect(StorageService.getAllSpells(), hasLength(1));
    await install(book(spell('Next installation.')));
    expect(StorageService.getAllSources(), hasLength(2));
  });
  test(
      'Definition comparison ignores root identity but retains nested mechanical references',
      () {
    expect(
        CatalogDefinitionSignature.of({
          'id': 'a',
          'sourceId': 'x',
          'rule': {'id': 'resource-a'}
        }),
        CatalogDefinitionSignature.of({
          'rule': {'id': 'resource-a'},
          'sourceId': 'y',
          'id': 'b'
        }));
    expect(
        CatalogDefinitionSignature.of({
          'rule': {'id': 'resource-a'}
        }),
        isNot(CatalogDefinitionSignature.of({
          'rule': {'id': 'resource-b'}
        })));
  });
}
