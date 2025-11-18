import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    // Filter and sort inventory
    // Create mutable copy to avoid "Cannot modify unmodifiable list" error from Hive
    List<Item> filteredItems = List.from(widget.character.inventory);

    // Apply type filter
    if (_filterType != 'all') {
      final itemType = ItemType.values.firstWhere(
        (type) => type.toString().split('.').last == _filterType,
        orElse: () => ItemType.gear,
      );
      filteredItems = filteredItems.where((item) => item.type == itemType).toList();
    }

    // Apply equipment filter
    if (_equipFilter == 'equipped') {
      filteredItems = filteredItems.where((item) => item.isEquipped).toList();
    } else if (_equipFilter == 'unequipped') {
      filteredItems = filteredItems.where((item) => !item.isEquipped).toList();
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filteredItems = filteredItems.where((item) {
        final name = item.getName(locale).toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query);
      }).toList();
    }

    // Apply sorting
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

    // Calculate total weight
    final totalWeight = widget.character.inventory.fold<double>(
      0.0,
      (sum, item) => sum + item.totalWeight,
    );

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: locale == 'ru' ? 'Поиск предметов...' : 'Search items...',
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
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),

        // Filter and sort row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Sort dropdown
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: locale == 'ru' ? 'Сортировка' : 'Sort by',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      isDense: true,
                      items: [
                        DropdownMenuItem(value: 'name', child: Text(locale == 'ru' ? 'Имя' : 'Name')),
                        DropdownMenuItem(value: 'weight', child: Text(locale == 'ru' ? 'Вес' : 'Weight')),
                        DropdownMenuItem(value: 'value', child: Text(locale == 'ru' ? 'Стоимость' : 'Value')),
                        DropdownMenuItem(value: 'type', child: Text(locale == 'ru' ? 'Тип' : 'Type')),
                      ],
                      onChanged: (value) => setState(() => _sortBy = value!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Equipment filter dropdown
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: locale == 'ru' ? 'Экипировка' : 'Equipped',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _equipFilter,
                      isDense: true,
                      items: [
                        DropdownMenuItem(value: 'all', child: Text(locale == 'ru' ? 'Все' : 'All')),
                        DropdownMenuItem(value: 'equipped', child: Text(locale == 'ru' ? 'Надето' : 'Equipped')),
                        DropdownMenuItem(value: 'unequipped', child: Text(locale == 'ru' ? 'Снято' : 'Unequipped')),
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

        // Type filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text(locale == 'ru' ? 'Всё' : 'All'),
                  selected: _filterType == 'all',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterType = 'all');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(locale == 'ru' ? 'Оружие' : 'Weapons'),
                  selected: _filterType == 'weapon',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterType = 'weapon');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(locale == 'ru' ? 'Доспехи' : 'Armor'),
                  selected: _filterType == 'armor',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterType = 'armor');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(locale == 'ru' ? 'Снаряжение' : 'Gear'),
                  selected: _filterType == 'gear',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterType = 'gear');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(locale == 'ru' ? 'Расходники' : 'Consumables'),
                  selected: _filterType == 'consumable',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterType = 'consumable');
                  },
                ),
              ],
            ),
          ),
        ),

        // Weight info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.fitness_center, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                locale == 'ru'
                    ? 'Общий вес: ${totalWeight.toStringAsFixed(1)} фунтов'
                    : 'Total Weight: ${totalWeight.toStringAsFixed(1)} lb',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Inventory list
        Expanded(
          child: filteredItems.isEmpty
              ? _buildEmptyState(locale)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _buildItemCard(context, item, locale);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String locale) {
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
              locale == 'ru' ? 'Инвентарь пуст' : 'Inventory is empty',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              locale == 'ru'
                  ? 'Нажмите + чтобы добавить предметы'
                  : 'Tap + to add items',
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

  Widget _buildItemCard(BuildContext context, Item item, String locale) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showItemDetails(context, item, locale),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Item icon
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

              // Item details
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
                        // Weapon damage or armor AC
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
                            'AC ${item.armorProperties!.baseAC}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // Weight
                        Icon(Icons.fitness_center,
                            size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${item.totalWeight.toStringAsFixed(1)} lb',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    // Weapon tags
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
                              tag,
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

              // Equipped indicator
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
        return Icons.gavel; // Closest to weapon in Material Icons
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

  void _showItemDetails(BuildContext context, Item item, String locale) {
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
                  // Header
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

                  // Description
                  Text(
                    item.getDescription(locale),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 24),

                  // Properties
                  if (item.weaponProperties != null)
                    _buildWeaponProperties(item.weaponProperties!, locale),
                  if (item.armorProperties != null)
                    _buildArmorProperties(item.armorProperties!, locale),

                  // Basic stats
                  _buildStatRow(
                    locale == 'ru' ? 'Вес' : 'Weight',
                    '${item.weight} lb',
                  ),
                  _buildStatRow(
                    locale == 'ru' ? 'Стоимость' : 'Value',
                    '${item.valueInGold.toStringAsFixed(2)} gp',
                  ),
                  // Quantity controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        locale == 'ru' ? 'Количество' : 'Quantity',
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
                                    _showItemDetails(context, item, locale);
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
                              _showItemDetails(context, item, locale);
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Actions
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
                                ? (locale == 'ru' ? 'Снять' : 'Unequip')
                                : (locale == 'ru' ? 'Экипировать' : 'Equip'),
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
                        label: Text(locale == 'ru' ? 'Удалить' : 'Remove'),
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

  Widget _buildWeaponProperties(WeaponProperties props, String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          locale == 'ru' ? 'СВОЙСТВА ОРУЖИЯ' : 'WEAPON PROPERTIES',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        _buildStatRow(
          locale == 'ru' ? 'Урон' : 'Damage',
          props.damageDice,
        ),
        _buildStatRow(
          locale == 'ru' ? 'Тип урона' : 'Damage Type',
          props.damageType.toString().split('.').last,
        ),
        if (props.versatileDamageDice != null)
          _buildStatRow(
            locale == 'ru' ? 'Универсальный урон' : 'Versatile Damage',
            props.versatileDamageDice!,
          ),
        if (props.range != null)
          _buildStatRow(
            locale == 'ru' ? 'Дальность' : 'Range',
            '${props.range}/${props.longRange} ft',
          ),
        if (props.weaponTags.isNotEmpty)
          _buildStatRow(
            locale == 'ru' ? 'Свойства' : 'Properties',
            props.weaponTags.join(', '),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildArmorProperties(ArmorProperties props, String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          locale == 'ru' ? 'СВОЙСТВА ДОСПЕХА' : 'ARMOR PROPERTIES',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        _buildStatRow(
          locale == 'ru' ? 'Класс доспеха' : 'Armor Class',
          'AC ${props.baseAC}',
        ),
        _buildStatRow(
          locale == 'ru' ? 'Тип' : 'Type',
          props.armorType.toString().split('.').last,
        ),
        if (props.strengthRequirement != null && props.strengthRequirement! > 0)
          _buildStatRow(
            locale == 'ru' ? 'Требование СИЛ' : 'STR Requirement',
            '${props.strengthRequirement}',
          ),
        if (props.stealthDisadvantage)
          _buildStatRow(
            locale == 'ru' ? 'Скрытность' : 'Stealth',
            locale == 'ru' ? 'Помеха' : 'Disadvantage',
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

    // Save to database
    widget.character.updatedAt = DateTime.now();
    await widget.character.save();

    // Update UI
    setState(() {});

    // Show feedback
    if (mounted) {
      final locale = Localizations.localeOf(context).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.character.inventory[index].isEquipped
                ? (locale == 'ru' ? 'Экипировано' : 'Equipped')
                : (locale == 'ru' ? 'Снято' : 'Unequipped'),
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
      final locale = Localizations.localeOf(context).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locale == 'ru' ? 'Предмет удалён' : 'Item removed',
          ),
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
}
