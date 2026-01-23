// D&D 5e Ability Scores
enum AbilityScore {
  strength,
  dexterity,
  constitution,
  intelligence,
  wisdom,
  charisma;

  String get shortName {
    switch (this) {
      case AbilityScore.strength:
        return 'STR';
      case AbilityScore.dexterity:
        return 'DEX';
      case AbilityScore.constitution:
        return 'CON';
      case AbilityScore.intelligence:
        return 'INT';
      case AbilityScore.wisdom:
        return 'WIS';
      case AbilityScore.charisma:
        return 'CHA';
    }
  }

  String get displayName {
    switch (this) {
      case AbilityScore.strength:
        return 'Strength';
      case AbilityScore.dexterity:
        return 'Dexterity';
      case AbilityScore.constitution:
        return 'Constitution';
      case AbilityScore.intelligence:
        return 'Intelligence';
      case AbilityScore.wisdom:
        return 'Wisdom';
      case AbilityScore.charisma:
        return 'Charisma';
    }
  }
}

// Character Classes
enum CharacterClass {
  barbarian,
  bard,
  cleric,
  druid,
  fighter,
  monk,
  paladin,
  ranger,
  rogue,
  sorcerer,
  warlock,
  wizard,
  artificer;

  String get displayName {
    return name[0].toUpperCase() + name.substring(1);
  }

  int get hitDie {
    switch (this) {
      case CharacterClass.barbarian:
        return 12;
      case CharacterClass.bard:
      case CharacterClass.cleric:
      case CharacterClass.druid:
      case CharacterClass.monk:
      case CharacterClass.rogue:
      case CharacterClass.warlock:
        return 8;
      case CharacterClass.fighter:
      case CharacterClass.paladin:
      case CharacterClass.ranger:
        return 10;
      case CharacterClass.sorcerer:
      case CharacterClass.wizard:
        return 6;
      case CharacterClass.artificer:
        return 8;
    }
  }
}
