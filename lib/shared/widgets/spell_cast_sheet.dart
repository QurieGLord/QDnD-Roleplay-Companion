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
import '../../core/progression/character_class_context.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/companion_kit.dart' show Pressable;
import '../../core/utils/spell_utils.dart';
import '../../features/character_sheet/widgets/class_widgets/instrument/instrument_kit.dart'
    show classAccent;
import 'spell_effects.dart';

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
    final spell = widget.spell;
    List<SpellUseOption> options = [];
    List<SpellUseSource> sources = [];
    String? issue;
    try {
      sources =
          SpellUse.sources(widget.hero, spell, manualAbility: _manualAbility);
      options = SpellUse.options(widget.hero, spell,
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
        : CastingConstraints.forSource(widget.hero, spell, source.id);
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
                .contains(spell.id);
    final classId = source != null && source.id.startsWith('class:')
        ? source.id.substring(6)
        : null;
    final accent =
        classId == null ? c.secondary : classAccent(context, classId);
    final circle = selected?.circle ?? spell.level;
    final effect = spellEffect(
        spell.id, circle == 0 ? 1 : circle, source?.modifier ?? 0, widget.hero,
        ru: s.ru);
    final description = spell.getDescription(locale).toLowerCase();
    // A save the spell imposes names its ability («спасбросок Мудрости»,
    // "Wisdom saving throw"); «+1к4 к спасброскам» is not one.
    final save = RegExp(
            r'спасброс(?:ок|ка|ке|ку|ком|ки)\s+(?:силы|ловкости|телосложения|интеллекта|мудрости|харизмы)|'
            r'(?:strength|dexterity|constitution|intelligence|wisdom|charisma)\s+saving throw|'
            r'сл\s+спасброска|spell save dc')
        .hasMatch(description);
    final attack =
        RegExp(r'атак[уа] заклинанием|spell attack').hasMatch(description);
    final concentration = widget.hero.concentratingOn;
    final replaces = spell.concentration &&
            concentration != null &&
            concentration != spell.id
        ? SpellService.getSpellById(concentration)?.getName(locale) ??
            concentration
        : null;
    final className = classId == null
        ? null
        : CharacterClassContext(widget.hero, classId).name(locale);
    String timeLabel(String value) => SpellUtils.getLocalizedValue(l, value);
    final facts = <(String, String)>[
      (s.t('Время', 'Time'), timeLabel(spell.castingTime)),
      (s.t('Дистанция', 'Range'), timeLabel(spell.range)),
      (
        s.t('Длительность', 'Duration'),
        effect?.duration ?? timeLabel(spell.duration)
      ),
      if (save && source != null)
        (s.t('Сл спаса', 'Save DC'), '${source.saveDC}'),
      if (attack && source != null)
        (
          s.t('Атака', 'Attack'),
          '${source.attack >= 0 ? '+' : ''}${source.attack}'
        ),
    ];
    final higher = spell.getAtHigherLevels(locale);

    Widget rung(SpellUseOption o) {
      final on = _choice == o.key;
      final pool = switch (o.method) {
        SpellUseMethod.sharedSlot => MagicPool.shared,
        SpellUseMethod.pactSlot => MagicPool.pact,
        _ => null,
      };
      var left = 1, max = 1;
      if (pool != null) {
        try {
          final state = MagicSlots.read(widget.hero);
          left = state.remaining(pool, o.circle);
          max = pool == MagicPool.pact
              ? state.pact?.maximum ?? left
              : state.maximum[o.circle - 1];
        } catch (_) {}
      }
      final caption = switch (o.method) {
        SpellUseMethod.sharedSlot => s.t('круг', 'level'),
        SpellUseMethod.pactSlot => s.t('договор', 'pact'),
        SpellUseMethod.ritual => s.t('ритуал', 'ritual'),
        SpellUseMethod.arcanum => s.t('арканум', 'arcanum'),
        SpellUseMethod.mastery => s.t('мастерство', 'mastery'),
        SpellUseMethod.signature => s.t('фирменное', 'signature'),
        SpellUseMethod.cantrip => s.t('заговор', 'cantrip'),
      };
      return Pressable(
        key: ValueKey('cast-rung-${o.method.name}-${o.circle}'),
        onTap: _saving
            ? null
            : () {
                if (on) return;
                HapticFeedback.selectionClick();
                setState(() => _choice = o.key);
              },
        selected: on,
        scale: .95,
        semanticLabel: _label(o, s, l),
        child: AnimatedContainer(
          duration: AppMotion.of(context, const Duration(milliseconds: 220)),
          curve: AppMotion.standard,
          constraints: const BoxConstraints(minWidth: 68),
          padding: const EdgeInsets.all(10),
          transform: Matrix4.translationValues(0, on ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: on
                ? c.secondary.withValues(alpha: .22)
                : c.onSurface.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    on ? c.secondary.withValues(alpha: .6) : Colors.transparent,
                width: 1.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(caption,
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: c.onSurfaceVariant)),
            const SizedBox(height: 5),
            SizedBox(
              height: 24,
              child: Center(
                child: o.method == SpellUseMethod.ritual
                    ? Icon(Icons.menu_book_rounded,
                        size: 22, color: c.onSurface)
                    : Text(
                        o.method == SpellUseMethod.cantrip
                            ? '0'
                            : '${o.circle}',
                        style: const TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            height: 1)),
              ),
            ),
            const SizedBox(height: 5),
            if (o.method == SpellUseMethod.ritual)
              Text(s.t('+10 мин', '+10 min'),
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      color: c.onSurfaceVariant))
            else if (pool != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < max.clamp(0, 6); i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < left ? c.secondary : Colors.transparent,
                      border: i < left
                          ? null
                          : Border.all(color: c.outline, width: 1.4),
                    ),
                  ),
              ])
            else
              const SizedBox(height: 7),
          ]),
        ),
      );
    }

    Widget fact((String, String) f) => Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
              color: c.onSurface.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.$1.toUpperCase(),
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .55,
                    height: 1,
                    color: c.onSurfaceVariant)),
            const SizedBox(height: 5),
            AnimatedSwitcher(
              duration:
                  AppMotion.of(context, const Duration(milliseconds: 380)),
              transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                      position:
                          Tween(begin: const Offset(0, .4), end: Offset.zero)
                              .animate(CurvedAnimation(
                                  parent: a, curve: AppMotion.snappyCurve)),
                      child: child)),
              child: Text(f.$2,
                  key: ValueKey(f.$2),
                  style: const TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.25)),
            ),
          ]),
        );

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
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                          children: [
                        SheetDragRegion(
                            enabled: !_saving,
                            child: Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          [
                                            if (className != null) className,
                                            spell.level == 0
                                                ? s.t('заговор', 'cantrip')
                                                : s.t('${spell.level} круг',
                                                    'level ${spell.level}'),
                                            SpellUtils.getLocalizedSchool(
                                                l, spell.school),
                                          ].join(' · '),
                                          style: TextStyle(
                                              fontFamily: AppType.body,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: accent)),
                                      const SizedBox(height: 8),
                                      Text(spell.getName(locale),
                                          style: const TextStyle(
                                              fontFamily: AppType.display,
                                              fontSize: 26,
                                              fontWeight: FontWeight.w600,
                                              height: 1.15,
                                              letterSpacing: -.4)),
                                    ]))),
                        if (effect != null) ...[
                          Container(
                            key: const ValueKey('spell-cast-effect'),
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color.lerp(
                                        c.surfaceContainerLow, accent, .2)!,
                                    c.surfaceContainerLow
                                  ]),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedSwitcher(
                                    duration: AppMotion.of(context,
                                        const Duration(milliseconds: 420)),
                                    transitionBuilder: (child, a) =>
                                        FadeTransition(
                                            opacity: a,
                                            child: SlideTransition(
                                                position: Tween(
                                                        begin: const Offset(
                                                            0, .35),
                                                        end: Offset.zero)
                                                    .animate(CurvedAnimation(
                                                        parent: a,
                                                        curve: AppMotion
                                                            .snappyCurve)),
                                                child: child)),
                                    layoutBuilder: (current, previous) => Stack(
                                        alignment: Alignment.centerLeft,
                                        children: [
                                          ...previous,
                                          if (current != null) current
                                        ]),
                                    child: Text(effect.value,
                                        key: ValueKey(effect.value),
                                        style: const TextStyle(
                                            fontFamily: AppType.display,
                                            fontSize: 40,
                                            fontWeight: FontWeight.w600,
                                            height: 1,
                                            letterSpacing: -.8)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(effect.label,
                                      style: TextStyle(
                                          fontFamily: AppType.body,
                                          fontSize: 13.5,
                                          color: c.onSurface
                                              .withValues(alpha: .78))),
                                ]),
                          ),
                          const SizedBox(height: 14),
                        ],
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
                        if (sources.length > 1) ...[
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
                          const SizedBox(height: 12),
                        ],
                        if (choices.isNotEmpty &&
                            !(choices.length == 1 &&
                                choices.single.method ==
                                    SpellUseMethod.cantrip)) ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [
                              for (final o in choices) ...[
                                if (o != choices.first)
                                  const SizedBox(width: 8),
                                rung(o),
                              ]
                            ]),
                          ),
                          const SizedBox(height: 14),
                        ] else if (spell.level == 0) ...[
                          _note(
                              context,
                              Icons.auto_awesome_outlined,
                              s.t('Заговор — без ячейки, растёт с уровнем',
                                  'A cantrip — no slot, grows with level')),
                          const SizedBox(height: 14),
                        ],
                        LayoutBuilder(builder: (context, box) {
                          final w = (box.maxWidth - 8) / 2;
                          return Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final f in facts)
                              SizedBox(width: w, child: fact(f)),
                          ]);
                        }),
                        if (effect == null &&
                            higher != null &&
                            higher.trim().isNotEmpty &&
                            spell.level > 0) ...[
                          const SizedBox(height: 10),
                          _Higher(text: higher),
                        ],
                        if (spell.concentration) ...[
                          const SizedBox(height: 12),
                          Wrap(spacing: 6, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 7),
                              decoration: BoxDecoration(
                                  color: classAccent(context, 'warlock')
                                      .withValues(alpha: .18),
                                  borderRadius: BorderRadius.circular(999)),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timer_outlined,
                                        size: 13, color: c.onSurface),
                                    const SizedBox(width: 5),
                                    Text(s.t('Концентрация', 'Concentration'),
                                        style: const TextStyle(
                                            fontFamily: AppType.body,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            height: 1)),
                                  ]),
                            ),
                          ]),
                        ],
                        if (replaces != null) ...[
                          const SizedBox(height: 10),
                          _note(context, Icons.timer_outlined,
                              s.t('Прервёт «$replaces»', 'Ends “$replaces”')),
                        ],
                        if (restrictions.isNotEmpty) ...[
                          const SizedBox(height: 14),
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
                        ],
                        if (CastingConstraints.hasMaterials(spell))
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                  '${s.t('Материалы', 'Materials')}: ${spell.getMaterialComponents(locale) ?? s.t('не указаны в книге', 'not specified in the book')}',
                                  style: t.bodyMedium
                                      ?.copyWith(color: c.onSurfaceVariant))),
                        if (issue != null) ...[
                          const SizedBox(height: 12),
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
                            restrictions.isEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                              s.t('Проверь источник, подготовку и остаток ячеек. Источник старой записи можно указать в описании заклинания.',
                                  'Check the source, preparation and remaining slots. Assign an older spell in its details.'),
                              style: t.bodyMedium),
                        ],
                      ])),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                      child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                              key: const ValueKey('spell-cast-confirm'),
                              style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: c.surface,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(999))),
                              onPressed: _saving || selected == null
                                  ? null
                                  : () => _cast(selected),
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.auto_fix_high_rounded),
                              label: Text(
                                  selected?.method == SpellUseMethod.ritual
                                      ? s.t('Провести ритуал', 'Perform ritual')
                                      : switch (selected?.method) {
                                          SpellUseMethod.sharedSlot => s.t(
                                              'Наложить · ячейка ${selected!.circle} круга',
                                              'Cast · level ${selected.circle} slot'),
                                          SpellUseMethod.pactSlot => s.t(
                                              'Наложить · ячейка договора',
                                              'Cast · pact slot'),
                                          SpellUseMethod.arcanum => s.t(
                                              'Наложить · арканум',
                                              'Cast · arcanum'),
                                          _ => s.t('Наложить заклинание',
                                              'Cast spell'),
                                        },
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontFamily: AppType.body,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600))))),
                ])));
  }

  Widget _note(BuildContext context, IconData icon, String text) {
    final c = Theme.of(context).colorScheme;
    final a5 = classAccent(context, 'warlock');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          color: Color.lerp(c.surfaceContainerLow, a5, .14),
          borderRadius: BorderRadius.circular(18)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: a5)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontFamily: AppType.body, fontSize: 13.5))),
      ]),
    );
  }
}

/// "What a higher slot gives" for spells without a one-line effect.
class _Higher extends StatefulWidget {
  const _Higher({required this.text});
  final String text;
  @override
  State<_Higher> createState() => _HigherState();
}

class _HigherState extends State<_Higher> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _open = !_open);
        },
        semanticLabel: ru ? 'Что даёт круг выше' : 'At higher levels',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedRotation(
              turns: _open ? .5 : 0,
              duration:
                  AppMotion.of(context, const Duration(milliseconds: 240)),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: c.secondary),
            ),
            const SizedBox(width: 6),
            Text(ru ? 'Что даёт круг выше' : 'At higher levels',
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.secondary)),
          ]),
        ),
      ),
      AnimatedSize(
        duration: AppMotion.of(context, const Duration(milliseconds: 320)),
        curve: AppMotion.standard,
        alignment: Alignment.topLeft,
        child: _open
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(widget.text,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.5)))
            : const SizedBox(width: double.infinity),
      ),
    ]);
  }
}
