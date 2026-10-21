import '../../../core/ui/app_menu_style.dart';
import '../../../core/ui/sheet_drag_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/journal/journal_graph.dart';
import '../../../core/journal/journal_service.dart';
import '../../../core/models/character.dart';
import '../../../core/models/journal_note.dart';
import '../../../core/models/quest.dart';
import '../../../core/search/journal_search.dart';
import '../../../core/ui/app_snack_bar.dart';
import '../../journal/journal_entry_editor.dart';
import '../../journal/journal_entry_page.dart';
import '../../journal/journal_entry_tile.dart';
import '../../journal/journal_atlas_page.dart';
import '../../journal/journal_strings.dart';
import '../../journal/journal_appear.dart';
import '../../journal/journal_reorder_section.dart';
import '../../journal/widgets/adventurer_quote_card.dart';

class JournalTab extends StatefulWidget {
  const JournalTab({super.key, required this.character});
  final Character character;
  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<JournalTab>
    with AutomaticKeepAliveClientMixin {
  final _seenEntries = <String>{};
  @override
  bool get wantKeepAlive => true;
  final _search = TextEditingController();
  Offset? _pointerStart;
  double _pointerTravel = 0;
  bool _actionBusy = false;
  String? _focus;
  NoteCategory? _category;
  QuestStatus? _status;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit({bool quest = false}) async {
    await Navigator.push(
        context,
        MaterialPageRoute<bool>(
            builder: (_) =>
                JournalEntryEditor(character: widget.character, quest: quest)));
    if (mounted) setState(() {});
  }

  Future<void> _open(JournalEntry entry) async {
    HapticFeedback.selectionClick();
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => JournalEntryPage(
                character: widget.character, entryKey: entry.key)));
    if (mounted) setState(() {});
  }

  Future<void> _actions(JournalEntry entry) async {
    if (_actionBusy) return;
    final s = JournalStrings(context);
    HapticFeedback.selectionClick();
    final action = await showResponsiveSheet<String>(
        context: context,
        showDragHandle: true,
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : null,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      if (entry.note != null)
                        ListTile(
                            leading: Icon(entry.note!.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined),
                            title: Text(entry.note!.isPinned
                                ? s.t('Открепить', 'Unpin')
                                : s.t('Закрепить', 'Pin')),
                            onTap: () => Navigator.pop(context, 'pin')),
                      if (entry.quest != null)
                        ListTile(
                            leading: const Icon(Icons.task_alt),
                            title: Text(entry.quest!.status ==
                                    QuestStatus.active
                                ? s.t('Отметить выполненным', 'Mark completed')
                                : s.t('Вернуть в активные', 'Mark active')),
                            onTap: () => Navigator.pop(context, 'status')),
                      ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(s.t('Редактировать', 'Edit')),
                          onTap: () => Navigator.pop(context, 'edit')),
                      ListTile(
                          leading: const Icon(Icons.open_in_new),
                          title: Text(s.t('Открыть', 'Open')),
                          onTap: () => Navigator.pop(context, 'open')),
                      ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: Text(s.t('Удалить', 'Delete')),
                          onTap: () => Navigator.pop(context, 'delete')),
                      const SizedBox(height: 8),
                      Text(
                          s.t('Удерживай и тяни карточку, чтобы переставить.',
                              'Hold and drag a card to reorder.'),
                          style: Theme.of(context).textTheme.bodySmall),
                    ]))));
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await Navigator.push(
          context,
          MaterialPageRoute<bool>(
              builder: (_) => JournalEntryEditor(
                  character: widget.character, entry: entry)));
      if (mounted) setState(() {});
      return;
    }
    if (action == 'open') {
      await _open(entry);
      return;
    }
    if (action == 'delete') {
      final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(s.t('Удалить запись?', 'Delete entry?')),
                  content: Text(entry.title),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(s.t('Отмена', 'Cancel'))),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(s.t('Удалить', 'Delete')))
                  ]));
      if (yes != true || !mounted) return;
    }
    setState(() => _actionBusy = true);
    try {
      if (action == 'pin') {
        await JournalService.setPinned(
            widget.character, entry.key, !entry.note!.isPinned);
      }
      if (action == 'status') {
        await JournalService.setQuestStatus(
            widget.character,
            entry.key,
            entry.quest!.status == QuestStatus.active
                ? QuestStatus.completed
                : QuestStatus.active);
      }
      if (action == 'delete') {
        await JournalService.delete(widget.character, entry.key);
      }
      HapticFeedback.lightImpact();
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context,
            s.t('Не удалось сохранить действие', 'Could not save the action'));
      }
    }
    if (mounted) setState(() => _actionBusy = false);
  }

  Future<void> _reorder(
      bool quests, List<String> order, Set<String>? pinned) async {
    try {
      await JournalService.reorder(widget.character,
          quests: quests, visibleOrder: order, pinned: pinned);
      if (mounted) setState(() {});
      HapticFeedback.selectionClick();
    } catch (_) {
      if (mounted) {
        setState(() {});
        AppSnackBar.error(
            context,
            JournalStrings(context).t(
                'Не удалось сохранить порядок. Попробуй ещё раз.',
                'Could not save the order. Try again.'));
      }
    }
  }

  Future<void> _pickFocus(JournalGraph graph) async {
    final s = JournalStrings(context);
    final query = TextEditingController();
    final result = await showResponsiveSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
            builder: (context, refresh) => SafeArea(
                child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * .65,
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  s.t('За какой историей следим?',
                                      'Which story are we following?'),
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 16),
                              TextField(
                                  controller: query,
                                  decoration: InputDecoration(
                                      hintText:
                                          s.t('Найти историю', 'Find a story'),
                                      prefixIcon: const Icon(Icons.search)),
                                  onChanged: (_) => refresh(() {})),
                              Expanded(
                                  child: ListView(children: [
                                ListTile(
                                    leading:
                                        const Icon(Icons.auto_stories_outlined),
                                    title:
                                        Text(s.t('Все истории', 'All stories')),
                                    onTap: () => Navigator.pop(context, 'all')),
                                for (final e in graph.entities.where((e) =>
                                    JournalSearch(query.text).matches(
                                        [e.name, e.description, ...e.aliases])))
                                  ListTile(
                                      leading: Icon(s.icon(e.kind)),
                                      title: Text(e.name),
                                      subtitle: Text(e.description.isEmpty
                                          ? s.kind(e.kind)
                                          : e.description),
                                      trailing: _focus == e.id
                                          ? const Icon(Icons.check)
                                          : null,
                                      onTap: () =>
                                          Navigator.pop(context, e.id)),
                                if (graph.entities.isEmpty)
                                  Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(s.t(
                                          'Подтверди новое имя в записи — здесь появится его история.',
                                          'Confirm a new name in an entry to see its story here.'))),
                              ])),
                            ]))))));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    query.dispose();
    if (result != null && mounted) {
      HapticFeedback.selectionClick();
      setState(() => _focus = result == 'all' ? null : result);
    }
  }

  Future<void> _filters() async {
    final s = JournalStrings(context);
    await showResponsiveSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
            builder: (context, refresh) => SafeArea(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.t('Выборка журнала', 'Journal filters'),
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<NoteCategory?>(
                              borderRadius: AppMenuStyle.radius,
                              dropdownColor: AppMenuStyle.background(context),
                              elevation: 4,
                              initialValue: _category,
                              decoration: InputDecoration(
                                  labelText: s.t(
                                      'Категория записей', 'Note category')),
                              items: [
                                DropdownMenuItem(
                                    value: null,
                                    child: Text(s.t(
                                        'Все категории', 'All categories'))),
                                for (final c in NoteCategory.values)
                                  DropdownMenuItem(
                                      value: c,
                                      child: Text(s.ru
                                          ? c.displayNameRu
                                          : c.displayName))
                              ],
                              onChanged: (v) {
                                setState(() => _category = v);
                                refresh(() {});
                              }),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<QuestStatus?>(
                              borderRadius: AppMenuStyle.radius,
                              dropdownColor: AppMenuStyle.background(context),
                              elevation: 4,
                              initialValue: _status,
                              decoration: InputDecoration(
                                  labelText:
                                      s.t('Статус заданий', 'Quest status')),
                              items: [
                                DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                        s.t('Все статусы', 'All statuses'))),
                                for (final status in QuestStatus.values)
                                  DropdownMenuItem(
                                      value: status,
                                      child: Text(s.ru
                                          ? status.displayNameRu
                                          : status.displayName))
                              ],
                              onChanged: (v) {
                                setState(() => _status = v);
                                refresh(() {});
                              }),
                          const SizedBox(height: 22),
                          SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(s.t('Готово', 'Done')))),
                        ])))));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final graph = JournalService.graph(widget.character);
    final all = JournalService.entries(widget.character);
    final search = JournalSearch(_search.text);
    if (_focus != null && graph.entity(_focus!) == null) _focus = null;
    List<String> fields(JournalEntry e) => [
          ...e.fields,
          for (final id in graph.forRecord(e.key).entities)
            if (graph.entity(id) case final entity?) ...[
              entity.name,
              ...entity.aliases
            ]
        ];
    final scores = {
      for (final entry in all) entry.key: search.score(fields(entry))
    };
    final filtered = all
        .where((e) =>
            (_focus == null ||
                graph.forRecord(e.key).entities.contains(_focus)) &&
            (scores[e.key] ?? 0) > 0)
        .toList();
    final visible = filtered.map((e) => e.key).toSet();
    final quests = JournalService.ordered(widget.character, quests: true)
        .where((e) =>
            visible.contains(e.key) &&
            (_status == null || e.quest!.status == _status))
        .toList();
    final notes = JournalService.ordered(widget.character, quests: false)
        .where((e) =>
            visible.contains(e.key) &&
            (_category == null || e.note!.category == _category))
        .toList();
    if (_search.text.trim().isNotEmpty) {
      quests.sort((a, b) => scores[b.key]!.compareTo(scores[a.key]!));
      notes.sort((a, b) {
        final pin =
            (a.note!.isPinned ? 0 : 1).compareTo(b.note!.isPinned ? 0 : 1);
        return pin == 0 ? scores[b.key]!.compareTo(scores[a.key]!) : pin;
      });
    }
    Widget heading(String label, int count, bool quest) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: quest ? c.tertiaryContainer : c.secondaryContainer,
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(
                  quest ? Icons.flag_outlined : Icons.auto_stories_outlined,
                  size: 19,
                  color:
                      quest ? c.onTertiaryContainer : c.onSecondaryContainer)),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(label, style: Theme.of(context).textTheme.titleLarge)),
          Text('$count', style: TextStyle(color: c.onSurfaceVariant)),
          const SizedBox(width: 8),
          IconButton.filledTonal(
              onPressed: () => _edit(quest: quest),
              icon: const Icon(Icons.add),
              tooltip: quest
                  ? s.t('Добавить задание', 'Add quest')
                  : s.t('Добавить запись', 'Add note')),
        ]));
    Widget empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        child: Text(text, style: TextStyle(color: c.onSurfaceVariant)));
    Widget tile(JournalEntry e) => JournalAppear(
        key: ValueKey('journal-appear-${e.key}'),
        seen: _seenEntries.contains(e.key),
        onSeen: () => _seenEntries.add(e.key),
        child: JournalEntryTile(
            entry: e,
            onTap: () => _open(e),
            onMenu: () => _actions(e),
            reorderManaged: true,
            connectionCount: graph.forRecord(e.key).entities.length +
                graph.forRecord(e.key).records.length,
            session: graph.forRecord(e.key).session));
    return Listener(
        onPointerDown: (event) {
          _pointerStart = event.position;
          _pointerTravel = 0;
        },
        onPointerMove: (event) {
          if (_pointerStart != null) {
            final distance = (event.position - _pointerStart!).distance;
            if (distance > _pointerTravel) _pointerTravel = distance;
          }
        },
        onPointerCancel: (_) => _pointerTravel = double.infinity,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: AdventurerQuoteCard(
                      characterName: widget.character.name))),
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    key: const ValueKey('journal-search'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                        hintText: s.t('Найти в журнале', 'Search journal'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: s.t('Очистить поиск', 'Clear search'),
                                onPressed: () =>
                                    setState(() => _search.clear()))),
                  ))),
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(children: [
                    Expanded(
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: ActionChip(
                                avatar: const Icon(Icons.filter_list, size: 18),
                                tooltip: _focus == null
                                    ? s.t('Все истории', 'All stories')
                                    : graph.entity(_focus!)!.name,
                                label: Text(
                                    _focus == null
                                        ? s.t('Все истории', 'All stories')
                                        : graph.entity(_focus!)!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                onPressed: () => _pickFocus(graph)))),
                    const SizedBox(width: 8),
                    ActionChip(
                        avatar: const Icon(Icons.hub_outlined, size: 18),
                        label: Text(s.t('Атлас', 'Atlas')),
                        onPressed: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) => JournalAtlasPage(
                                      character: widget.character,
                                      selected: _focus)));
                          if (mounted) setState(() {});
                        }),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                        icon: const Icon(Icons.tune, size: 20),
                        tooltip: s.t('Выборка', 'Filters'),
                        onPressed: _filters,
                        style: _category != null || _status != null
                            ? IconButton.styleFrom(
                                backgroundColor: c.primaryContainer)
                            : null),
                  ]))),
          SliverToBoxAdapter(
              child: heading(s.t('Задания', 'Quests'), quests.length, true)),
          if (quests.isEmpty)
            SliverToBoxAdapter(
                child: empty(
                    _search.text.isNotEmpty || _focus != null || _status != null
                        ? s.t('Нет заданий для этой выборки',
                            'No quests match these filters')
                        : s.t('Добавь первую цель приключения',
                            'Add your first adventure goal')))
          else
            SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: JournalReorderSection(
                    entries: quests,
                    notes: false,
                    tile: tile,
                    travel: () => _pointerTravel,
                    enabled: !_actionBusy,
                    onMenu: _actions,
                    onReorder: (order, _) => _reorder(true, order, null))),
          SliverToBoxAdapter(
              child: heading(s.t('Записи', 'Notes'), notes.length, false)),
          if (notes.isEmpty)
            SliverToBoxAdapter(
                child: empty(_search.text.isNotEmpty ||
                        _focus != null ||
                        _category != null
                    ? s.t('Нет записей для этой выборки',
                        'No notes match these filters')
                    : s.t('Здесь начинается твоя история',
                        'Your story starts here')))
          else ...[
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(children: [
                      Icon(Icons.push_pin_outlined, size: 15, color: c.primary),
                      const SizedBox(width: 8),
                      Text(s.t('Закреплённые', 'Pinned'),
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: c.primary)),
                    ]))),
            SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: JournalReorderSection(
                    entries: notes,
                    notes: true,
                    tile: tile,
                    travel: () => _pointerTravel,
                    enabled: !_actionBusy,
                    onMenu: _actions,
                    onReorder: (order, pins) => _reorder(false, order, pins))),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]));
  }
}
