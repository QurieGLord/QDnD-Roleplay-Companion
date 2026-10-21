import 'package:flutter/material.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/ui/companion_motion.dart';
import 'package:flutter/services.dart';
import '../../core/journal/journal_graph.dart';
import '../../core/journal/journal_service.dart';
import '../../core/models/character.dart';
import '../../core/search/journal_search.dart';
import '../../core/ui/app_snack_bar.dart';
import 'entity_editor.dart';
import 'journal_entry_page.dart';
import 'journal_story_carousel.dart';
import 'journal_strings.dart';

class JournalAtlasPage extends StatefulWidget {
  const JournalAtlasPage({super.key, required this.character, this.selected});
  final Character character;
  final String? selected;
  @override
  State<JournalAtlasPage> createState() => _JournalAtlasPageState();
}

class _JournalAtlasPageState extends State<JournalAtlasPage> {
  late String? _selected = widget.selected;
  final _query = TextEditingController();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _select(String id) {
    if (_selected == id) return;
    setState(() => _selected = id);
    HapticFeedback.selectionClick();
  }

  Future<void> _edit(JournalEntity? entity) async {
    final result = await editJournalEntity(context, entity: entity);
    if (result == null || !mounted) return;
    try {
      await JournalService.updateEntity(widget.character, result);
      if (mounted) setState(() => _selected = result.id);
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            JournalStrings(context)
                .t('Не удалось сохранить историю', 'Could not save the story'));
      }
    }
  }

  Future<void> _delete(JournalEntity entity) async {
    final s = JournalStrings(context);
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(s.t('Удалить историю?', 'Delete story?')),
                content: Text(s.t(
                    'Записи останутся. Их привязки к этой истории будут убраны.',
                    'Entries remain. Their connections to this story will be removed.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(s.t('Отмена', 'Cancel'))),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(s.t('Удалить', 'Delete')))
                ]));
    if (yes != true || !mounted) return;
    try {
      await JournalService.deleteEntity(widget.character, entity.id);
      if (mounted) setState(() => _selected = null);
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context,
            s.t('Не удалось удалить историю', 'Could not delete the story'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context);
    final graph = JournalService.graph(widget.character),
        all = JournalService.entries(widget.character);
    if (graph.entity(_selected ?? '') == null) {
      _selected = graph.entities.firstOrNull?.id;
    }
    final catalogue = graph.entities
        .where((e) => JournalSearch(_query.text)
            .matches([e.name, e.description, ...e.aliases]))
        .toList();
    final shown = catalogue.any((e) => e.id == _selected)
        ? _selected
        : catalogue.firstOrNull?.id;
    final entity = graph.entity(shown ?? '');
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return Scaffold(
        appBar: AppBar(
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
                key: const ValueKey('atlas-exit'),
                icon: const Icon(Icons.arrow_back),
                tooltip: s.t('Назад', 'Back'),
                onPressed: () => Navigator.pop(context)),
            title: Text(s.t('Атлас историй', 'Story atlas')),
            actions: [
              IconButton(
                  onPressed: () => _edit(null),
                  icon: const Icon(Icons.add),
                  tooltip: s.t('Новая история', 'New story')),
              if (entity != null)
                PopupMenuButton<String>(
                    tooltip: s.t('История', 'Story'),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _edit(entity);
                      } else {
                        _delete(entity);
                      }
                    },
                    itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'edit',
                              child: Text(
                                  s.t('Об этой истории', 'About this story'))),
                          PopupMenuItem(
                              value: 'delete',
                              child: Text(s.t('Удалить', 'Delete')))
                        ]),
            ]),
        body: SafeArea(
            child: CompanionEntrance(
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
              Text(s.t('Связи твоей истории', 'Your story, connected'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800, letterSpacing: -.7)),
              const SizedBox(height: 6),
              Text(
                  s.t('Люди, места и события — в контексте записей.',
                      'People, places and events, with the entries behind them.'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: s.t('Найти историю', 'Find a story'))),
              const SizedBox(height: 14),
              if (catalogue.isEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(graph.entities.isEmpty
                        ? s.t(
                            'Истории появятся, когда ты подтвердишь новое имя в записи. Можно добавить свою здесь.',
                            'Stories appear when you confirm a new name in an entry. You can also add one here.')
                        : s.t('История не найдена', 'Story not found')))
              else
                JournalStoryCarousel(
                    entities: catalogue,
                    selected: shown,
                    count: (id) => all
                        .where(
                            (e) => graph.forRecord(e.key).entities.contains(id))
                        .length,
                    onSelected: _select),
              const SizedBox(height: 20),
              // Both the summary and its sources share one size/fade transition.
              // Outgoing content is painted below the incoming content without layout jumps.
              AnimatedSize(
                  key: const ValueKey('atlas-content-size'),
                  duration: duration,
                  reverseDuration: duration,
                  alignment: Alignment.topCenter,
                  curve: Curves.easeInOutCubic,
                  child: AnimatedSwitcher(
                      duration: duration,
                      layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.topCenter,
                              clipBehavior: Clip.none,
                              children: [
                                for (final child in previous.reversed.take(1))
                                  Positioned(
                                      top: 0, left: 0, right: 0, child: child),
                                if (current != null) current,
                              ]),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: entity == null
                          ? const SizedBox.shrink()
                          : _AtlasContent(
                              key: ValueKey(entity.id),
                              entity: entity,
                              graph: graph,
                              entries: all,
                              onSelect: _select,
                              onEntry: (key) async {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) => JournalEntryPage(
                                            character: widget.character,
                                            entryKey: key)));
                                if (mounted) setState(() {});
                              }))),
            ]))));
  }
}

