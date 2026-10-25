import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/journal/journal_graph.dart';
import '../../../core/journal/journal_service.dart';
import '../../../core/models/character.dart';
import '../../../core/models/quest.dart';
import '../../../core/search/journal_search.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_snack_bar.dart';
import '../../../core/ui/companion_kit.dart';
import '../../../core/ui/expressive_kit.dart';
import '../../journal/journal_atlas_page.dart';
import '../../journal/journal_entity_sheet.dart';
import '../../journal/journal_entry_editor.dart';
import '../../journal/journal_entry_page.dart';
import '../../journal/journal_index.dart';
import '../../journal/journal_kit.dart';
import '../../journal/journal_pin_board.dart';
import '../../journal/journal_session_tape.dart';
import '../../journal/journal_strings.dart';

/// The journal, as in the accepted wave 4 prototype: a masthead with an
/// epigraph, the session tape, search and the strip of names, the quest in
/// work with its next step, the other quests, the pinned shelf over a board
/// of notes, and a glass dock to write.
class JournalTab extends StatefulWidget {
  const JournalTab({super.key, required this.character});
  final Character character;
  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<JournalTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late final int _quote = math.Random().nextInt(JournalLook.quotesRu.length);
  String? _focus;
  int? _session;
  bool _foldClosed = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    JournalFocus.request.addListener(_focusRequested);
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    JournalFocus.home = ModalRoute.of(context);
  }

  // The Atlas asks the journal to look at one name.
  void _focusRequested() {
    final id = JournalFocus.request.value;
    if (id == null || !mounted) return;
    JournalFocus.request.value = null;
    setState(() {
      _focus = id;
      _session = null;
    });
    // The sheet's own scroll: the tab never takes a controller of its own,
    // so the hero card folds with it.
    final scroll = PrimaryScrollController.maybeOf(context);
    if (scroll != null && scroll.hasClients) {
      for (final p in scroll.positions) {
        p.jumpTo(p.minScrollExtent);
      }
    }
  }

  @override
  void dispose() {
    JournalFocus.request.removeListener(_focusRequested);
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _write({bool quest = false}) async {
    HapticFeedback.selectionClick();
    await Navigator.push(
        context,
        MaterialPageRoute<bool>(
            builder: (_) =>
                JournalEntryEditor(character: widget.character, quest: quest)));
    if (mounted) setState(() {});
  }

  Future<void> _open(String key) async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) =>
                JournalEntryPage(character: widget.character, entryKey: key)));
    if (mounted) setState(() {});
  }

  Future<void> _atlas() async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) =>
                JournalAtlasPage(character: widget.character, selected: _focus)));
    if (mounted) setState(() {});
  }

  Future<void> _entity(String id) async {
    await openJournalEntity(context, widget.character, id);
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<void> Function() write, String failRu,
      String failEn) async {
    if (_busy) return;
    _busy = true;
    try {
      await write();
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, JournalStrings(context).t(failRu, failEn));
      }
    }
    _busy = false;
    if (mounted) setState(() {});
  }

  Future<void> _newSession() async {
    HapticFeedback.mediumImpact();
    final s = JournalStrings(context);
    await _run(() => JournalService.startSession(widget.character),
        'Не удалось начать сессию', 'Could not start the session');
    if (!mounted) return;
    setState(() => _session = null);
    final n = JournalService.graph(widget.character).currentSession;
    AppSnackBar.info(
        context,
        s.t('Сессия $n началась — новые записи попадут в неё',
            'Session $n started — new entries go there'),
        clearQueue: true);
  }

  Future<void> _dropSession() async {
    final s = JournalStrings(context);
    final n = JournalService.graph(widget.character).currentSession;
    var dropped = false;
    await _run(() async => dropped = await JournalService.dropSession(widget.character),
        'Не удалось убрать сессию', 'Could not remove the session');
    if (!mounted || !dropped) return;
    setState(() => _session = null);
    AppSnackBar.info(context, s.t('Сессия $n убрана', 'Session $n removed'),
        clearQueue: true);
  }

  Future<void> _tick(String key, int step, bool done) => _run(
      () => JournalService.setObjective(widget.character, key, step, done),
      'Не удалось отметить шаг',
      'Could not mark the step');

  Future<void> _commit(
      List<String> shelf, List<String> board, bool? pinned) async {
    final s = JournalStrings(context);
    try {
      await JournalService.reorder(widget.character,
          quests: false,
          visibleOrder: [...shelf, ...board],
          pinned: shelf.toSet());
      if (!mounted) return;
      setState(() {});
      if (pinned != null) {
        AppSnackBar.info(
            context,
            pinned ? s.t('Закреплено', 'Pinned') : s.t('Откреплено', 'Unpinned'),
            duration: const Duration(milliseconds: 1600),
            clearQueue: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {});
      AppSnackBar.error(
          context,
          s.t('Не удалось сохранить порядок. Попробуй ещё раз.',
              'Could not save the order. Try again.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final index = JournalIndex(widget.character);
    final graph = index.graph;
    if (_focus != null && graph.entity(_focus!) == null) _focus = null;
    final current = graph.currentSession;
    if (_session != null && _session! > current) _session = null;
    final search = JournalSearch(_search.text);
    List<String> fields(JournalEntry e) => [
          ...e.fields,
          for (final entity in index.entitiesOf(e.key)) ...[
            entity.name,
            ...entity.aliases
          ]
        ];
    final scores = {for (final e in index.entries) e.key: search.score(fields(e))};
    bool shown(JournalEntry e) =>
        (scores[e.key] ?? 0) > 0 &&
        (_focus == null || graph.forRecord(e.key).entities.contains(_focus)) &&
        (_session == null || graph.forRecord(e.key).session == _session);
    final searching = _search.text.trim().isNotEmpty;
    final quests = JournalService.ordered(widget.character, quests: true)
        .where(shown)
        .toList();
    final notes = JournalService.ordered(widget.character, quests: false)
        .where(shown)
        .toList();
    if (searching) {
      quests.sort((a, b) => scores[b.key]!.compareTo(scores[a.key]!));
    }
    final active = quests.where((q) => q.quest!.status == QuestStatus.active).toList();
    final closed = quests.where((q) => q.quest!.status != QuestStatus.active).toList();
    final hero = active.isEmpty ? null : active.first;
    final people = [
      for (final e in graph.entities)
        if (index.recordsOf(e.id).isNotEmpty) (e, index.recordsOf(e.id).length)
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final focus = _focus == null ? null : graph.entity(_focus!);
    final filtered = searching || _focus != null || _session != null;
    JournalCardData card(JournalEntry e) => JournalCardData(
        key: e.key,
        title: e.title,
        text: e.text,
        category: e.note!.category,
        kinds: [for (final x in index.entitiesOf(e.key)) x.kind],
        session: index.session(e.key));
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final a1 = JournalLook.accent(context, 1);
    return Stack(children: [
      CustomScrollView(
        clipBehavior: Clip.none,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                20, 24 + SheetPageInset.of(context), 20, 140 + bottom),
            sliver: SliverList.list(children: [
              // Masthead: a kicker, the heavy title, the epigraph.
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            journalUpper(
                                '${widget.character.name} · ${s.t('журнал', 'journal')}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: journalCap(context, a1)),
                        const SizedBox(height: 6),
                        Text(s.t('Журнал', 'Journal'),
                            style: TextStyle(
                                fontFamily: AppType.display,
                                fontSize: 46,
                                height: .95,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -2.07,
                                color: c.onSurface)),
                      ]),
                ),
                JournalRound(
                    key: const ValueKey('journal-atlas'),
                    icon: 'grid',
                    label: s.t('Атлас', 'Atlas'),
                    onTap: _atlas),
              ]),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: LineIcon('quote', size: 18, color: a1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      (s.ru ? JournalLook.quotesRu : JournalLook.quotesEn)[_quote],
                      style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: c.onSurfaceVariant)),
                ),
              ]),
              const SizedBox(height: 28),
              JournalSessionTape(
                current: current,
                countIn: graph.countIn,
                picked: _session,
                onPick: (n) => setState(() => _session = n),
                onAdd: _newSession,
                onDrop: _dropSession,
              ),
              const SizedBox(height: 22),
              JournalSearchField(
                  controller: _search,
                  focus: _searchFocus,
                  hint: s.t('Найти в журнале: имя, место, слово',
                      'Search the journal: a name, a place, a word'),
                  onChanged: () => setState(() {})),
              if (people.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Strip(children: [
                  for (final (e, _) in people)
                    JournalToken(
                        key: ValueKey('journal-name-${e.id}'),
                        entity: e,
                        on: _focus == e.id,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _focus = _focus == e.id ? null : e.id);
                        }),
                ]),
              ],
              if (focus != null) ...[
                const SizedBox(height: 14),
                _FocusBar(
                    entity: focus,
                    onCard: () => _entity(focus.id),
                    onClear: () {
                      HapticFeedback.selectionClick();
                      setState(() => _focus = null);
                    }),
              ],
              if (filtered) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                      s.t('Найдено: ${s.records(quests.length + notes.length)}',
                          'Found: ${s.records(quests.length + notes.length)}'),
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.onSurfaceVariant)),
                ),
              ],
              if (hero != null) ...[
                const SizedBox(height: 28),
                _HeroQuest(
                    key: ValueKey('journal-hero-${hero.key}'),
                    entry: hero,
                    session: index.session(hero.key),
                    names: index.entitiesOf(hero.key).take(4).toList(),
                    onOpen: () => _open(hero.key),
                    onEntity: _entity,
                    onTick: (step) => _tick(hero.key, step, true)),
              ],
              if (active.length > 1 || closed.isNotEmpty) ...[
                const SizedBox(height: 40),
                JournalHeading(s.t('Задания', 'Quests'),
                    count: s.t('${active.length} в работе',
                        '${active.length} in progress')),
                const SizedBox(height: 14),
                for (final q in active.skip(1)) ...[
                  _QuestRow(entry: q, onOpen: () => _open(q.key)),
                  const SizedBox(height: 10),
                ],
                if (closed.isNotEmpty) ...[
                  Pressable(
                    key: const ValueKey('journal-fold'),
                    haptic: true,
                    onTap: () => setState(() => _foldClosed = !_foldClosed),
                    semanticLabel: s.t('Завершённые и проваленные',
                        'Completed and failed'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 10),
                      child: Row(children: [
                        AnimatedRotation(
                            turns: _foldClosed ? 0 : .5,
                            duration: AppMotion.of(context, AppMotion.snappySettle),
                            curve: AppMotion.snappyCurve,
                            child: LineIcon('down',
                                size: 18, color: c.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              s.t('Завершённые и проваленные · ${closed.length}',
                                  'Completed and failed · ${closed.length}'),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: c.onSurfaceVariant)),
                        ),
                      ]),
                    ),
                  ),
                  CalmSize(
                    duration: AppMotion.gentleSettle,
                    curve: AppMotion.gentleCurve,
                    alignment: Alignment.topCenter,
                    child: _foldClosed
                        ? const SizedBox(width: double.infinity)
                        : Column(children: [
                            for (final q in closed) ...[
                              _QuestRow(entry: q, onOpen: () => _open(q.key)),
                              const SizedBox(height: 8),
                            ],
                          ]),
                  ),
                ],
              ],
              const SizedBox(height: 40),
              JournalPinBoard(
                key: const ValueKey('journal-board'),
                pinned: [for (final n in notes) if (n.note!.isPinned) card(n)],
                loose: [for (final n in notes) if (!n.note!.isPinned) card(n)],
                onOpen: _open,
                onCommit: _commit,
                emptyText: filtered
                    ? s.t('Ничего не нашлось.', 'Nothing found.')
                    : s.t('Здесь пока пусто. Начните с того, что случилось сегодня.',
                        'Nothing here yet. Start with what happened today.'),
              ),
            ]),
          ),
        ],
      ),
      Positioned(
        left: 14,
        right: 14,
        bottom: 18 + bottom,
        child: _Dock(
            onWrite: () => _write(),
            onQuest: () => _write(quest: true)),
      ),
    ]);
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.children});
  final List<Widget> children;
  // Runs edge to edge under the page's side padding.
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: MediaQuery.sizeOf(context).width,
          maxWidth: MediaQuery.sizeOf(context).width,
          child: Transform.translate(
            offset: const Offset(-20, 0),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              itemCount: children.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, i) => Center(child: children[i]),
            ),
          ),
        ),
      );
}

