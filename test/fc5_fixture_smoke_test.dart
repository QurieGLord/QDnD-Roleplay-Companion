import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/item.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';

void main() {
  group('FC5 fixture smoke tests', () {
    test('parses minimal player character export fixture', () async {
      final xml = await File(
        'test/fixtures/fc5/characters/fc5_pc_minimal_paladin.xml',
      ).readAsString();

      final character = FC5Parser.parseCharacter(xml);

      expect(character.name, 'Test Paladin');
      expect(character.characterClass, 'Paladin');
      expect(character.subclass, 'Oath of Devotion');
      expect(character.level, 5);
      expect(character.maxSpellSlots[0], 4);
      expect(character.maxSpellSlots[1], 2);
      expect(character.proficientSkills, contains('Athletics'));
    });

    test('parses first character from GM players wrapper fixture', () async {
      final xml = await File(
        'test/fixtures/fc5/characters/fc5_gm_players.xml',
      ).readAsString();

      final character = FC5Parser.parseCharacter(xml);

      expect(character.name, 'GM Export Fighter');
      expect(character.characterClass, 'Fighter');
      expect(character.level, 2);
    });

    test('parses minimal SRD-style compendium fixture', () async {
      final xml = await File(
        'test/fixtures/fc5/compendiums/fc5_srd_2014_minimal_compendium.xml',
      ).readAsString();

      final result = await FC5Parser.parseCompendium(xml);

      expect(result.races.length, 1);
      expect(result.classes.length, 1);
      expect(result.backgrounds.length, 1);
      expect(result.feats.length, 1);
      expect(result.items.length, 1);
      expect(result.spells.length, 1);
      expect(result.items.single.type, ItemType.weapon);
      expect(result.spells.single.availableToClasses, contains('cleric'));
    });
  });
}
