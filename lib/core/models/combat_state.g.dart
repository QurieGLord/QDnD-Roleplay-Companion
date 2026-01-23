// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'combat_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CombatStateAdapter extends TypeAdapter<CombatState> {
  @override
  final int typeId = 15;

  @override
  CombatState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CombatState(
      isInCombat: fields[0] as bool,
      currentRound: fields[1] as int,
      initiative: fields[2] as int,
      combatLog: (fields[3] as List?)?.cast<CombatLogEntry>(),
      totalDamageDealt: fields[4] as int,
      totalDamageTaken: fields[5] as int,
      totalHealing: fields[6] as int,
      combatStartTime: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, CombatState obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.isInCombat)
      ..writeByte(1)
      ..write(obj.currentRound)
      ..writeByte(2)
      ..write(obj.initiative)
      ..writeByte(3)
      ..write(obj.combatLog)
      ..writeByte(4)
      ..write(obj.totalDamageDealt)
      ..writeByte(5)
      ..write(obj.totalDamageTaken)
      ..writeByte(6)
      ..write(obj.totalHealing)
      ..writeByte(7)
      ..write(obj.combatStartTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CombatStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CombatLogEntryAdapter extends TypeAdapter<CombatLogEntry> {
  @override
  final int typeId = 16;

  @override
  CombatLogEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CombatLogEntry(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      type: fields[2] as CombatLogType,
      amount: fields[3] as int?,
      description: fields[4] as String?,
      round: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CombatLogEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.round);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CombatLogEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CombatLogTypeAdapter extends TypeAdapter<CombatLogType> {
  @override
  final int typeId = 17;

  @override
  CombatLogType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CombatLogType.damage;
      case 1:
        return CombatLogType.healing;
      case 2:
        return CombatLogType.deathSave;
      case 3:
        return CombatLogType.conditionAdded;
      case 4:
        return CombatLogType.conditionRemoved;
      case 5:
        return CombatLogType.concentrationCheck;
      case 6:
        return CombatLogType.roundStart;
      case 7:
        return CombatLogType.other;
      default:
        return CombatLogType.damage;
    }
  }

  @override
  void write(BinaryWriter writer, CombatLogType obj) {
    switch (obj) {
      case CombatLogType.damage:
        writer.writeByte(0);
        break;
      case CombatLogType.healing:
        writer.writeByte(1);
        break;
      case CombatLogType.deathSave:
        writer.writeByte(2);
        break;
      case CombatLogType.conditionAdded:
        writer.writeByte(3);
        break;
      case CombatLogType.conditionRemoved:
        writer.writeByte(4);
        break;
      case CombatLogType.concentrationCheck:
        writer.writeByte(5);
        break;
      case CombatLogType.roundStart:
        writer.writeByte(6);
        break;
      case CombatLogType.other:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CombatLogTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
