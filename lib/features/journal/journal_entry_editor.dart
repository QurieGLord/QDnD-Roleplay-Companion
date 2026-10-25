import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../core/journal/journal_graph.dart';
import '../../core/journal/journal_links.dart';
import '../../core/journal/journal_service.dart';
import '../../core/models/character.dart';
import '../../core/models/journal_note.dart';
import '../../core/models/quest.dart';
import '../../core/search/journal_search.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/expressive_kit.dart';
import '../../core/ui/sheet_drag_region.dart' show KeyboardPadding;
import 'entity_editor.dart';
import 'journal_kit.dart';
import 'journal_selection.dart';
import 'journal_strings.dart';

/// The blank page: no boxes, just a title and the text. Names of the story
/// light up while the player types; new names are offered as they appear.
/// A glass toolbar holds the type, the session, the pin and the photo.
class JournalEntryEditor extends StatefulWidget {
  const JournalEntryEditor(
      {super.key, required this.character, this.entry, this.quest = false});
  final Character character;
  final JournalEntry? entry;
  final bool quest;
  @override
  State<JournalEntryEditor> createState() => _JournalEntryEditorState();
}

class _JournalEntryEditorState extends State<JournalEntryEditor> {
  late final _title = TextEditingController(text: widget.entry?.title ?? '');
  late final _text = MarkedTextController(text: widget.entry?.text ?? '');
  final _tag = TextEditingController();
  final _titleFocus = FocusNode();
  final _textFocus = FocusNode();
  late final _graph = JournalService.graph(widget.character);
  late final _links = widget.entry == null
      ? JournalRecordLinks(session: _graph.currentSession)
      : JournalRecordLinks.fromJson(
          _graph.forRecord(widget.entry!.key).toJson());
  late var _category = widget.entry?.note?.category ?? NoteCategory.general;
  late bool _pinned = widget.entry?.note?.isPinned ?? false;
  late String? _image = widget.entry?.image;
  late final _tags = List<String>.of(widget.entry?.note?.tags ?? []);
  late final _objectives = [
    for (final o in widget.entry?.quest?.objectives ?? <QuestObjective>[])
      TextEditingController(text: o.description),
    if (widget.entry == null && widget.quest) TextEditingController(),
  ];
  late final _completed = [
    for (final o in widget.entry?.quest?.objectives ?? <QuestObjective>[])
      o.isCompleted,
    if (widget.entry == null && widget.quest) false,
  ];
  final _newEntities = <JournalEntity>[];
  final _dismissed = <String>{};
  Timer? _timer;
  bool _saving = false, _dirty = false;
  Set<String> _known = {};
  bool get _isQuest =>
      widget.entry?.quest != null || (widget.entry == null && widget.quest);
  String get _allText => [
        _title.text,
        _text.text,
        ..._tags,
        ..._objectives.map((o) => o.text)
      ].join('\n');

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _text.addListener(_changed);
    for (final c in _objectives) {
      c.addListener(_changed);
    }
    _rematch();
    _known = _connected();
  }

  void _rematch() {
    _text.matcher = JournalMatcher(_graph.entities);
    _text.excluded = _links.excluded;
  }

  Set<String> _connected() => {
        ..._links.manual,
        ...JournalLinks.analyze(_allText, _graph.entities).automatic
      }.difference(_links.excluded);

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final now = _connected();
      if (now.difference(_known).isNotEmpty) HapticFeedback.selectionClick();
      _known = now;
      setState(() {});
    });
  }

  void _touch(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
      _text.excluded = _links.excluded;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _title.dispose();
    _text.dispose();
    _tag.dispose();
    _titleFocus.dispose();
    _textFocus.dispose();
    for (final c in _objectives) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _discard() async {
    if (!_dirty) return true;
    final s = JournalStrings(context);
    return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text(s.t('Оставить изменения?', 'Keep your changes?')),
                  content: Text(s.t(
                      'Можно вернуться к записи или закрыть её без сохранения.',
                      'Return to editing or close without saving.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(s.t('Продолжить', 'Keep editing'))),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(s.t('Не сохранять', 'Discard')))
                  ],
                )) ??
        false;
  }

  Future<void> _close() async {
    if (!_saving && await _discard() && mounted) {
      ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
      Navigator.pop(context);
    }
  }

  void _adopt(JournalEntity entity) {
    _touch(() {
      _graph.entities.add(entity);
      _newEntities.add(entity);
      _links.manual.add(entity.id);
      _links.excluded.remove(entity.id);
      _rematch();
    });
    _known = _connected();
  }

  /// A new name: who or what it is, in one tap.
  Future<void> _newName(String name) async {
    final s = JournalStrings(context);
    final field = TextEditingController(text: name);
    final picked = await showCompanionSheet<Object>(context,
        builder: (context) =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(s.t('Новое имя в истории', 'A new name in the story'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.secondary)),
              const SizedBox(height: 8),
              SheetHeading(s.t('Кто или что это?', 'Who or what is it?'),
                  subtitle: s.t(
                      'Журнал будет узнавать это имя в записях и покажет его в Атласе.',
                      'The journal will know this name in entries and show it in the Atlas.')),
              const SizedBox(height: 14),
              JournalField(
                  controller: field,
                  label: s.t('Имя', 'Name'),
                  fieldKey: const ValueKey('journal-new-name')),
              const SizedBox(height: 14),
              JournalKindGrid<JournalEntityKind>(
                  values: JournalEntityKind.values,
                  icon: JournalLook.kindIcon,
                  accent: JournalLook.kindAccent,
                  label: s.kind,
                  onPick: (k) => Navigator.pop(context, k)),
              const SizedBox(height: 14),
              ToneButton(
                  key: const ValueKey('journal-not-a-name'),
                  label: s.t('Это не имя', 'Not a name'),
                  height: 48,
                  expand: true,
                  onPressed: () => Navigator.pop(context, false)),
            ]));
    final typed = field.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) => field.dispose());
    if (!mounted || picked == null) return;
    if (picked == false) {
      setState(() => _dismissed.add(name));
      return;
    }
    HapticFeedback.lightImpact();
    final kind = picked as JournalEntityKind;
    final entity =
        JournalEntity(name: typed.isEmpty ? name : typed, kind: kind);
    if (entity.name != name) _dismissed.add(name);
    _adopt(entity);
    AppSnackBar.info(context,
        '${entity.name}: ${s.kind(kind).toLowerCase()} ${s.t('в Атласе', 'in the Atlas')}',
        clearQueue: true);
  }

  /// «Кто ещё здесь?»: names the text does not mention but the record is about.
  Future<void> _attach() async {
    final s = JournalStrings(context);
    await showCompanionSheet<void>(context,
        builder: (context) => StatefulBuilder(builder: (context, refresh) {
              final on = _connected();
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.t('Связать с историей', 'Link to the story'),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.secondary)),
                    const SizedBox(height: 8),
                    SheetHeading(s.t('Кто ещё здесь?', 'Who else is here?')),
                    const SizedBox(height: 14),
                    Wrap(spacing: 7, runSpacing: 7, children: [
                      for (final e in _graph.entities)
                        JournalToken(
                            key: ValueKey('journal-attach-${e.id}'),
                            entity: e,
                            on: on.contains(e.id),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _touch(() {
                                if (on.contains(e.id)) {
                                  _links.manual.remove(e.id);
                                  _links.excluded.add(e.id);
                                } else {
                                  _links.manual.add(e.id);
                                  _links.excluded.remove(e.id);
                                }
                              });
                              refresh(() {});
                            }),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: ToneButton(
                            label: s.t('Новое имя', 'New name'),
                            icon: const LineIcon('plus', size: 18),
                            height: 52,
                            expand: true,
                            onPressed: () async {
                              Navigator.pop(context);
                              final entity =
                                  await editJournalEntity(this.context);
                              if (entity != null && mounted) _adopt(entity);
                            }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ToneButton(
                            label: s.t('Готово', 'Done'),
                            kind: ToneKind.primary,
                            height: 52,
                            expand: true,
                            onPressed: () => Navigator.pop(context)),
                      ),
                    ]),
                  ]);
            }));
    if (mounted) setState(() => _known = _connected());
  }

  /// Threads: records tied to this one by hand.
  Future<void> _link() async {
    final s = JournalStrings(context);
    final entries = JournalService.entries(widget.character)
        .where((e) => e.key != widget.entry?.key)
        .toList();
    final query = TextEditingController();
    await showCompanionSheet<void>(context,
        builder: (context) => StatefulBuilder(builder: (context, refresh) {
              final c = Theme.of(context).colorScheme;
              final found = entries
                  .where((e) => JournalSearch(query.text).matches(e.fields))
                  .toList();
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.t('Нити', 'Threads'),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.secondary)),
                    const SizedBox(height: 8),
                    SheetHeading(s.t('Связать запись', 'Link an entry')),
                    const SizedBox(height: 12),
                    JournalField(
                        controller: query,
                        label: s.t('Найти запись', 'Find an entry'),
                        onChanged: (_) => refresh(() {})),
                    const SizedBox(height: 12),
                    for (final e in found)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _LinkRow(
                            entry: e,
                            session: _graph.records[e.key]?.session,
                            on: _links.records.contains(e.key),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _touch(() {
                                if (!_links.records.remove(e.key)) {
                                  _links.records.add(e.key);
                                }
                              });
                              refresh(() {});
                            }),
                      ),
                  ]);
            }));
    WidgetsBinding.instance.addPostFrameCallback((_) => query.dispose());
    if (mounted) setState(() {});
  }

  Future<void> _pickCategory() async {
    final s = JournalStrings(context);
    final picked = await showCompanionSheet<NoteCategory>(context,
        builder: (context) =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(s.t('Запись', 'Note'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.secondary)),
              const SizedBox(height: 8),
              SheetHeading(s.t('О чём она?', 'What is it about?')),
              const SizedBox(height: 14),
              JournalKindGrid<NoteCategory>(
                  values: NoteCategory.values,
                  selected: _category,
                  icon: JournalLook.categoryIcon,
                  accent: JournalLook.categoryAccent,
                  label: (c) => JournalLook.categoryLabel(s, c),
                  keyPrefix: 'journal-category',
                  onPick: (c) => Navigator.pop(context, c)),
            ]));
    if (picked != null && mounted) {
      HapticFeedback.selectionClick();
      _touch(() => _category = picked);
    }
  }

  Future<void> _pickImage() async {
    final s = JournalStrings(context);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (mounted && result?.files.single.path != null) {
        _touch(() => _image = result!.files.single.path);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            s.t('Не удалось открыть фото. Попробуй другой файл.',
                'Could not open the image. Try another file.'));
      }
    }
  }

  Future<void> _linkSelected(String text) async {
    final choice = await chooseSelectionStory(context, text, _graph.entities);
    if (!mounted || choice == null) return;
    if (choice == 'new') {
      await _newName(text);
      return;
    }
    HapticFeedback.selectionClick();
    _touch(() {
      _links.manual.add(choice);
      _links.excluded.remove(choice);
    });
  }

  Future<void> _save() async {
    if (_saving || _title.text.trim().isEmpty) return;
    final s = JournalStrings(context);
    _timer?.cancel();
    final pending = _tag.text.trim().replaceFirst(RegExp(r'^#'), '');
    if (pending.isNotEmpty && !_tags.contains(pending)) _tags.add(pending);
    setState(() => _saving = true);
    final id =
        widget.entry?.note?.id ?? widget.entry?.quest?.id ?? const Uuid().v4();
    final old = widget.entry?.quest;
    final entry = _isQuest
        ? JournalEntry.quest(Quest(
            id: id,
            title: _title.text.trim(),
            description: _text.text.trim(),
            status: old?.status ?? QuestStatus.active,
            imagePath: _image,
            createdAt: widget.entry?.date,
            completedAt: old?.completedAt,
            objectives: [
                for (var i = 0; i < _objectives.length; i++)
                  if (_objectives[i].text.trim().isNotEmpty)
                    QuestObjective(
                        description: _objectives[i].text.trim(),
                        isCompleted: _completed[i])
              ]))
        : JournalEntry.note(JournalNote(
            id: id,
            title: _title.text.trim(),
            content: _text.text.trim(),
            category: _category,
            imagePath: _image,
            tags: _tags.toList(),
            isPinned: _pinned,
            createdAt: widget.entry?.date));
    try {
      await JournalService.save(widget.character, entry,
          links: _links, newEntities: _newEntities);
      if (!mounted) return;
      _dirty = false;
      HapticFeedback.mediumImpact();
      // A word about the draft must not outlive it over the journal's dock.
      ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.error(
            context,
            s.t('Не удалось сохранить. Текст остался здесь — можно повторить.',
                'Could not save. Your draft is still here — you can retry.'));
      }
    }
  }

  void _addTag() {
    final tag = _tag.text.trim().replaceFirst(RegExp(r'^#'), '');
    if (tag.isEmpty || _tags.contains(tag)) return;
    HapticFeedback.lightImpact();
    _touch(() {
      _tags.add(tag);
      _tag.clear();
    });
  }

  void _addStep() {
    HapticFeedback.selectionClick();
    _touch(() {
      _objectives.add(TextEditingController()..addListener(_changed));
      _completed.add(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    _text.accentOf =
        (e) => JournalLook.accent(context, JournalLook.kindAccent(e.kind));
    _text.ink = c.onSurface;
    final analysis = JournalLinks.analyze(_allText, _graph.entities);
    final on = [
      for (final id in {..._links.manual, ...analysis.automatic}
          .difference(_links.excluded))
        if (_graph.entity(id) case final e?) e
    ];
    final off = [
      for (final id in _links.excluded)
        if (_graph.entity(id) case final e?) e
    ];
    final candidates =
        JournalLinks.candidates(_title.text, _text.text, _graph.entities)
            .where((n) => !_dismissed.contains(n))
            .toList();
    final records = JournalService.entries(widget.character);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final heading = widget.entry != null
        ? (_isQuest ? s.t('Задание', 'Quest') : s.t('Запись', 'Note'))
        : (_isQuest
            ? s.t('Новое задание', 'New quest')
            : s.t('Новая запись', 'New note'));
    final mini = journalCap(context, JournalLook.accent(context, 4));
    final plain = InputDecoration(
        isCollapsed: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintStyle: TextStyle(color: c.onSurface.withValues(alpha: .32)));
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(children: [
          // Only the lift reads the keyboard: the page is not rebuilt while
          // the keyboard slides.
          KeyboardPadding(
            child: AbsorbPointer(
              absorbing: _saving,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    16, top + JournalTopBar.height + 12, 16, 120 + bottom),
                children: [
                  TextField(
                    key: const ValueKey('journal-title'),
                    controller: _title,
                    focusNode: _titleFocus,
                    autofocus: widget.entry == null,
                    textCapitalization: TextCapitalization.sentences,
                    contextMenuBuilder: (context, state) =>
                        journalSelectionToolbar(context, state, _linkSelected),
                    maxLines: null,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 32,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.96,
                        color: c.onSurface),
                    decoration: plain.copyWith(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 2),
                        hintText: _isQuest
                            ? s.t('Что нужно сделать?', 'What needs doing?')
                            : s.t('Что случилось?', 'What happened?')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('journal-text'),
                    controller: _text,
                    focusNode: _textFocus,
                    minLines: 6,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    contextMenuBuilder: (context, state) =>
                        journalSelectionToolbar(context, state, _linkSelected),
                    style: TextStyle(
                        fontFamily: AppType.body,
                        fontSize: 17,
                        height: 1.62,
                        color: c.onSurface),
                    cursorColor: c.primary,
                    decoration: plain.copyWith(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 2),
                        hintText: s.t(
                            'Пишите как есть — имена людей и мест журнал узнает сам',
                            'Write as it comes — the journal knows the names of people and places')),
                  ),
                  const SizedBox(height: 12),
                  // What the journal recognised, and what it could add.
                  Container(
                    key: const ValueKey('journal-live'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: c.onSurface.withValues(alpha: .04),
                        borderRadius: BorderRadius.circular(24)),
                    child: CalmSize(
                      duration: AppMotion.gentleSettle,
                      curve: AppMotion.gentleCurve,
                      alignment: Alignment.topCenter,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (on.isEmpty && off.isEmpty && candidates.isEmpty)
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LineIcon('spark',
                                        size: 17,
                                        color: JournalLook.accent(context, 2)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                          s.t('Имена и места из текста появятся здесь — журнал свяжет запись с ними',
                                              'Names and places from the text appear here — the journal links the entry to them'),
                                          style: TextStyle(
                                              fontSize: 13.5,
                                              color: c.onSurfaceVariant)),
                                    ),
                                  ])
                            else ...[
                              Text(
                                  journalUpper(
                                      s.t('Узнано в тексте', 'Recognised')),
                                  style: mini),
                              const SizedBox(height: 8),
                              Wrap(
                                  key: const ValueKey('journal-connected'),
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: [
                                    for (final e in on)
                                      JournalPop(
                                        key: ValueKey('journal-on-${e.id}'),
                                        child: JournalToken(
                                            entity: e,
                                            on: true,
                                            onRemove: () {
                                              HapticFeedback.selectionClick();
                                              _touch(() {
                                                _links.manual.remove(e.id);
                                                _links.excluded.add(e.id);
                                              });
                                            }),
                                      ),
                                    for (final e in off)
                                      JournalToken(
                                          key: ValueKey('journal-off-${e.id}'),
                                          entity: e,
                                          off: true,
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            _touch(() =>
                                                _links.excluded.remove(e.id));
                                          }),
                                    _DashedChip(
                                        key: const ValueKey('journal-attach'),
                                        icon: 'plus',
                                        label: s.t('История', 'Story'),
                                        onTap: _attach),
                                  ]),
                              if (analysis.ambiguous.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                    journalUpper(s.t('Имя совпало — кто это?',
                                        'Same name — who is it?')),
                                    style: mini),
                                const SizedBox(height: 8),
                                for (final group in analysis.ambiguous)
                                  Wrap(spacing: 7, runSpacing: 7, children: [
                                    for (final e in group)
                                      JournalToken(
                                          entity: e,
                                          on: _links.manual.contains(e.id),
                                          onTap: () => _touch(() {
                                                for (final other in group) {
                                                  _links.manual
                                                      .remove(other.id);
                                                  _links.excluded.add(other.id);
                                                }
                                                _links.manual.add(e.id);
                                                _links.excluded.remove(e.id);
                                              })),
                                  ]),
                              ],
                              if (candidates.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                    journalUpper(
                                        s.t('Новые имена?', 'New names?')),
                                    style: mini),
                                const SizedBox(height: 8),
                                Wrap(spacing: 7, runSpacing: 7, children: [
                                  for (final name in candidates)
                                    JournalPop(
                                      key: ValueKey('suggest-new-$name'),
                                      child: _DashedChip(
                                          icon: 'plus',
                                          label: name,
                                          accent:
                                              JournalLook.accent(context, 2),
                                          onTap: () => _newName(name)),
                                    ),
                                ]),
                              ],
                            ],
                          ]),
                    ),
                  ),
                  if (_isQuest) ...[
                    const SizedBox(height: 24),
                    JournalHeading(s.t('Шаги', 'Steps'),
                        count: '${_objectives.length}'),
                    const SizedBox(height: 10),
                    for (var i = 0; i < _objectives.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          decoration: BoxDecoration(
                              color: c.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(18)),
                          child: Row(children: [
                            JournalCheck(
                                on: _completed[i],
                                ring: c.outline,
                                label: s.t('Шаг сделан', 'Step done'),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _touch(() => _completed[i] = !_completed[i]);
                                }),
                            Expanded(
                              child: TextField(
                                key: ObjectKey(_objectives[i]),
                                controller: _objectives[i],
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: c.onSurface),
                                decoration: plain.copyWith(
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    hintText: s.t('Шаг', 'Step')),
                              ),
                            ),
                            JournalRound(
                                icon: 'x',
                                label: s.t('Убрать шаг', 'Remove step'),
                                size: 36,
                                fill: Colors.transparent,
                                color: c.onSurfaceVariant,
                                onTap: () => _touch(() {
                                      _objectives.removeAt(i).dispose();
                                      _completed.removeAt(i);
                                    })),
                            const SizedBox(width: 2),
                          ]),
                        ),
                      ),
                    _AddLine(
                        key: const ValueKey('journal-add-objective'),
                        label: s.t('Шаг', 'Step'),
                        onTap: _addStep),
                  ],
                  const SizedBox(height: 18),
                  JournalHeading(s.t('Нити', 'Threads'),
                      count: s.t('записи, связанные с этой',
                          'entries tied to this one')),
                  const SizedBox(height: 10),
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    for (final key in _links.records)
                      for (final e in records.where((e) => e.key == key))
                        _RemovableChip(
                            icon: 'link',
                            label: e.title,
                            removeLabel: s.t('Убрать связь', 'Remove link'),
                            onRemove: () =>
                                _touch(() => _links.records.remove(key))),
                    _DashedChip(
                        key: const ValueKey('journal-link'),
                        icon: 'link',
                        label: s.t('Связать запись', 'Link an entry'),
                        accent: c.secondary,
                        onTap: _link),
                  ]),
                  if (!_isQuest) ...[
                    const SizedBox(height: 18),
                    JournalHeading(s.t('Метки', 'Tags')),
                    const SizedBox(height: 10),
                    Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final tag in _tags)
                            _RemovableChip(
                                label: '#$tag',
                                round: true,
                                removeLabel: s.t('Убрать метку', 'Remove tag'),
                                onRemove: () =>
                                    _touch(() => _tags.remove(tag))),
                          SizedBox(
                            width: 120,
                            height: 38,
                            child: TextField(
                              key: const ValueKey('journal-tags'),
                              controller: _tag,
                              onSubmitted: (_) => _addTag(),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: c.onSurface),
                              decoration: InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 11),
                                  hintText: s.t('+ метка', '+ tag'),
                                  hintStyle: TextStyle(
                                      fontSize: 13, color: c.onSurfaceVariant),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(19),
                                      borderSide: BorderSide(
                                          color: c.onSurface
                                              .withValues(alpha: .14),
                                          width: 1.4)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(19),
                                      borderSide: BorderSide(
                                          color: c.secondary, width: 1.5))),
                            ),
                          ),
                        ]),
                  ],
                  if (_image != null) ...[
                    const SizedBox(height: 18),
                    Stack(children: [
                      journalImage(context, _image!,
                          height: 180, width: double.infinity),
                      Positioned(
                          right: 10,
                          top: 10,
                          child: JournalRound(
                              icon: 'x',
                              label: s.t('Убрать фото', 'Remove image'),
                              size: 36,
                              fill: c.surface.withValues(alpha: .7),
                              onTap: () => _touch(() => _image = null))),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: JournalTopBar(
              titled: true,
              title: heading,
              leading: JournalRound(
                  key: const ValueKey('journal-close'),
                  icon: 'x',
                  label: s.t('Закрыть', 'Close'),
                  onTap: _saving ? null : _close),
              actions: [
                ToneButton(
                    key: const ValueKey('journal-save'),
                    label: s.t('Сохранить', 'Save'),
                    kind: ToneKind.primary,
                    height: 40,
                    fontSize: 13,
                    onPressed:
                        _saving || _title.text.trim().isEmpty ? null : _save),
              ],
            ),
          ),
          Positioned.fill(
            child: _KeyboardDock(
                child: _Tools(
              quest: _isQuest,
              category: _category,
              session: _links.session,
              pinned: _pinned,
              onCategory: _pickCategory,
              onSession: (n) {
                HapticFeedback.selectionClick();
                _touch(() => _links.session = n);
              },
              onPin: () {
                HapticFeedback.lightImpact();
                _touch(() => _pinned = !_pinned);
              },
              onPhoto: _pickImage,
            )),
          ),
        ]),
      ),
    );
  }
}

