import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/models/character.dart';
import '../../core/magic/magic_slots.dart';
import '../../core/progression/multiclass_rules.dart';
import '../../core/progression/class_spellcasting_profile.dart';
import '../../core/services/gameplay_actions_service.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/ui/sheet_drag_region.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../features/spell_almanac/spell_almanac_strings.dart';

Future<bool> showMagicAllocationSheet(BuildContext context, Character hero,
        {Future<void> Function(MagicSlots)? apply}) async =>
    await showResponsiveSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _AllocationSheet(hero: hero, apply: apply)) ??
    false;

class _AllocationSheet extends StatefulWidget {
  const _AllocationSheet({required this.hero, this.apply});
  final Future<void> Function(MagicSlots)? apply;
  final Character hero;
  @override
  State<_AllocationSheet> createState() => _AllocationSheetState();
}

class _AllocationSheetState extends State<_AllocationSheet> {
  final _form = GlobalKey<FormState>();
  final _values = <String, TextEditingController>{};
  late final String _baseline = jsonEncode([
    widget.hero.spellSlots,
    widget.hero.maxSpellSlots,
    widget.hero.magicData
  ]);
  bool _busy = false;
  int _number(String key) => int.parse(_values[key]!.text.trim());
  TextEditingController _controller(String key, String initial) =>
      _values.putIfAbsent(key, () => TextEditingController(text: initial));
  @override
  void dispose() {
    for (final value in _values.values) {
      value.dispose();
    }
    super.dispose();
  }

  Future<void> _save(int circles, String? owner, int? pactCircle) async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final s = AlmanacStrings(context);
    try {
      final allocation = MagicSlots.allocation(
          current: [for (var i = 1; i <= circles; i++) _number('current-$i')],
          maximum: [for (var i = 1; i <= circles; i++) _number('maximum-$i')],
          pact: owner == null
              ? null
              : PactSlots(
                  owner: owner,
                  circle: pactCircle!,
                  current: _number('pact-current'),
                  maximum: _number('pact-maximum')));
      if (widget.apply != null) {
        await widget.apply!(allocation);
      } else {
        await GameplayActionsService.allocateMagic(widget.hero, allocation,
            expectedState: _baseline);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        AppSnackBar.error(
            context,
            s.t('Не удалось сохранить запасы. Проверь значения; если лист изменился, открой форму заново.',
                'Could not save. Check the values; reopen the form if the sheet changed.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hero = widget.hero,
        s = AlmanacStrings(context),
        l = AppLocalizations.of(context)!,
        t = Theme.of(context).textTheme;
    MagicSlots? existing;
    try {
      existing = MagicSlots.read(hero);
    } catch (_) {}
    final capacity = (() {
      try {
        return MulticlassRules.spellCapacity(hero);
      } catch (_) {
        return null;
      }
    })();
    if (capacity == null) {
      return Padding(
          padding: const EdgeInsets.all(24),
          child: Text(s.t(
              'В сохранённых правилах не хватает сведений о запасах магии. Уточни данные класса в повышении или подключи его книгу.',
              'The saved rules lack spell-pool information. Review the class rules in advancement or add its book.')));
    }
    final pactOwner = hero.classes
        .where((c) {
          try {
            return ClassSpellcastingProfile.resolve(hero, c.id)?.isPact == true;
          } catch (_) {
            return false;
          }
        })
        .firstOrNull
        ?.id;
    final circles = [
      capacity.sharedSlots.length,
      hero.spellSlots.length,
      hero.maxSpellSlots.length
    ].reduce((a, b) => a > b ? a : b).clamp(0, 9);
    int at(List<int> values, int index) =>
        index < values.length ? values[index] : 0;
    Widget field(String key, String label, String initial) => TextFormField(
        controller: _controller(key, initial),
        autofocus: false,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        validator: (v) {
          final n = int.tryParse(v?.trim() ?? '');
          return n == null || n < 0 || n > 999999
              ? s.t(
                  'Впиши целое число от 0', 'Enter a whole number, 0 or higher')
              : null;
        });
    Widget pair(Widget a, Widget b) => LayoutBuilder(
        builder: (context, size) => size.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(14) > 22
            ? Column(children: [a, const SizedBox(height: 12), b])
            : Row(children: [
                Expanded(child: a),
                const SizedBox(width: 12),
                Expanded(child: b)
              ]));
    return PopScope(
        canPop: !_busy,
        child: DraggableScrollableSheet(
            initialChildSize: .88,
            minChildSize: .5,
            maxChildSize: .96,
            expand: false,
            builder: (context, scroll) => Form(
                key: _form,
                child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      SheetDragRegion(
                          enabled: !_busy,
                          child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(s.t('Запасы магии', 'Spell pools'),
                                  style: t.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800)))),
                      Text(existing == null
                          ? s.t(
                              'В старом листе эти запасы хранились вместе. Укажи реальные остатки отдельно. Ничего не будет распределено или восстановлено автоматически.',
                              'This older sheet stored these pools together. Enter their actual remainders separately. Nothing is allocated or restored automatically.')
                          : s.t(
                              'Общие ячейки и Магия договора независимы. Ручные превышения сохраняются.',
                              'Shared slots and Pact Magic are independent. Manual extras are retained.')),
                      const SizedBox(height: 12),
                      if (existing == null)
                        Text(
                            '${s.t('Старый остаток', 'Old remainder')}: ${hero.spellSlots.asMap().entries.where((e) => e.value > 0).map((e) => '${e.key + 1}: ${e.value}').join(' · ')}',
                            style: t.labelLarge),
                      const SizedBox(height: 18),
                      Text(s.t('Общие ячейки', 'Shared slots'),
                          style: t.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      for (var i = 1; i <= circles; i++)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CompanionSurface(
                                quiet: true,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(l.levelLabel(i),
                                          style: t.labelLarge),
                                      const SizedBox(height: 12),
                                      pair(
                                          field(
                                              'current-$i',
                                              s.t('Остаток', 'Remaining'),
                                              existing == null
                                                  ? ''
                                                  : '${at(existing.current, i - 1)}'),
                                          field(
                                              'maximum-$i',
                                              s.t('Обычный максимум',
                                                  'Usual maximum'),
                                              '${existing == null ? at(capacity.sharedSlots, i - 1) : at(existing.maximum, i - 1)}'))
                                    ]))),
                      if (pactOwner != null) ...[
                        const SizedBox(height: 12),
                        Text(s.t('Магия договора', 'Pact Magic'),
                            style: t.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        Text(l.levelLabel(
                            existing?.pact?.circle ?? capacity.pact!.circle)),
                        const SizedBox(height: 12),
                        CompanionSurface(
                            quiet: true,
                            child: pair(
                                field(
                                    'pact-current',
                                    s.t('Остаток', 'Remaining'),
                                    existing == null
                                        ? ''
                                        : '${existing.pact?.current ?? 0}'),
                                field(
                                    'pact-maximum',
                                    s.t('Обычный максимум', 'Usual maximum'),
                                    '${existing?.pact?.maximum ?? capacity.pact!.count}')))
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _save(
                                  circles,
                                  pactOwner,
                                  existing?.pact?.circle ??
                                      capacity.pact?.circle),
                          child: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Text(l.save)),
                    ]))));
  }
}
