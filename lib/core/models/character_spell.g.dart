// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_spell.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CharacterSpellAdapter extends TypeAdapter<CharacterSpell> {
  @override
  final int typeId = 3;

  @override
  CharacterSpell read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CharacterSpell(
      spellId: fields[0] as String,
      isPrepared: fields[1] as bool,
      isAlwaysPrepared: fields[2] as bool,
      source: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CharacterSpell obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.spellId)
      ..writeByte(1)
      ..write(obj.isPrepared)
      ..writeByte(2)
      ..write(obj.isAlwaysPrepared)
      ..writeByte(3)
      ..write(obj.source);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterSpellAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