/// Holds the toolbar above the keyboard, or above the gesture bar when the
/// keyboard is away. Only this reads the keyboard while it slides.
class _KeyboardDock extends StatelessWidget {
  const _KeyboardDock({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bar = MediaQuery.viewPaddingOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
          padding: EdgeInsets.fromLTRB(
              12, 0, 12, 16 + (keyboard > 0 ? keyboard : bar)),
          child: child),
    );
  }
}

/// The writing toolbar floating over the page.
class _Tools extends StatelessWidget {
  const _Tools(
      {required this.quest,
      required this.category,
      required this.session,
      required this.pinned,
      required this.onCategory,
      required this.onSession,
      required this.onPin,
      required this.onPhoto});
  final bool quest, pinned;
  final NoteCategory category;
  final int? session;
  final VoidCallback onCategory, onPin, onPhoto;
  final ValueChanged<int?> onSession;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final a = JournalLook.accent(
        context,
        quest
            ? JournalLook.statusAccent(QuestStatus.active)
            : JournalLook.categoryAccent(category));
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    Widget icon(String key, String glyph, String label, Color tint, bool on,
            VoidCallback tap) =>
        Tooltip(
          message: label,
          child: Pressable(
            key: ValueKey(key),
            onTap: tap,
            scale: .94,
            selected: on,
            semanticLabel: label,
            child: SizedBox(
              width: 40,
              height: 48,
              child: Center(
                child: AnimatedContainer(
                  duration: dur,
                  curve: AppMotion.standard,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: on ? tint : c.onSurface.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(on ? 12 : 18)),
                  child: Center(
                      child: LineIcon(glyph,
                          size: 19,
                          color: on ? c.surface : c.onSurfaceVariant)),
                ),
              ),
            ),
          ),
        );
    final pill = Container(
      height: 48,
      padding: EdgeInsets.fromLTRB(6, 0, quest ? 14 : 12, 0),
      decoration: BoxDecoration(
          color: a.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: a.withValues(alpha: .26)),
          child: Center(
              child: LineIcon(
                  quest ? 'flag' : JournalLook.categoryIcon(category),
                  size: 19,
                  color: a)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
              quest
                  ? s.t('Задание', 'Quest')
                  : JournalLook.categoryLabel(s, category),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: c.onSurface)),
        ),
        if (!quest) ...[
          const SizedBox(width: 6),
          LineIcon('down', size: 15, color: c.onSurfaceVariant),
        ],
      ]),
    );
    return GlassSurface(
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Row(children: [
          Expanded(
            child: Row(children: [
              Flexible(
                child: quest
                    ? pill
                    : Pressable(
                        key: const ValueKey('journal-category'),
                        onTap: onCategory,
                        scale: .94,
                        haptic: true,
                        semanticLabel: s.t('Тип записи', 'Note type'),
                        child: pill),
              ),
              const SizedBox(width: 6),
              _SessionStep(session: session, onChanged: onSession),
            ]),
          ),
          if (!quest)
            icon('journal-pin', 'bookmark', s.t('Закрепить', 'Pin'),
                JournalLook.accent(context, 0), pinned, onPin),
          icon('journal-photo', 'image', s.t('Фото', 'Photo'),
              JournalLook.accent(context, 4), false, onPhoto),
        ]),
      ),
    );
  }
}

