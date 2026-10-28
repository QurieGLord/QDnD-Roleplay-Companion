import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/content/item_references.dart';
import '../../core/models/character.dart';
import '../../core/models/item.dart';
import '../../core/services/inventory_actions_service.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/ui/page_kit.dart';
import '../../shared/widgets/content_variant_picker.dart' show contentSourceName;
import '../../core/ui/sheet_drag_region.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/item_details_sheet.dart';
import 'inventory_presentation.dart';
import 'create_item_screen.dart';
import 'widgets/inventory_item_tile.dart';

Future<bool?> showInventoryQuantity(
    BuildContext context, Character hero, Item item,
    {bool split = false}) {
  final target = InventoryTarget(item), expected = item.quantity;
  return showResponsiveSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NumberSheet(
          title: split
              ? inventoryText(context, 'Разделить стопку', 'Split stack')
              : AppLocalizations.of(context)!.quantity,
          subtitle: item.getName(Localizations.localeOf(context).languageCode),
          initial: split ? 1 : item.quantity,
          maximum: split ? item.quantity - 1 : null,
          minimum: split ? 1 : 0,
          save: (n) => split
              ? InventoryActionsService.split(hero, target, n)
              : InventoryActionsService.quantity(hero, target, n,
                  expected: expected)));
}

Future<bool?> showInventoryWallet(BuildContext context, Character hero) =>
    showResponsiveSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _WalletSheet(hero));
Future<bool> confirmInventoryRemoval(BuildContext context, Item item) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) {
          final l = AppLocalizations.of(context)!;
          return AlertDialog(
              title: Text(l.remove),
              content: Text(l.deleteItemConfirmation(
                  item.getName(Localizations.localeOf(context).languageCode))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.cancel)),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l.remove))
              ]);
        }) ??
    false;
Future<bool> setInventoryAttunement(
    BuildContext context, Character hero, Item item) async {
  final target = InventoryTarget(item);
  try {
    await InventoryActionsService.attune(hero, target, !item.isAttuned);
    return true;
  } on AttunementLimit {
    if (!context.mounted) return false;
    final allow = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(inventoryText(context, 'Больше трёх настроек',
                    'More than three attunements')),
                content: Text(inventoryText(
                    context,
                    'Обычно герой может настроиться на три предмета. Добавить ещё один по разрешению мастера?',
                    'A character normally attunes to three items. Add another with your DM’s permission?')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(AppLocalizations.of(context)!.cancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(inventoryText(
                          context, 'Добавить настройку', 'Attune anyway')))
                ]));
    if (allow == true) {
      await InventoryActionsService.attune(hero, target, true,
          allowBeyondLimit: true);
      return true;
    }
    return false;
  }
}

Future<bool?> showOwnedInventoryItem(
        BuildContext context, Character hero, Item item,
        {required VoidCallback onChanged}) =>
    showResponsiveSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _OwnedItemSheet(hero, item, onChanged));

/// The owned item's sheet content, for hosts that open it themselves.
Widget ownedInventoryItemSheet(Character hero, Item item,
        {required VoidCallback onChanged}) =>
    _OwnedItemSheet(hero, item, onChanged);

class _OwnedItemSheet extends StatefulWidget {
  const _OwnedItemSheet(this.hero, this.item, this.onChanged);
  final Character hero;
  final Item item;
  final VoidCallback onChanged;
  @override
  State<_OwnedItemSheet> createState() => _OwnedItemSheetState();
}

