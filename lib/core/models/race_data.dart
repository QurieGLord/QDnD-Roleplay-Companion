import 'package:hive/hive.dart';
import 'package:xml/xml.dart';
import 'character_feature.dart';

part 'race_data.g.dart';

@HiveType(typeId: 31)
class RaceData {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final Map<String, String> name; // {'en': 'Human', 'ru': 'Человек'}

  @HiveField(2)
  final Map<String, String> description;

  @HiveField(3)
  final int speed;

  @HiveField(4)
  final Map<String, int> abilityScoreIncreases; // {'strength': 1, 'all': 1}

  @HiveField(5)
  final List<String> languages;

  @HiveField(6)
  final List<String> proficiencies;

  @HiveField(7)
  final List<CharacterFeature> traits;

  @HiveField(8)
  final List<SubraceData> subraces;

  @HiveField(9)
  final String size;

  @HiveField(10)
  final String? sourceId;

  RaceData({
    required this.id,
    required this.name,
    required this.description,
    required this.speed,
    required this.abilityScoreIncreases,
    required this.languages,
    required this.proficiencies,
    required this.traits,
    this.subraces = const [],
    this.size = 'Medium',
    this.sourceId,
  });

  String getName(String locale) {
    return name[locale] ?? name['en'] ?? id;
  }

  String getDescription(String locale) {
    return description[locale] ?? description['en'] ?? '';
  }

  factory RaceData.fromJson(Map<String, dynamic> json) {
    // Support both "abilityScoreIncrease" and "abilityScoreIncreases" for compatibility
    final abilityScores = json['abilityScoreIncreases'] ?? json['abilityScoreIncrease'] ?? {};

    // Parse traits - convert old format to CharacterFeature
    List<CharacterFeature> parsedTraits = [];
    if (json['traits'] != null) {
      final traitsJson = json['traits'];
      if (traitsJson is Map) {
        // Localized format: {"en": ["Darkvision", ...], "ru": ["Темное зрение", ...]}
        // This is tricky because we need to merge en/ru into single Features.
        // For simplicity in JSON migration, we'll take 'en' as primary and create features.
        // A better approach for the future is to update JSONs to have feature objects.
        // Here we just make best effort.
        final enTraits = List<String>.from(traitsJson['en'] ?? []);
        final ruTraits = List<String>.from(traitsJson['ru'] ?? []);

        for (int i = 0; i < enTraits.length; i++) {
            parsedTraits.add(CharacterFeature(
                id: 'trait_${enTraits[i].toLowerCase().replaceAll(' ', '_')}',
                nameEn: enTraits[i],
                nameRu: i < ruTraits.length ? ruTraits[i] : enTraits[i],
                descriptionEn: enTraits[i], // JSON traits were just names/short desc
                descriptionRu: i < ruTraits.length ? ruTraits[i] : enTraits[i],
                type: FeatureType.passive,
                minLevel: 1,
            ));
        }

      } else if (traitsJson is List) {
        // Simple format: [...]
         for (var t in traitsJson) {
            parsedTraits.add(CharacterFeature(
                id: 'trait_${t.toString().toLowerCase().replaceAll(' ', '_')}',
                nameEn: t.toString(),
                nameRu: t.toString(),
                descriptionEn: t.toString(),
                descriptionRu: t.toString(),
                type: FeatureType.passive,
                minLevel: 1,
            ));
         }
      }
    }

    return RaceData(
      id: json['id'],
      name: Map<String, String>.from(json['name']),
      description: Map<String, String>.from(json['description']),
      speed: json['speed'] ?? 30,
      abilityScoreIncreases: Map<String, int>.from(abilityScores),
      languages: List<String>.from(json['languages'] ?? []),
      proficiencies: List<String>.from(json['proficiencies'] ?? []),
      traits: parsedTraits,
      subraces: (json['subraces'] as List?)
          ?.map((s) => SubraceData.fromJson(s))
          .toList() ?? [],
      size: json['size'] ?? 'Medium',
    );
  }

