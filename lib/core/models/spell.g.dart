// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spell.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SpellAdapter extends TypeAdapter<Spell> {
  @override
  final int typeId = 2;

  @override
  Spell read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Spell(
      id: fields[0] as String,
      nameEn: fields[1] as String,
      nameRu: fields[2] as String,
      level: fields[3] as int,
      school: fields[4] as String,
      castingTime: fields[5] as String,
      range: fields[6] as String,
      duration: fields[7] as String,
      concentration: fields[8] as bool,
      ritual: fields[9] as bool,
      components: (fields[10] as List).cast<String>(),
      materialComponents: fields[11] as String?,
      materialComponentsRu: fields[17] as String?,
      descriptionEn: fields[12] as String,
      descriptionRu: fields[13] as String,
      availableToClasses: (fields[14] as List).cast<String>(),
      atHigherLevelsEn: fields[15] as String?,
      atHigherLevelsRu: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Spell obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nameEn)
      ..writeByte(2)
      ..write(obj.nameRu)
      ..writeByte(3)
      ..write(obj.level)
      ..writeByte(4)
      ..write(obj.school)
      ..writeByte(5)
      ..write(obj.castingTime)
      ..writeByte(6)
      ..write(obj.range)
      ..writeByte(7)
      ..write(obj.duration)
      ..writeByte(8)
      ..write(obj.concentration)
      ..writeByte(9)
      ..write(obj.ritual)
      ..writeByte(10)
      ..write(obj.components)
      ..writeByte(11)
      ..write(obj.materialComponents)
      ..writeByte(17)
      ..write(obj.materialComponentsRu)
      ..writeByte(12)
      ..write(obj.descriptionEn)
      ..writeByte(13)
      ..write(obj.descriptionRu)
      ..writeByte(14)
      ..write(obj.availableToClasses)
      ..writeByte(15)
      ..write(obj.atHigherLevelsEn)
      ..writeByte(16)
      ..write(obj.atHigherLevelsRu);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpellAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
