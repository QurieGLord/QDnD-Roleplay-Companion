import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import 'value_editor_dialog.dart';

Future<bool> showHealthValueEditor(BuildContext context, Character c,
    {bool form = false}) {
  final l10n = AppLocalizations.of(context)!;
  return showSheetValueEditor(context,
      title: form ? l10n.sheetHealthForm : l10n.hitPoints,
      icon: Icons.favorite_outline,
      description: l10n.sheetHealthEditHelp,
      fields: [
        SheetNumberField('current', l10n.gameStateCurrentHp,
            form ? c.beastCurrentHp ?? 0 : c.currentHp),
        SheetNumberField('maximum', l10n.gameStateMaximumHp,
            form ? c.beastMaxHp ?? 0 : c.maxHp),
        SheetNumberField('temporary', l10n.tempHp, c.temporaryHp),
      ],
      onSave: (values, _) => GameplayActionsService.editHealth(c,
          current: values['current']!,
          maximum: values['maximum']!,
          temporary: values['temporary']!,
          form: form));
}

Future<bool> showHealthAction(BuildContext context, Character c,
    {required bool healing}) async {
  final l10n = AppLocalizations.of(context)!;
  int? concentrationDc;
  final changed = await showSheetValueEditor(context,
      title: healing ? l10n.heal : l10n.damage,
      actionLabel: l10n.apply,
      icon: healing ? Icons.add : Icons.remove,
      description: healing ? l10n.sheetHealingHelp : l10n.sheetDamageHelp,
      fields: [
        SheetNumberField(
            'amount', healing ? l10n.healAmount : l10n.damageAmount, 1,
            minimum: 1)
      ], onSave: (values, _) async {
    final amount = values['amount']!;
    final needsCheck = !healing && c.concentratingOn != null;
    await GameplayActionsService.changeHealth(c, amount, healing: healing);
    if (needsCheck) concentrationDc = math.max(10, amount ~/ 2);
  });
  if (changed && concentrationDc != null && context.mounted) {
    AppSnackBar.info(context, l10n.sheetConcentrationDc(concentrationDc!));
  }
  return changed;
}

Future<bool> showArmorValueEditor(BuildContext context, Character c) {
  final l10n = AppLocalizations.of(context)!;
  return showSheetValueEditor(context,
      title: l10n.armorClass,
      icon: Icons.shield_outlined,
      description: l10n.sheetArmorEditHelp,
      calculatedValue: c.calculatedArmorClass,
      initiallyAutomatic: c.usesAutomaticArmorClass,
      fields: [SheetNumberField('value', l10n.armorClass, c.armorClass)],
      onSave: (values, automatic) => GameplayActionsService.editArmorClass(c,
          automatic: automatic, value: values['value']!));
}

Future<bool> showSlotValueEditor(BuildContext context, Character c, int level) {
  final l10n = AppLocalizations.of(context)!;
  final current = level <= c.spellSlots.length ? c.spellSlots[level - 1] : 0;
  final maximum =
      level <= c.maxSpellSlots.length ? c.maxSpellSlots[level - 1] : 0;
  return showSheetValueEditor(context,
      title: l10n.levelSlot(level),
      icon: Icons.auto_awesome,
      fields: [
        SheetNumberField('value', l10n.sheetRemainder, current,
            hint: l10n.gameStateNormalMaximum(maximum))
      ],
      onSave: (values, _) =>
          GameplayActionsService.editSpellSlot(c, level, values['value']!));
}

Future<bool> showAdditionalSlotEditor(BuildContext context, Character c) {
  final l10n = AppLocalizations.of(context)!;
  return showSheetValueEditor(context,
      title: l10n.sheetAdditionalSlots,
      icon: Icons.auto_awesome,
      description: l10n.sheetAdditionalSlotsHelp,
      fields: [
        SheetNumberField('level', l10n.sheetSlotLevel, 1,
            minimum: 1, maximum: 9),
        SheetNumberField('value', l10n.sheetAddSlotsAmount, 1, minimum: 1),
      ], onSave: (values, _) async {
    await GameplayActionsService.changeSpellSlot(
        c, values['level']!, values['value']!);
  });
}

Future<bool> showResourceValueEditor(
    BuildContext context, Character c, CharacterFeature f) {
  final l10n = AppLocalizations.of(context)!;
  final locale = Localizations.localeOf(context).languageCode;
  return showSheetValueEditor(context,
      title: f.getName(locale),
      icon: Icons.tune,
      fields: [
        SheetNumberField('value', l10n.sheetRemainder,
            GameplayActionsService.resourceCurrent(c, f),
            hint: l10n.gameStateNormalMaximum(f.resourcePool!.maxUses))
      ],
      onSave: (values, _) =>
          GameplayActionsService.editResource(c, f, values['value']!));
}
