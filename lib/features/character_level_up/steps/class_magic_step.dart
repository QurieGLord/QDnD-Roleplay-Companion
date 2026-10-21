import 'package:flutter/material.dart';
import '../../../core/models/spell.dart';
import '../../../core/progression/spell_learning_plan.dart';
import '../../../core/ui/companion_surface.dart';
import '../../../core/ui/sheet_drag_region.dart';
import '../../../core/search/journal_search.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/spell_details_sheet.dart';
import '../../spell_almanac/spell_almanac_strings.dart';
import '../widgets/advancement_layout.dart';
import '../widgets/advancement_selection.dart';

class ClassMagicStep extends StatelessWidget {
  const ClassMagicStep(
      {super.key,
      required this.plan,
      required this.selected,
      required this.onChanged,
      required this.onNext,
      this.replaceOld,
      this.replaceNew,
      required this.onReplace,
      this.manualCounts,
      required this.onManualCounts});
  final SpellLearningPlan plan;
  final Map<String, List<String>> selected;
  final ValueChanged<Map<String, List<String>>> onChanged;
  final VoidCallback onNext;
  final String? replaceOld, replaceNew;
  final void Function(String?, String?) onReplace;
  final Map<String, int>? manualCounts;
  final ValueChanged<Map<String, int>> onManualCounts;
  String _name(SpellLearningKind kind, AlmanacStrings s) => switch (kind) {
        SpellLearningKind.normal => s.t('Новые заклинания', 'New spells'),
        SpellLearningKind.cantrip => s.t('Новые заговоры', 'New cantrips'),
        SpellLearningKind.secret => s.t('Тайны магии', 'Magical Secrets'),
        SpellLearningKind.arcanum =>
          s.t('Таинственный арканум', 'Mystic Arcanum'),
        SpellLearningKind.masteryOne =>
          s.t('Мастерство · первый круг', 'Mastery · first circle'),
        SpellLearningKind.masteryTwo =>
          s.t('Мастерство · второй круг', 'Mastery · second circle'),
        SpellLearningKind.signature =>
          s.t('Фирменные заклинания', 'Signature Spells'),
        SpellLearningKind.ritualBook =>
          s.t('Книга ритуалов', 'Book of rituals'),
        SpellLearningKind.tome =>
          s.t('Заговоры Договора гримуара', 'Pact of the Tome cantrips'),
        SpellLearningKind.unrestricted =>
          s.t('Заклинание любой школы', 'Spell from any school')
      };
  Future<void> _pick(BuildContext context, SpellLearningChoice choice) async {
    final values = await showResponsiveSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _SpellPicker(
            title: _name(choice.kind, AlmanacStrings(context)),
            spells: choice.options,
            limit: choice.count,
            initial: selected[choice.key] ?? []));
    if (values != null) onChanged({...selected, choice.key: values});
  }

  Future<String?> _single(BuildContext context, String title,
      List<Spell> spells, String? initial) async {
    final values = await showResponsiveSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _SpellPicker(
            title: title,
            spells: spells,
            limit: 1,
            initial: initial == null ? [] : [initial]));
    return values?.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final s = AlmanacStrings(context),
        l = AppLocalizations.of(context)!,
        t = Theme.of(context).textTheme,
        c = Theme.of(context).colorScheme;
    bool ready = !plan.needsManualCounts;
    String? issue;
    try {
      plan.validate(selected, replaceOld: replaceOld, replaceNew: replaceNew);
    } catch (_) {
      ready = false;
      issue = s.t(
          'Заверши выборы магии. Одно заклинание нельзя выбрать дважды.',
          'Finish the spell choices. A spell cannot fill two learning choices.');
    }
    return Column(children: [
      Expanded(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        AdvancementHeading(
            title: s.t('Магия класса', 'Class spellcasting'),
            subtitle: s.t(
                'Изучение относится к уровню этого класса. Общие ячейки не открывают новые круги.',
                'Learning follows this class level. Shared slots do not unlock higher spell circles.')),
        if (plan.needsManualCounts || manualCounts != null)
          CompanionSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(s.t('Выборы по твоей книге', 'Choices from your book'),
                    style: t.titleMedium),
                const SizedBox(height: 8),
                Text(s.t(
                    'В книге нет полной таблицы изучения. Укажи положенный прирост; эти значения применятся только к этому повышению.',
                    'This book has no complete learning table. Enter the choices granted for this advancement.')),
                const SizedBox(height: 12),
                for (final field in [
                  ('normal', s.t('Новые заклинания', 'New spells')),
                  ('cantrip', s.t('Новые заговоры', 'New cantrips'))
                ])
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                          initialValue: '${manualCounts?[field.$1] ?? 0}',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: field.$2),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n >= 0 && n <= 100) {
                              onManualCounts({
                                ...?manualCounts,
                                field.$1: n,
                                'confirmed': 0
                              });
                            }
                          })),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.t('Выбирать из всего Альманаха',
                        'Choose from the entire Almanac')),
                    value: manualCounts?['all'] == 1,
                    onChanged: (v) => onManualCounts({
                          ...?manualCounts,
                          'all': v == true ? 1 : 0,
                          'confirmed': 0
                        })),
                FilledButton.tonal(
                    onPressed: () => onManualCounts({
                          'normal': manualCounts?['normal'] ?? 0,
                          'cantrip': manualCounts?['cantrip'] ?? 0,
                          'all': manualCounts?['all'] ?? 0,
                          'confirmed': 1
                        }),
                    child: Text(
                        s.t('Применить выборы книги', 'Use these choices'))),
              ])),
        for (final choice in plan.choices)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CompanionSurface(
                  contour: CompanionContour.focus,
                  onTap: () => _pick(context, choice),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(_name(choice.kind, s),
                                  style: t.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800))),
                          const SizedBox(width: 10),
                          Text(
                              '${selected[choice.key]?.length ?? 0}/${choice.count}',
                              style: t.titleSmall?.copyWith(color: c.secondary))
                        ]),
                        const SizedBox(height: 8),
                        Text(
                            (selected[choice.key] ?? [])
                                    .map((id) =>
                                        choice.options
                                            .where((v) => v.id == id)
                                            .firstOrNull
                                            ?.getName(s.ru ? 'ru' : 'en') ??
                                        id)
                                    .join(' · ')
                                    .isEmpty
                                ? s.t('Выбрать заклинания', 'Choose spells')
                                : (selected[choice.key] ?? [])
                                    .map((id) =>
                                        choice.options
                                            .where((v) => v.id == id)
                                            .firstOrNull
                                            ?.getName(s.ru ? 'ru' : 'en') ??
                                        id)
                                    .join(' · '),
                            style: t.bodyMedium),
                        if (choice.allowedSchools.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  s.t('Школы подкласса; свободных выборов другой школы: ${choice.freeSchoolChoices}.',
                                      'Subclass schools; unrestricted choices: ${choice.freeSchoolChoices}.'),
                                  style: t.bodySmall)),
                        if (choice.options.length < choice.count)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  s.t('В библиотеке недостаточно подходящих заклинаний.',
                                      'The library does not contain enough eligible spells.'),
                                  style:
                                      t.bodySmall?.copyWith(color: c.error))),
                      ]))),
        if (plan.replaceable.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CompanionSurface(
                  quiet: true,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.t('Замена заклинания', 'Replace a spell'),
                            style: t.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                            s.t('По желанию: забудь одно известное заклинание и изучи новое из списка класса.',
                                'Optional: replace one known spell with another from your class list.'),
                            style: t.bodySmall),
                        const SizedBox(height: 10),
                        OutlinedButton(
                            onPressed: () async {
                              final id = await _single(
                                  context,
                                  s.t('Что заменить', 'Spell to replace'),
                                  plan.replaceable,
                                  replaceOld);
                              if (id != null) onReplace(id, null);
                            },
                            child: Text(replaceOld == null
                                ? s.t('Выбрать известное', 'Choose known spell')
                                : plan.replaceable
                                    .where((s) => s.id == replaceOld)
                                    .first
                                    .getName(s.ru ? 'ru' : 'en'))),
                        if (replaceOld != null)
                          OutlinedButton(
                              onPressed: () async {
                                final id = await _single(
                                    context,
                                    s.t('Новое заклинание',
                                        'Replacement spell'),
                                    plan.replacementsFor(replaceOld),
                                    replaceNew);
                                if (id != null) onReplace(replaceOld, id);
                              },
                              child: Text(replaceNew == null
                                  ? s.t('Выбрать замену', 'Choose replacement')
                                  : plan.replacementOptions
                                      .where((s) => s.id == replaceNew)
                                      .first
                                      .getName(s.ru ? 'ru' : 'en'))),
                        if (replaceOld != null)
                          TextButton(
                              onPressed: () => onReplace(null, null),
                              child: Text(s.t('Оставить как есть',
                                  'Keep the current spell'))),
                      ]))),
        if (plan.choices.isEmpty && !plan.needsManualCounts)
          Text(s.t(
              'Новых выборов заклинаний на этом уровне нет. Изменения запасов показаны в итогах.',
              'No new spell choices at this level. Pool changes appear in the review.')),
      ])),
      AdvancementFooter(
          label: l.next, onPressed: ready ? onNext : null, hint: issue)
    ]);
  }
}

