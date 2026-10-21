import '../../core/ui/app_menu_style.dart';
import 'package:flutter/material.dart';
import '../../core/ui/companion_surface.dart';
import 'package:flutter/services.dart';
import '../../core/journal/journal_service.dart';
import '../../core/journal/journal_graph.dart';
import '../../core/models/character.dart';
import '../../core/models/quest.dart';
import '../../core/models/journal_note.dart';
import '../../core/ui/app_snack_bar.dart';
import 'journal_entry_editor.dart';
import 'journal_entry_tile.dart';
import 'journal_atlas_page.dart';
import 'journal_strings.dart';
import 'journal_selection.dart';
import 'entity_editor.dart';

class JournalEntryPage extends StatefulWidget {
  const JournalEntryPage(
      {super.key, required this.character, required this.entryKey});
  final Character character;
  final String entryKey;
  @override
  State<JournalEntryPage> createState() => _JournalEntryPageState();
}

class _JournalEntryPageState extends State<JournalEntryPage> {
  bool _busy = false;
  JournalEntry? get _entry {
    for (final e in JournalService.entries(widget.character)) {
      if (e.key == widget.entryKey) return e;
    }
    return null;
  }

  Future<void> _change(Quest quest) async {
    final s = JournalStrings(context);
    setState(() => _busy = true);
    try {
      await JournalService.save(widget.character, JournalEntry.quest(quest),
          links: JournalService.graph(widget.character)
              .forRecord(widget.entryKey));
      HapticFeedback.selectionClick();
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context,
            s.t('Не удалось сохранить изменение', 'Could not save the change'));
      }
    }
    if (mounted) setState(() => _busy = false);
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
    if (!mounted || _busy) return;
    final entry = _entry;
    if (entry == null) return;
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

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final entry = _entry;
    if (entry == null) {
      return Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          body: Center(child: Text(s.t('Запись удалена', 'Entry deleted'))));
    }
    final graph = JournalService.graph(widget.character);
    final links = graph.forRecord(entry.key);
    final all = JournalService.entries(widget.character);
    final related = all
        .where((other) =>
            other.key != entry.key &&
            (links.records.contains(other.key) ||
                graph.forRecord(other.key).records.contains(entry.key) ||
                graph
                    .forRecord(other.key)
                    .entities
                    .intersection(links.entities)
                    .isNotEmpty))
        .toList();
    return Scaffold(
        appBar: AppBar(
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(entry.quest == null
                ? s.t('Запись', 'Note')
                : s.t('Задание', 'Quest')),
            actions: [
              IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: s.t('Редактировать', 'Edit'),
                  onPressed: _busy
                      ? null
                      : () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute<bool>(
                                  builder: (_) => JournalEntryEditor(
                                      character: widget.character,
                                      entry: entry)));
                          if (mounted) setState(() {});
                        }),
              PopupMenuButton<String>(
                  tooltip: s.t('Действия', 'Actions'),
                  onSelected: (_) async {
                    final remove = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                                title: Text(
                                    s.t('Удалить запись?', 'Delete entry?')),
                                content: Text(entry.title),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(s.t('Отмена', 'Cancel'))),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(s.t('Удалить', 'Delete')))
                                ]));
                    if (remove != true || !mounted || !context.mounted) return;
                    try {
                      await JournalService.delete(widget.character, entry.key);
                      if (mounted && context.mounted) Navigator.pop(context);
                    } catch (_) {
                      if (mounted && context.mounted) {
                        AppSnackBar.error(
                            context,
                            s.t('Не удалось удалить запись',
                                'Could not delete the entry'));
                      }
                    }
                  },
                  itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'delete',
                            child: Text(s.t('Удалить', 'Delete')))
                      ]),
            ]),
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
              Container(
                  key: const ValueKey('journal-reader-summary'),
                  padding: const EdgeInsets.all(24),
                  decoration: companionDecoration(context,
                      raised: true,
                      color: entry.quest != null
                          ? c.tertiaryContainer
                          : c.secondaryContainer,
                      shape: CompanionShape(
                          contour: entry.quest != null
                              ? CompanionContour.facet
                              : CompanionContour.fold)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                              entry.quest == null
                                  ? entry.note!.category.icon
                                  : Icons.flag_outlined,
                              size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  entry.quest == null
                                      ? s.ru
                                          ? entry.note!.category.displayNameRu
                                          : entry.note!.category.displayName
                                      : s.ru
                                          ? entry.quest!.status.displayNameRu
                                          : entry.quest!.status.displayName,
                                  style:
                                      Theme.of(context).textTheme.labelLarge)),
                          if (entry.note?.isPinned ?? false)
                            const Icon(Icons.push_pin_outlined, size: 18),
                        ]),
                        const SizedBox(height: 20),
                        Text(entry.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                    letterSpacing: -.6)),
                        const SizedBox(height: 18),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _ReaderBadge(
                              icon: Icons.calendar_today_outlined,
                              text:
                                  '${entry.date.day.toString().padLeft(2, '0')}.${entry.date.month.toString().padLeft(2, '0')}.${entry.date.year}'),
                          if (links.session != null)
                            _ReaderBadge(
                                icon: Icons.history,
                                text: s.t('Сессия ${links.session}',
                                    'Session ${links.session}')),
                        ]),
                      ])),
              if (entry.image != null) ...[
                const SizedBox(height: 20),
                journalImage(context, entry.image!,
                    height: 240, width: double.infinity)
              ],
              if (entry.text.isNotEmpty) ...[
                const SizedBox(height: 22),
                _ReaderSection(
                    sectionKey: const ValueKey('journal-reader-content'),
                    icon: Icons.subject,
                    title: s.t('Содержание', 'Content'),
                    child: SelectableText(entry.text,
                        contextMenuBuilder: (context, state) =>
                            journalSelectionToolbar(
                                context, state, _linkSelected, enabled: !_busy),
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.7)))
              ],
              if (entry.note?.tags.isNotEmpty ?? false) ...[
                const SizedBox(height: 22),
                _ReaderSection(
                    sectionKey: const ValueKey('journal-reader-tags'),
                    icon: Icons.sell_outlined,
                    title: s.t('Метки', 'Tags'),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final tag in entry.note!.tags)
                        _ReaderBadge(icon: Icons.tag, text: tag),
                    ])),
              ],
              if (entry.quest case final q?) ...[
                if (q.objectives.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _ReaderSection(
                      sectionKey: const ValueKey('journal-reader-objectives'),
                      icon: Icons.checklist_rounded,
                      title: s.t('Шаги задания', 'Quest steps'),
                      trailing: Text(
                          '${q.completedObjectivesCount}/${q.objectives.length}',
                          style: Theme.of(context).textTheme.labelLarge),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TweenAnimationBuilder<double>(
                                tween:
                                    Tween(begin: q.progress, end: q.progress),
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 240),
                                builder: (_, progress, __) => ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 5,
                                        color: c.tertiary,
                                        backgroundColor:
                                            c.surfaceContainerHighest))),
                            const SizedBox(height: 16),
                            for (var i = 0; i < q.objectives.length; i++)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                      color: q.objectives[i].isCompleted
                                          ? c.secondaryContainer
                                              .withValues(alpha: .45)
                                          : c.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      clipBehavior: Clip.antiAlias,
                                      child: CheckboxListTile(
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          contentPadding:
                                              const EdgeInsets.fromLTRB(
                                                  6, 8, 14, 8),
                                          title: Text(q.objectives[i].description,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(
                                                      height: 1.45,
                                                      color: q.objectives[i]
                                                              .isCompleted
                                                          ? c.onSurfaceVariant
                                                          : c.onSurface,
                                                      decoration: q
                                                              .objectives[i]
                                                              .isCompleted
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null)),
                                          value: q.objectives[i].isCompleted,
                                          onChanged: _busy
                                              ? null
                                              : (value) {
                                                  final copy = Quest.fromJson(
                                                      q.toJson());
                                                  copy.objectives[i]
                                                      .isCompleted = value!;
                                                  _change(copy);
                                                }))),
                          ])),
                ],
                const SizedBox(height: 22),
                _ReaderSection(
                    sectionKey: const ValueKey('journal-reader-status'),
                    icon: Icons.flag_outlined,
                    title: s.t('Состояние задания', 'Quest state'),
                    child: DropdownButtonFormField<QuestStatus>(
                        borderRadius: AppMenuStyle.radius,
                        dropdownColor: AppMenuStyle.background(context),
                        elevation: 4,
                        key: ValueKey(q.status),
                        initialValue: q.status,
                        decoration: InputDecoration(
                            labelText: s.t('Статус задания', 'Quest status')),
                        items: [
                          for (final status in QuestStatus.values)
                            DropdownMenuItem(
                                value: status,
                                child: Text(s.ru
                                    ? status.displayNameRu
                                    : status.displayName))
                        ],
                        onChanged: _busy
                            ? null
                            : (status) {
                                if (status == null) return;
                                final copy = Quest.fromJson(q.toJson())
                                  ..status = status;
                                copy.completedAt = status == QuestStatus.active
                                    ? null
                                    : DateTime.now();
                                _change(copy);
                              })),
              ],
              if (links.entities.isNotEmpty) ...[
                const SizedBox(height: 22),
                _ReaderSection(
                    sectionKey: const ValueKey('journal-reader-stories'),
                    icon: Icons.auto_stories_outlined,
                    title: s.t('В этой истории', 'In this story'),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final id in links.entities)
                        if (graph.entity(id) case final entity?)
                          ActionChip(
                              avatar: Icon(s.icon(entity.kind), size: 18),
                              label: Text(entity.name),
                              onPressed: () async {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) => JournalAtlasPage(
                                            character: widget.character,
                                            selected: id)));
                                if (mounted) setState(() {});
                              })
                    ])),
              ],
              const SizedBox(height: 22),
              _ReaderSection(
                  sectionKey: const ValueKey('journal-reader-related'),
                  icon: Icons.link,
                  title: s.t('Связанные материалы', 'Related entries'),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (related.isEmpty)
                          Text(
                              s.t('Связи можно добавить при редактировании.',
                                  'Add connections while editing.'),
                              style: TextStyle(color: c.onSurfaceVariant)),
                        for (final other in related)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                  color: c.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  clipBehavior: Clip.antiAlias,
                                  child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      leading: Icon(other.quest == null ? Icons.description_outlined : Icons.flag_outlined,
                                          size: 20),
                                      title: Text(other.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(height: 1.35)),
                                      subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                              links.records.contains(other.key)
                                                  ? s.t(
                                                      'Связано тобой', 'Linked by you')
                                                  : graph
                                                          .forRecord(other.key)
                                                          .records
                                                          .contains(entry.key)
                                                      ? s.t(
                                                          'Ссылка на эту запись',
                                                          'Links to this entry')
                                                      : s.t('Общее упоминание',
                                                          'Shared mention'),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(color: c.onSurfaceVariant))),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () async {
                                        HapticFeedback.selectionClick();
                                        await Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    JournalEntryPage(
                                                        character:
                                                            widget.character,
                                                        entryKey: other.key)));
                                        if (mounted) setState(() {});
                                      }))),
                      ])),
            ])));
  }
}

class _ReaderSection extends StatelessWidget {
  const _ReaderSection(
      {required this.sectionKey,
      required this.icon,
      required this.title,
      required this.child,
      this.trailing});
  final Key sectionKey;
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
        key: sectionKey,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(26)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: c.primary),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600))),
            if (trailing != null) trailing!
          ]),
          const SizedBox(height: 18),
          child,
        ]));
  }
}

class _ReaderBadge extends StatelessWidget {
  const _ReaderBadge({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Tooltip(
        message: text,
        child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 88),
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(11)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 14, color: c.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Flexible(
                      child: Text(text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium))
                ]))));
  }
}
