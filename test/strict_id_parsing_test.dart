import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';

void main() {
  group('FC5Parser Strict ID & Bilingual Tests', () {
    const xmlContent = '''
    <compendium>
      <class>
        <name>Test Class</name>
        <name_ru>Тестовый Класс</name_ru>
        <hd>8</hd>
        <proficiency>Saving Throws: Wisdom, Charisma; Skills: Choose 2 from Arcana (Int), History, Insight</proficiency>
        <numSkills>2</numSkills>
        <autolevel level="1">
            <feature optional="YES">
                <name>Optional Feature</name>
                <text>This is optional.</text>
            </feature>
        </autolevel>
      </class>
      <background>
        <name>Test Background</name>
        <proficiency>Stealth (Dex), Perception</proficiency>
      </background>
    </compendium>
    ''';

    test('Parses Class Proficiencies with Strict IDs', () async {
      final result = await FC5Parser.parseCompendium(xmlContent);
      final testClass = result.classes.first;

      expect(testClass.id, 'test class'); // ID should be English Name
      expect(testClass.name['en'], 'Test Class');
      expect(testClass.name['ru'], 'Тестовый Класс');

      // Check Saving Throws (lowercase, trimmed)
      expect(testClass.savingThrowProficiencies, contains('wisdom'));
      expect(testClass.savingThrowProficiencies, contains('charisma'));

      // Check Skills (lowercase, trimmed, parentheses removed)
      expect(testClass.skillProficiencies.from, contains('arcana'));
      expect(testClass.skillProficiencies.from, contains('history'));
      expect(testClass.skillProficiencies.from, contains('insight'));

      // Ensure no raw text remains
      expect(testClass.skillProficiencies.from.contains('Arcana (Int)'), false);
    });

    test('Parses Background Proficiencies with Strict IDs', () async {
      final result = await FC5Parser.parseCompendium(xmlContent);
      final testBg = result.backgrounds.first;

      expect(testBg.id, 'test background');
      expect(testBg.skillProficiencies, contains('stealth'));
      expect(testBg.skillProficiencies, contains('perception'));
      expect(testBg.skillProficiencies.contains('Stealth (Dex)'), false);
    });

    test('Parses Optional Features', () async {
      final result = await FC5Parser.parseCompendium(xmlContent);
      final testClass = result.classes.first;
      final features = testClass.features[1]!;

      final optionalFeature =
          features.firstWhere((f) => f.nameEn.contains('Optional Feature'));
      expect(optionalFeature.nameEn, startsWith('[Optional]'));
    });
  });
}
