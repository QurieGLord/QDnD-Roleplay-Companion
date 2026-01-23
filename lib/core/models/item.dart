import 'package:hive/hive.dart';

part 'item.g.dart';

/// Universal model for ALL D&D 5e items and equipment
/// Examples: Longsword, Chain Mail, Potion of Healing, Rope, etc.
@HiveType(typeId: 8)
class Item extends HiveObject {
  @HiveField(0)
  String id; // e.g., "longsword", "chain_mail", "potion_healing"

  @HiveField(1)
  String nameEn;

  @HiveField(2)
  String nameRu;

  @HiveField(3)
  String descriptionEn;

  @HiveField(4)
  String descriptionRu;

  @HiveField(5)
  ItemType type; // weapon, armor, consumable, tool, gear, treasure

  @HiveField(6)
  ItemRarity rarity; // common, uncommon, rare, very_rare, legendary, artifact

  @HiveField(7)
  int quantity; // Number of items in this stack

  @HiveField(8)
  double weight; // Weight in pounds (lb)

  @HiveField(9)
  int valueInCopper; // Value in copper pieces (1 gp = 100 cp)

  @HiveField(10)
  bool isEquipped; // Is the item currently equipped?

  @HiveField(11)
  bool isAttuned; // Is the item attuned (for magical items)?

  @HiveField(12)
  WeaponProperties? weaponProperties; // For weapons only

  @HiveField(13)
  ArmorProperties? armorProperties; // For armor only

  @HiveField(14)
  bool isMagical; // Is this a magical item?

  @HiveField(15)
  String? iconName; // For UI display

  @HiveField(16)
  String? customImagePath; // Path to custom image for user-created items

  Item({
    required this.id,
    required this.nameEn,
    required this.nameRu,
    required this.descriptionEn,
    required this.descriptionRu,
    required this.type,
    required this.rarity,
    this.quantity = 1,
    this.weight = 0.0,
    this.valueInCopper = 0,
    this.isEquipped = false,
    this.isAttuned = false,
    this.weaponProperties,
    this.armorProperties,
    this.isMagical = false,
    this.iconName,
    this.customImagePath,
  });

  String getName(String locale) {
    return locale == 'ru' ? nameRu : nameEn;
  }

  String getDescription(String locale) {
    return locale == 'ru' ? descriptionRu : descriptionEn;
  }

  /// Get value in gold pieces (gp)
  double get valueInGold => valueInCopper / 100.0;

  /// Get total weight for this stack
  double get totalWeight => weight * quantity;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nameEn': nameEn,
      'nameRu': nameRu,
      'descriptionEn': descriptionEn,
      'descriptionRu': descriptionRu,
      'type': type.toString(),
      'rarity': rarity.toString(),
      'quantity': quantity,
      'weight': weight,
      'valueInCopper': valueInCopper,
      'isEquipped': isEquipped,
      'isAttuned': isAttuned,
      'weaponProperties': weaponProperties?.toJson(),
      'armorProperties': armorProperties?.toJson(),
      'isMagical': isMagical,
      'iconName': iconName,
      'customImagePath': customImagePath,
    };
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      nameEn: json['nameEn'],
      nameRu: json['nameRu'],
      descriptionEn: json['descriptionEn'],
      descriptionRu: json['descriptionRu'],
      type: ItemType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ItemType.gear,
      ),
      rarity: ItemRarity.values.firstWhere(
        (e) => e.toString() == json['rarity'],
        orElse: () => ItemRarity.common,
      ),
      quantity: json['quantity'] ?? 1,
      weight: json['weight']?.toDouble() ?? 0.0,
      valueInCopper: json['valueInCopper'] ?? 0,
      isEquipped: json['isEquipped'] ?? false,
      isAttuned: json['isAttuned'] ?? false,
      weaponProperties: json['weaponProperties'] != null
          ? WeaponProperties.fromJson(json['weaponProperties'])
          : null,
      armorProperties: json['armorProperties'] != null
          ? ArmorProperties.fromJson(json['armorProperties'])
          : null,
      isMagical: json['isMagical'] ?? false,
      iconName: json['iconName'],
      customImagePath: json['customImagePath'],
    );
  }
}

/// Properties for weapons
@HiveType(typeId: 9)
class WeaponProperties extends HiveObject {
  @HiveField(0)
  String damageDice; // e.g., "1d8", "2d6"

  @HiveField(1)
  DamageType damageType; // slashing, piercing, bludgeoning, etc.

  @HiveField(2)
  List<String> weaponTags; // finesse, versatile, two-handed, heavy, light, etc.

