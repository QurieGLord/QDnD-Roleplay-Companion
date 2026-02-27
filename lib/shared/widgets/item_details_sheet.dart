import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/item.dart';
import '../../core/utils/item_utils.dart';

class ItemDetailsSheet extends StatelessWidget {
  final Item item;
  // Inventory actions
  final VoidCallback? onEquip;
  final VoidCallback? onRemove;
  final Function(int)? onQuantityChanged;
  final Function(bool)? onAttuneToggle;

  // Catalog actions
  final VoidCallback? onAdd;

  const ItemDetailsSheet({
    super.key,
    required this.item,
    this.onEquip,
    this.onRemove,
    this.onQuantityChanged,
    this.onAttuneToggle,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: ItemDetailsContent(
            item: item,
            onEquip: onEquip,
            onRemove: onRemove,
            onQuantityChanged: onQuantityChanged,
            onAttuneToggle: onAttuneToggle,
            onAdd: onAdd,
          ),
        );
      },
    );
  }
}

class ItemDetailsContent extends StatelessWidget {
  final Item item;
  final VoidCallback? onEquip;
  final VoidCallback? onRemove;
  final Function(int)? onQuantityChanged;
  final Function(bool)? onAttuneToggle;
  final VoidCallback? onAdd;

  const ItemDetailsContent({
    super.key,
    required this.item,
    this.onEquip,
    this.onRemove,
    this.onQuantityChanged,
    this.onAttuneToggle,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ItemUtils.getIcon(item.type),
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.getName(locale),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (item.getDescription(locale).isNotEmpty) ...[
            Text(
              item.getDescription(locale),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
          ],
          if (item.isMagical && onAttuneToggle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SwitchListTile(
                title: Text(l10n.attunement),
                subtitle: Text(item.isAttuned ? 'Attuned' : 'Not Attuned'),
                value: item.isAttuned,
                onChanged: onAttuneToggle,
                secondary: const Icon(Icons.auto_awesome),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (item.weaponProperties != null)
            _buildWeaponProperties(context, item.weaponProperties!, l10n),
          if (item.armorProperties != null)
            _buildArmorProperties(context, item.armorProperties!, l10n),
          _buildStatRow(
            context,
            l10n.weight,
            '${item.weight} ${l10n.weightUnit}',
          ),
          _buildStatRow(
            context,
            l10n.value,
            '${item.valueInGold.toStringAsFixed(2)} ${l10n.currencyUnit}',
          ),
          if (onQuantityChanged != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.quantity,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: item.quantity > 1
                            ? () => onQuantityChanged!(-1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${item.quantity}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => onQuantityChanged!(1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          if (onAdd != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(l10n.addItem),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            )
          else if (onEquip != null && onRemove != null)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEquip,
                    icon: Icon(item.isEquipped ? Icons.close : Icons.check),
                    label: Text(
                      item.isEquipped ? l10n.unequip : l10n.equip,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete),
                  label: Text(l10n.remove),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWeaponProperties(
      BuildContext context, WeaponProperties props, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.weaponProperties,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        _buildStatRow(context, l10n.damage, props.damageDice),
        _buildStatRow(
            context,
            l10n.damageType,
            ItemUtils.getLocalizedDamageType(
                l10n, props.damageType.toString())),
        if (props.versatileDamageDice != null)
          _buildStatRow(
              context, l10n.versatileDamage, props.versatileDamageDice!),
        if (props.range != null)
          _buildStatRow(
              context, l10n.range, '${props.range}/${props.longRange} ft'),
        if (props.weaponTags.isNotEmpty)
          _buildStatRow(
              context,
              l10n.properties,
              props.weaponTags
                  .map((t) => ItemUtils.getLocalizedTag(l10n, t))
                  .join(', ')),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildArmorProperties(
      BuildContext context, ArmorProperties props, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.armorProperties,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        _buildStatRow(
            context, l10n.armorClass, '${l10n.armorClassAC} ${props.baseAC}'),
        _buildStatRow(context, l10n.type,
            ItemUtils.getLocalizedArmorType(l10n, props.armorType.toString())),
        if (props.strengthRequirement != null && props.strengthRequirement! > 0)
          _buildStatRow(
              context, l10n.strRequirement, '${props.strengthRequirement}'),
        if (props.stealthDisadvantage)
          _buildStatRow(context, l10n.stealth, l10n.disadvantage),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
