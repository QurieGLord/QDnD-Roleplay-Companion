import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../character_creation_state.dart';
import '../../../core/services/item_service.dart';
import '../../../core/models/item.dart';

class EquipmentStep extends StatefulWidget {
  const EquipmentStep({super.key});

  @override
  State<EquipmentStep> createState() => _EquipmentStepState();
}

class _EquipmentStepState extends State<EquipmentStep> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          locale == 'ru' ? 'Стартовая экипировка' : 'Starting Equipment',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          locale == 'ru'
              ? 'Выберите стартовое снаряжение для вашего класса'
              : 'Choose your starting equipment for your class',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        // Equipment Package Selection
        if (state.selectedClass != null) ...[
          Text(
            locale == 'ru' ? 'Выберите набор экипировки' : 'Choose Equipment Package',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Standard Package Card
          _buildPackageCard(
            context,
            packageId: 'standard',
            title: locale == 'ru' ? 'Стандартный набор' : 'Standard Package',
            subtitle: locale == 'ru'
                ? 'Рекомендуемое начальное снаряжение для вашего класса'
                : 'Recommended starting equipment for your class',
            icon: Icons.check_circle_outline,
            isSelected: state.selectedEquipmentPackage == 'standard' ||
                state.selectedEquipmentPackage == null,
            onTap: () {
              context.read<CharacterCreationState>().updateEquipmentPackage('standard');
            },
          ),

          const SizedBox(height: 12),

          // Alternative Package Card
          _buildPackageCard(
            context,
            packageId: 'alternative',
            title: locale == 'ru' ? 'Альтернативный набор' : 'Alternative Package',
            subtitle: locale == 'ru'
                ? 'Другие варианты экипировки'
                : 'Different equipment options',
            icon: Icons.swap_horiz,
            isSelected: state.selectedEquipmentPackage == 'alternative',
            onTap: () {
              context.read<CharacterCreationState>().updateEquipmentPackage('alternative');
            },
          ),

          const SizedBox(height: 12),

          // Custom Package Card
          _buildPackageCard(
            context,
            packageId: 'custom',
            title: locale == 'ru' ? 'Кастомный набор' : 'Custom Package',
            subtitle: locale == 'ru'
                ? 'Выберите предметы из каталога'
                : 'Choose items from catalog',
            icon: Icons.edit,
            isSelected: state.selectedEquipmentPackage == 'custom',
            onTap: () {
              context.read<CharacterCreationState>().updateEquipmentPackage('custom');
            },
          ),

          const SizedBox(height: 24),

          // Equipment Content based on selection
          if (state.selectedEquipmentPackage == 'custom')
            _buildCustomEquipmentSection(context, state, locale, theme)
          else
            _buildPresetEquipmentPreview(context, state, locale, theme),
        ],
      ],
    );
  }

  Widget _buildPackageCard(
    BuildContext context, {
    required String packageId,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Custom equipment section with add/remove functionality
  Widget _buildCustomEquipmentSection(
    BuildContext context,
    CharacterCreationState state,
    String locale,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Add button
        Row(
          children: [
            Expanded(
              child: Text(
                locale == 'ru' ? 'Выбранная экипировка' : 'Selected Equipment',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showItemCatalog(context, state, locale),
              icon: const Icon(Icons.add),
              label: Text(locale == 'ru' ? 'Добавить' : 'Add Item'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Selected items list
        if (state.customEquipmentQuantities.isEmpty)
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      locale == 'ru'
                          ? 'Нет выбранных предметов'
                          : 'No items selected',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locale == 'ru'
                          ? 'Нажмите "Добавить" чтобы выбрать предметы'
                          : 'Tap "Add Item" to select equipment',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...state.customEquipmentQuantities.entries.map((entry) {
            final itemId = entry.key;
            final quantity = entry.value;
            final item = ItemService.getItemById(itemId);
            if (item == null) return const SizedBox.shrink();

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  _getItemIcon(item.type),
                  color: theme.colorScheme.primary,
                ),
                title: Text(item.getName(locale)),
                subtitle: Text(
                  locale == 'ru'
                      ? '${item.getDescription(locale)} • Количество: $quantity'
                      : '${item.getDescription(locale)} • Quantity: $quantity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    context.read<CharacterCreationState>().removeCustomEquipment(itemId);
                  },
                ),
              ),
            );
          }),

        const SizedBox(height: 16),

        // Info card
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    locale == 'ru'
                        ? 'Вы можете добавить любые предметы из каталога. Рекомендуется выбрать оружие, доспехи и базовое снаряжение.'
                        : 'You can add any items from the catalog. It\'s recommended to choose weapons, armor, and basic equipment.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Preset equipment preview (standard/alternative)
  Widget _buildPresetEquipmentPreview(
    BuildContext context,
    CharacterCreationState state,
    String locale,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          locale == 'ru'
              ? 'Предпросмотр экипировки ${state.selectedClass!.name['ru']}'
              : '${state.selectedClass!.name['en']} Equipment Preview',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        _buildEquipmentCategory(
          context,
          locale == 'ru' ? 'Оружие' : 'Weapons',
          Icons.gavel,
          _getDefaultWeapons(
            state.selectedClass!.id,
            state.selectedEquipmentPackage ?? 'standard',
            locale,
          ),
          theme.colorScheme.primary,
        ),

        _buildEquipmentCategory(
          context,
          locale == 'ru' ? 'Доспехи' : 'Armor',
          Icons.shield,
          _getDefaultArmor(
            state.selectedClass!.id,
            state.selectedEquipmentPackage ?? 'standard',
            locale,
          ),
          theme.colorScheme.secondary,
        ),

        _buildEquipmentCategory(
          context,
          locale == 'ru' ? 'Инструменты и снаряжение' : 'Tools & Gear',
          Icons.handyman,
          _getDefaultTools(
            state.selectedClass!.id,
            state.selectedEquipmentPackage ?? 'standard',
            locale,
          ),
          theme.colorScheme.tertiary,
        ),

        const SizedBox(height: 16),

        // Info Card
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    locale == 'ru'
                        ? 'Это предпросмотр типичного стартового снаряжения. После создания персонажа вы сможете настроить инвентарь.'
                        : 'This is a preview of typical starting equipment. You can customize your inventory after character creation.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentCategory(
    BuildContext context,
    String title,
    IconData icon,
    List<String> items,
    Color accentColor,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showItemCatalog(BuildContext context, CharacterCreationState state, String locale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ItemCatalogDialog(
        state: state,
        locale: locale,
        onAddItem: (String itemId) async {
          // Show quantity dialog
          final quantity = await _showQuantityDialog(context, itemId, locale);
          if (quantity != null && quantity > 0 && context.mounted) {
            // Add item with quantity
            state.addCustomEquipment(itemId, quantity: quantity);

            // Show feedback
            final item = ItemService.getItemById(itemId);
            if (item != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    locale == 'ru'
                        ? '${item.getName(locale)} (x$quantity) добавлен'
                        : '${item.getName(locale)} (x$quantity) added',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<int?> _showQuantityDialog(BuildContext context, String itemId, String locale) async {
    final item = ItemService.getItemById(itemId);
    if (item == null) return null;

    final quantityController = TextEditingController(text: '1');

    return showDialog<int>(
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
            child: Text(locale == 'ru' ? 'Отмена' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(quantityController.text) ?? 1;
              if (qty > 0) {
                Navigator.pop(context, qty);
              }
            },
            child: Text(locale == 'ru' ? 'Добавить' : 'Add'),
          ),
        ],
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

  List<String> _getDefaultWeapons(String classId, String packageId, String locale) {
    final isAlternative = packageId == 'alternative';

    final weapons = {
      'paladin': {
        'standard': {
          'en': ['Longsword', 'Shield', 'Holy Symbol'],
          'ru': ['Длинный меч', 'Щит', 'Святой символ'],
        },
        'alternative': {
          'en': ['Longsword', 'Javelin (5)', 'Holy Symbol'],
          'ru': ['Длинный меч', 'Дротик (5)', 'Святой символ'],
        },
      },
      'fighter': {
        'standard': {
          'en': ['Longsword', 'Shield', 'Light Crossbow with 20 bolts'],
          'ru': ['Длинный меч', 'Щит', 'Лёгкий арбалет и 20 болтов'],
        },
        'alternative': {
          'en': ['Longbow with 20 arrows', 'Shortsword (2)'],
          'ru': ['Длинный лук и 20 стрел', 'Короткий меч (2)'],
        },
      },
      'wizard': {
        'standard': {
          'en': ['Quarterstaff', 'Dagger'],
          'ru': ['Боевой посох', 'Кинжал'],
        },
        'alternative': {
          'en': ['Dagger (2)', 'Arcane Focus'],
          'ru': ['Кинжал (2)', 'Магический фокус'],
        },
      },
      'rogue': {
        'standard': {
          'en': ['Shortsword', 'Dagger (2)', 'Thieves\' Tools'],
          'ru': ['Короткий меч', 'Кинжал (2)', 'Воровские инструменты'],
        },
        'alternative': {
          'en': ['Rapier', 'Shortbow with 20 arrows', 'Thieves\' Tools'],
          'ru': ['Рапира', 'Короткий лук и 20 стрел', 'Воровские инструменты'],
        },
      },
      'cleric': {
        'standard': {
          'en': ['Mace', 'Shield', 'Holy Symbol'],
          'ru': ['Булава', 'Щит', 'Святой символ'],
        },
        'alternative': {
          'en': ['Warhammer', 'Shield', 'Holy Symbol'],
          'ru': ['Боевой молот', 'Щит', 'Святой символ'],
        },
      },
      'ranger': {
        'standard': {
          'en': ['Longbow with 20 arrows', 'Shortsword'],
          'ru': ['Длинный лук и 20 стрел', 'Короткий меч'],
        },
        'alternative': {
          'en': ['Shortsword (2)', 'Longbow with 20 arrows'],
          'ru': ['Короткий меч (2)', 'Длинный лук и 20 стрел'],
        },
      },
    };

    final packageKey = isAlternative ? 'alternative' : 'standard';
    return weapons[classId]?[packageKey]?[locale] ??
        (locale == 'ru' ? ['Простое оружие', 'Резервное оружие'] : ['Simple weapon', 'Backup weapon']);
  }

  List<String> _getDefaultArmor(String classId, String packageId, String locale) {
    final isAlternative = packageId == 'alternative';

    final armor = {
      'paladin': {
        'standard': {
          'en': ['Chain Mail', 'Shield'],
          'ru': ['Кольчужная броня', 'Щит'],
        },
        'alternative': {
          'en': ['Scale Mail'],
          'ru': ['Чешуйчатая броня'],
        },
      },
      'fighter': {
        'standard': {
          'en': ['Chain Mail', 'Shield'],
          'ru': ['Кольчужная броня', 'Щит'],
        },
        'alternative': {
          'en': ['Leather Armor'],
          'ru': ['Кожаная броня'],
        },
      },
      'wizard': {
        'standard': {
          'en': ['No armor'],
          'ru': ['Без доспехов'],
        },
        'alternative': {
          'en': ['No armor'],
          'ru': ['Без доспехов'],
        },
      },
      'rogue': {
        'standard': {
          'en': ['Leather Armor'],
          'ru': ['Кожаная броня'],
        },
        'alternative': {
          'en': ['Leather Armor'],
          'ru': ['Кожаная броня'],
        },
      },
      'cleric': {
        'standard': {
          'en': ['Chain Mail', 'Shield'],
          'ru': ['Кольчужная броня', 'Щит'],
        },
        'alternative': {
          'en': ['Scale Mail', 'Shield'],
          'ru': ['Чешуйчатая броня', 'Щит'],
        },
      },
      'ranger': {
        'standard': {
          'en': ['Leather Armor'],
          'ru': ['Кожаная броня'],
        },
        'alternative': {
          'en': ['Scale Mail'],
          'ru': ['Чешуйчатая броня'],
        },
      },
    };

    final packageKey = isAlternative ? 'alternative' : 'standard';
    return armor[classId]?[packageKey]?[locale] ??
        (locale == 'ru' ? ['Лёгкая броня или без доспехов'] : ['Light armor or no armor']);
  }

  List<String> _getDefaultTools(String classId, String packageId, String locale) {
    final isAlternative = packageId == 'alternative';

    final tools = {
      'paladin': {
        'standard': {
          'en': ['Explorer\'s Pack', 'Bedroll', 'Rations (10 days)'],
          'ru': ['Набор путешественника', 'Спальный мешок', 'Рационы (10 дней)'],
        },
        'alternative': {
          'en': ['Priest\'s Pack', 'Prayer Book'],
          'ru': ['Набор священника', 'Молитвенник'],
        },
      },
      'fighter': {
        'standard': {
          'en': ['Explorer\'s Pack', 'Bedroll', 'Rations (10 days)'],
          'ru': ['Набор путешественника', 'Спальный мешок', 'Рационы (10 дней)'],
        },
        'alternative': {
          'en': ['Dungeoneer\'s Pack', 'Crowbar', 'Rope (50 feet)'],
          'ru': ['Набор подземельщика', 'Ломик', 'Верёвка (50 футов)'],
        },
      },
      'wizard': {
        'standard': {
          'en': ['Spellbook', 'Component Pouch', 'Scholar\'s Pack'],
          'ru': ['Книга заклинаний', 'Мешочек с компонентами', 'Набор учёного'],
        },
        'alternative': {
          'en': ['Spellbook', 'Arcane Focus', 'Scholar\'s Pack'],
          'ru': ['Книга заклинаний', 'Магический фокус', 'Набор учёного'],
        },
      },
      'rogue': {
        'standard': {
          'en': ['Thieves\' Tools', 'Burglar\'s Pack', 'Crowbar'],
          'ru': ['Воровские инструменты', 'Набор взломщика', 'Ломик'],
        },
        'alternative': {
          'en': ['Thieves\' Tools', 'Dungeoneer\'s Pack', 'Ball Bearings'],
          'ru': ['Воровские инструменты', 'Набор подземельщика', 'Шарики'],
        },
      },
      'cleric': {
        'standard': {
          'en': ['Holy Symbol', 'Priest\'s Pack', 'Prayer Book'],
          'ru': ['Святой символ', 'Набор священника', 'Молитвенник'],
        },
        'alternative': {
          'en': ['Holy Symbol', 'Explorer\'s Pack', 'Incense (10)'],
          'ru': ['Святой символ', 'Набор путешественника', 'Благовония (10)'],
        },
      },
      'ranger': {
        'standard': {
          'en': ['Explorer\'s Pack', 'Rope (50 feet)', 'Hunting Trap'],
          'ru': ['Набор путешественника', 'Верёвка (50 футов)', 'Охотничья ловушка'],
        },
        'alternative': {
          'en': ['Dungeoneer\'s Pack', 'Rope (50 feet)', 'Grappling Hook'],
          'ru': ['Набор подземельщика', 'Верёвка (50 футов)', 'Крюк-кошка'],
        },
      },
    };

    final packageKey = isAlternative ? 'alternative' : 'standard';
    return tools[classId]?[packageKey]?[locale] ??
        (locale == 'ru' ? ['Набор приключенца', 'Верёвка', 'Факел (10)'] : ['Adventurer\'s Pack', 'Rope', 'Torch (10)']);
  }
}

// ============================================================================
// Item Catalog Dialog for Custom Equipment
// ============================================================================

class _ItemCatalogDialog extends StatefulWidget {
  final CharacterCreationState state;
  final String locale;
  final Function(String) onAddItem;

  const _ItemCatalogDialog({
    required this.state,
    required this.locale,
    required this.onAddItem,
  });

  @override
  State<_ItemCatalogDialog> createState() => _ItemCatalogDialogState();
}

class _ItemCatalogDialogState extends State<_ItemCatalogDialog> {
  final _searchController = TextEditingController();
  ItemType? _selectedCategory;
  String _searchQuery = '';

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
            // Header
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
                      widget.locale == 'ru' ? 'Каталог предметов' : 'Item Catalog',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
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
                      ? 'Найдено: ${filteredItems.length} (выбрано: ${widget.state.customEquipmentQuantities.length})'
                      : 'Found: ${filteredItems.length} (selected: ${widget.state.customEquipmentQuantities.length})',
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
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
                        final isSelected = widget.state.customEquipmentQuantities.containsKey(item.id);
                        final quantity = isSelected ? widget.state.customEquipmentQuantities[item.id] ?? 1 : 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected
                                    ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                                    : null,
                              ),
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (_) {
                                if (isSelected) {
                                  setState(() {
                                    widget.state.removeCustomEquipment(item.id);
                                  });
                                } else {
                                  widget.onAddItem(item.id);
                                }
                              },
                            ),
                            onTap: () {
                              if (isSelected) {
                                setState(() {
                                  widget.state.removeCustomEquipment(item.id);
                                });
                              } else {
                                widget.onAddItem(item.id);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),

            // Bottom action button
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
                  onPressed: widget.state.customEquipmentQuantities.isEmpty
                      ? null
                      : () => Navigator.pop(context),
                  child: Text(
                    widget.locale == 'ru'
                        ? 'Готово (${widget.state.customEquipmentQuantities.length})'
                        : 'Done (${widget.state.customEquipmentQuantities.length})',
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
