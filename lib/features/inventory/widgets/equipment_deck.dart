import 'package:flutter/material.dart';
import '../../../core/models/character.dart';
import '../../../core/models/item.dart';
import '../../../core/ui/companion_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../inventory_presentation.dart';
import 'inventory_item_tile.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class EquipmentDeck extends StatelessWidget {
  const EquipmentDeck(
      {super.key,
      required this.hero,
      required this.onOpen,
      required this.onHold});
  final Character hero;
  final ValueChanged<Item> onOpen, onHold;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context),
        c = t.colorScheme,
        l = AppLocalizations.of(context)!;
    final equipped =
        hero.inventory.where((i) => i.isEquipped && i.quantity > 0).toList();
    final weapons = equipped.where((i) => i.weaponProperties != null).toList();
    final armor = equipped.where((i) => i.armorProperties != null).toList();
    final other = equipped
        .where((i) => i.weaponProperties == null && i.armorProperties == null)
        .toList();
    final attuned = hero.inventory.where((i) => i.isAttuned).toList();
    Widget item(Item i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InventoryItemTile(
            item: i,
            equipment: true,
            onTap: () => onOpen(i),
            onHold: () => onHold(i)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(inventoryText(context, 'При себе', 'At the ready'),
                      style: t.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800, letterSpacing: -.8)),
                  const SizedBox(height: 4),
                  Text(
                      inventoryText(
                          context,
                          'Снаряжение, на которое ты полагаешься',
                          'The gear you rely on'),
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: c.onSurfaceVariant)),
                ])),
            const SizedBox(width: 12),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: c.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
                child: Column(children: [
                  Text(l.armorClassAC, style: t.textTheme.labelSmall),
                  Text('${hero.armorClass}',
                      style: t.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800))
                ])),
          ])),
      if (equipped.isEmpty)
        CompanionSurface(
            quiet: true,
            child: Row(children: [
              Icon(Icons.backpack_outlined, color: c.secondary, size: 30),
              const SizedBox(width: 16),
              Expanded(
                  child: Text(
                      inventoryText(
                          context,
                          'Всё пока в рюкзаке. Открой предмет и экипируй его.',
                          'Everything is packed. Open an item to equip it.'),
                      style: t.textTheme.bodyMedium))
            ])),
      for (final i in weapons) item(i),
      if (armor.isNotEmpty)
        LayoutBuilder(builder: (context, bounds) {
          final paired = armor.length == 2 &&
              bounds.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(1) < 1.3;
          if (!paired) {
            return Column(children: [for (final i in armor) item(i)]);
          }
          return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    for (var j = 0; j < armor.length; j++) ...[
                      if (j > 0) const SizedBox(width: 10),
                      Expanded(
                          child: _ArmorCard(
                              item: armor[j],
                              onTap: () => onOpen(armor[j]),
                              onHold: () => onHold(armor[j]))),
                    ]
                  ])));
        }),
      for (final i in other) item(i),
      if (attuned.isNotEmpty) ...[
        const SizedBox(height: 4),
        Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                      inventoryText(context, 'Настройка ${attuned.length}/3',
                          'Attunement ${attuned.length}/3'),
                      style: t.textTheme.labelMedium
                          ?.copyWith(color: c.onSurfaceVariant))),
              for (final i in attuned)
                ActionChip(
                    avatar: Icon(Icons.auto_awesome_rounded,
                        size: 15, color: c.tertiary),
                    label: Text(i
                        .getName(Localizations.localeOf(context).languageCode)),
                    onPressed: () => onOpen(i)),
            ])
      ],
    ]);
  }
}

class _ArmorCard extends StatelessWidget {
  const _ArmorCard(
      {required this.item, required this.onTap, required this.onHold});
  final Item item;
  final VoidCallback onTap, onHold;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    return CompanionSurface(
        onTap: onTap,
        onLongPress: onHold,
        raised: true,
        color: c.tertiaryContainer,
        contour: CompanionContour.fold,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
                item.armorProperties!.armorType == ArmorType.shield
                    ? Icons.shield_outlined
                    : Icons.security_rounded,
                color: c.tertiary,
                size: 24),
            const Spacer(),
            Text(itemSummary(context, item),
                style: t.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800))
          ]),
          const SizedBox(height: 18),
          Text(item.getName(Localizations.localeOf(context).languageCode),
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, height: 1.15)),
          const SizedBox(height: 6),
          Text(
              item.armorProperties!.armorType == ArmorType.shield
                  ? inventoryText(context, 'Щит', 'Shield')
                  : inventoryText(context, 'Доспех', 'Armor'),
              style:
                  t.textTheme.labelSmall?.copyWith(color: c.onSurfaceVariant)),
        ]));
  }
}
