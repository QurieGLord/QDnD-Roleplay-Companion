import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import '../models/character.dart';
import 'fc5_parser.dart';
import 'storage_service.dart';
import 'feature_service.dart';

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
