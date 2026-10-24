import 'package:flutter/material.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart' show SheetPageInset;
import 'package:flutter/services.dart';
import '../../../core/models/character.dart';
import '../../../core/models/item.dart';
import '../../../core/services/inventory_actions_service.dart';
import '../../../core/ui/app_menu_style.dart';
import '../../../core/ui/app_snack_bar.dart';
import '../../../core/ui/companion_surface.dart';
import '../../../core/ui/sheet_drag_region.dart';
import '../../../l10n/app_localizations.dart';
import '../../inventory/inventory_add_sheet.dart';
import '../../inventory/inventory_presentation.dart';
import '../../inventory/inventory_sheets.dart';
import '../../inventory/widgets/equipment_deck.dart';
import '../../inventory/widgets/inventory_item_tile.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab(
      {super.key,
      required this.character,
      this.showAddButton = true,
      this.onCharacterUpdated});
  final Character character;
  final bool showAddButton;
  final VoidCallback? onCharacterUpdated;
  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final search = TextEditingController();
  String query = '', sort = 'name', equipped = 'all';
  ItemType? type;
  bool busy = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void updated() {
    if (!mounted) return;
    setState(() {});
    widget.onCharacterUpdated?.call();
  }

  Future<void> open(Item item) async {
    await showOwnedInventoryItem(context, widget.character, item,
        onChanged: updated);
  }

  Future<void> quick(Item item) async {
    if (busy) return;
    final target = InventoryTarget(item),
        action = await showInventoryQuickActions(context, item);
    if (!mounted || action == null) return;
    if (action == 'open') {
      await open(item);
      return;
    }
    setState(() => busy = true);
    try {
      switch (action) {
        case 'equip':
          await InventoryActionsService.equip(
              widget.character, target, !item.isEquipped);
        case 'attune':
          await setInventoryAttunement(context, widget.character, item);
        case 'quantity':
          await showInventoryQuantity(context, widget.character, item);
        case 'split':
          await showInventoryQuantity(context, widget.character, item,
              split: true);
        case 'use':
          await InventoryActionsService.consume(widget.character, target);
        case 'remove':
          if (await confirmInventoryRemoval(context, item)) {
            await InventoryActionsService.remove(widget.character, target);
          }
      }
      if (mounted) {
        HapticFeedback.selectionClick();
        updated();
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            inventoryText(
                context,
                'Изменение не сохранено. Открой предмет заново.',
                'Change not saved. Reopen the item and try again.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> filters() async {
    await showResponsiveSheet(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(builder: (context, refresh) {
              final t = Theme.of(context), l = AppLocalizations.of(context)!;
              void change(VoidCallback action) {
                setState(action);
                refresh(() {});
                HapticFeedback.selectionClick();
              }

              return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            inventoryText(
                                context, 'Найти нужное', 'Find what you need'),
                            style: t.textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 20),
                        Text(l.type, style: t.textTheme.titleMedium),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          ChoiceChip(
                              label: Text(l.filterAll),
                              selected: type == null,
                              onSelected: (_) => change(() => type = null)),
                          for (final value in ItemType.values)
                            ChoiceChip(
                                label: Text(itemTypeName(context, value)),
                                selected: type == value,
                                onSelected: (_) => change(() => type = value)),
                        ]),
                        const SizedBox(height: 20),
                        Text(
                            inventoryText(
                                context, 'Где искать', 'Where to look'),
                            style: t.textTheme.titleMedium),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          for (final entry in {
                            'all': l.filterAll,
                            'equipped': l.filterEquipped,
                            'packed': l.filterUnequipped
                          }.entries)
                            ChoiceChip(
                                label: Text(entry.value),
                                selected: equipped == entry.key,
                                onSelected: (_) =>
                                    change(() => equipped = entry.key)),
                        ]),
                        const SizedBox(height: 24),
                        FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(l.done)),
                      ]));
            }));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context),
        c = t.colorScheme,
        l = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode,
        hero = widget.character;
    final normalized = query.toLowerCase().replaceAll('ё', 'е').trim();
    final items = hero.inventory
        .where((i) =>
            (type == null || i.type == type) &&
            (equipped == 'all' || (equipped == 'equipped') == i.isEquipped) &&
            (normalized.isEmpty ||
                '${i.nameRu} ${i.nameEn}'
                    .toLowerCase()
                    .replaceAll('ё', 'е')
                    .contains(normalized)))
        .toList();
    items.sort((a, b) {
      final result = switch (sort) {
        'weight' => b.totalWeight.compareTo(a.totalWeight),
        'value' => (b.valueInCopper * b.quantity)
            .compareTo(a.valueInCopper * a.quantity),
        'type' => a.type.index.compareTo(b.type.index),
        _ => a
            .getName(locale)
            .toLowerCase()
            .compareTo(b.getName(locale).toLowerCase())
      };
      return result != 0
          ? result
          : hero.inventory.indexOf(a).compareTo(hero.inventory.indexOf(b));
    });
    final weight = hero.inventory.fold<double>(0, (n, i) => n + i.totalWeight),
        capacity = hero.abilityScores.strength * 15,
        wallet = Wallet.read(hero),
        filtered = type != null || equipped != 'all' || query.isNotEmpty;
    return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: widget.showAddButton
            ? FloatingActionButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (await showInventoryAddSheet(context, hero) == true) {
                          updated();
                        }
                      },
                tooltip: l.addItem,
                child: const Icon(Icons.add_rounded))
            : null,
        body: CustomScrollView(
            key: const PageStorageKey('inventory-scroll'),
            // The page scrolls on under the floating island, like Overview.
            clipBehavior: Clip.none,
            slivers: [
              SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      20, 20 + SheetPageInset.of(context), 20, 0),
                  sliver: SliverToBoxAdapter(
                      child: AnimatedSize(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 260),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.topCenter,
                          child: EquipmentDeck(
                              hero: hero, onOpen: open, onHold: quick)))),
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverToBoxAdapter(
                      child: LayoutBuilder(builder: (context, bounds) {
                    final narrow = bounds.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.3;
                    Widget purse() => CompanionSurface(
                        onTap: busy
                            ? null
                            : () async {
                                if (await showInventoryWallet(context, hero) ==
                                    true) {
                                  updated();
                                }
                              },
                        quiet: true,
                        contour: CompanionContour.focus,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.toll_rounded,
                                    size: 19, color: c.tertiary),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        inventoryText(
                                            context, 'Кошель', 'Coin purse'),
                                        style: t.textTheme.labelLarge)),
                                const Icon(Icons.chevron_right_rounded,
                                    size: 18)
                              ]),
                              const SizedBox(height: 14),
                              Text(goldValue(wallet.totalCopper),
                                  style: t.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.7)),
                              const SizedBox(height: 4),
                              Text(
                                  inventoryText(context, 'в золотых монетах',
                                      'in gold pieces'),
                                  style: t.textTheme.labelSmall
                                      ?.copyWith(color: c.onSurfaceVariant)),
                            ]));
                    Widget load() => CompanionSurface(
                        quiet: true,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.backpack_outlined,
                                    size: 19, color: c.secondary),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(l.totalWeight,
                                        style: t.textTheme.labelLarge))
                              ]),
                              const SizedBox(height: 14),
                              Text('${compactNumber(weight)} ${l.weightUnit}',
                                  style: t.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.7)),
                              const SizedBox(height: 4),
                              Text(
                                  inventoryText(
                                      context,
                                      'из $capacity ${l.weightUnit}',
                                      'of $capacity ${l.weightUnit}'),
                                  style: t.textTheme.labelSmall?.copyWith(
                                      color: weight > capacity
                                          ? c.error
                                          : c.onSurfaceVariant)),
                              const SizedBox(height: 10),
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadii.md),
                                  child: LinearProgressIndicator(
                                      minHeight: 4,
                                      value: capacity > 0
                                          ? (weight / capacity).clamp(0, 1)
                                          : weight > 0
                                              ? 1
                                              : 0,
                                      color: weight > capacity
                                          ? c.error
                                          : c.secondary,
                                      backgroundColor: c.surfaceContainerHigh)),
                            ]));
                    if (narrow) {
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            purse(),
                            const SizedBox(height: 10),
                            load()
                          ]);
                    }
                    return IntrinsicHeight(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Expanded(child: purse()),
                          const SizedBox(width: 10),
                          Expanded(child: load())
                        ]));
                  }))),
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 16),
                  sliver: SliverToBoxAdapter(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Row(children: [
                          Expanded(
                              child: Text(
                                  inventoryText(
                                      context, 'Снаряжение', 'Your belongings'),
                                  style: t.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.5))),
                          PopupMenuButton<String>(
                              tooltip: l.sortBy,
                              borderRadius: AppMenuStyle.radius,
                              color: AppMenuStyle.background(context),
                              icon: const Icon(Icons.sort_rounded),
                              initialValue: sort,
                              onSelected: (v) => setState(() => sort = v),
                              itemBuilder: (_) => [
                                    for (final entry in {
                                      'name': l.sortName,
                                      'weight': l.sortWeight,
                                      'value': l.sortValue,
                                      'type': l.sortType
                                    }.entries)
                                      CheckedPopupMenuItem(
                                          value: entry.key,
                                          checked: sort == entry.key,
                                          child: Text(entry.value))
                                  ]),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: search,
                                  autofocus: false,
                                  onChanged: (v) => setState(() => query = v),
                                  decoration: InputDecoration(
                                      hintText: l.searchItems,
                                      prefixIcon:
                                          const Icon(Icons.search_rounded),
                                      suffixIcon: query.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: inventoryText(
                                                  context,
                                                  'Очистить поиск',
                                                  'Clear search'),
                                              onPressed: () {
                                                search.clear();
                                                setState(() => query = '');
                                              },
                                              icon: const Icon(
                                                  Icons.close_rounded)),
                                      filled: true,
                                      fillColor: c.surfaceContainerHigh,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(AppRadii.xl),
                                          borderSide: BorderSide.none)))),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                              tooltip:
                                  inventoryText(context, 'Фильтры', 'Filters'),
                              onPressed: filters,
                              icon: Badge(
                                  isLabelVisible:
                                      type != null || equipped != 'all',
                                  child: const Icon(Icons.tune_rounded)))
                        ]),
                        if (filtered) ...[
                          const SizedBox(height: 10),
                          Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                Text(
                                    '${items.length} / ${hero.inventory.length}',
                                    style: t.textTheme.labelMedium),
                                TextButton(
                                    onPressed: () {
                                      search.clear();
                                      setState(() {
                                        type = null;
                                        equipped = 'all';
                                        query = '';
                                      });
                                    },
                                    child: Text(inventoryText(context,
                                        'Сбросить фильтры', 'Reset filters')))
                              ])
                        ],
                      ]))),
              if (items.isEmpty)
                SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                        child: CompanionSurface(
                            quiet: true,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.travel_explore_rounded,
                                      color: c.secondary, size: 32),
                                  const SizedBox(height: 12),
                                  Text(
                                      filtered
                                          ? l.noItemsFound
                                          : inventoryText(
                                              context,
                                              'Начало коллекции',
                                              'The start of a collection'),
                                      style: t.textTheme.titleLarge),
                                  const SizedBox(height: 8),
                                  Text(filtered
                                      ? inventoryText(
                                          context,
                                          'Попробуй другое название или категорию.',
                                          'Try another name or category.')
                                      : inventoryText(
                                          context,
                                          'Добавь снаряжение из библиотеки или создай своё в Кузнице.',
                                          'Add equipment from your library or create your own in the Forge.'))
                                ])))),
              SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Padding(
                            key: item.instanceId == null
                                ? ObjectKey(item)
                                : ValueKey('inventory-${item.instanceId}'),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InventoryItemTile(
                                item: item,
                                onTap: () => open(item),
                                onHold: () => quick(item)));
                      })),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ]));
  }
}
