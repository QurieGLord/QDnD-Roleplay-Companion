import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/item.dart';

class InventoryTab extends StatefulWidget {
  final Character character;

  const InventoryTab({
    super.key,
    required this.character,
  });

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  String _filterType = 'all'; // all, weapon, armor, gear, consumable, tool, treasure
  String _equipFilter = 'all'; // all, equipped, unequipped
  String _sortBy = 'name'; // name, weight, value, type
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getCurrencyLabel(AppLocalizations l10n, String currency) {
    switch (currency.toLowerCase()) {
      case 'pp': return l10n.currencyPP_short;
      case 'gp': return l10n.currencyGP_short;
      case 'sp': return l10n.currencySP_short;
      case 'cp': return l10n.currencyCP_short;
      default: return currency;
    }
  }

  String _getLocalizedTag(AppLocalizations l10n, String tag) {
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

  String _getLocalizedDamageType(AppLocalizations l10n, String damageType) {
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

  String _getLocalizedArmorType(AppLocalizations l10n, String armorType) {
     final lower = armorType.toLowerCase().split('.').last;
     switch (lower) {
       case 'light': return l10n.armorTypeLight;
       case 'medium': return l10n.armorTypeMedium;
       case 'heavy': return l10n.armorTypeHeavy;
       case 'shield': return l10n.armorTypeShield;
       default: return armorType;
     }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;

    List<Item> filteredItems = List.from(widget.character.inventory);

    if (_filterType != 'all') {
      final itemType = ItemType.values.firstWhere(
        (type) => type.toString().split('.').last == _filterType,
        orElse: () => ItemType.gear,
      );
      filteredItems = filteredItems.where((item) => item.type == itemType).toList();
    }

    if (_equipFilter == 'equipped') {
      filteredItems = filteredItems.where((item) => item.isEquipped).toList();
    } else if (_equipFilter == 'unequipped') {
      filteredItems = filteredItems.where((item) => !item.isEquipped).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredItems = filteredItems.where((item) {
        final name = item.getName(locale).toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query);
      }).toList();
    }

    filteredItems.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return a.getName(locale).compareTo(b.getName(locale));
        case 'weight':
          return b.totalWeight.compareTo(a.totalWeight);
        case 'value':
          return b.valueInGold.compareTo(a.valueInGold);
        case 'type':
          return a.type.toString().compareTo(b.type.toString());
        default:
          return 0;
      }
    });

    final totalWeight = widget.character.inventory.fold<double>(
      0.0,
      (sum, item) => sum + item.totalWeight,
    );

    return Column(
      children: [
        Container(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.searchItems,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.sortBy,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            isDense: true,
                            items: [
                              DropdownMenuItem(value: 'name', child: Text(l10n.sortName)),
                              DropdownMenuItem(value: 'weight', child: Text(l10n.sortWeight)),
                              DropdownMenuItem(value: 'value', child: Text(l10n.sortValue)),
                              DropdownMenuItem(value: 'type', child: Text(l10n.sortType)),
                            ],
                            onChanged: (value) => setState(() => _sortBy = value!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.filterEquipped,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _equipFilter,
                            isDense: true,
                            items: [
                              DropdownMenuItem(value: 'all', child: Text(l10n.filterAll)),
                              DropdownMenuItem(value: 'equipped', child: Text(l10n.filterEquipped)),
                              DropdownMenuItem(value: 'unequipped', child: Text(l10n.filterUnequipped)),
                            ],
                            onChanged: (value) => setState(() => _equipFilter = value!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(l10n.filterAll),
                      selected: _filterType == 'all',
                      onSelected: (selected) {
                        if (selected) setState(() => _filterType = 'all');
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(l10n.typeWeapon),
                      selected: _filterType == 'weapon',
                      onSelected: (selected) {
                        if (selected) setState(() => _filterType = 'weapon');
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(l10n.typeArmor),
                      selected: _filterType == 'armor',
                      onSelected: (selected) {
                        if (selected) setState(() => _filterType = 'armor');
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(l10n.typeGear),
                      selected: _filterType == 'gear',
                      onSelected: (selected) {
                        if (selected) setState(() => _filterType = 'gear');
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(l10n.typeConsumable),
                      selected: _filterType == 'consumable',
                      onSelected: (selected) {
                        if (selected) setState(() => _filterType = 'consumable');
                      },
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.fitness_center, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.totalWeight}: ${totalWeight.toStringAsFixed(1)} ${l10n.weightUnit}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: filteredItems.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.monetization_on, size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                l10n.currency,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showEditCurrencyDialog(context, l10n),
                                tooltip: l10n.edit,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildCurrencyChip(theme, _getCurrencyLabel(l10n, 'PP'), widget.character.platinumPieces, Colors.grey.shade300, Colors.black87)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildCurrencyChip(theme, _getCurrencyLabel(l10n, 'GP'), widget.character.goldPieces, Colors.amber.shade600, Colors.black87)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildCurrencyChip(theme, _getCurrencyLabel(l10n, 'SP'), widget.character.silverPieces, Colors.grey.shade400, Colors.black87)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildCurrencyChip(theme, _getCurrencyLabel(l10n, 'CP'), widget.character.copperPieces, Colors.brown.shade400, Colors.white)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final itemIndex = index - 1;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildItemCard(context, filteredItems[itemIndex], locale, l10n),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.inventoryEmpty,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.inventoryEmptyHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Item item, String locale, AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showItemDetails(context, item, locale, l10n),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.isEquipped
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getItemIcon(item.type),
                  color: item.isEquipped
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.getName(locale),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (item.quantity > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'x${item.quantity}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.weaponProperties != null) ...[
                          Icon(Icons.whatshot,
                              size: 14, color: theme.colorScheme.error),
                          const SizedBox(width: 4),
                          Text(
                            item.weaponProperties!.damageDice,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (item.armorProperties != null) ...[
                          Icon(Icons.shield,
                              size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${l10n.armorClassAC} ${item.armorProperties!.baseAC}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Icon(Icons.fitness_center,
                            size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${item.totalWeight.toStringAsFixed(1)} ${l10n.weightUnit}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                                          if (item.weaponProperties != null && item.weaponProperties!.weaponTags.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: item.weaponProperties!.weaponTags.take(3).map((tag) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  _getLocalizedTag(l10n, tag),
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                    color: theme.colorScheme.onSecondaryContainer,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                    
                                  if (item.isEquipped)
                                    Icon(
                                      Icons.check_circle,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    
                      IconData _getItemIcon(ItemType type) {
                        switch (type) {
                          case ItemType.weapon:
                            return Icons.gavel;
                          case ItemType.armor:
                            return Icons.shield;
                          case ItemType.gear:
                            return Icons.backpack;
                          case ItemType.consumable:
                            return Icons.local_drink;
                          case ItemType.tool:
                            return Icons.build;
                          case ItemType.treasure:
                            return Icons.diamond;
                        }
                      }
                    
                      void _showItemDetails(BuildContext context, Item item, String locale, AppLocalizations l10n) {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => DraggableScrollableSheet(
                            initialChildSize: 0.6,
                            minChildSize: 0.4,
                            maxChildSize: 0.9,
                            expand: false,
                            builder: (context, scrollController) {
                              return SingleChildScrollView(
                                controller: scrollController,
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _getItemIcon(item.type),
                                            size: 32,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              item.getName(locale),
                                              style: Theme.of(context).textTheme.headlineSmall,
                                            ),
                                          ),
                                        ],
                                      ),
                    
                                      const SizedBox(height: 16),
                    
                                      Text(
                                        item.getDescription(locale),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                    
                                      const SizedBox(height: 24),
                    
                                      if (item.weaponProperties != null)
                                        _buildWeaponProperties(item.weaponProperties!, l10n),
                                      if (item.armorProperties != null)
                                        _buildArmorProperties(item.armorProperties!, l10n),
                    
                                      _buildStatRow(
                                        l10n.weight,
                                        '${item.weight} ${l10n.weightUnit}',
                                      ),
                                      _buildStatRow(
                                        l10n.value,
                                        '${item.valueInGold.toStringAsFixed(2)} ${l10n.currencyUnit}',
                                      ),
                                      
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            l10n.quantity,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                onPressed: item.quantity > 1
                                                    ? () {
                                                        _changeQuantity(item, -1);
                                                        Navigator.pop(context);
                                                        _showItemDetails(context, item, locale, l10n);
                                                      }
                                                    : null,
                                                icon: const Icon(Icons.remove_circle_outline),
                                              ),
                                              Text(
                                                '${item.quantity}',
                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                              ),
                                              IconButton(
                                                onPressed: () {
                                                  _changeQuantity(item, 1);
                                                  Navigator.pop(context);
                                                  _showItemDetails(context, item, locale, l10n);
                                                },
                                                icon: const Icon(Icons.add_circle_outline),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                    
                                      const SizedBox(height: 24),
                    
                                      Row(
                                        children: [
                                          Expanded(
                                            child: FilledButton.icon(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _toggleEquip(item);
                                              },
                                              icon: Icon(
                                                  item.isEquipped ? Icons.close : Icons.check),
                                              label: Text(
                                                item.isEquipped
                                                    ? l10n.unequip
                                                    : l10n.equip,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          FilledButton.tonalIcon(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _removeItem(item);
                                            },
                                            icon: const Icon(Icons.delete),
                                            label: Text(l10n.remove),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }
                    
                      Widget _buildWeaponProperties(WeaponProperties props, AppLocalizations l10n) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.weaponProperties,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            _buildStatRow(
                              l10n.damage,
                              props.damageDice,
                            ),
                            _buildStatRow(
                              l10n.damageType,
                              _getLocalizedDamageType(l10n, props.damageType.toString()),
                            ),
                            if (props.versatileDamageDice != null)
                              _buildStatRow(
                                l10n.versatileDamage,
                                props.versatileDamageDice!,
                              ),
                            if (props.range != null)
                              _buildStatRow(
                                l10n.range,
                                '${props.range}/${props.longRange} ft', // Consider localizing unit if possible
                              ),
                            if (props.weaponTags.isNotEmpty)
                              _buildStatRow(
                                l10n.properties,
                                props.weaponTags.map((t) => _getLocalizedTag(l10n, t)).join(', '),
                              ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }
                    
                      Widget _buildArmorProperties(ArmorProperties props, AppLocalizations l10n) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.armorProperties,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            _buildStatRow(
                              l10n.armorClass,
                              '${l10n.armorClassAC} ${props.baseAC}',
                            ),
                            _buildStatRow(
                              l10n.type,
                              _getLocalizedArmorType(l10n, props.armorType.toString()),
                            ),
                            if (props.strengthRequirement != null && props.strengthRequirement! > 0)
                              _buildStatRow(
                                l10n.strRequirement,
                                '${props.strengthRequirement}',
                              ),
                            if (props.stealthDisadvantage)
                              _buildStatRow(
                                l10n.stealth,
                                l10n.disadvantage,
                              ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }
  Widget _buildStatRow(String label, String value) {
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

  void _toggleEquip(Item item) async {
    // Find the item in character's inventory
    final index = widget.character.inventory.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    // Toggle equipped state
    widget.character.inventory[index].isEquipped =
        !widget.character.inventory[index].isEquipped;

    // Recalculate AC if armor/shield
    if (item.type == ItemType.armor) {
      widget.character.recalculateAC();
    }

    // Save to database
    widget.character.updatedAt = DateTime.now();
    await widget.character.save();

    // Update UI
    setState(() {});

    // Show feedback
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.character.inventory[index].isEquipped
                ? l10n.itemEquipped
                : l10n.itemUnequipped,
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _removeItem(Item item) async {
    // Remove from inventory
    widget.character.inventory.removeWhere((i) => i.id == item.id);

    // Save to database
    widget.character.updatedAt = DateTime.now();
    await widget.character.save();

    // Update UI
    setState(() {});

    // Show feedback
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.itemRemoved),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _changeQuantity(Item item, int delta) async {
    // Find the item in character's inventory
    final index = widget.character.inventory.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    // Update quantity
    final newQuantity = widget.character.inventory[index].quantity + delta;

    // If quantity reaches 0, remove the item
    if (newQuantity <= 0) {
      widget.character.inventory.removeAt(index);
    } else {
      widget.character.inventory[index].quantity = newQuantity;
    }

    // Save to database
    widget.character.updatedAt = DateTime.now();
    await widget.character.save();

    // Update UI
    setState(() {});
  }

  Widget _buildCurrencyChip(ThemeData theme, String label, int amount, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$amount',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditCurrencyDialog(BuildContext context, AppLocalizations l10n) {
    final ppController = TextEditingController(text: '${widget.character.platinumPieces}');
    final gpController = TextEditingController(text: '${widget.character.goldPieces}');
    final spController = TextEditingController(text: '${widget.character.silverPieces}');
    final cpController = TextEditingController(text: '${widget.character.copperPieces}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editCurrency),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ppController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.currencyPP,
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monetization_on, color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.currencyGP,
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monetization_on, color: Colors.amber.shade600),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: spController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.currencySP,
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monetization_on, color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.currencyCP,
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monetization_on, color: Colors.brown.shade400),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              // Update currency values
              widget.character.platinumPieces = int.tryParse(ppController.text) ?? 0;
              widget.character.goldPieces = int.tryParse(gpController.text) ?? 0;
              widget.character.silverPieces = int.tryParse(spController.text) ?? 0;
              widget.character.copperPieces = int.tryParse(cpController.text) ?? 0;

              // Save to database
              widget.character.updatedAt = DateTime.now();
              await widget.character.save();

              // Close dialog
              if (context.mounted) {
                Navigator.pop(context);
              }

              // Update UI
              setState(() {});

              // Show feedback
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.currencyUpdated),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}