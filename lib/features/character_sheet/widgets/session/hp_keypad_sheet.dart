import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../core/models/character.dart';
import '../../../../core/models/combat_turn.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/services/spell_service.dart';
import '../../../../core/theme/app_palettes.dart';
import '../../../../core/ui/expressive_kit.dart';
import '../class_widgets/instrument/instrument_kit.dart' show InstrumentGlyph;

enum HpChange { damage, healing, temporary }

// The last applied amount per hero, for "same as last time" at the table.
final _lastAmount = <String, int>{};

/// Damage, healing and temporary HP from one number pad: the amount is
/// typed with the thumb, quick amounts sit above the keys, and the button
/// names exactly what will happen.
Future<bool> showHpKeypad(BuildContext context, Character character,
    {HpChange mode = HpChange.damage}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final l10n = AppLocalizations.of(context)!;
  // The sheet answers with the concentration DC to announce, 0 for none.
  final dc = await showCompanionSheet<int>(context,
      builder: (_) => _HpKeypad(character: character, mode: mode));
  if (dc == null) return false;
  if (dc > 0 && context.mounted) {
    AppSnackBar.info(context, l10n.sheetConcentrationDc(dc));
  }
  return true;
}

class _HpKeypad extends StatefulWidget {
  const _HpKeypad({required this.character, required this.mode});
  final Character character;
  final HpChange mode;
  @override
  State<_HpKeypad> createState() => _HpKeypadState();
}

/// Damage types of the prototype (`DTYPES`): the accent of each and
/// whether it is physical (halved by rage).
const _damageTypes = <(String, int, bool)>[
  ('none', 1, false),
  ('bludgeoning', 1, true),
  ('piercing', 4, true),
  ('slashing', 0, true),
  ('fire', 1, false),
  ('cold', 4, false),
  ('poison', 3, false),
  ('psychic', 5, false),
  ('radiant', 2, false),
  ('necrotic', 5, false),
  ('force', 5, false),
  ('thunder', 4, false),
  ('lightning', 2, false),
  ('acid', 3, false),
];

/// Rage halves bludgeoning, piercing and slashing damage.
bool resistsDamage(Character hero, String type) =>
    hero.isRaging && _damageTypes.any((d) => d.$1 == type && d.$3);

class _HpKeypadState extends State<_HpKeypad> {
  late HpChange _mode = widget.mode;
  int _amount = 0;
  String _type = 'none';
  bool _saving = false;

  Character get _hero => widget.character;
  bool get _form =>
      _hero.isWildShaped &&
      _hero.beastCurrentHp != null &&
      _hero.beastMaxHp != null;

  void _set(int value) {
    HapticFeedback.selectionClick();
    setState(() => _amount = value.clamp(0, 9999));
  }

  void _key(String key) {
    if (key == 'del') return _set(_amount ~/ 10);
    final next = int.parse('$_amount$key');
    _set(math.min(next, 9999));
  }

  /// The damage that actually lands: halved by rage against physical
  /// types, and by Uncanny Dodge when it was readied.
  int _effective(int amount) {
    var n = amount;
    if (resistsDamage(_hero, _type)) n ~/= 2;
    if (_hero.combatState.isInCombat &&
        CombatTurn(_hero.combatState).halveNext) {
      n ~/= 2;
    }
    return n;
  }

  Future<void> _apply() async {
    if (_amount <= 0 || _saving) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    final amount = _amount;
    final concentration =
        _mode == HpChange.damage && _hero.concentratingOn != null;
    final landed = _effective(amount);
    try {
      switch (_mode) {
        case HpChange.damage:
          // Rage halves before the shared rule; Uncanny Dodge is applied
          // there, once.
          final raw = resistsDamage(_hero, _type) ? amount ~/ 2 : amount;
          if (raw > 0) await GameplayActionsService.takeHit(_hero, raw);
        case HpChange.healing:
          await GameplayActionsService.changeHealth(_hero, amount,
              healing: true);
        case HpChange.temporary:
          // Temporary HP never stacks: the larger pool stays.
          await GameplayActionsService.editHealth(_hero,
              current: _hero.currentHp,
              maximum: _hero.maxHp,
              temporary: math.max(_hero.temporaryHp, amount));
      }
      _lastAmount[_hero.id] = amount;
      if (_mode == HpChange.damage && _hero.currentHp == 0) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      if (!mounted) return;
      Navigator.pop(
          context, concentration && landed > 0 ? math.max(10, landed ~/ 2) : 0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, l10n.sheetSaveFailed);
    }
  }

  String _actionLabel(AppLocalizations l10n, bool ru) {
    if (_amount == 0) {
      return switch (_mode) {
        HpChange.damage => l10n.hpKeypadEnterDamage,
        HpChange.healing => l10n.hpKeypadEnterHealing,
        HpChange.temporary => l10n.hpKeypadEnterTemporary,
      };
    }
    return switch (_mode) {
      HpChange.damage => ru
          ? 'Получить ${_effective(_amount)} урона'
          : 'Take ${_effective(_amount)} damage',
      HpChange.healing => l10n.hpKeypadApplyHealing(_amount),
      HpChange.temporary =>
        ru ? 'Дать $_amount временных' : 'Give $_amount temporary',
    };
  }

