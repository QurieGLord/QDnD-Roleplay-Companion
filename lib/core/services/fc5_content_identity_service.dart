import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'catalog_definition_signature.dart';
import 'qdnd_bundle_codec.dart';
import '../models/background_data.dart';
import '../models/character_feature.dart';
import '../models/class_data.dart';
import '../models/item.dart';
import '../models/race_data.dart';
import '../models/spell.dart';
import 'fc5_imported_name_normalizer.dart';
import 'fc5_parser.dart';

class FC5ContentIdentityService {
  static const Map<String, String> _classAliases = {
    'паладин': 'paladin',
    'воин': 'fighter',
    'варвар': 'barbarian',
    'монах': 'monk',
    'плут': 'rogue',
    'разбойник': 'rogue',
    'следопыт': 'ranger',
    'рейнджер': 'ranger',
    'друид': 'druid',
    'жрец': 'cleric',
    'клирик': 'cleric',
    'волшебник': 'wizard',
    'маг': 'wizard',
    'чародей': 'sorcerer',
    'колдун': 'warlock',
    'бард': 'bard',
    'изобретатель': 'artificer',
    'paladin': 'paladin',
    'fighter': 'fighter',
    'barbarian': 'barbarian',
    'monk': 'monk',
    'rogue': 'rogue',
    'ranger': 'ranger',
    'druid': 'druid',
    'cleric': 'cleric',
    'wizard': 'wizard',
    'sorcerer': 'sorcerer',
    'warlock': 'warlock',
    'bard': 'bard',
    'artificer': 'artificer',
  };

  static const Map<String, String> _subclassAliases = {
    'berserker': 'berserker',
    'path of the berserker': 'berserker',
    'путь берсерка': 'berserker',
    'берсерк': 'berserker',
    'lore': 'college of lore',
    'college of lore': 'college of lore',
    'коллегия знаний': 'college of lore',
    'land': 'circle of the land',
    'circle of land': 'circle of the land',
    'open hand': 'way of the open hand',
    'way of the open hand': 'way of the open hand',
    'путь открытой ладони': 'way of the open hand',
    'thief': 'thief',
    'вор': 'thief',
    'hunter': 'hunter',
    'охотник': 'hunter',
    'draconic': 'draconic bloodline',
    'draconic bloodline': 'draconic bloodline',
    'драконья кровь': 'draconic bloodline',
    'fiend': 'the fiend',
    'the fiend': 'the fiend',
    'бестия': 'the fiend',
    'evocation': 'school of evocation',
    'school of evocation': 'school of evocation',
    'школа воплощения': 'school of evocation',
    'школа эвокации': 'school of evocation',
    'devotion': 'oath of devotion',
    'oath devotion': 'oath of devotion',
    'oath of devotion': 'oath of devotion',
    'клятва преданности': 'oath of devotion',
    'клятва древних': 'oath of the ancients',
    'oath of the ancients': 'oath of the ancients',
    'клятва мести': 'oath of vengeance',
    'oath of vengeance': 'oath of vengeance',
    'клятва покорения': 'oath of conquest',
    'oath of conquest': 'oath of conquest',
    'клятва славы': 'oath of glory',
    'oath of glory': 'oath of glory',
    'клятва искупления': 'oath of redemption',
    'oath of redemption': 'oath of redemption',
    'клятва смотрителей': 'oath of the watchers',
    'клятва стражей': 'oath of the watchers',
    'oath of the watchers': 'oath of the watchers',
    'life': 'life domain',
    'life domain': 'life domain',
    'домен жизни': 'life domain',
    'домен бури': 'tempest domain',
    'tempest domain': 'tempest domain',
    'домен войны': 'war domain',
    'war domain': 'war domain',
    'домен знаний': 'knowledge domain',
    'knowledge domain': 'knowledge domain',
    'домен света': 'light domain',
    'light domain': 'light domain',
    'домен обмана': 'trickery domain',
    'trickery domain': 'trickery domain',
    'домен природы': 'nature domain',
    'nature domain': 'nature domain',
    'champion': 'champion',
    'чемпион': 'champion',
    'battle master': 'battle master',
    'мастер боевых искусств': 'battle master',
    'eldritch knight': 'eldritch knight',
    'мистический рыцарь': 'eldritch knight',
    'circle of the moon': 'circle of the moon',
    'круг луны': 'circle of the moon',
    'circle of the land': 'circle of the land',
    'круг земли': 'circle of the land',
  };

