import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';

import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/class_session_actions_service.dart';
import '../../../../l10n/app_localizations.dart';
import 'instrument/instrument_kit.dart';

/// Rogue (prototype `CLASS.rogue`, fourth pass: conditions, not a scene).
/// Sneak Attack waits in the shadow until one condition holds — advantage
/// or an ally beside the target, and no disadvantage; then its dice come
/// out and roll where they lie. Cunning Action and the defences below.
class RogueToolsWidget extends StatefulWidget {
  const RogueToolsWidget({super.key, required this.character});
  final Character character;
  @override
  State<RogueToolsWidget> createState() => _RogueToolsWidgetState();
}

class _RogueToolsWidgetState extends State<RogueToolsWidget> {
  bool _busy = false;
  bool _ally = false, _dis = false, _used = false, _advantage = false;
  List<int>? _rolls;
  int _rollKey = 0, _stealthKey = 0;
  String? _move;
  int? _stealth, _dodge;

  Character get _hero => widget.character;
  CharacterClassContext get _owner => CharacterClassContext(_hero, 'rogue');
  bool get _adv => _advantage || _hero.isHidden;

  Future<void> _setHidden(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ClassSessionActionsService.hidden(_hero, value);
    } catch (_) {
      if (mounted) AppSnackBar.error(context, AppLocalizations.of(context)!.sheetSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  CharacterFeature? _find(List<String> ids) => _hero.features
      .where((f) => _owner.canUseFeature(f) && (ids.contains(f.id.toLowerCase().replaceAll('_', '-')) || ids.contains(f.nameEn.toLowerCase())))
      .firstOrNull;

  int get _stealthBonus {
    final dex = _hero.abilityScores.dexterityModifier;
    if (_hero.expertSkills.contains('stealth')) return dex + _hero.proficiencyBonus * 2;
    if (_hero.proficientSkills.contains('stealth')) return dex + _hero.proficiencyBonus;
    return dex;
  }

  void _newTurn() {
    HapticFeedback.selectionClick();
    setState(() {
      _used = false;
      _rolls = null;
      _move = null;
      _advantage = false;
      _stealth = null;
    });
    if (_hero.isHidden) _setHidden(false);
  }

  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final level = _owner.level;
    final a4 = accentOf(context, 4), a5 = accentOf(context, 5), a2 = accentOf(context, 2);
    final c = Theme.of(context).colorScheme;
    final sneak = _find(['sneak-attack', 'sneak attack']);
    final cunning = _find(['cunning-action', 'cunning action']);
    final dodge = _find(['uncanny-dodge', 'uncanny dodge']);
    final evasion = _find(['evasion']);
    final fastHands = _find(['fast-hands', 'fast hands']);
    final nd = (level + 1) ~/ 2;
    final armed = (_adv || _ally) && !_dis && !_used;
    final k = ru ? 'к' : 'd';
    final status = _rolls != null
        ? (ru ? 'урона сверх атаки' : 'extra damage')
        : _used
            ? (ru ? 'уже в этом ходу' : 'already this turn')
            : _dis
                ? (ru ? 'помеха — скрытой атаки нет' : 'disadvantage — no sneak attack')
                : armed
                    ? (ru ? 'условие выполнено' : 'the condition holds')
                    : (ru ? 'нужно одно условие ниже' : 'one condition below is needed');
    final children = <Widget>[];
    if (sneak != null) {
      children.add(Instrument(
        key: const ValueKey('rogue-sneak-attack'),
        accent: a4,
        title: sneak.getName(locale),
        about: InstrumentAbout(
            title: sneak.getName(locale),
            kicker: ru ? 'Раз в ход' : 'Once a turn',
            paragraphs: sneak.getDescription(locale).split(RegExp(r'\n\s*\n')),
            how: ru
                ? 'Отметьте, что есть: преимущество или союзник у цели. Когда условие выполнено, кости выйдут из тени.'
                : 'Mark what you have: advantage or an ally beside the target. When it holds, the dice come out of the shadow.'),
        background: _Planes(armed: armed || _rolls != null, dim: _dis, a4: a4, a5: a5),
        trailing: InstrumentChip(_used ? (ru ? 'в этом ходу' : 'this turn') : (ru ? 'раз в ход' : 'once a turn')),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _rolls != null ? RollingNumber(_rolls!.fold(0, (a, b) => a + b), style: hugeStyle(context)) : Text('$nd${k}6', style: hugeStyle(context)),
                const SizedBox(height: 4),
                InstrumentHint(status),
              ]),
            ),
            SizedBox(
              width: 170,
              child: Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < nd; i++)
                  AnimatedSlide(
                    offset: armed || _rolls != null ? Offset.zero : const Offset(0, .2),
                    duration: AppMotion.of(context, Duration(milliseconds: 520 + 70 * i)),
                    curve: AppMotion.snappyCurve,
                    child: TumbleDie(
                        shape: DieShape.d6,
                        label: _rolls != null ? '${_rolls![i]}' : '',
                        accent: a4,
                        rollKey: _rollKey,
                        sides: 6,
                        natural: _rolls?[i],
                        dim: !(armed || _rolls != null),
                        size: nd > 4 ? 34 : 44),
                  ),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _Condition(
                    key: const ValueKey('rogue-advantage'),
                    glyph: 'hood',
                    label: _hero.isHidden ? (ru ? 'В тени' : 'Hidden') : (ru ? 'Преимущество' : 'Advantage'),
                    on: _adv,
                    accent: a4,
                    peek: (ru ? 'Преимущество' : 'Advantage', ru ? 'Любая причина: вы спрятались, цель вас не видит, вам помогают' : 'Any reason: you are hidden, the target can’t see you, someone helps'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (_hero.isHidden) {
                        _setHidden(false);
                        setState(() => _advantage = false);
                      } else {
                        setState(() => _advantage = !_advantage);
                      }
                    })),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(ru ? 'или' : 'or', style: hintStyle(context).copyWith(fontSize: 11.5, fontWeight: FontWeight.w600))),
            Expanded(
                child: _Condition(
                    key: const ValueKey('rogue-ally'),
                    glyph: 'person',
                    label: ru ? 'Союзник у цели' : 'Ally by target',
                    on: _ally,
                    accent: a4,
                    peek: (ru ? 'Союзник у цели' : 'Ally by the target', ru ? 'Другой враг цели стоит в 5 фт. от неё' : 'Another enemy of the target is within 5 ft. of it'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _ally = !_ally);
                    })),
          ]),
          const SizedBox(height: 8),
          SwitchRow(
            key: const ValueKey('rogue-disadvantage'),
            label: ru ? 'Помеха на атаку' : 'Disadvantage',
            glyph: 'sun',
            value: _dis,
            accent: a2,
            onChanged: (v) => setState(() => _dis = v),
            peek: (ru ? 'Помеха' : 'Disadvantage', ru ? 'С помехой на атаку скрытой атаки нет' : 'With disadvantage there is no sneak attack'),
          ),
          const SizedBox(height: 12),
          if (_used)
            GhostButton(label: ru ? 'Новый ход' : 'New turn', onTap: _newTurn)
          else
            GoButton(
              key: const ValueKey('rogue-sneak-roll'),
              label: ru ? 'Бросить $nd${k}6' : 'Roll $nd${k}6',
              accent: a4,
              onTap: armed
                  ? () {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        _rolls = [for (var i = 0; i < nd; i++) Random().nextInt(6) + 1];
                        _rollKey++;
                        _used = true;
                      });
                    }
                  : null,
            ),
        ]),
      ));
    }
    if (cunning != null) {
      final moves = <(String, String, String, String)>[
        ('dash', ru ? 'Рывок' : 'Dash', 'dash', ru ? 'Скорость удваивается до конца хода' : 'Your speed doubles this turn'),
        ('back', ru ? 'Отход' : 'Disengage', 'stepback', ru ? 'Перемещение не провоцирует атак' : 'Movement provokes no attacks'),
        ('hide', ru ? 'Засада' : 'Hide', 'hood', ru ? 'Спрятаться: Скрытность к20 ${_stealthBonus >= 0 ? '+' : '−'} ${_stealthBonus.abs()}' : 'Hide: Stealth d20 ${_stealthBonus >= 0 ? '+' : '−'} ${_stealthBonus.abs()}'),
        if (fastHands != null) ('hand', ru ? 'Руки' : 'Hands', 'hand', fastHands.getDescription(locale).split('\n').first),
      ];
      final speed = _hero.speed;
      children.add(LiteBlock(
        key: const ValueKey('rogue-cunning'),
        accent: a4,
        title: cunning.getName(locale),
        about: InstrumentAbout(title: cunning.getName(locale), kicker: ru ? 'Бонусное действие' : 'Bonus action', paragraphs: cunning.getDescription(locale).split(RegExp(r'\n\s*\n'))),
        trailing: InstrumentChip(_move != null ? (ru ? 'бонусное потрачено' : 'bonus used') : (ru ? 'бонусное' : 'bonus')),
        child: TileRow(gap: 6, children: [
          for (final (id, name, glyph, text) in moves)
            _Move(
              key: ValueKey('rogue-move-$id'),
              name: name,
              glyph: glyph,
              accent: a4,
              on: _move == id,
              enabled: _move == null || _move == id,
              peek: (name, text),
              value: switch (id) {
                'dash' => RollingNumber(_move == 'dash' ? speed * 2 : speed, style: bigStyle(context).copyWith(fontSize: 12.5)),
                'hide' => _stealth == null
                    ? Text('${k}20', style: bigStyle(context).copyWith(fontSize: 12.5, color: c.onSurfaceVariant))
                    : TumbleDie(shape: DieShape.d20, label: '$_stealth', accent: a4, rollKey: _stealthKey, sides: 20, size: 30),
                'back' => Text(_move == 'back' ? (ru ? 'без атак' : 'no attacks') : '', style: hintStyle(context).copyWith(fontSize: 11)),
                _ => Text(_move == id ? (ru ? 'предмет' : 'object') : '', style: hintStyle(context).copyWith(fontSize: 11)),
              },
              onTap: () {
                if (_move == id) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _move = null;
                    if (id == 'hide') _stealth = null;
                  });
                  if (id == 'hide' && _hero.isHidden) _setHidden(false);
                  return;
                }
                HapticFeedback.lightImpact();
                setState(() {
                  _move = id;
                  if (id == 'hide') {
                    _stealth = Random().nextInt(20) + 1 + _stealthBonus;
                    _stealthKey++;
                  }
                });
                if (id == 'hide') _setHidden(true);
              },
            ),
        ]),
      ));
    } else if (level < 2) {
      children.add(LockedCell(title: ru ? 'Хитрое действие' : 'Cunning Action', level: 2, accent: a4));
    }
    final defences = <Widget>[
      if (dodge != null)
        CellTile(
          key: const ValueKey('rogue-uncanny-dodge'),
          accent: a5,
          onTap: () async {
            final n = await showNumberKeypad(context, kicker: dodge.getName(locale), title: ru ? 'Урон по вам' : 'Damage to you');
            if (n != null && mounted) setState(() => _dodge = n);
          },
          peek: (dodge.getName(locale), ru ? 'Реакцией: урон от атаки видимого врага — вдвое меньше' : 'Reaction: halve the damage of an attack from an enemy you can see'),
          children: [
            InstrumentGlyph('shield', size: 26, color: a5),
            InstrumentCap(ru ? 'Уклонение' : 'Dodge', accent: a5, about: InstrumentAbout(title: dodge.getName(locale), paragraphs: [dodge.getDescription(locale)])),
            if (_dodge != null)
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('$_dodge', style: bigStyle(context).copyWith(fontSize: 18, color: c.onSurfaceVariant, decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 8),
                RollingNumber(_dodge! ~/ 2, style: bigStyle(context)),
              ])
            else
              InstrumentHint(ru ? 'реакция · урон вдвое' : 'reaction · half damage'),
          ],
        )
      else if (level < 5)
        LockedCell(title: ru ? 'Уклонение' : 'Uncanny Dodge', level: 5, accent: a5),
      if (evasion != null)
        CellTile(
          accent: a2,
          peek: (evasion.getName(locale), evasion.getDescription(locale).split('\n').first),
          children: [
            InstrumentGlyph('wind', size: 26, color: a2),
            InstrumentCap(evasion.getName(locale), accent: a2, about: InstrumentAbout(title: evasion.getName(locale), paragraphs: [evasion.getDescription(locale)])),
            InstrumentHint(ru ? 'спасбросок Ловкости — без урона' : 'a Dexterity save — no damage'),
          ],
        )
      else if (level < 7)
        LockedCell(title: ru ? 'Увёртливость' : 'Evasion', level: 7, accent: a2),
    ];
    if (defences.isNotEmpty) children.add(TileRow(children: defences));
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        children[i],
      ]
    ]);
  }
}