class _SpellPicker extends StatefulWidget {
  const _SpellPicker(
      {required this.title,
      required this.spells,
      required this.limit,
      required this.initial});
  final String title;
  final List<Spell> spells;
  final int limit;
  final List<String> initial;
  @override
  State<_SpellPicker> createState() => _SpellPickerState();
}

class _SpellPickerState extends State<_SpellPicker> {
  late Set<String> _selected = widget.initial.toSet();
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final s = AlmanacStrings(context),
        l = AppLocalizations.of(context)!,
        t = Theme.of(context).textTheme;
    final search = JournalSearch(_query);
    final spells = widget.spells
        .where((v) =>
            search.matches([v.getName(s.ru ? 'ru' : 'en'), v.nameRu, v.nameEn]))
        .toList()
      ..sort((a, b) => a.level != b.level
          ? a.level.compareTo(b.level)
          : a
              .getName(s.ru ? 'ru' : 'en')
              .compareTo(b.getName(s.ru ? 'ru' : 'en')));
    return DraggableScrollableSheet(
        initialChildSize: .9,
        minChildSize: .5,
        maxChildSize: .96,
        expand: false,
        builder: (context, controller) => Column(children: [
              SheetDragRegion(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Row(children: [
                        Expanded(
                            child: Text(widget.title,
                                style: t.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800))),
                        Text('${_selected.length}/${widget.limit}')
                      ]))),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                          hintText: l.searchSpells,
                          prefixIcon: const Icon(Icons.search_rounded)),
                      onChanged: (v) => setState(() => _query = v))),
              const SizedBox(height: 10),
              Expanded(
                  child: ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: spells.length,
                      itemBuilder: (context, i) {
                        final spell = spells[i],
                            selected = _selected.contains(spell.id);
                        return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: CompanionSurface(
                                quiet: !selected,
                                raised: selected,
                                padding: const EdgeInsets.all(14),
                                onTap: () => setState(() => _selected =
                                    toggleAdvancementSelection(
                                        _selected, spell.id, widget.limit)),
                                onLongPress: () => showResponsiveSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    builder: (_) =>
                                        SpellDetailsSheet(spell: spell)),
                                child: Row(children: [
                                  Icon(selected
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(spell.getName(s.ru ? 'ru' : 'en'),
                                            style: t.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 3),
                                        Text(
                                            spell.level == 0
                                                ? l.cantrips
                                                : l.levelLabel(spell.level),
                                            style: t.bodySmall)
                                      ])),
                                  IconButton(
                                      tooltip: s.t('Описание', 'Details'),
                                      onPressed: () =>
                                          showResponsiveSheet<void>(
                                              context: context,
                                              isScrollControlled: true,
                                              useSafeArea: true,
                                              builder: (_) => SpellDetailsSheet(
                                                  spell: spell)),
                                      icon: const Icon(
                                          Icons.info_outline_rounded))
                                ])));
                      })),
              SafeArea(
                  top: false,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              onPressed: _selected.length == widget.limit
                                  ? () =>
                                      Navigator.pop(context, _selected.toList())
                                  : null,
                              child: Text(l.apply))))),
            ]));
  }
}
