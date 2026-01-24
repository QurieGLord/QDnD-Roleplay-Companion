import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../models/item.dart';

class ItemUtils {
  static IconData getIcon(ItemType type) {
    switch (type) {
      case ItemType.weapon: return Icons.gavel;
      case ItemType.armor: return Icons.shield;
      case ItemType.gear: return Icons.backpack;
      case ItemType.consumable: return Icons.local_drink;
      case ItemType.tool: return Icons.build;
      case ItemType.treasure: return Icons.diamond;
    }
  }

  static String getLocalizedTag(AppLocalizations l10n, String tag) {
    switch (tag.trim().toLowerCase()) {
      case 'ammunition': return l10n.propertyAmmunition;
      case 'finesse': return l10n.propertyFinesse;
      case 'heavy': return l10n.propertyHeavy;
      case 'light': return l10n.propertyLight;
      case 'loading': return l10n.propertyLoading;
      case 'range': return l10n.propertyRange;
      case 'reach': return l10n.propertyReach;
      case 'special': return l10n.propertySpecial;
      case 'thrown': return l10n.propertyThrown;
      case 'two-handed': 
      case 'two_handed': return l10n.propertyTwoHanded;
      case 'versatile': return l10n.propertyVersatile;
      case 'martial': return l10n.propertyMartial;
      case 'simple': return l10n.propertySimple;
      default: return tag;
    }
  }

  static String getLocalizedDamageType(AppLocalizations l10n, String damageType) {
    final lower = damageType.toLowerCase().split('.').last;
    switch (lower) {
      case 'acid': return l10n.damageTypeAcid;
      case 'bludgeoning': return l10n.damageTypeBludgeoning;
      case 'cold': return l10n.damageTypeCold;
      case 'fire': return l10n.damageTypeFire;
      case 'force': return l10n.damageTypeForce;
      case 'lightning': return l10n.damageTypeLightning;
      case 'necrotic': return l10n.damageTypeNecrotic;
      case 'piercing': return l10n.damageTypePiercing;
      case 'poison': return l10n.damageTypePoison;
      case 'psychic': return l10n.damageTypePsychic;
      case 'radiant': return l10n.damageTypeRadiant;
      case 'slashing': return l10n.damageTypeSlashing;
      case 'thunder': return l10n.damageTypeThunder;
      default: return damageType;
    }
  }

  static String getLocalizedArmorType(AppLocalizations l10n, String armorType) {
     final lower = armorType.toLowerCase().split('.').last;
     switch (lower) {
       case 'light': return l10n.armorTypeLight;
       case 'medium': return l10n.armorTypeMedium;
       case 'heavy': return l10n.armorTypeHeavy;
       case 'shield': return l10n.armorTypeShield;
       default: return armorType;
     }
  }

  static String getLocalizedTypeName(AppLocalizations l10n, ItemType type) {
    switch (type) {
      case ItemType.weapon: return l10n.typeWeapon;
      case ItemType.armor: return l10n.typeArmor;
      case ItemType.gear: return l10n.typeGear;
      case ItemType.consumable: return l10n.typeConsumable;
      case ItemType.tool: return l10n.typeTool;
      case ItemType.treasure: return l10n.typeTreasure;
    }
  }

  static String getLocalizedRarityName(AppLocalizations l10n, ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.common: return l10n.rarityCommon;
      case ItemRarity.uncommon: return l10n.rarityUncommon;
      case ItemRarity.rare: return l10n.rarityRare;
      case ItemRarity.veryRare: return l10n.rarityVeryRare;
      case ItemRarity.legendary: return l10n.rarityLegendary;
      case ItemRarity.artifact: return l10n.rarityArtifact;
    }
  }
}