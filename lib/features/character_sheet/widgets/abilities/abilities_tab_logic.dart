import 'package:flutter/foundation.dart';

import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';

class AbilitiesTabLogic {
  const AbilitiesTabLogic(this.character);

  final Character character;

  bool shouldShowInList(CharacterFeature feature) {
    try {
      if (feature.options != null && feature.options!.isNotEmpty) {
        final hasAtLeastOneChild =
            character.features.any((f) => feature.options!.contains(f.id));
        if (hasAtLeastOneChild) {
          return false;
        }
      }

      final id = feature.id.toLowerCase();
      final name = feature.nameEn.toLowerCase();
      final usageCost = (feature.usageCostId ?? '').toLowerCase();

      if (id.contains('action_surge') || name.contains('action surge')) {
        return false;
      }
      if (id.contains('second_wind') || name.contains('second wind')) {
        return false;
      }
      if (id.contains('indomitable')) return false;
      if (id.contains('rage') || name == 'rage') return false;
      if (id.contains('ki') || name.startsWith('ki')) return false;
      if (id.contains('sneak_attack') || name.contains('sneak attack')) {
        return false;
      }

      if (id.contains('martial_arts') ||
          id.contains('martial-arts') ||
          name.contains('martial arts')) {
        return false;
      }
      const monkTactics = [
        'flurry_of_blows',
        'flurry-of-blows',
        'patient_defense',
        'patient-defense',
        'step_of_the_wind',
        'step-of-the-wind',
        'stunning_strike',
        'stunning-strike',
        'unarmored_movement',
        'unarmored-movement',
        'шквал ударов',
        'терпеливая оборона',
        'поступь ветра',
        'оглушающий удар',
        'движение без доспехов',
      ];
      if (monkTactics.any((t) => id.contains(t) || name.contains(t))) {
        return false;
      }

      if (id.contains('bardic_inspiration') ||
          id.contains('bardic-inspiration') ||
          name.contains('bardic inspiration') ||
          name.contains('бардовское вдохновение')) {
        return false;
      }
      const bardTactics = [
        'cutting_words',
        'cutting-words',
        'cutting words',
        'острые слова',
        'combat_inspiration',
        'combat-inspiration',
        'combat inspiration',
        'боевое вдохновение',
        'countercharm',
        'контрочарование',
        'song_of_rest',
        'song-of-rest',
        'song of rest',
        'песнь отдыха',
      ];
      if (bardTactics.any((t) => id.contains(t) || name.contains(t))) {
        return false;
      }

      const rogueTactics = [
        'sneak_attack',
        'sneak-attack',
        'sneak attack',
        'скрытая атака',
        'cunning_action',
        'cunning-action',
        'cunning action',
        'хитрое действие',
        'uncanny_dodge',
        'uncanny-dodge',
        'uncanny dodge',
        'невероятное уклонение',
        'evasion',
        'увертливость',
      ];
      if (rogueTactics.any((t) => id.contains(t) || name.contains(t))) {
        return false;
      }

      if (id.contains('lay-on-hands') || id.contains('lay_on_hands')) {
        return false;
      }
      if (id.contains('divine-sense') || id.contains('divine_sense')) {
        return false;
      }
      if (id == 'channel-divinity' || id == 'channel_divinity') return false;
      if (id == 'divine-smite' ||
          id == 'divine_smite' ||
          name.contains('divine smite') ||
          name.contains('божественная кара')) {
        return false;
      }
      if (id.startsWith('channel-divinity-') ||
          id.startsWith('channel_divinity_')) {
        return false;
      }
      if (usageCost.contains('channel-divinity') ||
          usageCost.contains('channel_divinity')) {
        return false;
      }

      if (id == 'primeval-awareness' || id == 'primeval_awareness') {
        return false;
      }
      if (id == 'favored-enemy' || id == 'favored_enemy') return false;
      if (id == 'natural-explorer' || id == 'natural_explorer') return false;
      if (id == 'hunters-mark' ||
          id == 'hunters_mark' ||
          name.contains("hunter's mark") ||
          name.contains('метка охотника')) {
        return false;
      }
      if (id == 'hide-in-plain-sight' ||
          id == 'hide_in_plain_sight' ||
          name.contains('hide in plain sight') ||
          name.contains('маскировка')) {
        return false;
      }

      const rangerTactics = [
        'colossus',
        'horde breaker',
        'giant killer',
        'volley',
        'whirlwind',
        'evasion',
        'uncanny dodge',
        'multiattack defense',
        'steel will',
        'stand against',
        'escape the horde',
      ];
      if (rangerTactics.any((t) =>
          id.contains(t.replaceAll(' ', '-')) ||
          id.contains(t.replaceAll(' ', '_')) ||
          name.contains(t))) {
        return false;
      }

      if (id.contains('reckless-attack') ||
          id.contains('reckless_attack') ||
          name.contains('reckless attack') ||
          name.contains('безрассудная атака')) {
        return false;
      }
      if (id.contains('frenzy') ||
          name.contains('frenzy') ||
          name.contains('бешенство')) {
        return false;
      }
      if (id.contains('primal_path') ||
          id.contains('primal-path') ||
          name.contains('primal path') ||
          name.contains('путь дикости')) {
        return false;
      }

      if (id.contains('sorcery_point') ||
          id.contains('sorcery-point') ||
          name.contains('sorcery point') ||
          name.contains('единицы чародейства')) {
        return false;
      }

      if (id.contains('font_of_magic') ||
          id.contains('font-of-magic') ||
          name.contains('font of magic') ||
          name.contains('источник магии')) {
        return false;
      }

      if (id.contains('flexible_casting') ||
          id.contains('flexible-casting') ||
          name.contains('flexible casting') ||
          name.contains('гибкое накладывание') ||
          name.contains('гибкая магия')) {
        return false;
      }

      if (id.contains('metamagic') ||
          name.contains('metamagic') ||
          name.contains('метамагия')) {
        return false;
      }

      if (id.contains('dragon-ancestor') ||
          id.contains('draconic') ||
          id.contains('dragon') ||
          name.contains('dragon') ||
          name.contains('дракон')) {
        return false;
      }

      if (id.contains('eldritch-invocation') ||
          id.contains('eldritch_invocation') ||
          id.contains('invocation') ||
          name.contains('invocation') ||
          name.contains('воззвание')) {
        return false;
      }

      if (id.contains('pact-boon') ||
          id.contains('pact_boon') ||
          id.contains('pact-of-the-') ||
          id.contains('pact_of_the_') ||
          name.contains('pact boon') ||
          name.contains('предмет договора') ||
          name.contains('договор пакта')) {
        return false;
      }

      if (id.contains('mystic-arcanum') ||
          id.contains('mystic_arcanum') ||
          name.contains('mystic arcanum') ||
          name.contains('таинственный арканум')) {
        return false;
      }

      if (name.contains('wild shape') ||
          name.contains('дикий облик') ||
          id.contains('wild_shape') ||
          id.contains('wild-shape')) {
        return false;
      }

      if (name.contains('natural recovery') ||
          name.contains('естественное восстановление') ||
          id.contains('natural_recovery') ||
          id.contains('natural-recovery')) {
        return false;
      }

      if (name.contains('arcane recovery') ||
          name.contains('арканное восстановление') ||
          id.contains('arcane_recovery') ||
          id.contains('arcane-recovery')) {
        return false;
      }

      if (id.contains('arcane-tradition') ||
          id.contains('arcane_tradition') ||
          name.contains('arcane tradition') ||
          name.contains('магическая традиция')) {
        return false;
      }

      if (id.contains('divine-domain') ||
          id.contains('divine_domain') ||
          name.contains('divine domain') ||
          name.contains('божественный домен')) {
        return false;
      }

      if (id == 'channel_divinity' ||
          id == 'channel-divinity' ||
          name.contains('channel divinity') ||
          name.contains('божественный канал')) {
        return false;
      }

      if (id == 'fighting_style') return false;

      return true;
    } catch (e) {
      debugPrint('Error in shouldShowInList: $e');
      return false;
    }
  }

