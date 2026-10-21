import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/progression/character_class_rules.dart';
import 'package:qd_and_d/core/progression/multiclass_rules.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:qd_and_d/core/services/imported_progression_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'journal_service_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-owned-rules-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  test('Missing die stays unknown through XML, codec and a real Hive restart',
      () async {
    final parsed = await FC5Parser.parseCompendium(
        '<compendium><class><name>Unknown Knight</name><other>Retain this unknown rule.</other></class></compendium>',
        sourceId: 'unknown');
    final data = parsed.classes.single;
    expect(data.declares('hitDie'), false);
    expect(data.rulesEdition, 'unknown');
    expect(data.sourceDefinition,
        contains('<other>Retain this unknown rule.</other>'));
    await StorageService.saveClasses([data]);
    await Hive.close();
    await StorageService.init();
    final restored = StorageService.getAllClasses().single;
    expect(restored.declares('hitDie'), false);
    final transferred =
        QdndBundleCodec.classFromJson(QdndBundleCodec.classToJson(restored));
    expect(transferred.declares('hitDie'), false);
    expect(transferred.sourceDefinition, restored.sourceDefinition);
  });
  test(
      'Partial Paladin does not conflict with d10 just because compatibility default is d8',
      () async {
    final base = CharacterDataService.getClassById('paladin')!;
    final incoming = (await FC5Parser.parseCompendium(
            '<compendium><class><name>Paladin: Oath of Stars</name><autolevel level="3"><feature><name>Starlit Vow</name><text>Custom.</text></feature></autolevel></class></compendium>',
            sourceId: 'stars'))
        .classes
        .single;
    expect(incoming.declares('hitDie'), false);
    expect(ImportedProgressionService.assessClass(base, incoming).differences,
        isNot(contains('hitDie')));
    final merged = ImportedProgressionService.overlayImportedClasses(
        assetClasses: [base], importedClasses: [incoming]).single;
    expect(merged.hitDie, 10);
    expect(merged.rulesEdition, '2014');
  });
  test(
      'Explicit chassis is preserved when an incomplete subclass node is first',
      () async {
    final parsed = await FC5Parser.parseCompendium(
        '<compendium><class><name>Paladin: Oath of Stars</name></class><class><name>Paladin</name><hd>10</hd></class></compendium>',
        sourceId: 'mixed');
    expect(parsed.diagnostics.hasErrors, false);
    expect(parsed.classes.single.hitDie, 10);
    expect(parsed.classes.single.declares('hitDie'), true);
  });
  test(
      'Captured rules are detached from mutable library definitions and cloned heroes',
      () {
    final data = CharacterDataService.getClassById('sorcerer')!;
    final rules = CharacterClassRules.capture(data);
    final c = fixtures.hero();
    rules.attachTo(c.classes.single);
    final original = rules.feature('metamagic-1')!.descriptionEn;
    final live = FeatureService.getFeatureById('metamagic-1')!;
    final previous = live.descriptionEn;
    try {
      live.descriptionEn = 'Changed later.';
      expect(
          CharacterClassRules.resolve(c.classes.single)
              .feature('metamagic-1')!
              .descriptionEn,
          original);
      final clone = QdndBundleCodec.cloneCharacter(c);
      clone.classes.single.rulesSnapshot!['version'] = 999;
      expect(c.classes.single.rulesSnapshot!['version'], 1);
      expect(() => CharacterClassRules.resolve(clone.classes.single),
          throwsFormatException);
    } finally {
      live.descriptionEn = previous;
    }
  });
  test(
      'A frozen imported class survives catalog removal, Hive restart and character JSON transfer',
      () async {
    final data = (await FC5Parser.parseCompendium(
            '<compendium><class><name>Star Knight</name><hd>12</hd><autolevel level="2"><feature><name>Star Ward</name><text>A personal rule.</text></feature></autolevel></class></compendium>',
            sourceId: 'vanishing'))
        .classes
        .single;
    final c = fixtures.hero();
    c.classes.single.id = data.id;
    c.classes.single.name = data.getName('en');
    CharacterClassRules.capture(data).attachTo(c.classes.single);
    await StorageService.saveCharacter(c);
    await StorageService.deleteSource('vanishing');
    await Hive.close();
    await StorageService.init();
    final saved = StorageService.getCharacter(c.id)!;
    final imported = QdndBundleCodec.characterFromJson(
        QdndBundleCodec.characterToJson(saved));
    final rules = CharacterClassRules.resolve(imported.classes.single);
    expect(rules.data.hitDie, 12);
    expect(rules.atLevel(2, null).single.descriptionEn, 'A personal rule.');
  });
  test(
      'Missing old Hive fields remain readable and are not silently pinned on access',
      () {
    final c = fixtures.hero();
    expect(c.classes.single.rulesSnapshot, isNull);
    final rules = CharacterClassRules.resolve(c.classes.single);
    expect(rules.data.id, c.classes.single.id);
    expect(c.classes.single.rulesSnapshot, isNull);
  });
  test(
      'Multiclass capacity resolves the saved rules, keeping personal learning and Pact separate',
      () {
    final c = fixtures.hero();
    c.classes = [
      CharacterClass(id: 'ranger', name: 'Ranger', level: 4, isPrimary: true),
      CharacterClass(id: 'wizard', name: 'Wizard', level: 3)
    ];
    c.level = 7;
    for (final entry in c.classes) {
      CharacterClassRules.capture(CharacterDataService.getClassById(entry.id)!)
          .attachTo(entry);
    }
    var capacity = MulticlassRules.spellCapacity(c);
    expect(capacity.sharedSlots, [4, 3, 2]);
    expect(capacity.learningCircles, {'ranger': 1, 'wizard': 2});
    c.classes[0] = CharacterClass(
        id: 'warlock', name: 'Warlock', level: 2, isPrimary: true);
    c.level = 5;
    CharacterClassRules.capture(CharacterDataService.getClassById('warlock')!)
        .attachTo(c.classes[0]);
    capacity = MulticlassRules.spellCapacity(c);
    expect(capacity.sharedSlots, [4, 2]);
    expect(capacity.pact!.circle, 1);
    expect(capacity.pact!.count, 2);
  });
  test(
      'A historical five-field CharacterClass is readable after restart without a fabricated binding',
      () async {
    final c = fixtures.hero();
    Hive.registerAdapter<CharacterClass>(_LegacyCharacterClassWriter(),
        override: true);
    await StorageService.saveCharacter(c);
    await Hive.close();
    Hive.registerAdapter<CharacterClass>(CharacterClassAdapter(),
        override: true);
    await StorageService.init();
    final restored = StorageService.getCharacter(c.id)!;
    expect(restored.classes.single.rulesSnapshot, isNull);
    expect(restored.classes.single.level, c.classes.single.level);
    expect(restored.classes.single.isPrimary, true);
  });
  test(
      'A user definition with a built-in ID cannot inherit its abilities just by matching that ID',
      () {
    final json = QdndBundleCodec.classToJson(
        CharacterDataService.getClassById('fighter')!);
    json['features'] = <String, dynamic>{};
    json['rulesMetadata'] = {'edition': '2014', 'origin': 'player'};
    final rules =
        CharacterClassRules.capture(QdndBundleCodec.classFromJson(json));
    expect(rules.atLevel(5, null), isEmpty);
    expect(rules.feature('fighter-extra-attack'), isNull);
  });
  test(
      'Bundle policy preserves mechanics and identity without embedding reference-only source prose',
      () async {
    final data = (await FC5Parser.parseCompendium(
            '<compendium><class><name>Secret Knight</name><hd>12</hd><autolevel level="2"><feature><name>Secret Ward</name><text>REFERENCE_ONLY_PROSE</text></feature></autolevel></class></compendium>',
            sourceId: 'private'))
        .classes
        .single;
    final c = fixtures.hero();
    CharacterClassRules.capture(data).attachTo(c.classes.single);
    final json = QdndBundleCodec.characterToJson(c, exportRules: true);
    expect(json.toString(), isNot(contains('REFERENCE_ONLY_PROSE')));
    final transferred = CharacterClassRules.resolve(
        QdndBundleCodec.characterFromJson(json).classes.single);
    expect(transferred.data.hitDie, 12);
    expect(transferred.data.declares('hitDie'), true);
    expect(transferred.atLevel(2, null).single.nameEn, 'Secret Ward');
    expect(transferred.snapshot['originDigest'],
        c.classes.single.rulesSnapshot!['digest']);
    expect(
        CharacterClassRules.resolve(c.classes.single)
            .atLevel(2, null)
            .single
            .descriptionEn,
        'REFERENCE_ONLY_PROSE');
  });
}

class _LegacyCharacterClassWriter extends TypeAdapter<CharacterClass> {
  @override
  final int typeId = 25;
  @override
  CharacterClass read(BinaryReader reader) =>
      CharacterClassAdapter().read(reader);
  @override
  void write(BinaryWriter writer, CharacterClass obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.level)
      ..writeByte(3)
      ..write(obj.subclass)
      ..writeByte(4)
      ..write(obj.isPrimary);
  }
}
