import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/character.dart';
import '../../core/models/item.dart';
import '../../core/services/item_service.dart';
import '../../shared/widgets/dice_roller_modal.dart';
import 'widgets/expandable_character_card.dart';
import 'widgets/overview_tab.dart';
import 'widgets/stats_tab.dart';
import 'widgets/spells_tab.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/journal_tab.dart';

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
  late PageController _pageController;
  final ScrollController _scrollController = ScrollController();
  bool _isCardExpanded = false;
  double? _dragStartY;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
      _isCardExpanded = false;
    });
    if (index == 0) _scrollToTop();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      if (index != 0) {
        _isCardExpanded = false;
      } else {
        _scrollToTop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
                            // 1. Character Card
                            SliverToBoxAdapter(
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: _currentIndex == 0
                                    ? Listener(
                                        behavior: HitTestBehavior.translucent,
                                        onPointerDown: (event) => _dragStartY = event.position.dy,
                                        onPointerUp: (_) => _dragStartY = null,
                                        onPointerMove: (event) {
                                          if (_dragStartY == null) return;
                                          final delta = event.position.dy - _dragStartY!;
                                          
                                          // Swipe Down -> Expand
                                          if (delta > 6 && !_isCardExpanded) {
                                            setState(() {
                                              _isCardExpanded = true;
                                              _dragStartY = null;
                                            });
                                            _scrollController.position.hold(() {});
                                          }
                                          // Swipe Up -> Collapse
                                          else if (delta < -6 && _isCardExpanded) {
                                            setState(() {
                                              _isCardExpanded = false;
                                              _dragStartY = null;
                                            });
                                            _scrollController.position.hold(() {});
                                          }
                                        },
                                        child: ExpandableCharacterCard(
                                          character: widget.character,
                                          isExpanded: _isCardExpanded,
                                          onDicePressed: () {
                                            showDiceRoller(
                                              context,
                                              title: AppLocalizations.of(context)!.rollDie(20),
                                              modifier: 0,
                                            );
                                          },
                                          onDetailsToggled: (val) {
                                            setState(() => _isCardExpanded = val);
                                          },
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
              // 2. Sticky Navigation Bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyNavBarDelegate(
                  child: _buildNavBar(),
                  height: 80,
                ),
              ),
            ];
          },
          body: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.forward && _isCardExpanded) {
                setState(() => _isCardExpanded = false);
              }
              return false;
            },
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                OverviewTab(
                  character: widget.character,
                  onCharacterUpdated: () => setState(() {}),
                ),
                StatsTab(character: widget.character),
                SpellsTab(character: widget.character),
                InventoryTab(character: widget.character),
                JournalTab(character: widget.character),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 3
          ? FloatingActionButton(
              onPressed: () => _showAddItemDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildNavBar() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.home_outlined, Icons.home),
            _buildNavItem(1, Icons.analytics_outlined, Icons.analytics),
            _buildNavItem(2, Icons.auto_fix_high_outlined, Icons.auto_fix_high),
            _buildNavItem(3, Icons.backpack_outlined, Icons.backpack),
            _buildNavItem(4, Icons.book_outlined, Icons.book),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon) {
    final isSelected = _currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: () => _onTabChanged(index),
        borderRadius: BorderRadius.circular(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSecondaryContainer.withOpacity(0.7),
              size: 26,
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSecondaryContainer,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) async {
    final locale = Localizations.localeOf(context).languageCode;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddItemDialog(
        character: widget.character,
        locale: locale,
        onAddItem: _showQuantityDialog,
      ),
    );
    setState(() {});
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
          children: [
            Text(item.getDescription(locale), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(labelText: locale == 'ru' ? 'Количество' : 'Quantity', border: const OutlineInputBorder()),
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text(locale == 'ru' ? 'Отмена' : 'Cancel')),
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
    widget.character.inventory.add(newItem);
    widget.character.updatedAt = DateTime.now();
    widget.character.save();
    final locale = Localizations.localeOf(context).languageCode;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(locale == 'ru' ? '${newItem.getName(locale)} (x$quantity) добавлен в инвентарь' : '${newItem.getName(locale)} (x$quantity) added to inventory'), duration: const Duration(seconds: 2)));
    setState(() {});
  }
}

