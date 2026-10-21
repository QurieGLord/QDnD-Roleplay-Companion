// End-to-end overlap probe. Only metadata is written; no book or hero is copied
// into the repository. Uses a disposable Hive store and the actual import path.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/content/content_catalog.dart';
import 'package:qd_and_d/core/content/content_reference_repair.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/import_service.dart';
import 'package:qd_and_d/core/services/fc5_compendium_zip_service.dart';
import 'package:qd_and_d/core/services/fc5_content_identity_service.dart';
import 'package:qd_and_d/core/services/catalog_definition_signature.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory store;
  final input = Platform.environment['QDND_PRIVATE_FC5_CORPUS'];
  setUpAll(() async {
    store = await Directory.systemTemp.createTemp('qdnd-overlap-probe-');
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
  test(
      'Whole archive installed together: overlap and saved-hero reference report',
      () async {
    final dir = Directory(input!),
        archive = dir
            .listSync()
            .whereType<File>()
            .singleWhere((f) => f.path.endsWith('.zip'));
    final heroFileBefore = dir
        .listSync()
        .whereType<File>()
        .singleWhere((f) => f.path.endsWith('.xml'));
    final savedBefore =
        (await ImportService.importCharactersFromFC5File(heroFileBefore))
            .characters
            .single;
    final missingBefore = savedBefore.knownSpells
        .where((id) => SpellService.getSpellById(id) == null)
        .toList();
    final preview = await FC5CompendiumZipService.previewFile(archive),
        modules = <Map<String, dynamic>>[];
    for (final entry in preview.entries) {
      if (!entry.canImport) continue;
      final xml =
          await FC5CompendiumZipService.readXmlEntry(archive, entry.rawPath);
      try {
        final result = await ImportService.importCompendiumXmlContentDetailed(
            xml,
            sourceName: entry.rawPath);
        modules.add({
          'index': modules.length + 1,
          'imported': true,
          'spells': result.parseResult.spells.length,
          'classes': result.parseResult.classes.length
        });
      } on ImportServiceException catch (e) {
        modules.add({
          'index': modules.length + 1,
          'imported': false,
          'diagnostics':
              e.diagnostics.entries.map((d) => d.code).toSet().toList()
        });
      }
    }
    final classGroups = <String, List<String>>{};
    for (final c in CharacterDataService.getAllClasses()) {
      classGroups
          .putIfAbsent(
              FC5ContentIdentityService.classIdFromClassData(c), () => [])
          .add(c.id);
    }
    final spellGroups = <String, List<Map<String, dynamic>>>{};
    for (final s in SpellService.getAllSpells()) {
      final key = '${s.getName('ru').toLowerCase().trim()}|${s.level}';
      spellGroups.putIfAbsent(key, () => []).add({
        'id': s.id,
        'sourceId': s.sourceId,
        'signature': CatalogDefinitionSignature.of(s.toJson())
      });
    }
    final duplicateSpellGroups =
        spellGroups.values.where((g) => g.length > 1).toList();
    final heroFile = dir
        .listSync()
        .whereType<File>()
        .singleWhere((f) => f.path.endsWith('.xml'));
    final imported = await ImportService.importCharactersFromFC5File(heroFile),
        hero = imported.characters.single;
    final missing = hero.knownSpells
        .where((id) => SpellService.getSpellById(id) == null)
        .toList();
    final spellIndex =
        ContentCatalog(SpellService.getAllSpells().map(ContentRecords.spell));
    final missingAfter = savedBefore.knownSpells
        .where((id) => SpellService.getSpellById(id) == null)
        .toList();
    final restored =
        await ContentReferenceRepair.repair(savedBefore, catalog: spellIndex);
    final stillMissing = savedBefore.knownSpells
        .where((id) => SpellService.getSpellById(id) == null)
        .length;
    expect(stillMissing, 0,
        reason:
            'Installing all books must restore the saved pre-book hero without reimport.');
    final report = {
      'heroBeforeMissingInitially': missingBefore.length,
      'explicitFinalRepairs': restored,
      'heroBeforeMissingAfterRepair': stillMissing,
      'heroBeforeMissingAfterAllBooks': missingAfter.length,
      'heroBeforeMissingReferences': [
        for (final id in missingAfter)
          {
            'id': id,
            'candidates': spellIndex.candidates(id).length,
            'unambiguousDefinition':
                spellIndex.unambiguousDefinition(id) != null
          }
      ],
      'spellFamilyCount': spellIndex.families.length,
      'spellVariantCount':
          spellIndex.families.fold<int>(0, (n, f) => n + f.variants.length),
      'modules': modules,
      'installedSources': StorageService.getAllSources().length,
      'classRows': CharacterDataService.getAllClasses().length,
      'classFamilyCounts': {
        for (final e in classGroups.entries) e.key: e.value.length
      },
      'spellRows': SpellService.getAllSpells().length,
      'spellOverlappingNameGroups': duplicateSpellGroups.length,
      'spellExactRepeatedDefinitionGroups': duplicateSpellGroups
          .where((g) => g.map((e) => e['signature']).toSet().length < g.length)
          .length,
      'heroKnownCount': hero.knownSpells.length,
      'heroMissingSpellCount': missing.length,
      'heroMissingSpellIds': missing
    };
    final output = Platform.environment['QDND_OVERLAP_REPORT'];
    if (output != null)
      File(output).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(report));
    expect(modules.any((m) => m['imported'] == true), true);
  },
      skip: input == null ? 'Set QDND_PRIVATE_FC5_CORPUS to run.' : false,
      timeout: const Timeout(Duration(minutes: 12)));
}
