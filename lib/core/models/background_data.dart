import 'package:hive/hive.dart';

part 'background_data.g.dart';

@HiveType(typeId: 39)
class BackgroundData {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final Map<String, String> name;

  @HiveField(2)
  final Map<String, String> description;

  @HiveField(3)
  final List<String> skillProficiencies;

  @HiveField(4)
  final Map<String, List<String>> toolProficiencies; // Localized

  @HiveField(5)
  final int languages; // Number of language choices

  @HiveField(6)
  final BackgroundFeature feature;

  @HiveField(7)
  final Map<String, List<String>> equipment; // Localized

  @HiveField(8)
  final String? sourceId;

  BackgroundData({
    required this.id,
    required this.name,
    required this.description,
    required this.skillProficiencies,
    required this.toolProficiencies,
    required this.languages,
    required this.feature,
    required this.equipment,
    this.sourceId,
  });

  String getName(String locale) {
    return name[locale] ?? name['en'] ?? id;
  }

  String getDescription(String locale) {
    return description[locale] ?? description['en'] ?? '';
  }

  List<String> getToolProficiencies(String locale) {
    return toolProficiencies[locale] ?? toolProficiencies['en'] ?? [];
  }

  List<String> getEquipment(String locale) {
    return equipment[locale] ?? equipment['en'] ?? [];
  }

  factory BackgroundData.fromJson(Map<String, dynamic> json) {
    // Handle toolProficiencies - can be empty Map or localized Map
    Map<String, List<String>> tools = {};
    if (json['toolProficiencies'] != null) {
      final toolsJson = json['toolProficiencies'];
      if (toolsJson is Map) {
        toolsJson.forEach((key, value) {
          if (value is List) {
            tools[key] = List<String>.from(value);
          }
        });
      }
    }

    // Handle equipment
    Map<String, List<String>> equip = {};
    if (json['equipment'] != null) {
      final equipJson = json['equipment'];
      if (equipJson is Map) {
        equipJson.forEach((key, value) {
          if (value is List) {
            equip[key] = List<String>.from(value);
          }
        });
      }
    }

    return BackgroundData(
      id: json['id'],
      name: Map<String, String>.from(json['name']),
      description: Map<String, String>.from(json['description']),
      skillProficiencies: List<String>.from(json['skillProficiencies'] ?? []),
      toolProficiencies: tools,
      languages: json['languages'] ?? 0,
      feature: BackgroundFeature.fromJson(json['feature']),
      equipment: equip,
      sourceId: json['sourceId'],
    );
  }
}

@HiveType(typeId: 40)
class BackgroundFeature {
  @HiveField(0)
  final Map<String, String> name;

  @HiveField(1)
  final Map<String, String> description;

  BackgroundFeature({
    required this.name,
    required this.description,
  });

  String getName(String locale) {
    return name[locale] ?? name['en'] ?? '';
  }

  String getDescription(String locale) {
    return description[locale] ?? description['en'] ?? '';
  }

  factory BackgroundFeature.fromJson(Map<String, dynamic> json) {
    return BackgroundFeature(
      name: Map<String, String>.from(json['name']),
      description: Map<String, String>.from(json['description']),
    );
  }
}
