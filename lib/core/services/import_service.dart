// ignore_for_file: avoid_print
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/compendium_source.dart';
import 'fc5_compendium_identity_service.dart';
import 'fc5_content_identity_service.dart';
import 'fc5_media_import_service.dart';
import 'fc5_parser.dart';
import 'storage_service.dart';
import 'feature_service.dart';
import 'feature_hydration_service.dart';
import 'item_service.dart';
import 'spell_service.dart';
import 'character_data_service.dart';

class ImportServiceException implements Exception {
  final String message;
  final FC5ParseDiagnostics diagnostics;

  ImportServiceException(this.message, {FC5ParseDiagnostics? diagnostics})
      : diagnostics = diagnostics ?? FC5ParseDiagnostics();

  @override
  String toString() => message;
}

class CharacterImportResult {
  final List<Character> characters;
  final FC5ParseDiagnostics diagnostics;

  CharacterImportResult({
    required this.characters,
    required this.diagnostics,
  });

  bool get hasWarnings => diagnostics.hasWarnings;
  int get warningCount => diagnostics.warningCount;
}

class CompendiumImportResult {
  final String sourceId;
  final String sourceName;
  final FC5ParseResult parseResult;

  CompendiumImportResult({
    required this.sourceId,
    required this.sourceName,
    required this.parseResult,
  });

  FC5ParseDiagnostics get diagnostics => parseResult.diagnostics;
  bool get hasWarnings => diagnostics.hasWarnings;
  int get warningCount => diagnostics.warningCount;

  String get summary {
    final duplicateCount = skippedDuplicateCount;
    final duplicateSummary =
        duplicateCount > 0 ? ' Skipped $duplicateCount duplicates.' : '';
    return 'Imported successfully: ${parseResult.items.length} items, '
        '${parseResult.spells.length} spells, ${parseResult.races.length} races, '
        '${parseResult.classes.length} classes, '
        '${parseResult.backgrounds.length} backgrounds, '
        '${parseResult.feats.length} feats.$duplicateSummary';
  }

  int get skippedDuplicateCount =>
      _diagnosticAggregateCount('duplicates_skipped');

  int get skippedUnsupportedCount =>
      _diagnosticAggregateCount('unsupported_nodes_skipped');

  int _diagnosticAggregateCount(String code) {
    var total = 0;
    for (final entry
        in diagnostics.entries.where((entry) => entry.code == code)) {
      final raw = entry.context ?? entry.message;
      final match = RegExp(r'\d+').firstMatch(raw);
      if (match != null) {
        total += int.tryParse(match.group(0) ?? '') ?? 0;
      }
    }
    return total;
  }
}

class ImportService {
  // Import from FC5 XML file
  static Future<Character> importFromFC5File(File file) async {
    final result = await importCharactersFromFC5File(file);
    if (result.characters.isEmpty) {
      throw ImportServiceException(
        'No supported FC5 characters found.',
        diagnostics: result.diagnostics,
      );
    }
    return result.characters.first;
  }

  static Future<CharacterImportResult> importCharactersFromFC5File(
    File file,
  ) async {
    final xmlContent = await file.readAsString();
    final parseResult = FC5Parser.parseCharacters(xmlContent);

    if (parseResult.candidates.isEmpty) {
      throw ImportServiceException(
        parseResult.diagnostics.entries.firstOrNull?.message ??
            'No supported FC5 characters found.',
        diagnostics: parseResult.diagnostics,
      );
    }

    final imported = <Character>[];
    for (final candidate in parseResult.candidates) {
      final character = candidate.character;
      await FC5MediaImportService.materializeCharacterMedia(
        character: character,
        media: candidate.media,
        diagnostics: parseResult.diagnostics,
      );
      FeatureService.addFeaturesToCharacter(character);
      final hydration = FeatureHydrationService.hydrateCharacter(character);
      character.features
        ..clear()
        ..addAll(hydration.features);
      _mergeHydrationDiagnostics(parseResult.diagnostics, hydration);
      character.recalculateAC();
      await StorageService.saveCharacter(character);
      imported.add(character);
    }

    return CharacterImportResult(
      characters: imported,
      diagnostics: parseResult.diagnostics,
    );
  }

  // Import Compendium (Items, Spells, Races, Classes, etc.) from FC5 XML file
  static Future<String> importCompendiumFile(File file) async {
    final result = await importCompendiumFileDetailed(file);
    return result.summary;
  }

