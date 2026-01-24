import 'package:hive/hive.dart';

part 'character_feature.g.dart';

/// Universal model for ALL D&D 5e class features
/// Examples: Rage, Ki Points, Channel Divinity, Lay on Hands, Sneak Attack, etc.
@HiveType(typeId: 4)
class CharacterFeature extends HiveObject {
  @HiveField(0)
  String id; // e.g., "lay_on_hands", "channel_divinity_devotion"

  @HiveField(1)
  String nameEn;

  @HiveField(2)
  String nameRu;

  @HiveField(3)
  String descriptionEn;

  @HiveField(4)
  String descriptionRu;

  @HiveField(5)
  FeatureType type; // passive, action, bonus_action, reaction, resource_pool

  @HiveField(6)
  ResourcePool? resourcePool; // For features with limited uses

  @HiveField(7)
  int minLevel; // Minimum character level to gain this feature

  @HiveField(8)
  String? associatedClass; // e.g., "Paladin", "Monk"

  @HiveField(9)
  String? associatedSubclass; // e.g., "Oath of Devotion", "Way of the Open Hand"

  @HiveField(10)
  bool requiresRest; // Does it require a rest to use?

  @HiveField(11)
  String? actionEconomy; // "action", "bonus_action", "reaction", "free"

  @HiveField(12)
  String? iconName; // For UI display

  @HiveField(13)
  FeatureConsumption? consumption; // Links to another feature's resource pool

  CharacterFeature({
    required this.id,
    required this.nameEn,
    required this.nameRu,
    required this.descriptionEn,
    required this.descriptionRu,
    required this.type,
    this.resourcePool,
    required this.minLevel,
    this.associatedClass,
    this.associatedSubclass,
    this.requiresRest = false,
    this.actionEconomy,
    this.iconName,
    this.consumption,
  });

  String getName(String locale) {
    return locale == 'ru' ? nameRu : nameEn;
  }

  String getDescription(String locale) {
    return locale == 'ru' ? descriptionRu : descriptionEn;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nameEn': nameEn,
      'nameRu': nameRu,
      'descriptionEn': descriptionEn,
      'descriptionRu': descriptionRu,
      'type': type.toString(),
      'resourcePool': resourcePool?.toJson(),
      'minLevel': minLevel,
      'associatedClass': associatedClass,
      'associatedSubclass': associatedSubclass,
      'requiresRest': requiresRest,
      'actionEconomy': actionEconomy,
      'iconName': iconName,
      'consumption': consumption?.toJson(),
    };
  }

  factory CharacterFeature.fromJson(Map<String, dynamic> json) {
    return CharacterFeature(
      id: json['id'],
      nameEn: json['nameEn'],
      nameRu: json['nameRu'],
      descriptionEn: json['descriptionEn'],
      descriptionRu: json['descriptionRu'],
      type: FeatureType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => FeatureType.passive,
      ),
      resourcePool: json['resourcePool'] != null
          ? ResourcePool.fromJson(json['resourcePool'])
          : null,
      minLevel: json['minLevel'],
      associatedClass: json['associatedClass'],
      associatedSubclass: json['associatedSubclass'],
      requiresRest: json['requiresRest'] ?? false,
      actionEconomy: json['actionEconomy'],
      iconName: json['iconName'],
      consumption: json['consumption'] != null
          ? FeatureConsumption.fromJson(json['consumption'])
          : null,
    );
  }
}

@HiveType(typeId: 8)
class FeatureConsumption extends HiveObject {
  @HiveField(0)
  String resourceId;

  @HiveField(1)
  int amount;

  FeatureConsumption({required this.resourceId, required this.amount});

  Map<String, dynamic> toJson() => {
    'resourceId': resourceId,
    'amount': amount,
  };

  factory FeatureConsumption.fromJson(Map<String, dynamic> json) {
    return FeatureConsumption(
      resourceId: json['resourceId'],
      amount: json['amount'],
    );
  }
}

/// Resource pool for features with limited uses
@HiveType(typeId: 5)
class ResourcePool extends HiveObject {
  @HiveField(0)
  int currentUses;

  @HiveField(1)
  int maxUses;

  @HiveField(2)
  RecoveryType recoveryType; // short_rest, long_rest, dawn, per_turn

  @HiveField(3)
  String? calculationFormula; // e.g., "level * 5" for Lay on Hands, "1 + cha_mod" for Divine Sense

  ResourcePool({
    required this.currentUses,
    required this.maxUses,
    required this.recoveryType,
    this.calculationFormula,
  });

  void use(int amount) {
    currentUses = (currentUses - amount).clamp(0, maxUses);
    // Note: Save manually after calling this method
  }

  void restore(int amount) {
    currentUses = (currentUses + amount).clamp(0, maxUses);
    // Note: Save manually after calling this method
  }

  void restoreFull() {
    currentUses = maxUses;
    // Note: Save manually after calling this method
  }

  bool get isEmpty => currentUses == 0;
  bool get isFull => currentUses == maxUses;

  Map<String, dynamic> toJson() {
    return {
      'currentUses': currentUses,
      'maxUses': maxUses,
      'recoveryType': recoveryType.toString(),
      'calculationFormula': calculationFormula,
    };
  }

  factory ResourcePool.fromJson(Map<String, dynamic> json) {
    return ResourcePool(
      currentUses: json['currentUses'],
      maxUses: json['maxUses'],
      recoveryType: RecoveryType.values.firstWhere(
        (e) => e.toString() == json['recoveryType'],
        orElse: () => RecoveryType.longRest,
      ),
      calculationFormula: json['calculationFormula'],
    );
  }
}

/// Type of character feature
@HiveType(typeId: 6)
enum FeatureType {
  @HiveField(0)
  passive,        // Always active (Unarmored Defense, Danger Sense)

  @HiveField(1)
  action,         // Takes an action (Attack, Dash, Channel Divinity)

  @HiveField(2)
  bonusAction,    // Takes bonus action (Rage, Cunning Action)

  @HiveField(3)
  reaction,       // Takes reaction (Opportunity Attack, Shield spell)

  @HiveField(4)
  resourcePool,   // Has limited uses (Ki Points, Sorcery Points, Lay on Hands)

  @HiveField(5)
  toggle,         // Can be turned on/off (Rage, Bladesong)
}

/// How the resource pool recovers
@HiveType(typeId: 7)
enum RecoveryType {
  @HiveField(0)
  shortRest,      // Recovers on short or long rest

  @HiveField(1)
  longRest,       // Recovers only on long rest

  @HiveField(2)
  dawn,           // Recovers at dawn (some features)

  @HiveField(3)
  perTurn,        // Recovers each turn (some reactions)

  @HiveField(4)
  recharge,       // Recharge on specific roll (dragon breath)

  @HiveField(5)
  manual,         // Must be manually restored
}
