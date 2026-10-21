import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/item.dart';
import '../../core/services/inventory_actions_service.dart';
import '../../core/ui/app_menu_style.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/utils/item_utils.dart';
import '../../l10n/app_localizations.dart';
import 'inventory_presentation.dart';
import 'widgets/inventory_item_tile.dart';

class CreateItemScreen extends StatefulWidget {
  const CreateItemScreen({super.key, this.initialName, this.initialItem});
  final String? initialName;
  final Item? initialItem;
  @override
  State<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends State<CreateItemScreen> {
  final form = GlobalKey<FormState>();
  late final Item draft;
  late final TextEditingController name,
      description,
      weight,
      value,
      quantity,
      damage,
      versatile,
      range,
      longRange,
      ac,
      maxDex,
      strength;
  ItemType type = ItemType.gear;
  ItemRarity rarity = ItemRarity.common;
  DamageType damageType = DamageType.slashing;
  ArmorType armorType = ArmorType.light;
  bool magical = false, attunement = false, dex = true, stealth = false;
  String currency = 'GP';
  final tags = <String>{};
  @override
  void initState() {
    super.initState();
    draft = widget.initialItem == null
        ? Item(
            id: const Uuid().v4(),
            nameEn: '',
            nameRu: '',
            descriptionEn: '',
            descriptionRu: '',
            type: ItemType.gear,
            rarity: ItemRarity.common)
        : InventoryActionsService.clone(widget.initialItem!);
    type = draft.type;
    rarity = draft.rarity;
    magical = draft.isMagical;
    attunement = draft.requiresAttunement;
    final w = draft.weaponProperties, a = draft.armorProperties;
    damageType = w?.damageType ?? DamageType.slashing;
    armorType = a?.armorType ?? ArmorType.light;
    dex = a?.addDexModifier ?? true;
    stealth = a?.stealthDisadvantage ?? false;
    tags.addAll(w?.weaponTags ?? []);
    name = TextEditingController(
        text: widget.initialName ??
            (draft.nameRu.isNotEmpty ? draft.nameRu : draft.nameEn));
    description = TextEditingController(
        text: draft.descriptionRu.isNotEmpty
            ? draft.descriptionRu
            : draft.descriptionEn);
    weight = TextEditingController(text: compactNumber(draft.weight));
    value = TextEditingController(text: goldValue(draft.valueInCopper));
    quantity = TextEditingController(text: '${draft.quantity}');
    damage = TextEditingController(text: w?.damageDice ?? '1d6');
    versatile = TextEditingController(text: w?.versatileDamageDice ?? '');
    range = TextEditingController(text: w?.range?.toString() ?? '');
    longRange = TextEditingController(text: w?.longRange?.toString() ?? '');
    ac = TextEditingController(text: '${a?.baseAC ?? 10}');
    maxDex = TextEditingController(text: a?.maxDexBonus?.toString() ?? '');
    strength =
        TextEditingController(text: a?.strengthRequirement?.toString() ?? '');
    name.addListener(refresh);
    damage.addListener(refresh);
    ac.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final v in [
      name,
      description,
      weight,
      value,
      quantity,
      damage,
      versatile,
      range,
      longRange,
      ac,
      maxDex,
      strength
    ]) {
      v.dispose();
    }
    super.dispose();
  }

  String? number(String? v, {bool decimal = false, bool optional = false}) {
    if (optional && (v?.trim().isEmpty ?? true)) return null;
    final n = decimal
        ? double.tryParse((v ?? '').replaceAll(',', '.'))
        : int.tryParse(v ?? '');
    return n == null || !n.isFinite || n < 0
        ? inventoryText(
            context, 'Введи число от нуля', 'Enter a number of zero or more')
        : null;
  }

