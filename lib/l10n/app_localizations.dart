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

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'QD&D'**
  String get appTitle;

  /// The app subtitle which should NOT be translated
  ///
  /// In en, this message translates to:
  /// **'Roleplay Companion'**
  String get appSubtitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @characters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get characters;

  /// No description provided for @compendium.
  ///
  /// In en, this message translates to:
  /// **'Compendium'**
  String get compendium;

  /// No description provided for @diceRoller.
  ///
  /// In en, this message translates to:
  /// **'Dice Roller'**
  String get diceRoller;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @spells.
  ///
  /// In en, this message translates to:
  /// **'Spells'**
  String get spells;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @combat.
  ///
  /// In en, this message translates to:
  /// **'Combat'**
  String get combat;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @quests.
  ///
  /// In en, this message translates to:
  /// **'Quests'**
  String get quests;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @race.
  ///
  /// In en, this message translates to:
  /// **'Race'**
  String get race;

  /// No description provided for @background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get background;

  /// No description provided for @classLabel.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get classLabel;

  /// No description provided for @subclass.
  ///
  /// In en, this message translates to:
  /// **'Subclass'**
  String get subclass;

  /// No description provided for @alignment.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get alignment;

  /// No description provided for @experience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get experience;

  /// No description provided for @playerName.
  ///
  /// In en, this message translates to:
  /// **'Player Name'**
  String get playerName;

  /// No description provided for @createNewCharacter.
  ///
  /// In en, this message translates to:
  /// **'Create New Character'**
  String get createNewCharacter;

  /// No description provided for @importFC5.
  ///
  /// In en, this message translates to:
  /// **'Import from Fight Club 5'**
  String get importFC5;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @deleteConfirmationTitle.
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

  /// No description provided for @abilities.
  ///
  /// In en, this message translates to:
  /// **'Abilities'**
  String get abilities;

  /// No description provided for @savingThrows.
  ///
  /// In en, this message translates to:
  /// **'Saving Throws'**
  String get savingThrows;

  /// No description provided for @skills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skills;

  /// No description provided for @abilityStr.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get abilityStr;

  /// No description provided for @abilityDex.
  ///
  /// In en, this message translates to:
  /// **'Dexterity'**
  String get abilityDex;

  /// No description provided for @abilityCon.
  ///
  /// In en, this message translates to:
  /// **'Constitution'**
  String get abilityCon;

  /// No description provided for @abilityInt.
  ///
  /// In en, this message translates to:
  /// **'Intelligence'**
  String get abilityInt;

  /// No description provided for @abilityWis.
  ///
  /// In en, this message translates to:
  /// **'Wisdom'**
  String get abilityWis;

  /// No description provided for @abilityCha.
  ///
  /// In en, this message translates to:
  /// **'Charisma'**
  String get abilityCha;

  /// No description provided for @skillAthletics.
  ///
  /// In en, this message translates to:
  /// **'Athletics'**
  String get skillAthletics;

  /// No description provided for @skillAcrobatics.
  ///
  /// In en, this message translates to:
  /// **'Acrobatics'**
  String get skillAcrobatics;

  /// No description provided for @skillSleightOfHand.
  ///
  /// In en, this message translates to:
  /// **'Sleight of Hand'**
  String get skillSleightOfHand;

  /// No description provided for @skillStealth.
  ///
  /// In en, this message translates to:
  /// **'Stealth'**
  String get skillStealth;

  /// No description provided for @skillArcana.
  ///
  /// In en, this message translates to:
  /// **'Arcana'**
  String get skillArcana;

  /// No description provided for @skillHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get skillHistory;

  /// No description provided for @skillInvestigation.
  ///
  /// In en, this message translates to:
  /// **'Investigation'**
  String get skillInvestigation;

  /// No description provided for @skillNature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get skillNature;

  /// No description provided for @skillReligion.
  ///
  /// In en, this message translates to:
  /// **'Religion'**
  String get skillReligion;

  /// No description provided for @skillAnimalHandling.
  ///
  /// In en, this message translates to:
  /// **'Animal Handling'**
  String get skillAnimalHandling;

  /// No description provided for @skillInsight.
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get skillInsight;

  /// No description provided for @skillMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get skillMedicine;

  /// No description provided for @skillPerception.
  ///
  /// In en, this message translates to:
  /// **'Perception'**
  String get skillPerception;

  /// No description provided for @skillSurvival.
  ///
  /// In en, this message translates to:
  /// **'Survival'**
  String get skillSurvival;

  /// No description provided for @skillDeception.
  ///
  /// In en, this message translates to:
  /// **'Deception'**
  String get skillDeception;

  /// No description provided for @skillIntimidation.
  ///
  /// In en, this message translates to:
  /// **'Intimidation'**
  String get skillIntimidation;

  /// No description provided for @skillPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get skillPerformance;

  /// No description provided for @skillPersuasion.
  ///
  /// In en, this message translates to:
  /// **'Persuasion'**
  String get skillPersuasion;

  /// No description provided for @combatDashboard.
  ///
  /// In en, this message translates to:
  /// **'Combat Dashboard'**
  String get combatDashboard;

  /// No description provided for @hitPoints.
  ///
  /// In en, this message translates to:
  /// **'Hit Points'**
  String get hitPoints;

  /// No description provided for @hpShort.
  ///
  /// In en, this message translates to:
  /// **'HP'**
  String get hpShort;

  /// No description provided for @armorClassAC.
  ///
  /// In en, this message translates to:
  /// **'AC'**
  String get armorClassAC;

  /// No description provided for @initiativeINIT.
  ///
  /// In en, this message translates to:
  /// **'INIT'**
  String get initiativeINIT;

  /// No description provided for @speedSPEED.
  ///
  /// In en, this message translates to:
  /// **'SPEED'**
  String get speedSPEED;

  /// No description provided for @proficiencyPROF.
  ///
  /// In en, this message translates to:
  /// **'PROF'**
  String get proficiencyPROF;

  /// No description provided for @weaponsAttacks.
  ///
  /// In en, this message translates to:
  /// **'Weapons & Attacks'**
  String get weaponsAttacks;

  /// No description provided for @shortRest.
  ///
  /// In en, this message translates to:
  /// **'Short Rest'**
  String get shortRest;

  /// No description provided for @longRest.
  ///
  /// In en, this message translates to:
  /// **'Long Rest'**
  String get longRest;

  /// No description provided for @enterCombatMode.
  ///
  /// In en, this message translates to:
  /// **'Enter Combat Mode'**
  String get enterCombatMode;

  /// No description provided for @rest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get rest;

  /// No description provided for @shortRestDescription.
  ///
  /// In en, this message translates to:
  /// **'Recover short-rest features and spend Hit Dice?'**
  String get shortRestDescription;

  /// No description provided for @longRestDescription.
  ///
  /// In en, this message translates to:
  /// **'Recover all HP, spell slots, and features?'**
  String get longRestDescription;

  /// No description provided for @restedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Rested successfully'**
  String get restedSuccess;

  /// No description provided for @unarmedStrike.
  ///
  /// In en, this message translates to:
  /// **'Unarmed Strike'**
  String get unarmedStrike;

  /// No description provided for @hit.
  ///
  /// In en, this message translates to:
  /// **'HIT'**
  String get hit;

  /// No description provided for @dmg.
  ///
  /// In en, this message translates to:
  /// **'DMG'**
  String get dmg;

  /// No description provided for @damageTypeBludgeoning.
  ///
  /// In en, this message translates to:
  /// **'Bludgeoning'**
  String get damageTypeBludgeoning;

  /// No description provided for @damageTypePiercing.
  ///
  /// In en, this message translates to:
  /// **'Piercing'**
  String get damageTypePiercing;

  /// No description provided for @damageTypeSlashing.
  ///
  /// In en, this message translates to:
  /// **'Slashing'**
  String get damageTypeSlashing;

  /// No description provided for @damageTypePhysical.
  ///
  /// In en, this message translates to:
  /// **'Physical'**
  String get damageTypePhysical;

  /// No description provided for @searchItems.
  ///
  /// In en, this message translates to:
  /// **'Search items...'**
  String get searchItems;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @sortWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get sortWeight;

  /// No description provided for @sortValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get sortValue;

  /// No description provided for @sortType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get sortType;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterEquipped.
  ///
  /// In en, this message translates to:
  /// **'Equipped'**
  String get filterEquipped;

  /// No description provided for @filterUnequipped.
  ///
  /// In en, this message translates to:
  /// **'Unequipped'**
  String get filterUnequipped;

  /// No description provided for @typeWeapon.
  ///
  /// In en, this message translates to:
  /// **'Weapons'**
  String get typeWeapon;

  /// No description provided for @typeArmor.
  ///
  /// In en, this message translates to:
  /// **'Armor'**
  String get typeArmor;

  /// No description provided for @typeGear.
  ///
  /// In en, this message translates to:
  /// **'Gear'**
  String get typeGear;

  /// No description provided for @typeConsumable.
  ///
  /// In en, this message translates to:
  /// **'Consumables'**
  String get typeConsumable;

  /// No description provided for @totalWeight.
  ///
  /// In en, this message translates to:
  /// **'Total Weight'**
  String get totalWeight;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @editCurrency.
  ///
  /// In en, this message translates to:
  /// **'Edit Currency'**
  String get editCurrency;

  /// No description provided for @currencyUpdated.
  ///
  /// In en, this message translates to:
  /// **'Currency updated'**
  String get currencyUpdated;

  /// No description provided for @currencyPP.
  ///
  /// In en, this message translates to:
  /// **'Platinum (PP)'**
  String get currencyPP;

  /// No description provided for @currencyGP.
  ///
  /// In en, this message translates to:
  /// **'Gold (GP)'**
  String get currencyGP;

  /// No description provided for @currencySP.
  ///
  /// In en, this message translates to:
  /// **'Silver (SP)'**
  String get currencySP;

  /// No description provided for @currencyCP.
  ///
  /// In en, this message translates to:
  /// **'Copper (CP)'**
  String get currencyCP;

  /// No description provided for @inventoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Inventory is empty'**
  String get inventoryEmpty;

  /// No description provided for @inventoryEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add items'**
  String get inventoryEmptyHint;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @unequip.
  ///
  /// In en, this message translates to:
  /// **'Unequip'**
  String get unequip;

  /// No description provided for @equip.
  ///
  /// In en, this message translates to:
  /// **'Equip'**
  String get equip;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @itemRemoved.
  ///
  /// In en, this message translates to:
  /// **'Item removed'**
  String get itemRemoved;

  /// No description provided for @itemEquipped.
  ///
  /// In en, this message translates to:
  /// **'Equipped'**
  String get itemEquipped;

  /// No description provided for @itemUnequipped.
  ///
  /// In en, this message translates to:
  /// **'Unequipped'**
  String get itemUnequipped;

  /// No description provided for @weaponProperties.
  ///
  /// In en, this message translates to:
  /// **'WEAPON PROPERTIES'**
  String get weaponProperties;

  /// No description provided for @armorProperties.
  ///
  /// In en, this message translates to:
  /// **'ARMOR PROPERTIES'**
  String get armorProperties;

  /// No description provided for @damage.
  ///
  /// In en, this message translates to:
  /// **'Damage'**
  String get damage;

  /// No description provided for @damageType.
  ///
  /// In en, this message translates to:
  /// **'Damage Type'**
  String get damageType;

  /// No description provided for @versatileDamage.
  ///
  /// In en, this message translates to:
  /// **'Versatile Damage'**
  String get versatileDamage;

  /// No description provided for @range.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get range;

  /// No description provided for @properties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get properties;

  /// No description provided for @armorClass.
  ///
  /// In en, this message translates to:
  /// **'Armor Class'**
  String get armorClass;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @strRequirement.
  ///
  /// In en, this message translates to:
  /// **'STR Requirement'**
  String get strRequirement;

  /// No description provided for @stealth.
  ///
  /// In en, this message translates to:
  /// **'Stealth'**
  String get stealth;

  /// No description provided for @disadvantage.
  ///
  /// In en, this message translates to:
  /// **'Disadvantage'**
  String get disadvantage;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @spellAlmanac.
  ///
  /// In en, this message translates to:
  /// **'Spell Almanac'**
  String get spellAlmanac;

  /// No description provided for @resources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get resources;

  /// No description provided for @activeAbilities.
  ///
  /// In en, this message translates to:
  /// **'Active Abilities'**
  String get activeAbilities;

  /// No description provided for @magic.
  ///
  /// In en, this message translates to:
  /// **'Magic'**
  String get magic;

  /// No description provided for @spellsList.
  ///
  /// In en, this message translates to:
  /// **'Spells List'**
  String get spellsList;

  /// No description provided for @passiveTraits.
  ///
  /// In en, this message translates to:
  /// **'Passive Traits'**
  String get passiveTraits;

  /// No description provided for @cantrips.
  ///
  /// In en, this message translates to:
  /// **'Cantrips'**
  String get cantrips;

  /// No description provided for @levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelLabel(int level);

  /// No description provided for @levelShort.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get levelShort;

  /// No description provided for @noSpellsLearned.
  ///
  /// In en, this message translates to:
  /// **'No spells learned yet'**
  String get noSpellsLearned;

  /// No description provided for @castSpell.
  ///
  /// In en, this message translates to:
  /// **'Cast Spell'**
  String get castSpell;

  /// No description provided for @castAction.
  ///
  /// In en, this message translates to:
  /// **'Cast {name}'**
  String castAction(String name);

  /// No description provided for @chooseSpellSlot.
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

  /// No description provided for @upcast.
  ///
  /// In en, this message translates to:
  /// **'Upcast'**
  String get upcast;

  /// No description provided for @noSlotsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No spell slots available!'**
  String get noSlotsAvailable;

  /// No description provided for @spellCastSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} cast!'**
  String spellCastSuccess(Object name);

  /// No description provided for @spellCastLevelSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} cast at level {level}!'**
  String spellCastLevelSuccess(Object level, Object name);

  /// No description provided for @spellAbility.
  ///
  /// In en, this message translates to:
  /// **'Ability'**
  String get spellAbility;

  /// No description provided for @spellSaveDC.
  ///
  /// In en, this message translates to:
  /// **'Save DC'**
  String get spellSaveDC;

  /// No description provided for @spellAttack.
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get spellAttack;

  /// No description provided for @lvlShort.
  ///
  /// In en, this message translates to:
  /// **'Lvl {level}'**
  String lvlShort(int level);

  /// No description provided for @useChannelDivinity.
  ///
  /// In en, this message translates to:
  /// **'Use Channel Divinity ({count} left)'**
  String useChannelDivinity(int count);

  /// No description provided for @noChannelDivinity.
  ///
  /// In en, this message translates to:
  /// **'No Channel Divinity charges'**
  String get noChannelDivinity;

  /// No description provided for @schoolAbjuration.
  ///
  /// In en, this message translates to:
  /// **'Abjuration'**
  String get schoolAbjuration;

  /// No description provided for @schoolConjuration.
  ///
  /// In en, this message translates to:
  /// **'Conjuration'**
  String get schoolConjuration;

  /// No description provided for @schoolDivination.
  ///
  /// In en, this message translates to:
  /// **'Divination'**
  String get schoolDivination;

  /// No description provided for @schoolEnchantment.
  ///
  /// In en, this message translates to:
  /// **'Enchantment'**
  String get schoolEnchantment;

  /// No description provided for @schoolEvocation.
  ///
  /// In en, this message translates to:
  /// **'Evocation'**
  String get schoolEvocation;

  /// No description provided for @schoolIllusion.
  ///
  /// In en, this message translates to:
  /// **'Illusion'**
  String get schoolIllusion;

  /// No description provided for @schoolNecromancy.
  ///
  /// In en, this message translates to:
  /// **'Necromancy'**
  String get schoolNecromancy;

  /// No description provided for @schoolTransmutation.
  ///
  /// In en, this message translates to:
  /// **'Transmutation'**
  String get schoolTransmutation;

  /// No description provided for @combatStats.
  ///
  /// In en, this message translates to:
  /// **'Combat Stats'**
  String get combatStats;

  /// No description provided for @rollInitiative.
  ///
  /// In en, this message translates to:
  /// **'Roll Initiative'**
  String get rollInitiative;

  /// No description provided for @endCombat.
  ///
  /// In en, this message translates to:
  /// **'End Combat'**
  String get endCombat;

  /// No description provided for @endCombatConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will reset the round counter.'**
  String get endCombatConfirm;

  /// No description provided for @nextRound.
  ///
  /// In en, this message translates to:
  /// **'Next Round'**
  String get nextRound;

  /// No description provided for @startCombat.
  ///
  /// In en, this message translates to:
  /// **'Start Combat'**
  String get startCombat;

  /// No description provided for @heal.
  ///
  /// In en, this message translates to:
  /// **'Heal'**
  String get heal;

  /// No description provided for @takeDamage.
  ///
  /// In en, this message translates to:
  /// **'Take Damage'**
  String get takeDamage;

  /// No description provided for @tempHp.
  ///
  /// In en, this message translates to:
  /// **'Temp HP'**
  String get tempHp;

  /// No description provided for @deathSaves.
  ///
  /// In en, this message translates to:
  /// **'Death Saves'**
  String get deathSaves;

  /// No description provided for @successes.
  ///
  /// In en, this message translates to:
  /// **'Successes'**
  String get successes;

  /// No description provided for @failures.
  ///
  /// In en, this message translates to:
  /// **'Failures'**
  String get failures;

  /// No description provided for @unconscious.
  ///
  /// In en, this message translates to:
  /// **'Unconscious'**
  String get unconscious;

  /// No description provided for @condition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get condition;

  /// No description provided for @conditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditions;

  /// No description provided for @actionTypeAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get actionTypeAction;

  /// No description provided for @actionTypeBonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus Action'**
  String get actionTypeBonus;

  /// No description provided for @actionTypeReaction.
  ///
  /// In en, this message translates to:
  /// **'Reaction'**
  String get actionTypeReaction;

  /// No description provided for @spellcastingAbility.
  ///
  /// In en, this message translates to:
  /// **'Spellcasting Ability'**
  String get spellcastingAbility;

  /// No description provided for @currencyPP_short.
  ///
  /// In en, this message translates to:
  /// **'pp'**
  String get currencyPP_short;

  /// No description provided for @currencyGP_short.
  ///
  /// In en, this message translates to:
  /// **'gp'**
  String get currencyGP_short;

  /// No description provided for @currencySP_short.
  ///
  /// In en, this message translates to:
  /// **'sp'**
  String get currencySP_short;

  /// No description provided for @currencyCP_short.
  ///
  /// In en, this message translates to:
  /// **'cp'**
  String get currencyCP_short;

  /// No description provided for @weightUnit.
  ///
  /// In en, this message translates to:
  /// **'lb'**
  String get weightUnit;

  /// No description provided for @currencyUnit.
  ///
  /// In en, this message translates to:
  /// **'gp'**
  String get currencyUnit;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @eyes.
  ///
  /// In en, this message translates to:
  /// **'Eyes'**
  String get eyes;

  /// No description provided for @skin.
  ///
  /// In en, this message translates to:
  /// **'Skin'**
  String get skin;

  /// No description provided for @hair.
  ///
  /// In en, this message translates to:
  /// **'Hair'**
  String get hair;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @rollType.
  ///
  /// In en, this message translates to:
  /// **'Roll Type'**
  String get rollType;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @advantage.
  ///
  /// In en, this message translates to:
  /// **'Advantage'**
  String get advantage;

  /// No description provided for @modifier.
  ///
  /// In en, this message translates to:
  /// **'Modifier'**
  String get modifier;

  /// No description provided for @rolling.
  ///
  /// In en, this message translates to:
  /// **'Rolling...'**
  String get rolling;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total: {value}'**
  String total(Object value);

  /// No description provided for @tapToRoll.
  ///
  /// In en, this message translates to:
  /// **'Tap to Roll'**
  String get tapToRoll;

  /// No description provided for @levelUp.
  ///
  /// In en, this message translates to:
  /// **'Level Up'**
  String get levelUp;

  /// No description provided for @levelUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Level Up'**
  String get levelUpTitle;

  /// No description provided for @currentLevel.
  ///
  /// In en, this message translates to:
  /// **'Current Level'**
  String get currentLevel;

  /// No description provided for @nextLevel.
  ///
  /// In en, this message translates to:
  /// **'Next Level'**
  String get nextLevel;

  /// No description provided for @hpIncrease.
  ///
  /// In en, this message translates to:
  /// **'HP Increase'**
  String get hpIncrease;

  /// No description provided for @chooseRace.
  ///
  /// In en, this message translates to:
  /// **'Choose Race'**
  String get chooseRace;

  /// No description provided for @chooseClass.
  ///
  /// In en, this message translates to:
  /// **'Choose Class'**
  String get chooseClass;

  /// No description provided for @hitDieType.
  ///
  /// In en, this message translates to:
  /// **'Hit Die: d{value}'**
  String hitDieType(Object value);

  /// No description provided for @damageTypeAcid.
  ///
  /// In en, this message translates to:
  /// **'Acid'**
  String get damageTypeAcid;

  /// No description provided for @damageTypeCold.
  ///
  /// In en, this message translates to:
  /// **'Cold'**
  String get damageTypeCold;

  /// No description provided for @damageTypeFire.
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get damageTypeFire;

  /// No description provided for @damageTypeForce.
  ///
  /// In en, this message translates to:
  /// **'Force'**
  String get damageTypeForce;

  /// No description provided for @damageTypeLightning.
  ///
  /// In en, this message translates to:
  /// **'Lightning'**
  String get damageTypeLightning;

  /// No description provided for @damageTypeNecrotic.
  ///
  /// In en, this message translates to:
  /// **'Necrotic'**
  String get damageTypeNecrotic;

  /// No description provided for @damageTypePoison.
  ///
  /// In en, this message translates to:
  /// **'Poison'**
  String get damageTypePoison;

  /// No description provided for @damageTypePsychic.
  ///
  /// In en, this message translates to:
  /// **'Psychic'**
  String get damageTypePsychic;

  /// No description provided for @damageTypeRadiant.
  ///
  /// In en, this message translates to:
  /// **'Radiant'**
  String get damageTypeRadiant;

  /// No description provided for @damageTypeThunder.
  ///
  /// In en, this message translates to:
  /// **'Thunder'**
  String get damageTypeThunder;

  /// No description provided for @conModIs.
  ///
  /// In en, this message translates to:
  /// **'Your Constitution modifier is {value}'**
  String conModIs(String value);

  /// No description provided for @average.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get average;

  /// No description provided for @safeChoice.
  ///
  /// In en, this message translates to:
  /// **'Safe choice'**
  String get safeChoice;

  /// No description provided for @roll.
  ///
  /// In en, this message translates to:
  /// **'Roll'**
  String get roll;

  /// No description provided for @riskIt.
  ///
  /// In en, this message translates to:
  /// **'Risk it!'**
  String get riskIt;

  /// No description provided for @conditionBlinded.
  ///
  /// In en, this message translates to:
  /// **'Blinded'**
  String get conditionBlinded;

  /// No description provided for @conditionCharmed.
  ///
  /// In en, this message translates to:
  /// **'Charmed'**
  String get conditionCharmed;

  /// No description provided for @conditionDeafened.
  ///
  /// In en, this message translates to:
  /// **'Deafened'**
  String get conditionDeafened;

  /// No description provided for @conditionFrightened.
  ///
  /// In en, this message translates to:
  /// **'Frightened'**
  String get conditionFrightened;

  /// No description provided for @conditionGrappled.
  ///
  /// In en, this message translates to:
  /// **'Grappled'**
  String get conditionGrappled;

  /// No description provided for @conditionIncapacitated.
  ///
  /// In en, this message translates to:
  /// **'Incapacitated'**
  String get conditionIncapacitated;

  /// No description provided for @conditionInvisible.
  ///
  /// In en, this message translates to:
  /// **'Invisible'**
  String get conditionInvisible;

  /// No description provided for @conditionParalyzed.
  ///
  /// In en, this message translates to:
  /// **'Paralyzed'**
  String get conditionParalyzed;

  /// No description provided for @conditionPetrified.
  ///
  /// In en, this message translates to:
  /// **'Petrified'**
  String get conditionPetrified;

  /// No description provided for @conditionPoisoned.
  ///
  /// In en, this message translates to:
  /// **'Poisoned'**
  String get conditionPoisoned;

  /// No description provided for @conditionProne.
  ///
  /// In en, this message translates to:
  /// **'Prone'**
  String get conditionProne;

  /// No description provided for @conditionRestrained.
  ///
  /// In en, this message translates to:
  /// **'Restrained'**
  String get conditionRestrained;

  /// No description provided for @conditionStunned.
  ///
  /// In en, this message translates to:
  /// **'Stunned'**
  String get conditionStunned;

  /// No description provided for @conditionUnconscious.
  ///
  /// In en, this message translates to:
  /// **'Unconscious'**
  String get conditionUnconscious;

  /// No description provided for @stepBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get stepBasicInfo;

  /// No description provided for @identity.
  ///
  /// In en, this message translates to:
  /// **'Character Identity'**
  String get identity;

  /// No description provided for @identitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create the foundation of your character'**
  String get identitySubtitle;

  /// No description provided for @charName.
  ///
  /// In en, this message translates to:
  /// **'Character Name *'**
  String get charName;

  /// No description provided for @charNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Gundren Rockseeker'**
  String get charNameHint;

  /// No description provided for @alignmentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your moral compass'**
  String get alignmentSubtitle;

  /// No description provided for @physicalAppearance.
  ///
  /// In en, this message translates to:
  /// **'Physical Appearance'**
  String get physicalAppearance;

  /// No description provided for @physicalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional details about looks'**
  String get physicalSubtitle;

  /// No description provided for @personality.
  ///
  /// In en, this message translates to:
  /// **'Personality'**
  String get personality;

  /// No description provided for @personalitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Traits, ideals, bonds, flaws'**
  String get personalitySubtitle;

  /// No description provided for @backstory.
  ///
  /// In en, this message translates to:
  /// **'Backstory'**
  String get backstory;

  /// No description provided for @backstorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your character\'s story'**
  String get backstorySubtitle;

  /// No description provided for @backstoryHint.
  ///
  /// In en, this message translates to:
  /// **'Born in a small village...'**
  String get backstoryHint;

  /// No description provided for @traits.
  ///
  /// In en, this message translates to:
  /// **'Personality Traits'**
  String get traits;

  /// No description provided for @traitsHint.
  ///
  /// In en, this message translates to:
  /// **'I am always polite...'**
  String get traitsHint;

  /// No description provided for @ideals.
  ///
  /// In en, this message translates to:
  /// **'Ideals'**
  String get ideals;

  /// No description provided for @idealsHint.
  ///
  /// In en, this message translates to:
  /// **'Justice...'**
  String get idealsHint;

  /// No description provided for @bonds.
  ///
  /// In en, this message translates to:
  /// **'Bonds'**
  String get bonds;

  /// No description provided for @bondsHint.
  ///
  /// In en, this message translates to:
  /// **'I owe my life...'**
  String get bondsHint;

  /// No description provided for @flaws.
  ///
  /// In en, this message translates to:
  /// **'Flaws'**
  String get flaws;

  /// No description provided for @flawsHint.
  ///
  /// In en, this message translates to:
  /// **'I have a weakness...'**
  String get flawsHint;

  /// No description provided for @appearanceDesc.
  ///
  /// In en, this message translates to:
  /// **'Appearance Description'**
  String get appearanceDesc;

  /// No description provided for @appearanceHint.
  ///
  /// In en, this message translates to:
  /// **'Tall and muscular...'**
  String get appearanceHint;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get ageYears;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @genderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// No description provided for @genderMaleShort.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get genderMaleShort;

  /// No description provided for @genderFemaleShort.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get genderFemaleShort;

  /// No description provided for @genderOtherShort.
  ///
  /// In en, this message translates to:
  /// **'Oth'**
  String get genderOtherShort;

  /// No description provided for @chooseRaceClass.
  ///
  /// In en, this message translates to:
  /// **'Choose Race & Class'**
  String get chooseRaceClass;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @raceClassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select your character\'s race and class.'**
  String get raceClassSubtitle;

  /// No description provided for @loadingRaces.
  ///
  /// In en, this message translates to:
  /// **'Loading races...'**
  String get loadingRaces;

  /// No description provided for @loadingClasses.
  ///
  /// In en, this message translates to:
  /// **'Loading classes...'**
  String get loadingClasses;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed: {value} ft'**
  String speed(int value);

  /// No description provided for @abilityScoreIncreases.
  ///
  /// In en, this message translates to:
  /// **'Ability Score Increases'**
  String get abilityScoreIncreases;

  /// No description provided for @languages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languages;

  /// No description provided for @racialTraits.
  ///
  /// In en, this message translates to:
  /// **'Racial Traits'**
  String get racialTraits;

  /// No description provided for @savingThrowProficiencies.
  ///
  /// In en, this message translates to:
  /// **'Saving Throw Proficiencies'**
  String get savingThrowProficiencies;

  /// No description provided for @skillProficiencies.
  ///
  /// In en, this message translates to:
  /// **'Skill Proficiencies'**
  String get skillProficiencies;

  /// No description provided for @armorProficiencies.
  ///
  /// In en, this message translates to:
  /// **'Armor Proficiencies'**
  String get armorProficiencies;

  /// No description provided for @weaponProficiencies.
  ///
  /// In en, this message translates to:
  /// **'Weapon Proficiencies'**
  String get weaponProficiencies;

  /// No description provided for @langCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get langCommon;

  /// No description provided for @langDwarvish.
  ///
  /// In en, this message translates to:
  /// **'Dwarvish'**
  String get langDwarvish;

  /// No description provided for @langElvish.
  ///
  /// In en, this message translates to:
  /// **'Elvish'**
  String get langElvish;

  /// No description provided for @langGiant.
  ///
  /// In en, this message translates to:
  /// **'Giant'**
  String get langGiant;

  /// No description provided for @langGnomish.
  ///
  /// In en, this message translates to:
  /// **'Gnomish'**
  String get langGnomish;

  /// No description provided for @langGoblin.
  ///
  /// In en, this message translates to:
  /// **'Goblin'**
  String get langGoblin;

  /// No description provided for @langHalfling.
  ///
  /// In en, this message translates to:
  /// **'Halfling'**
  String get langHalfling;

  /// No description provided for @langOrc.
  ///
  /// In en, this message translates to:
  /// **'Orc'**
  String get langOrc;

  /// No description provided for @langAbyssal.
  ///
  /// In en, this message translates to:
  /// **'Abyssal'**
  String get langAbyssal;

  /// No description provided for @langCelestial.
  ///
  /// In en, this message translates to:
  /// **'Celestial'**
  String get langCelestial;

  /// No description provided for @langDraconic.
  ///
  /// In en, this message translates to:
  /// **'Draconic'**
  String get langDraconic;

  /// No description provided for @langDeepSpeech.
  ///
  /// In en, this message translates to:
  /// **'Deep Speech'**
  String get langDeepSpeech;

  /// No description provided for @langInfernal.
  ///
  /// In en, this message translates to:
  /// **'Infernal'**
  String get langInfernal;

  /// No description provided for @langPrimordial.
  ///
  /// In en, this message translates to:
  /// **'Primordial'**
  String get langPrimordial;

  /// No description provided for @langSylvan.
  ///
  /// In en, this message translates to:
  /// **'Sylvan'**
  String get langSylvan;

  /// No description provided for @langUndercommon.
  ///
  /// In en, this message translates to:
  /// **'Undercommon'**
  String get langUndercommon;

  /// No description provided for @weaponClub.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get weaponClub;

  /// No description provided for @weaponDagger.
  ///
  /// In en, this message translates to:
  /// **'Dagger'**
  String get weaponDagger;

  /// No description provided for @weaponGreatclub.
  ///
  /// In en, this message translates to:
  /// **'Greatclub'**
  String get weaponGreatclub;

  /// No description provided for @weaponHandaxe.
  ///
  /// In en, this message translates to:
  /// **'Handaxe'**
  String get weaponHandaxe;

  /// No description provided for @weaponJavelin.
  ///
  /// In en, this message translates to:
  /// **'Javelin'**
  String get weaponJavelin;

  /// No description provided for @weaponLightHammer.
  ///
  /// In en, this message translates to:
  /// **'Light Hammer'**
  String get weaponLightHammer;

  /// No description provided for @weaponMace.
  ///
  /// In en, this message translates to:
  /// **'Mace'**
  String get weaponMace;

  /// No description provided for @weaponQuarterstaff.
  ///
  /// In en, this message translates to:
  /// **'Quarterstaff'**
  String get weaponQuarterstaff;

  /// No description provided for @weaponSickle.
  ///
  /// In en, this message translates to:
  /// **'Sickle'**
  String get weaponSickle;

  /// No description provided for @weaponSpear.
  ///
  /// In en, this message translates to:
  /// **'Spear'**
  String get weaponSpear;

  /// No description provided for @weaponLightCrossbow.
  ///
  /// In en, this message translates to:
  /// **'Light Crossbow'**
  String get weaponLightCrossbow;

  /// No description provided for @weaponDart.
  ///
  /// In en, this message translates to:
  /// **'Dart'**
  String get weaponDart;

  /// No description provided for @weaponShortbow.
  ///
  /// In en, this message translates to:
  /// **'Shortbow'**
  String get weaponShortbow;

  /// No description provided for @weaponSling.
  ///
  /// In en, this message translates to:
  /// **'Sling'**
  String get weaponSling;

  /// No description provided for @weaponBattleaxe.
  ///
  /// In en, this message translates to:
  /// **'Battleaxe'**
  String get weaponBattleaxe;

  /// No description provided for @weaponFlail.
  ///
  /// In en, this message translates to:
  /// **'Flail'**
  String get weaponFlail;

  /// No description provided for @weaponGlaive.
  ///
  /// In en, this message translates to:
  /// **'Glaive'**
  String get weaponGlaive;

  /// No description provided for @weaponGreataxe.
  ///
  /// In en, this message translates to:
  /// **'Greataxe'**
  String get weaponGreataxe;

  /// No description provided for @weaponGreatsword.
  ///
  /// In en, this message translates to:
  /// **'Greatsword'**
  String get weaponGreatsword;

  /// No description provided for @weaponHalberd.
  ///
  /// In en, this message translates to:
  /// **'Halberd'**
  String get weaponHalberd;

  /// No description provided for @weaponLance.
  ///
  /// In en, this message translates to:
  /// **'Lance'**
  String get weaponLance;

  /// No description provided for @weaponLongsword.
  ///
  /// In en, this message translates to:
  /// **'Longsword'**
  String get weaponLongsword;

  /// No description provided for @weaponMaul.
  ///
  /// In en, this message translates to:
  /// **'Maul'**
  String get weaponMaul;

  /// No description provided for @weaponMorningstar.
  ///
  /// In en, this message translates to:
  /// **'Morningstar'**
  String get weaponMorningstar;

  /// No description provided for @weaponPike.
  ///
  /// In en, this message translates to:
  /// **'Pike'**
  String get weaponPike;

  /// No description provided for @weaponRapier.
  ///
  /// In en, this message translates to:
  /// **'Rapier'**
  String get weaponRapier;

  /// No description provided for @weaponScimitar.
  ///
  /// In en, this message translates to:
  /// **'Scimitar'**
  String get weaponScimitar;

  /// No description provided for @weaponShortsword.
  ///
  /// In en, this message translates to:
  /// **'Shortsword'**
  String get weaponShortsword;

  /// No description provided for @weaponTrident.
  ///
  /// In en, this message translates to:
  /// **'Trident'**
  String get weaponTrident;

  /// No description provided for @weaponWarPick.
  ///
  /// In en, this message translates to:
  /// **'War Pick'**
  String get weaponWarPick;

  /// No description provided for @weaponWarhammer.
  ///
  /// In en, this message translates to:
  /// **'Warhammer'**
  String get weaponWarhammer;

  /// No description provided for @weaponWhip.
  ///
  /// In en, this message translates to:
  /// **'Whip'**
  String get weaponWhip;

  /// No description provided for @weaponBlowgun.
  ///
  /// In en, this message translates to:
  /// **'Blowgun'**
  String get weaponBlowgun;

  /// No description provided for @weaponHandCrossbow.
  ///
  /// In en, this message translates to:
  /// **'Hand Crossbow'**
  String get weaponHandCrossbow;

  /// No description provided for @weaponHeavyCrossbow.
  ///
  /// In en, this message translates to:
  /// **'Heavy Crossbow'**
  String get weaponHeavyCrossbow;

  /// No description provided for @weaponLongbow.
  ///
  /// In en, this message translates to:
  /// **'Longbow'**
  String get weaponLongbow;

  /// No description provided for @weaponNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get weaponNet;

  /// No description provided for @selectHeight.
  ///
  /// In en, this message translates to:
  /// **'Select Height'**
  String get selectHeight;

  /// No description provided for @selectWeight.
  ///
  /// In en, this message translates to:
  /// **'Select Weight'**
  String get selectWeight;

  /// No description provided for @selectEyeColor.
  ///
  /// In en, this message translates to:
  /// **'Select Eye Color'**
  String get selectEyeColor;

  /// No description provided for @selectHairColor.
  ///
  /// In en, this message translates to:
  /// **'Select Hair Color'**
  String get selectHairColor;

  /// No description provided for @selectSkinTone.
  ///
  /// In en, this message translates to:
  /// **'Select Skin Tone'**
  String get selectSkinTone;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @customEyeColor.
  ///
  /// In en, this message translates to:
  /// **'Custom Eye Color'**
  String get customEyeColor;

  /// No description provided for @customHairColor.
  ///
  /// In en, this message translates to:
  /// **'Custom Hair Color'**
  String get customHairColor;

  /// No description provided for @customSkinTone.
  ///
  /// In en, this message translates to:
  /// **'Custom Skin Tone'**
  String get customSkinTone;

  /// No description provided for @enterCustom.
  ///
  /// In en, this message translates to:
  /// **'Enter custom value'**
  String get enterCustom;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @readyMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} is ready to choose their path!'**
  String readyMessage(Object name);

  /// No description provided for @law.
  ///
  /// In en, this message translates to:
  /// **'LAW'**
  String get law;

  /// No description provided for @neutral.
  ///
  /// In en, this message translates to:
  /// **'NEUTRAL'**
  String get neutral;

  /// No description provided for @chaos.
  ///
  /// In en, this message translates to:
  /// **'CHAOS'**
  String get chaos;

  /// No description provided for @good.
  ///
  /// In en, this message translates to:
  /// **'GOOD'**
  String get good;

  /// No description provided for @evil.
  ///
  /// In en, this message translates to:
  /// **'EVIL'**
  String get evil;

  /// No description provided for @lg.
  ///
  /// In en, this message translates to:
  /// **'Lawful Good'**
  String get lg;

  /// No description provided for @ng.
  ///
  /// In en, this message translates to:
  /// **'Neutral Good'**
  String get ng;

  /// No description provided for @cg.
  ///
  /// In en, this message translates to:
  /// **'Chaotic Good'**
  String get cg;

  /// No description provided for @ln.
  ///
  /// In en, this message translates to:
  /// **'Lawful Neutral'**
  String get ln;

  /// No description provided for @tn.
  ///
  /// In en, this message translates to:
  /// **'True Neutral'**
  String get tn;

  /// No description provided for @cn.
  ///
  /// In en, this message translates to:
  /// **'Chaotic Neutral'**
  String get cn;

  /// No description provided for @le.
  ///
  /// In en, this message translates to:
  /// **'Lawful Evil'**
  String get le;

  /// No description provided for @ne.
  ///
  /// In en, this message translates to:
  /// **'Neutral Evil'**
  String get ne;

  /// No description provided for @ce.
  ///
  /// In en, this message translates to:
  /// **'Chaotic Evil'**
  String get ce;

  /// No description provided for @lgDesc.
  ///
  /// In en, this message translates to:
  /// **'Honor, compassion, duty'**
  String get lgDesc;

  /// No description provided for @ngDesc.
  ///
  /// In en, this message translates to:
  /// **'Kind, helpful, balance'**
  String get ngDesc;

  /// No description provided for @cgDesc.
  ///
  /// In en, this message translates to:
  /// **'Freedom, kindness, rebellion'**
  String get cgDesc;

  /// No description provided for @lnDesc.
  ///
  /// In en, this message translates to:
  /// **'Order, tradition, law'**
  String get lnDesc;

  /// No description provided for @tnDesc.
  ///
  /// In en, this message translates to:
  /// **'Balance, nature, neutrality'**
  String get tnDesc;

  /// No description provided for @cnDesc.
  ///
  /// In en, this message translates to:
  /// **'Freedom, unpredictability'**
  String get cnDesc;

  /// No description provided for @leDesc.
  ///
  /// In en, this message translates to:
  /// **'Tyranny, order, domination'**
  String get leDesc;

  /// No description provided for @neDesc.
  ///
  /// In en, this message translates to:
  /// **'Selfish, cruel, practical'**
  String get neDesc;

  /// No description provided for @ceDesc.
  ///
  /// In en, this message translates to:
  /// **'Destruction, cruelty, chaos'**
  String get ceDesc;

  /// No description provided for @stepRaceClass.
  ///
  /// In en, this message translates to:
  /// **'Race & Class'**
  String get stepRaceClass;

  /// No description provided for @stepAbilities.
  ///
  /// In en, this message translates to:
  /// **'Ability Scores & HP'**
  String get stepAbilities;

  /// No description provided for @stepFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features & Spells'**
  String get stepFeatures;

  /// No description provided for @stepEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get stepEquipment;

  /// No description provided for @stepBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get stepBackground;

  /// No description provided for @stepSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get stepSkills;

  /// No description provided for @stepReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get stepReview;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @characterCreated.
  ///
  /// In en, this message translates to:
  /// **'Character created successfully!'**
  String get characterCreated;

  /// No description provided for @tapToUpgrade.
  ///
  /// In en, this message translates to:
  /// **'TAP TO UPGRADE'**
  String get tapToUpgrade;

  /// No description provided for @showDetails.
  ///
  /// In en, this message translates to:
  /// **'Show Character Details'**
  String get showDetails;

  /// No description provided for @hideDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide Details'**
  String get hideDetails;

  /// No description provided for @newAbilities.
  ///
  /// In en, this message translates to:
  /// **'New Abilities'**
  String get newAbilities;

  /// No description provided for @unlocksAtLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {level} Unlocks'**
  String unlocksAtLevel(int level);

  /// No description provided for @noNewFeaturesAtLevel.
  ///
  /// In en, this message translates to:
  /// **'No new features at this level. But your stats improved!'**
  String get noNewFeaturesAtLevel;

  /// No description provided for @spellSlotsIncreased.
  ///
  /// In en, this message translates to:
  /// **'Spell Slots Increased'**
  String get spellSlotsIncreased;

  /// No description provided for @sacredOath.
  ///
  /// In en, this message translates to:
  /// **'Sacred Oath'**
  String get sacredOath;

  /// No description provided for @classFeatures.
  ///
  /// In en, this message translates to:
  /// **'Class Features'**
  String get classFeatures;

  /// No description provided for @chooseFightingStyle.
  ///
  /// In en, this message translates to:
  /// **'Choose a Fighting Style:'**
  String get chooseFightingStyle;

  /// No description provided for @makeChoices.
  ///
  /// In en, this message translates to:
  /// **'Make Choices to Continue'**
  String get makeChoices;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @levelUpReady.
  ///
  /// In en, this message translates to:
  /// **'Level Up Ready!'**
  String get levelUpReady;

  /// No description provided for @confirmLevelUp.
  ///
  /// In en, this message translates to:
  /// **'Confirm these changes to your character.'**
  String get confirmLevelUp;

  /// No description provided for @applyChanges.
  ///
  /// In en, this message translates to:
  /// **'APPLY CHANGES'**
  String get applyChanges;

  /// No description provided for @colorAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get colorAmber;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get colorBrown;

  /// No description provided for @colorGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get colorGray;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorHazel.
  ///
  /// In en, this message translates to:
  /// **'Hazel'**
  String get colorHazel;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorViolet.
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get colorViolet;

  /// No description provided for @colorAuburn.
  ///
  /// In en, this message translates to:
  /// **'Auburn'**
  String get colorAuburn;

  /// No description provided for @colorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colorBlack;

  /// No description provided for @colorBlonde.
  ///
  /// In en, this message translates to:
  /// **'Blonde'**
  String get colorBlonde;

  /// No description provided for @colorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colorWhite;

  /// No description provided for @colorBald.
  ///
  /// In en, this message translates to:
  /// **'Bald'**
  String get colorBald;

  /// No description provided for @skinPale.
  ///
  /// In en, this message translates to:
  /// **'Pale'**
  String get skinPale;

  /// No description provided for @skinFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get skinFair;

  /// No description provided for @skinLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get skinLight;

  /// No description provided for @skinMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get skinMedium;

  /// No description provided for @skinTan.
  ///
  /// In en, this message translates to:
  /// **'Tan'**
  String get skinTan;

  /// No description provided for @skinDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get skinDark;

  /// No description provided for @skinEbony.
  ///
  /// In en, this message translates to:
  /// **'Ebony'**
  String get skinEbony;

  /// No description provided for @unitCm.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get unitCm;

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @chooseSkillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Skills'**
  String get chooseSkillsTitle;

  /// No description provided for @chooseSkills.
  ///
  /// In en, this message translates to:
  /// **'Choose {count} from: {list}'**
  String chooseSkills(int count, String list);

  /// No description provided for @assignAbilityScores.
  ///
  /// In en, this message translates to:
  /// **'Assign Ability Scores'**
  String get assignAbilityScores;

  /// No description provided for @abilityScoresSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to determine your character\'s ability scores.'**
  String get abilityScoresSubtitle;

  /// No description provided for @allocationMethod.
  ///
  /// In en, this message translates to:
  /// **'Allocation Method'**
  String get allocationMethod;

  /// No description provided for @standardArray.
  ///
  /// In en, this message translates to:
  /// **'Standard Array'**
  String get standardArray;

  /// No description provided for @pointBuy.
  ///
  /// In en, this message translates to:
  /// **'Point Buy'**
  String get pointBuy;

  /// No description provided for @manualEntry.
  ///
  /// In en, this message translates to:
  /// **'Manual Entry'**
  String get manualEntry;

  /// No description provided for @standardArrayDesc.
  ///
  /// In en, this message translates to:
  /// **'Assign these values: 15, 14, 13, 12, 10, 8. Balanced.'**
  String get standardArrayDesc;

  /// No description provided for @pointBuyDesc.
  ///
  /// In en, this message translates to:
  /// **'Spend 27 points to customize scores (8-15).'**
  String get pointBuyDesc;

  /// No description provided for @manualEntryDesc.
  ///
  /// In en, this message translates to:
  /// **'Set any value from 3 to 18.'**
  String get manualEntryDesc;

  /// No description provided for @strDesc.
  ///
  /// In en, this message translates to:
  /// **'Physical power'**
  String get strDesc;

  /// No description provided for @dexDesc.
  ///
  /// In en, this message translates to:
  /// **'Agility & reflexes'**
  String get dexDesc;

  /// No description provided for @conDesc.
  ///
  /// In en, this message translates to:
  /// **'Endurance & health'**
  String get conDesc;

  /// No description provided for @intDesc.
  ///
  /// In en, this message translates to:
  /// **'Reasoning & memory'**
  String get intDesc;

  /// No description provided for @wisDesc.
  ///
  /// In en, this message translates to:
  /// **'Awareness & insight'**
  String get wisDesc;

  /// No description provided for @chaDesc.
  ///
  /// In en, this message translates to:
  /// **'Force of personality'**
  String get chaDesc;

  /// No description provided for @racialBonus.
  ///
  /// In en, this message translates to:
  /// **'Racial Bonus: +{bonus} → Final: {result} ({mod})'**
  String racialBonus(int bonus, int result, String mod);

  /// No description provided for @startingHitPoints.
  ///
  /// In en, this message translates to:
  /// **'Starting Hit Points'**
  String get startingHitPoints;

  /// No description provided for @hitDieConMod.
  ///
  /// In en, this message translates to:
  /// **'Hit Die: d{die} | CON Mod: {mod}'**
  String hitDieConMod(int die, String mod);

  /// No description provided for @hpMaxDesc.
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

  /// No description provided for @newFeaturesLabel.
  ///
  /// In en, this message translates to:
  /// **'New Features'**
  String get newFeaturesLabel;

  /// No description provided for @searchJournal.
  ///
  /// In en, this message translates to:
  /// **'Search journal...'**
  String get searchJournal;

  /// No description provided for @addQuest.
  ///
  /// In en, this message translates to:
  /// **'Add Quest'**
  String get addQuest;

  /// No description provided for @noActiveQuests.
  ///
  /// In en, this message translates to:
  /// **'No active quests'**
  String get noActiveQuests;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get addNote;

  /// No description provided for @noNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get noNotes;

  /// No description provided for @deleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete Note'**
  String get deleteNote;

  /// No description provided for @deleteNoteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String deleteNoteConfirmation(String title);

  /// No description provided for @deleteQuest.
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

  /// No description provided for @cancelCharacterCreationTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Character Creation?'**
  String get cancelCharacterCreationTitle;

  /// No description provided for @cancelCharacterCreationMessage.
  ///
  /// In en, this message translates to:
  /// **'All progress will be lost.'**
  String get cancelCharacterCreationMessage;

  /// No description provided for @continueEditing.
  ///
  /// In en, this message translates to:
  /// **'Continue Editing'**
  String get continueEditing;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @selectClassFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a class first'**
  String get selectClassFirst;

  /// No description provided for @selectSkillProficiencies.
  ///
  /// In en, this message translates to:
  /// **'Select {count} skill proficiencies for your {characterClass}.'**
  String selectSkillProficiencies(int count, String characterClass);

  /// No description provided for @allSkillsSelected.
  ///
  /// In en, this message translates to:
  /// **'All skills selected!'**
  String get allSkillsSelected;

  /// No description provided for @chooseMoreSkills.
  ///
  /// In en, this message translates to:
  /// **'Choose {count} more skill{count, plural, =1{} other{s}}'**
  String chooseMoreSkills(int count);

  /// No description provided for @skillAcrobaticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Dexterity - Balance, tumbling, aerial maneuvers'**
  String get skillAcrobaticsDesc;

  /// No description provided for @skillAnimalHandlingDesc.
  ///
  /// In en, this message translates to:
  /// **'Wisdom - Calming animals, riding, training'**
  String get skillAnimalHandlingDesc;

  /// No description provided for @skillArcanaDesc.
  ///
  /// In en, this message translates to:
  /// **'Intelligence - Magic, spells, magical items'**
  String get skillArcanaDesc;

  /// No description provided for @skillAthleticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Strength - Climbing, jumping, swimming'**
  String get skillAthleticsDesc;

  /// No description provided for @skillDeceptionDesc.
  ///
  /// In en, this message translates to:
  /// **'Charisma - Lying, disguising, misleading'**
  String get skillDeceptionDesc;

  /// No description provided for @skillHistoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Intelligence - Historical events, legends'**
  String get skillHistoryDesc;

  /// No description provided for @skillInsightDesc.
  ///
  /// In en, this message translates to:
  /// **'Wisdom - Reading intentions, detecting lies'**
  String get skillInsightDesc;

  /// No description provided for @skillIntimidationDesc.
  ///
  /// In en, this message translates to:
  /// **'Charisma - Threats, coercion'**
  String get skillIntimidationDesc;

  /// No description provided for @skillInvestigationDesc.
  ///
  /// In en, this message translates to:
  /// **'Intelligence - Finding clues, deduction'**
  String get skillInvestigationDesc;

  /// No description provided for @skillMedicineDesc.
  ///
  /// In en, this message translates to:
  /// **'Wisdom - Stabilizing, diagnosing'**
  String get skillMedicineDesc;

  /// No description provided for @skillNatureDesc.
  ///
  /// In en, this message translates to:
  /// **'Intelligence - Terrain, plants, animals'**
  String get skillNatureDesc;

  /// No description provided for @skillPerceptionDesc.
  ///
  /// In en, this message translates to:
  /// **'Wisdom - Spotting, hearing, detecting'**
  String get skillPerceptionDesc;

  /// No description provided for @skillPerformanceDesc.
  ///
  /// In en, this message translates to:
  /// **'Charisma - Music, dance, acting'**
  String get skillPerformanceDesc;

  /// No description provided for @skillPersuasionDesc.
  ///
  /// In en, this message translates to:
  /// **'Charisma - Diplomacy, negotiations'**
  String get skillPersuasionDesc;

  /// No description provided for @skillReligionDesc.
  ///
  /// In en, this message translates to:
  /// **'Intelligence - Deities, rites, prayers'**
  String get skillReligionDesc;

  /// No description provided for @skillSleightOfHandDesc.
  ///
  /// In en, this message translates to:
  /// **'Dexterity - Pickpocketing, tricks'**
  String get skillSleightOfHandDesc;

  /// No description provided for @skillStealthDesc.
  ///
  /// In en, this message translates to:
  /// **'Dexterity - Hiding, moving silently'**
  String get skillStealthDesc;

  /// No description provided for @skillSurvivalDesc.
  ///
  /// In en, this message translates to:
  /// **'Wisdom - Tracking, foraging, navigation'**
  String get skillSurvivalDesc;

  /// No description provided for @chooseBackground.
  ///
  /// In en, this message translates to:
  /// **'Choose Background'**
  String get chooseBackground;

  /// No description provided for @backgroundDescription.
  ///
  /// In en, this message translates to:
  /// **'Your background represents your character\'s past and grants additional skills.'**
  String get backgroundDescription;

  /// No description provided for @noBackgroundsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No backgrounds available'**
  String get noBackgroundsAvailable;

  /// No description provided for @abilityStrAbbr.
  ///
  /// In en, this message translates to:
  /// **'STR'**
  String get abilityStrAbbr;

  /// No description provided for @abilityDexAbbr.
  ///
  /// In en, this message translates to:
  /// **'DEX'**
  String get abilityDexAbbr;

  /// No description provided for @abilityConAbbr.
  ///
  /// In en, this message translates to:
  /// **'CON'**
  String get abilityConAbbr;

  /// No description provided for @abilityIntAbbr.
  ///
  /// In en, this message translates to:
  /// **'INT'**
  String get abilityIntAbbr;

  /// No description provided for @abilityWisAbbr.
  ///
  /// In en, this message translates to:
  /// **'WIS'**
  String get abilityWisAbbr;

  /// No description provided for @abilityChaAbbr.
  ///
  /// In en, this message translates to:
  /// **'CHA'**
  String get abilityChaAbbr;

  /// No description provided for @propertyAmmunition.
  ///
  /// In en, this message translates to:
  /// **'Ammunition'**
  String get propertyAmmunition;

  /// No description provided for @propertyFinesse.
  ///
  /// In en, this message translates to:
  /// **'Finesse'**
  String get propertyFinesse;

  /// No description provided for @propertyHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get propertyHeavy;

  /// No description provided for @propertyLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get propertyLight;

  /// No description provided for @propertyLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get propertyLoading;

  /// No description provided for @propertyRange.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get propertyRange;

  /// No description provided for @propertyReach.
  ///
  /// In en, this message translates to:
  /// **'Reach'**
  String get propertyReach;

  /// No description provided for @propertySpecial.
  ///
  /// In en, this message translates to:
  /// **'Special'**
  String get propertySpecial;

  /// No description provided for @propertyThrown.
  ///
  /// In en, this message translates to:
  /// **'Thrown'**
  String get propertyThrown;

  /// No description provided for @propertyTwoHanded.
  ///
  /// In en, this message translates to:
  /// **'Two-Handed'**
  String get propertyTwoHanded;

  /// No description provided for @propertyVersatile.
  ///
  /// In en, this message translates to:
  /// **'Versatile'**
  String get propertyVersatile;

  /// No description provided for @propertyMartial.
  ///
  /// In en, this message translates to:
  /// **'Martial'**
  String get propertyMartial;

  /// No description provided for @propertySimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get propertySimple;

  /// No description provided for @armorTypeLight.
  ///
  /// In en, this message translates to:
  /// **'Light Armor'**
  String get armorTypeLight;

  /// No description provided for @armorTypeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium Armor'**
  String get armorTypeMedium;

  /// No description provided for @armorTypeHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy Armor'**
  String get armorTypeHeavy;

  /// No description provided for @armorTypeShield.
  ///
  /// In en, this message translates to:
  /// **'Shield'**
  String get armorTypeShield;

  /// No description provided for @searchSpells.
  ///
  /// In en, this message translates to:
  /// **'Search spells...'**
  String get searchSpells;

  /// No description provided for @noSpellsFound.
  ///
  /// In en, this message translates to:
  /// **'No spells found'**
  String get noSpellsFound;

  /// No description provided for @tryAdjustingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters'**
  String get tryAdjustingFilters;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @castingTime.
  ///
  /// In en, this message translates to:
  /// **'Casting Time'**
  String get castingTime;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @components.
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get components;

  /// No description provided for @materials.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materials;

  /// No description provided for @concentration.
  ///
  /// In en, this message translates to:
  /// **'Concentration'**
  String get concentration;

  /// No description provided for @ritual.
  ///
  /// In en, this message translates to:
  /// **'Ritual'**
  String get ritual;

  /// No description provided for @atHigherLevels.
  ///
  /// In en, this message translates to:
  /// **'At Higher Levels'**
  String get atHigherLevels;

  /// No description provided for @classes.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get classes;

  /// No description provided for @addToKnown.
  ///
  /// In en, this message translates to:
  /// **'Add to Known Spells'**
  String get addToKnown;

  /// No description provided for @removeFromKnown.
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

  /// No description provided for @availableToLearn.
  ///
  /// In en, this message translates to:
  /// **'Available to Learn'**
  String get availableToLearn;

  /// No description provided for @availableAtLevel.
  ///
  /// In en, this message translates to:
  /// **'Available at Level {level}'**
  String availableAtLevel(int level);

  /// No description provided for @filterAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get filterAvailability;

  /// No description provided for @filterClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get filterClass;

  /// No description provided for @filterLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get filterLevel;

  /// No description provided for @filterSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get filterSchool;

  /// No description provided for @filterAllSpells.
  ///
  /// In en, this message translates to:
  /// **'All Spells'**
  String get filterAllSpells;

  /// No description provided for @filterCanLearnNow.
  ///
  /// In en, this message translates to:
  /// **'Can Learn Now'**
  String get filterCanLearnNow;

  /// No description provided for @filterAvailableToClass.
  ///
  /// In en, this message translates to:
  /// **'Available to Class'**
  String get filterAvailableToClass;

  /// No description provided for @filterAllClasses.
  ///
  /// In en, this message translates to:
  /// **'All Classes'**
  String get filterAllClasses;

  /// No description provided for @filterAllLevels.
  ///
  /// In en, this message translates to:
  /// **'All Levels'**
  String get filterAllLevels;

  /// No description provided for @filterAllSchools.
  ///
  /// In en, this message translates to:
  /// **'All Schools'**
  String get filterAllSchools;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @spellsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} spell{count, plural, =1{} other{s}}'**
  String spellsCount(int count);

  /// No description provided for @spellAlmanacTitle.
  ///
  /// In en, this message translates to:
  /// **'Spell Almanac'**
  String get spellAlmanacTitle;

  /// No description provided for @actionTypeFree.
  ///
  /// In en, this message translates to:
  /// **'Free Action'**
  String get actionTypeFree;

  /// No description provided for @featuresStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Class Features'**
  String get featuresStepTitle;

  /// No description provided for @featuresStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'As a level 1 {className}, you gain the following features:'**
  String featuresStepSubtitle(String className);

  /// No description provided for @noFeaturesAtLevel1.
  ///
  /// In en, this message translates to:
  /// **'No features available at level 1 for this class.'**
  String get noFeaturesAtLevel1;

  /// No description provided for @spellsStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Spells'**
  String get spellsStepTitle;

  /// No description provided for @spellsStepPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Spell selection will be available in future updates. For now, please add spells manually in the character sheet after creation.'**
  String get spellsStepPlaceholder;

  /// No description provided for @equipmentStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Starting Equipment'**
  String get equipmentStepTitle;

  /// No description provided for @equipmentStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your starting equipment for your class'**
  String get equipmentStepSubtitle;

  /// No description provided for @chooseEquipmentPackage.
  ///
  /// In en, this message translates to:
  /// **'Choose Equipment Package'**
  String get chooseEquipmentPackage;

  /// No description provided for @packageStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard Package'**
  String get packageStandard;

  /// No description provided for @packageStandardDesc.
  ///
  /// In en, this message translates to:
  /// **'Recommended starting equipment for your class'**
  String get packageStandardDesc;

  /// No description provided for @packageAlternative.
  ///
  /// In en, this message translates to:
  /// **'Alternative Package'**
  String get packageAlternative;

  /// No description provided for @packageAlternativeDesc.
  ///
  /// In en, this message translates to:
  /// **'Different equipment options'**
  String get packageAlternativeDesc;

  /// No description provided for @packageCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Package'**
  String get packageCustom;

  /// No description provided for @packageCustomDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose items from catalog'**
  String get packageCustomDesc;

  /// No description provided for @selectedEquipment.
  ///
  /// In en, this message translates to:
  /// **'Selected Equipment'**
  String get selectedEquipment;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// No description provided for @noItemsSelected.
  ///
  /// In en, this message translates to:
  /// **'No items selected'**
  String get noItemsSelected;

  /// No description provided for @tapToAddItems.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add Item\" to select equipment'**
  String get tapToAddItems;

  /// No description provided for @equipmentPreview.
  ///
  /// In en, this message translates to:
  /// **'{className} Equipment Preview'**
  String equipmentPreview(String className);

  /// No description provided for @toolsAndGear.
  ///
  /// In en, this message translates to:
  /// **'Tools & Gear'**
  String get toolsAndGear;

  /// No description provided for @equipmentPreviewDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This is a preview of typical starting equipment. You can customize your inventory after character creation.'**
  String get equipmentPreviewDisclaimer;

  /// No description provided for @itemCatalog.
  ///
  /// In en, this message translates to:
  /// **'Item Catalog'**
  String get itemCatalog;

  /// No description provided for @createItem.
  ///
  /// In en, this message translates to:
  /// **'Create Item'**
  String get createItem;

  /// No description provided for @foundItems.
  ///
  /// In en, this message translates to:
  /// **'Found: {count} (selected: {selected})'**
  String foundItems(int count, int selected);

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get noItemsFound;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @createCustomItem.
  ///
  /// In en, this message translates to:
  /// **'Create Custom Item'**
  String get createCustomItem;

  /// No description provided for @addImage.
  ///
  /// In en, this message translates to:
  /// **'Add\nimage'**
  String get addImage;

  /// No description provided for @errorLoadingImage.
  ///
  /// In en, this message translates to:
  /// **'Error loading image: {error}'**
  String errorLoadingImage(String error);

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get itemName;

  /// No description provided for @itemNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Sword of Light'**
  String get itemNameHint;

  /// No description provided for @enterItemName.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get enterItemName;

  /// No description provided for @itemDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get itemDescription;

  /// No description provided for @itemDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the item...'**
  String get itemDescriptionHint;

  /// No description provided for @itemType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get itemType;

  /// No description provided for @itemRarity.
  ///
  /// In en, this message translates to:
  /// **'Rarity'**
  String get itemRarity;

  /// No description provided for @itemWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get itemWeight;

  /// No description provided for @itemValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get itemValue;

  /// No description provided for @itemQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get itemQuantity;

  /// No description provided for @minQuantity1.
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

  /// No description provided for @rarityCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get rarityCommon;

  /// No description provided for @rarityUncommon.
  ///
  /// In en, this message translates to:
  /// **'Uncommon'**
  String get rarityUncommon;

  /// No description provided for @rarityRare.
  ///
  /// In en, this message translates to:
  /// **'Rare'**
  String get rarityRare;

  /// No description provided for @rarityVeryRare.
  ///
  /// In en, this message translates to:
  /// **'Very Rare'**
  String get rarityVeryRare;

  /// No description provided for @rarityLegendary.
  ///
  /// In en, this message translates to:
  /// **'Legendary'**
  String get rarityLegendary;

  /// No description provided for @rarityArtifact.
  ///
  /// In en, this message translates to:
  /// **'Artifact'**
  String get rarityArtifact;

  /// No description provided for @methodStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get methodStandard;

  /// No description provided for @methodPointBuy.
  ///
  /// In en, this message translates to:
  /// **'Point Buy'**
  String get methodPointBuy;

  /// No description provided for @methodManual.
  ///
  /// In en, this message translates to:
  /// **'Manual Entry'**
  String get methodManual;

  /// No description provided for @characterReady.
  ///
  /// In en, this message translates to:
  /// **'Character Ready!'**
  String get characterReady;

  /// No description provided for @reviewChoices.
  ///
  /// In en, this message translates to:
  /// **'Review your choices before finalizing'**
  String get reviewChoices;

  /// No description provided for @unnamed.
  ///
  /// In en, this message translates to:
  /// **'(Unnamed)'**
  String get unnamed;

  /// No description provided for @basicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get basicInfo;

  /// No description provided for @level1Info.
  ///
  /// In en, this message translates to:
  /// **'Your character will be created at level 1. Additional features will be added based on your class and background.'**
  String get level1Info;

  /// No description provided for @hpMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get hpMax;
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
