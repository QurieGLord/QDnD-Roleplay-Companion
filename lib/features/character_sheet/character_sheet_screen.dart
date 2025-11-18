import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
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
    _animationController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
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
                final cardHeight = 200.0 * progress;

                // Don't render card if nearly collapsed to avoid overflow
                if (progress < 0.2) {
                  return SizedBox(height: cardHeight);
                }

                return ClipRect(
                  child: SizedBox(
                    height: cardHeight,
                    child: Opacity(
                      opacity: progress,
                      child: ExpandableCharacterCard(
                        character: widget.character,
                        isExpanded: _currentIndex == 0,
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

            // Content Area
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  OverviewTab(character: widget.character),
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
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, size: 22),
              selectedIcon: Icon(Icons.home, size: 22),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined, size: 22),
              selectedIcon: Icon(Icons.analytics, size: 22),
              label: 'Stats',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_fix_high_outlined, size: 22),
              selectedIcon: Icon(Icons.auto_fix_high, size: 22),
              label: 'Spells',
            ),
            NavigationDestination(
              icon: Icon(Icons.backpack_outlined, size: 22),
              selectedIcon: Icon(Icons.backpack, size: 22),
              label: 'Inventory',
            ),
            NavigationDestination(
              icon: Icon(Icons.book_outlined, size: 22),
              selectedIcon: Icon(Icons.book, size: 22),
              label: 'Journal',
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          final allItems = ItemService.getAllItems();

          return Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  locale == 'ru' ? 'Добавить предмет' : 'Add Item',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const Divider(height: 1),

              // Item list
              Expanded(
                child: allItems.isEmpty
                    ? Center(
                        child: Text(
                          locale == 'ru'
                              ? 'Предметы не загружены'
                              : 'Items not loaded',
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: allItems.length,
                        itemBuilder: (context, index) {
                          final item = allItems[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(
                                _getItemIcon(item.type),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(item.getName(locale)),
                              subtitle: Text(
                                item.getDescription(locale),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showQuantityDialog(context, item);
                                },
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _showQuantityDialog(context, item);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
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