class _OwnedItemSheetState extends State<_OwnedItemSheet> {
  late Item item = widget.item;
  bool busy = false;
  String? issue;
  Future<void> act(Future<bool> Function() action,
      {bool removed = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      issue = null;
    });
    try {
      final target = InventoryTarget(item);
      final index = target.locate(widget.hero.inventory);
      final changed = await action();
      if (!mounted) return;
      if (changed) {
        widget.onChanged();
        HapticFeedback.selectionClick();
        if (removed) {
          Navigator.pop(context, true);
          return;
        }
        if (index >= 0 && index < widget.hero.inventory.length) {
          final owned = target.instanceId == null
              ? index
              : widget.hero.inventory
                  .indexWhere((i) => i.instanceId == target.instanceId);
          if (owned >= 0) item = widget.hero.inventory[owned];
        }
      }
      setState(() => busy = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          issue = inventoryText(
              context,
              'Не удалось сохранить. Лист мог измениться — закрой карточку и попробуй снова.',
              'Could not save. The sheet may have changed — reopen this item and try again.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return PopScope(
        canPop: !busy,
        child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // C02 · a newer book version is offered, never applied
                  // behind the player's back.
                  Builder(builder: (context) {
                    final update = ItemReferences.bookUpdate(item);
                    return PageReveal(
                        open: update != null,
                        child: update == null
                            ? const SizedBox(width: double.infinity)
                            : _BookUpdateNotice(
                                item: item,
                                update: update,
                                busy: busy,
                                onUpdate: () => act(() async {
                                      await InventoryActionsService
                                          .adoptBookVersion(widget.hero,
                                              InventoryTarget(item), update,
                                              expected:
                                                  InventoryActionsService.clone(
                                                      item));
                                      return true;
                                    })));
                  }),
                  IgnorePointer(
                      ignoring: busy,
                      child: ItemDetailsContent(
                        item: item,
                        onEquip: () => act(() async {
                          await InventoryActionsService.equip(widget.hero,
                              InventoryTarget(item), !item.isEquipped);
                          return true;
                        }),
                        onRemove: () => act(() async {
                          if (!await confirmInventoryRemoval(context, item)) {
                            return false;
                          }
                          await InventoryActionsService.remove(
                              widget.hero, InventoryTarget(item));
                          return true;
                        }, removed: true),
                        onEditQuantity: () => act(() async =>
                            await showInventoryQuantity(
                                context, widget.hero, item) ==
                            true),
                        onAttuneToggle: item.isMagical ||
                                item.isAttuned ||
                                item.requiresAttunement
                            ? (_) => act(() => setInventoryAttunement(
                                context, widget.hero, item))
                            : null,
                      )),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextButton.icon(
                          onPressed: busy
                              ? null
                              : () => act(() async {
                                    final expected =
                                            InventoryActionsService.clone(item),
                                        target = InventoryTarget(item);
                                    final result = await Navigator.push<Item>(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => CreateItemScreen(
                                                initialItem: item)));
                                    if (result == null) return false;
                                    await InventoryActionsService.revise(
                                        widget.hero, target, result,
                                        expected: expected);
                                    return true;
                                  }),
                          icon: const Icon(Icons.build_outlined),
                          label: Text(inventoryText(context,
                              'Изменить в Кузнице', 'Edit in the Forge')))),
                  if (!item.isEquipped &&
                      item.armorProperties != null &&
                      widget.hero.inventory.any((i) =>
                          i.isEquipped &&
                          i.armorProperties != null &&
                          (i.armorProperties!.armorType == ArmorType.shield) ==
                              (item.armorProperties!.armorType ==
                                  ArmorType.shield)))
                    Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Text(
                            inventoryText(
                                context,
                                'При экипировке заменит текущий ${item.armorProperties!.armorType == ArmorType.shield ? 'щит' : 'доспех'}.',
                                'Equipping this replaces your current ${item.armorProperties!.armorType == ArmorType.shield ? 'shield' : 'armor'}.'),
                            style: t.textTheme.bodySmall)),
                  if (issue != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(issue!,
                            style: t.textTheme.bodyMedium
                                ?.copyWith(color: t.colorScheme.error))),
                  if (item.quantity > 0 && item.type == ItemType.consumable)
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: FilledButton.tonalIcon(
                            onPressed: busy
                                ? null
                                : () => act(() async {
                                      await InventoryActionsService.consume(
                                          widget.hero, InventoryTarget(item));
                                      return true;
                                    }),
                            icon: const Icon(Icons.local_drink_outlined),
                            label: Text(inventoryText(
                                context, 'Использовать один', 'Use one')))),
                  if (item.quantity > 1)
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => act(() async =>
                                    await showInventoryQuantity(
                                        context, widget.hero, item,
                                        split: true) ==
                                    true),
                            icon: const Icon(Icons.call_split_rounded),
                            label: Text(inventoryText(
                                context, 'Разделить стопку', 'Split stack')))),
                  if (busy)
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator()),
                ])));
  }
}

/// «В книге новая версия»: what changed, from which book, and one tap to
/// take it. The stack's quantity, equipment and attunement stay.
class _BookUpdateNotice extends StatelessWidget {
  const _BookUpdateNotice(
      {required this.item,
      required this.update,
      required this.busy,
      required this.onUpdate});
  final Item item, update;
  final bool busy;
  final VoidCallback onUpdate;

