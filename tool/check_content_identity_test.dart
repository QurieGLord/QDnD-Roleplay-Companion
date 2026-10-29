// C01 probe on the whole private archive: the identity registry is built over
// every installed book, survives a rebuild unchanged, and keeps resolving the
// variants of a removed module. Only counts are written; no book or hero is
// copied into the repository. Uses a disposable Hive store and the real import.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/content/content_catalog.dart';
import 'package:qd_and_d/core/content/content_identity.dart';
import 'package:qd_and_d/core/content/shelf_choices.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/fc5_compendium_zip_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/import_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory store;
  final input = Platform.environment['QDND_PRIVATE_FC5_CORPUS'];
  setUpAll(() async {
    store = await Directory.systemTemp.createTemp('qdnd-identity-probe-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => store.path);
    await StorageService.init();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await ItemService.loadItems();
    await SpellService.loadSpells();
  });
  tearDownAll(() async {
    await Hive.close();
    await store.delete(recursive: true);
  });

  test('Identity registry over the whole archive', () async {
    final archive = Directory(input!)
        .listSync()
        .whereType<File>()
        .singleWhere((f) => f.path.endsWith('.zip'));
    final preview = await FC5CompendiumZipService.previewFile(archive);
    for (final entry in preview.entries) {
      if (!entry.canImport) continue;
      final xml =
          await FC5CompendiumZipService.readXmlEntry(archive, entry.rawPath);
      try {
        await ImportService.importCompendiumXmlContentDetailed(xml,
            sourceName: entry.rawPath);
      } on ImportServiceException {
        // A module the importer refuses is simply absent, as in the app.
      }
    }

    // C02 · the author's hero, saved after the books: its inventory links on
    // the next refresh where a copy is an exact book definition.
    final heroFile = Directory(input)
        .listSync()
        .whereType<File>()
        .singleWhere((f) => f.path.endsWith('.xml'));
    final heroImport =
        await ImportService.importCharactersFromFC5File(heroFile);
    final hero = heroImport.characters.single;
    // C03 · what the reconciliation step lists for this hero.
    final ambiguous = heroImport.ambiguities[hero.id] ?? const [];
    final heroSpellsResolved = hero.knownSpells
        .where((id) => SpellService.getSpellById(id) != null)
        .length;
    await StorageService.saveCharacter(hero);

    // Every module import has already reconciled; this is the launch path.
    final watch = Stopwatch()..start();
    await ContentIdentityService.refresh();
    final first = watch.elapsedMilliseconds;
    final registry = ContentIdentityService.current;
    final savedHero = StorageService.getCharacter(hero.id)!;
    final heroItems = [
      savedHero.inventory.length,
      savedHero.inventory.where((i) => i.variantId != null).length,
      savedHero.inventory.where((i) => i.familyId != null).length,
    ];
    final stored = StorageService.getSetting(ContentIdentityService.storageKey);
    final spells =
        ContentCatalog(SpellService.getAllSpells().map(ContentRecords.spell));
    final spellFamilies = registry.liveFamiliesOf(ContentKind.spell);

    // C04 · what the Prologue lists: rows on the shelf, cards after grouping,
    // and how many of those cards ask for a version.
    List<int> shelf<T>(List<T> rows, ContentRecord<T> Function(T) record) {
      final choices = shelfChoices(rows, record);
      return [
        rows.length,
        choices.length,
        choices.where((c) => c.hasVersions).length
      ];
    }

    final prologue = {
      'races': shelf(CharacterDataService.shelfRaces(), ContentRecords.race),
      'classes': shelf(
          CharacterDataService.getAllClasses(), ContentRecords.characterClass),
      'backgrounds': shelf(
          CharacterDataService.shelfBackgrounds(), ContentRecords.background),
    };

    // A rebuild of the same libraries changes nothing.
    final before = jsonEncode(registry.toJson());
    watch.reset();
    await ContentIdentityService.refresh();
    final second = watch.elapsedMilliseconds;
    expect(jsonEncode(ContentIdentityService.current.toJson()), before);

    // Removing a module keeps its variants resolvable.
    final itemsBefore = ItemService.getAllItems().length;
    final source = StorageService.getAllSources()
        .firstWhere((s) => SpellService.getAllSpells().any((x) => x.sourceId == s.id));
    final removedSpells =
        SpellService.getAllSpells().where((s) => s.sourceId == source.id).toList();
    final familiesBefore = {
      for (final s in removedSpells)
        s.id: ContentIdentityService.current
            .familyOfRecord(ContentKind.spell, s.sourceId, s.id)
    };
    await StorageService.deleteSource(source.id);
    await SpellService.reload();
    await ItemService.reload();
    await CharacterDataService.reload();
    await ContentIdentityService.refresh();
    final after = ContentIdentityService.current;
    final unresolved = familiesBefore.entries
        .where((e) =>
            after.familyOfRecord(ContentKind.spell, source.id, e.key) == null)
        .length;
    expect(unresolved, 0);

    final report = {
      'sources': StorageService.getAllSources().length + 1,
      'spellRows': spells.records.length,
      'spellCatalogFamilies': spells.families.length,
      'spellCatalogVariants':
          spells.families.fold<int>(0, (n, f) => n + f.variants.length),
      'spellRegistryFamilies': spellFamilies,
      'liveFamiliesAllKinds': registry.liveFamilies,
      'variantsAllKinds': registry.variantCount,
      'storedBytes': (stored as String).length,
      'prologueRowsCardsVersioned': prologue,
      'heroItemsAllLinkedWithFamily': heroItems,
      'heroSpellsKnownResolved': [hero.knownSpells.length, heroSpellsResolved],
      'heroAmbiguities': {
        for (final kind in ambiguous.map((a) => a.kind.name).toSet())
          kind: [
            for (final a in ambiguous.where((a) => a.kind.name == kind))
              a.family.variants.length
          ]
      },
      'firstRefreshMs': first,
      'secondRefreshMs': second,
      'removedSpells': removedSpells.length,
      'itemsBeforeAfterRemoval': [itemsBefore, ItemService.getAllItems().length],
      'journalByOpAndKind': {
        for (final op in after.journal.map((j) => j['op']).toSet())
          op: {
            for (final kind in after.journal
                .where((j) => j['op'] == op)
                .map((j) => j['kind'])
                .toSet())
              kind: after.journal
                  .where((j) => j['op'] == op && j['kind'] == kind)
                  .length
          }
      },
    };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
    expect(spellFamilies, spells.families.length);
  },
      skip: input == null ? 'Set QDND_PRIVATE_FC5_CORPUS to run.' : false,
      timeout: const Timeout(Duration(minutes: 12)));
}
