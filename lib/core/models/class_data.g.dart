// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClassDataAdapter extends TypeAdapter<ClassData> {
  @override
  final int typeId = 33;

  @override
  ClassData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClassData(
      id: fields[0] as String,
      name: (fields[1] as Map).cast<String, String>(),
      description: (fields[2] as Map).cast<String, String>(),
      hitDie: fields[3] as int,
      primaryAbilities: (fields[4] as List).cast<String>(),
      savingThrowProficiencies: (fields[5] as List).cast<String>(),
      armorProficiencies: fields[6] as ArmorProficiencies,
      weaponProficiencies: fields[7] as WeaponProficiencies,
      skillProficiencies: fields[8] as SkillProficiencies,
      subclasses: (fields[9] as List).cast<SubclassData>(),
      subclassLevel: fields[10] as int,
      spellcasting: fields[11] as SpellcastingInfo?,
      features: (fields[12] as Map).map((dynamic k, dynamic v) =>
          MapEntry(k as int, (v as List).cast<CharacterFeature>())),
      sourceId: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ClassData obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.hitDie)
      ..writeByte(4)
      ..write(obj.primaryAbilities)
      ..writeByte(5)
      ..write(obj.savingThrowProficiencies)
      ..writeByte(6)
      ..write(obj.armorProficiencies)
      ..writeByte(7)
      ..write(obj.weaponProficiencies)
      ..writeByte(8)
      ..write(obj.skillProficiencies)
      ..writeByte(9)
      ..write(obj.subclasses)
      ..writeByte(10)
      ..write(obj.subclassLevel)
      ..writeByte(11)
      ..write(obj.spellcasting)
      ..writeByte(12)
      ..write(obj.features)
      ..writeByte(13)
      ..write(obj.sourceId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ArmorProficienciesAdapter extends TypeAdapter<ArmorProficiencies> {
  @override
  final int typeId = 35;

  @override
  ArmorProficiencies read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArmorProficiencies(
      light: fields[0] as bool,
      medium: fields[1] as bool,
      heavy: fields[2] as bool,
      shields: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ArmorProficiencies obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.light)
      ..writeByte(1)
      ..write(obj.medium)
      ..writeByte(2)
      ..write(obj.heavy)
      ..writeByte(3)
      ..write(obj.shields);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArmorProficienciesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WeaponProficienciesAdapter extends TypeAdapter<WeaponProficiencies> {
  @override
  final int typeId = 36;

  @override
  WeaponProficiencies read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeaponProficiencies(
      simple: fields[0] as bool,
      martial: fields[1] as bool,
      specific: (fields[2] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, WeaponProficiencies obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.simple)
      ..writeByte(1)
      ..write(obj.martial)
      ..writeByte(2)
      ..write(obj.specific);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeaponProficienciesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SkillProficienciesAdapter extends TypeAdapter<SkillProficiencies> {
  @override
  final int typeId = 37;

  @override
  SkillProficiencies read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SkillProficiencies(
      choose: fields[0] as int,
      from: (fields[1] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, SkillProficiencies obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.choose)
      ..writeByte(1)
      ..write(obj.from);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillProficienciesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SubclassDataAdapter extends TypeAdapter<SubclassData> {
  @override
  final int typeId = 34;

  @override
  SubclassData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SubclassData(
      id: fields[0] as String,
      name: (fields[1] as Map).cast<String, String>(),
      description: (fields[2] as Map).cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, SubclassData obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubclassDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SpellcastingInfoAdapter extends TypeAdapter<SpellcastingInfo> {
  @override
  final int typeId = 38;

  @override
  SpellcastingInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SpellcastingInfo(
      ability: fields[0] as String,
      type: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SpellcastingInfo obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.ability)
      ..writeByte(1)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpellcastingInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
