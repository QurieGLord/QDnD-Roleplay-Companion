// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BackgroundDataAdapter extends TypeAdapter<BackgroundData> {
  @override
  final int typeId = 39;

  @override
  BackgroundData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BackgroundData(
      id: fields[0] as String,
      name: (fields[1] as Map).cast<String, String>(),
      description: (fields[2] as Map).cast<String, String>(),
      skillProficiencies: (fields[3] as List).cast<String>(),
      toolProficiencies: (fields[4] as Map).map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as List).cast<String>())),
      languages: fields[5] as int,
      feature: fields[6] as BackgroundFeature,
      equipment: (fields[7] as Map).map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as List).cast<String>())),
      sourceId: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BackgroundData obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.skillProficiencies)
      ..writeByte(4)
      ..write(obj.toolProficiencies)
      ..writeByte(5)
      ..write(obj.languages)
      ..writeByte(6)
      ..write(obj.feature)
      ..writeByte(7)
      ..write(obj.equipment)
      ..writeByte(8)
      ..write(obj.sourceId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackgroundDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BackgroundFeatureAdapter extends TypeAdapter<BackgroundFeature> {
  @override
  final int typeId = 40;

  @override
  BackgroundFeature read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BackgroundFeature(
      name: (fields[0] as Map).cast<String, String>(),
      description: (fields[1] as Map).cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, BackgroundFeature obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackgroundFeatureAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
