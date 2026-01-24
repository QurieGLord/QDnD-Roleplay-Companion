import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/item.dart';
import '../../../core/utils/item_utils.dart';
import '../../../shared/widgets/item_details_sheet.dart';
import '../widgets/inventory_status_bar.dart';
import '../../../core/services/item_service.dart';
import '../../inventory/create_item_screen.dart';

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
    
    final maxWeight = (widget.character.abilityScores.strength * 15).toDouble();
    final attunedCount = widget.character.inventory
        .where((i) => i.isAttuned && i.isEquipped) // User logic
        .length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreateItem(context),
        child: const Icon(Icons.add),
        tooltip: l10n.addItem,
      ),
      body: Column(
        children: [
          InventoryStatusBar(
            currentWeight: totalWeight,
            maxWeight: maxWeight,
            attunedCount: attunedCount,
          ),
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
                final item = filteredItems[itemIndex];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Dismissible(
                    key: Key(item.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: Icon(Icons.delete, color: theme.colorScheme.onError),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(l10n.delete),
                          content: Text(l10n.deleteItemConfirmation(item.getName(locale))),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(l10n.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                              child: Text(l10n.delete),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) => _removeItem(item),
                    child: _buildItemCard(context, item, locale, l10n),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCreateItem(BuildContext context) async {
    final newItem = await Navigator.push<Item>(
      context,
      MaterialPageRoute(builder: (context) => const CreateItemScreen()),
    );

    if (newItem != null) {
      widget.character.inventory.add(newItem);
      widget.character.updatedAt = DateTime.now();
      await widget.character.save();
      setState(() {});
      
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final locale = Localizations.localeOf(context).languageCode;
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(l10n.itemAdded(newItem.getName(locale), newItem.quantity))),
        );
      }
    }
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
        onTap: () => _showItemDetails(context, item),
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
                  ItemUtils.getIcon(item.type),
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
                              ItemUtils.getLocalizedTag(l10n, tag),
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

  void _showItemDetails(BuildContext context, Item item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ItemDetailsSheet(
        item: item,
        onEquip: () {
          Navigator.pop(context);
          _toggleEquip(item);
        },
        onRemove: () {
          Navigator.pop(context);
          _removeItem(item);
        },
        onQuantityChanged: (delta) {
          _changeQuantity(item, delta);
          Navigator.pop(context);
          _showItemDetails(context, item);
        },
        onAttuneToggle: (value) {
          Navigator.pop(context);
          _toggleAttunement(item, value);
        },
      ),
    );
  }

  void _toggleAttunement(Item item, bool value) async {
    final l10n = AppLocalizations.of(context)!;
    
    // Validation: Check limit if turning ON
    if (value) {
      final currentAttuned = widget.character.inventory
          .where((i) => i.isAttuned && i.isEquipped)
          .length;
      
      if (currentAttuned >= 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.attunementLimitReached), 
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
    }

    // Find item
    final index = widget.character.inventory.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    // Update
    widget.character.inventory[index].isAttuned = value;
    widget.character.updatedAt = DateTime.now();
    await widget.character.save();

    setState(() {});
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