class _Condition extends StatelessWidget {
  const _Condition({super.key, required this.glyph, required this.label, required this.on, required this.accent, required this.onTap, required this.peek});
  final String glyph, label;
  final bool on;
  final Color accent;
  final VoidCallback onTap;
  final (String, String) peek;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Peek(
      title: peek.$1,
      text: peek.$2,
      child: Pressable(
        onTap: onTap,
        scale: .97,
        selected: on,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: on ? mixColor(accent, .22, c.surfaceContainer) : c.onSurface.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? accent : Colors.transparent, width: 1.5),
          ),
          child: Row(children: [
            InstrumentGlyph(glyph, size: 22, color: accent),
            const SizedBox(width: 10),
            Expanded(
                child: label.contains(' ')
                    ? Text(label, style: labelStyle(context, size: 13.5))
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(label, maxLines: 1, style: labelStyle(context, size: 13.5)))),
          ]),
        ),
      ),
    );
  }
}

class _Move extends StatelessWidget {
  const _Move(
      {super.key,
      required this.name,
      required this.glyph,
      required this.accent,
      required this.on,
      required this.enabled,
      required this.value,
      required this.onTap,
      required this.peek});
  final String name, glyph;
  final Color accent;
  final bool on, enabled;
  final Widget value;
  final VoidCallback onTap;
  final (String, String) peek;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : .35,
      child: Peek(
        title: peek.$1,
        text: peek.$2,
        child: Pressable(
          onTap: enabled ? onTap : null,
          scale: .94,
          selected: on,
          semanticLabel: name,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
                color: on ? mixColor(accent, .24, c.surfaceContainer) : c.onSurface.withValues(alpha: .05), borderRadius: BorderRadius.circular(18)),
            child: Column(children: [
              Pulse(trigger: on, child: InstrumentGlyph(glyph, size: 24, color: accent)),
              const SizedBox(height: 5),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle(context, size: 12)),
              const SizedBox(height: 5),
              SizedBox(height: 30, child: Center(child: value)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Overlapping shadow planes that shift aside when the dice come out.
class _Planes extends StatelessWidget {
  const _Planes({required this.armed, required this.dim, required this.a4, required this.a5});
  final bool armed, dim;
  final Color a4, a5;
  @override
  Widget build(BuildContext context) {
    final d = AppMotion.of(context, const Duration(milliseconds: 800));
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: dim ? .3 : 1,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        return Stack(children: [
          AnimatedPositioned(
            duration: d,
            curve: AppMotion.gentleCurve,
            left: w * .4 + (armed ? -24 : 0),
            top: h * .35 + (armed ? -12 : 0),
            width: w * .85,
            height: h,
            child: AnimatedRotation(
              duration: d,
              turns: armed ? -.011 : -.039,
              child: DecoratedBox(decoration: BoxDecoration(color: a4.withValues(alpha: .1), borderRadius: BorderRadius.circular(30))),
            ),
          ),
          AnimatedPositioned(
            duration: d,
            curve: AppMotion.gentleCurve,
            left: -w * .25 + (armed ? 14 : 0),
            top: h * .6 + (armed ? -12 : 0),
            width: w * .95,
            height: h,
            child: AnimatedRotation(
              duration: d,
              turns: armed ? .005 : .025,
              child: DecoratedBox(decoration: BoxDecoration(color: a5.withValues(alpha: .09), borderRadius: BorderRadius.circular(30))),
            ),
          ),
        ]);
      }),
    );
  }
}
