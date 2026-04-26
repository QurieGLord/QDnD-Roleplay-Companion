import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/item.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
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

      final candidates = FC5Parser.parseCharacters(xml);
      expect(candidates.candidates.length, 2);
      expect(candidates.candidates[1].character.name, 'GM Export Wizard');
      expect(
          candidates.diagnostics.entries.any(
            (entry) => entry.code == 'multiple_characters',
          ),
          isTrue);
    });

    test('parses rich player character export fixture', () async {
      final xml = await File(
        'test/fixtures/fc5/characters/fc5_pc_rich_export_shape.xml',
      ).readAsString();

      final result = FC5Parser.parseCharacters(xml);
      expect(result.candidates.length, 1);

      final character = result.candidates.single.character;
      expect(character.name, 'Mira Dawnward');
      expect(character.race, 'Elf');
      expect(character.background, 'Acolyte');
      expect(character.characterClass, 'Cleric');
      expect(character.subclass, 'Life Domain');
      expect(character.level, 3);
      expect(character.maxHp, 27);
      expect(character.currentHp, 21);
      expect(character.maxSpellSlots[0], 4);
      expect(character.maxSpellSlots[1], 2);
      expect(character.spellSlots[0], 2);
      expect(character.spellSlots[1], 1);

      expect(character.savingThrowProficiencies, contains('wisdom'));
      expect(character.savingThrowProficiencies, contains('charisma'));
      expect(character.proficientSkills, contains('insight'));
      expect(character.proficientSkills, contains('Religion'));

      expect(character.inventory.length, 2);
      final mace = character.inventory.firstWhere((i) => i.nameEn == 'Mace');
      expect(mace.type, ItemType.weapon);
      expect(mace.isEquipped, isTrue);
      expect(mace.weaponProperties?.damageDice, '1d6');
      expect(mace.weaponProperties?.damageType, DamageType.bludgeoning);

      final armor =
          character.inventory.firstWhere((i) => i.nameEn == 'Chain Shirt');
      expect(armor.type, ItemType.armor);
      expect(armor.isEquipped, isTrue);
      expect(armor.armorProperties?.baseAC, 13);
      expect(character.armorClass, 15);

      expect(character.goldPieces, 25);
      expect(character.journalNotes.length, 2);
      expect(
        character.journalNotes
            .firstWhere((n) => n.title.contains('Quest'))
            .category,
        NoteCategory.story,
      );

      expect(character.knownSpells, contains('bless'));
      expect(character.preparedSpells, contains('cure_wounds'));
      expect(
        character.features.map((feature) => feature.nameEn),
        containsAll([
          'Keen Senses',
          'Feature: Shelter of the Faithful',
          'Channel Divinity',
        ]),
      );
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

    test('parses FC5 spell and item variants with stable source scoped ids',
        () async {
      const xml = '''
<compendium version="5">
  <item>
    <name>Fixture Longbow</name>
    <type>R</type>
    <weight>2</weight>
    <value>50</value>
    <dmg1>1d8</dmg1>
    <dmgType>P</dmgType>
    <property>A, H, 2H</property>
    <range>150/600</range>
  </item>
  <item>
    <name>Fixture Scale Mail</name>
    <type>MA</type>
    <ac>14</ac>
    <stealth>YES</stealth>
    <strength>13</strength>
  </item>
  <spell>
    <name>Fixture Ritual</name>
    <level>1</level>
    <school>D</school>
    <ritual>1</ritual>
    <time>1 action</time>
    <range>Self</range>
    <v>1</v>
    <s>1</s>
    <m>1</m>
    <materials>silver dust</materials>
    <duration>Concentration, up to 1 minute</duration>
    <sclass>Wizard</sclass>
    <sclass>Паладин (Клятва преданности)</sclass>
    <text>Fixture text.</text>
  </spell>
</compendium>
''';

      final result = await FC5Parser.parseCompendium(
        xml,
        sourceId: 'fixture-source',
      );

      expect(result.items.length, 2);
      expect(result.items.first.id, 'fc5_fixture_source_item_fixture_longbow');
      expect(
          result.items.first.weaponProperties?.damageType, DamageType.piercing);
      expect(result.items.first.weaponProperties?.weaponTags,
          containsAll(['ammunition', 'heavy', 'two_handed']));
      expect(result.items.first.weaponProperties?.range, 150);
      expect(result.items.first.weaponProperties?.longRange, 600);
      expect(result.items.last.armorProperties?.stealthDisadvantage, isTrue);
      expect(result.items.last.armorProperties?.strengthRequirement, 13);

      expect(result.spells.single.school, 'Divination');
      expect(result.spells.single.ritual, isTrue);
      expect(result.spells.single.components, containsAll(['V', 'S', 'M']));
      expect(result.spells.single.materialComponents, 'silver dust');
      expect(result.spells.single.availableToClasses,
          containsAll(['wizard', 'paladin']));
    });

    test('reports unsupported collection and monster-only compendium',
        () async {
      final collection = await FC5Parser.parseCompendium('''
<collection><doc href="Sources/example.xml"/></collection>
''');
      expect(collection.isEmpty, isTrue);
      expect(collection.diagnostics.hasErrors, isTrue);
      expect(
          collection.diagnostics.entries.single.code, 'collection_unsupported');

      final monsterOnly = await FC5Parser.parseCompendium('''
<compendium version="5"><monster><name>Fixture Beast</name></monster></compendium>
''');
      expect(monsterOnly.isEmpty, isTrue);
      expect(monsterOnly.diagnostics.hasWarnings, isTrue);
      expect(monsterOnly.diagnostics.entries.single.code, 'unsupported_node');
    });
  });
}
