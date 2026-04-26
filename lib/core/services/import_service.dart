// ignore_for_file: avoid_print
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/compendium_source.dart';
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
    return 'Imported successfully: ${parseResult.items.length} items, '
        '${parseResult.spells.length} spells, ${parseResult.races.length} races, '
        '${parseResult.classes.length} classes, '
        '${parseResult.backgrounds.length} backgrounds, '
        '${parseResult.feats.length} feats.';
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
    try {
      final xmlContent = await file.readAsString();
      final sourceId = const Uuid().v4();
      final parseResult =
          await FC5Parser.parseCompendium(xmlContent, sourceId: sourceId);

      final fileName = file.path.split(Platform.pathSeparator).last;

      if (parseResult.isEmpty) {
        throw ImportServiceException(
          parseResult.diagnostics.entries.firstOrNull?.message ??
              'This XML file does not contain supported FC5 compendium content.',
          diagnostics: parseResult.diagnostics,
        );
      }

      // Create and save source metadata
      final source = CompendiumSource(
        id: sourceId,
        name: fileName,
        importedAt: DateTime.now(),
        itemCount: parseResult.items.length,
        spellCount: parseResult.spells.length,
        raceCount: parseResult.races.length,
        classCount: parseResult.classes.length,
        backgroundCount: parseResult.backgrounds.length,
        featCount: parseResult.feats.length,
      );

      await StorageService.saveSource(source);

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
        sourceName: fileName,
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