  static Future<CompendiumImportResult> importCompendiumFileDetailed(
    File file,
  ) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final xmlContent = await file.readAsString();
    return importCompendiumXmlContentDetailed(
      xmlContent,
      sourceName: fileName,
    );
  }

  static Future<CompendiumImportResult> importCompendiumXmlContentDetailed(
    String xmlContent, {
    required String sourceName,
    String? archiveId,
    String? archiveName,
    String? moduleName,
    String? modulePath,
    String sourceKind = 'xml',
  }) async {
    try {
      final fingerprint = FC5CompendiumIdentityService.fingerprintXml(
        xmlContent,
      );
      final duplicateSource = await _findDuplicateSource(fingerprint);
      if (duplicateSource != null) {
        final diagnostics = FC5ParseDiagnostics()
          ..warning(
            'duplicate_source',
            'This FC5 compendium has already been imported.',
            context: duplicateSource.name,
          );
        throw ImportServiceException(
          'This FC5 compendium has already been imported as "${duplicateSource.name}".',
          diagnostics: diagnostics,
        );
      }

      final sourceId = const Uuid().v4();
      final rawParseResult =
          await FC5Parser.parseCompendium(xmlContent, sourceId: sourceId);
      final deduped = FC5CompendiumDeduplicationService.dedupe(rawParseResult);
      final parseResult = deduped.parseResult;

      if (rawParseResult.isEmpty) {
        throw ImportServiceException(
          rawParseResult.diagnostics.entries.firstOrNull?.message ??
              'This XML file does not contain supported FC5 compendium content.',
          diagnostics: rawParseResult.diagnostics,
        );
      }

      if (parseResult.isEmpty) {
        throw ImportServiceException(
          deduped.stats.total > 0
              ? 'This FC5 compendium does not contain new importable content.'
              : 'This XML file does not contain supported FC5 compendium content.',
          diagnostics: parseResult.diagnostics,
        );
      }

      // Create and save source metadata
      final source = CompendiumSource(
        id: sourceId,
        name: moduleName ?? sourceName,
        importedAt: DateTime.now(),
        itemCount: parseResult.items.length,
        spellCount: parseResult.spells.length,
        raceCount: parseResult.races.length,
        classCount: parseResult.classes.length,
        backgroundCount: parseResult.backgrounds.length,
        featCount: parseResult.feats.length,
        archiveId: archiveId,
        archiveName: archiveName,
        moduleName: moduleName,
        modulePath: modulePath,
        sourceKind: sourceKind,
      );

      await StorageService.saveSource(source);
      await StorageService.saveSourceFingerprint(fingerprint, sourceId);

      if (parseResult.items.isNotEmpty) {
        await StorageService.saveItems(parseResult.items);
      }

      if (parseResult.spells.isNotEmpty) {
        await StorageService.saveSpells(parseResult.spells);
      }

      if (parseResult.races.isNotEmpty) {
        await StorageService.saveRaces(parseResult.races);
      }

      if (parseResult.classes.isNotEmpty) {
        await StorageService.saveClasses(parseResult.classes);
      }

      if (parseResult.backgrounds.isNotEmpty) {
        await StorageService.saveBackgrounds(parseResult.backgrounds);
      }

      if (parseResult.feats.isNotEmpty) {
        await StorageService.saveFeats(parseResult.feats);
      }

      // Reload services to reflect changes
      await ItemService.reload();
      await SpellService.reload();
      // CharacterDataService handles races/classes usually, now needs to handle backgrounds/feats too
      await CharacterDataService.reload();

      return CompendiumImportResult(
        sourceId: sourceId,
        sourceName: moduleName ?? sourceName,
        parseResult: parseResult,
      );
    } on ImportServiceException {
      rethrow;
    } catch (e) {
      print('ImportService: Failed to import compendium: $e');
      throw ImportServiceException('Failed to import compendium: $e');
    }
  }

  static Future<void> reloadImportedContentServices() async {
    await ItemService.reload();
    await SpellService.reload();
    await CharacterDataService.reload();
  }

  static Future<CompendiumSource?> _findDuplicateSource(
    String fingerprint,
  ) async {
    final sourceId = StorageService.getSourceIdForFingerprint(fingerprint);
    if (sourceId == null) return null;

    for (final source in StorageService.getAllSources()) {
      if (source.id == sourceId) return source;
    }

    await StorageService.deleteSourceFingerprint(fingerprint);
    return null;
  }

  static void _mergeHydrationDiagnostics(
    FC5ParseDiagnostics diagnostics,
    FeatureHydrationResult hydration,
  ) {
    for (final entry in hydration.diagnostics) {
      switch (entry.severity) {
        case FeatureHydrationDiagnosticSeverity.warning:
          diagnostics.warning(
            entry.code,
            entry.message,
            context: entry.context,
          );
          break;
        case FeatureHydrationDiagnosticSeverity.info:
          diagnostics.info(
            entry.code,
            entry.message,
            context: entry.context,
          );
          break;
      }
    }
  }
}
