import 'package:flutter/material.dart';
import '../../core/models/item.dart';
import '../../core/utils/item_utils.dart';
import '../../l10n/app_localizations.dart';

String inventoryText(BuildContext context, String ru, String en) =>
    Localizations.localeOf(context).languageCode == 'ru' ? ru : en;
String itemTypeName(BuildContext context, ItemType type) {
  final l = AppLocalizations.of(context)!;
  return switch (type) {
    ItemType.weapon => l.typeWeapon,
    ItemType.armor => l.typeArmor,
    ItemType.gear => l.typeGear,
    ItemType.consumable => l.typeConsumable,
    ItemType.tool => l.typeTool,
    ItemType.treasure => l.typeTreasure,
  };
}

String itemSummary(BuildContext context, Item item) {
  final l = AppLocalizations.of(context)!;
  final w = item.weaponProperties, a = item.armorProperties;
  if (w != null) {
    return '${w.damageDice} · ${ItemUtils.getLocalizedDamageType(l, w.damageType.toString())}';
  }
  if (a != null) {
    return a.armorType == ArmorType.shield
        ? '${l.armorClassAC} +${a.baseAC}'
        : '${l.armorClassAC} ${a.baseAC}';
  }
  return itemTypeName(context, item.type);
}

String compactNumber(num value) => value == value.roundToDouble()
    ? '${value.toInt()}'
    : value.toStringAsFixed(1);
String goldValue(int copper) {
  final fraction = (copper.abs() % 100)
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0$'), '');
  return copper % 100 == 0
      ? '${copper ~/ 100}'
      : '${copper < 0 ? '-' : ''}${copper.abs() ~/ 100}.$fraction';
}

int itemValueInCopper(String input, String denomination) {
  final value = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException('Invalid price');
  }
  final factor = {'CP': 1, 'SP': 10, 'GP': 100, 'PP': 1000}[denomination];
  if (factor == null) throw const FormatException('Unknown denomination');
  final parts = value.split('.'), fraction = parts.length == 2 ? parts[1] : '';
  final numerator = fraction.isEmpty ? 0 : int.parse(fraction) * factor,
      denominator = fraction.length == 1 ? 10 : 100;
  if (numerator % denominator != 0) {
    throw const FormatException('Price is smaller than a copper piece');
  }
  return int.parse(parts.first) * factor + numerator ~/ denominator;
}
