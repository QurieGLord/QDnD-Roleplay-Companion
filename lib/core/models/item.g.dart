// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final int typeId = 8;

  @override
  Item read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Item(
      id: fields[0] as String,
      nameEn: fields[1] as String,
      nameRu: fields[2] as String,
      descriptionEn: fields[3] as String,
      descriptionRu: fields[4] as String,
      type: fields[5] as ItemType,
      rarity: fields[6] as ItemRarity,
      quantity: fields[7] as int,
      weight: fields[8] as double,
      valueInCopper: fields[9] as int,
      isEquipped: fields[10] as bool,
      isAttuned: fields[11] as bool,
      weaponProperties: fields[12] as WeaponProperties?,
      armorProperties: fields[13] as ArmorProperties?,
      isMagical: fields[14] as bool,
      iconName: fields[15] as String?,
      customImagePath: fields[16] as String?,
      sourceId: fields[17] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nameEn)
      ..writeByte(2)
      ..write(obj.nameRu)
      ..writeByte(3)
      ..write(obj.descriptionEn)
      ..writeByte(4)
      ..write(obj.descriptionRu)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.rarity)
      ..writeByte(7)
      ..write(obj.quantity)
      ..writeByte(8)
      ..write(obj.weight)
      ..writeByte(9)
      ..write(obj.valueInCopper)
      ..writeByte(10)
      ..write(obj.isEquipped)
      ..writeByte(11)
      ..write(obj.isAttuned)
      ..writeByte(12)
      ..write(obj.weaponProperties)
      ..writeByte(13)
      ..write(obj.armorProperties)
      ..writeByte(14)
      ..write(obj.isMagical)
      ..writeByte(15)
      ..write(obj.iconName)
      ..writeByte(16)
      ..write(obj.customImagePath)
      ..writeByte(17)
      ..write(obj.sourceId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WeaponPropertiesAdapter extends TypeAdapter<WeaponProperties> {
  @override
  final int typeId = 9;

  @override
  WeaponProperties read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeaponProperties(
      damageDice: fields[0] as String,
      damageType: fields[1] as DamageType,
      weaponTags: (fields[2] as List).cast<String>(),
      range: fields[3] as int?,
      longRange: fields[4] as int?,
      versatileDamageDice: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WeaponProperties obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.damageDice)
      ..writeByte(1)
      ..write(obj.damageType)
      ..writeByte(2)
      ..write(obj.weaponTags)
      ..writeByte(3)
      ..write(obj.range)
      ..writeByte(4)
      ..write(obj.longRange)
      ..writeByte(5)
      ..write(obj.versatileDamageDice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeaponPropertiesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ArmorPropertiesAdapter extends TypeAdapter<ArmorProperties> {
  @override
  final int typeId = 10;

  @override
  ArmorProperties read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArmorProperties(
      baseAC: fields[0] as int,
      armorType: fields[1] as ArmorType,
      addDexModifier: fields[2] as bool,
      maxDexBonus: fields[3] as int?,
      strengthRequirement: fields[4] as int?,
      stealthDisadvantage: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ArmorProperties obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.baseAC)
      ..writeByte(1)
      ..write(obj.armorType)
      ..writeByte(2)
      ..write(obj.addDexModifier)
      ..writeByte(3)
      ..write(obj.maxDexBonus)
      ..writeByte(4)
      ..write(obj.strengthRequirement)
      ..writeByte(5)
      ..write(obj.stealthDisadvantage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArmorPropertiesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ItemTypeAdapter extends TypeAdapter<ItemType> {
  @override
  final int typeId = 11;

  @override
  ItemType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ItemType.weapon;
      case 1:
        return ItemType.armor;
      case 2:
        return ItemType.consumable;
      case 3:
        return ItemType.tool;
      case 4:
        return ItemType.gear;
      case 5:
        return ItemType.treasure;
      default:
        return ItemType.weapon;
    }
  }

  @override
  void write(BinaryWriter writer, ItemType obj) {
    switch (obj) {
      case ItemType.weapon:
        writer.writeByte(0);
        break;
      case ItemType.armor:
        writer.writeByte(1);
        break;
      case ItemType.consumable:
        writer.writeByte(2);
        break;
      case ItemType.tool:
        writer.writeByte(3);
        break;
      case ItemType.gear:
        writer.writeByte(4);
        break;
      case ItemType.treasure:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ItemRarityAdapter extends TypeAdapter<ItemRarity> {
  @override
  final int typeId = 12;

  @override
  ItemRarity read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ItemRarity.common;
      case 1:
        return ItemRarity.uncommon;
      case 2:
        return ItemRarity.rare;
      case 3:
        return ItemRarity.veryRare;
      case 4:
        return ItemRarity.legendary;
      case 5:
        return ItemRarity.artifact;
      default:
        return ItemRarity.common;
    }
  }

  @override
  void write(BinaryWriter writer, ItemRarity obj) {
    switch (obj) {
      case ItemRarity.common:
        writer.writeByte(0);
        break;
      case ItemRarity.uncommon:
        writer.writeByte(1);
        break;
      case ItemRarity.rare:
        writer.writeByte(2);
        break;
      case ItemRarity.veryRare:
        writer.writeByte(3);
        break;
      case ItemRarity.legendary:
        writer.writeByte(4);
        break;
      case ItemRarity.artifact:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemRarityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DamageTypeAdapter extends TypeAdapter<DamageType> {
  @override
  final int typeId = 13;

  @override
  DamageType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DamageType.slashing;
      case 1:
        return DamageType.piercing;
      case 2:
        return DamageType.bludgeoning;
      case 3:
        return DamageType.acid;
      case 4:
        return DamageType.cold;
      case 5:
        return DamageType.fire;
      case 6:
        return DamageType.force;
      case 7:
        return DamageType.lightning;
      case 8:
        return DamageType.necrotic;
      case 9:
        return DamageType.poison;
      case 10:
        return DamageType.psychic;
      case 11:
        return DamageType.radiant;
      case 12:
        return DamageType.thunder;
      default:
        return DamageType.slashing;
    }
  }

  @override
  void write(BinaryWriter writer, DamageType obj) {
    switch (obj) {
      case DamageType.slashing:
        writer.writeByte(0);
        break;
      case DamageType.piercing:
        writer.writeByte(1);
        break;
      case DamageType.bludgeoning:
        writer.writeByte(2);
        break;
      case DamageType.acid:
        writer.writeByte(3);
        break;
      case DamageType.cold:
        writer.writeByte(4);
        break;
      case DamageType.fire:
        writer.writeByte(5);
        break;
      case DamageType.force:
        writer.writeByte(6);
        break;
      case DamageType.lightning:
        writer.writeByte(7);
        break;
      case DamageType.necrotic:
        writer.writeByte(8);
        break;
      case DamageType.poison:
        writer.writeByte(9);
        break;
      case DamageType.psychic:
        writer.writeByte(10);
        break;
      case DamageType.radiant:
        writer.writeByte(11);
        break;
      case DamageType.thunder:
        writer.writeByte(12);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DamageTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ArmorTypeAdapter extends TypeAdapter<ArmorType> {
  @override
  final int typeId = 14;

  @override
  ArmorType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ArmorType.light;
      case 1:
        return ArmorType.medium;
      case 2:
        return ArmorType.heavy;
      case 3:
        return ArmorType.shield;
      default:
        return ArmorType.light;
    }
  }

  @override
  void write(BinaryWriter writer, ArmorType obj) {
    switch (obj) {
      case ArmorType.light:
        writer.writeByte(0);
        break;
      case ArmorType.medium:
        writer.writeByte(1);
        break;
      case ArmorType.heavy:
        writer.writeByte(2);
        break;
      case ArmorType.shield:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArmorTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
