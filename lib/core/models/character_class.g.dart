// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_class.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CharacterClassAdapter extends TypeAdapter<CharacterClass> {
  @override
  final int typeId = 8;

  @override
  CharacterClass read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CharacterClass(
      id: fields[0] as String,
      name: fields[1] as String,
      level: fields[2] as int,
      subclass: fields[3] as String?,
      isPrimary: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CharacterClass obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.level)
      ..writeByte(3)
      ..write(obj.subclass)
      ..writeByte(4)
      ..write(obj.isPrimary);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterClassAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
