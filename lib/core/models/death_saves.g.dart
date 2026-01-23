// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'death_saves.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeathSavesAdapter extends TypeAdapter<DeathSaves> {
  @override
  final int typeId = 18;

  @override
  DeathSaves read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeathSaves(
      successes: fields[0] as int,
      failures: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DeathSaves obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.successes)
      ..writeByte(1)
      ..write(obj.failures);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeathSavesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
