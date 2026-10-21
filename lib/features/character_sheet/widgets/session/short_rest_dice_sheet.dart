import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/models/character.dart';
import '../../../../core/progression/character_class_rules.dart';
import '../../../../core/services/hit_dice_rest_service.dart';
import '../../../../core/ui/companion_surface.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../core/ui/sheet_drag_region.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../spell_almanac/spell_almanac_strings.dart';

Future<bool> showShortRestDiceSheet(
        BuildContext context, Character hero) async =>
    await showResponsiveSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _RestDiceSheet(hero: hero)) ??
    false;

class _RestDiceSheet extends StatefulWidget {
  const _RestDiceSheet({required this.hero});
  final Character hero;
  @override
  State<_RestDiceSheet> createState() => _RestDiceSheetState();
}

class _RestDiceSheetState extends State<_RestDiceSheet> {
  final _rolls = <HitDieRoll>[];
  bool _busy = false;
  Future<void> _roll(String classId, int die) async {
    final s = AlmanacStrings(context);
    final value = await showResponsiveSheet<int>(
        context: context,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${s.t('Кость хитов', 'Hit Die')} · d$die',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: () => Navigator.pop(
                          context, math.Random().nextInt(die) + 1),
                      icon: const Icon(Icons.casino_outlined),
                      label:
                          Text(s.t('Бросить в приложении', 'Roll in the app'))),
                  const SizedBox(height: 12),
                  Text(s.t('Или выбери результат своей кости',
                      'Or enter your own die result')),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (var i = 1; i <= die; i++)
                      ActionChip(
                          label: Text('$i'),
                          onPressed: () => Navigator.pop(context, i))
                  ]),
                ]))));
    if (value != null && mounted) {
      setState(() => _rolls.add(HitDieRoll(classId, value)));
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = AlmanacStrings(context);
    try {
      final healed = await HitDiceRestService.shortRest(widget.hero, _rolls);
      if (mounted) {
        AppSnackBar.success(
            context,
            s.t('Короткий отдых · восстановлено $healed ОЗ',
                'Short rest · $healed HP restored'));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        AppSnackBar.error(
            context,
            s.t('Не удалось завершить отдых. Проверь остаток костей.',
                'Could not complete the rest. Check remaining Hit Dice.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AlmanacStrings(context),
        l = AppLocalizations.of(context)!,
        t = Theme.of(context).textTheme,
        hero = widget.hero;
    final con = hero.abilityScores.constitutionModifier,
        total = _rolls.fold<int>(
            0,
            (sum, r) =>
                sum +
                math.max(0, r.value + hero.abilityScores.constitutionModifier));
    final current = hero.isWildShaped && hero.beastCurrentHp != null
        ? hero.beastCurrentHp!
        : hero.currentHp;
    final maximum = hero.isWildShaped && hero.beastMaxHp != null
        ? hero.beastMaxHp!
        : hero.maxHp;
    final healed = math.min(total, math.max(0, maximum - current));
    return PopScope(
        canPop: !_busy,
        child: DraggableScrollableSheet(
            initialChildSize: .8,
            minChildSize: .45,
            maxChildSize: .95,
            expand: false,
            builder: (context, controller) => ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    children: [
                      SheetDragRegion(
                          enabled: !_busy,
                          child: Text(l.shortRest,
                              style: t.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800))),
                      const SizedBox(height: 12),
                      Text(s.t(
                          'Кости каждого класса расходуются отдельно. Можно отдохнуть без бросков.',
                          'Each class has its own Hit Dice. You can rest without rolling.')),
                      const SizedBox(height: 18),
                      for (var i = 0; i < hero.classes.length; i++)
                        Builder(builder: (context) {
                          final entry = hero.classes[i],
                              data = CharacterClassRules.resolve(entry).data;
                          final remaining = (i < hero.hitDice.length
                                  ? hero.hitDice[i]
                                  : 0) -
                              _rolls.where((r) => r.classId == entry.id).length;
                          return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: CompanionSurface(
                                  quiet: true,
                                  child: Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                  data.getName(
                                                      s.ru ? 'ru' : 'en'),
                                                  style: t.titleSmall),
                                              Text(
                                                  'd${data.hitDie} · $remaining/${entry.level}',
                                                  style: t.labelLarge)
                                            ]),
                                        FilledButton.tonal(
                                            onPressed: _busy || remaining < 1
                                                ? null
                                                : () => _roll(
                                                    entry.id, data.hitDie),
                                            child: Text(s.t('Потратить кость',
                                                'Spend a die'))),
                                      ])));
                        }),
                      if (_rolls.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          for (var i = 0; i < _rolls.length; i++)
                            InputChip(
                                label: Text(
                                    '${_rolls[i].value}${con < 0 ? '' : '+'}$con'),
                                onDeleted: _busy
                                    ? null
                                    : () => setState(() => _rolls.removeAt(i)))
                        ]),
                        const SizedBox(height: 14)
                      ],
                      CompanionSurface(
                          contour: CompanionContour.focus,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.t('После отдыха', 'After the rest'),
                                    style: t.labelLarge),
                                const SizedBox(height: 8),
                                Text(
                                    '$current → ${current + healed} ${l.hpShort}',
                                    style: t.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Text(l.sheetRestPreserves, style: t.bodySmall),
                              ])),
                      const SizedBox(height: 18),
                      FilledButton(
                          onPressed: _busy ? null : _save, child: Text(l.rest)),
                    ])));
  }
}
