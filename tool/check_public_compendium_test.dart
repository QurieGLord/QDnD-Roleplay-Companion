// Probe for compendiums found in the wild: imports each .xml exactly as the
// library's «Импорт» button does (no edits to the files), then reports what
// the app made of them — parsed rows, diagnostics, concepts and versions per
// kind, the Prologue shelf, and names that look like one concept split in
// two. Opt-in; the files stay outside the repository:
// QDND_FC5_COMPENDIUMS='/a.xml|/b.xml' [QDND_FC5_HERO=/hero.xml]
//   flutter test --no-pub tool/check_public_compendium_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/content/content_catalog.dart';
import 'package:qd_and_d/core/content/content_identity.dart';
import 'package:qd_and_d/core/content/shelf_choices.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/import_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory store;
  final input = Platform.environment['QDND_FC5_COMPENDIUMS'];
  final heroPath = switch (Platform.environment['QDND_FC5_HERO']) {
    '' => null,
    final p => p,
  };
  setUpAll(() async {
    store = await Directory.systemTemp.createTemp('qdnd-public-probe-');
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

  test('Public compendiums, imported as found', () async {
    // What the built-in classes look like before any book is on the shelf.
    Map<String, List<int>> builtIn() => {
          for (final c in CharacterDataService.getAllClasses()
              .where((c) => c.sourceId == null))
            c.id: [
              c.features.values.fold<int>(0, (n, row) => n + row.length),
              c.subclasses.length
            ]
        };
    final builtInBefore = builtIn();
    final imports = <String, Object>{};
    for (final path in input!.split('|')) {
      final file = File(path);
      final name = file.uri.pathSegments.last;
      final watch = Stopwatch()..start();
      try {
        final result = await ImportService.importCompendiumFileDetailed(file);
        final p = result.parseResult;
        final codes = <String, int>{};
        for (final d in p.diagnostics.entries) {
          final key = '${d.severity.name}:${d.code}';
          codes[key] = (codes[key] ?? 0) + 1;
        }
        imports[name] = {
          'ms': watch.elapsedMilliseconds,
          'parsed': {
            'items': p.items.length,
            'spells': p.spells.length,
            'races': p.races.length,
            'classes': p.classes.length,
            'backgrounds': p.backgrounds.length,
            'feats': p.feats.length,
          },
          'diagnostics': codes,
          'diagnosticSamples': [
            for (final d in p.diagnostics.entries
                .where((d) => d.severity.name != 'info')
                .take(6))
              '${d.code}: ${d.message} ${d.context ?? ''}'.trim()
          ],
        };
      } catch (e) {
        imports[name] = {'failed': '$e'};
      }
    }
    await ContentIdentityService.refresh();

    String nameOf(ContentRecord r) => (r.entity as dynamic).getName('en');
    // One concept split in two: family names equal once a bracketed tag,
    // a parenthetical and the edition words are dropped.
    String loose(String n) => ContentRecord.normalize(n
        .replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\b(2014|2024|legacy|5\.5e|5e)\b',
            caseSensitive: false), ' '));
    Map<String, Object> kind<T>(
        List<T> rows, ContentRecord<T> Function(T) record) {
      final catalog = ContentCatalog(rows.map(record));
      final versioned =
          catalog.families.where((f) => f.variants.length > 1).toList();
      final byLoose = <String, Set<String>>{};
      for (final f in catalog.families) {
        byLoose
            .putIfAbsent(loose(nameOf(f.records.first)), () => {})
            .add(nameOf(f.records.first));
      }
      return {
        'rows': catalog.records.length,
        'concepts': catalog.families.length,
        'withVersions': versioned.length,
        'versionSamples': [
          for (final f in versioned.take(6))
            '${nameOf(f.records.first)} · ${f.variants.length} versions · '
                'sources ${f.sources.map((s) => s ?? 'built-in').join(', ')}'
        ],
        'bracketedNames': catalog.records
            .map(nameOf)
            .where((n) => n.contains('['))
            .length,
        'splitConcepts': byLoose.values.where((s) => s.length > 1).length,
        'splitSamples': [
          for (final s in byLoose.values.where((s) => s.length > 1).take(8))
            s.join(' ≠ ')
        ],
      };
    }

    List<int> shelf<T>(List<T> rows, ContentRecord<T> Function(T) record) {
      final choices = shelfChoices(rows, record);
      return [
        rows.length,
        choices.length,
        choices.where((c) => c.hasVersions).length
      ];
    }

    Object? hero;
    if (heroPath != null) {
      final imported =
          await ImportService.importCharactersFromFC5File(File(heroPath));
      final h = imported.characters.single;
      final found = imported.ambiguities[h.id] ?? const [];
      hero = {
        'spellsKnownResolved': [
          h.knownSpells.length,
          h.knownSpells.where((id) => SpellService.getSpellById(id) != null).length
        ],
        'classes': [for (final c in h.classes) '${c.name} → ${c.id}'],
        'toReconcile': [
          for (final a in found) '${a.kind.name}: ${a.original} · '
              '${a.family.variants.length} versions'
        ],
      };
    }

    final builtInAfter = builtIn();
    final report = {
      'imports': imports,
      'builtInClassesChanged': {
        for (final id in builtInBefore.keys)
          if ('${builtInBefore[id]}' != '${builtInAfter[id]}')
            id: 'features·subclasses ${builtInBefore[id]} → ${builtInAfter[id]}'
      },
      'spells': kind(SpellService.getAllSpells(), ContentRecords.spell),
      'classes': kind(
          CharacterDataService.getAllClasses(), ContentRecords.characterClass),
      'races': kind(CharacterDataService.getAllRaces(), ContentRecords.race),
      'backgrounds': kind(
          CharacterDataService.getAllBackgrounds(), ContentRecords.background),
      'feats': kind(CharacterDataService.getAllFeats(), ContentRecords.feat),
      'items': kind(ItemService.getAllItems(), ContentRecords.item),
      'prologueRowsCardsVersioned': {
        'races': shelf(CharacterDataService.shelfRaces(), ContentRecords.race),
        'classes': shelf(CharacterDataService.getAllClasses(),
            ContentRecords.characterClass),
        'backgrounds': shelf(CharacterDataService.shelfBackgrounds(),
            ContentRecords.background),
      },
      'registry': {
        'liveFamilies': ContentIdentityService.current.liveFamilies,
        'variants': ContentIdentityService.current.variantCount,
      },
      if (hero != null) 'hero': hero,
    };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  },
      skip: input == null ? 'Set QDND_FC5_COMPENDIUMS to run.' : false,
      timeout: const Timeout(Duration(minutes: 12)));
}