class _StickyNavBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyNavBarDelegate({required this.child, required this.height});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _StickyNavBarDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}

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
  final Map<String, int> _selectedItems = {}; 

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Item> _getFilteredItems() {
    var items = ItemService.getAllItems();
    if (_selectedCategory != null) {
      items = items.where((item) => item.type == _selectedCategory).toList();
    }
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
      case ItemType.weapon: return Icons.gavel;
      case ItemType.armor: return Icons.shield;
      case ItemType.gear: return Icons.backpack;
      case ItemType.consumable: return Icons.local_drink;
      case ItemType.tool: return Icons.build;
      case ItemType.treasure: return Icons.diamond;
    }
  }

  String _getCategoryName(ItemType type) {
    switch (type) {
      case ItemType.weapon: return widget.locale == 'ru' ? 'Оружие' : 'Weapons';
      case ItemType.armor: return widget.locale == 'ru' ? 'Доспехи' : 'Armor';
      case ItemType.gear: return widget.locale == 'ru' ? 'Снаряжение' : 'Gear';
      case ItemType.consumable: return widget.locale == 'ru' ? 'Расходники' : 'Consumables';
      case ItemType.tool: return widget.locale == 'ru' ? 'Инструменты' : 'Tools';
      case ItemType.treasure: return widget.locale == 'ru' ? 'Сокровища' : 'Treasure';
    }
  }

  void _showCreateCustomItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateCustomItemDialog(character: widget.character, locale: widget.locale),
    );
  }

  Future<void> _showQuantityDialogForItem(String itemId, String itemName, String itemDesc) async {
    final quantityController = TextEditingController(text: _selectedItems.containsKey(itemId) ? '${_selectedItems[itemId]}' : '1');
    final quantity = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(itemName),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(itemDesc, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(controller: quantityController, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(labelText: widget.locale == 'ru' ? 'Количество' : 'Quantity', border: const OutlineInputBorder()), onSubmitted: (value) { final qty = int.tryParse(value) ?? 1; if (qty > 0) Navigator.pop(context, qty); }),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.locale == 'ru' ? 'Отмена' : 'Cancel')), FilledButton(onPressed: () { final qty = int.tryParse(quantityController.text) ?? 1; if (qty > 0) Navigator.pop(context, qty); }, child: Text(widget.locale == 'ru' ? 'Готово' : 'Done'))],
      ),
    );
    if (quantity != null && quantity > 0) setState(() => _selectedItems[itemId] = quantity);
  }

  void _addSelectedItemsToInventory() {
    for (var entry in _selectedItems.entries) {
      for (int i = 0; i < entry.value; i++) {
        final newItem = ItemService.createItemFromTemplate(entry.key);
        if (newItem != null) widget.character.inventory.add(newItem);
      }
    }
    widget.character.updatedAt = DateTime.now();
    widget.character.save();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.locale == 'ru' ? 'Добавлено предметов: ${_selectedItems.length}' : 'Added ${_selectedItems.length} items'), duration: const Duration(seconds: 2)));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredItems = _getFilteredItems();
    return DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (context, scrollController) {
        return Column(children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1))), child: Row(children: [Expanded(child: Text(widget.locale == 'ru' ? 'Добавить предмет' : 'Add Item', style: theme.textTheme.headlineSmall)), FilledButton.icon(onPressed: () { Navigator.pop(context); _showCreateCustomItemDialog(context); }, icon: const Icon(Icons.add), label: Text(widget.locale == 'ru' ? 'Создать' : 'Create'))])),
            Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _searchController, decoration: InputDecoration(hintText: widget.locale == 'ru' ? 'Поиск предметов...' : 'Search items...', prefixIcon: const Icon(Icons.search), suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; })) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), onChanged: (value) => setState(() => _searchQuery = value))),
            SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(widget.locale == 'ru' ? 'Все' : 'All'), selected: _selectedCategory == null, onSelected: (_) => setState(() => _selectedCategory = null))), ...ItemType.values.map((type) => Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(avatar: Icon(_getItemIcon(type), size: 18), label: Text(_getCategoryName(type)), selected: _selectedCategory == type, onSelected: (_) => setState(() => _selectedCategory = type))))])),
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: Alignment.centerLeft, child: Text(widget.locale == 'ru' ? 'Найдено: ${filteredItems.length}' : 'Found: ${filteredItems.length}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)))),
            const SizedBox(height: 8),
            Expanded(child: filteredItems.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)), const SizedBox(height: 16), Text(widget.locale == 'ru' ? 'Предметы не найдены' : 'No items found', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant))])) : ListView.builder(controller: scrollController, padding: const EdgeInsets.all(16), itemCount: filteredItems.length, itemBuilder: (context, index) { final item = filteredItems[index]; final isSelected = _selectedItems.containsKey(item.id); final quantity = isSelected ? _selectedItems[item.id] ?? 1 : 0; return Card(margin: const EdgeInsets.only(bottom: 12), color: isSelected ? theme.colorScheme.primaryContainer : null, child: ListTile(leading: Badge(label: Text('$quantity'), isLabelVisible: isSelected && quantity > 0, backgroundColor: theme.colorScheme.secondary, textColor: theme.colorScheme.onSecondary, child: Icon(_getItemIcon(item.type), color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.primary)), title: Text(item.getName(widget.locale), style: TextStyle(color: isSelected ? theme.colorScheme.onPrimaryContainer : null)), subtitle: Text(item.getDescription(widget.locale), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isSelected ? theme.colorScheme.onPrimaryContainer.withOpacity(0.8) : null)), trailing: IconButton(icon: Icon(isSelected ? Icons.remove_circle : Icons.add_circle, color: isSelected ? theme.colorScheme.onPrimaryContainer : null), onPressed: () { if (isSelected) { setState(() => _selectedItems.remove(item.id)); } else { _showQuantityDialogForItem(item.id, item.getName(widget.locale), item.getDescription(widget.locale)); } }), onTap: () => _showQuantityDialogForItem(item.id, item.getName(widget.locale), item.getDescription(widget.locale)))); })),
            if (_selectedItems.isNotEmpty) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: theme.colorScheme.surface, border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1))), child: SafeArea(top: false, child: FilledButton(onPressed: _addSelectedItemsToInventory, child: Text(widget.locale == 'ru' ? 'Готово (${_selectedItems.length})' : 'Done (${_selectedItems.length})')))),
        ]);
      },
    );
  }
}