  static Set<String> itemKeys(Item item) {
    final suffix = [
      item.type.name,
      if (item.weaponProperties != null) item.weaponProperties!.damageType.name,
      if (item.armorProperties != null) item.armorProperties!.armorType.name,
    ].join(':');
    return _localizedNameKeys(
      'item',
      [item.id, item.nameEn, item.nameRu],
      suffix,
    );
  }

  static Set<String> spellKeys(Spell spell) {
    return _localizedNameKeys(
      'spell',
      [spell.id, spell.nameEn, spell.nameRu],
      '${spell.level}:${_normalize(spell.school)}',
    );
  }

  static Set<String> raceKeys(RaceData race) {
    return _localizedNameKeys(
      'race',
      [race.id, ...race.name.values],
      '',
    );
  }

  static Set<String> backgroundKeys(BackgroundData background) {
    return _localizedNameKeys(
      'background',
      [background.id, ...background.name.values],
      '',
    );
  }

  static Set<String> featKeys(CharacterFeature feat) {
    return _localizedNameKeys(
      'feat',
      [feat.id, feat.nameEn, feat.nameRu],
      '',
    );
  }

  static Set<String> classKeys(ClassData classData) {
    final classId = classIdFromClassData(classData);
    return {
      'class:$classId',
      ..._localizedNameKeys('class', classData.name.values, ''),
    };
  }

  static Set<String> subclassKeys(
    ClassData classData,
    SubclassData subclass,
  ) {
    final classId = classIdFromClassData(classData);
    return _localizedNameKeys(
      'subclass:$classId',
      [subclass.id, ...subclass.name.values],
      '',
      canonicalize: canonicalSubclassName,
    );
  }

  static Set<String> featureKeys(CharacterFeature feature) {
    final classId = canonicalClassId(feature.associatedClass ?? '');
    final subclassId = canonicalSubclassName(feature.associatedSubclass ?? '');
    final prefix = [
      'feature',
      classId,
      subclassId,
      feature.minLevel,
    ].join(':');
    return _localizedNameKeys(
      prefix,
      [feature.id, feature.nameEn, feature.nameRu],
      '',
      canonicalize: _canonicalFeatureName,
    );
  }

  static String classIdFromClassData(ClassData classData) {
    for (final value in [classData.id, ...classData.name.values]) {
      final id = canonicalClassId(value);
      if (id.isNotEmpty && _classAliases.containsValue(id)) return id;
    }
    return _normalize(classData.name['en'] ?? classData.id)
        .replaceAll(' ', '_');
  }

  static String canonicalClassId(String value) {
    final normalized = _normalize(value)
        .replaceFirst(RegExp(r'^fc5 [^ ]+ class '), '')
        .replaceFirst(RegExp(r'^fc5 [^ ]+ [^ ]+ class '), '');
    return _classAliases[normalized] ?? normalized.replaceAll(' ', '_');
  }

  static String canonicalSubclassName(String value) {
    final normalized = _normalize(value)
        .replaceFirst(RegExp(r'^oath (?!of )'), 'oath of ')
        .replaceFirst(RegExp(r'^circle (?!of )'), 'circle of ');
    return _subclassAliases[normalized] ?? normalized;
  }

  static Set<String> _localizedNameKeys(
    String prefix,
    Iterable<String> names,
    String suffix, {
    String Function(String value)? canonicalize,
  }) {
    final result = <String>{};
    for (final rawName in names) {
      final normalized = _normalize(rawName);
      if (normalized.isEmpty) continue;
      final canonical = canonicalize?.call(normalized) ?? normalized;
      final fullSuffix = suffix.isEmpty ? '' : ':$suffix';
      result.add('$prefix:$canonical$fullSuffix');
    }
    return result;
  }

  static String _canonicalFeatureName(String value) {
    return _normalize(value)
        .replaceFirst(
            RegExp(
                r'\s*\(\d+(?:\s*/\s*(?:\d+|(?:short|long)\s+rest|rest|отдых))?\s*(?:uses?|раз|заряд(?:а|ов)?)?\)$'),
            '')
        .trim();
  }

