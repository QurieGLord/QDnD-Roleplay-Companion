import '../../core/ui/app_menu_style.dart';
import '../../core/ui/sheet_drag_region.dart';
import 'dart:async';
import 'dart:io';
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
import '../../core/ui/app_snack_bar.dart';
import '../../core/search/journal_search.dart';
import 'entity_editor.dart';
import 'journal_strings.dart';
import 'journal_selection.dart';

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
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.entry?.title ?? '');
  late final _text = TextEditingController(text: widget.entry?.text ?? '');
  final _tag = TextEditingController();
  final _titleFocus = FocusNode();
  final _textFocus = FocusNode();
  final _tagFocus = FocusNode();
  final _suggestionScroll = ScrollController();
  Set<String> _lastCandidates = {};
  late final _graph = JournalService.graph(widget.character);
  late final _links = widget.entry == null
      ? JournalRecordLinks()
      : JournalRecordLinks.fromJson(
          _graph.forRecord(widget.entry!.key).toJson());
  late final _session =
      TextEditingController(text: _links.session?.toString() ?? '');
  late var _category = widget.entry?.note?.category ?? NoteCategory.general;
  late var _status = widget.entry?.quest?.status ?? QuestStatus.active;
  late bool _pinned = widget.entry?.note?.isPinned ?? false;
  late String? _image = widget.entry?.image;
  late final _tags = List<String>.of(widget.entry?.note?.tags ?? []);
  late final _objectives = [
    for (final o in widget.entry?.quest?.objectives ?? <QuestObjective>[])
      TextEditingController(text: o.description)
  ];
  late final _completed = [
    for (final o in widget.entry?.quest?.objectives ?? <QuestObjective>[])
      o.isCompleted
  ];
  final _newEntities = <JournalEntity>[];
  Timer? _timer;
  bool _saving = false;
  bool _dirty = false;
  bool get _isQuest =>
      widget.entry?.quest != null || (widget.entry == null && widget.quest);
  String get _allText => [
        _title.text,
        _text.text,
        ..._tags,
        ..._objectives.map((o) => o.text)
      ].join('\n');
  JournalLinkAnalysis get _analysis =>
      JournalLinks.analyze(_allText, _graph.entities);

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _text.addListener(_changed);
    _session.addListener(_changed);
    _tag.addListener(_tagChanged);
    _titleFocus.addListener(_focusChanged);
    _textFocus.addListener(_focusChanged);
    for (final c in _objectives) {
      c.addListener(_changed);
    }
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final next =
          JournalLinks.candidates(_title.text, _text.text, _graph.entities)
              .toSet();
      final hasNew = next
          .any((name) => !_lastCandidates.any((old) => name.startsWith(old)));
      _lastCandidates = next;
      setState(() {});
      if (hasNew &&
          _suggestionScroll.hasClients &&
          _suggestionScroll.offset > 0) {
        _suggestionScroll.animateTo(0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic);
      }
    });
  }

  void _tagChanged() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _title.dispose();
    _text.dispose();
    _tag.dispose();
    _titleFocus.dispose();
    _textFocus.dispose();
    _tagFocus.dispose();
    _suggestionScroll.dispose();
    _session.dispose();
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
    if (!_saving && await _discard() && mounted) Navigator.pop(context);
  }

  Future<void> _addEntity([String name = '']) async {
    final entity = await editJournalEntity(context,
        name: name,
        kind: _category == NoteCategory.location
            ? JournalEntityKind.place
            : _category == NoteCategory.artifact
                ? JournalEntityKind.item
                : JournalEntityKind.person);
    if (entity == null || !mounted) return;
    setState(() {
      _graph.entities.add(entity);
      _newEntities.add(entity);
      _links.manual.add(entity.id);
      _links.excluded.remove(entity.id);
      _dirty = true;
    });
    HapticFeedback.selectionClick();
  }

  Widget _selectionMenu(BuildContext context, EditableTextState state,
          TextEditingController controller) =>
      journalSelectionToolbar(context, state, _linkSelected);

  Future<void> _linkSelected(String text) async {
    final choice = await chooseSelectionStory(context, text, _graph.entities);
    if (!mounted || choice == null) return;
    if (choice == 'new') {
      await _addEntity(text);
      return;
    }
    setState(() {
      _links.manual.add(choice);
      _links.excluded.remove(choice);
      _dirty = true;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _pickEntity() async {
    final s = JournalStrings(context);
    final choice = await showResponsiveSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
            child: SizedBox(
                height: 420,
                child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      ListTile(
                          leading: const Icon(Icons.add),
                          title: Text(s.t('Новая история', 'New story')),
                          onTap: () => Navigator.pop(context, 'new')),
                      for (final e in _graph.entities)
                        ListTile(
                            leading: Icon(s.icon(e.kind)),
                            title: Text(e.name),
                            subtitle: Text(e.description.isEmpty
                                ? s.kind(e.kind)
                                : e.description),
                            onTap: () => Navigator.pop(context, e.id)),
                    ]))));
    if (choice == null || !mounted) return;
    if (choice == 'new') {
      await _addEntity();
      return;
    }
    setState(() {
      _links.manual.add(choice);
      _links.excluded.remove(choice);
      _dirty = true;
    });
  }

  Future<void> _pickRecord() async {
    final s = JournalStrings(context);
    final entries = JournalService.entries(widget.character)
        .where((e) => e.key != widget.entry?.key)
        .toList();
    final query = TextEditingController();
    final choice = await showResponsiveSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
            builder: (context, refresh) => SafeArea(
                child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * .65,
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          Text(s.t('Связать с записью', 'Link an entry'),
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          TextField(
                              controller: query,
                              decoration: InputDecoration(
                                  hintText:
                                      s.t('Найти запись', 'Find an entry')),
                              onChanged: (_) => refresh(() {})),
                          Expanded(
                              child: ListView(children: [
                            for (final e in entries.where((e) =>
                                JournalSearch(query.text).matches(e.fields)))
                              ListTile(
                                  title: Text(e.title),
                                  leading: Icon(e.quest == null
                                      ? Icons.description_outlined
                                      : Icons.flag_outlined),
                                  onTap: () => Navigator.pop(context, e.key))
                          ])),
                        ]))))));
    // Do not dispose a controller while the sheet is animating out.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    query.dispose();
    if (choice != null && mounted) {
      setState(() {
        _links.records.add(choice);
        _dirty = true;
      });
    }
  }

  Future<void> _pickImage() async {
    final s = JournalStrings(context);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (mounted && result?.files.single.path != null) {
        setState(() {
          _image = result!.files.single.path;
          _dirty = true;
        });
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

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final s = JournalStrings(context);
    _timer?.cancel();
    if (_tag.text.trim().isNotEmpty && !_tags.contains(_tag.text.trim())) {
      _tags.add(_tag.text.trim());
    }
    setState(() => _saving = true);
    final id =
        widget.entry?.note?.id ?? widget.entry?.quest?.id ?? const Uuid().v4();
    final entry = _isQuest
        ? JournalEntry.quest(Quest(
            id: id,
            title: _title.text.trim(),
            description: _text.text.trim(),
            status: _status,
            imagePath: _image,
            createdAt: widget.entry?.date,
            completedAt: _status == QuestStatus.active
                ? null
                : widget.entry?.quest?.completedAt ?? DateTime.now(),
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
    _links.session = int.tryParse(_session.text);
    try {
      await JournalService.save(widget.character, entry,
          links: _links, newEntities: _newEntities);
      if (!mounted) return;
      _dirty = false;
      HapticFeedback.lightImpact();
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
    final tag = _tag.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tag.clear();
        _dirty = true;
      });
    }
  }

  Widget _chipMotion(Widget child) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
                offset: Offset(0, 5 * (1 - value)), child: child)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final analysis = _analysis;
    final connected =
        {..._links.manual, ...analysis.automatic}.difference(_links.excluded);
    final candidates = JournalLinks.candidates(
        _title.text, _text.text, _graph.entities,
        entityTitle: !_isQuest &&
            const [
              NoteCategory.npc,
              NoteCategory.location,
              NoteCategory.artifact
            ].contains(_category));
    final records = JournalService.entries(widget.character);
    final liveSuggestions = (_titleFocus.hasFocus || _textFocus.hasFocus) &&
        MediaQuery.viewInsetsOf(context).bottom > 0 &&
        (candidates.isNotEmpty || connected.isNotEmpty);
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
                onPressed: _saving ? null : _close,
                icon: const Icon(Icons.close),
                tooltip: s.t('Закрыть', 'Close')),
            title: Text(
                _isQuest ? s.t('Задание', 'Quest') : s.t('Запись', 'Note')),
            actions: [
              TextButton(
                  key: const ValueKey('journal-save'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(s.t('Сохранить', 'Save')))
            ],
          ),
          bottomNavigationBar: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: liveSuggestions
                  ? SafeArea(
                      top: false,
                      child: Material(
                        color: c.surfaceContainerHigh,
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      s.t('Истории в записи',
                                          'Stories in this entry'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall),
                                  const SizedBox(height: 6),
                                  SingleChildScrollView(
                                      controller: _suggestionScroll,
                                      scrollDirection: Axis.horizontal,
                                      child: Row(children: [
                                        for (final name in candidates)
                                          Padding(
                                              key:
                                                  ValueKey('suggest-new-$name'),
                                              padding: const EdgeInsets.only(
                                                  right: 8),
                                              child: _chipMotion(ActionChip(
                                                  avatar: const Icon(Icons.add,
                                                      size: 16),
                                                  label: Text(name),
                                                  onPressed: () =>
                                                      _addEntity(name)))),
                                        for (final id in connected)
                                          if (_graph.entity(id) case final e?)
                                            Padding(
                                                key: ValueKey(
                                                    'suggest-known-$id'),
                                                padding: const EdgeInsets.only(
                                                    right: 8),
                                                child: _chipMotion(InputChip(
                                                    avatar: const Icon(
                                                        Icons.check,
                                                        size: 16),
                                                    label: Text(e.name),
                                                    tooltip: s.t(
                                                        'Связано · нажми крестик, чтобы отменить',
                                                        'Linked · remove to disconnect'),
                                                    onDeleted: () =>
                                                        setState(() {
                                                          _links.manual
                                                              .remove(id);
                                                          _links.excluded
                                                              .add(id);
                                                          _dirty = true;
                                                        })))),
                                      ])),
                                ])),
                      ))
                  : const SizedBox.shrink(),
            ),
          ),
          body: SafeArea(
              child: AbsorbPointer(
                  absorbing: _saving,
                  child: Form(
                      key: _form,
                      child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                          children: [
                            TextFormField(
                                key: const ValueKey('journal-title'),
                                controller: _title,
                                focusNode: _titleFocus,
                                contextMenuBuilder: (context, state) =>
                                    _selectionMenu(context, state, _title),
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                                decoration: InputDecoration(
                                    labelText: s.t('Название', 'Title')),
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? s.t('Добавь название', 'Add a title')
                                    : null),
                            const SizedBox(height: 16),
                            TextFormField(
                                key: const ValueKey('journal-text'),
                                controller: _text,
                                focusNode: _textFocus,
                                contextMenuBuilder: (context, state) =>
                                    _selectionMenu(context, state, _text),
                                minLines: 5,
                                maxLines: null,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                    labelText: s.t('Текст', 'Text'),
                                    alignLabelWithHint: true)),
                            const SizedBox(height: 14),
                            if (connected.isNotEmpty)
                              Wrap(
                                  key: const ValueKey('journal-connected'),
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final id in connected)
                                      if (_graph.entity(id) case final e?)
                                        InputChip(
                                          avatar:
                                              Icon(s.icon(e.kind), size: 18),
                                          label: Text(e.name),
                                          tooltip: _links.manual.contains(id)
                                              ? s.t('Добавлено тобой',
                                                  'Added by you')
                                              : s.t(
                                                  'Знакомое имя · связано автоматически',
                                                  'Known name · linked automatically'),
                                          onDeleted: () => setState(() {
                                            _links.manual.remove(id);
                                            _links.excluded.add(id);
                                            _dirty = true;
                                          }),
                                        ),
                                  ]),
                            if (analysis.ambiguous.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                  s.t('Имя совпало. Кто упоминается?',
                                      'Same name. Who is mentioned?'),
                                  style:
                                      Theme.of(context).textTheme.labelLarge),
                              for (final group in analysis.ambiguous)
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  for (final e in group)
                                    ChoiceChip(
                                        label: Text(
                                            '${e.name} · ${e.description.isEmpty ? s.kind(e.kind) : e.description}'),
                                        selected: _links.manual.contains(e.id),
                                        onSelected: (_) => setState(() {
                                              for (final other in group) {
                                                _links.manual.remove(other.id);
                                                _links.excluded.add(other.id);
                                              }
                                              _links.manual.add(e.id);
                                              _links.excluded.remove(e.id);
                                              _dirty = true;
                                            }))
                                ]),
                            ],
                            if (candidates.isNotEmpty && !liveSuggestions) ...[
                              const SizedBox(height: 12),
                              Text(
                                  s.t('Добавить в истории?', 'Add to stories?'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(color: c.onSurfaceVariant)),
                              Wrap(spacing: 8, runSpacing: 6, children: [
                                for (final name in candidates)
                                  ActionChip(
                                      avatar: const Icon(Icons.add, size: 16),
                                      label: Text(name),
                                      onPressed: () => _addEntity(name))
                              ]),
                            ],
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              TextButton.icon(
                                  onPressed: _pickEntity,
                                  icon: const Icon(Icons.bookmark_add_outlined,
                                      size: 18),
                                  label: Text(s.t('История', 'Story'))),
                              TextButton.icon(
                                  onPressed: _pickRecord,
                                  icon: const Icon(Icons.link, size: 18),
                                  label: Text(
                                      s.t('Связать запись', 'Link entry'))),
                            ]),
                            for (final key in _links.records)
                              for (final e
                                  in records.where((e) => e.key == key))
                                ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(e.title),
                                    leading: const Icon(Icons.link),
                                    trailing: IconButton(
                                        icon: const Icon(Icons.close),
                                        tooltip:
                                            s.t('Убрать связь', 'Remove link'),
                                        onPressed: () => setState(() {
                                              _links.records.remove(key);
                                              _dirty = true;
                                            }))),
                            const SizedBox(height: 20),
                            if (_isQuest) ...[
                              DropdownButtonFormField<QuestStatus>(
                                  borderRadius: AppMenuStyle.radius,
                                  dropdownColor:
                                      AppMenuStyle.background(context),
                                  elevation: 4,
                                  key: const ValueKey('journal-status'),
                                  initialValue: _status,
                                  decoration: InputDecoration(
                                      labelText: s.t('Статус', 'Status')),
                                  items: [
                                    for (final status in QuestStatus.values)
                                      DropdownMenuItem(
                                          value: status,
                                          child: Text(s.ru
                                              ? status.displayNameRu
                                              : status.displayName))
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _status = v;
                                        _dirty = true;
                                      });
                                    }
                                  }),
                              const SizedBox(height: 18),
                              Row(children: [
                                Expanded(
                                    child: Text(s.t('Подзадачи', 'Objectives'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium)),
                                TextButton.icon(
                                    onPressed: () => setState(() {
                                          final controller =
                                              TextEditingController()
                                                ..addListener(_changed);
                                          _objectives.add(controller);
                                          _completed.add(false);
                                          _dirty = true;
                                        }),
                                    icon: const Icon(Icons.add),
                                    label: Text(s.t('Добавить', 'Add')))
                              ]),
                              for (var i = 0; i < _objectives.length; i++)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(children: [
                                      Checkbox(
                                          value: _completed[i],
                                          onChanged: (v) => setState(() {
                                                _completed[i] = v!;
                                                _dirty = true;
                                              })),
                                      Expanded(
                                          child: TextFormField(
                                              key: ObjectKey(_objectives[i]),
                                              controller: _objectives[i],
                                              decoration: InputDecoration(
                                                  hintText: s.t(
                                                      'Что нужно сделать',
                                                      'What needs doing')))),
                                      IconButton(
                                          onPressed: () => setState(() {
                                                _objectives
                                                    .removeAt(i)
                                                    .dispose();
                                                _completed.removeAt(i);
                                                _dirty = true;
                                              }),
                                          icon: const Icon(Icons.close),
                                          tooltip: s.t('Убрать подзадачу',
                                              'Remove objective')),
                                    ])),
                            ] else ...[
                              DropdownButtonFormField<NoteCategory>(
                                  borderRadius: AppMenuStyle.radius,
                                  dropdownColor:
                                      AppMenuStyle.background(context),
                                  elevation: 4,
                                  key: const ValueKey('journal-category'),
                                  initialValue: _category,
                                  decoration: InputDecoration(
                                      labelText: s.t('Категория', 'Category')),
                                  items: [
                                    for (final category in NoteCategory.values)
                                      DropdownMenuItem(
                                          value: category,
                                          child: Text(s.ru
                                              ? category.displayNameRu
                                              : category.displayName))
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _category = v;
                                        _dirty = true;
                                      });
                                    }
                                  }),
                              const SizedBox(height: 16),
                              TextField(
                                  key: const ValueKey('journal-tags'),
                                  controller: _tag,
                                  focusNode: _tagFocus,
                                  decoration: InputDecoration(
                                      labelText: s.t('Теги', 'Tags'),
                                      suffixIcon: IconButton(
                                          onPressed: _addTag,
                                          icon: const Icon(Icons.add),
                                          tooltip:
                                              s.t('Добавить тег', 'Add tag'))),
                                  onSubmitted: (_) => _addTag()),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, runSpacing: 6, children: [
                                for (final tag in _tags)
                                  InputChip(
                                      label: Text(tag),
                                      onDeleted: () => setState(() {
                                            _tags.remove(tag);
                                            _dirty = true;
                                          }))
                              ]),
                              SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title:
                                      Text(s.t('Закрепить запись', 'Pin note')),
                                  value: _pinned,
                                  onChanged: (v) => setState(() {
                                        _pinned = v;
                                        _dirty = true;
                                      })),
                            ],
                            const SizedBox(height: 16),
                            TextFormField(
                                key: const ValueKey('journal-session'),
                                controller: _session,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText: s.t(
                                        'Номер сессии · необязательно',
                                        'Session number · optional')),
                                validator: (v) => (v ?? '').trim().isEmpty ||
                                        (int.tryParse(v!) ?? 0) > 0
                                    ? null
                                    : s.t('Укажи положительный номер',
                                        'Enter a positive number')),
                            const SizedBox(height: 18),
                            if (_image != null) ...[
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: _image!.startsWith('http')
                                      ? Image.network(_image!,
                                          height: 180,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Text(
                                              s.t('Фото недоступно',
                                                  'Image unavailable')))
                                      : Image.file(File(_image!),
                                          height: 180,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Text(
                                              s.t('Фото недоступно',
                                                  'Image unavailable')))),
                              TextButton.icon(
                                  onPressed: () => setState(() {
                                        _image = null;
                                        _dirty = true;
                                      }),
                                  icon: const Icon(Icons.close),
                                  label:
                                      Text(s.t('Убрать фото', 'Remove image'))),
                            ] else
                              OutlinedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(
                                      Icons.add_photo_alternate_outlined),
                                  label:
                                      Text(s.t('Добавить фото', 'Add image'))),
                          ]))))),
    );
  }
}