class _FocusBar extends StatelessWidget {
  const _FocusBar(
      {required this.entity, required this.onCard, required this.onClear});
  final JournalEntity entity;
  final VoidCallback onCard, onClear;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final a = JournalLook.accent(context, JournalLook.kindAccent(entity.kind));
    return Container(
      key: const ValueKey('journal-focus'),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: JournalLook.mix(a, .16, c.surfaceContainerLow),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: a.withValues(alpha: .45), width: 1.5),
      ),
      child: Row(children: [
        JournalSeal(
            icon: JournalLook.kindIcon(entity.kind),
            accent: a,
            size: JournalSealSize.sm),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(journalUpper(s.t('Фокус истории', 'Story focus')),
                style: journalCap(context, a, size: 11).copyWith(color: a)),
            const SizedBox(height: 2),
            Text(entity.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: c.onSurface)),
          ]),
        ),
        ToneButton(
            label: s.t('Карточка', 'Card'), height: 38, fontSize: 13, onPressed: onCard),
        const SizedBox(width: 6),
        JournalRound(
            icon: 'x',
            label: s.t('Снять фокус', 'Clear focus'),
            size: 36,
            onTap: onClear),
      ]),
    );
  }
}

/// The quest in work, its next step checkable right here.
class _HeroQuest extends StatelessWidget {
  const _HeroQuest(
      {super.key,
      required this.entry,
      required this.session,
      required this.names,
      required this.onOpen,
      required this.onEntity,
      required this.onTick});
  final JournalEntry entry;
  final int? session;
  final List<JournalEntity> names;
  final VoidCallback onOpen;
  final ValueChanged<String> onEntity;
  final ValueChanged<int> onTick;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final q = entry.quest!;
    final a = JournalLook.accent(context, 1);
    final next = q.objectives.indexWhere((o) => !o.isCompleted);
    return Pressable(
      onTap: onOpen,
      haptic: true,
      scale: .985,
      semanticLabel: q.title,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: LinearGradient(
            begin: const Alignment(-.6, -1),
            end: const Alignment(.6, 1),
            colors: [JournalLook.mix(a, .22, c.surfaceContainerLow), c.surfaceContainerLow],
            stops: const [0, .7],
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .8),
                blurRadius: 44,
                spreadRadius: -30,
                offset: const Offset(0, 22)),
          ],
        ),
        child: Stack(children: [
          Positioned(
            right: -90,
            top: -110,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    a.withValues(alpha: .4),
                    a.withValues(alpha: 0)
                  ], stops: const [0, .68]),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  journalUpper([
                    s.t('В работе', 'In progress'),
                    s.t('задание', 'quest'),
                    if (session != null) s.t('с сессии $session', 'since session $session'),
                  ].join(' · ')),
                  style: journalCap(context, a)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Text(q.title,
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 29,
                          height: 1.04,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.87,
                          color: c.onSurface)),
                ),
                const SizedBox(width: 14),
                JournalRing(
                    done: q.completedObjectivesCount,
                    total: q.objectives.length),
              ]),
              const SizedBox(height: 14),
              if (next >= 0)
                _NextStep(
                    key: ValueKey('journal-next-${entry.key}-$next'),
                    text: q.objectives[next].description,
                    onTick: () => onTick(next))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    LineIcon('check', size: 22, color: JournalLook.accent(context, 3)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.t('Все шаги отмечены', 'All steps done'),
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: c.onSurface)),
                            const SizedBox(height: 3),
                            Text(
                                s.t('Отметьте задание выполненным на его странице',
                                    'Mark the quest completed on its page'),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: c.onSurfaceVariant)),
                          ]),
                    ),
                  ]),
                ),
              if (names.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final e in names)
                    JournalToken(
                        entity: e, mini: true, onTap: () => onEntity(e.id)),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// «Следующий шаг» with its check: ticked, the box fills and the step is