class _CreateCustomItemDialog extends StatefulWidget {
  final Character character;
  final String locale;
  const _CreateCustomItemDialog({required this.character, required this.locale});
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
    _nameController.dispose(); _descController.dispose(); _weightController.dispose(); _valueController.dispose(); _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
      if (result != null && result.files.isNotEmpty) setState(() => _imagePath = result.files.first.path);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.locale == 'ru' ? 'Ошибка: $e' : 'Error: $e'), backgroundColor: Theme.of(context).colorScheme.error)); }
  }

  String _getTypeName(ItemType type) {
    switch (type) { case ItemType.weapon: return widget.locale == 'ru' ? 'Оружие' : 'Weapon'; case ItemType.armor: return widget.locale == 'ru' ? 'Доспехи' : 'Armor'; case ItemType.gear: return widget.locale == 'ru' ? 'Снаряжение' : 'Gear'; case ItemType.consumable: return widget.locale == 'ru' ? 'Расходник' : 'Consumable'; case ItemType.tool: return widget.locale == 'ru' ? 'Инструмент' : 'Tool'; case ItemType.treasure: return widget.locale == 'ru' ? 'Сокровище' : 'Treasure'; }
  }

  String _getRarityName(ItemRarity rarity) {
    switch (rarity) { case ItemRarity.common: return widget.locale == 'ru' ? 'Обычный' : 'Common'; case ItemRarity.uncommon: return widget.locale == 'ru' ? 'Необычный' : 'Uncommon'; case ItemRarity.rare: return widget.locale == 'ru' ? 'Редкий' : 'Rare'; case ItemRarity.veryRare: return widget.locale == 'ru' ? 'Очень редкий' : 'Very Rare'; case ItemRarity.legendary: return widget.locale == 'ru' ? 'Легендарный' : 'Legendary'; case ItemRarity.artifact: return widget.locale == 'ru' ? 'Артефакт' : 'Artifact'; }
  }

  void _createItem() {
    if (!_formKey.currentState!.validate()) return;
    try {
      final newItem = Item(id: 'custom_${Uuid().v4()}', nameEn: _nameController.text.trim(), nameRu: _nameController.text.trim(), descriptionEn: _descController.text.trim(), descriptionRu: _descController.text.trim(), type: _selectedType, rarity: _selectedRarity, quantity: int.tryParse(_quantityController.text) ?? 1, weight: double.tryParse(_weightController.text) ?? 0.0, valueInCopper: int.tryParse(_valueController.text) ?? 0, customImagePath: _imagePath, isEquipped: false, isAttuned: false);
      widget.character.inventory.add(newItem); widget.character.updatedAt = DateTime.now(); widget.character.save(); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.locale == 'ru' ? '${newItem.getName(widget.locale)} создан!' : '${newItem.getName(widget.locale)} created!')));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.locale == 'ru' ? 'Ошибка: $e' : 'Error: $e'), backgroundColor: Theme.of(context).colorScheme.error)); } 
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.locale == 'ru' ? 'Создать предмет' : 'Create Custom Item',
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.colorScheme.outline, width: 2),
                            ),
                            child: _imagePath != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate, size: 40, color: theme.colorScheme.onSurfaceVariant),
                                      const SizedBox(height: 8),
                                      Text(
                                        widget.locale == 'ru' ? 'Добавить\nизображение' : 'Add\nimage',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: widget.locale == 'ru' ? 'Название' : 'Name',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? (widget.locale == 'ru' ? 'Введите название' : 'Enter name') : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        decoration: InputDecoration(
                          labelText: widget.locale == 'ru' ? 'Описание' : 'Description',
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ItemType>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: widget.locale == 'ru' ? 'Тип' : 'Type',
                          border: const OutlineInputBorder(),
                        ),
                        items: ItemType.values.map((t) => DropdownMenuItem(value: t, child: Text(_getTypeName(t)))).toList(),
                        onChanged: (v) => setState(() => _selectedType = v!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ItemRarity>(
                        value: _selectedRarity,
                        decoration: InputDecoration(
                          labelText: widget.locale == 'ru' ? 'Редкость' : 'Rarity',
                          border: const OutlineInputBorder(),
                        ),
                        items: ItemRarity.values.map((r) => DropdownMenuItem(value: r, child: Text(_getRarityName(r)))).toList(),
                        onChanged: (v) => setState(() => _selectedRarity = v!),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              decoration: InputDecoration(
                                labelText: widget.locale == 'ru' ? 'Вес' : 'Weight',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _valueController,
                              decoration: InputDecoration(
                                labelText: widget.locale == 'ru' ? 'Цена' : 'Value',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText: widget.locale == 'ru' ? 'Количество' : 'Quantity',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
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
