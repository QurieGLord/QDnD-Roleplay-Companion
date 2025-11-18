// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ability_scores.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AbilityScoresAdapter extends TypeAdapter<AbilityScores> {
  @override
  final int typeId = 1;

  @override
  AbilityScores read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AbilityScores(
      strength: fields[0] as int,
      dexterity: fields[1] as int,
      constitution: fields[2] as int,
      intelligence: fields[3] as int,
      wisdom: fields[4] as int,
      charisma: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AbilityScores obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.strength)
      ..writeByte(1)
      ..write(obj.dexterity)
      ..writeByte(2)
      ..write(obj.constitution)
      ..writeByte(3)
      ..write(obj.intelligence)
      ..writeByte(4)
      ..write(obj.wisdom)
      ..writeByte(5)
      ..write(obj.charisma);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbilityScoresAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
