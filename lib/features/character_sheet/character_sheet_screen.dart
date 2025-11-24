import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/character.dart';
import '../../core/models/item.dart';
import '../../core/services/item_service.dart';
import '../../shared/widgets/dice_roller_modal.dart';
import 'widgets/expandable_character_card.dart';
import 'widgets/overview_tab.dart';
import 'widgets/stats_tab.dart';
import 'widgets/spells_tab.dart';
import 'tabs/inventory_tab.dart';

class CharacterSheetScreen extends StatefulWidget {
  final Character character;

  const CharacterSheetScreen({
    super.key,
    required this.character,
  });

  @override
  State<CharacterSheetScreen> createState() => _CharacterSheetScreenState();
}

class _CharacterSheetScreenState extends State<CharacterSheetScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _cardHeightAnimation;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
      value: 1.0,  // Start expanded (Overview is default)
    );

    _cardHeightAnimation = Tween<double>(
      begin: 0.0,  // Collapsed (other tabs)
      end: 1.0,    // Expanded (Overview tab)
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) {
        _animationController.forward();  // Expand on Overview
      } else {
        _animationController.reverse();  // Collapse on other tabs
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Expandable Character Card
            AnimatedBuilder(
              animation: _cardHeightAnimation,
              builder: (context, child) {
                final progress = _cardHeightAnimation.value;
                final isOnOverviewTab = _currentIndex == 0;

                // Don't render card if nearly collapsed to avoid overflow
                if (progress < 0.2) {
                  return SizedBox(height: 200.0 * progress);
                }

                // On Overview tab, let card expand naturally
                if (isOnOverviewTab) {
                  return Opacity(
                    opacity: progress,
                    child: ExpandableCharacterCard(
                      character: widget.character,
                      isExpanded: true,
                      onDicePressed: () {
                        showDiceRoller(
                          context,
                          title: 'Roll d20',
                          modifier: 0,
                        );
                      },
                    ),
                  );
                }

                // On other tabs, clip to fixed height
                return ClipRect(
                  child: SizedBox(
                    height: 200.0 * progress,
                    child: Opacity(
                      opacity: progress,
                      child: ExpandableCharacterCard(
                        character: widget.character,
                        isExpanded: false,
                        onDicePressed: () {
                          showDiceRoller(
                            context,
                            title: 'Roll d20',
                            modifier: 0,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),

            // Navigation Bar (under the card)
            _buildAnimatedNavBar(),

            // Content Area with PageView for swipe gestures
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  OverviewTab(
                    character: widget.character,
                    onCharacterUpdated: () {
                      setState(() {
                        // Force rebuild after combat changes
                      });
                    },
                  ),
                  StatsTab(character: widget.character),
                  SpellsTab(character: widget.character),
                  InventoryTab(character: widget.character),
                  _buildPlaceholderTab('Journal - Session 8'),
                ],
              ),
            ),
          ],
        ),
      ),
      // FAB - показывается только на вкладке Inventory (index 3)
      floatingActionButton: _currentIndex == 3
          ? FloatingActionButton(
              onPressed: () => _showAddItemDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildAnimatedNavBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabChanged,
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          indicatorShape: const CircleBorder(),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, size: 26),
              selectedIcon: Icon(Icons.home, size: 26),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined, size: 26),
              selectedIcon: Icon(Icons.analytics, size: 26),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_fix_high_outlined, size: 26),
              selectedIcon: Icon(Icons.auto_fix_high, size: 26),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.backpack_outlined, size: 26),
              selectedIcon: Icon(Icons.backpack, size: 26),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.book_outlined, size: 26),
              selectedIcon: Icon(Icons.book, size: 26),
              label: '',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddItemDialog(
        character: widget.character,
        locale: locale,
        onAddItem: _showQuantityDialog,
      ),
    );
  }

  void _showQuantityDialog(BuildContext context, Item item) {
    final locale = Localizations.localeOf(context).languageCode;
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.getName(locale)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.getDescription(locale),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: locale == 'ru' ? 'Количество' : 'Quantity',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                final quantity = int.tryParse(value) ?? 1;
                if (quantity > 0) {
                  Navigator.pop(context);
                  _addItemToInventory(item.id, quantity: quantity);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(locale == 'ru' ? 'Отмена' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 1;
              if (quantity > 0) {
                Navigator.pop(context);
                _addItemToInventory(item.id, quantity: quantity);
              }
            },
            child: Text(locale == 'ru' ? 'Добавить' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _addItemToInventory(String itemId, {int quantity = 1}) {
    final newItem = ItemService.createItemFromTemplate(itemId, quantity: quantity);
    if (newItem == null) return;

    // Add to character's inventory
    widget.character.inventory.add(newItem);
    widget.character.updatedAt = DateTime.now();
    widget.character.save();

    // Show feedback
    final locale = Localizations.localeOf(context).languageCode;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          locale == 'ru'
              ? '${newItem.getName(locale)} (x$quantity) добавлен в инвентарь'
              : '${newItem.getName(locale)} (x$quantity) added to inventory',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    // Refresh UI
    setState(() {});
  }
}

// ============================================================================
// Add Item Dialog Widget
// ============================================================================

class _AddItemDialog extends StatefulWidget {
  final Character character;
  final String locale;
  final Function(BuildContext, Item) onAddItem;

  const _AddItemDialog({
    required this.character,
    required this.locale,
    required this.onAddItem,
  });

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _searchController = TextEditingController();
  ItemType? _selectedCategory;
  String _searchQuery = '';
  final Map<String, int> _selectedItems = {}; // itemId -> quantity

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Item> _getFilteredItems() {
    var items = ItemService.getAllItems();

    // Filter by category
    if (_selectedCategory != null) {
      items = items.where((item) => item.type == _selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      items = items.where((item) {
        final name = item.getName(widget.locale).toLowerCase();
        final description = item.getDescription(widget.locale).toLowerCase();
        return name.contains(query) || description.contains(query);
      }).toList();
    }

    return items;
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

  String _getCategoryName(ItemType type) {
    switch (type) {
      case ItemType.weapon:
        return widget.locale == 'ru' ? 'Оружие' : 'Weapons';
      case ItemType.armor:
        return widget.locale == 'ru' ? 'Доспехи' : 'Armor';
      case ItemType.gear:
        return widget.locale == 'ru' ? 'Снаряжение' : 'Gear';
      case ItemType.consumable:
        return widget.locale == 'ru' ? 'Расходники' : 'Consumables';
      case ItemType.tool:
        return widget.locale == 'ru' ? 'Инструменты' : 'Tools';
      case ItemType.treasure:
        return widget.locale == 'ru' ? 'Сокровища' : 'Treasure';
    }
  }

  void _showCreateCustomItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateCustomItemDialog(
        character: widget.character,
        locale: widget.locale,
      ),
    );
  }

  Future<void> _showQuantityDialogForItem(String itemId, String itemName, String itemDesc) async {
    final quantityController = TextEditingController(
      text: _selectedItems.containsKey(itemId) ? '${_selectedItems[itemId]}' : '1',
    );

    final quantity = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(itemName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              itemDesc,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: widget.locale == 'ru' ? 'Количество' : 'Quantity',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                final qty = int.tryParse(value) ?? 1;
                if (qty > 0) {
                  Navigator.pop(context, qty);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.locale == 'ru' ? 'Отмена' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(quantityController.text) ?? 1;
              if (qty > 0) {
                Navigator.pop(context, qty);
              }
            },
            child: Text(widget.locale == 'ru' ? 'Готово' : 'Done'),
          ),
        ],
      ),
    );

    if (quantity != null && quantity > 0) {
      setState(() {
        _selectedItems[itemId] = quantity;
      });
    }
  }

  void _addSelectedItemsToInventory() {
    for (var entry in _selectedItems.entries) {
      final itemId = entry.key;
      final quantity = entry.value;

      for (int i = 0; i < quantity; i++) {
        final newItem = ItemService.createItemFromTemplate(itemId);
        if (newItem != null) {
          widget.character.inventory.add(newItem);
        }
      }
    }

    widget.character.updatedAt = DateTime.now();
    widget.character.save();

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.locale == 'ru'
              ? 'Добавлено предметов: ${_selectedItems.length}'
              : 'Added ${_selectedItems.length} items',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredItems = _getFilteredItems();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header with Create Custom button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.locale == 'ru' ? 'Добавить предмет' : 'Add Item',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreateCustomItemDialog(context);
                    },
                    icon: const Icon(Icons.add),
                    label: Text(
                      widget.locale == 'ru' ? 'Создать' : 'Create',
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.locale == 'ru'
                      ? 'Поиск предметов...'
                      : 'Search items...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // Category filters
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // All items chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        widget.locale == 'ru' ? 'Все' : 'All',
                      ),
                      selected: _selectedCategory == null,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = null;
                        });
                      },
                    ),
                  ),
                  // Category chips
                  ...ItemType.values.map((type) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(
                          _getItemIcon(type),
                          size: 18,
                        ),
                        label: Text(_getCategoryName(type)),
                        selected: _selectedCategory == type,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = type;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Results count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.locale == 'ru'
                      ? 'Найдено: ${filteredItems.length}'
                      : 'Found: ${filteredItems.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Item list
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.locale == 'ru'
                                ? 'Предметы не найдены'
                                : 'No items found',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = _selectedItems.containsKey(item.id);
                        final quantity = isSelected ? _selectedItems[item.id] ?? 1 : 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isSelected
                              ? theme.colorScheme.primaryContainer
                              : null,
                          child: ListTile(
                            leading: Badge(
                              label: Text('$quantity'),
                              isLabelVisible: isSelected && quantity > 0,
                              backgroundColor: theme.colorScheme.secondary,
                              textColor: theme.colorScheme.onSecondary,
                              child: Icon(
                                _getItemIcon(item.type),
                                color: isSelected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              item.getName(widget.locale),
                              style: TextStyle(
                                color: isSelected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              item.getDescription(widget.locale),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected
                                    ? theme.colorScheme.onPrimaryContainer.withOpacity(0.8)
                                    : null,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isSelected ? Icons.remove_circle : Icons.add_circle,
                                color: isSelected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : null,
                              ),
                              onPressed: () {
                                if (isSelected) {
                                  setState(() {
                                    _selectedItems.remove(item.id);
                                  });
                                } else {
                                  _showQuantityDialogForItem(
                                    item.id,
                                    item.getName(widget.locale),
                                    item.getDescription(widget.locale),
                                  );
                                }
                              },
                            ),
                            onTap: () {
                              if (isSelected) {
                                _showQuantityDialogForItem(
                                  item.id,
                                  item.getName(widget.locale),
                                  item.getDescription(widget.locale),
                                );
                              } else {
                                _showQuantityDialogForItem(
                                  item.id,
                                  item.getName(widget.locale),
                                  item.getDescription(widget.locale),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),

            // Done button at bottom
            if (_selectedItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: FilledButton(
                    onPressed: _addSelectedItemsToInventory,
                    child: Text(
                      widget.locale == 'ru'
                          ? 'Готово (${_selectedItems.length})'
                          : 'Done (${_selectedItems.length})',
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// Create Custom Item Dialog Widget
// ============================================================================

class _CreateCustomItemDialog extends StatefulWidget {
  final Character character;
  final String locale;

  const _CreateCustomItemDialog({
    required this.character,
    required this.locale,
  });

  @override
  State<_CreateCustomItemDialog> createState() => _CreateCustomItemDialogState();
}

class _CreateCustomItemDialogState extends State<_CreateCustomItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _weightController = TextEditingController(text: '0');
  final _valueController = TextEditingController(text: '0');
  final _quantityController = TextEditingController(text: '1');

  ItemType _selectedType = ItemType.gear;
  ItemRarity _selectedRarity = ItemRarity.common;
  String? _imagePath;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _weightController.dispose();
    _valueController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _imagePath = result.files.first.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.locale == 'ru'
                  ? 'Ошибка загрузки изображения: $e'
                  : 'Error loading image: $e',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _getTypeName(ItemType type) {
    switch (type) {
      case ItemType.weapon:
        return widget.locale == 'ru' ? 'Оружие' : 'Weapon';
      case ItemType.armor:
        return widget.locale == 'ru' ? 'Доспехи' : 'Armor';
      case ItemType.gear:
        return widget.locale == 'ru' ? 'Снаряжение' : 'Gear';
      case ItemType.consumable:
        return widget.locale == 'ru' ? 'Расходник' : 'Consumable';
      case ItemType.tool:
        return widget.locale == 'ru' ? 'Инструмент' : 'Tool';
      case ItemType.treasure:
        return widget.locale == 'ru' ? 'Сокровище' : 'Treasure';
    }
  }

  String _getRarityName(ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.common:
        return widget.locale == 'ru' ? 'Обычный' : 'Common';
      case ItemRarity.uncommon:
        return widget.locale == 'ru' ? 'Необычный' : 'Uncommon';
      case ItemRarity.rare:
        return widget.locale == 'ru' ? 'Редкий' : 'Rare';
      case ItemRarity.veryRare:
        return widget.locale == 'ru' ? 'Очень редкий' : 'Very Rare';
      case ItemRarity.legendary:
        return widget.locale == 'ru' ? 'Легендарный' : 'Legendary';
      case ItemRarity.artifact:
        return widget.locale == 'ru' ? 'Артефакт' : 'Artifact';
    }
  }

  void _createItem() {
    if (!_formKey.currentState!.validate()) return;

    try {
      final name = _nameController.text.trim();
      final desc = _descController.text.trim();

      final customItem = Item(
        id: 'custom_${const Uuid().v4()}',
        nameEn: widget.locale == 'en' ? name : name,
        nameRu: widget.locale == 'ru' ? name : name,
        descriptionEn: widget.locale == 'en' ? desc : desc,
        descriptionRu: widget.locale == 'ru' ? desc : desc,
        type: _selectedType,
        rarity: _selectedRarity,
        quantity: int.tryParse(_quantityController.text) ?? 1,
        weight: double.tryParse(_weightController.text) ?? 0.0,
        valueInCopper: int.tryParse(_valueController.text) ?? 0,
        customImagePath: _imagePath,
        isEquipped: false,
        isAttuned: false,
      );

      // Add to character inventory
      widget.character.inventory.add(customItem);
      widget.character.updatedAt = DateTime.now();
      widget.character.save();

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.locale == 'ru'
                ? '${customItem.getName(widget.locale)} создан!'
                : '${customItem.getName(widget.locale)} created!',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.locale == 'ru'
                ? 'Ошибка создания предмета: $e'
                : 'Error creating item: $e',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.locale == 'ru'
                          ? 'Создать предмет'
                          : 'Create Custom Item',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image picker
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.outline,
                                width: 2,
                              ),
                            ),
                            child: _imagePath != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(_imagePath!),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        size: 40,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        widget.locale == 'ru'
                                            ? 'Добавить\nизображение'
                                            : 'Add\nimage',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: widget.locale == 'ru' ? 'Название' : 'Name',
                          hintText: widget.locale == 'ru' ? 'Например: Меч света' : 'e.g., Sword of Light',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return widget.locale == 'ru'
                                ? 'Введите название'
                                : 'Enter name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descController,
                        decoration: InputDecoration(
                          labelText: widget.locale == 'ru' ? 'Описание' : 'Description',
                          hintText: widget.locale == 'ru'
                              ? 'Опишите предмет...'
                              : 'Describe the item...',
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),

                      const SizedBox(height: 16),

                      // Type dropdown
                      DropdownButtonFormField<ItemType>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: widget.locale == 'ru' ? 'Тип' : 'Type',
                          border: const OutlineInputBorder(),
                        ),
                        items: ItemType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getTypeName(type)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedType = value;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // Rarity dropdown
                      DropdownButtonFormField<ItemRarity>(
                        value: _selectedRarity,
                        decoration: InputDecoration(
                          labelText: widget.locale == 'ru' ? 'Редкость' : 'Rarity',
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          ItemRarity.common,
                          ItemRarity.uncommon,
                          ItemRarity.rare,
                          ItemRarity.veryRare,
                          ItemRarity.legendary,
                        ].map((rarity) {
                          return DropdownMenuItem(
                            value: rarity,
                            child: Text(_getRarityName(rarity)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedRarity = value;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // Weight and Value in row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              decoration: InputDecoration(
                                labelText: widget.locale == 'ru' ? 'Вес (lb)' : 'Weight (lb)',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _valueController,
                              decoration: InputDecoration(
                                labelText: widget.locale == 'ru' ? 'Цена (cp)' : 'Value (cp)',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Quantity
                      TextFormField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText: widget.locale == 'ru' ? 'Количество' : 'Quantity',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final qty = int.tryParse(value ?? '');
                          if (qty == null || qty < 1) {
                            return widget.locale == 'ru'
                                ? 'Минимум 1'
                                : 'Minimum 1';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(widget.locale == 'ru' ? 'Отмена' : 'Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _createItem,
                    icon: const Icon(Icons.check),
                    label: Text(widget.locale == 'ru' ? 'Создать' : 'Create'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
