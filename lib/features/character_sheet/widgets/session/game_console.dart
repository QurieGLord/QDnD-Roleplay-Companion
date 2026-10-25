import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/magic/magic_slots.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/theme/app_palettes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../core/ui/companion_kit.dart';
import '../../../../core/ui/expressive_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../class_widgets/instrument/instrument_kit.dart';
import '../gameplay_state_editor.dart';
import 'rest_sheet.dart' show hitDieOf;

/// Wave 3 game console (`.dials`): every number of the session on a dial.
/// Drag a number sideways and it turns, tap it to type; each change is one
/// write. Abilities, marks and effects live under "All parameters".
Future<bool> showGameConsole(BuildContext context, Character character) async {
  var changed = false;
  final more = await showCompanionSheet<bool>(context,
      builder: (_) =>
          _Console(character: character, onChanged: () => changed = true));
  if (more == true && context.mounted) {
    return await showGameplayStateEditor(context, character) || changed;
  }
  return changed;
}

class _Dial {
  const _Dial(this.id, this.icon, this.accent, this.label, this.hint, this.read,
      this.write,
      {this.step = 1, this.min = 0, this.max = 9999, this.over});
  final String id, icon, label, hint;
  final int accent, step, min, max;
  final int Function() read;
  final Future<void> Function(int) write;

  /// A note shown when the value goes beyond the usual ("выше нормы").
  final bool Function(int)? over;
}

class _Console extends StatefulWidget {
  const _Console({required this.character, required this.onChanged});
  final Character character;
  final VoidCallback onChanged;
  @override
  State<_Console> createState() => _ConsoleState();
}

class _ConsoleState extends State<_Console> {
  bool _busy = false;
  Character get _c => widget.character;

