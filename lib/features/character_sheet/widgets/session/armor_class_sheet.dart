import 'package:flutter/material.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../core/models/armor_class_parts.dart';
import '../../../../core/models/character.dart';
import 'value_editors.dart';

/// Shows what the armour class is made of; a pinned value keeps the
/// calculation visible beside it. Returns true when the value was changed.
Future<bool> showArmorClassBreakdown(
    BuildContext context, Character character) async {
  final edit = await showCompanionSheet<bool>(context,
      builder: (_) => _ArmorClassBreakdown(character: character));
  if (edit != true || !context.mounted) return false;
  return showArmorValueEditor(context, character);
}

class _ArmorClassBreakdown extends StatelessWidget {
  const _ArmorClassBreakdown({required this.character});
  final Character character;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final parts = armorClassParts(character);
    final calculated = character.calculatedArmorClass;
    final pinned = !character.usesAutomaticArmorClass;

    (IconData, String, String?) describe(ArmorClassPart part) =>
        switch (part.source) {
          ArmorClassSource.unarmored => (
              Icons.accessibility_new_rounded,
              l10n.acSourceUnarmored,
              null
            ),
          ArmorClassSource.armor => (
              Icons.checkroom_rounded,
              part.item!.getName(locale),
              null
            ),
          ArmorClassSource.dexterity => (
              Icons.directions_run_rounded,
              l10n.abilityDex,
              part.cap == null ? null : l10n.acDexCap(part.cap!)
            ),
          ArmorClassSource.constitution => (
              Icons.favorite_outline_rounded,
              l10n.abilityCon,
              null
            ),
          ArmorClassSource.wisdom => (
              Icons.self_improvement_rounded,
              l10n.abilityWis,
              null
            ),
          ArmorClassSource.draconic => (
              Icons.auto_awesome_rounded,
              l10n.acSourceDraconic,
              null
            ),
          ArmorClassSource.shield => (
              Icons.shield_outlined,
              part.item!.getName(locale),
              null
            ),
          ArmorClassSource.defense => (
              Icons.security_rounded,
              l10n.acSourceDefense,
              null
            ),
        };

    final rows = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      final (icon, label, note) = describe(parts[i]);
      final v = parts[i].value;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
              color: c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: c.secondaryContainer,
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 20, color: c.secondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: t.textTheme.bodyLarge),
                    if (note != null)
                      Text(note,
                          style: t.textTheme.bodySmall
                              ?.copyWith(color: c.onSurfaceVariant)),
                  ]),
            ),
            Text(i > 0 && v >= 0 ? '+$v' : '$v',
                style: AppType.numeric(t.textTheme.titleLarge)
                    .copyWith(fontSize: 20, fontWeight: FontWeight.w600)),
          ]),
        ),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetHeading(l10n.armorClass, subtitle: l10n.acBreakdownSubtitle),
      const SizedBox(height: 14),
      ...rows,
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
            color: Color.alphaBlend(
                c.secondary.withValues(alpha: .14), c.surfaceContainerLow),
            borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Expanded(
              child: Text(l10n.acTotal,
                  style: t.textTheme.titleSmall?.copyWith(
                      fontSize: 15, fontWeight: FontWeight.w600))),
          Text('$calculated',
              key: const ValueKey('ac-breakdown-total'),
              style: AppType.numeric(t.textTheme.headlineMedium)
                  .copyWith(fontSize: 32, fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 14),
      Text(
          pinned
              ? l10n.acPinned(character.armorClass, calculated)
              : l10n.acAutomaticNote,
          style: t.textTheme.bodyMedium
              ?.copyWith(fontSize: 13.5, color: c.onSurfaceVariant)),
      const SizedBox(height: 14),
      ToneButton(
        key: const ValueKey('ac-breakdown-edit'),
        height: 50,
        expand: true,
        label: pinned ? l10n.acEditPinned : l10n.acEditManual,
        onPressed: () => Navigator.pop(context, true),
      ),
    ]);
  }
}
