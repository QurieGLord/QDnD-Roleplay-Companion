import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/compendium_source.dart';
import 'fc5_parser.dart';
import 'storage_service.dart';
import 'feature_service.dart';
import 'item_service.dart';
import 'spell_service.dart';

class ImportService {
  // Import from FC5 XML file
  static Future<Character> importFromFC5File(File file) async {
    final xmlContent = await file.readAsString();
    final character = FC5Parser.parseXml(xmlContent);

    // Add class features to character
    FeatureService.addFeaturesToCharacter(character);

    await StorageService.saveCharacter(character);
    return character;
  }

  // Import Compendium (Items & Spells) from FC5 XML file
  static Future<String> importCompendiumFile(File file) async {
    try {
      final xmlContent = await file.readAsString();
      final compendiumData = await FC5Parser.parseCompendium(xmlContent);
      
      final sourceId = const Uuid().v4();
      final fileName = file.path.split(Platform.pathSeparator).last;
      
      // Assign sourceId to all items and spells
      for (var item in compendiumData.items) {
        item.sourceId = sourceId;
      }
      
      for (var spell in compendiumData.spells) {
        spell.sourceId = sourceId;
      }

      // Create and save source metadata
      final source = CompendiumSource(
        id: sourceId,
        name: fileName,
        importedAt: DateTime.now(),
        itemCount: compendiumData.items.length,
        spellCount: compendiumData.spells.length,
      );
      
      await StorageService.saveSource(source);

      if (compendiumData.items.isNotEmpty) {
        await StorageService.saveItems(compendiumData.items);
      }
      
      if (compendiumData.spells.isNotEmpty) {
        await StorageService.saveSpells(compendiumData.spells);
      }

      // Reload ItemService to reflect changes
      await ItemService.reload();
      // Reload SpellService to reflect changes
      await SpellService.reload();

      return 'Imported successfully: ${compendiumData.items.length} items, ${compendiumData.spells.length} spells.';
    } catch (e) {
      print('❌ ImportService: Failed to import compendium: $e');
      throw Exception('Failed to import compendium: $e');
    }
  }

  // Import from asset (for testing with pal_example.xml)
  static Future<Character> importFromAsset(String assetPath) async {
    final xmlContent = await rootBundle.loadString(assetPath);
    final character = FC5Parser.parseXml(xmlContent);

    // Add class features to character
    FeatureService.addFeaturesToCharacter(character);

    await StorageService.saveCharacter(character);
    return character;
  }

  // Load example character on first run
  static Future<void> loadExampleCharacterIfNeeded() async {
    final characters = StorageService.getAllCharacters();

    if (characters.isEmpty) {
      try {
        await importFromAsset('assets/data/fc5_examples/pal_example.xml');
        print('✅ Example character "Кюри" imported successfully!');
      } catch (e) {
        print('❌ Failed to import example character: $e');
      }
    }
  }
}
