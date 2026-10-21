// Explicit, local-only corpus check. Run with flutter test and environment
// QDND_PUBLIC_FC5_CORPUS and/or QDND_PRIVATE_FC5_CORPUS. No corpus is committed.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/progression/character_class_context.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/fc5_compendium_zip_service.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:qd_and_d/core/services/fc5_content_identity_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/import_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory store;
  final report = <String, dynamic>{};
  final publicRoot = Platform.environment['QDND_PUBLIC_FC5_CORPUS'];
  final privateRoot = Platform.environment['QDND_PRIVATE_FC5_CORPUS'];
  setUpAll(() async {
    store = await Directory.systemTemp.createTemp('qdnd-fc5-corpus-store-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => store.path);
    await StorageService.init();
    await FeatureService.init();
    await ItemService.loadItems();
    await SpellService.loadSpells();
    await CharacterDataService.loadAllData();
  });
  tearDownAll(() async {
    await Hive.close();
    await store.delete(recursive: true);
    final output = Platform.environment['QDND_FC5_REPORT'];
    if (output != null) {
      File(output).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(report));
    }
  });
  test('Independent public compendiums: parsed counts and diagnostics',
      () async {
    expect(publicRoot, isNotNull);
    final entries = <Map<String, dynamic>>[];
    for (final file in Directory(publicRoot!)
        .listSync(recursive: true)
        .whereType<File>()
        .where(
            (f) => f.path.endsWith('.xml') && f.path.contains('/Sources/'))) {
      final xml = await file.readAsString();
      if (!xml.contains('<compendium')) {
        continue; // Manifests are tested separately.
      }
      final result =
          await FC5Parser.parseCompendium(xml, sourceId: 'public-probe');
      entries.add({
        'file': file.path.substring(publicRoot.length + 1),
        'items': result.items.length,
        'spells': result.spells.length,
        'classes': result.classes.length,
        'subclasses':
            result.classes.fold<int>(0, (n, c) => n + c.subclasses.length),
        'features': result.classes.fold<int>(
            0, (n, c) => n + c.features.values.expand((v) => v).length),
        'errors': result.diagnostics.entries
            .where((d) => d.severity == FC5DiagnosticSeverity.error)
            .map((d) => d.code)
            .toList(),
        'warnings': result.diagnostics.entries
            .where((d) => d.severity == FC5DiagnosticSeverity.warning)
            .map((d) => d.code)
            .toSet()
            .toList()
      });
      expect(result.isEmpty, isFalse, reason: file.path);
      if (file.path.contains('/class-') || file.path.endsWith('/all-srd.xml')) {
        expect(result.classes.every((c) => c.subclasses.isNotEmpty), isTrue,
            reason: file.path);
      }
      expect(result.diagnostics.hasErrors, isFalse, reason: file.path);
    }
    report['public'] = entries;
    expect(entries.length, greaterThanOrEqualTo(15));
  }, skip: publicRoot == null ? 'Set QDND_PUBLIC_FC5_CORPUS to run.' : false);

  test('All private archive modules are scanned without copying content',
      () async {
    final archive = Directory(privateRoot!)
        .listSync()
        .whereType<File>()
        .singleWhere((f) => f.path.endsWith('.zip'));
    final preview = await FC5CompendiumZipService.previewFile(archive);
    final modules = <Map<String, dynamic>>[];
    for (final entry in preview.entries) {
      final xml =
          await FC5CompendiumZipService.readXmlEntry(archive, entry.rawPath);
      final parsed =
          await FC5Parser.parseCompendium(xml, sourceId: 'private-module');
      final checked =
          FC5CompendiumDeduplicationService.dedupe(parsed).parseResult;
      modules.add({
        'index': modules.length + 1,
        'previewImportable': entry.canImport,
        'supported': checked.supportedEntityCount,
        'errors': checked.diagnostics.entries
            .where((d) => d.severity == FC5DiagnosticSeverity.error)
            .map((d) => d.code)
            .toList(),
        'warnings': checked.diagnostics.entries
            .where((d) => d.severity == FC5DiagnosticSeverity.warning)
            .map((d) => d.code)
            .toSet()
            .toList()
      });
    }
    report['private-modules'] = modules;
    expect(modules, hasLength(34));
    expect(modules.where((m) => (m['errors'] as List).isNotEmpty), isEmpty);
  }, skip: privateRoot == null ? 'Set QDND_PRIVATE_FC5_CORPUS to run.' : false);
  for (final libraryFirst in [false, true]) {
    test(
        'Private regression: library ${libraryFirst ? 'before' : 'after'} character',
        () async {
      expect(privateRoot, isNotNull);
      for (final s in StorageService.getAllSources()) {
        await StorageService.deleteSource(s.id);
      }
      await Hive.box<Character>('characters').clear();
      await ImportService.reloadImportedContentServices();
      final dir = Directory(privateRoot!);
      final archive = dir
          .listSync()
          .whereType<File>()
          .singleWhere((f) => f.path.endsWith('.zip'));
      final characterFile = dir
          .listSync()
          .whereType<File>()
          .singleWhere((f) => f.path.endsWith('.xml'));
      final preview = await FC5CompendiumZipService.previewFile(archive);
      final module = preview.suggestedEntry!;
      final xml =
          await FC5CompendiumZipService.readXmlEntry(archive, module.rawPath);
      final parsed =
          await FC5Parser.parseCompendium(xml, sourceId: 'private-shape');
      report['private-source-diagnostics'] = {
        'moduleSupported': module.supportedCount,
        'errors': FC5CompendiumDeduplicationService.dedupe(parsed)
            .parseResult
            .diagnostics
            .entries
            .where((d) => d.severity == FC5DiagnosticSeverity.error)
            .map((d) => {'code': d.code, 'context': d.context})
            .toList()
      };
      Future<void> install() async {
        await ImportService.importCompendiumXmlContentDetailed(xml,
            sourceName: 'Private test source');
      }

      if (libraryFirst) {
        await install();
      }
      final result =
          await ImportService.importCharactersFromFC5File(characterFile);
      final character = result.characters.single;
      final saved = QdndBundleCodec.characterToJson(character);
      if (!libraryFirst) {
        await install();
      }
      final after = QdndBundleCodec.characterToJson(character);
      Map<String, dynamic> sessionState(Map<String, dynamic> state) =>
          Map.of(state)
            ..removeWhere((key, _) => {
                  'updatedAt',
                  'knownSpells',
                  'preparedSpells',
                  'spellMasterySpells',
                  'signatureSpells',
                  'signatureSpellsUsed',
                  'concentratingOn',
                  'spellbookData',
                  'advancementData'
                }.contains(key));
      final owner = CharacterClassContext(character, 'paladin');
      final reference = owner.subclassReference!;
      report['private-${libraryFirst ? 'book-first' : 'hero-first'}'] = {
        'archiveXmlModules': preview.entries.length,
        'suggestedSupported': module.supportedCount,
        'classes': parsed.classes.length,
        'subclasses':
            parsed.classes.fold<int>(0, (n, c) => n + c.subclasses.length),
        'hasRussianSubclassName':
            RegExp('[А-Яа-я]').hasMatch(owner.subclassName('ru') ?? ''),
        'descriptionCharacters': reference.description('ru').length,
        'ambiguous': reference.ambiguous,
        'characterDiagnostics':
            result.diagnostics.entries.map((d) => d.code).toSet().toList(),
        'gameplayUnchanged': const DeepCollectionEqualityForProbe()
            .same(sessionState(saved), sessionState(after)),
        'knownSpellCountPreserved': (saved['knownSpells'] as List).length ==
            character.knownSpells.length,
        'unresolvedSpellCount': character.knownSpells
            .where((id) => SpellService.getSpellById(id) == null)
            .length,
      };
      expect(reference.ambiguous, isFalse);
      expect(owner.subclassName('ru'), contains('покорения'));
      expect(reference.description('ru').length, greaterThan(100));
      expect(sessionState(after), sessionState(saved));
      expect(
          character.knownSpells.length, (saved['knownSpells'] as List).length);
      expect(character.preparedSpells.length,
          (saved['preparedSpells'] as List).length);
      final references =
          character.spellbookData['contentReferences'] as Map? ?? {};
      for (final old in saved['knownSpells'] as List) {
        if (character.knownSpells.contains(old)) continue;
        final replacements = references.entries.where((e) =>
            e.value is Map &&
            ((e.value as Map)['originalIds'] as List? ?? []).contains(old));
        expect(replacements, hasLength(1));
        expect(character.knownSpells, contains(replacements.single.key));
        expect(SpellService.getSpellById(replacements.single.key as String),
            isNotNull);
      }
    },
        skip: privateRoot == null
            ? 'Set QDND_PRIVATE_FC5_CORPUS to run.'
            : false);
  }
}

class DeepCollectionEqualityForProbe {
  const DeepCollectionEqualityForProbe();
  bool same(Object a, Object b) => jsonEncode(a) == jsonEncode(b);
}
