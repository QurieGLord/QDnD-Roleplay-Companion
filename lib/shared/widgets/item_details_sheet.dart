import 'package:flutter/material.dart';
import '../../core/models/item.dart';
import '../../core/utils/item_utils.dart';
import '../../core/ui/companion_surface.dart';
import '../../features/inventory/inventory_presentation.dart';
import '../../features/inventory/widgets/inventory_item_tile.dart';
import '../../l10n/app_localizations.dart';

class ItemDetailsSheet extends StatelessWidget {
  const ItemDetailsSheet(
      {super.key,
      required this.item,
      this.onEquip,
      this.onRemove,
      this.onQuantityChanged,
      this.onAttuneToggle,
      this.onAdd,
      this.onEditQuantity});
  final Item item;
  final VoidCallback? onEquip, onRemove, onAdd, onEditQuantity;
  final ValueChanged<int>? onQuantityChanged;
  final ValueChanged<bool>? onAttuneToggle;
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
      initialChildSize: .7,
      minChildSize: .4,
      maxChildSize: .94,
      expand: false,
      builder: (context, controller) => SingleChildScrollView(
          controller: controller,
          child: ItemDetailsContent(
              item: item,
              onEquip: onEquip,
              onRemove: onRemove,
              onQuantityChanged: onQuantityChanged,
              onAttuneToggle: onAttuneToggle,
              onAdd: onAdd,
              onEditQuantity: onEditQuantity)));
}

