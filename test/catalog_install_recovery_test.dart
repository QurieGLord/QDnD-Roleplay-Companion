import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/compendium_source.dart';
import 'package:qd_and_d/core/models/item.dart';
import 'package:qd_and_d/core/models/spell.dart';
import 'package:qd_and_d/core/services/catalog_install_journal.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:qd_and_d/core/services/storage_service.dart';

CompendiumSource source(String id) => CompendiumSource(
    id: id,
    name: 'Same displayed book name',
    importedAt: DateTime(2026, 10, 9));
Future<FC5ParseResult> content(String id) => FC5Parser.parseCompendium(
    '''<compendium><item><name>Test Lantern</name><type>G</type><text>A preserved item.</text></item><spell><name>Test Beacon</name><level>1</level><school>V</school><classes>Wizard</classes><text>A preserved rule.</text></spell></compendium>''',
    sourceId: id);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-catalog-recovery-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
  });
  setUp(() async {
    await Hive.box('settings').clear();
    await Hive.box<Item>('items_library').clear();
    await Hive.box<Spell>('spells_library').clear();
    await Hive.box<CompendiumSource>('compendium_sources').clear();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  test(
      'Failure after multiple real box writes restores catalog and leaves a retry possible',
      () async {
    final old = await content('old');
    await StorageService.saveSource(source('old'));
    await StorageService.saveItems(old.items);
    await StorageService.saveSpells(old.spells);
    final incoming = await content('new');
    await expectLater(
        StorageService.installSource(
            source: source('new'),
            fingerprint: 'new-hash',
            items: incoming.items,
            spells: incoming.spells,
            afterWrite: (box) async {
              if (box == 'spells') throw const FileSystemException('No space');
            }),
        throwsA(isA<FileSystemException>()));
    expect(StorageService.getAllSources().map((s) => s.id), ['old']);
    expect(StorageService.getAllItems().map((i) => i.id),
        old.items.map((i) => i.id));
    expect(StorageService.getAllSpells().map((s) => s.id),
        old.spells.map((s) => s.id));
    expect(StorageService.getSourceIdForFingerprint('new-hash'), isNull);
    expect(StorageService.getSetting(CatalogInstallJournal.key), isNull);
    await StorageService.installSource(
        source: source('new'),
        fingerprint: 'new-hash',
        items: incoming.items,
        spells: incoming.spells);
    expect(StorageService.getAllSources(), hasLength(2));
  });
  test(
      'Uncommitted content stays outside public catalog views and publication failure undoes everything',
      () async {
    final incoming = await content('pending');
    await expectLater(
        StorageService.installSource(
            source: source('pending'),
            fingerprint: 'pending-hash',
            items: incoming.items,
            spells: incoming.spells,
            afterWrite: (box) async {
              if (box == 'items') {
                expect(Hive.box<Item>('items_library').values, isNotEmpty);
                expect(StorageService.getAllItems(), isEmpty);
                expect(StorageService.getAllSources(), isEmpty);
              }
              if (box == 'sources') {
                throw const FileSystemException('Commit failed');
              }
            }),
        throwsA(isA<FileSystemException>()));
    expect(StorageService.getAllSources(), isEmpty);
    expect(StorageService.getAllItems(), isEmpty);
    expect(StorageService.getAllSpells(), isEmpty);
    expect(StorageService.getSourceIdForFingerprint('pending-hash'), isNull);
  });
  test(
      'A real restart recovers an interrupted install including an overwritten native value',
      () async {
    final original = await content('old');
    final oldSpell = original.spells.single;
    await StorageService.saveSpells([oldSpell]);
    final incoming = await content('crashed');
    final settings = Hive.box('settings');
    await settings.put(CatalogInstallJournal.key, {
      'version': 1,
      'sourceId': 'crashed',
      'state': 'applying',
      'backup': [
        {
          'box': 'spells',
          'key': oldSpell.id,
          'exists': true,
          'value': oldSpell
        },
        {
          'box': 'items',
          'key': incoming.items.single.id,
          'exists': false,
          'value': null
        },
        {'box': 'sources', 'key': 'crashed', 'exists': false, 'value': null},
      ]
    });
    await settings.flush();
    final changed = Spell.fromJson(oldSpell.toJson())
      ..descriptionEn = 'Interrupted overwrite';
    await Hive.box<Spell>('spells_library').put(oldSpell.id, changed);
    await StorageService.saveItems(incoming.items);
    await StorageService.saveSource(source('crashed'));
    await Hive.close();
    await StorageService.init();
    expect(StorageService.getAllSpells().single.descriptionEn,
        oldSpell.descriptionEn);
    expect(StorageService.getAllItems(), isEmpty);
    expect(StorageService.getAllSources(), isEmpty);
    expect(StorageService.getSetting(CatalogInstallJournal.key), isNull);
  });
  test('Restart cleanup preserves an already committed source', () async {
    final incoming = await content('committed');
    await StorageService.saveItems(incoming.items);
    await StorageService.saveSource(source('committed'));
    await Hive.box('settings').put(CatalogInstallJournal.key, {
      'version': 1,
      'sourceId': 'committed',
      'state': 'committed',
      'backup': [
        {
          'box': 'items',
          'key': incoming.items.single.id,
          'exists': false,
          'value': null
        }
      ]
    });
    await Hive.close();
    await StorageService.init();
    expect(StorageService.getAllItems(), hasLength(1));
    expect(StorageService.getAllSources().single.id, 'committed');
    expect(StorageService.getSetting(CatalogInstallJournal.key), isNull);
  });
  test('A colliding entity ID cannot silently update another installed source',
      () async {
    final existing = await content('existing');
    await StorageService.saveSpells(existing.spells);
    final changed = Spell.fromJson(existing.spells.single.toJson())
      ..sourceId = 'another'
      ..descriptionEn = 'Different mechanics';
    await expectLater(
        StorageService.installSource(
            source: source('another'),
            fingerprint: 'collision',
            spells: [changed]),
        throwsStateError);
    expect(StorageService.getAllSpells().single.descriptionEn,
        existing.spells.single.descriptionEn);
    expect(StorageService.getAllSources(), isEmpty);
  });
  test(
      'Source preflight rejects mixed ownership or repeated IDs before writing',
      () async {
    final incoming = await content('owner');
    await expectLater(
        StorageService.installSource(
            source: source('another'),
            fingerprint: 'wrong-owner',
            spells: incoming.spells),
        throwsArgumentError);
    await expectLater(
        StorageService.installSource(
            source: source('owner'),
            fingerprint: 'repeated-id',
            spells: [...incoming.spells, ...incoming.spells]),
        throwsArgumentError);
    expect(StorageService.getAllSources(), isEmpty);
    expect(StorageService.getAllSpells(), isEmpty);
    expect(StorageService.getSetting(CatalogInstallJournal.key), isNull);
  });
  test(
      'Invalid recovery entries are rejected before any existing value is changed',
      () async {
    final original = await content('original');
    final saved = original.spells.single;
    await StorageService.saveSpells([saved]);
    final record = {
      'version': 1,
      'sourceId': 'broken',
      'state': 'applying',
      'backup': [
        {'box': 'characters', 'key': 'forbidden', 'exists': false},
        {'box': 'spells', 'key': saved.id, 'exists': false},
      ]
    };
    await Hive.box('settings').put(CatalogInstallJournal.key, record);
    final journal = CatalogInstallJournal(
        Hive.box('settings'), {'spells': Hive.box<Spell>('spells_library')});
    await expectLater(journal.recover(), throwsStateError);
    expect(StorageService.getAllSpells().single.id, saved.id);
    expect(StorageService.getSetting(CatalogInstallJournal.key), isNotNull);
  });
  test(
      'The storage queue prevents two direct installs from claiming the same fingerprint',
      () async {
    final first = await content('first');
    final second = await content('second');
    final attempts = await Future.wait([
      StorageService.installSource(
              source: source('first'),
              fingerprint: 'same-hash',
              spells: first.spells)
          .then<Object>((_) => 'installed', onError: (Object e) => e),
      StorageService.installSource(
              source: source('second'),
              fingerprint: 'same-hash',
              spells: second.spells)
          .then<Object>((_) => 'installed', onError: (Object e) => e),
    ]);
    expect(attempts.whereType<String>(), ['installed']);
    expect(attempts.whereType<StateError>(), hasLength(1));
    expect(StorageService.getAllSources(), hasLength(1));
    expect(StorageService.getAllSpells(), hasLength(1));
    expect(StorageService.getSourceIdForFingerprint('same-hash'), 'first');
  });
}
