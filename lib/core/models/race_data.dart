class RaceData {
  final String id;
  final Map<String, String> name; // {'en': 'Human', 'ru': 'Человек'}
  final Map<String, String> description;
  final int speed;
  final Map<String, int> abilityScoreIncreases; // {'strength': 1, 'all': 1}
  final List<String> languages;
  final List<String> proficiencies;
  final Map<String, List<String>> traits; // Localized traits
  final List<SubraceData> subraces;

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
  });

  String getName(String locale) {
    return name[locale] ?? name['en'] ?? id;
  }

  String getDescription(String locale) {
    return description[locale] ?? description['en'] ?? '';
  }

  List<String> getTraits(String locale) {
    return traits[locale] ?? traits['en'] ?? [];
  }

  factory RaceData.fromJson(Map<String, dynamic> json) {
    // Support both "abilityScoreIncrease" and "abilityScoreIncreases" for compatibility
    final abilityScores = json['abilityScoreIncreases'] ?? json['abilityScoreIncrease'] ?? {};

    // Parse traits - support both localized Map and simple List
    Map<String, List<String>> traitsMap = {};
    if (json['traits'] != null) {
      final traitsJson = json['traits'];
      if (traitsJson is Map) {
        // Localized format: {"en": [...], "ru": [...]}
        traitsJson.forEach((key, value) {
          if (value is List) {
            traitsMap[key] = List<String>.from(value);
          }
        });
      } else if (traitsJson is List) {
        // Simple format: [...] (backwards compatibility)
        traitsMap['en'] = List<String>.from(traitsJson);
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
      traits: traitsMap,
      subraces: (json['subraces'] as List?)
          ?.map((s) => SubraceData.fromJson(s))
          .toList() ?? [],
    );
  }
}

class SubraceData {
  final String id;
  final Map<String, String> name;
  final Map<String, int> additionalAbilityScores;
  final Map<String, List<String>> additionalTraits; // Localized traits

  SubraceData({
    required this.id,
    required this.name,
    required this.additionalAbilityScores,
    required this.additionalTraits,
  });

  String getName(String locale) {
    return name[locale] ?? name['en'] ?? id;
  }

  List<String> getAdditionalTraits(String locale) {
    return additionalTraits[locale] ?? additionalTraits['en'] ?? [];
  }

  factory SubraceData.fromJson(Map<String, dynamic> json) {
    // Support both "abilityScoreIncrease" and "additionalAbilityScores" for compatibility
    final abilityScores = json['additionalAbilityScores'] ?? json['abilityScoreIncrease'] ?? {};

    // Parse traits - support both localized Map and simple List
    Map<String, List<String>> traitsMap = {};
    final traitsJson = json['additionalTraits'] ?? json['traits'];
    if (traitsJson != null) {
      if (traitsJson is Map) {
        // Localized format: {"en": [...], "ru": [...]}
        traitsJson.forEach((key, value) {
          if (value is List) {
            traitsMap[key] = List<String>.from(value);
          }
        });
      } else if (traitsJson is List) {
        // Simple format: [...] (backwards compatibility)
        traitsMap['en'] = List<String>.from(traitsJson);
      }
    }

    return SubraceData(
      id: json['id'],
      name: Map<String, String>.from(json['name'] ?? {'en': json['id']}),
      additionalAbilityScores: Map<String, int>.from(abilityScores),
      additionalTraits: traitsMap,
    );
  }
}
