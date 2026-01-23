// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_feature.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CharacterFeatureAdapter extends TypeAdapter<CharacterFeature> {
  @override
  final int typeId = 4;

  @override
  CharacterFeature read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CharacterFeature(
      id: fields[0] as String,
      nameEn: fields[1] as String,
      nameRu: fields[2] as String,
      descriptionEn: fields[3] as String,
      descriptionRu: fields[4] as String,
      type: fields[5] as FeatureType,
      resourcePool: fields[6] as ResourcePool?,
      minLevel: fields[7] as int,
      associatedClass: fields[8] as String?,
      associatedSubclass: fields[9] as String?,
      requiresRest: fields[10] as bool,
      actionEconomy: fields[11] as String?,
      iconName: fields[12] as String?,
      consumption: fields[13] as FeatureConsumption?,
    );
  }

  @override
  void write(BinaryWriter writer, CharacterFeature obj) {
    writer
      ..writeByte(14)
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
      ..write(obj.resourcePool)
      ..writeByte(7)
      ..write(obj.minLevel)
      ..writeByte(8)
      ..write(obj.associatedClass)
      ..writeByte(9)
      ..write(obj.associatedSubclass)
      ..writeByte(10)
      ..write(obj.requiresRest)
      ..writeByte(11)
      ..write(obj.actionEconomy)
      ..writeByte(12)
      ..write(obj.iconName)
      ..writeByte(13)
      ..write(obj.consumption);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterFeatureAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FeatureConsumptionAdapter extends TypeAdapter<FeatureConsumption> {
  @override
  final int typeId = 8;

  @override
  FeatureConsumption read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FeatureConsumption(
      resourceId: fields[0] as String,
      amount: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, FeatureConsumption obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.resourceId)
      ..writeByte(1)
      ..write(obj.amount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeatureConsumptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ResourcePoolAdapter extends TypeAdapter<ResourcePool> {
  @override
  final int typeId = 5;

  @override
  ResourcePool read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ResourcePool(
      currentUses: fields[0] as int,
      maxUses: fields[1] as int,
      recoveryType: fields[2] as RecoveryType,
      calculationFormula: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ResourcePool obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.currentUses)
      ..writeByte(1)
      ..write(obj.maxUses)
      ..writeByte(2)
      ..write(obj.recoveryType)
      ..writeByte(3)
      ..write(obj.calculationFormula);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourcePoolAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FeatureTypeAdapter extends TypeAdapter<FeatureType> {
  @override
  final int typeId = 6;

  @override
  FeatureType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FeatureType.passive;
      case 1:
        return FeatureType.action;
      case 2:
        return FeatureType.bonusAction;
      case 3:
        return FeatureType.reaction;
      case 4:
        return FeatureType.resourcePool;
      case 5:
        return FeatureType.toggle;
      default:
        return FeatureType.passive;
    }
  }

  @override
  void write(BinaryWriter writer, FeatureType obj) {
    switch (obj) {
      case FeatureType.passive:
        writer.writeByte(0);
        break;
      case FeatureType.action:
        writer.writeByte(1);
        break;
      case FeatureType.bonusAction:
        writer.writeByte(2);
        break;
      case FeatureType.reaction:
        writer.writeByte(3);
        break;
      case FeatureType.resourcePool:
        writer.writeByte(4);
        break;
      case FeatureType.toggle:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeatureTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecoveryTypeAdapter extends TypeAdapter<RecoveryType> {
  @override
  final int typeId = 7;

  @override
  RecoveryType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RecoveryType.shortRest;
      case 1:
        return RecoveryType.longRest;
      case 2:
        return RecoveryType.dawn;
      case 3:
        return RecoveryType.perTurn;
      case 4:
        return RecoveryType.recharge;
      case 5:
        return RecoveryType.manual;
      default:
        return RecoveryType.shortRest;
    }
  }

  @override
  void write(BinaryWriter writer, RecoveryType obj) {
    switch (obj) {
      case RecoveryType.shortRest:
        writer.writeByte(0);
        break;
      case RecoveryType.longRest:
        writer.writeByte(1);
        break;
      case RecoveryType.dawn:
        writer.writeByte(2);
        break;
      case RecoveryType.perTurn:
        writer.writeByte(3);
        break;
      case RecoveryType.recharge:
        writer.writeByte(4);
        break;
      case RecoveryType.manual:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecoveryTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
