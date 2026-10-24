import 'package:flutter/material.dart';
import 'package:qd_and_d/core/ui/sheet_drag_region.dart' show SheetSafeArea;
import 'package:flutter/services.dart';
import '../../core/search/journal_search.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

/// An isolated, in-memory comparison. It never reads or saves a character.
class JournalCycleScreen extends StatefulWidget {
  const JournalCycleScreen({super.key});

  @override
  State<JournalCycleScreen> createState() => _JournalCycleScreenState();
}

class _Entry {
  _Entry(this.id, this.ru, this.en, this.bodyRu, this.bodyEn, this.contexts,
      this.session,
      {this.quest = false, this.done = false, this.links = const []});
  final String id;
  String ru;
  String en;
  String bodyRu;
  String bodyEn;
  final List<String> contexts;
  final int session;
  final bool quest;
  bool done;
  final List<String> links;
}

List<_Entry> _seed() => [
      _Entry(
          'find',
          'Найти Элиана',
          'Find Elian',
          'Передать сыну последние слова отца. Первая зацепка — письмо из Лесной гавани. Награда пока неизвестна.',
          'Deliver his father’s last words. The first lead is a letter from Woodland Haven. Reward unknown.',
          ['elian', 'haven'],
          6,
          quest: true,
          links: ['last', 'letter']),
      _Entry(
          'road',
          'Угроза на северной дороге',
          'Threat on the northern road',
          'Противник повержен. В городе обещали 450 зм; награда ещё не получена.',
          'The enemy is defeated. The town promised 450 gp; the reward has not been collected.',
          ['road'],
          6,
          quest: true,
          done: true,
          links: ['blade']),
      _Entry(
          'last',
          'Последние слова',
          'Last words',
          'Альдрен попросил найти сына Элиана. Он ушёл из семьи ради её защиты; его история оказалась сложнее, чем мы думали.',
          'Aldren asked us to find his son Elian. He left to protect his family; his story was more complicated than we thought.',
          ['elian'],
          6,
          links: ['letter', 'find']),
      _Entry(
          'letter',
          'Письмо из Лесной гавани',
          'A letter from Woodland Haven',
          'В письме есть имя Элиан и упоминание старой пристани. Пока не установлено, тот ли это человек.',
          'The letter mentions Elian and the old wharf. We have not confirmed whether this is the same person.',
          ['elian', 'haven'],
          2,
          links: ['last', 'find']),
      _Entry(
          'blade',
          'Клинок из сокровищницы',
          'The blade from the treasury',
          'С мастером договорились: у клинка три заряда. Свойства перенесены в Кузницу.',
          'The GM agreed that the blade has three charges. Its properties were recorded in the Forge.',
          ['road'],
          6,
          links: ['road']),
    ];

class _JournalCycleScreenState extends State<JournalCycleScreen> {
  List<_Entry> _entries = _seed();
  int _mode = 0;
  String _focus = 'all';
  String _query = '';
  bool _ru = true;
  bool _dark = true;
  final _search = TextEditingController();
  String t(String ru, String en) => _ru ? ru : en;
  String title(_Entry e) => _ru ? e.ru : e.en;
  String body(_Entry e) => _ru ? e.bodyRu : e.bodyEn;
  String contextName(String id) => switch (id) {
        'elian' => t('Элиан', 'Elian'),
        'haven' => t('Лесная гавань', 'Woodland Haven'),
        'road' => t('Северная дорога', 'Northern road'),
        _ => t('Все истории', 'All stories'),
      };

  String connections(int count) {
    if (!_ru) return '$count ${count == 1 ? 'link' : 'links'}';
    final last = count % 10;
    final teens = count % 100 >= 11 && count % 100 <= 14;
    final noun = !teens && last == 1
        ? 'связь'
        : !teens && last >= 2 && last <= 4
            ? 'связи'
            : 'связей';
    return '$count $noun';
  }

  void _touch() => HapticFeedback.selectionClick();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Entry> get _filtered {
    final search = JournalSearch(_query);
    return _entries
        .where((e) =>
            (_focus == 'all' || e.contexts.contains(_focus)) &&
            search.matches([title(e), body(e)]))
        .toList();
  }