/// struck through for a beat before the quest moves on.
class _NextStep extends StatefulWidget {
  const _NextStep({super.key, required this.text, required this.onTick});
  final String text;
  final VoidCallback onTick;
  @override
  State<_NextStep> createState() => _NextStepState();
}

class _NextStepState extends State<_NextStep> {
  bool _ticked = false;
  void _tap() {
    if (_ticked) return;
    HapticFeedback.lightImpact();
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onTick();
      return;
    }
    setState(() => _ticked = true);
    Timer(const Duration(milliseconds: 380), widget.onTick);
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: BoxDecoration(
          color: c.surface.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        JournalCheck(
            key: const ValueKey('journal-next-check'),
            on: _ticked,
            label: s.t('Отметить шаг', 'Mark the step'),
            onTap: _tap),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(journalUpper(s.t('Следующий шаг', 'Next step')),
                style: TextStyle(
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .66,
                    color: c.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(widget.text,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: c.onSurface,
                    decoration: _ticked ? TextDecoration.lineThrough : null,
                    decorationColor: JournalLook.accent(context, 3),
                    decorationThickness: 2)),
          ]),
        ),
      ]),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.entry, required this.onOpen});
  final JournalEntry entry;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final q = entry.quest!;
    final active = q.status == QuestStatus.active;
    final a = JournalLook.accent(context, JournalLook.statusAccent(q.status));
    final next = q.objectives.where((o) => !o.isCompleted).firstOrNull;
    return Pressable(
      key: ValueKey('journal-quest-${entry.key}'),
      onTap: onOpen,
      haptic: true,
      scale: .98,
      semanticLabel: q.title,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        decoration: BoxDecoration(
          color: active ? c.surfaceContainerLow : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          border: active
              ? null
              : Border.all(color: c.onSurface.withValues(alpha: .1), width: 1.2),
        ),
        child: Row(children: [
          if (active)
            JournalRing(
                done: q.completedObjectivesCount,
                total: q.objectives.length,
                size: 44)
          else
            JournalSeal(
                icon: JournalLook.statusIcon(q.status),
                accent: a,
                size: JournalSealSize.sm,
                dimension: 44,
                round: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(q.title,
                  style: TextStyle(
                      fontSize: 15.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: active ? c.onSurface : c.onSurfaceVariant,
                      decoration: q.status == QuestStatus.failed
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: JournalLook.accent(context, 0).withValues(alpha: .7))),
              const SizedBox(height: 3),
              Text(
                  active
                      ? next?.description ?? s.t('Все шаги отмечены', 'All steps done')
                      : JournalLook.statusLabel(s, q.status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
            ]),
          ),
          LineIcon('forward', size: 18, color: c.onSurfaceVariant),
        ]),
      ),
    );
  }
}

