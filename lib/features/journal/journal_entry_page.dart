import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/journal/journal_graph.dart';
import '../../core/journal/journal_links.dart';
import '../../core/journal/journal_service.dart';
import '../../core/models/character.dart';
import '../../core/models/journal_note.dart';
import '../../core/models/quest.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/companion_kit.dart';
import 'entity_editor.dart';
import 'journal_entity_sheet.dart';
import 'journal_entry_editor.dart';
import 'journal_index.dart';
import 'journal_kit.dart';
import 'journal_selection.dart';
import 'journal_strings.dart';

/// A record as a manuscript page: a stamped seal and a big title, the text
/// with its names drawn in their colours, a quest's checklist and state,
/// the people and places of the record and its threads to other records.
class JournalEntryPage extends StatefulWidget {
  const JournalEntryPage(
      {super.key, required this.character, required this.entryKey});
  final Character character;
  final String entryKey;
  @override
  State<JournalEntryPage> createState() => _JournalEntryPageState();
}

class _JournalEntryPageState extends State<JournalEntryPage> {
  bool _busy = false, _titled = false;
  final _newStep = TextEditingController();
  String _selected = '';
  int? _ticking;

  static const _months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля',
    'августа', 'сентября', 'октября', 'ноября', 'декабря'
  ];
  static const _monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void dispose() {
    _newStep.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() write) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await write();
    } catch (_) {
      if (mounted) {
        final s = JournalStrings(context);
        AppSnackBar.error(context,
            s.t('Не удалось сохранить изменение', 'Could not save the change'));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  void _step(int i, bool done) {
    if (_busy) return;
    if (done) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    if (done && !MediaQuery.disableAnimationsOf(context)) {
      setState(() => _ticking = i);
      Timer(const Duration(milliseconds: 380), () {
        if (!mounted) return;
        _ticking = null;
        _run(() => JournalService.setObjective(
            widget.character, widget.entryKey, i, done));
      });
      return;
    }
    _run(() =>
        JournalService.setObjective(widget.character, widget.entryKey, i, done));
  }

  void _addStep() {
    final text = _newStep.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _newStep.clear();
    _run(() => JournalService.addObjective(
        widget.character, widget.entryKey, text));
  }

  void _status(QuestStatus status) {
    final s = JournalStrings(context);
    HapticFeedback.mediumImpact();
    _run(() async {
      await JournalService.setQuestStatus(
          widget.character, widget.entryKey, status);
      if (!mounted) return;
      AppSnackBar.info(
          context,
          switch (status) {
            QuestStatus.completed => s.t('Задание выполнено', 'Quest completed'),
            QuestStatus.failed => s.t('Задание провалено', 'Quest failed'),
            QuestStatus.active =>
              s.t('Задание снова в работе', 'Quest back in progress'),
          },
          clearQueue: true);
    });
  }

  Future<void> _edit(JournalEntry entry) async {
    await Navigator.push(
        context,
        MaterialPageRoute<bool>(
            builder: (_) =>
                JournalEntryEditor(character: widget.character, entry: entry)));
    if (mounted) setState(() {});
  }

  Future<void> _more(JournalEntry entry) async {
    final s = JournalStrings(context);
    final note = entry.note;
    final action = await showCompanionSheet<String>(context,
        builder: (context) {
      Widget row(String key, String icon, String label, Color tint) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Pressable(
              key: ValueKey('journal-more-$key'),
              onTap: () => Navigator.pop(context, key),
              haptic: true,
              scale: .98,
              semanticLabel: label,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  JournalSeal(icon: icon, accent: tint),
                  const SizedBox(width: 12),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          );
      final a0 = JournalLook.accent(context, 0);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(entry.title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.secondary)),
        const SizedBox(height: 8),
        SheetHeading(note != null ? s.t('Запись', 'Note') : s.t('Задание', 'Quest')),
        const SizedBox(height: 14),
        if (note != null)
          row('pin', 'bookmark',
              note.isPinned ? s.t('Открепить', 'Unpin') : s.t('Закрепить', 'Pin'), a0),
        row('delete', 'x', s.t('Удалить', 'Delete'), a0),
      ]);
    });
    if (!mounted || action == null) return;
    if (action == 'pin') {
      HapticFeedback.lightImpact();
      await _run(() =>
          JournalService.setPinned(widget.character, entry.key, !note!.isPinned));
      if (mounted) {
        AppSnackBar.info(
            context,
            note!.isPinned ? s.t('Откреплено', 'Unpinned') : s.t('Закреплено', 'Pinned'),
            clearQueue: true);
      }
      return;
    }
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
                      key: const ValueKey('journal-delete-confirm'),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(s.t('Удалить', 'Delete')))
                ]));
    if (yes != true || !mounted) return;
    try {
      await JournalService.delete(widget.character, entry.key);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, s.t('Не удалось удалить запись', 'Could not delete the entry'));
      }
    }
  }

  Future<void> _linkSelected(String text) async {
    if (_busy) return;
    final graph = JournalService.graph(widget.character);
    final choice = await chooseSelectionStory(context, text, graph.entities);
    if (!mounted || choice == null) return;
    JournalEntity? created;
    if (choice == 'new') {
      created = await editJournalEntity(context, name: text);
      if (!mounted || created == null) return;
    }
    await _saveSelection(created?.id ?? choice, created);
  }

  Future<void> _saveSelection(String id, JournalEntity? created) async {
    final entry = JournalIndex(widget.character).entry(widget.entryKey);
    if (!mounted || _busy || entry == null) return;
    final links = JournalService.graph(widget.character).forRecord(entry.key);
    links.manual.add(id);
    links.excluded.remove(id);
    final copy = entry.note != null
        ? JournalEntry.note(JournalNote.fromJson(entry.note!.toJson()))
        : JournalEntry.quest(Quest.fromJson(entry.quest!.toJson()));
    setState(() => _busy = true);
    try {
      await JournalService.save(widget.character, copy,
          links: links, newEntities: created == null ? [] : [created]);
      HapticFeedback.selectionClick();
    } catch (_) {
      if (mounted) {
        final s = JournalStrings(context);
        AppSnackBar.error(context,
            s.t('Не удалось сохранить связь', 'Could not save the connection'),
            actionLabel: s.t('Повторить', 'Retry'),
            onAction: () => _saveSelection(id, created));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _entity(String id) async {
    await openJournalEntity(context, widget.character, id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final index = JournalIndex(widget.character);
    final entry = index.entry(widget.entryKey);
    final back = JournalRound(
        key: const ValueKey('journal-back'),
        icon: 'back',
        label: s.t('Назад', 'Back'),
        onTap: () => Navigator.maybePop(context));
    if (entry == null) {
      return Scaffold(
          body: Stack(children: [
        Center(child: Text(s.t('Запись удалена', 'Entry deleted'))),
        Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: JournalTopBar(titled: false, leading: back)),
      ]));
    }
    final q = entry.quest, note = entry.note;
    final links = index.graph.forRecord(entry.key);
    final head = q != null ? JournalLook.statusAccent(q.status) : JournalLook.categoryAccent(note!.category);
    final a = JournalLook.accent(context, head);
    final names = index.entitiesOf(entry.key);
    final threads = index.threadsOf(entry.key);
    final date = entry.date;
    final meta = [
      q != null ? s.t('Задание', 'Quest') : JournalLook.categoryLabel(s, note!.category),
      if (links.session != null) s.t('Сессия ${links.session}', 'Session ${links.session}'),
      s.ru
          ? '${date.day} ${_months[date.month - 1]}'
          : '${_monthsEn[date.month - 1]} ${date.day}',
    ].join(' · ');
    final top = MediaQuery.paddingOf(context).top;
    final linked = links.entities;
    final prose = TextStyle(
        fontFamily: AppType.body, fontSize: 17, height: 1.66, color: c.onSurface);
    return Scaffold(
      body: Stack(children: [
        NotificationListener<ScrollUpdateNotification>(
          onNotification: (n) {
            final titled = n.metrics.pixels > 96;
            if (n.depth == 0 && titled != _titled) setState(() => _titled = titled);
            return false;
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, top + JournalTopBar.height + 16, 16,
                60 + MediaQuery.paddingOf(context).bottom),
            children: [
              // The manuscript's head: a glow of the record's colour, the
              // seal, the line of facts and the title.
              Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: -60,
                  top: -120,
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: AppMotion.of(context, const Duration(milliseconds: 500)),
                      width: 320,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                            colors: [a.withValues(alpha: .3), a.withValues(alpha: 0)],
                            stops: const [0, .66]),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    JournalSeal(
                        key: const ValueKey('journal-seal'),
                        icon: q != null
                            ? JournalLook.statusIcon(q.status)
                            : JournalLook.categoryIcon(note!.category),
                        accent: a,
                        size: JournalSealSize.lg),
                    const SizedBox(height: 16),
                    Text(journalUpper(meta), style: journalCap(context, a, size: 12)),
                    const SizedBox(height: 10),
                    Text(entry.title,
                        key: const ValueKey('journal-page-title'),
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 36,
                            height: 1.02,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.26,
                            color: c.onSurface)),
                    if (note?.isPinned ?? false) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        LineIcon('bookmark', size: 15, color: JournalLook.accent(context, 0)),
                        const SizedBox(width: 6),
                        Text(s.t('Закреплено', 'Pinned'),
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: JournalLook.accent(context, 0))),
                      ]),
                    ],
                  ]),
                ),
              ]),
              if (entry.image != null) ...[
                const SizedBox(height: 14),
                journalImage(context, entry.image!, height: 240, width: double.infinity),
              ],
              if (entry.text.isNotEmpty) ...[
                const SizedBox(height: 14),
                SelectionArea(
                  key: const ValueKey('journal-reader-content'),
                  onSelectionChanged: (content) => _selected = content?.plainText.trim() ?? '',
                  contextMenuBuilder: (context, state) =>
                      AdaptiveTextSelectionToolbar.buttonItems(
                          anchors: state.contextMenuAnchors,
                          buttonItems: [
                            ...state.contextMenuButtonItems,
                            if (_selected.isNotEmpty && !_busy)
                              ContextMenuButtonItem(
                                  label: s.t('Связать с историей', 'Link to story'),
                                  onPressed: () {
                                    final text = _selected;
                                    ContextMenuController.removeAny();
                                    _linkSelected(text);
                                  }),
                          ]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final p in entry.text.split('\n'))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: MarkedText(p,
                            mentions: index.mentions(p),
                            only: linked,
                            style: prose,
                            onEntity: (e) => _entity(e.id)),
                      ),
                  ]),
                ),
              ],
              if (q != null) ...[
                const SizedBox(height: 4),
                _QuestBox(
                  quest: q,
                  ticking: _ticking,
                  busy: _busy,
                  newStep: _newStep,
                  mentions: index.mentions,
                  linked: linked,
                  onStep: _step,
                  onAdd: _addStep,
                  onStatus: _status,
                ),
              ],
              if (note?.tags.isNotEmpty ?? false) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final tag in note!.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: c.onSurface.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(999)),
                      child: Text('#$tag',
                          style: TextStyle(
                              fontSize: 13,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              color: c.onSurfaceVariant)),
                    ),
                ]),
              ],
              if (names.isNotEmpty) ...[
                const SizedBox(height: 24),
                JournalHeading(s.t('Действующие лица', 'Who and where'),
                    count: s.t('касание — карточка', 'tap for the card')),
                const SizedBox(height: 10),
                SizedBox(
                  height: 126,
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: MediaQuery.sizeOf(context).width,
                    maxWidth: MediaQuery.sizeOf(context).width,
                    child: Transform.translate(
                      offset: const Offset(-16, 0),
                      child: ListView.separated(
                        key: const ValueKey('journal-reader-stories'),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: names.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) =>
                            _Actor(entity: names[i], onTap: () => _entity(names[i].id)),
                      ),
                    ),
                  ),
                ),
              ],
              if (threads.isNotEmpty) ...[
                const SizedBox(height: 24),
                JournalHeading(s.t('Нити', 'Threads'),
                    count: s.plural(threads.length, const ['связь', 'связи', 'связей'],
                        const ['link', 'links'])),
                const SizedBox(height: 10),
                for (final (other, mine) in threads) ...[
                  _Thread(
                      entry: other,
                      why: mine
                          ? s.t('Связано тобой', 'Linked by you')
                          : s.t('Ссылается на эту запись', 'Links to this entry'),
                      session: index.session(other.key),
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => JournalEntryPage(
                                    character: widget.character, entryKey: other.key)));
                        if (mounted) setState(() {});
                      }),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: JournalTopBar(
            titled: _titled,
            title: entry.title,
            leading: back,
            actions: [
              JournalRound(
                  key: const ValueKey('journal-edit'),
                  icon: 'edit',
                  label: s.t('Изменить', 'Edit'),
                  onTap: _busy ? null : () => _edit(entry)),
              const SizedBox(width: 8),
              JournalRound(
                  key: const ValueKey('journal-more'),
                  icon: 'more',
                  label: s.t('Ещё', 'More'),
                  onTap: _busy ? null : () => _more(entry)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _QuestBox extends StatelessWidget {
  const _QuestBox(
      {required this.quest,
      required this.ticking,
      required this.busy,
      required this.newStep,
      required this.mentions,
      required this.linked,
      required this.onStep,
      required this.onAdd,
      required this.onStatus});
  final Quest quest;
  final int? ticking;
  final bool busy;
  final TextEditingController newStep;
  final List<JournalMention> Function(String) mentions;
  final Set<String> linked;
  final void Function(int, bool) onStep;
  final VoidCallback onAdd;
  final ValueChanged<QuestStatus> onStatus;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final done = quest.completedObjectivesCount, total = quest.objectives.length;
    final ok = JournalLook.accent(context, 3);
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return Container(
      key: const ValueKey('journal-reader-objectives'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          JournalRing(done: done, total: total, size: 76),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  total == 0
                      ? s.t('Шагов пока нет', 'No steps yet')
                      : done == total
                          ? s.t('Все шаги отмечены', 'All steps done')
                          : s.t('Шаг ${done + 1} из $total', 'Step ${done + 1} of $total'),
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 19,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.19,
                      fontFeatures: AppType.tabular,
                      color: c.onSurface)),
              const SizedBox(height: 4),
              Text(s.t('Коснитесь шага, чтобы отметить', 'Tap a step to mark it'),
                  style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        for (var i = 0; i < total; i++)
          Builder(builder: (context) {
            final o = quest.objectives[i];
            final on = o.isCompleted || ticking == i;
            return Pressable(
              key: ValueKey('journal-step-$i'),
              onTap: busy ? null : () => onStep(i, !o.isCompleted),
              scale: .98,
              selected: o.isCompleted,
              semanticLabel: o.description,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                child: Row(children: [
                  AnimatedContainer(
                    duration: dur,
                    curve: AppMotion.standard,
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: on ? ok : Colors.transparent,
                      borderRadius: BorderRadius.circular(on ? 9 : 14),
                      border: on ? null : Border.all(color: c.outline, width: 2),
                    ),
                    child: on
                        ? Center(child: LineIcon('check', size: 17, color: c.surface))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: AppMotion.of(context, AppMotion.medium),
                      style: TextStyle(
                          fontFamily: AppType.body,
                          fontSize: 15.5,
                          height: 1.35,
                          color: o.isCompleted ? c.onSurfaceVariant : c.onSurface,
                          decoration: on ? TextDecoration.lineThrough : null,
                          decorationColor: ok.withValues(alpha: .7),
                          decorationThickness: 2),
                      child: MarkedText(o.description,
                          mentions: mentions(o.description),
                          only: linked,
                          style: const TextStyle()),
                    ),
                  ),
                ]),
              ),
            );
          }),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.onSurface.withValues(alpha: .12), width: 1.4),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('journal-new-step'),
                controller: newStep,
                onSubmitted: (_) => onAdd(),
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.onSurface),
                decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    hintText: s.t('Новый шаг', 'New step'),
                    hintStyle: TextStyle(fontSize: 15, color: c.onSurfaceVariant)),
              ),
            ),
            JournalRound(
                key: const ValueKey('journal-add-step'),
                icon: 'plus',
                label: s.t('Добавить шаг', 'Add step'),
                size: 36,
                onTap: busy ? null : onAdd),
          ]),
        ),
        const SizedBox(height: 12),
        FlowSegment<QuestStatus>(
          key: const ValueKey('journal-reader-status'),
          values: QuestStatus.values,
          labels: [for (final st in QuestStatus.values) JournalLook.statusLabel(s, st)],
          selected: quest.status,
          keyPrefix: 'journal-status',
          onChanged: (st) {
            if (!busy && st != quest.status) onStatus(st);
          },
        ),
      ]),
    );
  }
}