  String _typeName(AppLocalizations l10n, String type, bool ru) =>
      switch (type) {
        'bludgeoning' => l10n.damageTypeBludgeoning,
        'piercing' => l10n.damageTypePiercing,
        'slashing' => l10n.damageTypeSlashing,
        'fire' => l10n.damageTypeFire,
        'cold' => l10n.damageTypeCold,
        'poison' => l10n.damageTypePoison,
        'psychic' => l10n.damageTypePsychic,
        'radiant' => l10n.damageTypeRadiant,
        'necrotic' => l10n.damageTypeNecrotic,
        'force' => l10n.damageTypeForce,
        'thunder' => l10n.damageTypeThunder,
        'lightning' => l10n.damageTypeLightning,
        'acid' => l10n.damageTypeAcid,
        _ => ru ? 'Без типа' : 'Untyped',
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final accents = AppAccents.of(context);
    final heal = AppPaletteRoles.heal(context);
    final last = _lastAmount[_hero.id];
    final form = _form;
    final hp = form ? _hero.beastCurrentHp! : _hero.currentHp;
    final max = math.max(1, form ? _hero.beastMaxHp! : _hero.maxHp);
    final temp0 = form ? 0 : _hero.temporaryHp;
    // The preview: where health and the shield will be after this.
    var to = hp, temp = temp0;
    String note = '';
    if (_mode == HpChange.damage) {
      final eff = _effective(_amount);
      final fromTemp = math.min(temp, eff);
      temp -= fromTemp;
      to = math.max(0, hp - (eff - fromTemp));
      note = [
        if (fromTemp > 0)
          ru ? 'Щит снимет $fromTemp.' : 'The shield takes $fromTemp.',
        if (to == 0 && hp > 0)
          ru ? 'Герой упадёт без сознания.' : 'The hero falls unconscious.',
        if (hp == 0 && !form)
          ru
              ? 'Без сознания: это провал спасброска.'
              : 'Unconscious: this is a failed death save.',
      ].join(' ');
    } else if (_mode == HpChange.healing) {
      to = math.min(max, hp + _amount);
    } else {
      temp = math.max(temp, _amount);
    }
    final modeColor = switch (_mode) {
      HpChange.damage => c.primary,
      HpChange.healing => heal,
      HpChange.temporary => accents.at(4),
    };
    final rage = _mode == HpChange.damage && resistsDamage(_hero, _type);
    final dodge = _mode == HpChange.damage &&
        _hero.combatState.isInCombat &&
        CombatTurn(_hero.combatState).halveNext;
    final concentration = _hero.concentratingOn;
    final concName = concentration == null
        ? null
        : SpellService.getSpellById(concentration)?.getName(ru ? 'ru' : 'en') ??
            concentration;

    Widget key(String value) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _Key(
              key: ValueKey('hp-key-$value'),
              label: value == 'del' ? l10n.hpKeypadErase : value,
              onTap: _saving ? null : () => _key(value),
              child: value == 'del'
                  ? LineIcon('del', size: 24, color: c.onSurface)
                  : Text(value,
                      style: AppType.numeric(t.textTheme.titleLarge)
                          .copyWith(fontSize: 22, fontWeight: FontWeight.w600)),
            ),
          ),
        );
    Widget noteBox(String icon, Color accent, String text) => Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
              color: Color.alphaBlend(
                  accent.withValues(alpha: .14), c.surfaceContainerLow),
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            InstrumentGlyph(icon, size: 17, color: accent),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        fontFamily: AppType.body, fontSize: 13, height: 1.3))),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(_hero.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontFamily: AppType.body,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.secondary)),
      const SizedBox(height: 12),
      FlowSegment<HpChange>(
        keyPrefix: 'hp-mode',
        values: HpChange.values,
        labels: [l10n.damage, l10n.heal, l10n.hpKeypadTemporary],
        selected: _mode,
        onChanged: (mode) => setState(() => _mode = mode),
      ),
      const SizedBox(height: 14),
      // The preview: from → to, with the bar and the shield.
      Container(
        key: const ValueKey('hp-preview'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('$hp${temp0 > 0 ? ' +$temp0' : ''}',
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppType.tabular,
                    color: c.onSurfaceVariant)),
            const SizedBox(width: 8),
            LineIcon('forward', size: 16, color: c.onSurfaceVariant),
            const SizedBox(width: 8),
            RollingNumber(to,
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.6,
                    color: modeColor)),
            if (temp > 0)
              Text(' +$temp',
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: accents.at(4))),
            const SizedBox(width: 8),
            Expanded(
              child: Text(ru ? 'из $max' : 'of $max',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 13,
                      color: c.onSurfaceVariant)),
            ),
          ]),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final shieldW = math.min(1.0, temp / max), p = to / max;
            return SizedBox(
              height: 14,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: c.onSurface.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(7)))),
                AnimatedPositioned(
                  duration:
                      AppMotion.of(context, const Duration(milliseconds: 520)),
                  curve: AppMotion.snappyCurve,
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: w * p,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: _mode == HpChange.healing ? heal : c.primary,
                          borderRadius: BorderRadius.circular(7))),
                ),
                if (temp > 0)
                  AnimatedPositioned(
                    duration: AppMotion.of(
                        context, const Duration(milliseconds: 520)),
                    curve: AppMotion.snappyCurve,
                    left: w * (p - math.min(p, shieldW)),
                    width: w * shieldW,
                    top: -3,
                    bottom: -3,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: accents.at(4).withValues(alpha: .45),
                            border:
                                Border.all(color: accents.at(4), width: 1.5),
                            borderRadius: BorderRadius.circular(9))),
                  ),
              ]),
            );
          }),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(note,
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 12.5,
                    color: c.onSurfaceVariant)),
          ],
        ]),
      ),
      if (_mode == HpChange.damage) ...[
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(children: [
            for (final d in _damageTypes) ...[
              _TypeChip(
                key: ValueKey('hp-type-${d.$1}'),
                label: _typeName(l10n, d.$1, ru),
                accent: accents.at(d.$2),
                selected: _type == d.$1,
                onTap: _saving
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() => _type = d.$1);
                      },
              ),
              const SizedBox(width: 6),
            ]
          ]),
        ),
      ],
      if (rage) ...[
        const SizedBox(height: 12),
        noteBox(
            'axe',
            accents.at(1),
            ru
                ? 'Ярость: сопротивление — урон вдвое меньше (${_amount ~/ 2})'
                : 'Rage: resistance — half damage (${_amount ~/ 2})'),
      ],
      if (dodge) ...[
        const SizedBox(height: 12),
        noteBox(
            'stepback',
            accents.at(4),
            ru
                ? 'Невероятное уклонение: урон вдвое'
                : 'Uncanny Dodge: half damage'),
      ],
      if (_mode == HpChange.damage && concName != null && _amount > 0) ...[
        const SizedBox(height: 12),
        noteBox(
            'timer',
            accents.at(5),
            ru
                ? 'Концентрация «$concName»: спасбросок Сл ${math.max(10, _effective(_amount) ~/ 2)}'
                : 'Concentration “$concName”: save DC ${math.max(10, _effective(_amount) ~/ 2)}'),
      ],
      if (_mode == HpChange.temporary &&
          temp0 > 0 &&
          _amount > 0 &&
          _amount <= temp0) ...[
        const SizedBox(height: 12),
        noteBox(
            'shield',
            accents.at(4),
            ru
                ? 'Временные ОЗ не складываются: останутся $temp0'
                : 'Temporary HP does not stack: $temp0 stays'),
      ],
      const SizedBox(height: 10),
      Semantics(
        liveRegion: true,
        child: Center(
          child: RollingNumber(_amount,
              key: const ValueKey('hp-keypad-amount'),
              style: AppType.numeric(t.textTheme.displayMedium).copyWith(
                  fontSize: 64,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.9,
                  color: _amount == 0 ? c.onSurfaceVariant : c.onSurface)),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final n in const [1, 5, 10])
              OutlineChip(
                  label: '+$n',
                  onTap: _saving ? null : () => _set(_amount + n)),
            if (last != null)
              OutlineChip(
                  label: l10n.hpKeypadSameAsLast(last),
                  onTap: _saving ? null : () => _set(last)),
          ]),
      const SizedBox(height: 10),
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['del', '0', '00'],
      ])
        Row(children: [for (final k in row) key(k)]),
      const SizedBox(height: 10),
      SizedBox(
        height: 56,
        child: FilledButton(
          key: const ValueKey('hp-keypad-apply'),
          style: FilledButton.styleFrom(
              backgroundColor: modeColor,
              foregroundColor: c.surface,
              disabledBackgroundColor: modeColor.withValues(alpha: .35),
              shape: const StadiumBorder()),
          onPressed: _amount == 0 || _saving ? null : _apply,
          child: Text(_actionLabel(l10n, ru),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }
}

/// A damage type: a dot of its accent and the name; the chosen one takes
/// a tinted fill, a ring and tighter corners.
class _TypeChip extends StatelessWidget {
  const _TypeChip(
      {super.key,
      required this.label,
      required this.accent,
      required this.selected,
      this.onTap});
  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      selected: selected,
      scale: .95,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 260)),
        curve: AppMotion.snappyCurve,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  accent.withValues(alpha: .22), c.surfaceContainerLow)
              : c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(selected ? 10 : 14),
          border: Border.all(
              color: selected ? accent : Colors.transparent, width: 1.4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 12.5,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: selected ? c.onSurface : c.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// A number-pad key: 56 high, corners 18, on the low surface; it dips and
/// lights up while pressed.
class _Key extends StatefulWidget {
  const _Key({super.key, required this.child, required this.label, this.onTap});
  final Widget child;
  final String label;
  final VoidCallback? onTap;
  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: Pressable(
        onTap: widget.onTap,
        scale: .94,
        semanticLabel: widget.label,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _down ? c.surfaceContainerHigh : c.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18)),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