  @HiveField(3)
  int? range; // Range in feet (for ranged weapons)

  @HiveField(4)
  int? longRange; // Long range in feet

  @HiveField(5)
  String? versatileDamageDice; // For versatile weapons (e.g., "1d10")

  WeaponProperties({
    required this.damageDice,
    required this.damageType,
    this.weaponTags = const [],
    this.range,
    this.longRange,
    this.versatileDamageDice,
  });

  Map<String, dynamic> toJson() {
    return {
      'damageDice': damageDice,
      'damageType': damageType.toString(),
      'weaponTags': weaponTags,
      'range': range,
      'longRange': longRange,
      'versatileDamageDice': versatileDamageDice,
    };
  }

  factory WeaponProperties.fromJson(Map<String, dynamic> json) {
    return WeaponProperties(
      damageDice: json['damageDice'],
      damageType: DamageType.values.firstWhere(
        (e) => e.toString() == json['damageType'],
        orElse: () => DamageType.slashing,
      ),
      weaponTags: List<String>.from(json['weaponTags'] ?? []),
      range: json['range'],
      longRange: json['longRange'],
      versatileDamageDice: json['versatileDamageDice'],
    );
  }
}

/// Properties for armor
@HiveType(typeId: 10)
class ArmorProperties extends HiveObject {
  @HiveField(0)
  int baseAC; // Base armor class

  @HiveField(1)
  ArmorType armorType; // light, medium, heavy, shield

  @HiveField(2)
  bool addDexModifier; // Does it add DEX modifier to AC?

  @HiveField(3)
  int? maxDexBonus; // Maximum DEX bonus (for medium armor)

  @HiveField(4)
  int? strengthRequirement; // Minimum STR to wear without penalty

  @HiveField(5)
  bool stealthDisadvantage; // Does it impose disadvantage on Stealth?

  ArmorProperties({
    required this.baseAC,
    required this.armorType,
    this.addDexModifier = false,
    this.maxDexBonus,
    this.strengthRequirement,
    this.stealthDisadvantage = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'baseAC': baseAC,
      'armorType': armorType.toString(),
      'addDexModifier': addDexModifier,
      'maxDexBonus': maxDexBonus,
      'strengthRequirement': strengthRequirement,
      'stealthDisadvantage': stealthDisadvantage,
    };
  }

  factory ArmorProperties.fromJson(Map<String, dynamic> json) {
    return ArmorProperties(
      baseAC: json['baseAC'],
      armorType: ArmorType.values.firstWhere(
        (e) => e.toString() == json['armorType'],
        orElse: () => ArmorType.light,
      ),
      addDexModifier: json['addDexModifier'] ?? false,
      maxDexBonus: json['maxDexBonus'],
      strengthRequirement: json['strengthRequirement'],
      stealthDisadvantage: json['stealthDisadvantage'] ?? false,
    );
  }
}

/// Type of item
@HiveType(typeId: 11)
enum ItemType {
  @HiveField(0)
  weapon,

  @HiveField(1)
  armor,

  @HiveField(2)
  consumable, // Potions, scrolls, food

  @HiveField(3)
  tool, // Thieves' tools, herbalism kit, etc.

  @HiveField(4)
  gear, // Rope, torches, backpack, etc.

  @HiveField(5)
  treasure, // Gems, art objects, coins
}

/// Rarity of item
@HiveType(typeId: 12)
enum ItemRarity {
  @HiveField(0)
  common,

  @HiveField(1)
  uncommon,

  @HiveField(2)
  rare,

  @HiveField(3)
  veryRare,

  @HiveField(4)
  legendary,

  @HiveField(5)
  artifact,
}

/// Damage type for weapons
@HiveType(typeId: 13)
enum DamageType {
  @HiveField(0)
  slashing,

  @HiveField(1)
  piercing,

  @HiveField(2)
  bludgeoning,

  @HiveField(3)
  acid,

  @HiveField(4)
  cold,

  @HiveField(5)
  fire,

  @HiveField(6)
  force,

  @HiveField(7)
  lightning,

  @HiveField(8)
  necrotic,

  @HiveField(9)
  poison,

  @HiveField(10)
  psychic,

  @HiveField(11)
  radiant,

  @HiveField(12)
  thunder,
}

/// Type of armor
@HiveType(typeId: 14)
enum ArmorType {
  @HiveField(0)
  light, // Leather, studded leather

  @HiveField(1)
  medium, // Hide, chain shirt, scale mail

  @HiveField(2)
  heavy, // Ring mail, chain mail, plate

  @HiveField(3)
  shield, // Shield (not technically armor but similar)
}
