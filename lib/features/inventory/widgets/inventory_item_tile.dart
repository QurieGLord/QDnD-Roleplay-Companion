import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/models/item.dart';
import '../../../core/ui/companion_surface.dart';
import '../../../core/ui/expressive_hold_surface.dart';
import '../../../core/utils/item_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../inventory_presentation.dart';

class InventoryItemGlyph extends StatelessWidget {
  const InventoryItemGlyph({super.key, required this.item, this.size = 48});
  final Item item;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final icon = switch (item.iconName) {
      'scroll' => Icons.menu_book_rounded,
      'food' => Icons.restaurant_rounded,
      'gold' => Icons.toll_rounded,
      'sword' => Icons.gavel_rounded,
      _ => ItemUtils.getIcon(item.type)
    };
    return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: c.surface.withValues(alpha: .55),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(size * .36),
                topRight: Radius.circular(size * .27),
                bottomLeft: Radius.circular(size * .25),
                bottomRight: Radius.circular(size * .36))),
        child: item.customImagePath != null
            ? Image.file(File(item.customImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(icon, color: c.secondary))
            : Icon(icon, color: c.secondary, size: size * .48));
  }
}

class InventoryItemTile extends StatelessWidget {
  const InventoryItemTile(
      {super.key,
      required this.item,
      required this.onTap,
      required this.onHold,
      this.equipment = false});
  final Item item;
  final VoidCallback onTap, onHold;
  final bool equipment;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context),
        c = t.colorScheme,
        l = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    return ExpressiveHoldSurface(
        onTap: onTap,
        onHold: onHold,
        semanticLabel:
            '${item.getName(locale)}, ${l.quantity}: ${item.quantity}',
        hint: l.sheetHoldToEdit,
        child: CompanionSurface(
            quiet: !equipment,
            raised: equipment,
            color: equipment ? c.secondaryContainer : c.surfaceContainerLow,
            contour: equipment ? CompanionContour.focus : CompanionContour.soft,
            padding: const EdgeInsets.all(16),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              InventoryItemGlyph(item: item, size: equipment ? 54 : 46),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(item.getName(locale),
                        style: (equipment
                                ? t.textTheme.titleLarge
                                : t.textTheme.titleMedium)
                            ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.35,
                                height: 1.14)),
                    const SizedBox(height: 7),
                    Text(itemSummary(context, item),
                        style: t.textTheme.bodySmall
                            ?.copyWith(color: c.onSurfaceVariant)),
                    if (item.isAttuned || item.isEquipped && !equipment) ...[
                      const SizedBox(height: 7),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        if (item.isEquipped && !equipment)
                          Text(inventoryText(context, 'Экипирован', 'Equipped'),
                              style: t.textTheme.labelSmall
                                  ?.copyWith(color: c.secondary)),
                        if (item.isAttuned)
                          Text(inventoryText(context, 'Настроен', 'Attuned'),
                              style: t.textTheme.labelSmall
                                  ?.copyWith(color: c.tertiary)),
                      ])
                    ],
                  ])),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (item.quantity != 1)
                  Text('×${item.quantity}',
                      style: t.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: item.quantity == 0
                              ? c.onSurfaceVariant
                              : c.onSurface)),
                if (!equipment) ...[
                  const SizedBox(height: 4),
                  Text('${compactNumber(item.totalWeight)} ${l.weightUnit}',
                      style: t.textTheme.labelSmall
                          ?.copyWith(color: c.onSurfaceVariant))
                ],
              ]),
            ])));
  }
}
