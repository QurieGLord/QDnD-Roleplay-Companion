import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/item.dart';
import '../../core/utils/item_utils.dart';
import '../../shared/widgets/item_details_sheet.dart';

class CreateItemScreen extends StatefulWidget {
  final String? initialName;

  const CreateItemScreen({
    super.key,
    this.initialName,
  });

  @override
  State<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends State<CreateItemScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _weightController = TextEditingController(text: '0');
  final _valueController = TextEditingController(text: '0');
  final _quantityController = TextEditingController(text: '1');

  // Weapon/Armor specific
  final _damageDiceController = TextEditingController(text: '1d6');
  final _acController = TextEditingController(text: '10');

  // State
  String _selectedIcon = 'gear'; // Default icon key
  ItemType _selectedType = ItemType.gear;
  ItemRarity _selectedRarity = ItemRarity.common;
  String _selectedCurrency = 'GP';
  bool _isMagical = false;
  bool _requiresAttunement = false;
  DamageType _selectedDamageType = DamageType.slashing;
  ArmorType _selectedArmorType = ArmorType.light;
  bool _stealthDisadvantage = false;
  bool _addDexModifier = true; // For armor

  // Available Icons matching ItemUtils + Extras
  final Map<String, IconData> _availableIcons = {
    'weapon': Icons.gavel,
    'armor': Icons.shield,
    'gear': Icons.backpack,
    'consumable': Icons.local_drink,
    'tool': Icons.build,
    'treasure': Icons.diamond,
    'sword': Icons.pages,
    'scroll': Icons.menu_book,
    'food': Icons.restaurant,
    'gold': Icons.monetization_on,
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    _nameController.addListener(_updateState);
    _descController.addListener(_updateState);
    _weightController.addListener(_updateState);
    _valueController.addListener(_updateState);
    _quantityController.addListener(_updateState);
    _damageDiceController.addListener(_updateState);
    _acController.addListener(_updateState);
  }

