import '../../core/content/content_catalog.dart';
import '../../shared/widgets/content_variant_picker.dart';
import '../../core/progression/character_class_context.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../core/models/character.dart';
import '../../core/models/spell.dart';
import '../../core/search/spell_catalog.dart';
import '../../core/services/character_data_service.dart';
import '../../core/services/spell_eligibility_service.dart';
import '../../core/services/spell_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/ui/companion_kit.dart' show FloatingFooter;
import '../../core/ui/companion_motion.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/ui/sheet_drag_region.dart';
import '../../core/utils/spell_utils.dart';
import '../../shared/widgets/spell_details_sheet.dart';
import 'spell_almanac_strings.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class SpellAlmanacScreen extends StatefulWidget {
  const SpellAlmanacScreen({super.key, this.character});
  final Character? character;
  @override
  State<SpellAlmanacScreen> createState() => _SpellAlmanacScreenState();
}

class _SpellAlmanacScreenState extends State<SpellAlmanacScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  var _filter = const SpellCatalogFilter();
  late SpellCatalog _catalog;
  int _revision = -1, _classRevision = -1;
  final _eligibility = <String, SpellEligibilityResult>{};
  SpellCatalogFilter? _lastFilter;
  String? _lastLocale, _lastKnown;
  List<Spell>? _results;
  final _families = <String, ContentFamily<Spell>>{};
  late ContentCatalog<Spell> _content;
  List<Spell> _select(String locale) {
    final known = widget.character?.knownSpells.join('\u0000');
    if (_results != null &&
        identical(_lastFilter, _filter) &&
        _lastLocale == locale &&
        _lastKnown == known) {
      return _results!;
    }
    _lastFilter = _filter;
    _lastLocale = locale;
    _lastKnown = known;
    final selected = _catalog.select(_filter,
        locale: locale, hero: widget.character, eligibility: _eligibility);
    final allowed = selected.map((s) => s.id).toSet();
    final rank = {for (var i = 0; i < selected.length; i++) selected[i].id: i};
    _families.clear();
    final results = <Spell>[];
    for (final family in _content.families) {
      final records =
          family.records.where((r) => allowed.contains(r.id)).toList();
      if (records.isEmpty) continue;
      records.sort((a, b) {
        final ak = widget.character?.knownSpells.contains(a.id) ?? false,
            bk = widget.character?.knownSpells.contains(b.id) ?? false;
        if (ak != bk) return ak ? -1 : 1;
        return rank[a.id]!.compareTo(rank[b.id]!);
      });
      final representative = records.first.entity;
      _families[representative.id] = ContentFamily(records);
      results.add(representative);
    }
    results.sort((a, b) => rank[a.id]!.compareTo(rank[b.id]!));
    return _results = results;
  }

  void _refreshCatalog() {
    if (_revision == SpellService.catalogRevision &&
        _classRevision == CharacterDataService.catalogRevision) {
      return;
    }
    _revision = SpellService.catalogRevision;
    _classRevision = CharacterDataService.catalogRevision;
    _catalog = SpellCatalog(SpellService.shelfSpells());
    _content = ContentCatalog(_catalog.spells.map(ContentRecords.spell));
    _eligibility.clear();
    _results = null;
    final hero = widget.character;
    if (hero != null) {
      final evaluate = SpellEligibilityService.forCharacter(hero);
      for (final spell in _catalog.spells) {
        _eligibility[spell.id] = evaluate(spell);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshCatalog();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _setFilter(SpellCatalogFilter f) {
    setState(() => _filter = f);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _reset() {
    _debounce?.cancel();
    _search.clear();
    _setFilter(const SpellCatalogFilter());
  }

  Future<void> _filters() async {
    FocusScope.of(context).unfocus();
    final result = await showResponsiveSheet<SpellCatalogFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(catalog: _catalog, initial: _filter),
    );
    if (mounted && result != null) _setFilter(result);
  }

  Future<void> _details(Spell spell) async {
    FocusScope.of(context).unfocus();
    final family = _families[spell.id];
    if (family != null && family.variants.length > 1) {
      final s = AlmanacStrings(context), l = AppLocalizations.of(context)!;
      final chosen = await showContentVariantPicker(context, family,
          title: spell.getName(s.ru ? 'ru' : 'en'),
          preferredIds: widget.character?.knownSpells.toSet() ?? {},
          summary: (Spell value) =>
              '${value.level == 0 ? l.cantrips : l.levelLabel(value.level)} · ${SpellUtils.getLocalizedValue(l, value.castingTime)} · ${SpellUtils.getLocalizedSchool(l, value.school)}',
          description: (Spell value) =>
              value.getDescription(s.ru ? 'ru' : 'en'));
      if (chosen == null || !mounted) return;
      spell = chosen;
    }
    await showResponsiveSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SpellDetailsSheet(
        spell: spell,
        character: widget.character,
        editable: widget.character != null,
        onChanged: () {
          if (mounted) setState(() {});
        },
      ),
    );
    if (mounted) setState(() {});
  }

  String _sourceName(String source) {
    final strings = AlmanacStrings(context);
    if (source.isEmpty) return strings.t('Базовая библиотека', 'Core library');
    try {
      return StorageService.getAllSources()
              .where((s) => s.id == source)
              .firstOrNull
              ?.name ??
          strings.t('Подключённая книга', 'Imported book');
    } catch (_) {
      return strings.t('Подключённая книга', 'Imported book');
    }
  }

  @override
  Widget build(BuildContext context) {
    _refreshCatalog();
    final l = AppLocalizations.of(context)!, s = AlmanacStrings(context);
    final c = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final spells = _select(locale);
    final rows = <({int? circle, Spell? spell})>[];
    int? last;
    for (final spell in spells) {
      if (_filter.query.trim().isEmpty && spell.level != last) {
        rows.add((circle: spell.level, spell: null));
        last = spell.level;
      }
      rows.add((circle: null, spell: spell));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.spellAlmanacTitle),
        scrolledUnderElevation: 0,
        backgroundColor: c.surface,
        actions: [
          if (_filter.isActive)
            IconButton(
              tooltip: l.clearFilters,
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt_rounded),
            ),
        ],
      ),
      body: CompanionEntrance(
        child: CustomScrollView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
                child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: CompanionSurface(
                  contour: CompanionContour.fold,
                  raised: true,
                  padding: const EdgeInsets.all(16),
                  color: Color.lerp(
                    c.surfaceContainerLow,
                    c.secondaryContainer,
                    .22,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.character?.name ??
                            s.t('Магия на страницах', 'Magic, page by page'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.character == null
                            ? s.t(
                                'Твои книги — в одном месте',
                                'Your books, together',
                              )
                            : widget.character!.classes
                                .map((entry) =>
                                    '${CharacterClassContext(widget.character!, entry.id).name(locale)} ${entry.level}')
                                .join(' · '),
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                                container: true,
                                child: TextField(
                                  key: const ValueKey('almanac-search'),
                                  controller: _search,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (q) {
                                    _debounce?.cancel();
                                    _setFilter(_filter.copyWith(query: q));
                                    FocusScope.of(context).unfocus();
                                  },
                                  decoration: InputDecoration(
                                    hintText: l.searchSpells,
                                    filled: true,
                                    fillColor: c.surface,
                                    prefixIcon:
                                        const Icon(Icons.search_rounded),
                                    suffixIcon: _search.text.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: l.clearFilters,
                                            icon:
                                                const Icon(Icons.close_rounded),
                                            onPressed: () {
                                              _debounce?.cancel();
                                              _search.clear();
                                              _setFilter(
                                                  _filter.copyWith(query: ''));
                                            },
                                          ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppRadii.lgPlus),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (q) {
                                    setState(() {});
                                    _debounce?.cancel();
                                    _debounce = Timer(
                                      const Duration(milliseconds: 160),
                                      () {
                                        if (mounted) {
                                          _setFilter(
                                              _filter.copyWith(query: q));
                                        }
                                      },
                                    );
                                  },
                                )),
                          ),
                          const SizedBox(width: 8),
                          Badge(
                            isLabelVisible: _filter.count > 0,
                            label: Text('${_filter.count}'),
                            child: IconButton.filledTonal(
                              key: const ValueKey('almanac-filters'),
                              tooltip: l.filters,
                              onPressed: _filters,
                              icon: const Icon(Icons.tune_rounded),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.character != null)
                SizedBox(
                  height: 28 + MediaQuery.textScalerOf(context).scale(16),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final a in AlmanacAvailability.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s.availability(a)),
                            selected: _filter.availability == a,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              _setFilter(_filter.copyWith(availability: a));
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              SizedBox(
                height: 28 + MediaQuery.textScalerOf(context).scale(16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(s.t('Все круги', 'All circles')),
                        selected: _filter.circle == null,
                        onSelected: (_) =>
                            _setFilter(_filter.copyWith(clearCircle: true)),
                      ),
                    ),
                    for (var circle = 0; circle <= 9; circle++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          tooltip:
                              circle == 0 ? l.cantrips : l.levelLabel(circle),
                          label: Text(circle == 0 ? l.cantrips : '$circle'),
                          selected: _filter.circle == circle,
                          onSelected: (selected) => _setFilter(
                            _filter.copyWith(
                              circle: circle,
                              clearCircle: !selected,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        child: Align(
                          key: ValueKey(spells.length),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l.spellsCount(spells.length),
                            style: t.labelLarge?.copyWith(
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_filter.school != null)
                      Flexible(
                        child: Text(
                          SpellUtils.getLocalizedSchool(l, _filter.school!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.labelMedium,
                        ),
                      ),
                  ],
                ),
              ),
            ])),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: spells.isEmpty
                  ? SliverToBoxAdapter(
                      child: CompanionSurface(
                        quiet: true,
                        child: Column(
                          children: [
                            Icon(
                              _catalog.spells.isEmpty
                                  ? Icons.menu_book_rounded
                                  : Icons.search_off_rounded,
                              size: 38,
                              color: c.secondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _catalog.spells.isEmpty
                                  ? s.t('Книги ещё не открыты', 'No books yet')
                                  : l.noSpellsFound,
                              style: t.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _catalog.spells.isEmpty
                                  ? s.t(
                                      'Подключи библиотеку в настройках приложения.',
                                      'Add a library in app settings.',
                                    )
                                  : l.tryAdjustingFilters,
                              textAlign: TextAlign.center,
                            ),
                            if (_filter.isActive)
                              TextButton(
                                onPressed: _reset,
                                child: Text(l.clearFilters),
                              ),
                          ],
                        ),
                      ),
                    )
                  : SliverList.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        if (row.spell == null) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
                            child: Text(
                              row.circle == 0
                                  ? l.cantrips
                                  : l.levelLabel(row.circle!),
                              style: t.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: c.secondary,
                              ),
                            ),
                          );
                        }
                        final spell = row.spell!,
                            access = _eligibility[spell.id];
                        final known =
                            widget.character?.knownSpells.contains(spell.id) ??
                                false;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _SpellTile(
                            key: ValueKey('almanac-${spell.id}'),
                            spell: spell,
                            known: known,
                            access: access,
                            source:
                                (_families[spell.id]?.records.length ?? 1) > 1
                                    ? contentFamilySummary(
                                        context, _families[spell.id]!)
                                    : _sourceName(spell.sourceId ?? ''),
                            onTap: () => _details(spell),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpellTile extends StatelessWidget {
  const _SpellTile({
    super.key,
    required this.spell,
    required this.known,
    required this.access,
    required this.source,
    required this.onTap,
  });
  final Spell spell;
  final bool known;
  final SpellEligibilityResult? access;
  final String source;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!,
        s = AlmanacStrings(context),
        locale = Localizations.localeOf(context).languageCode;
    final c = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    final icon = known
        ? Icons.bookmark_rounded
        : switch (access?.state) {
            SpellAccessState.available => Icons.check_rounded,
            SpellAccessState.future => Icons.lock_clock_rounded,
            SpellAccessState.conditional => Icons.auto_awesome_outlined,
            SpellAccessState.unknown => Icons.help_outline_rounded,
            _ => null,
          };
    final hint = known
        ? s.t('В листе персонажа', 'On your sheet')
        : s.ru
            ? access?.reasonRu
            : access?.reason;
    return Semantics(
      button: true,
      child: CompanionSurface(
        onTap: onTap,
        quiet: true,
        contour: CompanionContour.focus,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: known
                    ? c.primaryContainer
                    : c.secondaryContainer.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Text(
                spell.level == 0 ? '∞' : '${spell.level}',
                style: t.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: known ? c.onPrimaryContainer : c.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spell.getName(locale),
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    SpellUtils.getLocalizedSchool(l, spell.school),
                    style: t.labelMedium?.copyWith(color: c.secondary),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        SpellUtils.getLocalizedValue(l, spell.castingTime),
                        style: t.bodySmall,
                      ),
                      if (spell.concentration)
                        Text(
                          l.concentration,
                          style: t.bodySmall?.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      if (spell.ritual)
                        Text(
                          l.ritual,
                          style: t.bodySmall?.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (source.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelSmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Tooltip(
                  message: hint ?? '',
                  child: Icon(
                    icon,
                    size: 20,
                    color: known ? c.primary : c.secondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.catalog, required this.initial});
  final SpellCatalog catalog;
  final SpellCatalogFilter initial;
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late var _draft = widget.initial;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!,
        s = AlmanacStrings(context),
        t = Theme.of(context).textTheme;
    Widget section(String title, List<Widget> children) {
      final selected = children
          .whereType<ChoiceChip>()
          .where((chip) => chip.selected)
          .toList();
      final summary =
          selected.map((chip) => (chip.label as Text).data ?? '').join(' · ');
      return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CompanionSurface(
              quiet: true,
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                  key: PageStorageKey('almanac-filter-$title'),
                  shape: const RoundedRectangleBorder(),
                  collapsedShape: const RoundedRectangleBorder(),
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  onExpansionChanged: (_) => HapticFeedback.selectionClick(),
                  title: Text(title,
                      style:
                          t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  subtitle: Text(summary,
                      style: t.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary)),
                  children: [
                    Align(
                        alignment: Alignment.centerLeft,
                        child:
                            Wrap(spacing: 8, runSpacing: 4, children: children))
                  ])));
    }

    Widget chip(String label, bool selected, VoidCallback action) => ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) {
            HapticFeedback.selectionClick();
            setState(action);
          },
        );
    return DraggableScrollableSheet(
      initialChildSize: .8,
      minChildSize: .45,
      maxChildSize: .95,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          SheetDragRegion(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.filters,
                      style: t.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _draft = SpellCatalogFilter(
                        query: widget.initial.query,
                        availability: widget.initial.availability,
                      ),
                    ),
                    child: Text(l.clearFilters),
                  ),
                ],
              ),
            ),
          ),
