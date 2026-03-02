import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'QD&D'**
  String get appTitle;

  /// The app subtitle which should NOT be translated
  ///
  /// In en, this message translates to:
  /// **'Roleplay Companion'**
  String get appSubtitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get characters;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Compendium'**
  String get compendium;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Dice Roller'**
  String get diceRoller;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Spells'**
  String get spells;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Combat'**
  String get combat;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Quests'**
  String get quests;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Race'**
  String get race;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get background;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get classLabel;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Subclass'**
  String get subclass;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get alignment;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get experience;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Player Name'**
  String get playerName;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Create New Character'**
  String get createNewCharacter;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Import from Fight Club 5'**
  String get importFC5;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Delete Character'**
  String get deleteConfirmationTitle;

  /// No description provided for @deleteConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}? This cannot be undone.'**
  String deleteConfirmationMessage(String name);

  /// No description provided for @deletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String deletedSuccess(String name);

  /// No description provided for @duplicatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} duplicated successfully!'**
  String duplicatedSuccess(String name);

  /// No description provided for @importedSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} imported successfully!'**
  String importedSuccess(String name);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Abilities'**
  String get abilities;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Saving Throws'**
  String get savingThrows;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skills;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get abilityStr;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Dexterity'**
  String get abilityDex;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Constitution'**
  String get abilityCon;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Intelligence'**
  String get abilityInt;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Wisdom'**
  String get abilityWis;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Charisma'**
  String get abilityCha;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Athletics'**
  String get skillAthletics;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Acrobatics'**
  String get skillAcrobatics;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Sleight of Hand'**
  String get skillSleightOfHand;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Stealth'**
  String get skillStealth;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Arcana'**
  String get skillArcana;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get skillHistory;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Investigation'**
  String get skillInvestigation;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get skillNature;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Religion'**
  String get skillReligion;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Animal Handling'**
  String get skillAnimalHandling;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get skillInsight;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get skillMedicine;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Perception'**
  String get skillPerception;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Survival'**
  String get skillSurvival;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Deception'**
  String get skillDeception;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Intimidation'**
  String get skillIntimidation;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get skillPerformance;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Persuasion'**
  String get skillPersuasion;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Combat Dashboard'**
  String get combatDashboard;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Hit Points'**
  String get hitPoints;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'HP'**
  String get hpShort;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'AC'**
  String get armorClassAC;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'INIT'**
  String get initiativeINIT;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'SPEED'**
  String get speedSPEED;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'PROF'**
  String get proficiencyPROF;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Weapons & Attacks'**
  String get weaponsAttacks;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Short Rest'**
  String get shortRest;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Long Rest'**
  String get longRest;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Enter Combat Mode'**
  String get enterCombatMode;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get rest;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Recover short-rest features and spend Hit Dice?'**
  String get shortRestDescription;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Recover all HP, spell slots, and features?'**
  String get longRestDescription;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Rested successfully'**
  String get restedSuccess;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Unarmed Strike'**
  String get unarmedStrike;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'HIT'**
  String get hit;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'DMG'**
  String get dmg;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Bludgeoning'**
  String get damageTypeBludgeoning;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Piercing'**
  String get damageTypePiercing;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Slashing'**
  String get damageTypeSlashing;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Physical'**
  String get damageTypePhysical;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Search items...'**
  String get searchItems;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get sortWeight;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get sortValue;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get sortType;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Equipped'**
  String get filterEquipped;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Unequipped'**
  String get filterUnequipped;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Weapons'**
  String get typeWeapon;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Armor'**
  String get typeArmor;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Gear'**
  String get typeGear;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Consumables'**
  String get typeConsumable;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Total Weight'**
  String get totalWeight;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Edit Currency'**
  String get editCurrency;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Currency updated'**
  String get currencyUpdated;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Platinum (PP)'**
  String get currencyPP;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Gold (GP)'**
  String get currencyGP;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Silver (SP)'**
  String get currencySP;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Copper (CP)'**
  String get currencyCP;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Inventory is empty'**
  String get inventoryEmpty;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Tap + to add items'**
  String get inventoryEmptyHint;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Unequip'**
  String get unequip;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Equip'**
  String get equip;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Item removed'**
  String get itemRemoved;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Equipped'**
  String get itemEquipped;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Unequipped'**
  String get itemUnequipped;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'WEAPON PROPERTIES'**
  String get weaponProperties;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'ARMOR PROPERTIES'**
  String get armorProperties;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Damage'**
  String get damage;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Damage Type'**
  String get damageType;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Versatile Damage'**
  String get versatileDamage;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get range;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get properties;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Armor Class'**
  String get armorClass;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'STR Requirement'**
  String get strRequirement;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Stealth'**
  String get stealth;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Disadvantage'**
  String get disadvantage;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Spell Almanac'**
  String get spellAlmanac;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get resources;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Active Abilities'**
  String get activeAbilities;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Magic'**
  String get magic;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Spells List'**
  String get spellsList;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Passive Traits'**
  String get passiveTraits;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Cantrips'**
  String get cantrips;

  /// No description provided for @levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelLabel(int level);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get levelShort;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No spells learned yet'**
  String get noSpellsLearned;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Cast Spell'**
  String get castSpell;

  /// No description provided for @castAction.
  ///
  /// In en, this message translates to:
  /// **'Cast {name}'**
  String castAction(String name);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose spell slot level:'**
  String get chooseSpellSlot;

  /// No description provided for @levelSlot.
  ///
  /// In en, this message translates to:
  /// **'Level {level} Slot'**
  String levelSlot(int level);

  /// No description provided for @slotsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} slot{count, plural, =1{ } other{s }} remaining'**
  String slotsRemaining(int count);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Upcast'**
  String get upcast;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No spell slots available!'**
  String get noSlotsAvailable;

  /// No description provided for @spellCastSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} cast!'**
  String spellCastSuccess(String name);

  /// No description provided for @spellCastLevelSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} cast at level {level}!'**
  String spellCastLevelSuccess(String name, String level);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Ability'**
  String get spellAbility;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Save DC'**
  String get spellSaveDC;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get spellAttack;

  /// No description provided for @lvlShort.
  ///
  /// In en, this message translates to:
  /// **'Lvl {level}'**
  String lvlShort(int level);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Channel Divinity'**
  String get channelDivinity;

  /// No description provided for @useChannelDivinity.
  ///
  /// In en, this message translates to:
  /// **'Use Channel Divinity ({count} left)'**
  String useChannelDivinity(int count);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No Channel Divinity charges'**
  String get noChannelDivinity;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No Wild Shape charges'**
  String get noWildShapeCharges;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Abjuration'**
  String get schoolAbjuration;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Conjuration'**
  String get schoolConjuration;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Divination'**
  String get schoolDivination;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Enchantment'**
  String get schoolEnchantment;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Evocation'**
  String get schoolEvocation;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Illusion'**
  String get schoolIllusion;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Necromancy'**
  String get schoolNecromancy;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Transmutation'**
  String get schoolTransmutation;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Combat Stats'**
  String get combatStats;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Roll Initiative'**
  String get rollInitiative;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'End Combat'**
  String get endCombat;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'This will reset the round counter.'**
  String get endCombatConfirm;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Next Round'**
  String get nextRound;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Start Combat'**
  String get startCombat;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Heal'**
  String get heal;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Take Damage'**
  String get takeDamage;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Temp HP'**
  String get tempHp;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Death Saves'**
  String get deathSaves;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Successes'**
  String get successes;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Failures'**
  String get failures;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Unconscious'**
  String get unconscious;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get condition;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditions;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get actionTypeAction;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Bonus Action'**
  String get actionTypeBonus;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Reaction'**
  String get actionTypeReaction;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Spellcasting Ability'**
  String get spellcastingAbility;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'pp'**
  String get currencyPP_short;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'gp'**
  String get currencyGP_short;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'sp'**
  String get currencySP_short;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'cp'**
  String get currencyCP_short;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'lb'**
  String get weightUnit;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'gp'**
  String get currencyUnit;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Eyes'**
  String get eyes;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Skin'**
  String get skin;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Hair'**
  String get hair;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Roll Type'**
  String get rollType;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Advantage'**
  String get advantage;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Modifier'**
  String get modifier;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Rolling...'**
  String get rolling;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total: {value}'**
  String total(String value);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Tap to Roll'**
  String get tapToRoll;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Level Up'**
  String get levelUp;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Level Up'**
  String get levelUpTitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Current Level'**
  String get currentLevel;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Next Level'**
  String get nextLevel;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'HP Increase'**
  String get hpIncrease;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose Race'**
  String get chooseRace;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose Class'**
  String get chooseClass;

  /// No description provided for @hitDieType.
  ///
  /// In en, this message translates to:
  /// **'Hit Die: d{value}'**
  String hitDieType(String value);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Acid'**
  String get damageTypeAcid;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Cold'**
  String get damageTypeCold;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get damageTypeFire;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Force'**
  String get damageTypeForce;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Lightning'**
  String get damageTypeLightning;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Necrotic'**
  String get damageTypeNecrotic;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Poison'**
  String get damageTypePoison;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Psychic'**
  String get damageTypePsychic;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Radiant'**
  String get damageTypeRadiant;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Thunder'**
  String get damageTypeThunder;

  /// No description provided for @conModIs.
  ///
  /// In en, this message translates to:
  /// **'Your Constitution modifier is {value}'**
  String conModIs(String value);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get average;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Safe choice'**
  String get safeChoice;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Roll'**
  String get roll;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Risk it!'**
  String get riskIt;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Blinded'**
  String get conditionBlinded;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Charmed'**
  String get conditionCharmed;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Deafened'**
  String get conditionDeafened;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Frightened'**
  String get conditionFrightened;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Grappled'**
  String get conditionGrappled;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Incapacitated'**
  String get conditionIncapacitated;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Invisible'**
  String get conditionInvisible;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Paralyzed'**
  String get conditionParalyzed;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Petrified'**
  String get conditionPetrified;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Poisoned'**
  String get conditionPoisoned;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Prone'**
  String get conditionProne;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Restrained'**
  String get conditionRestrained;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Stunned'**
  String get conditionStunned;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Unconscious'**
  String get conditionUnconscious;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get stepBasicInfo;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Character Identity'**
  String get identity;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Create the foundation of your character'**
  String get identitySubtitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Character Name *'**
  String get charName;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'e.g., Gundren Rockseeker'**
  String get charNameHint;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose your moral compass'**
  String get alignmentSubtitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Physical Appearance'**
  String get physicalAppearance;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Optional details about looks'**
  String get physicalSubtitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Personality'**
  String get personality;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Traits, ideals, bonds, flaws'**
  String get personalitySubtitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Backstory'**
  String get backstory;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Your character\'s story'**
  String get backstorySubtitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Born in a small village...'**
  String get backstoryHint;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Personality Traits'**
  String get traits;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'I am always polite...'**
  String get traitsHint;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Ideals'**
  String get ideals;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Justice...'**
  String get idealsHint;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Bonds'**
  String get bonds;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'I owe my life...'**
  String get bondsHint;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Flaws'**
  String get flaws;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'I have a weakness...'**
  String get flawsHint;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Appearance Description'**
  String get appearanceDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Tall and muscular...'**
  String get appearanceHint;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get ageYears;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get genderMaleShort;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get genderFemaleShort;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Oth'**
  String get genderOtherShort;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose Race & Class'**
  String get chooseRaceClass;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Select your character\'s race and class.'**
  String get raceClassSubtitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Loading races...'**
  String get loadingRaces;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Loading classes...'**
  String get loadingClasses;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed: {value} ft'**
  String speed(int value);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Ability Score Increases'**
  String get abilityScoreIncreases;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languages;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Racial Traits'**
  String get racialTraits;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Saving Throw Proficiencies'**
  String get savingThrowProficiencies;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// No description provided for @rollDie.
  ///
  /// In en, this message translates to:
  /// **'Roll d{sides}'**
  String rollDie(int sides);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Skill Proficiencies'**
  String get skillProficiencies;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Armor Proficiencies'**
  String get armorProficiencies;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Weapon Proficiencies'**
  String get weaponProficiencies;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get langCommon;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Dwarvish'**
  String get langDwarvish;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Elvish'**
  String get langElvish;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Giant'**
  String get langGiant;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Gnomish'**
  String get langGnomish;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Goblin'**
  String get langGoblin;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Halfling'**
  String get langHalfling;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Orc'**
  String get langOrc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Abyssal'**
  String get langAbyssal;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Celestial'**
  String get langCelestial;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Draconic'**
  String get langDraconic;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Deep Speech'**
  String get langDeepSpeech;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Infernal'**
  String get langInfernal;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Primordial'**
  String get langPrimordial;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Sylvan'**
  String get langSylvan;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Undercommon'**
  String get langUndercommon;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get weaponClub;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Dagger'**
  String get weaponDagger;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Greatclub'**
  String get weaponGreatclub;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Handaxe'**
  String get weaponHandaxe;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Javelin'**
  String get weaponJavelin;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Light Hammer'**
  String get weaponLightHammer;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Mace'**
  String get weaponMace;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Quarterstaff'**
  String get weaponQuarterstaff;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Sickle'**
  String get weaponSickle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Spear'**
  String get weaponSpear;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Light Crossbow'**
  String get weaponLightCrossbow;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Dart'**
  String get weaponDart;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Shortbow'**
  String get weaponShortbow;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Sling'**
  String get weaponSling;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Battleaxe'**
  String get weaponBattleaxe;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Flail'**
  String get weaponFlail;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Glaive'**
  String get weaponGlaive;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Greataxe'**
  String get weaponGreataxe;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Greatsword'**
  String get weaponGreatsword;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Halberd'**
  String get weaponHalberd;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Lance'**
  String get weaponLance;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Longsword'**
  String get weaponLongsword;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Maul'**
  String get weaponMaul;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Morningstar'**
  String get weaponMorningstar;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Pike'**
  String get weaponPike;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Rapier'**
  String get weaponRapier;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Scimitar'**
  String get weaponScimitar;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Shortsword'**
  String get weaponShortsword;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Trident'**
  String get weaponTrident;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'War Pick'**
  String get weaponWarPick;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Warhammer'**
  String get weaponWarhammer;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Whip'**
  String get weaponWhip;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Blowgun'**
  String get weaponBlowgun;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Hand Crossbow'**
  String get weaponHandCrossbow;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Heavy Crossbow'**
  String get weaponHeavyCrossbow;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Longbow'**
  String get weaponLongbow;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get weaponNet;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Select Height'**
  String get selectHeight;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Select Weight'**
  String get selectWeight;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Select Eye Color'**
  String get selectEyeColor;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Select Hair Color'**
  String get selectHairColor;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Select Skin Tone'**
  String get selectSkinTone;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Custom Eye Color'**
  String get customEyeColor;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Custom Hair Color'**
  String get customHairColor;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Custom Skin Tone'**
  String get customSkinTone;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Enter custom value'**
  String get enterCustom;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @readyMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} is ready to choose their path!'**
  String readyMessage(String name);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'LAW'**
  String get law;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'NEUTRAL'**
  String get neutral;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'CHAOS'**
  String get chaos;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'GOOD'**
  String get good;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'EVIL'**
  String get evil;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Lawful Good'**
  String get lg;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Neutral Good'**
  String get ng;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Chaotic Good'**
  String get cg;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Lawful Neutral'**
  String get ln;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'True Neutral'**
  String get tn;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Chaotic Neutral'**
  String get cn;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Lawful Evil'**
  String get le;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Neutral Evil'**
  String get ne;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Chaotic Evil'**
  String get ce;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Honor, compassion, duty'**
  String get lgDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Kind, helpful, balance'**
  String get ngDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Freedom, kindness, rebellion'**
  String get cgDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Order, tradition, law'**
  String get lnDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Balance, nature, neutrality'**
  String get tnDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Freedom, unpredictability'**
  String get cnDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Tyranny, order, domination'**
  String get leDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Selfish, cruel, practical'**
  String get neDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Destruction, cruelty, chaos'**
  String get ceDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Race & Class'**
  String get stepRaceClass;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Ability Scores & HP'**
  String get stepAbilities;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Features & Spells'**
  String get stepFeatures;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get stepEquipment;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get stepBackground;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get stepSkills;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get stepReview;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Character created successfully!'**
  String get characterCreated;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'TAP TO UPGRADE'**
  String get tapToUpgrade;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Show Character Details'**
  String get showDetails;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Hide Details'**
  String get hideDetails;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'New Abilities'**
  String get newAbilities;

  /// No description provided for @unlocksAtLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {level} Unlocks'**
  String unlocksAtLevel(int level);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No new features at this level. But your stats improved!'**
  String get noNewFeaturesAtLevel;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Spell Slots Increased'**
  String get spellSlotsIncreased;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Sacred Oath'**
  String get sacredOath;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Primal Path'**
  String get primalPath;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Bard College'**
  String get bardCollege;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Divine Domain'**
  String get divineDomain;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Druid Circle'**
  String get druidCircle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Martial Archetype'**
  String get martialArchetype;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Monastic Tradition'**
  String get monasticTradition;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Ranger Archetype'**
  String get rangerArchetype;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Roguish Archetype'**
  String get roguishArchetype;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Sorcerous Origin'**
  String get sorcerousOrigin;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Otherworldly Patron'**
  String get otherworldlyPatron;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Arcane Tradition'**
  String get arcaneTradition;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Passive'**
  String get featureTypePassive;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get featureTypeAction;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Bonus Action'**
  String get featureTypeBonusAction;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Reaction'**
  String get featureTypeReaction;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get featureTypeOther;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Select Subclass'**
  String get selectSubclass;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Select Specialization'**
  String get selectSpecialization;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Class Features'**
  String get classFeatures;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose a Fighting Style:'**
  String get chooseFightingStyle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Make Choices to Continue'**
  String get makeChoices;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Level Up Ready!'**
  String get levelUpReady;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Confirm these changes to your character.'**
  String get confirmLevelUp;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'APPLY CHANGES'**
  String get applyChanges;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get colorAmber;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get colorBrown;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get colorGray;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Hazel'**
  String get colorHazel;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get colorViolet;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Auburn'**
  String get colorAuburn;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colorBlack;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Blonde'**
  String get colorBlonde;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colorWhite;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Bald'**
  String get colorBald;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Pale'**
  String get skinPale;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get skinFair;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get skinLight;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get skinMedium;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Tan'**
  String get skinTan;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get skinDark;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Ebony'**
  String get skinEbony;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get unitCm;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose Skills'**
  String get chooseSkillsTitle;

  /// No description provided for @chooseSkills.
  ///
  /// In en, this message translates to:
  /// **'Choose {count} from: {list}'**
  String chooseSkills(int count, String list);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Assign Ability Scores'**
  String get assignAbilityScores;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to determine your character\'s ability scores.'**
  String get abilityScoresSubtitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Allocation Method'**
  String get allocationMethod;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Standard Array'**
  String get standardArray;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Point Buy'**
  String get pointBuy;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Manual Entry'**
  String get manualEntry;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Assign these values: 15, 14, 13, 12, 10, 8. Balanced.'**
  String get standardArrayDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Spend 27 points to customize scores (8-15).'**
  String get pointBuyDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Set any value from 3 to 18.'**
  String get manualEntryDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Physical power'**
  String get strDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Agility & reflexes'**
  String get dexDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Endurance & health'**
  String get conDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Reasoning & memory'**
  String get intDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Awareness & insight'**
  String get wisDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Force of personality'**
  String get chaDesc;

  /// No description provided for @racialBonus.
  ///
  /// In en, this message translates to:
  /// **'Racial Bonus: +{bonus} → Final: {result} ({mod})'**
  String racialBonus(int bonus, int result, String mod);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Starting Hit Points'**
  String get startingHitPoints;

  /// No description provided for @hitDieConMod.
  ///
  /// In en, this message translates to:
  /// **'Hit Die: d{die} | CON Mod: {mod}'**
  String hitDieConMod(int die, String mod);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Maximum HP (recommended)'**
  String get hpMaxDesc;

  /// No description provided for @hpAvgDesc.
  ///
  /// In en, this message translates to:
  /// **'Average roll: {avg} + CON modifier'**
  String hpAvgDesc(int avg);

  /// No description provided for @hpRollDesc.
  ///
  /// In en, this message translates to:
  /// **'Roll 1d{die} for starting HP'**
  String hpRollDesc(int die);

  /// No description provided for @reRoll.
  ///
  /// In en, this message translates to:
  /// **'Re-roll d{die} (rolled: {val})'**
  String reRoll(int die, int val);

  /// No description provided for @pointsUsed.
  ///
  /// In en, this message translates to:
  /// **'Points: {used} / {total} used ({remaining} remaining)'**
  String pointsUsed(int used, int total, int remaining);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'New Features'**
  String get newFeaturesLabel;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Search journal...'**
  String get searchJournal;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Add Quest'**
  String get addQuest;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No active quests'**
  String get noActiveQuests;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get addNote;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get noNotes;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Delete Note'**
  String get deleteNote;

  /// No description provided for @deleteNoteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String deleteNoteConfirmation(String title);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Delete Quest'**
  String get deleteQuest;

  /// No description provided for @deleteQuestConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String deleteQuestConfirmation(String title);

  /// No description provided for @characterCreatedName.
  ///
  /// In en, this message translates to:
  /// **'{name} created successfully!'**
  String characterCreatedName(String name);

  /// No description provided for @errorCreatingCharacter.
  ///
  /// In en, this message translates to:
  /// **'Error creating character: {error}'**
  String errorCreatingCharacter(String error);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Cancel Character Creation?'**
  String get cancelCharacterCreationTitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'All progress will be lost.'**
  String get cancelCharacterCreationMessage;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Continue Editing'**
  String get continueEditing;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Please select a class first'**
  String get selectClassFirst;

  /// No description provided for @selectSkillProficiencies.
  ///
  /// In en, this message translates to:
  /// **'Select {count} skill proficiencies for your {characterClass}.'**
  String selectSkillProficiencies(int count, String characterClass);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'All skills selected!'**
  String get allSkillsSelected;

  /// No description provided for @chooseMoreSkills.
  ///
  /// In en, this message translates to:
  /// **'Choose {count} more skill{count, plural, =1{} other{s}}'**
  String chooseMoreSkills(int count);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Dexterity - Balance, tumbling, aerial maneuvers'**
  String get skillAcrobaticsDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Wisdom - Calming animals, riding, training'**
  String get skillAnimalHandlingDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Intelligence - Magic, spells, magical items'**
  String get skillArcanaDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Strength - Climbing, jumping, swimming'**
  String get skillAthleticsDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Charisma - Lying, disguising, misleading'**
  String get skillDeceptionDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Intelligence - Historical events, legends'**
  String get skillHistoryDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Wisdom - Reading intentions, detecting lies'**
  String get skillInsightDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Charisma - Threats, coercion'**
  String get skillIntimidationDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Intelligence - Finding clues, deduction'**
  String get skillInvestigationDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Wisdom - Stabilizing, diagnosing'**
  String get skillMedicineDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Intelligence - Terrain, plants, animals'**
  String get skillNatureDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Wisdom - Spotting, hearing, detecting'**
  String get skillPerceptionDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Charisma - Music, dance, acting'**
  String get skillPerformanceDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Charisma - Diplomacy, negotiations'**
  String get skillPersuasionDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Intelligence - Deities, rites, prayers'**
  String get skillReligionDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Dexterity - Pickpocketing, tricks'**
  String get skillSleightOfHandDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Dexterity - Hiding, moving silently'**
  String get skillStealthDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Wisdom - Tracking, foraging, navigation'**
  String get skillSurvivalDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose Background'**
  String get chooseBackground;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Your background represents your character\'s past and grants additional skills.'**
  String get backgroundDescription;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No backgrounds available'**
  String get noBackgroundsAvailable;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'STR'**
  String get abilityStrAbbr;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'DEX'**
  String get abilityDexAbbr;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'CON'**
  String get abilityConAbbr;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'INT'**
  String get abilityIntAbbr;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'WIS'**
  String get abilityWisAbbr;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'CHA'**
  String get abilityChaAbbr;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Ammunition'**
  String get propertyAmmunition;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Finesse'**
  String get propertyFinesse;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get propertyHeavy;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get propertyLight;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get propertyLoading;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get propertyRange;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Reach'**
  String get propertyReach;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Special'**
  String get propertySpecial;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Thrown'**
  String get propertyThrown;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Two-Handed'**
  String get propertyTwoHanded;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Versatile'**
  String get propertyVersatile;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Martial'**
  String get propertyMartial;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get propertySimple;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Light Armor'**
  String get armorTypeLight;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Medium Armor'**
  String get armorTypeMedium;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Heavy Armor'**
  String get armorTypeHeavy;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Shield'**
  String get armorTypeShield;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Search spells...'**
  String get searchSpells;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No spells found'**
  String get noSpellsFound;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters'**
  String get tryAdjustingFilters;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Casting Time'**
  String get castingTime;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get components;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materials;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Concentration'**
  String get concentration;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Ritual'**
  String get ritual;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'At Higher Levels'**
  String get atHigherLevels;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get classes;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Add to Known Spells'**
  String get addToKnown;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Remove from Known Spells'**
  String get removeFromKnown;

  /// No description provided for @addedToKnown.
  ///
  /// In en, this message translates to:
  /// **'Added \"{name}\" to known spells'**
  String addedToKnown(String name);

  /// No description provided for @removedFromKnown.
  ///
  /// In en, this message translates to:
  /// **'Removed \"{name}\" from known spells'**
  String removedFromKnown(String name);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Available to Learn'**
  String get availableToLearn;

  /// No description provided for @availableAtLevel.
  ///
  /// In en, this message translates to:
  /// **'Available at Level {level}'**
  String availableAtLevel(int level);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get filterAvailability;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get filterClass;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get filterLevel;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get filterSchool;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'All Spells'**
  String get filterAllSpells;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Can Learn Now'**
  String get filterCanLearnNow;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Available to Class'**
  String get filterAvailableToClass;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'All Classes'**
  String get filterAllClasses;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'All Levels'**
  String get filterAllLevels;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'All Schools'**
  String get filterAllSchools;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Encumbrance'**
  String get encumbrance;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Attunement'**
  String get attunement;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Maximum attunement slots reached (3/3). Unequip something first.'**
  String get attunementLimitReached;

  /// No description provided for @deleteItemConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Throw away {name}?'**
  String deleteItemConfirmation(String name);

  /// No description provided for @spellsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} spell{count, plural, =1{} other{s}}'**
  String spellsCount(int count);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Prepared'**
  String get preparedSpells;

  /// No description provided for @preparedSpellsCount.
  ///
  /// In en, this message translates to:
  /// **'Prepared: {current} / {max}'**
  String preparedSpellsCount(int current, int max);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Spell Almanac'**
  String get spellAlmanacTitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'ARCHETYPE'**
  String get fighterArchetype;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Improved Critical'**
  String get improvedCritical;

  /// No description provided for @criticalHitTarget.
  ///
  /// In en, this message translates to:
  /// **'Critical Hit: {range}'**
  String criticalHitTarget(String range);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Fighting Styles'**
  String get fightingStylesTitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Free Action'**
  String get actionTypeFree;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Class Features'**
  String get featuresStepTitle;

  /// No description provided for @featuresStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'As a level 1 {className}, you gain the following features:'**
  String featuresStepSubtitle(String className);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No features available at level 1 for this class.'**
  String get noFeaturesAtLevel1;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Spells'**
  String get spellsStepTitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Select spells for your character (Level 0 & 1).'**
  String get selectSpellsInstruction;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Select your skill proficiencies.'**
  String get selectSkillsInstruction;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Please select skills first'**
  String get selectSkillsFirst;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Expertise'**
  String get expertise;

  /// No description provided for @noSpellsFoundForClass.
  ///
  /// In en, this message translates to:
  /// **'No spells found for {className}'**
  String noSpellsFoundForClass(String className);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Level 1 Spells'**
  String get level1Spells;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Spell selection will be available in future updates. For now, please add spells manually in the character sheet after creation.'**
  String get spellsStepPlaceholder;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Starting Equipment'**
  String get equipmentStepTitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose your starting equipment for your class'**
  String get equipmentStepSubtitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose Equipment Package'**
  String get chooseEquipmentPackage;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Standard Package'**
  String get packageStandard;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Recommended starting equipment for your class'**
  String get packageStandardDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Alternative Package'**
  String get packageAlternative;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Different equipment options'**
  String get packageAlternativeDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Custom Package'**
  String get packageCustom;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose items from catalog'**
  String get packageCustomDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Selected Equipment'**
  String get selectedEquipment;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No items selected'**
  String get noItemsSelected;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add Item\" to select equipment'**
  String get tapToAddItems;

  /// No description provided for @equipmentPreview.
  ///
  /// In en, this message translates to:
  /// **'{className} Equipment Preview'**
  String equipmentPreview(String className);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Tools & Gear'**
  String get toolsAndGear;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'This is a preview of typical starting equipment. You can customize your inventory after character creation.'**
  String get equipmentPreviewDisclaimer;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Item Catalog'**
  String get itemCatalog;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Create Item'**
  String get createItem;

  /// No description provided for @foundItems.
  ///
  /// In en, this message translates to:
  /// **'Found: {count} (selected: {selected})'**
  String foundItems(int count, int selected);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get noItemsFound;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Create Custom Item'**
  String get createCustomItem;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Add\nimage'**
  String get addImage;

  /// No description provided for @errorLoadingImage.
  ///
  /// In en, this message translates to:
  /// **'Error loading image: {error}'**
  String errorLoadingImage(String error);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get itemName;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'e.g., Sword of Light'**
  String get itemNameHint;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get enterItemName;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get itemDescription;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Describe the item...'**
  String get itemDescriptionHint;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get itemType;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Rarity'**
  String get itemRarity;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get itemWeight;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get itemValue;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get itemQuantity;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Minimum 1'**
  String get minQuantity1;

  /// No description provided for @itemAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} (x{quantity}) added'**
  String itemAdded(String name, int quantity);

  /// No description provided for @errorCreatingItem.
  ///
  /// In en, this message translates to:
  /// **'Error creating item: {error}'**
  String errorCreatingItem(String error);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get rarityCommon;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Uncommon'**
  String get rarityUncommon;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Rare'**
  String get rarityRare;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Very Rare'**
  String get rarityVeryRare;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Legendary'**
  String get rarityLegendary;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Artifact'**
  String get rarityArtifact;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get methodStandard;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Point Buy'**
  String get methodPointBuy;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Manual Entry'**
  String get methodManual;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'High Contrast'**
  String get highContrast;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Increases visibility with sharper colors'**
  String get highContrastDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Color Scheme'**
  String get colorScheme;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Developed by'**
  String get developedBy;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'May your d20 always land on 20!'**
  String get d20wish;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Character Ready!'**
  String get characterReady;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Review your choices before finalizing'**
  String get reviewChoices;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'(Unnamed)'**
  String get unnamed;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get basicInfo;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Your character will be created at level 1. Additional features will be added based on your class and background.'**
  String get level1Info;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get hpMax;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Content Management'**
  String get contentManagement;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Managed Libraries'**
  String get libraryManagerTitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Manage Libraries'**
  String get manageLibraries;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Import and manage external content (XML)'**
  String get manageLibrariesSubtitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Import XML'**
  String get importXML;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No imported libraries'**
  String get noLibraries;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Tap + to import content from FC5 XML files'**
  String get noLibrariesHint;

  /// No description provided for @libraryStats.
  ///
  /// In en, this message translates to:
  /// **'{items} Items, {spells} Spells'**
  String libraryStats(int items, int spells);

  /// No description provided for @libraryImportedDate.
  ///
  /// In en, this message translates to:
  /// **'Imported {date}'**
  String libraryImportedDate(String date);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Delete Library?'**
  String get deleteLibraryTitle;

  /// No description provided for @deleteLibraryMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove \"{name}\" and all associated content:\n\n• {items} Items\n• {spells} Spells\n\nThis action cannot be undone.'**
  String deleteLibraryMessage(String name, int items, int spells);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Library deleted successfully'**
  String get libraryDeleted;

  /// No description provided for @errorDeletingLibrary.
  ///
  /// In en, this message translates to:
  /// **'Error deleting library: {error}'**
  String errorDeletingLibrary(String error);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'The Forge'**
  String get forgeTitle;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'IDENTITY'**
  String get identitySection;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'CHARACTERISTICS'**
  String get characteristicsSection;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'STATS'**
  String get statsSection;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'MAGIC & PROPERTIES'**
  String get magicPropertiesSection;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Magical Item'**
  String get isMagical;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Requires Attunement'**
  String get requiresAttunement;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Weapon Stats'**
  String get weaponStats;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Damage Dice'**
  String get damageDice;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'1d8'**
  String get damageDiceHint;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Armor Stats'**
  String get armorStats;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Add DEX Modifier'**
  String get addDexModifier;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Stealth Disadvantage'**
  String get stealthDisadvantage;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Forge Item'**
  String get forgeItem;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'e.g. Excalibur'**
  String get itemExample;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get typeTool;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Treasure'**
  String get typeTreasure;

  /// No description provided for @cantripsTab.
  ///
  /// In en, this message translates to:
  /// **'Cantrips ({current}/{max})'**
  String cantripsTab(int current, int max);

  /// No description provided for @level1TabKnown.
  ///
  /// In en, this message translates to:
  /// **'Level 1 ({current}/{max})'**
  String level1TabKnown(int current, int max);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Level 1 (All)'**
  String get level1TabAll;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No spells available at level 1'**
  String get noSpellsAtLevel1;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get useAction;

  /// No description provided for @useActionCost.
  ///
  /// In en, this message translates to:
  /// **'Use ({cost})'**
  String useActionCost(String cost);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Ki Points'**
  String get kiPoints;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Martial Arts Die'**
  String get martialArtsDie;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Rage'**
  String get rage;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Rage Damage'**
  String get rageDamage;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Raging'**
  String get raging;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Sneak Attack'**
  String get sneakAttack;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Damage'**
  String get sneakAttackDamage;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Second Wind'**
  String get secondWind;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Action Surge'**
  String get actionSurge;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Healing'**
  String get healing;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Combat Tactics'**
  String get fighterTactics;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Champion'**
  String get fighterChampion;

  /// No description provided for @sneakAttackRoll.
  ///
  /// In en, this message translates to:
  /// **'Sneak Attack: {total} ({dice})'**
  String sneakAttackRoll(String total, String dice);

  /// No description provided for @kiStrikeRoll.
  ///
  /// In en, this message translates to:
  /// **'Ki Strike: {total} ({dice})'**
  String kiStrikeRoll(String total, String dice);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get rageInactive;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Heal'**
  String get healShort;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Indomitable'**
  String get indomitable;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Reroll Saving Throw!'**
  String get rerollSave;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No traits'**
  String get noTraits;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Martial Arts'**
  String get martialArts;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Bardic Inspiration'**
  String get bardicInspiration;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Wild Shape'**
  String get wildShape;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get wildShapeDuration;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Max CR'**
  String get wildShapeMaxCR;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Restrictions'**
  String get wildShapeRestrictions;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No restrictions'**
  String get noRestrictions;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No flying'**
  String get noFlying;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'No flying/swimming'**
  String get noFlyingSwimming;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Transform'**
  String get transform;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Revert to True Form'**
  String get revertForm;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Beast HP'**
  String get beastHP;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Beast Name'**
  String get beastName;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Natural Recovery'**
  String get naturalRecovery;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Recover Spell Slots'**
  String get recoverSpellSlots;

  /// No description provided for @selectSlotsToRecover.
  ///
  /// In en, this message translates to:
  /// **'Select slots to recover (Max levels: {max})'**
  String selectSlotsToRecover(int max);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Current Spell Slots'**
  String get currentSpellSlots;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Tap note to use/restore charge'**
  String get tapToUse;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get used;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'All spell slots are full'**
  String get allSpellSlotsFull;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Arcane Recovery'**
  String get arcaneRecovery;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'School of Evocation'**
  String get traditionEvocation;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'School of Abjuration'**
  String get traditionAbjuration;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'School of Conjuration'**
  String get traditionConjuration;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'School of Divination'**
  String get traditionDivination;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'School of Enchantment'**
  String get traditionEnchantment;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'School of Illusion'**
  String get traditionIllusion;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'School of Necromancy'**
  String get traditionNecromancy;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'School of Transmutation'**
  String get traditionTransmutation;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'You gain the ability to channel divine energy directly from your deity, using that energy to fuel magical effects. You start with two such effects: Turn Undead and an effect determined by your domain. Some domains grant you additional effects as you advance in levels, as noted in the domain description.\n\nWhen you use your Channel Divinity, you choose which effect to create. You must then finish a short or long rest to use your Channel Divinity again.\n\nSome Channel Divinity effects require saving throws. When you use such an effect from this class, the DC equals your cleric spell save DC.'**
  String get channelDivinityRules;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Life Domain'**
  String get domainLife;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Light Domain'**
  String get domainLight;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Knowledge Domain'**
  String get domainKnowledge;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Nature Domain'**
  String get domainNature;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Tempest Domain'**
  String get domainTempest;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Trickery Domain'**
  String get domainTrickery;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'War Domain'**
  String get domainWar;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Death Domain'**
  String get domainDeath;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Oath of Devotion'**
  String get oathDevotion;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Oath of the Ancients'**
  String get oathAncients;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Oath of Vengeance'**
  String get oathVengeance;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Oath of Conquest'**
  String get oathConquest;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Oath of Redemption'**
  String get oathRedemption;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Divine Intervention'**
  String get divineIntervention;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'You can call on your deity to intervene on your behalf when your need is great.\n\nImploring your deity\'s aid requires you to use your action. Describe the assistance you seek, and roll percentile dice. If you roll a number equal to or lower than your cleric level, your deity intervenes. The DM chooses the nature of the intervention; the effect of any cleric spell or cleric domain spell would be appropriate.\n\nIf your deity intervenes, you can\'t use this feature again for 7 days. Otherwise, you can use it again after you finish a long rest.\n\nAt 20th level, your call for intervention succeeds automatically, no roll required.'**
  String get divineInterventionRules;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Turn Undead'**
  String get turnUndead;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Destroy Undead'**
  String get destroyUndead;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Max CR'**
  String get maxCR;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Used Turn/Destroy Undead (Channel Divinity spent)'**
  String get usedChannelDivinity;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'As an action, you present your holy symbol and speak a prayer censuring the undead. Each undead that can see or hear you within 30 feet of you must make a Wisdom saving throw. If the creature fails its saving throw, it is turned for 1 minute or until it takes any damage.\n\nA turned creature must spend its turns trying to move as far away from you as it can, and it can\'t willingly move to a space within 30 feet of you. It also can\'t take reactions. For its action, it can use only the Dash action or try to escape from an effect that prevents it from moving. If there\'s nowhere to move, the creature can use the Dodge action.'**
  String get turnUndeadRules;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'When an undead fails its saving throw against your Turn Undead feature, the creature is instantly destroyed if its challenge rating is at or below a certain threshold, as shown in the Destroy Undead table.'**
  String get destroyUndeadRules;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Call upon Deity'**
  String get callUponDeity;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Reset 7-day Cooldown'**
  String get resetCooldown;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Success! The gods have heard your prayer!'**
  String get interventionSuccess;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'The deity did not respond to your call.'**
  String get interventionFailure;

  /// No description provided for @interventionRollResult.
  ///
  /// In en, this message translates to:
  /// **'Rolled: {value}'**
  String interventionRollResult(String value);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'ARCHETYPE'**
  String get hunterArchetype;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Hunter\'s Mark'**
  String get huntersMarkTracker;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Target Name'**
  String get markTargetName;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'+1d6 damage / Advantage'**
  String get markBonusDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Move Mark'**
  String get moveMark;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Hide in Plain Sight'**
  String get hideInPlainSight;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'+10 to Stealth while not moving'**
  String get hideInPlainSightDesc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get markActivate;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get markDrop;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'A 3rd-level mark lasts 8 hours, 5th-level lasts 24 hours.'**
  String get markDurationHint;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Choose a spell slot to cast Hunter\'s Mark'**
  String get markSlotChoose;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Spent 1 minute to camouflage'**
  String get hideSpentMinute;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Spell not found in the database'**
  String get spellNotFound;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Stealth Difficulty (Enemy Perception)'**
  String get stealthDifficulty;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Roll'**
  String get rollStealthBtn;

  /// No description provided for @stealthSuccess.
  ///
  /// In en, this message translates to:
  /// **'Stealth: {total} (DC {dc}). Success! You blend into the shadows.'**
  String stealthSuccess(int total, int dc);

  /// No description provided for @stealthFailure.
  ///
  /// In en, this message translates to:
  /// **'Stealth: {total} (DC {dc}). Failure! {reason}'**
  String stealthFailure(int total, int dc, String reason);

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'You tripped over a bucket!'**
  String get stealthFail1;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'A gold coin fell from your pocket with a loud ring.'**
  String get stealthFail2;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Archery'**
  String get fs_archery_name;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'You gain a +2 bonus to attack rolls you make with ranged weapons.'**
  String get fs_archery_desc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Defense'**
  String get fs_defense_name;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'While you are wearing armor, you gain a +1 bonus to AC.'**
  String get fs_defense_desc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Dueling'**
  String get fs_dueling_name;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'When you are wielding a melee weapon in one hand and no other weapons, you gain a +2 bonus to damage rolls with that weapon.'**
  String get fs_dueling_desc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Great Weapon Fighting'**
  String get fs_great_weapon_name;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'When you roll a 1 or 2 on a damage die for an attack you make with a melee weapon that you are wielding with two hands, you can reroll the die...'**
  String get fs_great_weapon_desc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Protection'**
  String get fs_protection_name;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'When a creature you can see attacks a target other than you that is within 5 feet of you, you can use your reaction to impose disadvantage...'**
  String get fs_protection_desc;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Two-Weapon Fighting'**
  String get fs_two_weapon_name;

  /// No description provided for @fs_two_weapon_desc.
  ///
  /// In en, this message translates to:
  /// **'When you engage in two-weapon fighting, you can add your ability modifier to the damage of the second attack.'**
  String get fs_two_weapon_desc;

  /// No description provided for @empty_roster_title.
  ///
  /// In en, this message translates to:
  /// **'The tavern is empty'**
  String get empty_roster_title;

  /// No description provided for @empty_roster_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first hero to begin the adventure!'**
  String get empty_roster_subtitle;

  /// No description provided for @create_first_character_btn.
  ///
  /// In en, this message translates to:
  /// **'Create Character'**
  String get create_first_character_btn;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'You sneezed loudly.'**
  String get stealthFail3;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Your stomach growled treacherously.'**
  String get stealthFail4;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'You stepped on a sleeping cat.'**
  String get stealthFail5;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Your cloak caught on a nail.'**
  String get stealthFail6;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'The loudest branch in the forest just snapped under your boot.'**
  String get stealthFail7;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'You tried to blend into a shadow, but it was an enemy.'**
  String get stealthFail8;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Your boot squeaked. Very loudly.'**
  String get stealthFail9;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'You forgot to cover your lantern.'**
  String get stealthFail10;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'Your scabbard loudly hit the doorframe.'**
  String get stealthFail11;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'You are breathing way too loudly.'**
  String get stealthFail12;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'A random pigeon gave away your position.'**
  String get stealthFail13;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'You hiccupped at the worst possible moment.'**
  String get stealthFail14;

  /// No description provided
  ///
  /// In en, this message translates to:
  /// **'You epically tripped on flat ground.'**
  String get stealthFail15;

  /// Dialog title for Lay on Hands amount.
  ///
  /// In en, this message translates to:
  /// **'Custom Heal Amount'**
  String get customHealAmount;

  /// Textfield label for spending HP.
  ///
  /// In en, this message translates to:
  /// **'HP to spend'**
  String get hpToSpend;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
