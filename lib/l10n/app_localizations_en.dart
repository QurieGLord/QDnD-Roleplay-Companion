// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'QD&D';

  @override
  String get appSubtitle => 'Roleplay Companion';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get characters => 'Characters';

  @override
  String get compendium => 'Compendium';

  @override
  String get diceRoller => 'Dice Roller';

  @override
  String get inventory => 'Inventory';

  @override
  String get spells => 'Spells';

  @override
  String get features => 'Features';

  @override
  String get stats => 'Stats';

  @override
  String get combat => 'Combat';

  @override
  String get notes => 'Notes';

  @override
  String get quests => 'Quests';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get level => 'Level';

  @override
  String get race => 'Race';

  @override
  String get background => 'Background';

  @override
  String get classLabel => 'Class';

  @override
  String get subclass => 'Subclass';

  @override
  String get alignment => 'Alignment';

  @override
  String get experience => 'Experience';

  @override
  String get playerName => 'Player Name';

  @override
  String get createNewCharacter => 'Create New Character';

  @override
  String get importFC5 => 'Import from Fight Club 5';

  @override
  String get viewDetails => 'View Details';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get close => 'Close';

  @override
  String get deleteConfirmationTitle => 'Delete Character';

  @override
  String deleteConfirmationMessage(String name) {
    return 'Are you sure you want to delete $name? This cannot be undone.';
  }

  @override
  String deletedSuccess(String name) {
    return '$name deleted';
  }

  @override
  String duplicatedSuccess(String name) {
    return '$name duplicated successfully!';
  }

  @override
  String importedSuccess(String name) {
    return '$name imported successfully!';
  }

  @override
  String get abilities => 'Abilities';

  @override
  String get savingThrows => 'Saving Throws';

  @override
  String get skills => 'Skills';

  @override
  String get abilityStr => 'Strength';

  @override
  String get abilityDex => 'Dexterity';

  @override
  String get abilityCon => 'Constitution';

  @override
  String get abilityInt => 'Intelligence';

  @override
  String get abilityWis => 'Wisdom';

  @override
  String get abilityCha => 'Charisma';

  @override
  String get skillAthletics => 'Athletics';

  @override
  String get skillAcrobatics => 'Acrobatics';

  @override
  String get skillSleightOfHand => 'Sleight of Hand';

  @override
  String get skillStealth => 'Stealth';

  @override
  String get skillArcana => 'Arcana';

  @override
  String get skillHistory => 'History';

  @override
  String get skillInvestigation => 'Investigation';

  @override
  String get skillNature => 'Nature';

  @override
  String get skillReligion => 'Religion';

  @override
  String get skillAnimalHandling => 'Animal Handling';

  @override
  String get skillInsight => 'Insight';

  @override
  String get skillMedicine => 'Medicine';

  @override
  String get skillPerception => 'Perception';

  @override
  String get skillSurvival => 'Survival';

  @override
  String get skillDeception => 'Deception';

  @override
  String get skillIntimidation => 'Intimidation';

  @override
  String get skillPerformance => 'Performance';

  @override
  String get skillPersuasion => 'Persuasion';

  @override
  String get combatDashboard => 'Combat Dashboard';

  @override
  String get hitPoints => 'Hit Points';

  @override
  String get hpShort => 'HP';

  @override
  String get armorClassAC => 'AC';

  @override
  String get initiativeINIT => 'INIT';

  @override
  String get speedSPEED => 'SPEED';

  @override
  String get proficiencyPROF => 'PROF';

  @override
  String get weaponsAttacks => 'Weapons & Attacks';

  @override
  String get shortRest => 'Short Rest';

  @override
  String get longRest => 'Long Rest';

  @override
  String get enterCombatMode => 'Enter Combat Mode';

  @override
  String get rest => 'Rest';

  @override
  String get shortRestDescription =>
      'Recover short-rest features and spend Hit Dice?';

  @override
  String get longRestDescription =>
      'Recover all HP, spell slots, and features?';

  @override
  String get restedSuccess => 'Rested successfully';

  @override
  String get unarmedStrike => 'Unarmed Strike';

  @override
  String get hit => 'HIT';

  @override
  String get dmg => 'DMG';

  @override
  String get damageTypeBludgeoning => 'Bludgeoning';

  @override
  String get damageTypePiercing => 'Piercing';

  @override
  String get damageTypeSlashing => 'Slashing';

  @override
  String get damageTypePhysical => 'Physical';

  @override
  String get searchItems => 'Search items...';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortName => 'Name';

  @override
  String get sortWeight => 'Weight';

  @override
  String get sortValue => 'Value';

  @override
  String get sortType => 'Type';

  @override
  String get filterAll => 'All';

  @override
  String get filterEquipped => 'Equipped';

  @override
  String get filterUnequipped => 'Unequipped';

  @override
  String get typeWeapon => 'Weapons';

  @override
  String get typeArmor => 'Armor';

  @override
  String get typeGear => 'Gear';

  @override
  String get typeConsumable => 'Consumables';

  @override
  String get totalWeight => 'Total Weight';

  @override
  String get currency => 'Currency';

  @override
  String get editCurrency => 'Edit Currency';

  @override
  String get currencyUpdated => 'Currency updated';

  @override
  String get currencyPP => 'Platinum (PP)';

  @override
  String get currencyGP => 'Gold (GP)';

  @override
  String get currencySP => 'Silver (SP)';

  @override
  String get currencyCP => 'Copper (CP)';

  @override
  String get inventoryEmpty => 'Inventory is empty';

  @override
  String get inventoryEmptyHint => 'Tap + to add items';

  @override
  String get quantity => 'Quantity';

  @override
  String get unequip => 'Unequip';

  @override
  String get equip => 'Equip';

  @override
  String get remove => 'Remove';

  @override
  String get itemRemoved => 'Item removed';

  @override
  String get itemEquipped => 'Equipped';

  @override
  String get itemUnequipped => 'Unequipped';

  @override
  String get weaponProperties => 'WEAPON PROPERTIES';

  @override
  String get armorProperties => 'ARMOR PROPERTIES';

  @override
  String get damage => 'Damage';

  @override
  String get damageType => 'Damage Type';

  @override
  String get versatileDamage => 'Versatile Damage';

  @override
  String get range => 'Range';

  @override
  String get properties => 'Properties';

  @override
  String get armorClass => 'Armor Class';

  @override
  String get type => 'Type';

  @override
  String get strRequirement => 'STR Requirement';

  @override
  String get stealth => 'Stealth';

  @override
  String get disadvantage => 'Disadvantage';

  @override
  String get weight => 'Weight';

  @override
  String get value => 'Value';

  @override
  String get spellAlmanac => 'Spell Almanac';

  @override
  String get resources => 'Resources';

  @override
  String get activeAbilities => 'Active Abilities';

  @override
  String get magic => 'Magic';

  @override
  String get spellsList => 'Spells List';

  @override
  String get passiveTraits => 'Passive Traits';

  @override
  String get cantrips => 'Cantrips';

  @override
  String levelLabel(int level) {
    return 'Level $level';
  }

  @override
  String get levelShort => 'Level';

  @override
  String get noSpellsLearned => 'No spells learned yet';

  @override
  String get castSpell => 'Cast Spell';

  @override
  String castAction(String name) {
    return 'Cast $name';
  }

  @override
  String get chooseSpellSlot => 'Choose spell slot level:';

  @override
  String levelSlot(int level) {
    return 'Level $level Slot';
  }

  @override
  String slotsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's ',
      one: ' ',
    );
    return '$count slot$_temp0 remaining';
  }

  @override
  String get upcast => 'Upcast';

  @override
  String get noSlotsAvailable => 'No spell slots available!';

  @override
  String spellCastSuccess(Object name) {
    return '$name cast!';
  }

  @override
  String spellCastLevelSuccess(Object level, Object name) {
    return '$name cast at level $level!';
  }

  @override
  String get spellAbility => 'Ability';

  @override
  String get spellSaveDC => 'Save DC';

  @override
  String get spellAttack => 'Attack';

  @override
  String lvlShort(int level) {
    return 'Lvl $level';
  }

  @override
  String useChannelDivinity(int count) {
    return 'Use Channel Divinity ($count left)';
  }

  @override
  String get noChannelDivinity => 'No Channel Divinity charges';

  @override
  String get schoolAbjuration => 'Abjuration';

  @override
  String get schoolConjuration => 'Conjuration';

  @override
  String get schoolDivination => 'Divination';

  @override
  String get schoolEnchantment => 'Enchantment';

  @override
  String get schoolEvocation => 'Evocation';

  @override
  String get schoolIllusion => 'Illusion';

  @override
  String get schoolNecromancy => 'Necromancy';

  @override
  String get schoolTransmutation => 'Transmutation';

  @override
  String get combatStats => 'Combat Stats';

  @override
  String get rollInitiative => 'Roll Initiative';

  @override
  String get endCombat => 'End Combat';

  @override
  String get endCombatConfirm => 'This will reset the round counter.';

  @override
  String get nextRound => 'Next Round';

  @override
  String get startCombat => 'Start Combat';

  @override
  String get heal => 'Heal';

  @override
  String get takeDamage => 'Take Damage';

  @override
  String get tempHp => 'Temp HP';

  @override
  String get deathSaves => 'Death Saves';

  @override
  String get successes => 'Successes';

  @override
  String get failures => 'Failures';

  @override
  String get unconscious => 'Unconscious';

  @override
  String get condition => 'Condition';

  @override
  String get conditions => 'Conditions';

  @override
  String get actionTypeAction => 'Action';

  @override
  String get actionTypeBonus => 'Bonus Action';

  @override
  String get actionTypeReaction => 'Reaction';

  @override
  String get spellcastingAbility => 'Spellcasting Ability';

  @override
  String get currencyPP_short => 'pp';

  @override
  String get currencyGP_short => 'gp';

  @override
  String get currencySP_short => 'sp';

  @override
  String get currencyCP_short => 'cp';

  @override
  String get weightUnit => 'lb';

  @override
  String get currencyUnit => 'gp';

  @override
  String get age => 'Age';

  @override
  String get height => 'Height';

  @override
  String get eyes => 'Eyes';

  @override
  String get skin => 'Skin';

  @override
  String get hair => 'Hair';

  @override
  String get appearance => 'Appearance';

  @override
  String get rollType => 'Roll Type';

  @override
  String get normal => 'Normal';

  @override
  String get advantage => 'Advantage';

  @override
  String get modifier => 'Modifier';

  @override
  String get rolling => 'Rolling...';

  @override
  String total(Object value) {
    return 'Total: $value';
  }

  @override
  String get tapToRoll => 'Tap to Roll';

  @override
  String get levelUp => 'Level Up';

  @override
  String get levelUpTitle => 'Level Up';

  @override
  String get currentLevel => 'Current Level';

  @override
  String get nextLevel => 'Next Level';

  @override
  String get hpIncrease => 'HP Increase';

  @override
  String get chooseRace => 'Choose Race';

  @override
  String get chooseClass => 'Choose Class';

  @override
  String hitDieType(Object value) {
    return 'Hit Die: d$value';
  }

  @override
  String get damageTypeAcid => 'Acid';

  @override
  String get damageTypeCold => 'Cold';

  @override
  String get damageTypeFire => 'Fire';

  @override
  String get damageTypeForce => 'Force';

  @override
  String get damageTypeLightning => 'Lightning';

  @override
  String get damageTypeNecrotic => 'Necrotic';

  @override
  String get damageTypePoison => 'Poison';

  @override
  String get damageTypePsychic => 'Psychic';

  @override
  String get damageTypeRadiant => 'Radiant';

  @override
  String get damageTypeThunder => 'Thunder';

  @override
  String conModIs(String value) {
    return 'Your Constitution modifier is $value';
  }

  @override
  String get average => 'Average';

  @override
  String get safeChoice => 'Safe choice';

  @override
  String get roll => 'Roll';

  @override
  String get riskIt => 'Risk it!';

  @override
  String get conditionBlinded => 'Blinded';

  @override
  String get conditionCharmed => 'Charmed';

  @override
  String get conditionDeafened => 'Deafened';

  @override
  String get conditionFrightened => 'Frightened';

  @override
  String get conditionGrappled => 'Grappled';

  @override
  String get conditionIncapacitated => 'Incapacitated';

  @override
  String get conditionInvisible => 'Invisible';

  @override
  String get conditionParalyzed => 'Paralyzed';

  @override
  String get conditionPetrified => 'Petrified';

  @override
  String get conditionPoisoned => 'Poisoned';

  @override
  String get conditionProne => 'Prone';

  @override
  String get conditionRestrained => 'Restrained';

  @override
  String get conditionStunned => 'Stunned';

  @override
  String get conditionUnconscious => 'Unconscious';

  @override
  String get stepBasicInfo => 'Basic Info';

  @override
  String get identity => 'Character Identity';

  @override
  String get identitySubtitle => 'Create the foundation of your character';

  @override
  String get charName => 'Character Name *';

  @override
  String get charNameHint => 'e.g., Gundren Rockseeker';

  @override
  String get alignmentSubtitle => 'Choose your moral compass';

  @override
  String get physicalAppearance => 'Physical Appearance';

  @override
  String get physicalSubtitle => 'Optional details about looks';

  @override
  String get personality => 'Personality';

  @override
  String get personalitySubtitle => 'Traits, ideals, bonds, flaws';

  @override
  String get backstory => 'Backstory';

  @override
  String get backstorySubtitle => 'Your character\'s story';

  @override
  String get backstoryHint => 'Born in a small village...';

  @override
  String get traits => 'Personality Traits';

  @override
  String get traitsHint => 'I am always polite...';

  @override
  String get ideals => 'Ideals';

  @override
  String get idealsHint => 'Justice...';

  @override
  String get bonds => 'Bonds';

  @override
  String get bondsHint => 'I owe my life...';

  @override
  String get flaws => 'Flaws';

  @override
  String get flawsHint => 'I have a weakness...';

  @override
  String get appearanceDesc => 'Appearance Description';

  @override
  String get appearanceHint => 'Tall and muscular...';

  @override
  String get ageYears => 'years';

  @override
  String get gender => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderOther => 'Other';

  @override
  String get genderMaleShort => 'M';

  @override
  String get genderFemaleShort => 'F';

  @override
  String get genderOtherShort => 'Oth';

  @override
  String get chooseRaceClass => 'Choose Race & Class';

  @override
  String get choose => 'Choose';

  @override
  String get raceClassSubtitle => 'Select your character\'s race and class.';

  @override
  String get loadingRaces => 'Loading races...';

  @override
  String get loadingClasses => 'Loading classes...';

  @override
  String speed(int value) {
    return 'Speed: $value ft';
  }

  @override
  String get abilityScoreIncreases => 'Ability Score Increases';

  @override
  String get languages => 'Languages';

  @override
  String get racialTraits => 'Racial Traits';

  @override
  String get savingThrowProficiencies => 'Saving Throw Proficiencies';

  @override
  String get check => 'Check';

  @override
  String get saveLabel => 'Save';

  @override
  String rollDie(int sides) {
    return 'Roll d$sides';
  }

  @override
  String get skillProficiencies => 'Skill Proficiencies';

  @override
  String get armorProficiencies => 'Armor Proficiencies';

  @override
  String get weaponProficiencies => 'Weapon Proficiencies';

  @override
  String get langCommon => 'Common';

  @override
  String get langDwarvish => 'Dwarvish';

  @override
  String get langElvish => 'Elvish';

  @override
  String get langGiant => 'Giant';

  @override
  String get langGnomish => 'Gnomish';

  @override
  String get langGoblin => 'Goblin';

  @override
  String get langHalfling => 'Halfling';

  @override
  String get langOrc => 'Orc';

  @override
  String get langAbyssal => 'Abyssal';

  @override
  String get langCelestial => 'Celestial';

  @override
  String get langDraconic => 'Draconic';

  @override
  String get langDeepSpeech => 'Deep Speech';

  @override
  String get langInfernal => 'Infernal';

  @override
  String get langPrimordial => 'Primordial';

  @override
  String get langSylvan => 'Sylvan';

  @override
  String get langUndercommon => 'Undercommon';

  @override
  String get weaponClub => 'Club';

  @override
  String get weaponDagger => 'Dagger';

  @override
  String get weaponGreatclub => 'Greatclub';

  @override
  String get weaponHandaxe => 'Handaxe';

  @override
  String get weaponJavelin => 'Javelin';

  @override
  String get weaponLightHammer => 'Light Hammer';

  @override
  String get weaponMace => 'Mace';

  @override
  String get weaponQuarterstaff => 'Quarterstaff';

  @override
  String get weaponSickle => 'Sickle';

  @override
  String get weaponSpear => 'Spear';

  @override
  String get weaponLightCrossbow => 'Light Crossbow';

  @override
  String get weaponDart => 'Dart';

  @override
  String get weaponShortbow => 'Shortbow';

  @override
  String get weaponSling => 'Sling';

  @override
  String get weaponBattleaxe => 'Battleaxe';

  @override
  String get weaponFlail => 'Flail';

  @override
  String get weaponGlaive => 'Glaive';

  @override
  String get weaponGreataxe => 'Greataxe';

  @override
  String get weaponGreatsword => 'Greatsword';

  @override
  String get weaponHalberd => 'Halberd';

  @override
  String get weaponLance => 'Lance';

  @override
  String get weaponLongsword => 'Longsword';

  @override
  String get weaponMaul => 'Maul';

  @override
  String get weaponMorningstar => 'Morningstar';

  @override
  String get weaponPike => 'Pike';

  @override
  String get weaponRapier => 'Rapier';

  @override
  String get weaponScimitar => 'Scimitar';

  @override
  String get weaponShortsword => 'Shortsword';

  @override
  String get weaponTrident => 'Trident';

  @override
  String get weaponWarPick => 'War Pick';

  @override
  String get weaponWarhammer => 'Warhammer';

  @override
  String get weaponWhip => 'Whip';

  @override
  String get weaponBlowgun => 'Blowgun';

  @override
  String get weaponHandCrossbow => 'Hand Crossbow';

  @override
  String get weaponHeavyCrossbow => 'Heavy Crossbow';

  @override
  String get weaponLongbow => 'Longbow';

  @override
  String get weaponNet => 'Net';

  @override
  String get selectHeight => 'Select Height';

  @override
  String get selectWeight => 'Select Weight';

  @override
  String get selectEyeColor => 'Select Eye Color';

  @override
  String get selectHairColor => 'Select Hair Color';

  @override
  String get selectSkinTone => 'Select Skin Tone';

  @override
  String get custom => 'Custom';

  @override
  String get customEyeColor => 'Custom Eye Color';

  @override
  String get customHairColor => 'Custom Hair Color';

  @override
  String get customSkinTone => 'Custom Skin Tone';

  @override
  String get enterCustom => 'Enter custom value';

  @override
  String get confirm => 'Confirm';

  @override
  String readyMessage(Object name) {
    return '$name is ready to choose their path!';
  }

  @override
  String get law => 'LAW';

  @override
  String get neutral => 'NEUTRAL';

  @override
  String get chaos => 'CHAOS';

  @override
  String get good => 'GOOD';

  @override
  String get evil => 'EVIL';

  @override
  String get lg => 'Lawful Good';

  @override
  String get ng => 'Neutral Good';

  @override
  String get cg => 'Chaotic Good';

  @override
  String get ln => 'Lawful Neutral';

  @override
  String get tn => 'True Neutral';

  @override
  String get cn => 'Chaotic Neutral';

  @override
  String get le => 'Lawful Evil';

  @override
  String get ne => 'Neutral Evil';

  @override
  String get ce => 'Chaotic Evil';

  @override
  String get lgDesc => 'Honor, compassion, duty';

  @override
  String get ngDesc => 'Kind, helpful, balance';

  @override
  String get cgDesc => 'Freedom, kindness, rebellion';

  @override
  String get lnDesc => 'Order, tradition, law';

  @override
  String get tnDesc => 'Balance, nature, neutrality';

  @override
  String get cnDesc => 'Freedom, unpredictability';

  @override
  String get leDesc => 'Tyranny, order, domination';

  @override
  String get neDesc => 'Selfish, cruel, practical';

  @override
  String get ceDesc => 'Destruction, cruelty, chaos';

  @override
  String get stepRaceClass => 'Race & Class';

  @override
  String get stepAbilities => 'Ability Scores & HP';

  @override
  String get stepFeatures => 'Features & Spells';

  @override
  String get stepEquipment => 'Equipment';

  @override
  String get stepBackground => 'Background';

  @override
  String get stepSkills => 'Skills';

  @override
  String get stepReview => 'Review';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get finish => 'Finish';

  @override
  String get characterCreated => 'Character created successfully!';

  @override
  String get tapToUpgrade => 'TAP TO UPGRADE';

  @override
  String get showDetails => 'Show Character Details';

  @override
  String get hideDetails => 'Hide Details';

  @override
  String get newAbilities => 'New Abilities';

  @override
  String unlocksAtLevel(int level) {
    return 'Level $level Unlocks';
  }

  @override
  String get noNewFeaturesAtLevel =>
      'No new features at this level. But your stats improved!';

  @override
  String get spellSlotsIncreased => 'Spell Slots Increased';

  @override
  String get sacredOath => 'Sacred Oath';

  @override
  String get primalPath => 'Primal Path';

  @override
  String get bardCollege => 'Bard College';

  @override
  String get divineDomain => 'Divine Domain';

  @override
  String get druidCircle => 'Druid Circle';

  @override
  String get martialArchetype => 'Martial Archetype';

  @override
  String get monasticTradition => 'Monastic Tradition';

  @override
  String get rangerArchetype => 'Ranger Archetype';

  @override
  String get roguishArchetype => 'Roguish Archetype';

  @override
  String get sorcerousOrigin => 'Sorcerous Origin';

  @override
  String get otherworldlyPatron => 'Otherworldly Patron';

  @override
  String get arcaneTradition => 'Arcane Tradition';

  @override
  String get featureTypePassive => 'Passive';

  @override
  String get featureTypeAction => 'Action';

  @override
  String get featureTypeBonusAction => 'Bonus Action';

  @override
  String get featureTypeReaction => 'Reaction';

  @override
  String get featureTypeOther => 'Other';

  @override
  String get selectSubclass => 'Select Subclass';

  @override
  String get selectSpecialization => 'Select Specialization';

  @override
  String get classFeatures => 'Class Features';

  @override
  String get chooseFightingStyle => 'Choose a Fighting Style:';

  @override
  String get makeChoices => 'Make Choices to Continue';

  @override
  String get continueLabel => 'Continue';

  @override
  String get levelUpReady => 'Level Up Ready!';

  @override
  String get confirmLevelUp => 'Confirm these changes to your character.';

  @override
  String get applyChanges => 'APPLY CHANGES';

  @override
  String get colorAmber => 'Amber';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorBrown => 'Brown';

  @override
  String get colorGray => 'Gray';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorHazel => 'Hazel';

  @override
  String get colorRed => 'Red';

  @override
  String get colorViolet => 'Violet';

  @override
  String get colorAuburn => 'Auburn';

  @override
  String get colorBlack => 'Black';

  @override
  String get colorBlonde => 'Blonde';

  @override
  String get colorWhite => 'White';

  @override
  String get colorBald => 'Bald';

  @override
  String get skinPale => 'Pale';

  @override
  String get skinFair => 'Fair';

  @override
  String get skinLight => 'Light';

  @override
  String get skinMedium => 'Medium';

  @override
  String get skinTan => 'Tan';

  @override
  String get skinDark => 'Dark';

  @override
  String get skinEbony => 'Ebony';

  @override
  String get unitCm => 'cm';

  @override
  String get unitKg => 'kg';

  @override
  String get chooseSkillsTitle => 'Choose Skills';

  @override
  String chooseSkills(int count, String list) {
    return 'Choose $count from: $list';
  }

  @override
  String get assignAbilityScores => 'Assign Ability Scores';

  @override
  String get abilityScoresSubtitle =>
      'Choose how you want to determine your character\'s ability scores.';

  @override
  String get allocationMethod => 'Allocation Method';

  @override
  String get standardArray => 'Standard Array';

  @override
  String get pointBuy => 'Point Buy';

  @override
  String get manualEntry => 'Manual Entry';

  @override
  String get standardArrayDesc =>
      'Assign these values: 15, 14, 13, 12, 10, 8. Balanced.';

  @override
  String get pointBuyDesc => 'Spend 27 points to customize scores (8-15).';

  @override
  String get manualEntryDesc => 'Set any value from 3 to 18.';

  @override
  String get strDesc => 'Physical power';

  @override
  String get dexDesc => 'Agility & reflexes';

  @override
  String get conDesc => 'Endurance & health';

  @override
  String get intDesc => 'Reasoning & memory';

  @override
  String get wisDesc => 'Awareness & insight';

  @override
  String get chaDesc => 'Force of personality';

  @override
  String racialBonus(int bonus, int result, String mod) {
    return 'Racial Bonus: +$bonus → Final: $result ($mod)';
  }

  @override
  String get startingHitPoints => 'Starting Hit Points';

  @override
  String hitDieConMod(int die, String mod) {
    return 'Hit Die: d$die | CON Mod: $mod';
  }

  @override
  String get hpMaxDesc => 'Maximum HP (recommended)';

  @override
  String hpAvgDesc(int avg) {
    return 'Average roll: $avg + CON modifier';
  }

  @override
  String hpRollDesc(int die) {
    return 'Roll 1d$die for starting HP';
  }

  @override
  String reRoll(int die, int val) {
    return 'Re-roll d$die (rolled: $val)';
  }

  @override
  String pointsUsed(int used, int total, int remaining) {
    return 'Points: $used / $total used ($remaining remaining)';
  }

  @override
  String get newFeaturesLabel => 'New Features';

  @override
  String get searchJournal => 'Search journal...';

  @override
  String get addQuest => 'Add Quest';

  @override
  String get noActiveQuests => 'No active quests';

  @override
  String get addNote => 'Add Note';

  @override
  String get noNotes => 'No notes';

  @override
  String get deleteNote => 'Delete Note';

  @override
  String deleteNoteConfirmation(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get deleteQuest => 'Delete Quest';

  @override
  String deleteQuestConfirmation(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String characterCreatedName(String name) {
    return '$name created successfully!';
  }

  @override
  String errorCreatingCharacter(String error) {
    return 'Error creating character: $error';
  }

  @override
  String get cancelCharacterCreationTitle => 'Cancel Character Creation?';

  @override
  String get cancelCharacterCreationMessage => 'All progress will be lost.';

  @override
  String get continueEditing => 'Continue Editing';

  @override
  String get discard => 'Discard';

  @override
  String get selectClassFirst => 'Please select a class first';

  @override
  String selectSkillProficiencies(int count, String characterClass) {
    return 'Select $count skill proficiencies for your $characterClass.';
  }

  @override
  String get allSkillsSelected => 'All skills selected!';

  @override
  String chooseMoreSkills(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Choose $count more skill$_temp0';
  }

  @override
  String get skillAcrobaticsDesc =>
      'Dexterity - Balance, tumbling, aerial maneuvers';

  @override
  String get skillAnimalHandlingDesc =>
      'Wisdom - Calming animals, riding, training';

  @override
  String get skillArcanaDesc => 'Intelligence - Magic, spells, magical items';

  @override
  String get skillAthleticsDesc => 'Strength - Climbing, jumping, swimming';

  @override
  String get skillDeceptionDesc => 'Charisma - Lying, disguising, misleading';

  @override
  String get skillHistoryDesc => 'Intelligence - Historical events, legends';

  @override
  String get skillInsightDesc => 'Wisdom - Reading intentions, detecting lies';

  @override
  String get skillIntimidationDesc => 'Charisma - Threats, coercion';

  @override
  String get skillInvestigationDesc =>
      'Intelligence - Finding clues, deduction';

  @override
  String get skillMedicineDesc => 'Wisdom - Stabilizing, diagnosing';

  @override
  String get skillNatureDesc => 'Intelligence - Terrain, plants, animals';

  @override
  String get skillPerceptionDesc => 'Wisdom - Spotting, hearing, detecting';

  @override
  String get skillPerformanceDesc => 'Charisma - Music, dance, acting';

  @override
  String get skillPersuasionDesc => 'Charisma - Diplomacy, negotiations';

  @override
  String get skillReligionDesc => 'Intelligence - Deities, rites, prayers';

  @override
  String get skillSleightOfHandDesc => 'Dexterity - Pickpocketing, tricks';

  @override
  String get skillStealthDesc => 'Dexterity - Hiding, moving silently';

  @override
  String get skillSurvivalDesc => 'Wisdom - Tracking, foraging, navigation';

  @override
  String get chooseBackground => 'Choose Background';

  @override
  String get backgroundDescription =>
      'Your background represents your character\'s past and grants additional skills.';

  @override
  String get noBackgroundsAvailable => 'No backgrounds available';

  @override
  String get abilityStrAbbr => 'STR';

  @override
  String get abilityDexAbbr => 'DEX';

  @override
  String get abilityConAbbr => 'CON';

  @override
  String get abilityIntAbbr => 'INT';

  @override
  String get abilityWisAbbr => 'WIS';

  @override
  String get abilityChaAbbr => 'CHA';

  @override
  String get propertyAmmunition => 'Ammunition';

  @override
  String get propertyFinesse => 'Finesse';

  @override
  String get propertyHeavy => 'Heavy';

  @override
  String get propertyLight => 'Light';

  @override
  String get propertyLoading => 'Loading';

  @override
  String get propertyRange => 'Range';

  @override
  String get propertyReach => 'Reach';

  @override
  String get propertySpecial => 'Special';

  @override
  String get propertyThrown => 'Thrown';

  @override
  String get propertyTwoHanded => 'Two-Handed';

  @override
  String get propertyVersatile => 'Versatile';

  @override
  String get propertyMartial => 'Martial';

  @override
  String get propertySimple => 'Simple';

  @override
  String get armorTypeLight => 'Light Armor';

  @override
  String get armorTypeMedium => 'Medium Armor';

  @override
  String get armorTypeHeavy => 'Heavy Armor';

  @override
  String get armorTypeShield => 'Shield';

  @override
  String get searchSpells => 'Search spells...';

  @override
  String get noSpellsFound => 'No spells found';

  @override
  String get tryAdjustingFilters => 'Try adjusting your filters';

  @override
  String get filters => 'Filters';

  @override
  String get clearAll => 'Clear All';

  @override
  String get apply => 'Apply';

  @override
  String get castingTime => 'Casting Time';

  @override
  String get duration => 'Duration';

  @override
  String get components => 'Components';

  @override
  String get materials => 'Materials';

  @override
  String get concentration => 'Concentration';

  @override
  String get ritual => 'Ritual';

  @override
  String get atHigherLevels => 'At Higher Levels';

  @override
  String get classes => 'Classes';

  @override
  String get addToKnown => 'Add to Known Spells';

  @override
  String get removeFromKnown => 'Remove from Known Spells';

  @override
  String addedToKnown(String name) {
    return 'Added \"$name\" to known spells';
  }

  @override
  String removedFromKnown(String name) {
    return 'Removed \"$name\" from known spells';
  }

  @override
  String get availableToLearn => 'Available to Learn';

  @override
  String availableAtLevel(int level) {
    return 'Available at Level $level';
  }

  @override
  String get filterAvailability => 'Availability';

  @override
  String get filterClass => 'Class';

  @override
  String get filterLevel => 'Level';

  @override
  String get filterSchool => 'School';

  @override
  String get filterAllSpells => 'All Spells';

  @override
  String get filterCanLearnNow => 'Can Learn Now';

  @override
  String get filterAvailableToClass => 'Available to Class';

  @override
  String get filterAllClasses => 'All Classes';

  @override
  String get filterAllLevels => 'All Levels';

  @override
  String get filterAllSchools => 'All Schools';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get encumbrance => 'Encumbrance';

  @override
  String get attunement => 'Attunement';

  @override
  String get attunementLimitReached =>
      'Maximum attunement slots reached (3/3). Unequip something first.';

  @override
  String deleteItemConfirmation(String name) {
    return 'Throw away $name?';
  }

  @override
  String spellsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count spell$_temp0';
  }

  @override
  String preparedSpellsCount(int current, int max) {
    return 'Prepared: $current / $max';
  }

  @override
  String get spellAlmanacTitle => 'Spell Almanac';

  @override
  String get actionTypeFree => 'Free Action';

  @override
  String get featuresStepTitle => 'Class Features';

  @override
  String featuresStepSubtitle(String className) {
    return 'As a level 1 $className, you gain the following features:';
  }

  @override
  String get noFeaturesAtLevel1 =>
      'No features available at level 1 for this class.';

  @override
  String get spellsStepTitle => 'Spells';

  @override
  String get selectSpellsInstruction =>
      'Select spells for your character (Level 0 & 1).';

  @override
  String get selectSkillsInstruction => 'Select your skill proficiencies.';

  @override
  String get selectSkillsFirst => 'Please select skills first';

  @override
  String get expertise => 'Expertise';

  @override
  String noSpellsFoundForClass(String className) {
    return 'No spells found for $className';
  }

  @override
  String get level1Spells => 'Level 1 Spells';

  @override
  String get spellsStepPlaceholder =>
      'Spell selection will be available in future updates. For now, please add spells manually in the character sheet after creation.';

  @override
  String get equipmentStepTitle => 'Starting Equipment';

  @override
  String get equipmentStepSubtitle =>
      'Choose your starting equipment for your class';

  @override
  String get chooseEquipmentPackage => 'Choose Equipment Package';

  @override
  String get packageStandard => 'Standard Package';

  @override
  String get packageStandardDesc =>
      'Recommended starting equipment for your class';

  @override
  String get packageAlternative => 'Alternative Package';

  @override
  String get packageAlternativeDesc => 'Different equipment options';

  @override
  String get packageCustom => 'Custom Package';

  @override
  String get packageCustomDesc => 'Choose items from catalog';

  @override
  String get selectedEquipment => 'Selected Equipment';

  @override
  String get addItem => 'Add Item';

  @override
  String get noItemsSelected => 'No items selected';

  @override
  String get tapToAddItems => 'Tap \"Add Item\" to select equipment';

  @override
  String equipmentPreview(String className) {
    return '$className Equipment Preview';
  }

  @override
  String get toolsAndGear => 'Tools & Gear';

  @override
  String get equipmentPreviewDisclaimer =>
      'This is a preview of typical starting equipment. You can customize your inventory after character creation.';

  @override
  String get itemCatalog => 'Item Catalog';

  @override
  String get createItem => 'Create Item';

  @override
  String foundItems(int count, int selected) {
    return 'Found: $count (selected: $selected)';
  }

  @override
  String get noItemsFound => 'No items found';

  @override
  String get done => 'Done';

  @override
  String get createCustomItem => 'Create Custom Item';

  @override
  String get addImage => 'Add\nimage';

  @override
  String errorLoadingImage(String error) {
    return 'Error loading image: $error';
  }

  @override
  String get itemName => 'Name';

  @override
  String get itemNameHint => 'e.g., Sword of Light';

  @override
  String get enterItemName => 'Enter name';

  @override
  String get itemDescription => 'Description';

  @override
  String get itemDescriptionHint => 'Describe the item...';

  @override
  String get itemType => 'Type';

  @override
  String get itemRarity => 'Rarity';

  @override
  String get itemWeight => 'Weight';

  @override
  String get itemValue => 'Value';

  @override
  String get itemQuantity => 'Quantity';

  @override
  String get minQuantity1 => 'Minimum 1';

  @override
  String itemAdded(String name, int quantity) {
    return '$name (x$quantity) added';
  }

  @override
  String errorCreatingItem(String error) {
    return 'Error creating item: $error';
  }

  @override
  String get rarityCommon => 'Common';

  @override
  String get rarityUncommon => 'Uncommon';

  @override
  String get rarityRare => 'Rare';

  @override
  String get rarityVeryRare => 'Very Rare';

  @override
  String get rarityLegendary => 'Legendary';

  @override
  String get rarityArtifact => 'Artifact';

  @override
  String get methodStandard => 'Standard';

  @override
  String get methodPointBuy => 'Point Buy';

  @override
  String get methodManual => 'Manual Entry';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get highContrast => 'High Contrast';

  @override
  String get highContrastDesc => 'Increases visibility with sharper colors';

  @override
  String get colorScheme => 'Color Scheme';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get developedBy => 'Developed by';

  @override
  String get license => 'License';

  @override
  String get d20wish => 'May your d20 always land on 20!';

  @override
  String get characterReady => 'Character Ready!';

  @override
  String get reviewChoices => 'Review your choices before finalizing';

  @override
  String get unnamed => '(Unnamed)';

  @override
  String get basicInfo => 'Basic Information';

  @override
  String get level1Info =>
      'Your character will be created at level 1. Additional features will be added based on your class and background.';

  @override
  String get hpMax => 'Max';

  @override
  String get contentManagement => 'Content Management';

  @override
  String get libraryManagerTitle => 'Managed Libraries';

  @override
  String get manageLibraries => 'Manage Libraries';

  @override
  String get manageLibrariesSubtitle =>
      'Import and manage external content (XML)';

  @override
  String get importXML => 'Import XML';

  @override
  String get noLibraries => 'No imported libraries';

  @override
  String get noLibrariesHint => 'Tap + to import content from FC5 XML files';

  @override
  String libraryStats(int items, int spells) {
    return '$items Items, $spells Spells';
  }

  @override
  String libraryImportedDate(String date) {
    return 'Imported $date';
  }

  @override
  String get deleteLibraryTitle => 'Delete Library?';

  @override
  String deleteLibraryMessage(String name, int items, int spells) {
    return 'This will remove \"$name\" and all associated content:\n\n• $items Items\n• $spells Spells\n\nThis action cannot be undone.';
  }

  @override
  String get libraryDeleted => 'Library deleted successfully';

  @override
  String errorDeletingLibrary(String error) {
    return 'Error deleting library: $error';
  }

  @override
  String get forgeTitle => 'The Forge';

  @override
  String get identitySection => 'IDENTITY';

  @override
  String get characteristicsSection => 'CHARACTERISTICS';

  @override
  String get statsSection => 'STATS';

  @override
  String get magicPropertiesSection => 'MAGIC & PROPERTIES';

  @override
  String get isMagical => 'Magical Item';

  @override
  String get requiresAttunement => 'Requires Attunement';

  @override
  String get weaponStats => 'Weapon Stats';

  @override
  String get damageDice => 'Damage Dice';

  @override
  String get damageDiceHint => '1d8';

  @override
  String get armorStats => 'Armor Stats';

  @override
  String get addDexModifier => 'Add DEX Modifier';

  @override
  String get stealthDisadvantage => 'Stealth Disadvantage';

  @override
  String get forgeItem => 'Forge Item';

  @override
  String get itemExample => 'e.g. Excalibur';

  @override
  String get typeTool => 'Tools';

  @override
  String get typeTreasure => 'Treasure';

  @override
  String cantripsTab(int current, int max) {
    return 'Cantrips ($current/$max)';
  }

  @override
  String level1TabKnown(int current, int max) {
    return 'Level 1 ($current/$max)';
  }

  @override
  String get level1TabAll => 'Level 1 (All)';

  @override
  String get noSpellsAtLevel1 => 'No spells available at level 1';

  @override
  String get useAction => 'Use';

  @override
  String useActionCost(String cost) {
    return 'Use ($cost)';
  }
}
