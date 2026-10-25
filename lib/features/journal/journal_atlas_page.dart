import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/journal/journal_graph.dart';
import '../../core/journal/journal_service.dart';
import '../../core/models/character.dart';
import '../../core/search/journal_search.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/companion_kit.dart';
import 'entity_editor.dart';
import 'journal_constellation.dart';
import 'journal_entity_sheet.dart';
import 'journal_entry_page.dart';
import 'journal_index.dart';
import 'journal_kit.dart';
import 'journal_strings.dart';

/// The Atlas: people, places and events of the story as a living
/// constellation, filtered by kind and name, with the chosen star's card,
/// the names it shares records with and its trail through the sessions.
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
  final _queryFocus = FocusNode();
  final _scroll = ScrollController();
  final _starsKey = GlobalKey();
  final _off = <JournalEntityKind>{};
  bool _titled = false;

  @override
  void initState() {
    super.initState();
    _queryFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _queryFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _select(String? id) => setState(() => _selected = id);

  void _toStar(String id) {
    if (_selected != id) {
      HapticFeedback.selectionClick();
      _select(id);
    }
    final ctx = _starsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: .3,
          duration: AppMotion.of(context, AppMotion.gentleSettle),
          curve: AppMotion.gentleCurve);
    }
  }

  Future<void> _edit(JournalEntity? entity) async {
    final s = JournalStrings(context);
    final result = await editJournalEntity(context,
        entity: entity, onDelete: entity == null ? null : () => _delete(entity));
    if (result == null || !mounted) return;
    try {
      await JournalService.updateEntity(widget.character, result);
      if (mounted) setState(() => _selected = result.id);
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, s.t('Не удалось сохранить имя', 'Could not save the name'));
      }
    }
  }

  Future<void> _delete(JournalEntity entity) async {
    final s = JournalStrings(context);
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(s.t('Убрать из Атласа?', 'Remove from the Atlas?')),
                content: Text(s.t(
                    'Записи останутся. Их связи с этим именем будут убраны.',
                    'Entries remain. Their ties to this name will be removed.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(s.t('Отмена', 'Cancel'))),
                  TextButton(
                      key: const ValueKey('journal-entity-delete-confirm'),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(s.t('Убрать', 'Remove')))
                ]));
    if (yes != true || !mounted) return;
    try {
      await JournalService.deleteEntity(widget.character, entity.id);
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _selected = null);
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, s.t('Не удалось убрать имя', 'Could not remove the name'));
      }
    }
  }

  void _focus(JournalEntity entity) {
    HapticFeedback.lightImpact();
    JournalFocus.request.value = entity.id;
    final home = JournalFocus.home;
    if (home != null && home.isActive) {
      Navigator.popUntil(context, (r) => r == home);
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _open(String key) async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => JournalEntryPage(character: widget.character, entryKey: key)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final index = JournalIndex(widget.character);
    final graph = index.graph;
    if (_selected != null && graph.entity(_selected!) == null) _selected = null;
    final search = JournalSearch(_query.text);
    final shown = {
      for (final e in graph.entities)
        if (!_off.contains(e.kind) && search.matches([e.name, e.description, ...e.aliases])) e.id
    };
    final ties = <JournalTie>[];
    final list = graph.entities;
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final n = index.entries.where((r) {
          final ids = graph.forRecord(r.key).entities;
          return ids.contains(list[i].id) && ids.contains(list[j].id);
        }).length;
        if (n > 0) ties.add(JournalTie(list[i].id, list[j].id, n));
      }
    }
    final weight = {for (final e in list) e.id: index.recordsOf(e.id).length};
    final selected = _selected == null ? null : graph.entity(_selected!);
    final top = MediaQuery.paddingOf(context).top;
    final a1 = JournalLook.accent(context, 1);
    return Scaffold(
      // Fields here sit at the top or in sheets over the page; the page never
      // resizes for the keyboard, so it is not laid out again on every frame
      // of the keyboard's slide.
      resizeToAvoidBottomInset: false,
      body: Stack(children: [
        NotificationListener<ScrollUpdateNotification>(
          onNotification: (n) {
            final titled = n.metrics.pixels > 96;
            if (n.depth == 0 && titled != _titled) setState(() => _titled = titled);
            return false;
          },
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(
                16, top + JournalTopBar.height + 16, 16, 40 + MediaQuery.paddingOf(context).bottom),
            children: [
              Text(journalUpper(widget.character.name),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: journalCap(context, a1)),
              const SizedBox(height: 6),
              Text(s.t('Атлас', 'Atlas'),
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 46,
                      height: .95,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -2.07,
                      color: c.onSurface)),
              const SizedBox(height: 8),
              Text(
                  s.t('Люди, места и события — и как они связаны записями.',
                      'People, places and events — and how entries tie them together.'),
                  style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
              const SizedBox(height: 14),
              JournalSearchField(
                  controller: _query,
                  focus: _queryFocus,
                  hint: s.t('Найти имя или место', 'Find a name or a place'),
                  onChanged: () => setState(() {})),
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: MediaQuery.sizeOf(context).width,
                  maxWidth: MediaQuery.sizeOf(context).width,
                  child: Transform.translate(
                    offset: const Offset(-16, 0),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      itemCount: JournalEntityKind.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final kind = JournalEntityKind.values[i];
                        return Center(
                          child: _KindChip(
                              kind: kind,
                              count: list.where((e) => e.kind == kind).length,
                              off: _off.contains(kind),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _off.contains(kind) ? _off.remove(kind) : _off.add(kind));
                              }),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                key: _starsKey,
                height: 340,
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: MediaQuery.sizeOf(context).width,
                  maxWidth: MediaQuery.sizeOf(context).width,
                  child: Transform.translate(
                    offset: const Offset(-16, 0),
                    child: list.isEmpty
                        ? Center(
                            child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                                s.t('Имена появятся, когда журнал узнает их в записях. Можно добавить своё — кнопкой «+».',
                                    'Names appear once the journal knows them in entries. Add your own with «+».'),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                          ))
                        : JournalConstellation(
                            key: const ValueKey('journal-constellation'),
                            entities: list,
                            ties: ties,
                            weight: weight,
                            shown: shown,
                            selected: _selected,
                            onSelect: _select),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.long),
                switchInCurve: AppMotion.snappyCurve,
                transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                        position: Tween(begin: const Offset(0, .04), end: Offset.zero)
                            .animate(animation),
                        child: child)),
                layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current]),
                child: selected == null
                    ? JournalDashed(
                        key: const ValueKey('atlas-empty'),
                        color: c.onSurface.withValues(alpha: .14),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Center(
                            child: Text(
                                s.t('Коснитесь звезды — здесь появится её история.',
                                    'Tap a star — its story appears here.'),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                          ),
                        ),
                      )
                    : _Detail(
                        key: ValueKey('atlas-entity-${selected.id}'),
                        index: index,
                        entity: selected,
                        onEdit: () => _edit(selected),
                        onFocus: () => _focus(selected),
                        onName: _toStar,
                        onOpen: _open),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: JournalTopBar(
            titled: _titled,
            title: s.t('Атлас', 'Atlas'),
            leading: JournalRound(
                key: const ValueKey('atlas-exit'),
                icon: 'back',
                label: s.t('Назад', 'Back'),
                onTap: () => Navigator.maybePop(context)),
            actions: [
              JournalRound(
                  key: const ValueKey('atlas-new'),
                  icon: 'plus',
                  label: s.t('Новое имя', 'New name'),
                  onTap: () => _edit(null)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind, required this.count, required this.off, required this.onTap});
  final JournalEntityKind kind;
  final int count;
  final bool off;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final a = JournalLook.accent(context, JournalLook.kindAccent(kind));
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return Pressable(
      key: ValueKey('atlas-kind-${kind.name}'),
      onTap: onTap,
      scale: .95,
      selected: !off,
      semanticLabel: '${JournalLook.kindPlural(s, kind)}: $count',
      child: AnimatedContainer(
        duration: dur,
        curve: AppMotion.standard,
        height: 38,
        padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
        decoration: BoxDecoration(
          color: off ? Colors.transparent : JournalLook.mix(a, .16, c.surfaceContainerLow),
          borderRadius: BorderRadius.circular(off ? 19 : 12),
          border: Border.all(
              color: off ? c.onSurface.withValues(alpha: .14) : Colors.transparent, width: 1.3),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: dur,
            curve: AppMotion.standard,
            width: 26,
            height: 26,
            decoration: BoxDecoration(
                color: off ? c.onSurface.withValues(alpha: .08) : a,
                borderRadius: BorderRadius.circular(off ? 13 : 8)),
            child: Center(
                child: LineIcon(JournalLook.kindIcon(kind),
                    size: 15, color: off ? c.onSurfaceVariant : c.surface)),
          ),
          const SizedBox(width: 7),
          Text(JournalLook.kindPlural(s, kind),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: off ? c.onSurfaceVariant : c.onSurface)),
          const SizedBox(width: 7),
          Text('$count', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(
      {super.key,
      required this.index,
      required this.entity,
      required this.onEdit,
      required this.onFocus,
      required this.onName,
      required this.onOpen});
  final JournalIndex index;
  final JournalEntity entity;
  final VoidCallback onEdit, onFocus;
  final ValueChanged<String> onName, onOpen;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final a = JournalLook.accent(context, JournalLook.kindAccent(entity.kind));
    final trail = index.trailOf(entity.id), together = index.together(entity.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(30)),
        child: Stack(children: [
          Positioned(
            right: -110,
            top: -140,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                      colors: [a.withValues(alpha: .3), a.withValues(alpha: 0)], stops: const [0, .66]),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                JournalSeal(
                    icon: JournalLook.kindIcon(entity.kind),
                    accent: a,
                    size: JournalSealSize.lg,
                    dimension: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        journalUpper([
                          s.kind(entity.kind),
                          if (entity.aliases.isNotEmpty) entity.aliases.join(', ')
                        ].join(' · ')),
                        style: journalCap(context, a)),
                    const SizedBox(height: 6),
                    Text(entity.name,
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 30,
                            height: 1.02,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.9,
                            color: c.onSurface)),
                  ]),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: JournalRound(
                      key: const ValueKey('atlas-edit'),
                      icon: 'edit',
                      label: s.t('Изменить', 'Edit'),
                      size: 36,
                      onTap: onEdit),
                ),
              ]),
              if (entity.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(entity.description,
                    style: TextStyle(fontSize: 15, height: 1.5, color: c.onSurface.withValues(alpha: .84))),
              ],
              const SizedBox(height: 12),
              JournalStats(records: trail.length, together: together.length, strings: s),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ToneButton(
                    key: const ValueKey('atlas-focus'),
                    label: s.t('Фокус журнала', 'Focus the journal'),
                    icon: const LineIcon('search', size: 16),
                    kind: ToneKind.tonal,
                    height: 38,
                    fontSize: 13,
                    onPressed: onFocus),
              ),
            ]),
          ),
        ]),
      ),
      if (together.isNotEmpty) ...[
        const SizedBox(height: 18),
        JournalHeading(s.t('Вместе в записях', 'Together in entries')),
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final (e, _) in together) JournalToken(entity: e, onTap: () => onName(e.id)),
        ]),
      ],
      const SizedBox(height: 18),
      JournalHeading(s.t('След истории', 'Story trail'), count: s.t('по сессиям', 'by session')),
      const SizedBox(height: 6),
      if (trail.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(s.t('Пока ни одной записи.', 'No entries yet.'),
              style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
        )
      else
        JournalTrail(index: index, records: trail, ring: c.surface, onOpen: onOpen),
    ]);
  }
}
