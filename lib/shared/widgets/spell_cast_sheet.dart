import '../../core/magic/casting_constraints.dart';
import 'magic_allocation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/magic/magic_slots.dart';
import '../../core/magic/spell_use.dart';
import '../../core/models/character.dart';
import '../../core/models/spell.dart';
import '../../core/services/spell_cast_actions_service.dart';
import '../../core/services/spell_service.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/ui/sheet_drag_region.dart';
import '../../l10n/app_localizations.dart';
import '../../features/spell_almanac/spell_almanac_strings.dart';

Future<bool> showSpellCastSheet(
        BuildContext context, Character hero, Spell spell) async =>
    await showResponsiveSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SpellCastSheet(hero: hero, spell: spell)) ??
    false;

class SpellCastSheet extends StatefulWidget {
  const SpellCastSheet({super.key, required this.hero, required this.spell});
  final Character hero;
  final Spell spell;
  @override
  State<SpellCastSheet> createState() => _SpellCastSheetState();
}

class _SpellCastSheetState extends State<SpellCastSheet> {
  String? _source, _manualAbility, _choice;
  bool _saving = false, _tableException = false;
  String _label(SpellUseOption o, AlmanacStrings s, AppLocalizations l) =>
      switch (o.method) {
        SpellUseMethod.sharedSlot => s.t(
            'Общая ячейка · ${l.levelLabel(o.circle)}',
            'Shared slot · ${l.levelLabel(o.circle)}'),
        SpellUseMethod.pactSlot => s.t(
            'Магия договора · ${l.levelLabel(o.circle)}',
            'Pact Magic · ${l.levelLabel(o.circle)}'),
        SpellUseMethod.cantrip => l.cantrips,
        SpellUseMethod.ritual => l.ritual,
        SpellUseMethod.mastery => s.t('Мастерство заклинаний', 'Spell Mastery'),
        SpellUseMethod.signature =>
          s.t('Фирменное заклинание', 'Signature Spell'),
        SpellUseMethod.arcanum => s.t('Таинственный арканум', 'Mystic Arcanum')
      };
  Future<void> _cast(SpellUseOption choice) async {
    if (_saving) return;
    final s = AlmanacStrings(context), old = widget.hero.concentratingOn;
    final restrictions = CastingConstraints.signature(
        widget.hero, widget.spell, choice.source.id);
    if (widget.spell.concentration && old != null && old != widget.spell.id) {
      final name =
          SpellService.getSpellById(old)?.getName(s.ru ? 'ru' : 'en') ?? old;
      final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(
                      s.t('Сменить концентрацию?', 'Replace concentration?')),
                  content: Text(s.t(
                      'Концентрация на «$name» завершится после применения нового заклинания.',
                      'Concentration on "$name" will end when the new spell is cast.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(s.t('Назад', 'Back'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(s.t('Продолжить', 'Continue')))
                  ]));
      if (ok != true || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      await SpellCastActionsService.cast(widget.hero, widget.spell, choice,
          locale: s.ru ? 'ru' : 'en',
          expectedConcentration: old,
          tableException: _tableException,
          expectedRestrictions: restrictions,
          requireCurrentCatalog: true);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.error(
            context,
            s.t('Не удалось применить заклинание. Проверь подготовку и выбранный запас.',
                'Could not cast. Check preparation and the selected pool.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AlmanacStrings(context),
        l = AppLocalizations.of(context)!,
        t = Theme.of(context).textTheme,
        c = Theme.of(context).colorScheme;
    final locale = s.ru ? 'ru' : 'en';
    List<SpellUseOption> options = [];
    List<SpellUseSource> sources = [];
    String? issue;
    try {
      sources = SpellUse.sources(widget.hero, widget.spell,
          manualAbility: _manualAbility);
      options = SpellUse.options(widget.hero, widget.spell,
          manualAbility: _manualAbility, tableException: _tableException);
    } catch (_) {
      issue = s.t(
          'Запасы старого смешанного героя нужно разделить на общие ячейки и Магию договора.',
          'This older multiclass sheet needs separate shared and Pact pools.');
    }
    _source ??= sources.firstOrNull?.id;
    final source = sources.where((s) => s.id == _source).firstOrNull;
    final restrictions = source == null
        ? <CastingConstraint>[]
        : CastingConstraints.forSource(widget.hero, widget.spell, source.id);
    final choices = options.where((o) => o.source.id == _source).toList();
    if (!choices.any((o) => o.key == _choice)) {
      _choice = (choices
                  .where((o) => o.method != SpellUseMethod.ritual)
                  .firstOrNull ??
              choices.firstOrNull)
          ?.key;
    }
    final selected = choices.where((o) => o.key == _choice).firstOrNull;
    final manual =
        ((widget.hero.spellbookData['sources'] as Map?)?['manual'] is Map) &&
            ((widget.hero.spellbookData['sources'] as Map)['manual']
                as Map)['known'] is List &&
            (((widget.hero.spellbookData['sources'] as Map)['manual']
                    as Map)['known'] as List)
                .contains(widget.spell.id);
    return PopScope(
        canPop: !_saving,
        child: DraggableScrollableSheet(
            initialChildSize: .78,
            minChildSize: .4,
            maxChildSize: .95,
            expand: false,
            builder: (context, controller) => Column(children: [
                  Expanded(
                      child: ListView(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          children: [
                        SheetDragRegion(
                            enabled: !_saving,
                            child: Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          widget.spell.level == 0
                                              ? l.cantrips
                                              : l.levelLabel(
                                                  widget.spell.level),
                                          style: t.labelLarge
                                              ?.copyWith(color: c.secondary)),
                                      const SizedBox(height: 7),
                                      Text(widget.spell.getName(locale),
                                          style: t.headlineMedium?.copyWith(
                                              fontWeight: FontWeight.w800)),
                                    ]))),
                        if (manual) ...[
                          Text(
                              s.t('Базовая характеристика решения стола',
                                  'Casting ability for the table ruling'),
                              style: t.labelLarge),
                          Wrap(spacing: 6, children: [
                            for (final ability in [
                              'intelligence',
                              'wisdom',
                              'charisma',
                              'strength',
                              'dexterity',
                              'constitution'
                            ])
                              ChoiceChip(
                                  label: Text(switch (ability) {
                                    'intelligence' =>
                                      s.t('Интеллект', 'Intelligence'),
                                    'wisdom' => s.t('Мудрость', 'Wisdom'),
                                    'strength' => l.abilityStr,
                                    'dexterity' => l.abilityDex,
                                    'constitution' => l.abilityCon,
                                    _ => s.t('Харизма', 'Charisma')
                                  }),
                                  selected: _manualAbility == ability,
                                  onSelected: _saving
                                      ? null
                                      : (_) => setState(() {
                                            _manualAbility = ability;
                                            _source = 'manual';
                                            _tableException = false;
                                          }))
                          ]),
                          const SizedBox(height: 14)
                        ],
                        if (sources.length > 1)
                          Wrap(spacing: 8, runSpacing: 4, children: [
                            for (final source in sources)
                              ChoiceChip(
                                  label: Text(source.label(locale)),
                                  selected: _source == source.id,
                                  onSelected: _saving
                                      ? null
                                      : (_) {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            _source = source.id;
                                            _tableException = false;
                                          });
                                        })
                          ]),
                        if (source != null) ...[
                          const SizedBox(height: 12),
                          CompanionSurface(
                              contour: CompanionContour.focus,
                              padding: const EdgeInsets.all(16),
                              child:
                                  Wrap(spacing: 22, runSpacing: 12, children: [
                                _fact(source.label(locale),
                                    s.t('Источник', 'Source')),
                                _fact('${source.saveDC}', l.spellSaveDC),
                                _fact(
                                    '${source.attack >= 0 ? '+' : ''}${source.attack}',
                                    l.spellAttack)
                              ])),
                          const SizedBox(height: 18)
                        ],
                        if (restrictions.isNotEmpty) ...[
                          CompanionSurface(
                              quiet: true,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        s.t('Перед накладыванием',
                                            'Before casting'),
                                        style: t.titleMedium),
                                    const SizedBox(height: 8),
                                    for (final restriction in restrictions)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Text(restriction.label(locale),
                                              style: t.bodyMedium)),
                                    CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(s.t(
                                            'Мастер разрешил исключение',
                                            'The GM permits an exception')),
                                        subtitle: Text(s.t(
                                            'Только для этого применения. Состояния героя сохраняются.',
                                            'For this casting only. Your character’s conditions are preserved.')),
                                        value: _tableException,
                                        onChanged: _saving
                                            ? null
                                            : (v) => setState(() =>
                                                _tableException = v == true)),
                                  ])),
                          const SizedBox(height: 12),
                        ],
                        if (CastingConstraints.hasMaterials(widget.spell))
                          Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text(
                                  '${s.t('Материалы', 'Materials')}: ${widget.spell.getMaterialComponents(locale) ?? s.t('не указаны в книге', 'not specified in the book')}',
                                  style: t.bodyMedium)),
                        if (issue != null) ...[
                          Text(issue, style: t.bodyMedium),
                          const SizedBox(height: 10),
                          FilledButton.tonal(
                              onPressed: () async {
                                final changed = await showMagicAllocationSheet(
                                    context, widget.hero);
                                if (mounted && changed) setState(() {});
                              },
                              child: Text(s.t(
                                  'Уточнить запасы', 'Resolve spell pools')))
                        ],
                        if (issue == null &&
                            choices.isEmpty &&
                            restrictions.isEmpty)
                          Text(
                              s.t('Проверь источник, подготовку и остаток ячеек. Источник старой записи можно указать в описании заклинания.',
                                  'Check the source, preparation and remaining slots. Assign an older spell in its details.'),
                              style: t.bodyMedium),
                        for (final choice in choices)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: CompanionSurface(
                                  quiet: _choice != choice.key,
                                  raised: _choice == choice.key,
                                  color: _choice == choice.key
                                      ? c.secondaryContainer
                                      : null,
                                  padding: const EdgeInsets.all(15),
                                  onTap: _saving
                                      ? null
                                      : () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _choice = choice.key);
                                        },
                                  child: Row(children: [
                                    Icon(
                                        _choice == choice.key
                                            ? Icons.radio_button_checked_rounded
                                            : Icons
                                                .radio_button_unchecked_rounded,
                                        color: c.secondary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(_label(choice, s, l),
                                              style: t.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w700)),
                                          if (choice.method ==
                                                  SpellUseMethod.sharedSlot ||
                                              choice.method ==
                                                  SpellUseMethod.pactSlot)
                                            Text(
                                                s.t('Осталось ${MagicSlots.read(widget.hero).remaining(choice.method == SpellUseMethod.pactSlot ? MagicPool.pact : MagicPool.shared, choice.circle)}',
                                                    '${MagicSlots.read(widget.hero).remaining(choice.method == SpellUseMethod.pactSlot ? MagicPool.pact : MagicPool.shared, choice.circle)} remaining'),
                                                style: t.bodySmall),
                                          if (choice.method ==
                                              SpellUseMethod.ritual)
                                            Text(
                                                s.t('Время накладывания увеличивается на 10 минут',
                                                    'Casting time increases by 10 minutes'),
                                                style: t.bodySmall),
                                        ]))
                                  ]))),
                      ])),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                              key: const ValueKey('spell-cast-confirm'),
                              style: FilledButton.styleFrom(
                                  backgroundColor: c.secondary,
                                  foregroundColor: c.onSecondary),
                              onPressed: _saving || selected == null
                                  ? null
                                  : () => _cast(selected),
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.auto_awesome_rounded),
                              label: Text(selected?.method ==
                                      SpellUseMethod.ritual
                                  ? s.t('Провести ритуал', 'Perform ritual')
                                  : s.t(
                                      'Наложить заклинание', 'Cast spell'))))),
                ])));
  }

  Widget _fact(String value, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 3),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800))
          ]);
}
