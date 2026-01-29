// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'race_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RaceDataAdapter extends TypeAdapter<RaceData> {
  @override
  final int typeId = 31;

  @override
  RaceData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RaceData(
      id: fields[0] as String,
      name: (fields[1] as Map).cast<String, String>(),
      description: (fields[2] as Map).cast<String, String>(),
      speed: fields[3] as int,
      abilityScoreIncreases: (fields[4] as Map).cast<String, int>(),
      languages: (fields[5] as List).cast<String>(),
      proficiencies: (fields[6] as List).cast<String>(),
      traits: (fields[7] as List).cast<CharacterFeature>(),
      subraces: (fields[8] as List).cast<SubraceData>(),
      size: fields[9] as String,
      sourceId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RaceData obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.speed)
      ..writeByte(4)
      ..write(obj.abilityScoreIncreases)
      ..writeByte(5)
      ..write(obj.languages)
      ..writeByte(6)
      ..write(obj.proficiencies)
      ..writeByte(7)
      ..write(obj.traits)
      ..writeByte(8)
      ..write(obj.subraces)
      ..writeByte(9)
      ..write(obj.size)
      ..writeByte(10)
      ..write(obj.sourceId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RaceDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SubraceDataAdapter extends TypeAdapter<SubraceData> {
  @override
  final int typeId = 32;

  @override
  SubraceData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SubraceData(
      id: fields[0] as String,
      name: (fields[1] as Map).cast<String, String>(),
      additionalAbilityScores: (fields[2] as Map).cast<String, int>(),
      additionalTraits: (fields[3] as List).cast<CharacterFeature>(),
    );
  }

  @override
  void write(BinaryWriter writer, SubraceData obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.additionalAbilityScores)
      ..writeByte(3)
      ..write(obj.additionalTraits);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubraceDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