  Future<void> _save(_Dial dial, int value) async {
    final v = value.clamp(dial.min, dial.max);
    if (v == dial.read() || _busy) return;
    setState(() => _busy = true);
    try {
      await dial.write(v);
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _type(_Dial dial) async {
    final value =
        await showNumberKeypad(context, title: dial.label, kicker: _c.name);
    if (value != null && mounted) await _save(dial, value);
  }

  List<(String, List<_Dial>)> _groups(bool ru, String locale) {
    final c = _c;
    final form =
        c.isWildShaped && c.beastCurrentHp != null && c.beastMaxHp != null;
    Future<void> health({int? current, int? maximum, int? temporary}) =>
        GameplayActionsService.editHealth(c,
            current: current ?? c.currentHp,
            maximum: maximum ?? c.maxHp,
            temporary: temporary ?? c.temporaryHp);
    final core = <_Dial>[
      _Dial(
          'hp',
          'heart',
          0,
          ru ? 'Текущие ОЗ' : 'Current HP',
          ru
              ? 'Норма — максимум; выше — переполнение'
              : 'Usually up to the maximum; above is overflow',
          () => c.currentHp,
          (v) => health(current: v),
          over: (v) => v > c.maxHp),
      _Dial(
          'max',
          'heart',
          0,
          ru ? 'Максимум ОЗ' : 'Maximum HP',
          ru
              ? 'Обычно считается от уровня и Телосложения'
              : 'Usually from level and Constitution',
          () => c.maxHp,
          (v) => health(maximum: v),
          min: 1),
      _Dial(
          'temp',
          'shield',
          4,
          ru ? 'Временные ОЗ' : 'Temporary HP',
          ru ? 'Снимаются уроном первыми' : 'Damage takes them first',
          () => c.temporaryHp,
          (v) => health(temporary: v)),
      if (form)
        _Dial(
            'beast',
            'paw',
            3,
            ru ? 'ОЗ формы' : 'Form HP',
            c.beastName ?? (ru ? 'Дикий облик' : 'Wild Shape'),
            () => c.beastCurrentHp!,
            (v) => GameplayActionsService.editHealth(c,
                current: v,
                maximum: c.beastMaxHp!,
                temporary: c.temporaryHp,
                form: true)),
      _Dial(
          'ac',
          'shield',
          4,
          ru ? 'Класс доспеха' : 'Armour class',
          ru
              ? 'Вручную поверх расчёта из снаряжения'
              : 'By hand over the equipment value',
          () => c.armorClass,
          (v) => GameplayActionsService.editArmorClass(c,
              automatic: false, value: v),
          max: 40),
      _Dial(
          'speed',
          'run',
          3,
          ru ? 'Скорость' : 'Speed',
          ru ? 'Футы за ход' : 'Feet per turn',
          () => c.speed,
          (v) => GameplayActionsService.combat(c, () => c.speed = v),
          step: 5,
          max: 200),
      if (c.hitDice.length == c.classes.length)
        for (var i = 0; i < c.classes.length; i++)
          _Dial(
              'hd-$i',
              'dice',
              1,
              '${ru ? 'Кости хитов' : 'Hit Dice'}${hitDieOf(c.classes[i]) == null ? '' : ' · ${ru ? 'к' : 'd'}${hitDieOf(c.classes[i])}'}',
              '${ru ? 'Из' : 'Of'} ${c.classes[i].level}${c.classes.length > 1 ? ' · ${CharacterClassContext(c, c.classes[i].id).name(locale)}' : ''}',
              () => c.hitDice[i],
              (v) => GameplayActionsService.combat(c, () {
                    c.hitDice = List<int>.of(c.hitDice)..[i] = v;
                  }),
              max: c.classes[i].level),
      _Dial(
          'exh',
          'timer',
          1,
          ru ? 'Истощение' : 'Exhaustion',
          ru ? 'От 0 до 6' : 'From 0 to 6',
          () => c.exhaustionLevel,
          (v) => GameplayActionsService.editExhaustion(c, v),
          max: 6),
    ];
    final magic = <_Dial>[];
    try {
      final slots = MagicSlots.read(c);
      for (var l = 1; l <= slots.maximum.length; l++) {
        final m = slots.maximum[l - 1];
        if (m <= 0) continue;
        magic.add(_Dial(
            'slot-$l',
            'wand',
            4,
            ru ? 'Ячейки $l круга' : 'Level $l slots',
            '${ru ? 'Из' : 'Of'} $m',
            () => MagicSlots.read(c).remaining(MagicPool.shared, l),
            (v) =>
                GameplayActionsService.editMagicSlot(c, MagicPool.shared, l, v),
            over: (v) => v > m));
      }
      final pact = slots.pact;
      if (pact != null) {
        magic.add(_Dial(
            'pact',
            'eye',
            5,
            ru
                ? 'Магия договора · ${pact.circle} круг'
                : 'Pact Magic · level ${pact.circle}',
            '${ru ? 'Из' : 'Of'} ${pact.maximum}',
            () => MagicSlots.read(c).pact?.current ?? 0,
            (v) => GameplayActionsService.editMagicSlot(
                c, MagicPool.pact, pact.circle, v)));
      }
    } catch (_) {}
    final resources = <_Dial>[
      for (final f in c.features)
        if (f.resourcePool != null && !Character.isChannelDivinityResource(f))
          _Dial(
              'pool-${f.id}',
              'star',
              2,
              f.getName(locale),
              '${ru ? 'Из' : 'Of'} ${f.resourcePool!.maxUses}',
              () => f.resourcePool!.currentUses,
              (v) => GameplayActionsService.editResource(c, f, v)),
      if (c.channelDivinityResource case final CharacterFeature cd?)
        _Dial(
            'channel',
            'sun',
            2,
            AppLocalizations.of(context)!.channelDivinity,
            '${ru ? 'Из' : 'Of'} ${c.getMaxChannelDivinityCharges()}',
            () => c.editableChannelDivinityCharges,
            (v) => GameplayActionsService.editResource(c, cd, v)),
      if (c.classLevel('druid') >= 2 || c.isWildShaped)
        _Dial(
            'wild',
            'paw',
            3,
            AppLocalizations.of(context)!.wildShape,
            '${ru ? 'Из' : 'Of'} 2',
            () => c.wildShapeCharges,
            (v) =>
                GameplayActionsService.combat(c, () => c.wildShapeCharges = v)),
    ];
    return [
      (ru ? 'Здоровье и защита' : 'Health and defence', core),
      if (magic.isNotEmpty) (ru ? 'Магия' : 'Magic', magic),
      if (resources.isNotEmpty) (ru ? 'Ресурсы' : 'Resources', resources),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context);
    final c = Theme.of(context).colorScheme;
    final groups = _groups(ru, ru ? 'ru' : 'en');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(_c.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontFamily: AppType.body,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.secondary)),
      const SizedBox(height: 8),
      SheetHeading(ru ? 'Игровые параметры' : 'Game parameters',
          subtitle: ru
              ? 'Тяните число вбок — оно крутится; коснитесь, чтобы ввести.'
              : 'Drag a number sideways to turn it; tap to type it.'),
      for (final g in groups) ...[
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(g.$1.toUpperCase(),
              style: TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: c.onSurfaceVariant)),
        ),
        for (final d in g.$2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DialRow(
                key: ValueKey('console-${d.id}'),
                dial: d,
                busy: _busy,
                onSave: (v) => _save(d, v),
                onType: () => _type(d)),
          ),
      ],
      const SizedBox(height: 8),
      ToneButton(
        key: const ValueKey('console-done'),
        kind: ToneKind.primary,
        height: 52,
        expand: true,
        label: ru ? 'Готово' : 'Done',
        onPressed: () => Navigator.pop(context, false),
      ),
      const SizedBox(height: 4),
      TextButton(
        key: const ValueKey('console-all'),
        onPressed: () => Navigator.pop(context, true),
        child: Text(AppLocalizations.of(context)!.conditionsAllParameters),
      ),
    ]);
  }
}

