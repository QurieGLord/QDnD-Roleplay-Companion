
import 'character.dart';
import 'item.dart';

/// Where one term of the armour class comes from.
enum ArmorClassSource {
  unarmored,
  armor,
  dexterity,
  constitution,
  wisdom,
  draconic,
  shield,
  defense,
}

/// One term of the automatic armour class; [item] names worn gear and
/// [cap] the armour's Dexterity limit when it applies.
class ArmorClassPart {
  const ArmorClassPart(this.source, this.value, {this.item, this.cap});
  final ArmorClassSource source;
  final int value;
  final Item? item;
  final int? cap;
}

/// The automatic armour class as the terms that add up to it, so the sheet
/// can show why it is what it is. The sum is [Character.calculatedArmorClass].
List<ArmorClassPart> armorClassParts(Character c) {
  final scores = c.abilityScores;
  final dex = scores.dexterityModifier;
  Item? armor, shield;
  for (final item in c.inventory) {
    if (item.isEquipped &&
        item.type == ItemType.armor &&
        item.armorProperties != null) {
      if (item.armorProperties!.armorType == ArmorType.shield) {
        shield = item;
      } else {
        armor = item;
      }
    }
  }

  final parts = <ArmorClassPart>[];
  if (armor != null) {
    final props = armor.armorProperties!;
    parts.add(ArmorClassPart(ArmorClassSource.armor, props.baseAC, item: armor));
    if (props.addDexModifier) {
      final cap = props.maxDexBonus;
      parts.add(ArmorClassPart(ArmorClassSource.dexterity,
          cap == null ? dex : dex.clamp(-10, cap),
          cap: cap));
    }
  } else {
    // Without armour the best of the available formulas applies.
    var best = [
      const ArmorClassPart(ArmorClassSource.unarmored, 10),
      ArmorClassPart(ArmorClassSource.dexterity, dex),
      if (c.hasBarbarianUnarmoredDefense)
        ArmorClassPart(
            ArmorClassSource.constitution, scores.constitutionModifier),
    ];
    int sum(List<ArmorClassPart> p) => p.fold(0, (a, b) => a + b.value);
    final monk = (c.classLevel('monk') > 0 &&
            !c.hasBarbarianUnarmoredDefense) ||
        c.hasFeatureId('monk-unarmored-defense');
    if (monk && shield == null) {
      final wisdom = [
        const ArmorClassPart(ArmorClassSource.unarmored, 10),
        ArmorClassPart(ArmorClassSource.dexterity, dex),
        ArmorClassPart(ArmorClassSource.wisdom, scores.wisdomModifier),
      ];
      if (sum(wisdom) > sum(best)) best = wisdom;
    }
    if (c.hasFeatureId('draconic-resilience')) {
      final scales = [
        const ArmorClassPart(ArmorClassSource.draconic, 13),
        ArmorClassPart(ArmorClassSource.dexterity, dex),
      ];
      if (sum(scales) > sum(best)) best = scales;
    }
    parts.addAll(best);
  }
  if (shield != null) {
    parts.add(ArmorClassPart(
        ArmorClassSource.shield, shield.armorProperties!.baseAC,
        item: shield));
  }
  if (armor != null &&
      (c.hasFeatureId('fighter-fighting-style-defense') ||
          c.hasFeatureId('fighting-style-defense') ||
          c.hasFeatureId('ranger-fighting-style-defense'))) {
    parts.add(const ArmorClassPart(ArmorClassSource.defense, 1));
  }
  return parts;
}
