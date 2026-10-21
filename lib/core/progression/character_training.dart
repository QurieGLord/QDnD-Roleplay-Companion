import '../models/character.dart';
import '../models/item.dart';
import 'character_class_context.dart';
import '../services/feature_service.dart';

class CharacterTraining {
  static Set<String> tokens(Character hero) {
    final result = <String>{};
    for (final entry in hero.classes) {
      result.addAll(entry.entryProficiencies);
      if (!entry.isPrimary) continue;
      final data = CharacterClassContext(hero, entry.id).definition;
      if (data == null) continue;
      if (data.armorProficiencies.light) result.add('armor:light');
      if (data.armorProficiencies.medium) result.add('armor:medium');
      if (data.armorProficiencies.heavy) result.add('armor:heavy');
      if (data.armorProficiencies.shields) result.add('armor:shield');
      if (data.weaponProficiencies.simple) result.add('weapon:simple');
      if (data.weaponProficiencies.martial) result.add('weapon:martial');
      for (final name in data.weaponProficiencies.specific) {
        result.add('weapon:${name.toLowerCase()}');
      }
    }
    return result;
  }

  static bool? weapon(Character hero, Item item) {
    final tags =
        item.weaponProperties?.weaponTags.map((v) => v.toLowerCase()).toSet() ??
            {};
    final training = tokens(hero);
    String key(String value) =>
        value.toLowerCase().replaceAll(RegExp('[^a-z0-9а-яё]'), '');
    final names = {key(item.id), key(item.nameEn), key(item.nameRu)};
    if (training
        .where((t) => t.startsWith('weapon:'))
        .any((t) => names.contains(key(t.substring(7))))) {
      return true;
    }
    if (tags.contains('simple')) return training.contains('weapon:simple');
    if (tags.contains('martial')) return training.contains('weapon:martial');
    return null;
  }

  static int attacks(Character hero) {
    var count = 1;
    for (final f in hero.features) {
      if (!f.id.contains('extra-attack')) continue;
      if (f.associatedClass != null &&
          !CharacterClassContext(
                  hero, FeatureService.classKey(f.associatedClass!))
              .canUseFeature(f)) {
        continue;
      }
      final extra = int.tryParse(
          RegExp(r'^extra-attack-(\d+)$').firstMatch(f.id)?.group(1) ?? '');
      final value = extra == null ? 2 : extra + 1;
      if (value > count) count = value;
    }
    return count;
  }

  static String label(String token, String locale) {
    final ru = locale == 'ru';
    final pairs = {
      'armor:light': ('Лёгкие доспехи', 'Light armor'),
      'armor:medium': ('Средние доспехи', 'Medium armor'),
      'armor:heavy': ('Тяжёлые доспехи', 'Heavy armor'),
      'armor:shield': ('Щиты', 'Shields'),
      'weapon:simple': ('Простое оружие', 'Simple weapons'),
      'weapon:martial': ('Воинское оружие', 'Martial weapons'),
      'weapon:shortsword': ('Короткие мечи', 'Shortswords'),
      'tool:thieves-tools': ('Воровские инструменты', 'Thieves’ tools')
    };
    final value = pairs[token];
    if (value != null) return ru ? value.$1 : value.$2;
    if (token.startsWith('instrument:')) {
      return '${ru ? 'Инструмент' : 'Instrument'}: ${token.substring(11)}';
    }
    return token.contains(':')
        ? token.substring(token.indexOf(':') + 1)
        : token;
  }
}