class _SessionStep extends StatelessWidget {
  const _SessionStep({required this.session, required this.onChanged});
  final int? session;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    Widget step(String glyph, String label, int by) => Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            key: ValueKey('journal-session-${by > 0 ? 'up' : 'down'}'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final next = ((session ?? 0) + by).clamp(0, 99);
              onChanged(next == 0 ? null : next);
            },
            child: SizedBox(
                width: 26,
                height: 40,
                child: Center(
                    child:
                        LineIcon(glyph, size: 16, color: c.onSurfaceVariant))),
          ),
        );
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          color: c.onSurface.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        step('minus', s.t('Раньше', 'Earlier'), -1),
        SizedBox(
          width: 46,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(journalUpper(s.t('сессия', 'session')),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                    fontSize: 9.5,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .57,
                    color: c.onSurfaceVariant)),
            const SizedBox(height: 2),
            session == null
                ? Text('—',
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 18,
                        height: 1,
                        color: c.onSurface))
                : RollingNumber(session!,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: c.onSurface)),
          ]),
        ),
        step('plus', s.t('Позже', 'Later'), 1),
      ]),
    );
  }
}

class _DashedChip extends StatelessWidget {
  const _DashedChip(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap,
      this.accent});
  final String icon, label;
  final VoidCallback onTap;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = accent ?? c.outline;
    return Pressable(
      onTap: onTap,
      scale: .95,
      haptic: true,
      semanticLabel: label,
      child: JournalDashed(
        radius: 19,
        width: 1.4,
        color: a.withValues(alpha: accent == null ? 1 : .7),
        child: Container(
          height: 38,
          padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            LineIcon(icon, size: 16, color: accent ?? c.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color:
                          accent == null ? c.onSurfaceVariant : c.onSurface)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip(
      {required this.label,
      required this.removeLabel,
      required this.onRemove,
      this.icon,
      this.round = false});
  final String label, removeLabel;
  final String? icon;
  final VoidCallback onRemove;
  final bool round;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      height: 38,
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32),
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
      decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(round ? 19 : 12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          LineIcon(icon!, size: 15, color: c.secondary),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: round ? c.onSurfaceVariant : c.onSurface)),
        ),
        Semantics(
          button: true,
          label: removeLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onRemove();
            },
            child: SizedBox(
                width: 30,
                height: 30,
                child: Center(
                    child: LineIcon('x', size: 14, color: c.onSurfaceVariant))),
          ),
        ),
      ]),
    );
  }
}