class _Actor extends StatelessWidget {
  const _Actor({required this.entity, required this.onTap});
  final JournalEntity entity;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final a = JournalLook.accent(context, JournalLook.kindAccent(entity.kind));
    return Pressable(
      key: ValueKey('journal-actor-${entity.id}'),
      onTap: onTap,
      haptic: true,
      scale: .96,
      semanticLabel: '${s.kind(entity.kind)}: ${entity.name}',
      child: Container(
        width: 116,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: const Alignment(-.55, -1),
            end: const Alignment(.55, 1),
            colors: [JournalLook.mix(a, .16, c.surfaceContainerLow), c.surfaceContainerLow],
            stops: const [0, .8],
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: a.withValues(alpha: .24)),
            child: LineIcon(JournalLook.kindIcon(entity.kind), size: 19, color: a),
          ),
          const SizedBox(height: 8),
          Text(entity.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: c.onSurface)),
          const SizedBox(height: 3),
          Text(s.kind(entity.kind),
              style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _Thread extends StatelessWidget {
  const _Thread(
      {required this.entry, required this.why, required this.session, required this.onTap});
  final JournalEntry entry;
  final String why;
  final int? session;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final q = entry.quest;
    final a = JournalLook.accent(
        context,
        q != null
            ? JournalLook.statusAccent(q.status)
            : JournalLook.categoryAccent(entry.note!.category));
    return Pressable(
      key: ValueKey('journal-thread-${entry.key}'),
      onTap: onTap,
      haptic: true,
      scale: .98,
      semanticLabel: entry.title,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        decoration: BoxDecoration(
            color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          JournalSeal(
              icon: q != null
                  ? JournalLook.statusIcon(q.status)
                  : JournalLook.categoryIcon(entry.note!.category),
              accent: a,
              size: JournalSealSize.sm),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.title,
                  style: TextStyle(
                      fontSize: 15, height: 1.25, fontWeight: FontWeight.w600, color: c.onSurface)),
              const SizedBox(height: 3),
              Text(
                  [why, if (session != null) s.t('сессия $session', 'session $session')]
                      .join(' · '),
                  style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant)),
            ]),
          ),
          LineIcon('forward', size: 18, color: c.onSurfaceVariant),
        ]),
      ),
    );
  }
}
