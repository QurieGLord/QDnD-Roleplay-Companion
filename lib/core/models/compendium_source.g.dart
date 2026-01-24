// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compendium_source.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompendiumSourceAdapter extends TypeAdapter<CompendiumSource> {
  @override
  final int typeId = 26;

  @override
  CompendiumSource read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CompendiumSource(
      id: fields[0] as String,
      name: fields[1] as String,
      importedAt: fields[2] as DateTime,
      itemCount: fields[3] as int,
      spellCount: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CompendiumSource obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.importedAt)
      ..writeByte(3)
      ..write(obj.itemCount)
      ..writeByte(4)
      ..write(obj.spellCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompendiumSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
