import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:hive/hive.dart';

void main() {
  group('FC5 Import Tests', () {
    test('Parse minimal Paladin XML', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<pc version="5">
  <character>
    <name>Test Paladin</name>
    <abilities>15,12,14,10,10,16</abilities>
    <hpMax>30</hpMax>
    <hpCurrent>30</hpCurrent>
    <race><name>Human</name></race>
    <class>
      <name>Paladin: Oath of Devotion</name>
      <level>5</level>
      <slots>0,4,2,0,0,0,0,0,0,0</slots>
      <slotsCurrent>0,4,2,0,0,0,0,0,0,0</slotsCurrent>
    </class>
  </character>
</pc>
      ''';

      final char = FC5Parser.parseXml(xml);

      expect(char.name, 'Test Paladin');
      expect(char.characterClass, 'Paladin'); // Legacy field
      expect(char.subclass, 'Oath of Devotion'); // Legacy field
      expect(char.level, 5);
      
      // Check Migration to Classes list
      expect(char.classes.isNotEmpty, true);
      expect(char.classes.first.id, 'paladin');
      expect(char.classes.first.level, 5);
      expect(char.classes.first.subclass, 'Oath of Devotion');
      
      // Check stats
      expect(char.maxHp, 30);
      expect(char.abilityScores.strength, 15);
      
      // Check spell slots (index 0 is level 1)
      expect(char.maxSpellSlots[0], 4);
      expect(char.maxSpellSlots[1], 2);
    });
  });
}