class _DialRow extends StatefulWidget {
  const _DialRow(
      {super.key,
      required this.dial,
      required this.busy,
      required this.onSave,
      required this.onType});
  final _Dial dial;
  final bool busy;
  final ValueChanged<int> onSave;
  final VoidCallback onType;
  @override
  State<_DialRow> createState() => _DialRowState();
}

class _DialRowState extends State<_DialRow> {
  int? _drag;
  double _x0 = 0;
  int _v0 = 0;

  void _start(DragStartDetails d) {
    if (widget.busy) return;
    _x0 = d.localPosition.dx;
    _v0 = widget.dial.read();
    setState(() => _drag = _v0);
  }

  void _move(DragUpdateDetails d) {
    if (_drag == null) return;
    final steps = ((d.localPosition.dx - _x0) / 9).truncate();
    final next = (_v0 + steps * widget.dial.step)
        .clamp(widget.dial.min, widget.dial.max);
    if (next != _drag) {
      HapticFeedback.selectionClick();
      setState(() => _drag = next);
    }
  }

  void _end([DragEndDetails? _]) {
    final v = _drag;
    setState(() => _drag = null);
    if (v != null) widget.onSave(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final d = widget.dial;
    final accent = AppAccents.of(context).at(d.accent);
    final value = _drag ?? d.read();
    final active = _drag != null;
    final over = d.over?.call(value) ?? false;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: accent.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(12)),
          child: InstrumentGlyph(d.icon, size: 18, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.label,
                style: const TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w600)),
            Text(d.hint,
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 11.5,
                    height: 1.3,
                    color: c.onSurfaceVariant)),
          ]),
        ),
        if (over)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: AppAccents.of(context).at(1).withValues(alpha: .16)),
            child: Text(ru ? 'выше нормы' : 'above usual',
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppAccents.of(context).at(1))),
          ),
        Semantics(
          button: true,
          label: '${d.label}: $value',
          hint: ru ? 'Тяните вбок или коснитесь' : 'Drag sideways or tap',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.busy ? null : widget.onType,
            onHorizontalDragStart: _start,
            onHorizontalDragUpdate: _move,
            onHorizontalDragEnd: _end,
            onHorizontalDragCancel: _end,
            child: AnimatedContainer(
              duration:
                  AppMotion.of(context, const Duration(milliseconds: 200)),
              constraints: const BoxConstraints(minWidth: 92),
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active
                    ? accent.withValues(alpha: .22)
                    : c.onSurface.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                    color: active ? accent : Colors.transparent, width: 1.5),
              ),
              child: Stack(alignment: Alignment.center, children: [
                RollingNumber(value,
                    style: const TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w600)),
                Positioned(
                  bottom: 4,
                  child: Opacity(
                    opacity: .5,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < 9; i++)
                        Container(
                            width: 2,
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            color: c.onSurface),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