/// The glass dock: «Записать» and a new quest, within the thumb's reach.
class _Dock extends StatelessWidget {
  const _Dock({required this.onWrite, required this.onQuest});
  final VoidCallback onWrite, onQuest;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final a1 = JournalLook.accent(context, 1);
    return GlassSurface(
      borderRadius: BorderRadius.circular(36),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(
            child: _WriteButton(
                label: s.t('Записать', 'Write'), onTap: onWrite),
          ),
          const SizedBox(width: 8),
          JournalRound(
              key: const ValueKey('journal-new-quest'),
              icon: 'flag',
              label: s.t('Новое задание', 'New quest'),
              size: 56,
              color: a1,
              fill: JournalLook.mix(a1, .22, c.surfaceContainer),
              onTap: onQuest),
        ]),
      ),
    );
  }
}

class _WriteButton extends StatefulWidget {
  const _WriteButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  State<_WriteButton> createState() => _WriteButtonState();
}

class _WriteButtonState extends State<_WriteButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        key: const ValueKey('journal-write'),
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? .97 : 1,
          duration: dur,
          curve: AppMotion.snappyCurve,
          child: AnimatedContainer(
            duration: dur,
            curve: AppMotion.standard,
            height: 56,
            decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(_down ? 18 : 28)),
            child: ExcludeSemantics(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                LineIcon('feather', size: 22, color: c.onPrimary),
                const SizedBox(width: 10),
                Text(widget.label,
                    style: TextStyle(
                        fontFamily: AppType.body,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.onPrimary)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
