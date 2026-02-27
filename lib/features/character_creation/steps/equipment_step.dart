import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.equipmentStepTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.equipmentStepSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        // Equipment Package Selection
        if (state.selectedClass != null) ...[
          Text(
            l10n.chooseEquipmentPackage,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Standard Package Card
          _buildPackageCard(
            context,
            packageId: 'standard',
            title: l10n.packageStandard,
            subtitle: l10n.packageStandardDesc,
            icon: Icons.check_circle_outline,
            isSelected: state.selectedEquipmentPackage == 'standard' ||
                state.selectedEquipmentPackage == null,
            onTap: () {
              context
                  .read<CharacterCreationState>()
                  .updateEquipmentPackage('standard');
            },
          ),

          const SizedBox(height: 12),

          // Alternative Package Card
          _buildPackageCard(
            context,
            packageId: 'alternative',
            title: l10n.packageAlternative,
            subtitle: l10n.packageAlternativeDesc,
            icon: Icons.swap_horiz,
            isSelected: state.selectedEquipmentPackage == 'alternative',
            onTap: () {
              context
                  .read<CharacterCreationState>()
                  .updateEquipmentPackage('alternative');
            },
          ),

          const SizedBox(height: 12),

          // Custom Package Card
          _buildPackageCard(
            context,
            packageId: 'custom',
            title: l10n.packageCustom,
            subtitle: l10n.packageCustomDesc,
            icon: Icons.edit,
            isSelected: state.selectedEquipmentPackage == 'custom',
            onTap: () {
              context
                  .read<CharacterCreationState>()
                  .updateEquipmentPackage('custom');
            },
          ),

          const SizedBox(height: 24),

          // Equipment Content based on selection
          if (state.selectedEquipmentPackage == 'custom')
            _buildCustomEquipmentSection(context, state, locale, theme, l10n)
          else
            _buildPresetEquipmentPreview(context, state, locale, theme, l10n),
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
                            ? theme.colorScheme.onPrimaryContainer
                                .withOpacity(0.8)
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
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Add button
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.selectedEquipment,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showItemCatalog(context, state, locale, l10n),
              icon: const Icon(Icons.add),
              label: Text(l10n.addItem),
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
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.noItemsSelected,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.tapToAddItems,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
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
                  '${item.getDescription(locale)} • ${l10n.itemQuantity}: $quantity',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    context
                        .read<CharacterCreationState>()
                        .removeCustomEquipment(itemId);
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
                    l10n.packageCustomDesc,
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
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.equipmentPreview(state.selectedClass!.getName(locale)),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        _buildEquipmentCategory(
          context,
          l10n.typeWeapon,
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
          l10n.typeArmor,
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
          l10n.toolsAndGear,
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
                    l10n.equipmentPreviewDisclaimer,
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
                    color: accentColor.withOpacity(0.15),
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

  void _showItemCatalog(BuildContext context, CharacterCreationState state,
      String locale, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ItemCatalogDialog(
        state: state,
        locale: locale,
        l10n: l10n,
        onAddItem: (String itemId) async {
          // Show quantity dialog
          final quantity =
              await _showQuantityDialog(context, itemId, locale, l10n);
          if (quantity != null && quantity > 0 && context.mounted) {
            // Add item with quantity
            state.addCustomEquipment(itemId, quantity: quantity);

            // Show feedback
            final item = ItemService.getItemById(itemId);
            if (item != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.itemAdded(item.getName(locale), quantity)),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<int?> _showQuantityDialog(BuildContext context, String itemId,
      String locale, AppLocalizations l10n) async {
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
                labelText: l10n.itemQuantity,
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
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(quantityController.text) ?? 1;
              if (qty > 0) {
                Navigator.pop(context, qty);
              }
            },
            child: Text(l10n.addItem),
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

  List<String> _getDefaultWeapons(
      String classId, String packageId, String locale) {
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
          'en': ['Shortsword', 'Dagger (2)', 'Thieves\'s Tools'],
          'ru': ['Короткий меч', 'Кинжал (2)', 'Воровские инструменты'],
        },
        'alternative': {
          'en': ['Rapier', 'Shortbow with 20 arrows', 'Thieves\'s Tools'],
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
        (locale == 'ru'
            ? ['Простое оружие', 'Резервное оружие']
            : ['Simple weapon', 'Backup weapon']);
  }

  List<String> _getDefaultArmor(
      String classId, String packageId, String locale) {
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
        (locale == 'ru'
            ? ['Лёгкая броня или без доспехов']
            : ['Light armor or no armor']);
  }

  List<String> _getDefaultTools(
      String classId, String packageId, String locale) {
    final isAlternative = packageId == 'alternative';

    final tools = {
      'paladin': {
        'standard': {
          'en': ['Explorer\'s Pack', 'Bedroll', 'Rations (10 days)'],
          'ru': [
            'Набор путешественника',
            'Спальный мешок',
            'Рационы (10 дней)'
          ],
        },
        'alternative': {
          'en': ['Priest\'s Pack', 'Prayer Book'],
          'ru': ['Набор священника', 'Молитвенник'],
        },
      },
      'fighter': {
        'standard': {
          'en': ['Explorer\'s Pack', 'Bedroll', 'Rations (10 days)'],
          'ru': [
            'Набор путешественника',
            'Спальный мешок',
            'Рационы (10 дней)'
          ],
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
          'ru': [
            'Набор путешественника',
            'Верёвка (50 футов)',
            'Охотничья ловушка'
          ],
        },
        'alternative': {
          'en': ['Dungeoneer\'s Pack', 'Rope (50 feet)', 'Grappling Hook'],
          'ru': ['Набор подземельщика', 'Верёвка (50 футов)', 'Крюк-кошка'],
        },
      },
    };

    final packageKey = isAlternative ? 'alternative' : 'standard';
    return tools[classId]?[packageKey]?[locale] ??
        (locale == 'ru'
            ? ['Набор приключенца', 'Верёвка', 'Факел (10)']
            : ['Adventurer\'s Pack', 'Rope', 'Torch (10)']);
  }
}

class _ItemCatalogDialog extends StatefulWidget {
  final CharacterCreationState state;
  final String locale;
  final AppLocalizations l10n;
  final Function(String) onAddItem;

  const _ItemCatalogDialog({
    required this.state,
    required this.locale,
    required this.l10n,
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
        return widget.l10n.typeWeapon;
      case ItemType.armor:
        return widget.l10n.typeArmor;
      case ItemType.gear:
        return widget.l10n.typeGear;
      case ItemType.consumable:
        return widget.l10n.typeConsumable;
      case ItemType.tool:
        return 'Инструменты';
      case ItemType.treasure:
        return 'Сокровища';
    }
  }

  void _showCreateCustomItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateCustomItemDialog(
        state: widget.state,
        locale: widget.locale,
        l10n: widget.l10n,
      ),
    );
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: Text(widget.l10n.itemCatalog,
                          style: theme.textTheme.headlineSmall)),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreateCustomItemDialog(context);
                    },
                    icon: const Icon(Icons.add),
                    label: Text(widget.l10n.createItem),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.l10n.searchItems,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          })
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(widget.l10n.filterAll),
                      selected: _selectedCategory == null,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = null),
                    ),
                  ),
                  ...ItemType.values.map((type) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(_getItemIcon(type), size: 18),
                          label: Text(_getCategoryName(type)),
                          selected: _selectedCategory == type,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = type),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      widget.l10n.foundItems(filteredItems.length,
                          widget.state.customEquipmentQuantities.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant))),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(widget.l10n.noItemsFound,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant))
                        ]))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = widget
                            .state.customEquipmentQuantities
                            .containsKey(item.id);
                        final quantity = isSelected
                            ? widget.state.customEquipmentQuantities[item.id] ??
                                1
                            : 0;
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
                                child: Icon(_getItemIcon(item.type),
                                    color: isSelected
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.primary)),
                            title: Text(item.getName(widget.locale),
                                style: TextStyle(
                                    color: isSelected
                                        ? theme.colorScheme.onPrimaryContainer
                                        : null)),
                            subtitle: Text(item.getDescription(widget.locale),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: isSelected
                                        ? theme.colorScheme.onPrimaryContainer
                                            .withOpacity(0.7)
                                        : null)),
                            trailing: Checkbox(
                                value: isSelected,
                                onChanged: (_) {
                                  if (isSelected) {
                                    setState(() => widget.state
                                        .removeCustomEquipment(item.id));
                                  } else {
                                    widget.onAddItem(item.id);
                                  }
                                }),
                            onTap: () {
                              if (isSelected) {
                                setState(() => widget.state
                                    .removeCustomEquipment(item.id));
                              } else {
                                widget.onAddItem(item.id);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                      top: BorderSide(
                          color: theme.colorScheme.outlineVariant, width: 1))),
              child: SafeArea(
                  top: false,
                  child: FilledButton(
                      onPressed: widget.state.customEquipmentQuantities.isEmpty
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(
                          '${widget.l10n.done} (${widget.state.customEquipmentQuantities.length})'))),
            ),
          ],
        );
      },
    );
  }
}