  Duration motion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff8c78bb),
      brightness: _dark ? Brightness.dark : Brightness.light,
    );
    final theme = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: scheme,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: scheme.surface,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.lgPlus),
            borderSide: BorderSide.none),
      ),
      chipTheme: ChipThemeData(
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant)),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
    );
    return Localizations.override(
        context: context,
        locale: Locale(_ru ? 'ru' : 'en'),
        child: Theme(
            data: theme,
            child: Builder(builder: (context) {
              final quests = _filtered.where((e) => e.quest).toList()
                ..sort((a, b) => (a.done ? 1 : 0).compareTo(b.done ? 1 : 0));
              final notes = _filtered.where((e) => !e.quest).toList()
                ..sort((a, b) => b.session.compareTo(a.session));
              return Scaffold(
                appBar: AppBar(
                  title: Text(t('Журнал', 'Journal')),
                  actions: [
                    PopupMenuButton<String>(
                      tooltip: t('Настройки демо', 'Demo options'),
                      onSelected: (value) {
                        _touch();
                        if (value == 'help') {
                          _help(context);
                        } else {
                          setState(() {
                            if (value == 'language') _ru = !_ru;
                            if (value == 'theme') _dark = !_dark;
                            if (value == 'reset') {
                              _entries = _seed();
                              _focus = 'all';
                              _query = '';
                              _search.clear();
                            }
                          });
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'help',
                            child: Text(t('Как проверить', 'How to try it'))),
                        PopupMenuItem(
                            value: 'theme',
                            child: Text(t('Сменить тему', 'Switch theme'))),
                        PopupMenuItem(
                            value: 'language',
                            child: Text(t('English', 'Русский'))),
                        PopupMenuItem(
                            value: 'reset',
                            child: Text(t(
                                'Сбросить историю демо', 'Reset demo story'))),
                      ],
                    ),
                  ],
                ),
                body: SafeArea(
                    top: false,
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  t('CYCLE · ТРИ ВАРИАНТА',
                                      'CYCLE · THREE VARIANTS'),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.primary,
                                      letterSpacing: 1.2)),
                              const SizedBox(height: 8),
                              SizedBox(
                                  width: double.infinity,
                                  child: SegmentedButton<int>(
                                    showSelectedIcon: false,
                                    segments: [
                                      ButtonSegment(
                                          value: 0,
                                          label: Text(t('Фокус', 'Focus'))),
                                      ButtonSegment(
                                          value: 1,
                                          label: Text(t('Обзор', 'Overview'))),
                                      ButtonSegment(
                                          value: 2,
                                          label: Text(t('Нить', 'Timeline'))),
                                    ],
                                    selected: {_mode},
                                    onSelectionChanged: (s) {
                                      _touch();
                                      setState(() => _mode = s.first);
                                    },
                                  )),
                            ]),
                      ),
                      Expanded(
                          child: AnimatedSwitcher(
                        duration: motion(context),
                        child: ListView(
                          key: ValueKey(_mode),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer
                                    .withValues(alpha: .45),
                                borderRadius: BorderRadius.circular(AppRadii.xl),
                              ),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.auto_stories_outlined,
                                        color: scheme.primary),
                                    const SizedBox(height: 12),
                                    Text(
                                        t('Иногда новая встреча меняет смысл старой истории.',
                                            'Sometimes a new encounter changes the meaning of an old story.'),
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(height: 1.4)),
                                    const SizedBox(height: 10),
                                    Text(
                                        t('Демонстрационная история · сессия 6',
                                            'Demo story · session 6'),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                                color:
                                                    scheme.onSurfaceVariant)),
                                  ]),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _search,
                              onChanged: (v) => setState(() => _query = v),
                              decoration: InputDecoration(
                                hintText:
                                    t('Найти в журнале', 'Search journal'),
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip:
                                            t('Очистить поиск', 'Clear search'),
                                        icon: const Icon(Icons.close),
                                        onPressed: () => setState(() {
                                          _query = '';
                                          _search.clear();
                                        }),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                                alignment: Alignment.centerLeft,
                                child: ActionChip(
                                  avatar: Icon(
                                      _focus == 'all'
                                          ? Icons.filter_list
                                          : Icons.bookmark_outline,
                                      size: 18),
                                  label: Text(contextName(_focus)),
                                  onPressed: () => _pickFocus(context),
                                )),
                            if (_mode == 1) ...[
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: () => _overview(context,
                                    _focus == 'all' ? 'elian' : _focus),
                                icon: const Icon(Icons.hub_outlined, size: 20),
                                label: Text(
                                    t('Обзор связей', 'Explore connections')),
                              ),
                            ],
                            _heading(
                                context, t('Задания', 'Quests'), quests.length),
                            if (quests.isEmpty)
                              _empty(
                                  context,
                                  t('Здесь пока нет заданий',
                                      'No quests here yet')),
                            for (final e in quests) _card(context, e),
                            _heading(
                                context, t('Записи', 'Notes'), notes.length),
                            if (notes.isEmpty)
                              _empty(context,
                                  t('Ничего не найдено', 'Nothing found')),
                            if (_mode == 2)
                              for (final session
                                  in notes.map((e) => e.session).toSet()) ...[
                                Padding(
                                    key: ValueKey('session-$session'),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Row(children: [
                                      Icon(Icons.circle,
                                          size: 8, color: scheme.primary),
                                      const SizedBox(width: 10),
                                      Text(
                                          t('Сессия $session',
                                              'Session $session'),
                                          style: theme.textTheme.labelLarge),
                                      const SizedBox(width: 12),
                                      const Expanded(child: Divider()),
                                    ])),
                                for (final e
                                    in notes.where((e) => e.session == session))
                                  _card(context, e),
                              ]
                            else
                              for (final e in notes) _card(context, e),
                          ],
                        ),
                      )),
                    ])),
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.add),
                  label: Text(t('Запись', 'Note')),
                ),
              );
            })));
  }

  Widget _heading(BuildContext context, String label, int count) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Row(children: [
          Expanded(
              child:
                  Text(label, style: Theme.of(context).textTheme.titleLarge)),
          Text('$count',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );

  Widget _empty(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _card(BuildContext context, _Entry e, {VoidCallback? refresh}) {
    final c = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.lgPlus),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              _touch();
              _detail(context, e).then((_) => refresh?.call());
            },
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (e.quest) ...[
                              SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    tooltip: e.done
                                        ? t('Вернуть в активные', 'Mark active')
                                        : t('Завершить задание',
                                            'Complete quest'),
                                    icon: Icon(
                                        e.done
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: e.done
                                            ? c.primary
                                            : c.onSurfaceVariant),
                                    onPressed: () {
                                      _touch();
                                      setState(() => e.done = !e.done);
                                      refresh?.call();
                                    },
                                  )),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                                child: Text(title(e),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium)),
                          ]),
                      const SizedBox(height: 8),
                      Text(body(e),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.onSurfaceVariant, height: 1.4)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 12, runSpacing: 6, children: [
                        Text(
                            e.quest
                                ? (e.done
                                    ? t('Выполнено', 'Completed')
                                    : t('В пути', 'In progress'))
                                : t('Сессия ${e.session}',
                                    'Session ${e.session}'),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: c.primary)),
                        Text(connections(e.links.length),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: c.onSurfaceVariant)),
                      ]),
                    ])),
          ),
        ));
  }

  Future<void> _pickFocus(BuildContext context) async {
    _touch();
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) => SheetSafeArea(child: SafeArea(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                      t('За какой историей следим?',
                          'Which story are we following?'),
                      style: Theme.of(context).textTheme.titleLarge)),
              for (final id in ['all', 'elian', 'haven', 'road'])
                ListTile(
                  title: Text(contextName(id)),
                  trailing: _focus == id ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, id),
                ),
            ]),
      ))),
    );
    if (result != null && mounted) {
      _touch();
      setState(() => _focus = result);
    }
  }

  Future<void> _detail(BuildContext context, _Entry e) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (routeContext) => Theme(
              data: Theme.of(context),
              child: StatefulBuilder(
                  builder: (context, refresh) => Scaffold(
                        appBar: AppBar(
                            title: Text(e.quest
                                ? t('Задание', 'Quest')
                                : t('Запись', 'Note')),
                            actions: [
                              IconButton(
                                  tooltip: t('Редактировать', 'Edit'),
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () async {
                                    await _edit(context, e);
                                    if (context.mounted) refresh(() {});
                                  }),
                            ]),
                        body: SafeArea(
                            child: ListView(
                                padding: const EdgeInsets.all(24),
                                children: [
                              Text(title(e),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const SizedBox(height: 12),
                              Text(
                                  t('Сессия ${e.session}',
                                      'Session ${e.session}'),
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary)),
                              const SizedBox(height: 24),
                              Text(body(e),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(height: 1.6)),
                              if (e.quest) ...[
                                const SizedBox(height: 20),
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    _touch();
                                    setState(() => e.done = !e.done);
                                    refresh(() {});
                                  },
                                  icon: Icon(e.done
                                      ? Icons.check_circle_outline
                                      : Icons.flag_outlined),
                                  label: Text(e.done
                                      ? t('Выполнено · вернуть в активные',
                                          'Completed · mark active')
                                      : t('Отметить выполненным',
                                          'Mark completed')),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    t('Отметка задания не выдаёт награду автоматически.',
                                        'Completing a quest does not award its reward automatically.'),
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ],
                              if (e.contexts.isNotEmpty) ...[
                                _heading(
                                    context,
                                    t('В этой истории', 'In this story'),
                                    e.contexts.length),
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  for (final id in e.contexts)
                                    ActionChip(
                                        label: Text(contextName(id)),
                                        onPressed: () =>
                                            _overview(context, id)),
                                ]),
                              ],
                              _heading(
                                  context,
                                  t('Связанные записи', 'Related entries'),
                                  e.links.length),
                              if (e.id == 'letter' || e.id == 'last')
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                      t('Совпадение имени — зацепка, а не подтверждённая личность.',
                                          'A matching name is a clue, not a confirmed identity.'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ),
                              for (final id in e.links)
                                for (final linked in _entries
                                    .where((entry) => entry.id == id))
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(linked.quest
                                        ? Icons.flag_outlined
                                        : Icons.description_outlined),
                                    title: Text(title(linked)),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      _touch();
                                      _detail(context, linked);
                                    },
                                  ),
                            ])),
                      )),
            )));
    if (mounted) setState(() {});
  }

  void _overview(BuildContext context, String focus) {
    _touch();
    var selected = focus;
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
            builder: (_) => Theme(
                  data: Theme.of(context),
                  child: StatefulBuilder(builder: (context, update) {
                    final c = Theme.of(context).colorScheme;
                    final related = _entries
                        .where((e) => e.contexts.contains(selected))
                        .toList();
                    final clues = related.where((e) => !e.quest).toList()
                      ..sort((a, b) => a.session.compareTo(b.session));
                    final quests = related.where((e) => e.quest).toList();
                    return Scaffold(
                      appBar: AppBar(
                          title: Text(t('Атлас историй', 'Story atlas'))),
                      body: SafeArea(
                          child: ListView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                              children: [
                            Text(
                                t('За какой нитью пойдём?',
                                    'Which thread shall we follow?'),
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            Text(
                                t('Выбери историю. У каждой связи есть запись-источник.',
                                    'Choose a story. Every connection has a source entry.'),
                                style: TextStyle(color: c.onSurfaceVariant)),
                            const SizedBox(height: 20),
                            SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: [
                                  for (final id in ['elian', 'haven', 'road'])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: SizedBox(
                                          width: 184,
                                          child: Semantics(
                                            selected: selected == id,
                                            button: true,
                                            child: AnimatedContainer(
                                              duration: motion(context),
                                              decoration: BoxDecoration(
                                                color: selected == id
                                                    ? c.primaryContainer
                                                    : c.surfaceContainerLow,
                                                borderRadius:
                                                    BorderRadius.circular(AppRadii.xl),
                                                border: Border.all(
                                                    color: selected == id
                                                        ? c.primary
                                                        : c.outlineVariant),
                                              ),
                                              child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            26),
                                                    onTap: () {
                                                      _touch();
                                                      update(
                                                          () => selected = id);
                                                    },
                                                    child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(18),
                                                        child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Row(children: [
                                                                Icon(id ==
                                                                        'elian'
                                                                    ? Icons
                                                                        .person_outline
                                                                    : id ==
                                                                            'haven'
                                                                        ? Icons
                                                                            .sailing_outlined
                                                                        : Icons
                                                                            .explore_outlined),
                                                                const Spacer(),
                                                                if (selected ==
                                                                    id)
                                                                  const Icon(
                                                                      Icons
                                                                          .check_circle_outline,
                                                                      size: 20),
                                                              ]),
                                                              const SizedBox(
                                                                  height: 20),
                                                              Text(
                                                                  contextName(
                                                                      id),
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .titleMedium),
                                                              const SizedBox(
                                                                  height: 8),
                                                              Text(
                                                                  t('${_entries.where((e) => e.contexts.contains(id)).length} записи',
                                                                      '${_entries.where((e) => e.contexts.contains(id)).length} entries'),
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .labelSmall),
                                                            ])),
                                                  )),
                                            ),
                                          )),
                                    ),
                                ])),
                            const SizedBox(height: 28),
                            AnimatedSwitcher(
                                duration: motion(context),
                                child: Container(
                                  key: ValueKey(selected),
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          c.secondaryContainer,
                                          c.surfaceContainerLow
                                        ]),
                                    borderRadius: BorderRadius.circular(AppRadii.xlPlus),
                                  ),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            t('В ЦЕНТРЕ ИСТОРИИ',
                                                'AT THE HEART OF THE STORY'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(letterSpacing: 1.1)),
                                        const SizedBox(height: 12),
                                        Text(contextName(selected),
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium),
                                        const SizedBox(height: 16),
                                        Text(
                                            selected == 'elian'
                                                ? t('Просьба отца привела к старому письму. Совпадение имени ещё предстоит проверить.',
                                                    'A father’s request led back to an old letter. The matching name still needs to be verified.')
                                                : selected == 'haven'
                                                    ? t('Письмо связывает гавань с поиском Элиана. Старая пристань — следующая зацепка.',
                                                        'The letter links the haven to the search for Elian. The old wharf is the next lead.')
                                                    : t('Победа на дороге, обещанная награда и клинок из сокровищницы — части одного приключения.',
                                                        'The victory on the road, the promised reward and the treasury blade belong to one adventure.'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(height: 1.5)),
                                      ]),
                                )),
                            _heading(
                                context,
                                t('Как связались события',
                                    'How events connect'),
                                clues.length),
                            for (var i = 0; i < clues.length; i++) ...[
                              _evidence(context, clues[i]),
                              if (i < clues.length - 1)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(children: [
                                    const SizedBox(width: 21),
                                    Icon(Icons.south,
                                        size: 18, color: c.primary),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: Text(
                                            t('Общее упоминание: ${contextName(selected)}',
                                                'Shared mention: ${contextName(selected)}'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                    color:
                                                        c.onSurfaceVariant))),
                                  ]),
                                ),
                            ],
                            if (selected == 'elian') ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                    color: c.tertiaryContainer
                                        .withValues(alpha: .5),
                                    borderRadius: BorderRadius.circular(AppRadii.xl)),
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.help_outline),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(
                                                t('Открытый вопрос',
                                                    'Open question'),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall),
                                            const SizedBox(height: 8),
                                            Text(t(
                                                'Элиан из письма — сын Альдрена? Совпадение имени не подтверждает личность.',
                                                'Is Elian in the letter Aldren’s son? A matching name does not confirm identity.')),
                                          ])),
                                    ]),
                              ),
                            ],
                            _heading(
                                context,
                                t('Что делать дальше', 'What comes next'),
                                quests.length),
                            for (final e in quests)
                              _card(context, e, refresh: () => update(() {})),
                            const SizedBox(height: 18),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                setState(() {
                                  _focus = selected;
                                  _query = '';
                                  _search.clear();
                                });
                                Navigator.of(context)
                                    .popUntil((route) => route.isFirst);
                              },
                              icon: const Icon(Icons.filter_list),
                              label: Text(
                                  t('Показать в журнале', 'Show in journal')),
                            ),
                          ])),
                    );
                  }),
                )))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _evidence(BuildContext context, _Entry e) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        onTap: () {
          _touch();
          _detail(context, e);
        },
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                        color: c.secondaryContainer, shape: BoxShape.circle),
                    child: const Icon(Icons.history_edu, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        t('Сессия ${e.session} · источник',
                            'Session ${e.session} · source'),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: c.primary))),
                const Icon(Icons.chevron_right),
              ]),
              const SizedBox(height: 14),
              Text(title(e), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(body(e),
                  style: TextStyle(color: c.onSurfaceVariant, height: 1.5)),
            ])),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [_Entry? e]) async {
    final titleController =
        TextEditingController(text: e == null ? '' : title(e));
    final bodyController =
        TextEditingController(text: e == null ? '' : body(e));
    final form = GlobalKey<FormState>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) => SheetSafeArea(child: Padding(
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: SafeArea(
            top: false,
            child: SingleChildScrollView(
                child: Form(
                    key: form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              e == null
                                  ? t('Новая запись', 'New note')
                                  : t('Редактирование', 'Edit entry'),
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 20),
                          TextFormField(
                              controller: titleController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                  labelText: t('Название', 'Title')),
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? t('Добавь название', 'Add a title')
                                  : null),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: bodyController,
                              minLines: 3,
                              maxLines: 6,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                  labelText: t('Текст', 'Text'))),
                          const SizedBox(height: 18),
                          Text(
                              t('Только для демо. Перезапуск вернёт исходную историю.',
                                  'Demo only. Restarting restores the original story.'),
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 16),
                          SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                  onPressed: () {
                                    if (form.currentState!.validate()) {
                                      Navigator.pop(context, true);
                                    }
                                  },
                                  child: Text(t('Сохранить', 'Save')))),
                        ])))),
      )),
    );
    if (saved == true && mounted) {
      _touch();
      setState(() {
        if (e == null) {
          _entries.add(_Entry(
              'demo-${DateTime.now().microsecondsSinceEpoch}',
              titleController.text.trim(),
              titleController.text.trim(),
              bodyController.text.trim(),
              bodyController.text.trim(),
              _focus == 'all' ? [] : [_focus],
              6));
        } else if (_ru) {
          e.ru = titleController.text.trim();
          e.bodyRu = bodyController.text.trim();
        } else {
          e.en = titleController.text.trim();
          e.bodyEn = bodyController.text.trim();
        }
      });
    }
    // The sheet's closing animation may still reference its controllers.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    titleController.dispose();
    bodyController.dispose();
  }

  void _help(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: Text(t('Попробуй три варианта', 'Try three variants')),
            content: SingleChildScrollView(
                child: Text(t(
                    'Фокус — выбери Элиана через «Все истории»: задания и записи останутся на привычных местах.\n\nОбзор — открой «Обзор связей», пройди из последних слов к письму и вернись в журнал.\n\nНить — сравни события сессий 6 и 2.\n\nМожно искать, редактировать записи и отмечать задания. Данные вымышленные; все изменения живут только до перезапуска. Язык, тема и сброс — в этом меню.',
                    'Focus: choose Elian under “All stories”; quests and notes keep their familiar places.\n\nOverview: explore connections, follow the last words to the letter, then return to the journal.\n\nTimeline: compare sessions 6 and 2.\n\nSearch, edit notes and complete quests. All data is fictional and changes last only until restart. Language, theme and reset are in this menu.'))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('Понятно', 'Got it')))
            ],
          ));
}