class _AtlasContent extends StatelessWidget {
  const _AtlasContent(
      {super.key,
      required this.entity,
      required this.graph,
      required this.entries,
      required this.onSelect,
      required this.onEntry});
  final JournalEntity entity;
  final JournalGraph graph;
  final List<JournalEntry> entries;
  final ValueChanged<String> onSelect, onEntry;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final related = entries
        .where((e) => graph.forRecord(e.key).entities.contains(entity.id))
        .toList()
      ..sort((a, b) {
        final aa = graph.forRecord(a.key).session,
            bb = graph.forRecord(b.key).session;
        return aa != null && bb != null
            ? aa.compareTo(bb)
            : a.date.compareTo(b.date);
      });
    // Count shared sources once instead of scanning every source for every entity.
    final sharedCounts = <String, int>{};
    for (final entry in related) {
      for (final id in graph.forRecord(entry.key).entities) {
        if (id != entity.id) {
          sharedCounts.update(id, (count) => count + 1, ifAbsent: () => 1);
        }
      }
    }
    final neighbors =
        graph.entities.where((e) => sharedCounts.containsKey(e.id)).toList();
    final t = Theme.of(context);
    String countWord(int value, {bool connection = false}) {
      if (!s.ru) {
        return connection
            ? (value == 1 ? 'connection' : 'connections')
            : (value == 1 ? 'entry' : 'entries');
      }
      final last = value % 10, hundred = value % 100;
      final form = hundred >= 11 && hundred <= 14
          ? 2
          : last == 1
              ? 0
              : last >= 2 && last <= 4
                  ? 1
                  : 2;
      return (connection
          ? ['пересечение', 'пересечения', 'пересечений']
          : ['запись', 'записи', 'записей'])[form];
    }

