// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'condition.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConditionTypeAdapter extends TypeAdapter<ConditionType> {
  @override
  final int typeId = 19;

  @override
  ConditionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ConditionType.blinded;
      case 1:
        return ConditionType.charmed;
      case 2:
        return ConditionType.deafened;
      case 3:
        return ConditionType.frightened;
      case 4:
        return ConditionType.grappled;
      case 5:
        return ConditionType.incapacitated;
      case 6:
        return ConditionType.invisible;
      case 7:
        return ConditionType.paralyzed;
      case 8:
        return ConditionType.petrified;
      case 9:
        return ConditionType.poisoned;
      case 10:
        return ConditionType.prone;
      case 11:
        return ConditionType.restrained;
      case 12:
        return ConditionType.stunned;
      case 13:
        return ConditionType.unconscious;
      default:
        return ConditionType.blinded;
    }
  }

  @override
  void write(BinaryWriter writer, ConditionType obj) {
    switch (obj) {
      case ConditionType.blinded:
        writer.writeByte(0);
        break;
      case ConditionType.charmed:
        writer.writeByte(1);
        break;
      case ConditionType.deafened:
        writer.writeByte(2);
        break;
      case ConditionType.frightened:
        writer.writeByte(3);
        break;
      case ConditionType.grappled:
        writer.writeByte(4);
        break;
      case ConditionType.incapacitated:
        writer.writeByte(5);
        break;
      case ConditionType.invisible:
        writer.writeByte(6);
        break;
      case ConditionType.paralyzed:
        writer.writeByte(7);
        break;
      case ConditionType.petrified:
        writer.writeByte(8);
        break;
      case ConditionType.poisoned:
        writer.writeByte(9);
        break;
      case ConditionType.prone:
        writer.writeByte(10);
        break;
      case ConditionType.restrained:
        writer.writeByte(11);
        break;
      case ConditionType.stunned:
        writer.writeByte(12);
        break;
      case ConditionType.unconscious:
        writer.writeByte(13);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConditionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
