import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/character.dart';
import '../../core/models/item.dart';
import '../../core/services/inventory_actions_service.dart';
import '../../core/services/item_service.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/ui/sheet_drag_region.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/item_details_sheet.dart';
import 'create_item_screen.dart';
import 'inventory_presentation.dart';
import 'widgets/inventory_item_tile.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

Future<bool?> showInventoryAddSheet(BuildContext context, Character hero) =>
    showResponsiveSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _AddSheet(hero));

class _AddSheet extends StatefulWidget {
  const _AddSheet(this.hero);
  final Character hero;
  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final search = TextEditingController();
  final selected = <String, int>{};
  ItemType? type;
  String query = '';
  bool busy = false;
  String? issue;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> forge() async {
    final item = await Navigator.push<Item>(
        context, MaterialPageRoute(builder: (_) => const CreateItemScreen()));
    if (item == null || !mounted) return;
    setState(() => busy = true);
    try {
      await InventoryActionsService.add(widget.hero, [item]);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          issue = inventoryText(
              context,
              'Предмет не сохранён. Попробуй ещё раз.',
              'Item not saved. Please try again.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context),
        c = t.colorScheme,
        l = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    final items = ItemService.shelfItems()
        .where((i) =>
            (type == null || i.type == type) &&
            (query.isEmpty ||
                '${i.nameRu} ${i.nameEn}'
                    .toLowerCase()
                    .replaceAll('ё', 'е')
                    .contains(query.toLowerCase().replaceAll('ё', 'е'))))
        .toList();
    return PopScope(
        canPop: !busy,
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .88,
            child: KeyboardPadding(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(l.addItem,
                                    style: t.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -.7)),
                                const SizedBox(height: 16),
                                CompanionSurface(
                                    onTap: busy ? null : forge,
                                    contour: CompanionContour.focus,
                                    color: c.tertiaryContainer,
                                    padding: const EdgeInsets.all(16),
                                    child: Row(children: [
                                      Icon(Icons.build, color: c.tertiary),
                                      const SizedBox(width: 14),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(l.forgeTitle,
                                                style: t.textTheme.titleMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800)),
                                            Text(
                                                inventoryText(
                                                    context,
                                                    'Предмет с твоей историей',
                                                    'An item with your own story'),
                                                style: t.textTheme.bodySmall)
                                          ])),
                                      const Icon(Icons.arrow_forward_rounded)
                                    ])),
                                const SizedBox(height: 16),
                                TextField(
                                    controller: search,
                                    enabled: !busy,
                                    autofocus: false,
                                    onChanged: (v) => setState(() => query = v),
                                    decoration: InputDecoration(
                                        hintText: l.searchItems,
                                        prefixIcon:
                                            const Icon(Icons.search_rounded),
                                        filled: true,
                                        fillColor: c.surfaceContainerHigh,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(AppRadii.xl),
                                            borderSide: BorderSide.none))),
                              ])),
                      SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(children: [
                            Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                    label: Text(l.filterAll),
                                    selected: type == null,
                                    onSelected: busy
                                        ? null
                                        : (_) => setState(() => type = null))),
                            for (final value in ItemType.values)
                              Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                      label: Text(itemTypeName(context, value)),
                                      selected: type == value,
                                      onSelected: busy
                                          ? null
                                          : (_) =>
                                              setState(() => type = value))),
                          ])),
                      const SizedBox(height: 10),
                      Expanded(
                          child: items.isEmpty
                              ? Center(child: Text(l.noItemsFound))
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 4, 24, 16),
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index],
                                        count = selected[item.id] ?? 0;
                                    return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: CompanionSurface(
                                            quiet: count == 0,
                                            color: count > 0
                                                ? c.secondaryContainer
                                                : null,
                                            padding: const EdgeInsets.fromLTRB(
                                                14, 10, 6, 10),
                                            child: Row(children: [
                                              InventoryItemGlyph(
                                                  item: item, size: 40),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: InkWell(
                                                      onTap: busy
                                                          ? null
                                                          : () async {
                                                              await showResponsiveSheet(
                                                                  context:
                                                                      context,
                                                                  isScrollControlled:
                                                                      true,
                                                                  useSafeArea:
                                                                      true,
                                                                  builder: (_) =>
                                                                      ItemDetailsSheet(
                                                                          item:
                                                                              item,
                                                                          onAdd:
                                                                              () {
                                                                            Navigator.pop(context);
                                                                            setState(() =>
                                                                                selected[item.id] = count + 1);
                                                                          }));
                                                            },
                                                      child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 10),
                                                          child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                    item.getName(
                                                                        locale),
                                                                    style: t
                                                                        .textTheme
                                                                        .titleSmall
                                                                        ?.copyWith(
                                                                            fontWeight:
                                                                                FontWeight.w800)),
                                                                const SizedBox(
                                                                    height: 4),
                                                                Text(
                                                                    itemSummary(
                                                                        context,
                                                                        item),
                                                                    style: t
                                                                        .textTheme
                                                                        .bodySmall
                                                                        ?.copyWith(
                                                                            color:
                                                                                c.onSurfaceVariant))
                                                              ])))),
                                              if (count > 0)
                                                IconButton(
                                                    tooltip: l.remove,
                                                    onPressed: busy
                                                        ? null
                                                        : () => setState(() {
                                                              if (count == 1) {
                                                                selected.remove(
                                                                    item.id);
                                                              } else {
                                                                selected[item
                                                                        .id] =
                                                                    count - 1;
                                                              }
                                                            }),
                                                    icon: const Icon(
                                                        Icons.remove_rounded)),
                                              if (count > 0)
                                                Text('$count',
                                                    style: t
                                                        .textTheme.titleMedium),
                                              IconButton(
                                                  tooltip: l.addItem,
                                                  onPressed: busy
                                                      ? null
                                                      : () {
                                                          HapticFeedback
                                                              .selectionClick();
                                                          setState(() =>
                                                              selected[
                                                                      item.id] =
                                                                  count + 1);
                                                        },
                                                  icon: Icon(count == 0
                                                      ? Icons
                                                          .add_circle_outline_rounded
                                                      : Icons.add_rounded)),
                                            ])));
                                  })),
                      if (issue != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child:
                                Text(issue!, style: TextStyle(color: c.error))),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                          child: FilledButton.icon(
                              onPressed: busy || selected.isEmpty
                                  ? null
                                  : () async {
                                      setState(() => busy = true);
                                      try {
                                        final added = <Item>[];
                                        for (final entry in selected.entries) {
                                          final item = ItemService
                                              .createItemFromTemplate(entry.key,
                                                  quantity: entry.value);
                                          if (item == null) {
                                            throw StateError('Catalog changed');
                                          }
                                          added.add(item);
                                        }
                                        await InventoryActionsService.add(
                                            widget.hero, added);
                                        if (context.mounted) {
                                          Navigator.pop(context, true);
                                        }
                                      } catch (_) {
                                        if (mounted) {
                                          setState(() {
                                            busy = false;
                                            issue = inventoryText(
                                                context,
                                                'Не удалось добавить предметы. Выбор сохранён — попробуй снова.',
                                                'Could not add items. Your selection is kept — please try again.');
                                          });
                                        }
                                      }
                                    },
                              icon: busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.backpack_rounded),
                              label: Text(selected.isEmpty
                                  ? l.addItem
                                  : inventoryText(
                                      context,
                                      'В рюкзак · ${selected.values.fold<int>(0, (n, v) => n + v)}',
                                      'Pack · ${selected.values.fold<int>(0, (n, v) => n + v)}')))),
                    ]))));
  }
}