  static String _field(BuildContext context, String key) => switch (key) {
        'nameRu' || 'nameEn' => inventoryText(context, 'название', 'name'),
        'descriptionRu' ||
        'descriptionEn' =>
          inventoryText(context, 'описание', 'description'),
        'weight' => inventoryText(context, 'вес', 'weight'),
        'valueInCopper' => inventoryText(context, 'цена', 'price'),
        'weaponProperties' =>
          inventoryText(context, 'свойства оружия', 'weapon properties'),
        'armorProperties' =>
          inventoryText(context, 'свойства доспеха', 'armour properties'),
        'rarity' => inventoryText(context, 'редкость', 'rarity'),
        'type' => inventoryText(context, 'тип', 'type'),
        'isMagical' ||
        'requiresAttunement' =>
          inventoryText(context, 'магия и настройка', 'magic and attunement'),
        _ => inventoryText(context, 'детали', 'details'),
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final changed = {
      for (final key in ItemReferences.changes(item, update))
        _field(context, key)
    }.join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: CompanionSurface(
        key: const ValueKey('item-book-update'),
        quiet: true,
        contour: CompanionContour.focus,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: LineIcon('book', size: 20, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inventoryText(context, 'В книге новая версия', 'A new version in the book'),
                  style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                  inventoryText(
                      context,
                      '${contentSourceName(context, update.sourceId)} · изменились: $changed. Количество, экипировка и настройка останутся.',
                      '${contentSourceName(context, update.sourceId)} · changed: $changed. Quantity, equipment and attunement stay.'),
                  style: t.textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant, height: 1.35)),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.tonal(
                    key: const ValueKey('item-book-update-apply'),
                    onPressed: busy ? null : onUpdate,
                    child: Text(inventoryText(context, 'Обновить', 'Update'))),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<String?> showInventoryQuickActions(BuildContext context, Item item) =>
    showResponsiveSheet<String>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) {
          final t = Theme.of(context), l = AppLocalizations.of(context)!;
          Widget action(String id, String title, IconData icon) => ListTile(
              leading: Icon(icon),
              title: Text(title),
              onTap: () => Navigator.pop(context, id));
          return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      InventoryItemGlyph(item: item),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text(
                              item.getName(
                                  Localizations.localeOf(context).languageCode),
                              style: t.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)))
                    ]),
                    const SizedBox(height: 12),
                    action(
                        'open',
                        inventoryText(context, 'О предмете', 'Item details'),
                        Icons.info_outline_rounded),
                    if (item.quantity > 0 || item.isEquipped)
                      action('equip', item.isEquipped ? l.unequip : l.equip,
                          Icons.checkroom_rounded),
                    if (item.isMagical ||
                        item.isAttuned ||
                        item.requiresAttunement)
                      action(
                          'attune',
                          item.isAttuned
                              ? inventoryText(context, 'Прекратить настройку',
                                  'End attunement')
                              : l.attunement,
                          Icons.auto_awesome_rounded),
                    action('quantity', l.quantity, Icons.numbers_rounded),
                    if (item.quantity > 1)
                      action(
                          'split',
                          inventoryText(
                              context, 'Разделить стопку', 'Split stack'),
                          Icons.call_split_rounded),
                    if (item.quantity > 0 && item.type == ItemType.consumable)
                      action(
                          'use',
                          inventoryText(
                              context, 'Использовать один', 'Use one'),
                          Icons.local_drink_outlined),
                    action('remove', l.remove, Icons.delete_outline_rounded),
                  ]));
        });