  factory RaceData.fromFC5(XmlElement element, String sourceId) {
    final name = element.findElements('name').first.innerText;
    final size = element.findElements('size').firstOrNull?.innerText ?? 'Medium';
    final speedStr = element.findElements('speed').firstOrNull?.innerText ?? '30';
    final speed = int.tryParse(speedStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 30;

    final traits = <CharacterFeature>[];
    for (var traitElement in element.findElements('trait')) {
      final traitName = traitElement.findElements('name').firstOrNull?.innerText ?? '';
      final traitText = traitElement.findElements('text').map((e) => e.innerText).join('\n');
      
      if (traitName.isNotEmpty) {
        traits.add(CharacterFeature(
          id: 'fc5_${traitName.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
          nameEn: traitName,
          nameRu: traitName, // FC5 is typically EN only
          descriptionEn: traitText,
          descriptionRu: traitText,
          type: FeatureType.passive,
          minLevel: 1,
          sourceId: sourceId,
        ));
      }
    }

    return RaceData(
      id: name.toLowerCase().replaceAll(' ', '_'),
      name: {'en': name, 'ru': name},
      description: {'en': 'Imported from FC5', 'ru': 'Импортировано из FC5'},
      speed: speed,
      abilityScoreIncreases: {}, // Parsing ability scores from FC5 text is complex, leaving empty for now
      languages: [], // Parsing languages requires mapping, leaving empty
      proficiencies: [],
      traits: traits,
      subraces: [], // Subraces handling can be added later
      size: size,
      sourceId: sourceId,
    );
  }
}

@HiveType(typeId: 32)
class SubraceData {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final Map<String, String> name;

  @HiveField(2)
  final Map<String, int> additionalAbilityScores;

  @HiveField(3)
  final List<CharacterFeature> additionalTraits;

  SubraceData({
    required this.id,
    required this.name,
    required this.additionalAbilityScores,
    required this.additionalTraits,
  });

  String getName(String locale) {
    return name[locale] ?? name['en'] ?? id;
  }

  factory SubraceData.fromJson(Map<String, dynamic> json) {
    final abilityScores = json['additionalAbilityScores'] ?? json['abilityScoreIncrease'] ?? {};

    List<CharacterFeature> parsedTraits = [];
    final traitsJson = json['additionalTraits'] ?? json['traits'];
    
    if (traitsJson != null) {
      if (traitsJson is Map) {
        final enTraits = List<String>.from(traitsJson['en'] ?? []);
        final ruTraits = List<String>.from(traitsJson['ru'] ?? []);
        for (int i = 0; i < enTraits.length; i++) {
            parsedTraits.add(CharacterFeature(
                id: 'subtrait_${enTraits[i].toLowerCase().replaceAll(' ', '_')}',
                nameEn: enTraits[i],
                nameRu: i < ruTraits.length ? ruTraits[i] : enTraits[i],
                descriptionEn: enTraits[i],
                descriptionRu: i < ruTraits.length ? ruTraits[i] : enTraits[i],
                type: FeatureType.passive,
                minLevel: 1,
            ));
        }
      } else if (traitsJson is List) {
         for (var t in traitsJson) {
            parsedTraits.add(CharacterFeature(
                id: 'subtrait_${t.toString().toLowerCase().replaceAll(' ', '_')}',
                nameEn: t.toString(),
                nameRu: t.toString(),
                descriptionEn: t.toString(),
                descriptionRu: t.toString(),
                type: FeatureType.passive,
                minLevel: 1,
            ));
         }
      }
    }

    return SubraceData(
      id: json['id'],
      name: Map<String, String>.from(json['name'] ?? {'en': json['id']}),
      additionalAbilityScores: Map<String, int>.from(abilityScores),
      additionalTraits: parsedTraits,
    );
  }
}
