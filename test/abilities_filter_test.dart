// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/character_feature.dart';

void main() {
  test('Trace paladinChannelDivinity EXACT filter', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await FeatureService.init();

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
    char.subclass = 'devotion';

    FeatureService.addFeaturesToCharacter(char);
    final allFeatures = char.features;

    CharacterFeature? findFeatureDeep(
        List<CharacterFeature> list, List<String> keywords) {
      // 1. Exact ID Match first
      for (final keyword in keywords) {
        final match = list.where((f) => (f.id) == keyword).firstOrNull;
        if (match != null) return match;
      }

      // 2. Contains ID
      for (final keyword in keywords) {
        final candidates = list.where((f) => (f.id).contains(keyword)).toList();
        candidates.sort((a, b) => (b.minLevel).compareTo(a.minLevel));
        if (candidates.isNotEmpty) return candidates.first;
      }

      return null;
    }

    final paladinChannelDivinity =
        findFeatureDeep(allFeatures, ['channel-divinity', 'channel_divinity']);

    print('paladinChannelDivinity ID: ${paladinChannelDivinity?.id}');
    print(
        'paladinChannelDivinity ResourcePool: ${paladinChannelDivinity?.resourcePool}');

    var paladinChannelSpells = <CharacterFeature>[];
    if (paladinChannelDivinity != null) {
      paladinChannelSpells = allFeatures
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
    }

    print('Channel Spells filtered: ${paladinChannelSpells.length}');
  });
}
