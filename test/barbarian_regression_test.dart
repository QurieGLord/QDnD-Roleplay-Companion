import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/services/feature_service.dart';

Character _buildBarbarian({
  required int level,
  int strength = 16,
  int dexterity = 14,
  int constitution = 16,
}) {
  return Character(
    id: 'barbarian-$level',
    name: 'Regression Barbarian',
    race: 'Human',
    characterClass: 'Barbarian',
    level: level,
    maxHp: 30,
    currentHp: 30,
    abilityScores: AbilityScores(
      strength: strength,
      dexterity: dexterity,
      constitution: constitution,
      intelligence: 10,
      wisdom: 10,
      charisma: 8,
    ),
    savingThrowProficiencies: const ['strength', 'constitution'],
    spellSlots: const [],
    maxSpellSlots: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await FeatureService.init();
  });

  group('Barbarian regressions', () {
    test(
        'rage resource formula follows SRD progression including unlimited uses',
        () {
      expect(
        FeatureService.calculateMaxUses(
          _buildBarbarian(level: 1),
          'level < 3 ? 2 : (level < 6 ? 3 : (level < 12 ? 4 : (level < 17 ? 5 : (level < 20 ? 6 : 99))))',
        ),
        2,
      );
      expect(
        FeatureService.calculateMaxUses(
          _buildBarbarian(level: 3),
          'level < 3 ? 2 : (level < 6 ? 3 : (level < 12 ? 4 : (level < 17 ? 5 : (level < 20 ? 6 : 99))))',
        ),
        3,
      );
      expect(
        FeatureService.calculateMaxUses(
          _buildBarbarian(level: 6),
          'level < 3 ? 2 : (level < 6 ? 3 : (level < 12 ? 4 : (level < 17 ? 5 : (level < 20 ? 6 : 99))))',
        ),
        4,
      );
      expect(
        FeatureService.calculateMaxUses(
          _buildBarbarian(level: 20),
          'level < 3 ? 2 : (level < 6 ? 3 : (level < 12 ? 4 : (level < 17 ? 5 : (level < 20 ? 6 : 99))))',
        ),
        99,
      );
    });

    test('placeholder primal path entries are filtered from level rewards', () {
      final features = FeatureService.getFeaturesForLevel(
        classId: 'Barbarian',
        level: 6,
        subclassId: 'berserker',
      );

      expect(features.any((feature) => feature.id == 'mindless-rage'), isTrue);
      expect(
        features.any(
          (feature) => feature.id.startsWith('primal-path-improvement-'),
        ),
        isFalse,
      );
    });

    test('unarmored defense adds constitution modifier to AC', () {
      final barbarian = _buildBarbarian(level: 1);
      barbarian.recalculateAC();

      expect(barbarian.armorClass, 15);
    });

    test(
        'constitution saving throw bonus includes proficiency for relentless rage checks',
        () {
      final barbarian = _buildBarbarian(level: 11);
      barbarian.features.add(
        CharacterFeature(
          id: 'relentless-rage',
          nameEn: 'Relentless Rage',
          nameRu: 'Неумолимая ярость',
          descriptionEn: '',
          descriptionRu: '',
          type: FeatureType.passive,
          minLevel: 11,
          associatedClass: 'Barbarian',
        ),
      );

      expect(barbarian.hasRelentlessRage, isTrue);
      expect(barbarian.constitutionSavingThrowBonus, 7);
    });

    test('rest resets relentless rage state', () {
      final barbarian = _buildBarbarian(level: 11);
      barbarian.relentlessRageSaveDc = 20;
      barbarian.isRaging = true;

      barbarian.shortRest();

      expect(barbarian.relentlessRageSaveDc, 10);
      expect(barbarian.isRaging, isFalse);
    });
  });
}
