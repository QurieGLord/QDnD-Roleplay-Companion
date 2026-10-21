import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/progression/character_class_context.dart';
import 'package:qd_and_d/core/progression/character_class_rules.dart';
import 'package:qd_and_d/core/progression/subclass_reference.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/class_reference_actions_service.dart';
import 'package:qd_and_d/core/services/fc5_content_identity_service.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/import_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'journal_service_test.dart' as fixtures;

Character hero(String classId, String subclass) => fixtures.hero()
  ..level = 4
  ..characterClass = classId
  ..subclass = subclass
  ..classes = [
    CharacterClass(
        id: classId,
        name: classId,
        level: 4,
        subclass: subclass,
        isPrimary: true)
  ];
String book(String className, String subclass, String text,
        {String? translatedName, String? translatedText}) =>
    '''
<compendium version="5"><class><name>$className: $subclass</name><hd>10</hd>
${translatedName == null ? '' : '<name_ru>$className: $translatedName</name_ru>'}
<autolevel level="3"><feature><name>Tradition: $subclass</name><text>$text</text>
${translatedText == null ? '' : '<text_ru>$translatedText</text_ru>'}
</feature></autolevel></class></compendium>''';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-subclass-reference-');
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
    for (final s in StorageService.getAllSources()) {
      await StorageService.deleteSource(s.id);
    }
    await Hive.box<Character>('characters').clear();
    await ImportService.reloadImportedContentServices();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('Canonical names are idempotent, bilingual and whitespace tolerant', () {
    for (final name in [
      'Oath of Conquest',
      'oath_of_conquest',
      '  Oath   of Conquest ',
      'Клятва покорения'
    ]) {
      final key = FC5ContentIdentityService.canonicalSubclassName(name);
      expect(key, 'oath of conquest');
      expect(FC5ContentIdentityService.canonicalSubclassName(key), key);
    }
    expect(
        FC5ContentIdentityService.canonicalSubclassName('Circle of the Land'),
        'circle of the land');
  });
  test(
      'Description is extracted from exact title or colon tail, not an arbitrary ability',
      () async {
    final result = await FC5Parser.parseCompendium('''<compendium><class>
<name>Paladin: Oath of Ash</name><hd>10</hd>
<autolevel level="3"><feature><name>Sacred Oath: Oath of Ash</name><text>Introduction.</text><text>Second paragraph.</text></feature>
<feature><name>Oath of Ash: Smite</name><text>A much longer unrelated ability description.</text></feature></autolevel>
<autolevel level="7"><feature><name>Oath of Ash</name><text>A later improvement.</text></feature></autolevel>
</class></compendium>''', sourceId: 'shape');
    expect(result.classes.single.subclasses.single.description['en'],
        'Introduction.\nSecond paragraph.');
  });
  for (final classId in [
    'barbarian',
    'bard',
    'cleric',
    'druid',
    'fighter',
    'monk',
    'paladin',
    'ranger',
    'rogue',
    'sorcerer',
    'warlock',
    'wizard'
  ]) {
    test('$classId reference resolves without acquiring another class rules',
        () async {
      final parsed = await FC5Parser.parseCompendium(
          book(classId, 'Echo Tradition', 'A reference for $classId.'),
          sourceId: 'all-classes');
      final c = hero(classId, 'Echo Tradition');
      final base = CharacterDataService.getClassById(classId)!;
      final before = QdndBundleCodec.characterToJson(c);
      final reference = SubclassReference.resolve(
          entry: c.classes.single,
          subclass: c.subclass!,
          definition: base,
          catalog: parsed.classes);
      expect(reference.description('en'), 'A reference for $classId.');
      expect(QdndBundleCodec.characterToJson(c), before);
    });
  }
  for (final first in [true, false]) {
    test(
        'Library ${first ? 'before' : 'after'} hero: translated reference, unchanged gameplay and restart',
        () async {
      final c = hero('paladin', 'Oath of Conquest')
        ..currentHp = 0
        ..temporaryHp = 7
        ..goldPieces = 450
        ..spellSlots = [6]
        ..maxSpellSlots = [4];
      final before = QdndBundleCodec.characterToJson(c);
      final xml = book('Paladin', 'Oath of Conquest', 'The oath.',
          translatedName: 'Клятва покорения',
          translatedText: 'Описание клятвы.');
      if (first) {
        await ImportService.importCompendiumXmlContentDetailed(xml,
            sourceName: 'Book');
      }
      await StorageService.saveCharacter(c);
      final savedBefore = QdndBundleCodec.characterToJson(c);
      if (!first) {
        await ImportService.importCompendiumXmlContentDetailed(xml,
            sourceName: 'Book');
      }
      final context = CharacterClassContext(c, 'paladin');
      expect(context.subclassName('ru'), 'Клятва покорения');
      expect(context.subclassReference!.description('ru'), 'Описание клятвы.');
      expect(c.currentHp, before['currentHp']);
      expect(c.spellSlots, [6]);
      expect(QdndBundleCodec.characterToJson(c), savedBefore);
      await Hive.box<Character>('characters').flush();
      await Hive.box<Character>('characters').close();
      final reopened = await Hive.openBox<Character>('characters');
      final restored = reopened.get(c.id)!;
      expect(CharacterClassContext(restored, 'paladin').subclassName('ru'),
          'Клятва покорения');
      // StorageService keeps its original box reference; reopen all service boxes.
      await StorageService.init();
    });
  }
  test(
      'Conflicting books require a choice; identical definitions are one candidate',
      () async {
    final c = hero('paladin', 'Oath of Ash');
    final one = await FC5Parser.parseCompendium(
        book('Paladin', 'Oath of Ash', 'First text.'),
        sourceId: 'one');
    final same = await FC5Parser.parseCompendium(
        book('Paladin', 'Oath of Ash', 'First text.'),
        sourceId: 'same');
    final two = await FC5Parser.parseCompendium(
        book('Paladin', 'Oath of Ash', 'Other text.'),
        sourceId: 'two');
    SubclassReference resolve(List<ClassData> catalog) =>
        SubclassReference.resolve(
            entry: c.classes.single,
            subclass: c.subclass!,
            definition: CharacterDataService.getClassById('paladin'),
            catalog: catalog);
    expect(resolve([...one.classes, ...same.classes]).candidates, hasLength(1));
    final ambiguous = resolve([...two.classes, ...one.classes]);
    expect(ambiguous.ambiguous, isTrue);
    expect(ambiguous.description('en'), isEmpty);
    c.classes.single.referenceData =
        ambiguous.candidates.first.selection(c.subclass!);
    final copy = QdndBundleCodec.cloneCharacter(c);
    expect(copy.classes.single.referenceData, c.classes.single.referenceData);
    expect(resolve([...two.classes, ...one.classes]).selected, isNotNull);
    expect(resolve([]).selectionMissing, isTrue);
    expect(resolve([]).description('en'), isEmpty);
  });
  test('Explicit 2024 book is not used for 2014 presentation', () async {
    final parsed = await FC5Parser.parseCompendium(
        book('Paladin', 'Oath of Ash', 'Other edition.'),
        sourceId: 'foreign');
    final data = QdndBundleCodec.classToJson(parsed.classes.single);
    data['rulesMetadata'] = {'edition': '2024'};
    final c = hero('paladin', 'Oath of Ash');
    final ref = SubclassReference.resolve(
        entry: c.classes.single,
        subclass: c.subclass!,
        definition: CharacterDataService.getClassById('paladin'),
        catalog: [ClassData.fromJson(data)]);
    expect(ref.selected, isNull);
  });
  test(
      'Saved source owns reference; damaged snapshot does not borrow live rules',
      () async {
    final parsed = await FC5Parser.parseCompendium(
        book('Paladin', 'Oath of Ash', 'Saved personal text.'),
        sourceId: 'own');
    final c = hero('paladin', 'Oath of Ash');
    CharacterClassRules.capture(parsed.classes.single)
        .attachTo(c.classes.single);
    expect(
        CharacterClassContext(c, 'paladin')
            .subclassReference!
            .description('en'),
        'Saved personal text.');
    c.classes.single.rulesSnapshot!['digest'] = 'broken';
    expect(CharacterClassContext(c, 'paladin').subclassReference, isNull);
  });
  test(
      'Explicit reference choice rolls back on a failed save and queue remains usable',
      () async {
    await ImportService.importCompendiumXmlContentDetailed(
        book('Paladin', 'Oath of Ash', 'A text.'),
        sourceName: 'Reference');
    final c = hero('paladin', 'Oath of Ash');
    final candidate = CharacterClassContext(c, 'paladin')
        .subclassReference!
        .candidates
        .single;
    final before = QdndBundleCodec.characterToJson(c);
    await expectLater(
        ClassReferenceActionsService.select(c, 'paladin', candidate.signature,
            write: (_) async {
          throw StateError('disk');
        }),
        throwsStateError);
    expect(QdndBundleCodec.characterToJson(c), before);
    await ClassReferenceActionsService.select(
        c, 'paladin', candidate.signature);
    expect(
        StorageService.getCharacter(c.id)!
            .classes
            .single
            .referenceData['signature'],
        candidate.signature);
  });
  test(
      'Community subclass conventions preserve nested choices and meaningful parentheses',
      () async {
    final parsed = await FC5Parser.parseCompendium(
        '''<compendium><class><name>Fighter</name><hd>10</hd>
<autolevel level="3"><feature optional="YES"><name>Martial Archetype: Champion</name><text>Introduction.</text></feature>
<feature optional="YES"><name>Improved Critical (Champion)</name><text>Critical rule.</text></feature>
<feature optional="YES"><name>Fighting Style: Archery (Champion)</name><text>Choose a style.</text></feature>
<feature><name>Aura (Sea)</name><text>Sea rule.</text></feature>
<feature><name>Aura (Tundra)</name><text>Tundra rule.</text></feature>
</autolevel></class></compendium>''',
        sourceId: 'community');
    expect(parsed.diagnostics.hasErrors, isFalse);
    final cls = parsed.classes.single;
    expect(cls.subclasses.single.getName('en'), 'Champion');
    final features = cls.features[3]!;
    expect(
        features
            .firstWhere((f) => f.nameEn.startsWith('Improved Critical'))
            .isOptional,
        isFalse);
    expect(
        features
            .firstWhere((f) => f.nameEn.startsWith('Fighting Style'))
            .isOptional,
        isTrue);
    expect(features.where((f) => f.nameEn.startsWith('Aura')), hasLength(2));
    expect(features.map((f) => f.id).toSet(), hasLength(features.length));
    expect(CharacterClassRules.capture(cls).data.features[3],
        hasLength(features.length));
  });
  test('Missing namespaced class does not substitute the core class', () {
    final c = hero('deleted-book-class', 'Unknown class');
    c.classes.single.name = 'Paladin';
    expect(CharacterClassContext(c, 'paladin').definition, isNull);
    expect(CharacterClassContext(c, 'paladin').level, 4);
  });

  test(
      'Already installed old book is read from retained XML without replacing mechanics or saving the hero',
      () async {
    final imported = await ImportService.importCompendiumXmlContentDetailed(
        book('Paladin', 'Oath of Ash', 'Retained description.',
            translatedName: 'Клятва пепла',
            translatedText: 'Сохранённое описание.'),
        sourceName: 'Old book');
    final stored = StorageService.getAllClasses().single;
    final old = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(QdndBundleCodec.classToJson(stored))) as Map);
    (old['rulesMetadata'] as Map).remove('referenceAdapterVersion');
    old['subclasses'] = [
      for (final sub in stored.subclasses)
        {
          'id': sub.id,
          'name': {'en': 'Oath of Ash', 'ru': 'Oath of Ash'},
          'description': {'en': 'Subclass of Paladin', 'ru': 'Подкласс Паладин'}
        }
    ];
    final legacy = ClassData.fromJson(old);
    await StorageService.saveClasses([legacy]);
    final c = hero('paladin', 'Oath of Ash');
    await StorageService.saveCharacter(c);
    final baseline = QdndBundleCodec.characterToJson(c);
    await ImportService.reloadImportedContentServices();
    final context = CharacterClassContext(c, 'paladin');
    expect(context.subclassName('ru'), 'Клятва пепла');
    expect(
        context.subclassReference!.description('ru'), 'Сохранённое описание.');
    expect(QdndBundleCodec.classToJson(StorageService.getAllClasses().single),
        old);
    expect(QdndBundleCodec.characterToJson(c), baseline);
    await StorageService.deleteSource(imported.sourceId);
    await ImportService.reloadImportedContentServices();
    expect(context.subclassReference!.description('ru'), isEmpty);
    expect(QdndBundleCodec.characterToJson(c), baseline);
  });
  test(
      'Full subclass-specific class nodes do not acquire their subclass at their first base feature',
      () async {
    final parsed = await FC5Parser.parseCompendium(
        '''<compendium><class><name>Paladin: Oath of Ash</name><hd>10</hd>
<autolevel level="1"><feature><name>Base training</name><text>Base class.</text></feature></autolevel>
<autolevel level="3"><feature><name>Sacred Oath: Oath of Ash</name><text>Subclass introduction.</text></feature>
<feature optional="YES"><name>Sacred Oath: Oath of Dawn</name><text>A contradictory source label must not create another subclass.</text></feature></autolevel>
</class></compendium>''',
        sourceId: 'full-subclass');
    expect(parsed.classes.single.subclassLevel, 3);
    expect(parsed.classes.single.subclasses, hasLength(1));
  });
  test(
      'Historical library without XML recovers paired translation and intro from stored features only',
      () async {
    final imported = await ImportService.importCompendiumXmlContentDetailed(
        book('Paladin', 'Oath of Ash', 'Retained English.',
            translatedName: 'Клятва пепла',
            translatedText: 'Ранее сохранённый текст.'),
        sourceName: 'Historical book');
    final stored = StorageService.getAllClasses().single;
    final data = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(QdndBundleCodec.classToJson(stored))) as Map);
    data['sourceDefinition'] = null;
    data['rulesMetadata'] = {};
    data['subclasses'] = [
      for (final sub in stored.subclasses)
        {
          'id': sub.id,
          'name': {'en': 'Oath of Ash', 'ru': 'Oath of Ash'},
          'description': {'en': 'Subclass of Paladin', 'ru': 'Подкласс Паладин'}
        }
    ];
    (((data['features'] as Map)['3'] as List).first as Map)['nameRu'] =
        'Традиция: Клятва пепла';
    await StorageService.saveClasses([ClassData.fromJson(data)]);
    final c = hero('paladin', 'Oath of Ash');
    await StorageService.saveCharacter(c);
    final baseline = QdndBundleCodec.characterToJson(c);
    await ImportService.reloadImportedContentServices();
    expect(
        CharacterClassContext(c, 'paladin').subclassName('ru'), 'Клятва пепла');
    expect(
        CharacterClassContext(c, 'paladin')
            .subclassReference!
            .description('ru'),
        'Ранее сохранённый текст.');
    expect(QdndBundleCodec.characterToJson(c), baseline);
    expect(QdndBundleCodec.classToJson(StorageService.getAllClasses().single),
        data);
    await Hive.close();
    await StorageService.init();
    await ImportService.reloadImportedContentServices();
    final reopened = StorageService.getCharacter(c.id)!;
    expect(
        CharacterClassContext(reopened, 'paladin')
            .subclassReference!
            .description('ru'),
        'Ранее сохранённый текст.');
    final normalized = Map<String, dynamic>.from(baseline);
    for (final key in ['createdAt', 'updatedAt']) {
      final v = DateTime.parse(normalized[key] as String);
      normalized[key] = DateTime.fromMillisecondsSinceEpoch(
              v.millisecondsSinceEpoch,
              isUtc: v.isUtc)
          .toIso8601String();
    }
    expect(QdndBundleCodec.characterToJson(reopened), normalized);
    await StorageService.deleteSource(imported.sourceId);
  });
  test('An empty translation is not a match for every subclass', () async {
    final parsed = await FC5Parser.parseCompendium(
        book('Paladin', 'Oath of Ash', 'Only Ash.'),
        sourceId: 'empty-translation');
    final data = QdndBundleCodec.classToJson(parsed.classes.single);
    ((data['subclasses'] as List).single as Map)['name'] = {
      'en': 'Oath of Ash',
      'ru': ''
    };
    final c = hero('paladin', 'Oath of Other');
    final ref = SubclassReference.resolve(
        entry: c.classes.single,
        subclass: c.subclass!,
        definition: CharacterDataService.getClassById('paladin'),
        catalog: [ClassData.fromJson(data)]);
    expect(ref.candidates, isEmpty);
  });
  test(
      'A personal source removed/reimported with another ID offers reference choice without replacing rules',
      () async {
    final parsed = await FC5Parser.parseCompendium(
        book('Paladin', 'Oath of Ash', 'Old text.'),
        sourceId: 'old-bound-source');
    final data = QdndBundleCodec.classToJson(parsed.classes.single);
    data['features'] = {};
    data['sourceDefinition'] = null;
    for (final sub in data['subclasses'] as List) {
      (sub as Map)['description'] = {
        'en': 'Subclass of Paladin',
        'ru': 'Подкласс Паладин'
      };
    }
    final c = hero('paladin', 'Oath of Ash');
    CharacterClassRules.capture(ClassData.fromJson(data))
        .attachTo(c.classes.single);
    final snapshot = jsonEncode(c.classes.single.rulesSnapshot);
    await ImportService.importCompendiumXmlContentDetailed(
        book('Paladin', 'Oath of Ash', 'New source text.'),
        sourceName: 'Reimported book');
    final before = CharacterClassContext(c, 'paladin').subclassReference!;
    expect(before.requiresChoice, isTrue);
    expect(before.description('en'), isEmpty);
    await ClassReferenceActionsService.select(
        c, 'paladin', before.candidates.single.signature);
    expect(
        CharacterClassContext(c, 'paladin')
            .subclassReference!
            .description('en'),
        'New source text.');
    expect(jsonEncode(c.classes.single.rulesSnapshot), snapshot);
  });
}