class _NumberSheet extends StatefulWidget {
  const _NumberSheet(
      {required this.title,
      required this.subtitle,
      required this.initial,
      required this.save,
      this.minimum = 0,
      this.maximum});
  final String title, subtitle;
  final int initial, minimum;
  final int? maximum;
  final Future<void> Function(int) save;
  @override
  State<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends State<_NumberSheet> {
  final form = GlobalKey<FormState>();
  late final value = TextEditingController(text: '${widget.initial}');
  bool busy = false;
  String? issue;
  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), l = AppLocalizations.of(context)!;
    return PopScope(
        canPop: !busy,
        child: KeyboardPadding(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                24, 8, 24, 24),
            child: Form(
                key: form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(widget.title,
                          style: t.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(widget.subtitle, style: t.textTheme.bodyLarge),
                      const SizedBox(height: 24),
                      TextFormField(
                          controller: value,
                          enabled: !busy,
                          autofocus: false,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: l.quantity),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            return n == null ||
                                    n < widget.minimum ||
                                    widget.maximum != null &&
                                        n > widget.maximum!
                                ? inventoryText(
                                    context,
                                    'Введи целое число от ${widget.minimum}${widget.maximum == null ? '' : ' до ${widget.maximum}'}',
                                    'Enter a whole number from ${widget.minimum}${widget.maximum == null ? '' : ' to ${widget.maximum}'}')
                                : null;
                          }),
                      if (issue != null) ...[
                        const SizedBox(height: 12),
                        Text(issue!,
                            style: TextStyle(color: t.colorScheme.error))
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  if (!form.currentState!.validate()) return;
                                  setState(() => busy = true);
                                  try {
                                    await widget
                                        .save(int.parse(value.text.trim()));
                                    if (context.mounted) {
                                      Navigator.pop(context, true);
                                    }
                                  } catch (_) {
                                    if (mounted) {
                                      setState(() {
                                        busy = false;
                                        issue = inventoryText(
                                            context,
                                            'Изменение не сохранено. Проверь актуальное количество.',
                                            'Change not saved. Check the current quantity.');
                                      });
                                    }
                                  }
                                },
                          child: Text(l.save)),
                    ])))));
  }
}

class _WalletSheet extends StatefulWidget {
  const _WalletSheet(this.hero);
  final Character hero;
  @override
  State<_WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends State<_WalletSheet> {
  final form = GlobalKey<FormState>();
  late final before = Wallet.read(widget.hero);
  late final values = [
    for (final n in before.values) TextEditingController(text: '$n')
  ];
  bool busy = false;
  String? issue;
  @override
  void dispose() {
    for (final c in values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), l = AppLocalizations.of(context)!;
    final names = [l.currencyPP, l.currencyGP, l.currencySP, l.currencyCP];
    return PopScope(
        canPop: !busy,
        child: KeyboardPadding(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                24, 8, 24, 24),
            child: Form(
                key: form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(inventoryText(context, 'Кошель', 'Coin purse'),
                          style: t.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                          inventoryText(
                              context,
                              'Укажи монеты, которые действительно есть у героя. Номиналы не обмениваются автоматически.',
                              'Record the coins your character actually carries. Denominations are not exchanged automatically.'),
                          style: t.textTheme.bodyMedium),
                      const SizedBox(height: 24),
                      CompanionSurface(
                          quiet: true,
                          child: Column(children: [
                            for (var i = 0; i < values.length; i++)
                              Padding(
                                  padding:
                                      EdgeInsets.only(top: i == 0 ? 0 : 16),
                                  child: TextFormField(
                                      key: ValueKey('wallet-denomination-$i'),
                                      controller: values[i],
                                      enabled: !busy,
                                      autofocus: false,
                                      keyboardType: TextInputType.number,
                                      decoration:
                                          InputDecoration(labelText: names[i]),
                                      validator: (v) {
                                        final n = int.tryParse(v?.trim() ?? '');
                                        return n == null || n < 0
                                            ? inventoryText(
                                                context,
                                                'Целое число от нуля',
                                                'Whole number of zero or more')
                                            : null;
                                      }))
                          ])),
                      if (issue != null) ...[
                        const SizedBox(height: 12),
                        Text(issue!,
                            style: TextStyle(color: t.colorScheme.error))
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  if (!form.currentState!.validate()) return;
                                  setState(() => busy = true);
                                  try {
                                    final n = values
                                        .map((v) => int.parse(v.text.trim()))
                                        .toList();
                                    await InventoryActionsService.editWallet(
                                        widget.hero,
                                        Wallet(
                                            platinum: n[0],
                                            gold: n[1],
                                            silver: n[2],
                                            copper: n[3]),
                                        expected: before);
                                    if (context.mounted) {
                                      Navigator.pop(context, true);
                                    }
                                  } catch (_) {
                                    if (mounted) {
                                      setState(() {
                                        busy = false;
                                        issue = inventoryText(
                                            context,
                                            'Кошель изменился или запись не завершилась. Закрой форму и проверь баланс.',
                                            'The purse changed or saving failed. Reopen it to check your balance.');
                                      });
                                    }
                                  }
                                },
                          child: Text(l.save)),
                    ])))));
  }
}
