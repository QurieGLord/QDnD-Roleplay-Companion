import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/features/character_creation/character_creation_state.dart';

ClassData _buildClass({
  required String id,
  String? spellcastingType,
}) {
  return ClassData(
    id: id,
    name: {'en': id, 'ru': id},
    description: {'en': id, 'ru': id},
    hitDie: 10,
    primaryAbilities: const ['strength'],
    savingThrowProficiencies: const ['strength'],
    armorProficiencies: ArmorProficiencies(),
    weaponProficiencies: WeaponProficiencies(),
    skillProficiencies: SkillProficiencies(choose: 0, from: const []),
    subclasses: const [],
    subclassLevel: 3,
    spellcasting: spellcastingType == null
        ? null
        : SpellcastingInfo(
            ability: 'charisma',
            type: spellcastingType,
          ),
    features: const {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await SpellService.loadSpells();
  });

  group('CharacterCreationState spell validation', () {
    test('does not block paladin at level 1 when there are no spell choices',
        () {
      final state = CharacterCreationState()
        ..selectedClass = _buildClass(id: 'paladin', spellcastingType: 'half');

      expect(state.hasAnySpellChoicesAtLevel1, isFalse);
      expect(state.getSpellLimits().cantrips, 0);
      expect(state.getSpellLimits().spellsKnown, 0);
      expect(state.isStepValid(3), isTrue);
    });

    test(
        'does not block ranger spells when mandatory feature choices are filled',
        () {
      final state = CharacterCreationState()
        ..selectedClass = _buildClass(id: 'ranger', spellcastingType: 'half')
        ..selectedFeatureOptions['favored_enemy'] = 'beasts'
        ..selectedFeatureOptions['natural_explorer'] = 'forest';

      expect(state.hasAnySpellChoicesAtLevel1, isFalse);
      expect(state.isStepValid(3), isTrue);
    });

    test('still requires spell picks for bard at level 1', () {
      final state = CharacterCreationState()
        ..selectedClass = _buildClass(id: 'bard', spellcastingType: 'full');

      expect(state.hasAnySpellChoicesAtLevel1, isTrue);
      expect(state.getSpellLimits().cantrips, greaterThan(0));
      expect(state.getSpellLimits().spellsKnown, greaterThan(0));
      expect(state.isStepValid(3), isFalse);
    });
  });
}