class ItemDetailsContent extends StatelessWidget {
  const ItemDetailsContent(
      {super.key,
      required this.item,
      this.onEquip,
      this.onRemove,
      this.onQuantityChanged,
      this.onAttuneToggle,
      this.onAdd,
      this.onEditQuantity});
  final Item item;
  final VoidCallback? onEquip, onRemove, onAdd, onEditQuantity;
  final ValueChanged<int>? onQuantityChanged;
  final ValueChanged<bool>? onAttuneToggle;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context),
        c = t.colorScheme,
        l = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    final w = item.weaponProperties, a = item.armorProperties;
    Widget fact(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(label,
                  style: t.textTheme.bodyMedium
                      ?.copyWith(color: c.onSurfaceVariant))),
          const SizedBox(width: 18),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: t.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)))
        ]));
    final description = item.getDescription(locale).trim().isNotEmpty
        ? item.getDescription(locale)
        : item.getDescription(locale == 'ru' ? 'en' : 'ru');
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InventoryItemGlyph(item: item, size: 60),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(itemTypeName(context, item.type),
                          style: t.textTheme.labelMedium
                              ?.copyWith(color: c.onSurfaceVariant)),
                      const SizedBox(height: 5),
                      Text(item.getName(locale),
                          style: t.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              letterSpacing: -.7))
                    ]))
              ]),
              const SizedBox(height: 18),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Chip(
                    label:
                        Text(ItemUtils.getLocalizedRarityName(l, item.rarity))),
                if (item.isMagical)
                  Chip(
                      avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: Text(
                          inventoryText(context, 'Магический', 'Magical'))),
                if (item.isEquipped)
                  Chip(
                      label: Text(
                          inventoryText(context, 'Экипирован', 'Equipped'))),
              ]),
              const SizedBox(height: 18),
              if (w != null || a != null)
                CompanionSurface(
                    raised: true,
                    color: c.secondaryContainer,
                    contour: CompanionContour.focus,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w != null ? l.damage : l.armorClass,
                              style: t.textTheme.labelMedium),
                          const SizedBox(height: 6),
                          Text(
                              w != null
                                  ? w.damageDice
                                  : a!.armorType == ArmorType.shield
                                      ? '+${a.baseAC}'
                                      : '${a.baseAC}',
                              style: t.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1)),
                          if (w != null) ...[
                            const SizedBox(height: 4),
                            Text(
                                ItemUtils.getLocalizedDamageType(
                                    l, w.damageType.toString()),
                                style: t.textTheme.bodyMedium),
                            if (w.versatileDamageDice != null)
                              fact(l.versatileDamage, w.versatileDamageDice!),
                            if (w.range != null)
                              fact(l.range,
                                  '${w.range}${w.longRange == null ? '' : ' / ${w.longRange}'} ${inventoryText(context, 'фт', 'ft')}'),
                            if (w.weaponTags.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(spacing: 6, runSpacing: 6, children: [
                                for (final tag in w.weaponTags)
                                  Chip(
                                      label: Text(
                                          ItemUtils.getLocalizedTag(l, tag)))
                              ])
                            ],
                          ],
                          if (a != null) ...[
                            fact(
                                l.type,
                                ItemUtils.getLocalizedArmorType(
                                    l, a.armorType.toString())),
                            if (a.armorType != ArmorType.shield)
                              fact(
                                  inventoryText(
                                      context, 'Ловкость', 'Dexterity'),
                                  a.addDexModifier
                                      ? (a.maxDexBonus == null
                                          ? inventoryText(
                                              context,
                                              'Полный модификатор',
                                              'Full modifier')
                                          : inventoryText(
                                              context,
                                              'Не больше +${a.maxDexBonus}',
                                              'Up to +${a.maxDexBonus}'))
                                      : inventoryText(context, 'Не добавляется',
                                          'Not added')),
                            if ((a.strengthRequirement ?? 0) > 0)
                              fact(
                                  l.strRequirement, '${a.strengthRequirement}'),
                            if (a.stealthDisadvantage)
                              fact(l.stealth, l.disadvantage),
                          ],
                        ])),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(inventoryText(context, 'О предмете', 'About this item'),
                    style: t.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                SelectableText(description,
                    style: t.textTheme.bodyLarge?.copyWith(height: 1.45))
              ],
              const SizedBox(height: 20),
              CompanionSurface(
                  quiet: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Column(children: [
                    fact(l.weight,
                        '${compactNumber(item.weight)} ${l.weightUnit}'),
                    fact(
                        inventoryText(
                            context, 'Цена за штуку', 'Value per item'),
                        '${goldValue(item.valueInCopper)} ${l.currencyGP_short}'),
                    if (onEditQuantity != null)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.quantity),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('×${item.quantity}',
                                style: t.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right_rounded)
                          ]),
                          onTap: onEditQuantity),
                    if (item.requiresAttunement)
                      fact(l.attunement,
                          inventoryText(context, 'Требуется', 'Required')),
                  ])),
              if (onAttuneToggle != null) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(l.attunement),
                    subtitle: Text(item.isAttuned
                        ? inventoryText(context, 'Настроен на героя',
                            'Attuned to your character')
                        : inventoryText(context, 'Не настроен', 'Not attuned')),
                    value: item.isAttuned,
                    onChanged: onAttuneToggle)
              ],
              const SizedBox(height: 24),
              if (onAdd != null)
                FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l.addItem))
              else if (onEquip != null) ...[
                FilledButton.icon(
                    onPressed:
                        item.quantity > 0 || item.isEquipped ? onEquip : null,
                    icon: Icon(item.isEquipped
                        ? Icons.backpack_outlined
                        : Icons.checkroom_rounded),
                    label: Text(item.isEquipped ? l.unequip : l.equip)),
                if (onRemove != null)
                  TextButton.icon(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(l.remove)),
              ],
              if (onQuantityChanged != null && onEditQuantity == null)
                Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                          onPressed: item.quantity > 0
                              ? () => onQuantityChanged!(-1)
                              : null,
                          icon: const Icon(Icons.remove_rounded)),
                      Text('×${item.quantity}'),
                      IconButton(
                          onPressed: () => onQuantityChanged!(1),
                          icon: const Icon(Icons.add_rounded))
                    ]),
            ]));
  }
}