    Widget metric(String label, int value) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$value',
              style: t.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 7),
          Flexible(
              child: Text(label,
                  style: t.textTheme.bodySmall
                      ?.copyWith(color: c.onSurfaceVariant))),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CompanionSurface(
          key: ValueKey('atlas-entity-${entity.id}'),
          contour: CompanionContour.focus,
          raised: true,
          color: c.secondaryContainer,
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: companionDecoration(context,
                      color: c.surface,
                      shape:
                          const CompanionShape(contour: CompanionContour.fold)),
                  child:
                      Icon(s.icon(entity.kind), size: 28, color: c.secondary)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(s.kind(entity.kind),
                        style: t.textTheme.labelMedium
                            ?.copyWith(color: c.onSurfaceVariant)),
                    const SizedBox(height: 5),
                    Text(entity.name,
                        style: t.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                            letterSpacing: -.8)),
                  ])),
            ]),
            if (entity.description.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(entity.description,
                  style: t.textTheme.bodyLarge?.copyWith(height: 1.45)),
            ],
            if (entity.aliases.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(entity.aliases.join(' · '),
                  style: t.textTheme.bodySmall
                      ?.copyWith(color: c.onSurfaceVariant)),
            ],
            const SizedBox(height: 18),
            Divider(
                height: 1, color: c.onSurfaceVariant.withValues(alpha: .15)),
            const SizedBox(height: 14),
            Wrap(spacing: 22, runSpacing: 12, children: [
              metric(countWord(related.length), related.length),
              metric(countWord(neighbors.length, connection: true),
                  neighbors.length),
            ]),
          ])),
      if (neighbors.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text(s.t('Вместе в записях', 'Together in entries'),
            style:
                t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        for (final e in neighbors) ...[
          CompanionSurface(
              quiet: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: () => onSelect(e.id),
              child: Row(children: [
                Icon(s.icon(e.kind), color: c.secondary, size: 25),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(e.name,
                          style: t.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                          s.t('Общих записей: ${sharedCounts[e.id]}',
                              'Shared entries: ${sharedCounts[e.id]}'),
                          style: t.textTheme.bodySmall
                              ?.copyWith(color: c.onSurfaceVariant)),
                    ])),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 22),
              ])),
          const SizedBox(height: 8),
        ],
        Text(
            s.t('Общее упоминание не подтверждает сюжетную связь.',
                'A shared mention does not confirm a story relationship.'),
            style: t.textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ],
      const SizedBox(height: 26),
      Text(s.t('След истории', 'Story trail'),
          style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      if (related.isEmpty)
        Text(s.t(
            'Пока нет связанных записей. Добавь имя в текст или выбери эту историю в редакторе.',
            'No linked entries yet. Use the name in your text or choose this story in the editor.')),
      for (var i = 0; i < related.length; i++)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Stack(children: [
              if (i < related.length - 1)
                Positioned(
                    left: 12,
                    top: 24,
                    bottom: -12,
                    child: Container(
                        width: 2, color: c.secondary.withValues(alpha: .2))),
              Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: CompanionSurface(
                      quiet: true,
                      padding: const EdgeInsets.all(16),
                      onTap: () => onEntry(related[i].key),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                graph.forRecord(related[i].key).session != null
                                    ? s.t(
                                        'Сессия ${graph.forRecord(related[i].key).session}',
                                        'Session ${graph.forRecord(related[i].key).session}')
                                    : '${related[i].date.day}.${related[i].date.month}.${related[i].date.year}',
                                style: t.textTheme.labelMedium
                                    ?.copyWith(color: c.secondary)),
                            const SizedBox(height: 8),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: Text(related[i].title,
                                          style: t.textTheme.titleMedium
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w700))),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right_rounded,
                                      size: 20),
                                ]),
                            if (related[i].text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(related[i].text,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.textTheme.bodyMedium?.copyWith(
                                      color: c.onSurfaceVariant, height: 1.45)),
                            ],
                          ]))),
              Positioned(
                  left: 0,
                  top: 16,
                  child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: c.secondaryContainer),
                      child: Icon(
                          related[i].quest == null
                              ? Icons.history_edu_rounded
                              : Icons.flag_outlined,
                          size: 15,
                          color: c.secondary))),
            ])),
    ]);
  }
}
