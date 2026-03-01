// ignore_for_file: avoid_print
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/compendium_source.dart';
import 'fc5_parser.dart';
import 'storage_service.dart';
import 'feature_service.dart';
import 'item_service.dart';
import 'spell_service.dart';
import 'character_data_service.dart';

class ImportService {
  // Import from FC5 XML file
  static Future<Character> importFromFC5File(File file) async {
    final xmlContent = await file.readAsString();
    final character = FC5Parser.parseCharacter(xmlContent);

    // Add class features to character
    FeatureService.addFeaturesToCharacter(character);

    await StorageService.saveCharacter(character);
    return character;
  }

  // Import Compendium (Items, Spells, Races, Classes, etc.) from FC5 XML file
  static Future<String> importCompendiumFile(File file) async {
    try {
      final xmlContent = await file.readAsString();
      final sourceId = const Uuid().v4();
      // Use parseCompendium for the universal import
      final parseResult =
          await FC5Parser.parseCompendium(xmlContent, sourceId: sourceId);

      final fileName = file.path.split(Platform.pathSeparator).last;

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

      return 'Imported successfully: ${parseResult.items.length} items, ${parseResult.spells.length} spells, ${parseResult.races.length} races, ${parseResult.classes.length} classes, ${parseResult.backgrounds.length} backgrounds, ${parseResult.feats.length} feats.';
    } catch (e) {
      print('❌ ImportService: Failed to import compendium: $e');
      throw Exception('Failed to import compendium: $e');
    }
  }
}