  static String _normalize(String value) {
    return FC5ImportedNameNormalizer.normalizedDisplayName(value)
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'[^a-zа-я0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class FC5CompendiumDeduplicationStats {
  int items = 0;
  int spells = 0;
  int races = 0;
  int classes = 0;
  int subclasses = 0;
  int backgrounds = 0;
  int feats = 0;
  int features = 0;

  int get total =>
      items +
      spells +
      races +
      classes +
      subclasses +
      backgrounds +
      feats +
      features;
}

class FC5CompendiumDeduplicationResult {
  const FC5CompendiumDeduplicationResult({
    required this.parseResult,
    required this.stats,
  });

  final FC5ParseResult parseResult;
  final FC5CompendiumDeduplicationStats stats;
}

class FC5CompendiumDeduplicationService {
  /// Source ownership matters: independent books retain their definitions even
  /// when they overlap. Removing one book must not erase another's content.
  static FC5CompendiumDeduplicationResult dedupe(FC5ParseResult input) {
    final stats = FC5CompendiumDeduplicationStats();
    final diagnostics = input.diagnostics.copy();
    List<T> filter<T>(List<T> values, String kind, String Function(T) idFor,
        Map<String, dynamic> Function(T) jsonFor, void Function() skipped,
        {T Function(T, String)? variant}) {
      final groups = <String, Map<String, T>>{};
      final result = <T>[];
      for (final value in values) {
        final id = idFor(value);
        final signature = CatalogDefinitionSignature.of(jsonFor(value));
        final group = groups.putIfAbsent(id, () => {});
        if (group.containsKey(signature)) {
          skipped();
        } else {
          group[signature] = value;
        }
      }
      for (final entry in groups.entries) {
        if (entry.value.length == 1) {
          result.add(entry.value.values.single);
          continue;
        }
        // FC5 entities have no standard identity field: our generated ID is
        // based on their display name. A collision of that name is not proof
        // that the book contradicts itself. Preserve every distinct variant.
        if (variant != null && entry.key.startsWith('fc5_')) {
          diagnostics.warning('named_variants_preserved',
              'Different same-name definitions were preserved as separate variants.',
              context: '$kind:${entry.value.length}');
          for (final version in entry.value.entries) {
            final digest = sha256.convert(utf8.encode(version.key)).toString();
            result.add(variant(version.value, '${entry.key}__$digest'));
          }
        } else {
          diagnostics.error('conflicting_entity_id',
              'Two different definitions share one ID in the same source. No content can be safely installed.',
              context: '$kind:${entry.key}');
          result.addAll(entry.value.values);
        }
      }
      return result;
    }

    final items = filter(input.items, 'item', (v) => v.id, (v) => v.toJson(),
        () => stats.items++,
        variant: (v, id) => Item.fromJson({...v.toJson(), 'id': id}));
    final spells = filter(input.spells, 'spell', (v) => v.id, (v) => v.toJson(),
        () => stats.spells++,
        variant: (v, id) => Spell.fromJson({...v.toJson(), 'id': id}));
    final races = filter(input.races, 'race', (v) => v.id,
        QdndBundleCodec.raceToJson, () => stats.races++,
        variant: (v, id) => QdndBundleCodec.raceFromJson(
            {...QdndBundleCodec.raceToJson(v), 'id': id}));
    final classes = filter(input.classes, 'class', (v) => v.id,
        QdndBundleCodec.classToJson, () => stats.classes++);
    final backgrounds = filter(input.backgrounds, 'background', (v) => v.id,
        QdndBundleCodec.backgroundToJson, () => stats.backgrounds++,
        variant: (v, id) => QdndBundleCodec.backgroundFromJson(
            {...QdndBundleCodec.backgroundToJson(v), 'id': id}));
    final feats = filter(input.feats, 'feat', (v) => v.id, (v) => v.toJson(),
        () => stats.feats++,
        variant: (v, id) =>
            CharacterFeature.fromJson({...v.toJson(), 'id': id}));
    if (stats.total > 0) {
      diagnostics.info('duplicates_skipped',
          'Skipped ${stats.total} exact repetitions within this source.',
          context: '${stats.total}');
    }
    return FC5CompendiumDeduplicationResult(
        parseResult: FC5ParseResult(
            items: items,
            spells: spells,
            races: races,
            classes: classes,
            backgrounds: backgrounds,
            feats: feats,
            diagnostics: diagnostics),
        stats: stats);
  }
}