  CharacterFeature? findFeatureDeep(
      List<CharacterFeature> list, List<String> keywords) {
    try {
      for (final keyword in keywords) {
        final match = list.where((f) => f.id == keyword).firstOrNull;
        if (match != null) {
          return match;
        }
      }

      for (final keyword in keywords) {
        final candidates = list.where((f) => f.id.contains(keyword)).toList()
          ..sort((a, b) => b.minLevel.compareTo(a.minLevel));
        if (candidates.isNotEmpty) {
          return candidates.first;
        }
      }

      for (final keyword in keywords) {
        final cleanKeyword = keyword.replaceAll('_', ' ');
        final candidates = list
            .where((f) => f.nameEn.toLowerCase().contains(cleanKeyword))
            .toList()
          ..sort((a, b) => b.minLevel.compareTo(a.minLevel));
        if (candidates.isNotEmpty) {
          return candidates.first;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Deep search failed: $e');
      return null;
    }
  }

  CharacterFeature? findResourceFeature(String id) {
    try {
      return character.features.where((f) => f.id == id).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  List<CharacterFeature> deduplicateAndFilterFeatures(
      List<CharacterFeature> list, String locale) {
    debugPrint('--- Smart Deduplicating ${list.length} features ---');
    try {
      final bestFeatures = <String, CharacterFeature>{};

      for (final feature in list) {
        final groupKey = feature.getName(locale).toLowerCase().trim();

        var baseName = groupKey;
        final upgradeRegex = RegExp(r'^(.*?)\s*\(.*?\)$');
        if (upgradeRegex.hasMatch(groupKey)) {
          baseName = upgradeRegex.firstMatch(groupKey)!.group(1)!.trim();
        }

        if (!bestFeatures.containsKey(baseName)) {
          bestFeatures[baseName] = feature;
          continue;
        }

        final existing = bestFeatures[baseName]!;
        if (feature.minLevel > existing.minLevel) {
          bestFeatures[baseName] = feature;
          continue;
        }

        if (feature.minLevel == existing.minLevel &&
            feature.id.length > existing.id.length) {
          bestFeatures[baseName] = feature;
        }
      }

      final finalMap = <String, CharacterFeature>{};
      for (final feature in bestFeatures.values) {
        var baseId = feature.id;
        final versionRegex = RegExp(r'(_|-)\d+$');
        if (versionRegex.hasMatch(baseId)) {
          baseId = baseId.replaceAll(versionRegex, '');
        }

        if (!finalMap.containsKey(baseId) ||
            feature.minLevel > finalMap[baseId]!.minLevel) {
          finalMap[baseId] = feature;
        }
      }

      return finalMap.values.toList();
    } catch (e) {
      debugPrint('Error in smart deduplication: $e');
      return list;
    }
  }
}
