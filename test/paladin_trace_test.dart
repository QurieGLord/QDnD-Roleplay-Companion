// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';

void main() {
  test('Trace Paladin Channel Divinity', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await FeatureService.init();

    // Create a level 3 Paladin of Devotion
    var char = Character(
      id: 'test',
      name: 'Test Paladin',
      race: 'Human',
      characterClass: 'Paladin',
      level: 3,
      maxHp: 30,
      currentHp: 30,
      abilityScores: AbilityScores(
          strength: 16,
          dexterity: 10,
          constitution: 14,
          intelligence: 10,
          wisdom: 10,
          charisma: 16),
      spellSlots: [0, 0, 0, 0, 0, 0, 0, 0, 0],
      maxSpellSlots: [0, 0, 0, 0, 0, 0, 0, 0, 0],
    );
    char.subclass = 'devotion'; // Devotion subclass ID

    // Add features
    FeatureService.addFeaturesToCharacter(char);

    print('=== Character Features ===');
    for (var f in char.features) {
      print('- ${f.nameEn} (ID: ${f.id}, Subclass: ${f.associatedSubclass})');
    }

    final allFeatures = char.features;
    final paladinChannelDivinity = allFeatures.cast<dynamic>().where((f) {
      final name = (f.nameEn).toLowerCase();
      final id = (f.id).toLowerCase();
      return name == 'channel divinity' ||
          id == 'channel-divinity' ||
          id == 'channel_divinity';
    }).firstOrNull;

    print('\nFound Base Channel Divinity: ${paladinChannelDivinity != null}');

    if (paladinChannelDivinity != null) {
      final paladinChannelSpells = allFeatures
          .where((f) {
            final id = (f.id).toLowerCase();
            final usageCost = (f.usageCostId ?? '').toLowerCase();
            return (id.startsWith('channel-divinity-') ||
                    id.startsWith('channel_divinity_')) ||
                (usageCost.contains('channel-divinity') ||
                    usageCost.contains('channel_divinity'));
          })
          .where((f) => f.id != paladinChannelDivinity.id)
          .toList();

      print('\nChannel Spells Filtered: ${paladinChannelSpells.length}');
      for (var f in paladinChannelSpells) {
        print(' - ${f.id} (usageCostId: ${f.usageCostId})');
      }
    }
  });
}