  void _updateState() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _weightController.dispose();
    _valueController.dispose();
    _quantityController.dispose();
    _damageDiceController.dispose();
    _acController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(l10n.forgeTitle),
            centerTitle: true,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                onPressed:
                    _nameController.text.trim().isNotEmpty ? _saveItem : null,
              ),
            ],
          ),

          // Live Preview Section
          SliverToBoxAdapter(
            child: _buildLivePreview(theme, l10n),
          ),

          // Form Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Identity Section
                    _buildSectionHeader(theme, l10n.identitySection),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.itemName,
                        hintText: l10n.itemExample,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.edit),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      decoration: InputDecoration(
                        labelText: l10n.itemDescription,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 70,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _availableIcons.entries.map((entry) {
                          final isSelected = _selectedIcon == entry.key;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedIcon = entry.key),
                            child: Container(
                              width: 60,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 2)
                                    : null,
                              ),
                              child: Icon(
                                entry.value,
                                color: isSelected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Characteristics Section
                    _buildSectionHeader(theme, l10n.characteristicsSection),
                    const SizedBox(height: 16),
                    Text(l10n.itemType, style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ItemType.values.map((type) {
                        return ChoiceChip(
                          label:
                              Text(ItemUtils.getLocalizedTypeName(l10n, type)),
                          selected: _selectedType == type,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedType = type);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.itemRarity, style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ItemRarity.values.map((rarity) {
                        return ChoiceChip(
                          label: Text(
                            ItemUtils.getLocalizedRarityName(l10n, rarity),
                            style: TextStyle(
                              color: _selectedRarity == rarity
                                  ? Colors.white
                                  : null,
                            ),
                          ),
                          selected: _selectedRarity == rarity,
                          selectedColor: _getRarityColor(rarity),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedRarity = rarity);
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),

                    // Stats Section
                    _buildSectionHeader(theme, l10n.statsSection),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: l10n.itemWeight,
                              suffixText: l10n.weightUnit,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.quantity,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              prefixIcon: IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () {
                                  int current =
                                      int.tryParse(_quantityController.text) ??
                                          1;
                                  if (current > 1) {
                                    _quantityController.text =
                                        (current - 1).toString();
                                  }
                                },
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  int current =
                                      int.tryParse(_quantityController.text) ??
                                          1;
                                  _quantityController.text =
                                      (current + 1).toString();
                                },
                              ),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _valueController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.itemValue,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedCurrency,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            items: [
                              l10n.currencyGP_short.toUpperCase(),
                              l10n.currencySP_short.toUpperCase(),
                              l10n.currencyCP_short.toUpperCase(),
                              l10n.currencyPP_short.toUpperCase()
                            ]
                                .map((c) =>
                                    DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCurrency = v!),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Magic & Properties
                    _buildSectionHeader(theme, l10n.magicPropertiesSection),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text(l10n.isMagical),
                      value: _isMagical,
                      onChanged: (v) => setState(() => _isMagical = v),
                      secondary: Icon(Icons.auto_fix_high,
                          color: _isMagical ? theme.colorScheme.primary : null),
                      activeThumbColor: theme.colorScheme.primary,
                    ),
                    SwitchListTile(
                      title: Text(l10n.requiresAttunement),
                      value: _requiresAttunement,
                      onChanged: (v) => setState(() => _requiresAttunement = v),
                      secondary: Icon(Icons.link,
                          color: _requiresAttunement
                              ? theme.colorScheme.primary
                              : null),
                      activeThumbColor: theme.colorScheme.primary,
                    ),

                    // Dynamic Fields: Weapon
                    if (_selectedType == ItemType.weapon) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(l10n.weaponStats,
                            style: theme.textTheme.titleMedium),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _damageDiceController,
                              decoration: InputDecoration(
                                labelText: l10n.damageDice,
                                hintText: l10n.damageDiceHint,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<DamageType>(
                              initialValue: _selectedDamageType,
                              decoration: InputDecoration(
                                labelText: l10n.damageType,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              isExpanded: true,
                              items: DamageType.values
                                  .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(
                                          ItemUtils.getLocalizedDamageType(
                                              l10n, t.toString()))))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedDamageType = v!),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Dynamic Fields: Armor
                    if (_selectedType == ItemType.armor) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(l10n.armorStats,
                            style: theme.textTheme.titleMedium),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _acController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '${l10n.armorClass} (AC)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<ArmorType>(
                              initialValue: _selectedArmorType,
                              decoration: InputDecoration(
                                labelText: l10n.type,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              items: ArmorType.values
                                  .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(
                                          ItemUtils.getLocalizedArmorType(
                                              l10n, t.toString()))))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedArmorType = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: Text(l10n.addDexModifier),
                        value: _addDexModifier,
                        onChanged: (v) => setState(() => _addDexModifier = v),
                        activeThumbColor: theme.colorScheme.primary,
                      ),
                      SwitchListTile(
                        title: Text(l10n.stealthDisadvantage),
                        value: _stealthDisadvantage,
                        onChanged: (v) =>
                            setState(() => _stealthDisadvantage = v),
                        activeThumbColor: theme.colorScheme.primary,
                      ),
                    ],

                    const SizedBox(height: 80), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview(ThemeData theme, AppLocalizations l10n) {
    // Calculate value in copper for preview
    int val = int.tryParse(_valueController.text) ?? 0;
    int multiplier = 1; // CP
    if (_selectedCurrency == l10n.currencySP_short.toUpperCase()) {
      multiplier = 10;
    }
    if (_selectedCurrency == l10n.currencyGP_short.toUpperCase()) {
      multiplier = 100;
    }
    if (_selectedCurrency == l10n.currencyPP_short.toUpperCase()) {
      multiplier = 1000;
    }
    int valueInCopper = val * multiplier;

    // Construct a temporary item for preview
    final previewItem = Item(
      id: 'preview',
      nameEn:
          _nameController.text.isEmpty ? l10n.itemName : _nameController.text,
      nameRu:
          _nameController.text.isEmpty ? l10n.itemName : _nameController.text,
      descriptionEn: _descController.text,
      descriptionRu: _descController.text,
      type: _selectedType,
      rarity: _selectedRarity,
      weight: double.tryParse(_weightController.text) ?? 0,
      quantity: int.tryParse(_quantityController.text) ?? 1,
      valueInCopper: valueInCopper,
      isMagical: _isMagical,
      isAttuned: false,
      // Create properties if needed
      weaponProperties: _selectedType == ItemType.weapon
          ? WeaponProperties(
              damageDice: _damageDiceController.text,
              damageType: _selectedDamageType)
          : null,
      armorProperties: _selectedType == ItemType.armor
          ? ArmorProperties(
              baseAC: int.tryParse(_acController.text) ?? 10,
              armorType: _selectedArmorType)
          : null,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.3, 1.0],
          colors: [
            theme.scaffoldBackgroundColor,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ItemDetailsContent(item: previewItem),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Row(
      children: [
        Container(
            width: 4,
            height: 16,
            color: theme.colorScheme.primary,
            margin: const EdgeInsets.only(right: 8)),
        Text(
          title.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Color _getRarityColor(ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.common:
        return Colors.grey;
      case ItemRarity.uncommon:
        return Colors.green;
      case ItemRarity.rare:
        return Colors.blue;
      case ItemRarity.veryRare:
        return Colors.purple;
      case ItemRarity.legendary:
        return Colors.orange;
      case ItemRarity.artifact:
        return Colors.red;
    }
  }

  void _saveItem() {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;

    // Calculate value in copper
    int val = int.tryParse(_valueController.text) ?? 0;
    int multiplier = 1; // CP
    if (_selectedCurrency == l10n.currencySP_short.toUpperCase()) {
      multiplier = 10;
    }
    if (_selectedCurrency == l10n.currencyGP_short.toUpperCase()) {
      multiplier = 100;
    }
    if (_selectedCurrency == l10n.currencyPP_short.toUpperCase()) {
      multiplier = 1000;
    }
    int valueInCopper = val * multiplier;

    final item = Item(
      id: const Uuid().v4(),
      nameEn: _nameController.text.trim(),
      nameRu: _nameController.text.trim(),
      descriptionEn: _descController.text.trim(),
      descriptionRu: _descController.text.trim(),
      type: _selectedType,
      rarity: _selectedRarity,
      weight: double.tryParse(_weightController.text) ?? 0.0,
      quantity: int.tryParse(_quantityController.text) ?? 1,
      valueInCopper: valueInCopper,
      isMagical: _isMagical,
      isAttuned: false,
      iconName: _selectedIcon,

      // Weapon Props
      weaponProperties: _selectedType == ItemType.weapon
          ? WeaponProperties(
              damageDice: _damageDiceController.text,
              damageType: _selectedDamageType,
              weaponTags: [],
            )
          : null,

      // Armor Props
      armorProperties: _selectedType == ItemType.armor
          ? ArmorProperties(
              baseAC: int.tryParse(_acController.text) ?? 10,
              armorType: _selectedArmorType,
              addDexModifier: _addDexModifier,
              stealthDisadvantage: _stealthDisadvantage,
            )
          : null,
    );

    Navigator.pop(context, item);
  }
}