class _AddLine extends StatelessWidget {
  const _AddLine({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Pressable(
        onTap: onTap,
        scale: .95,
        semanticLabel: label,
        child: SizedBox(
          height: 42,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              LineIcon('plus', size: 17, color: c.secondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: c.secondary)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow(
      {required this.entry,
      required this.session,
      required this.on,
      required this.onTap});
  final JournalEntry entry;
  final int? session;
  final bool on;
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
    final dur = AppMotion.of(context, AppMotion.medium);
    return Pressable(
      key: ValueKey('journal-link-${entry.key}'),
      onTap: onTap,
      scale: .98,
      selected: on,
      semanticLabel: entry.title,
      child: AnimatedContainer(
        duration: dur,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: on
              ? JournalLook.mix(c.secondary, .16, c.surfaceContainerLow)
              : c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color:
                  on ? c.secondary.withValues(alpha: .5) : Colors.transparent,
              width: 1.5),
        ),
        child: Row(children: [
          JournalSeal(
              icon: q != null
                  ? JournalLook.statusIcon(q.status)
                  : JournalLook.categoryIcon(entry.note!.category),
              accent: a,
              size: JournalSealSize.sm),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.title,
                  style: TextStyle(
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: c.onSurface)),
              const SizedBox(height: 3),
              Text(
                  [
                    q != null
                        ? s.t('Задание', 'Quest')
                        : JournalLook.categoryLabel(s, entry.note!.category),
                    if (session != null)
                      s.t('сессия $session', 'session $session'),
                  ].join(' · '),
                  style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant)),
            ]),
          ),
          AnimatedContainer(
            duration: dur,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? c.secondary : c.onSurface.withValues(alpha: .07)),
            child: Center(
                child: LineIcon(on ? 'check' : 'plus',
                    size: 16, color: on ? c.surface : c.onSurfaceVariant)),
          ),
        ]),
      ),
    );
  }
}