  Item preview() => Item(
      id: draft.id,
      nameEn: name.text.trim().isEmpty
          ? AppLocalizations.of(context)!.itemName
          : name.text.trim(),
      nameRu: name.text.trim().isEmpty
          ? AppLocalizations.of(context)!.itemName
          : name.text.trim(),
      descriptionEn: description.text,
      descriptionRu: description.text,
      type: type,
      rarity: rarity,
      isMagical: magical,
      requiresAttunement: magical && attunement,
      weaponProperties: type == ItemType.weapon
          ? WeaponProperties(damageDice: damage.text, damageType: damageType)
          : null,
      armorProperties: type == ItemType.armor
          ? ArmorProperties(
              baseAC: int.tryParse(ac.text) ?? 10, armorType: armorType)
          : null);
  void save() {
    if (!form.currentState!.validate()) return;
    final result = InventoryActionsService.clone(draft);
    // Editing a book item creates a personal definition, never changes the book.
    if (widget.initialItem != null && draft.sourceId != null) {
      result.id = const Uuid().v4();
      result.sourceId = null;
    }
    result.nameEn = name.text.trim();
    result.nameRu = name.text.trim();
    result.descriptionEn = description.text.trim();
    result.descriptionRu = description.text.trim();
    result.type = type;
    result.rarity = rarity;
    result.isMagical = magical;
    result.requiresAttunement = magical && attunement;
    result.quantity = int.parse(quantity.text.trim());
    result.weight = double.parse(weight.text.replaceAll(',', '.'));
    result.valueInCopper = itemValueInCopper(value.text, currency);
    result.weaponProperties = type == ItemType.weapon
        ? WeaponProperties(
            damageDice: damage.text.trim(),
            damageType: damageType,
            weaponTags: tags.toList(),
            versatileDamageDice:
                versatile.text.trim().isEmpty ? null : versatile.text.trim(),
            range: int.tryParse(range.text),
            longRange: int.tryParse(longRange.text))
        : null;
    result.armorProperties = type == ItemType.armor
        ? ArmorProperties(
            baseAC: int.parse(ac.text),
            armorType: armorType,
            addDexModifier: armorType == ArmorType.shield ? false : dex,
            maxDexBonus: dex ? int.tryParse(maxDex.text) : null,
            strengthRequirement: int.tryParse(strength.text),
            stealthDisadvantage: stealth)
        : null;
    HapticFeedback.selectionClick();
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context),
        c = t.colorScheme,
        l = AppLocalizations.of(context)!;
    Widget section(String title, String subtitle, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: CompanionSurface(
            quiet: true,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title,
                      style: t.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800, letterSpacing: -.4)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: c.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  child
                ])));
    Widget field(TextEditingController controller, String label,
            {bool decimal = false, bool optional = false}) =>
        TextFormField(
            controller: controller,
            autofocus: false,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            decoration: InputDecoration(labelText: label),
            validator: (v) => number(v, decimal: decimal, optional: optional));
    Widget pair(Widget a, Widget b) => LayoutBuilder(
        builder: (context, bounds) => bounds.maxWidth < 260 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? Column(children: [a, const SizedBox(height: 16), b])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: a),
                const SizedBox(width: 14),
                Expanded(child: b)
              ]));
    String? dice(String? v, {bool optional = false}) {
      if (optional && (v?.trim().isEmpty ?? true)) return null;
      return RegExp(r'^\d+[dDкК]\d+(\s*[+-]\s*\d+)?$').hasMatch(v?.trim() ?? '')
          ? null
          : inventoryText(context, 'Например, 1к8 или 1d8', 'For example, 1d8');
    }

    return Scaffold(
        appBar: AppBar(title: Text(l.forgeTitle), actions: [
          Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(onPressed: save, child: Text(l.save)))
        ]),
        body: Form(
            key: form,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  CompanionSurface(
                      raised: true,
                      contour: CompanionContour.focus,
                      color: c.tertiaryContainer,
                      child: Row(children: [
                        InventoryItemGlyph(item: preview(), size: 62),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  inventoryText(context, 'Твоя находка',
                                      'Your discovery'),
                                  style: t.textTheme.labelMedium),
                              const SizedBox(height: 6),
                              Text(
                                  preview().getName(
                                      Localizations.localeOf(context)
                                          .languageCode),
                                  style: t.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.6)),
                              const SizedBox(height: 7),
                              Text(itemSummary(context, preview()),
                                  style: t.textTheme.bodySmall)
                            ]))
                      ])),
                  const SizedBox(height: 24),
                  section(
                      inventoryText(context, 'Замысел', 'The idea'),
                      inventoryText(context, 'Дай вещи имя и историю.',
                          'Give this item a name and a story.'),
                      Column(children: [
                        TextFormField(
                            controller: name,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(labelText: l.itemName),
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? inventoryText(
                                    context, 'Укажи название', 'Enter a name')
                                : null),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: description,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 3,
                            maxLines: 8,
                            decoration: InputDecoration(
                                labelText: l.itemDescription,
                                alignLabelWithHint: true)),
                      ])),
                  section(
                      inventoryText(
                          context, 'Характер предмета', 'The item’s character'),
                      inventoryText(
                          context,
                          'Тип определяет доступные свойства.',
                          'The type determines the available properties.'),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(spacing: 7, runSpacing: 6, children: [
                              for (final v in ItemType.values)
                                ChoiceChip(
                                    label: Text(itemTypeName(context, v)),
                                    selected: type == v,
                                    onSelected: (_) => setState(() => type = v))
                            ]),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<ItemRarity>(
                                initialValue: rarity,
                                isExpanded: true,
                                borderRadius: AppMenuStyle.radius,
                                decoration: InputDecoration(
                                    labelText: inventoryText(
                                        context, 'Редкость', 'Rarity')),
                                items: [
                                  for (final v in ItemRarity.values)
                                    DropdownMenuItem(
                                        value: v,
                                        child: Text(
                                            ItemUtils.getLocalizedRarityName(
                                                l, v)))
                                ],
                                onChanged: (v) => setState(() => rarity = v!)),
                            const SizedBox(height: 12),
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(inventoryText(context,
                                    'Магический предмет', 'Magical item')),
                                value: magical,
                                onChanged: (v) => setState(() => magical = v)),
                            if (magical)
                              SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(l.requiresAttunement),
                                  value: attunement,
                                  onChanged: (v) =>
                                      setState(() => attunement = v)),
                          ])),
                  if (type == ItemType.weapon)
                    section(
                        l.weaponProperties,
                        inventoryText(
                            context,
                            'Урон, дистанция и способы применения.',
                            'Damage, range and ways to wield it.'),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              pair(
                                  TextFormField(
                                      controller: damage,
                                      decoration:
                                          InputDecoration(labelText: l.damage),
                                      validator: dice),
                                  DropdownButtonFormField<DamageType>(
                                      initialValue: damageType,
                                      isExpanded: true,
                                      borderRadius: AppMenuStyle.radius,
                                      decoration: InputDecoration(
                                          labelText: l.damageType),
                                      items: [
                                        for (final v in DamageType.values)
                                          DropdownMenuItem(
                                              value: v,
                                              child: Text(ItemUtils
                                                  .getLocalizedDamageType(
                                                      l, v.toString())))
                                      ],
                                      onChanged: (v) =>
                                          setState(() => damageType = v!))),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: versatile,
                                  decoration: InputDecoration(
                                      labelText: l.versatileDamage),
                                  validator: (v) => dice(v, optional: true)),
                              const SizedBox(height: 16),
                              pair(
                                  field(
                                      range,
                                      inventoryText(context, 'Дистанция, фт',
                                          'Range, ft'),
                                      optional: true),
                                  field(
                                      longRange,
                                      inventoryText(context, 'Дальняя, фт',
                                          'Long range, ft'),
                                      optional: true)),
                              const SizedBox(height: 18),
                              Wrap(spacing: 6, runSpacing: 6, children: [
                                for (final v in {
                                  'ammunition',
                                  'finesse',
                                  'heavy',
                                  'light',
                                  'loading',
                                  'reach',
                                  'thrown',
                                  'two-handed',
                                  'versatile',
                                  ...tags
                                })
                                  FilterChip(
                                      label:
                                          Text(ItemUtils.getLocalizedTag(l, v)),
                                      selected: tags.contains(v),
                                      onSelected: (on) => setState(() {
                                            if (on) {
                                              tags.add(v);
                                            } else {
                                              tags.remove(v);
                                            }
                                          }))
                              ]),
                            ])),
                  if (type == ItemType.armor)
                    section(
                        l.armorProperties,
                        inventoryText(
                            context,
                            'Защита с учётом Ловкости и ограничений.',
                            'Protection, Dexterity and restrictions.'),
                        Column(children: [
                          pair(
                              field(ac, l.armorClassAC),
                              DropdownButtonFormField<ArmorType>(
                                  initialValue: armorType,
                                  isExpanded: true,
                                  borderRadius: AppMenuStyle.radius,
                                  decoration:
                                      InputDecoration(labelText: l.type),
                                  items: [
                                    for (final v in ArmorType.values)
                                      DropdownMenuItem(
                                          value: v,
                                          child: Text(
                                              ItemUtils.getLocalizedArmorType(
                                                  l, v.toString())))
                                  ],
                                  onChanged: (v) =>
                                      setState(() => armorType = v!))),
                          const SizedBox(height: 16),
                          if (armorType != ArmorType.shield) ...[
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(inventoryText(
                                    context,
                                    'Добавлять Ловкость',
                                    'Add Dexterity modifier')),
                                value: dex,
                                onChanged: (v) => setState(() => dex = v)),
                            if (dex)
                              field(
                                  maxDex,
                                  inventoryText(
                                      context,
                                      'Максимальный бонус Ловкости',
                                      'Maximum Dexterity bonus'),
                                  optional: true),
                            const SizedBox(height: 16),
                            field(strength, l.strRequirement, optional: true),
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(inventoryText(
                                    context,
                                    'Помеха Скрытности',
                                    'Disadvantage on Stealth')),
                                value: stealth,
                                onChanged: (v) => setState(() => stealth = v))
                          ],
                        ])),
                  section(
                      inventoryText(context, 'В рюкзак', 'In the pack'),
                      inventoryText(
                          context,
                          'Количество, вес и цена одной вещи.',
                          'Quantity, weight and the value of one item.'),
                      Column(children: [
                        pair(
                            field(quantity, l.quantity),
                            field(weight, '${l.weight}, ${l.weightUnit}',
                                decimal: true)),
                        const SizedBox(height: 16),
                        pair(
                            TextFormField(
                                controller: value,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(labelText: l.value),
                                validator: (v) {
                                  try {
                                    itemValueInCopper(v ?? '', currency);
                                    return null;
                                  } on FormatException {
                                    return inventoryText(
                                        context,
                                        'Цена от нуля, кратная медной монете',
                                        'A nonnegative price in whole copper pieces');
                                  }
                                }),
                            DropdownButtonFormField<String>(
                                initialValue: currency,
                                borderRadius: AppMenuStyle.radius,
                                decoration:
                                    InputDecoration(labelText: l.currency),
                                items: [
                                  for (final e in {
                                    'GP': l.currencyGP_short,
                                    'SP': l.currencySP_short,
                                    'CP': l.currencyCP_short,
                                    'PP': l.currencyPP_short
                                  }.entries)
                                    DropdownMenuItem(
                                        value: e.key, child: Text(e.value))
                                ],
                                onChanged: (v) =>
                                    setState(() => currency = v!))),
                      ])),
                  FilledButton.icon(
                      onPressed: save,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(widget.initialItem == null
                          ? inventoryText(
                              context, 'Создать предмет', 'Create item')
                          : l.save)),
                ])));
  }
}