Expanded(child: FloatingFooter(inset: const EdgeInsets.fromLTRB(24, 0, 24, 16), action:           SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _draft),
                  child: Text(l.apply),
                ),
              ), child: ListView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(24, 0, 24, FloatingFooter.room(context)),
              children: [
                section(l.filterSchool, [
                  chip(
                    l.filterAllSchools,
                    _draft.school == null,
                    () => _draft = _draft.copyWith(clearSchool: true),
                  ),
                  for (final school in widget.catalog.schools)
                    chip(
                      SpellUtils.getLocalizedSchool(l, school),
                      _draft.school == school,
                      () => _draft = _draft.copyWith(
                        school: school,
                        clearSchool: _draft.school == school,
                      ),
                    ),
                ]),
                section(l.filterClass, [
                  chip(
                    l.filterAllClasses,
                    _draft.classId == null,
                    () => _draft = _draft.copyWith(clearClass: true),
                  ),
                  for (final id in widget.catalog.classes)
                    chip(
                      SpellUtils.getLocalizedClassName(context, id),
                      _draft.classId == id,
                      () => _draft = _draft.copyWith(
                        classId: id,
                        clearClass: _draft.classId == id,
                      ),
                    ),
                ]),
                section(s.t('Книги', 'Books'), [
                  chip(
                    s.t('Все книги', 'All books'),
                    _draft.sourceId == null,
                    () => _draft = _draft.copyWith(clearSource: true),
                  ),
                  for (final source in widget.catalog.sources)
                    chip(
                      _source(source, s),
                      _draft.sourceId == source,
                      () => _draft = _draft.copyWith(
                        sourceId: source,
                        clearSource: _draft.sourceId == source,
                      ),
                    ),
                ]),
                section(l.concentration, [
                  for (final p in AlmanacProperty.values)
                    chip(
                      s.property(p),
                      _draft.concentration == p,
                      () => _draft = _draft.copyWith(concentration: p),
                    ),
                ]),
                section(l.ritual, [
                  for (final p in AlmanacProperty.values)
                    chip(
                      s.property(p),
                      _draft.ritual == p,
                      () => _draft = _draft.copyWith(ritual: p),
                    ),
                ]),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.t('Искать в описаниях', 'Search descriptions')),
                  subtitle: Text(
                    s.t(
                      'Включить текст заклинаний в поиск',
                      'Include spell text in search',
                    ),
                  ),
                  value: _draft.searchDescriptions,
                  onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(searchDescriptions: v),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ))),

        ],
      ),
    );
  }

  String _source(String id, AlmanacStrings s) {
    if (id.isEmpty) return s.t('Базовая библиотека', 'Core library');
    try {
      return StorageService.getAllSources()
              .where((v) => v.id == id)
              .firstOrNull
              ?.name ??
          s.t('Подключённая книга', 'Imported book');
    } catch (_) {
      return s.t('Подключённая книга', 'Imported book');
    }
  }
}