class _CreateCustomItemDialog extends StatefulWidget {
  final CharacterCreationState state;
  final String locale;
  final AppLocalizations l10n;

  const _CreateCustomItemDialog(
      {required this.state, required this.locale, required this.l10n});

  @override
  State<_CreateCustomItemDialog> createState() =>
      _CreateCustomItemDialogState();
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
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, allowMultiple: false);
      if (result != null && result.files.isNotEmpty) {
        setState(() => _imagePath = result.files.first.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.l10n.errorLoadingImage(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  String _getTypeName(ItemType type) {
    switch (type) {
      case ItemType.weapon:
        return widget.l10n.typeWeapon;
      case ItemType.armor:
        return widget.l10n.typeArmor;
      case ItemType.gear:
        return widget.l10n.typeGear;
      case ItemType.consumable:
        return widget.l10n.typeConsumable;
      case ItemType.tool:
        return 'Инструменты'; // TODO
      case ItemType.treasure:
        return 'Сокровища'; // TODO
    }
  }

  String _getRarityName(ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.common:
        return widget.l10n.rarityCommon;
      case ItemRarity.uncommon:
        return widget.l10n.rarityUncommon;
      case ItemRarity.rare:
        return widget.l10n.rarityRare;
      case ItemRarity.veryRare:
        return widget.l10n.rarityVeryRare;
      case ItemRarity.legendary:
        return widget.l10n.rarityLegendary;
      case ItemRarity.artifact:
        return widget.l10n.rarityArtifact;
    }
  }

  void _createItem() {
    if (!_formKey.currentState!.validate()) return;
    try {
      final name = _nameController.text.trim();
      final quantity = int.tryParse(_quantityController.text) ?? 1;
      final customItemId = 'custom_${const Uuid().v4()}';
      widget.state.addCustomEquipment(customItemId, quantity: quantity);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.l10n.itemAdded(name, quantity))));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.l10n.errorCreatingItem(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error));
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
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28))),
                child: Row(children: [
                  Icon(Icons.add_circle,
                      color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(widget.l10n.createCustomItem,
                          style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer))),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context))
                ])),
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
                                              color: theme.colorScheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color:
                                                      theme.colorScheme.outline,
                                                  width: 2)),
                                          child: _imagePath != null
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Image.file(
                                                      File(_imagePath!),
                                                      fit: BoxFit.cover))
                                              : Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                      Icon(
                                                          Icons
                                                              .add_photo_alternate,
                                                          size: 40,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurfaceVariant),
                                                      const SizedBox(height: 8),
                                                      Text(widget.l10n.addImage,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: theme.textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                  color: theme
                                                                      .colorScheme
                                                                      .onSurfaceVariant))
                                                    ])))),
                              const SizedBox(height: 24),
                              TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                      labelText: widget.l10n.itemName,
                                      hintText: widget.l10n.itemNameHint,
                                      border: const OutlineInputBorder()),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? widget.l10n.enterItemName
                                          : null),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _descController,
                                  decoration: InputDecoration(
                                      labelText: widget.l10n.itemDescription,
                                      hintText: widget.l10n.itemDescriptionHint,
                                      border: const OutlineInputBorder()),
                                  maxLines: 3),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<ItemType>(
                                  initialValue: _selectedType,
                                  decoration: InputDecoration(
                                      labelText: widget.l10n.itemType,
                                      border: const OutlineInputBorder()),
                                  items: ItemType.values
                                      .map((type) => DropdownMenuItem(
                                          value: type,
                                          child: Text(_getTypeName(type))))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedType = value);
                                    }
                                  }),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<ItemRarity>(
                                  initialValue: _selectedRarity,
                                  decoration: InputDecoration(
                                      labelText: widget.l10n.itemRarity,
                                      border: const OutlineInputBorder()),
                                  items: ItemRarity.values
                                      .map((rarity) => DropdownMenuItem(
                                          value: rarity,
                                          child: Text(_getRarityName(rarity))))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedRarity = value);
                                    }
                                  }),
                              const SizedBox(height: 16),
                              Row(children: [
                                Expanded(
                                    child: TextFormField(
                                        controller: _weightController,
                                        decoration: InputDecoration(
                                            labelText:
                                                '${widget.l10n.itemWeight} (${widget.l10n.weightUnit})',
                                            border: const OutlineInputBorder()),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true))),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: TextFormField(
                                        controller: _valueController,
                                        decoration: InputDecoration(
                                            labelText:
                                                '${widget.l10n.itemValue} (cp)',
                                            border: const OutlineInputBorder()),
                                        keyboardType: TextInputType.number))
                              ]),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _quantityController,
                                  decoration: InputDecoration(
                                      labelText: widget.l10n.itemQuantity,
                                      border: const OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    final qty = int.tryParse(value ?? '');
                                    return qty == null || qty < 1
                                        ? widget.l10n.minQuantity1
                                        : null;
                                  }),
                            ])))),
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                            width: 1))),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(widget.l10n.cancel)),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                      onPressed: _createItem,
                      icon: const Icon(Icons.check),
                      label: Text(widget.l10n.createItem))
                ])),
          ],
        ),
      ),
    );
  }
}
