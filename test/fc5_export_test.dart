import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/models/item.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/core/services/fc5_export_service.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:xml/xml.dart';

void main() {
  group('FC5ExportService', () {
    test('exports parser-compatible XML and roundtrips key fields', () async {
      final character = Character(
        id: 'fc5-export-rich',
        name: 'Astral Rowan',
        race: 'Elf',
        characterClass: 'Cleric',
        subclass: 'Life Domain',
        level: 3,
        maxHp: 27,
        currentHp: 19,
        temporaryHp: 4,
        abilityScores: AbilityScores(
          strength: 10,
          dexterity: 14,
          constitution: 13,
          intelligence: 12,
          wisdom: 16,
          charisma: 8,
        ),
        background: 'Acolyte',
        spellSlots: const [2, 1, 0, 0, 0, 0, 0, 0, 0],
        maxSpellSlots: const [4, 2, 0, 0, 0, 0, 0, 0, 0],
        proficientSkills: const ['insight', 'religion'],
        expertSkills: const ['insight'],
        savingThrowProficiencies: const ['wisdom', 'charisma'],
        knownSpells: const ['astral_spark', 'cure_wounds'],
        preparedSpells: const ['astral_spark'],
        maxPreparedSpells: 1,
        inventory: [
          Item(
            id: 'crimson_mace',
            nameEn: 'Crimson Mace',
            nameRu: 'Crimson Mace',
            descriptionEn: 'Synthetic test weapon.',
            descriptionRu: 'Synthetic test weapon.',
            type: ItemType.weapon,
            rarity: ItemRarity.common,
            quantity: 1,
            weight: 4,
            valueInCopper: 500,
            isEquipped: true,
            isAttuned: true,
            weaponProperties: WeaponProperties(
              damageDice: '1d6',
              damageType: DamageType.bludgeoning,
            ),
          ),
        ],
        features: [
          CharacterFeature(
            id: 'channel-divinity',
            nameEn: 'Channel Divinity',
            nameRu: 'Channel Divinity',
            descriptionEn: 'Synthetic channel option state.',
            descriptionRu: 'Synthetic channel option state.',
            type: FeatureType.resourcePool,
            minLevel: 2,
            associatedClass: 'Cleric',
            resourcePool: ResourcePool(
              currentUses: 1,
              maxUses: 1,
              recoveryType: RecoveryType.shortRest,
            ),
          ),
        ],
        journalNotes: [
          JournalNote(
            id: 'note-astral',
            title: 'Quest: Astral Bell',
            content: 'Find the bell under the violet bridge.',
          ),
        ],
        classes: [
          CharacterClass(
            id: 'cleric',
            name: 'Cleric',
            level: 3,
            subclass: 'Life Domain',
            isPrimary: true,
          ),
        ],
        copperPieces: 3,
        silverPieces: 4,
        goldPieces: 25,
        platinumPieces: 1,
      );

      final result = await FC5ExportService.exportCharacter(character);
      XmlDocument.parse(result.xml);

      final parsed = FC5Parser.parseCharacter(result.xml);

      expect(parsed.name, character.name);
      expect(parsed.race, 'Elf');
      expect(parsed.background, 'Acolyte');
      expect(parsed.characterClass, 'Cleric');
      expect(parsed.subclass, 'Life Domain');
      expect(parsed.level, 3);
      expect(parsed.maxHp, 27);
      expect(parsed.currentHp, 19);
      expect(parsed.temporaryHp, 4);
      expect(parsed.abilityScores.wisdom, 16);
      expect(parsed.maxSpellSlots[0], 4);
      expect(parsed.spellSlots[0], 2);
      expect(
          parsed.savingThrowProficiencies, containsAll(['wisdom', 'charisma']));
      expect(parsed.proficientSkills, containsAll(['insight', 'religion']));
      expect(parsed.expertSkills, contains('insight'));
      expect(parsed.knownSpells, containsAll(['astral_spark', 'cure_wounds']));
      expect(parsed.preparedSpells, contains('astral_spark'));
      expect(parsed.inventory.single.nameEn, 'Crimson Mace');
      expect(parsed.inventory.single.isEquipped, isTrue);
      expect(parsed.inventory.single.isAttuned, isTrue);
      expect(parsed.goldPieces, 25);
      expect(parsed.journalNotes.single.title, 'Quest: Astral Bell');
      expect(parsed.features.map((feature) => feature.nameEn),
          contains('Channel Divinity'));
    });
  });
}
