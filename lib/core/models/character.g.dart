// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CharacterAdapter extends TypeAdapter<Character> {
  @override
  final int typeId = 0;

  @override
  Character read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Character(
      id: fields[0] as String,
      name: fields[1] as String,
      avatarPath: fields[2] as String?,
      race: fields[3] as String,
      characterClass: fields[4] as String,
      subclass: fields[5] as String?,
      level: fields[6] as int,
      maxHp: fields[7] as int,
      currentHp: fields[8] as int,
      temporaryHp: fields[9] as int,
      abilityScores: fields[10] as AbilityScores,
      background: fields[11] as String?,
      spellSlots: (fields[12] as List).cast<int>(),
      maxSpellSlots: (fields[13] as List).cast<int>(),
      armorClass: fields[14] as int,
      speed: fields[15] as int,
      initiative: fields[16] as int,
      proficientSkills: (fields[17] as List).cast<String>(),
      savingThrowProficiencies: (fields[18] as List).cast<String>(),
      personalityTraits: fields[19] as String?,
      ideals: fields[20] as String?,
      bonds: fields[21] as String?,
      flaws: fields[22] as String?,
      backstory: fields[23] as String?,
      createdAt: fields[24] as DateTime?,
      updatedAt: fields[25] as DateTime?,
      appearance: fields[26] as String?,
      knownSpells: (fields[27] as List?)?.cast<String>(),
      preparedSpells: (fields[28] as List?)?.cast<String>(),
      maxPreparedSpells: fields[29] as int,
      features: (fields[30] as List?)?.cast<CharacterFeature>(),
      inventory: (fields[31] as List?)?.cast<Item>(),
      combatState: fields[32] as CombatState?,
      deathSaves: fields[33] as DeathSaves?,
      activeConditions: (fields[34] as List?)?.cast<ConditionType>(),
      concentratingOn: fields[35] as String?,
      hitDice: (fields[36] as List?)?.cast<int>(),
      maxHitDice: fields[37] as int?,
      age: fields[38] as String?,
      gender: fields[39] as String?,
      height: fields[40] as String?,
      weight: fields[41] as String?,
      eyes: fields[42] as String?,
      hair: fields[43] as String?,
      skin: fields[44] as String?,
      appearanceDescription: fields[45] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Character obj) {
    writer
      ..writeByte(46)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.avatarPath)
      ..writeByte(3)
      ..write(obj.race)
      ..writeByte(4)
      ..write(obj.characterClass)
      ..writeByte(5)
      ..write(obj.subclass)
      ..writeByte(6)
      ..write(obj.level)
      ..writeByte(7)
      ..write(obj.maxHp)
      ..writeByte(8)
      ..write(obj.currentHp)
      ..writeByte(9)
      ..write(obj.temporaryHp)
      ..writeByte(10)
      ..write(obj.abilityScores)
      ..writeByte(11)
      ..write(obj.background)
      ..writeByte(12)
      ..write(obj.spellSlots)
      ..writeByte(13)
      ..write(obj.maxSpellSlots)
      ..writeByte(14)
      ..write(obj.armorClass)
      ..writeByte(15)
      ..write(obj.speed)
      ..writeByte(16)
      ..write(obj.initiative)
      ..writeByte(17)
      ..write(obj.proficientSkills)
      ..writeByte(18)
      ..write(obj.savingThrowProficiencies)
      ..writeByte(19)
      ..write(obj.personalityTraits)
      ..writeByte(20)
      ..write(obj.ideals)
      ..writeByte(21)
      ..write(obj.bonds)
      ..writeByte(22)
      ..write(obj.flaws)
      ..writeByte(23)
      ..write(obj.backstory)
      ..writeByte(24)
      ..write(obj.createdAt)
      ..writeByte(25)
      ..write(obj.updatedAt)
      ..writeByte(26)
      ..write(obj.appearance)
      ..writeByte(27)
      ..write(obj.knownSpells)
      ..writeByte(28)
      ..write(obj.preparedSpells)
      ..writeByte(29)
      ..write(obj.maxPreparedSpells)
      ..writeByte(30)
      ..write(obj.features)
      ..writeByte(31)
      ..write(obj.inventory)
      ..writeByte(32)
      ..write(obj.combatState)
      ..writeByte(33)
      ..write(obj.deathSaves)
      ..writeByte(34)
      ..write(obj.activeConditions)
      ..writeByte(35)
      ..write(obj.concentratingOn)
      ..writeByte(36)
      ..write(obj.hitDice)
      ..writeByte(37)
      ..write(obj.maxHitDice)
      ..writeByte(38)
      ..write(obj.age)
      ..writeByte(39)
      ..write(obj.gender)
      ..writeByte(40)
      ..write(obj.height)
      ..writeByte(41)
      ..write(obj.weight)
      ..writeByte(42)
      ..write(obj.eyes)
      ..writeByte(43)
      ..write(obj.hair)
      ..writeByte(44)
      ..write(obj.skin)
      ..writeByte(45)
      ..write(obj.appearanceDescription);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
