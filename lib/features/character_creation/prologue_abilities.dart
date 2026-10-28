import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/expressive_kit.dart';
import '../../core/ui/page_kit.dart';
import '../character_level_up/widgets/advancement_climb.dart' show SoftSize;
import '../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';
import 'character_creation_state.dart';
import 'prologue.dart';

/// «В чём его сила?» (wave 6): the standard set, point buy or a roll.
/// Values sit in a tray as tokens; a token picked and an ability tapped
/// sends the value flying into its tile, where the number rolls up. The
/// roll throws six dice out of the button: they spin down smoothly, land
/// with a small soft halo, and their values drift into the tray.
class PrologueAbilities extends StatefulWidget {
  const PrologueAbilities({super.key});
  @override
  State<PrologueAbilities> createState() => _PrologueAbilitiesState();
}

class _PrologueAbilitiesState extends State<PrologueAbilities> {
  int? _pick;
  final _tokens = List.generate(6, (_) => GlobalKey());
  final _slots = List.generate(6, (_) => GlobalKey());
  final _tiles = {
    for (final key in CharacterCreationState.abilityKeys) key: GlobalKey()
  };
  final _filled = <int, int>{};
  int _round = 0;
  int _nudge = 0;
  final _timers = <Timer>[];

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  CharacterCreationState get _s => context.read<CharacterCreationState>();

  /// Which tokens are already placed: a repeated value counts once per tile.
  List<bool> _used(CharacterCreationState s) {
    final pool = s.scorePool;
    final placed = s.assignedScores.values.toList();
    return [
      for (var i = 0; i < pool.length; i++)
        placed.where((v) => v == pool[i]).length >
            pool.take(i).where((v) => v == pool[i]).length
    ];
  }

  void _tapToken(int i) {
    HapticFeedback.selectionClick();
    setState(() => _pick = _pick == i ? null : i);
  }

  void _tapTile(String id) {
    final s = _s;
    if (s.allocationMethod == 'point_buy') {
      _buy(id);
      return;
    }
    if (_pick != null) {
      final v = s.scorePool[_pick!];
      final from = _tokens[_pick!];
      HapticFeedback.lightImpact();
      setState(() => _pick = null);
      prologueFly(context, from, _tiles[id]!, '$v',
          done: () => mounted ? _s.assignScore(id, v) : null);
    } else if (s.assignedScores[id] != null) {
      final v = s.assignedScores[id]!;
      HapticFeedback.selectionClick();
      s.assignScore(id, null);
      // The value flies back to the first free token that carries it.
      final used = _used(s);
      final back = [
        for (var i = 0; i < s.scorePool.length; i++)
          if (s.scorePool[i] == v && !used[i]) i
      ].firstOrNull;
      if (back != null) prologueFly(context, _tiles[id]!, _tokens[back], '$v');
    } else {
      HapticFeedback.lightImpact();
      setState(() => _nudge++);
    }
  }

  void _auto() {
    final s = _s;
    final cls = s.selectedClass;
    final primary = [
      ...?cls?.primaryAbilities,
      'constitution',
      'dexterity',
      ...CharacterCreationState.abilityKeys
    ];
    final order = <String>[];
    for (final k in primary) {
      if (CharacterCreationState.abilityKeys.contains(k) && !order.contains(k)) {
        order.add(k);
      }
    }
    final values = [...s.scorePool]..sort((a, b) => b.compareTo(a));
    HapticFeedback.lightImpact();
    s.clearAssignedScores();
    setState(() => _pick = null);
    final reduced = MediaQuery.disableAnimationsOf(context);
    for (var i = 0; i < order.length && i < values.length; i++) {
      void place() {
        if (!mounted) return;
        final used = _used(_s);
        final from = [
          for (var t = 0; t < values.length; t++)
            if (_s.scorePool[t] == values[i] && !used[t]) t
        ].firstOrNull;
        HapticFeedback.selectionClick();
        if (from == null || reduced) {
          _s.assignScore(order[i], values[i]);
        } else {
          prologueFly(context, _tokens[from], _tiles[order[i]]!, '${values[i]}',
              done: () => mounted ? _s.assignScore(order[i], values[i]) : null);
        }
      }

      if (reduced) {
        place();
      } else {
        _timers.add(Timer(Duration(milliseconds: i * 110), place));
      }
    }
  }

  Future<void> _buy(String id) async {
    final tr = Tr(context);
    final l = AppLocalizations.of(context)!;
    await showCompanionSheet<void>(context, builder: (sheet) {
      return Consumer<CharacterCreationState>(builder: (sheet, s, _) {
        final c = Theme.of(sheet).colorScheme;
        final bonus = s.racialBonus(id);
        final current = s.pointBuy[id]!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageSheetHead(
                    kicker: tr.t('Покупка очков', 'Point buy'),
                    title: abilityName(l, id),
                    sub: tr.t(
                        'Осталось очков: ${s.pointBuyLeft}. Выше 13 каждое очко стоит дороже.',
                        'Points left: ${s.pointBuyLeft}. Above 13 each point costs more.')),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, box) {
                  final w = (box.maxWidth - 24) / 4;
                  return Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final e in CharacterCreationState.pointBuyCost.entries)
                      Builder(builder: (context) {
                        final on = e.key == current;
                        final ok = s.pointBuyLeft +
                                CharacterCreationState.pointBuyCost[current]! -
                                e.value >=
                            0;
                        return SizedBox(
                          width: w,
                          child: Opacity(
                            opacity: ok ? 1 : .3,
                            child: Pressable(
                              onTap: ok
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      s.setPointBuy(id, e.key);
                                      Navigator.of(sheet).pop();
                                    }
                                  : null,
                              scale: .94,
                              child: AnimatedContainer(
                                duration: AppMotion.of(context, AppMotion.medium),
                                padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
                                decoration: BoxDecoration(
                                    color: on ? c.secondary : c.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(on ? 12 : 18)),
                                child: Column(children: [
                                  Text.rich(
                                      TextSpan(children: [
                                        TextSpan(text: '${e.key}'),
                                        if (bonus != 0)
                                          TextSpan(
                                              text: ' →${e.key + bonus}',
                                              style: const TextStyle(fontSize: 12)),
                                      ]),
                                      style: TextStyle(
                                          fontFamily: AppType.display,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          color: on ? c.surface : c.onSurface)),
                                  const SizedBox(height: 6),
                                  Text(tr.t('${e.value} оч.', '${e.value} pt'),
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: on
                                              ? c.surface.withValues(alpha: .8)
                                              : c.onSurfaceVariant)),
                                ]),
                              ),
                            ),
                          ),
                        );
                      }),
                  ]);
                }),
              ]),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CharacterCreationState>();
    final tr = Tr(context);
    final l = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    final accent = prologueAccent(context, s);
    final method = s.allocationMethod;
    final prime = (s.selectedClass?.primaryAbilities ?? const []).take(2).toSet();
    final used = _used(s);
    final rolling = method == 'roll' && s.rolledScores == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, prologueDockRoom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Segment(
          value: method,
          options: [
            ('standard_array', tr.t('Набор', 'Standard')),
            ('point_buy', tr.t('Покупка', 'Point buy')),
            ('roll', tr.t('Бросок', 'Roll')),
          ],
          onChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() {
              _pick = null;
              _filled.clear();
              _round++;
            });
            s.setAllocationMethod(v);
          },
        ),
        const SizedBox(height: 16),
        SoftSize(
          duration: AppMotion.of(context, AppMotion.long),
          curve: AppMotion.standard,
          alignment: Alignment.topCenter,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (method == 'point_buy')
              _Budget(left: s.pointBuyLeft)
            else ...[
              // The dice stay after the roll: faded, they fold away while
              // the tray rises into their place.
              if (method == 'roll')
                PageReveal(
                  open: rolling,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DiceRoller(
                      key: ValueKey('roller-$_round'),
                      accent: accent,
                      slots: _slots,
                      onSlot: (i, v) => setState(() => _filled[i] = v),
                      onRolled: (values) => s.setRolledScores(values),
                    ),
                  ),
                ),
              _Shake(
                key: ValueKey('tray-$_nudge'),
                shake: _nudge > 0,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: c.onSurface.withValues(alpha: .04),
                      borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    for (var i = 0; i < 6; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        // A filled place turns into a token softly.
                        child: AnimatedSwitcher(
                          duration: AppMotion.of(context, AppMotion.long),
                          switchInCurve: AppMotion.standard,
                          switchOutCurve: AppMotion.standard,
                          child: rolling
                              ? _Slot(key: _slots[i], value: _filled[i])
                              : _Token(
                                  key: _tokens[i],
                                  value: s.scorePool[i],
                                  picked: _pick == i,
                                  used: used[i],
                                  onTap: used[i] ? null : () => _tapToken(i),
                                ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
              PageReveal(
                open: !rolling,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                  PrologueChip(
                      label: tr.t('Расставить по классу', 'Place by class'),
                      icon: 'spark',
                      selected: false,
                      onTap: _auto),
                  PrologueChip(
                      label: tr.t('Вернуть все', 'Take all back'),
                      icon: 'back',
                      selected: false,
                      onTap: () {
                        setState(() => _pick = null);
                        s.clearAssignedScores();
                      }),
                  if (method == 'roll')
                    PrologueChip(
                        label: tr.t('Перебросить', 'Roll again'),
                        icon: 'dice',
                        selected: false,
                        onTap: () {
                          setState(() {
                            _pick = null;
                            _filled.clear();
                            _round++;
                          });
                          s.setRolledScores(null);
                        }),
                ]),
                  ),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 8) / 2;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final id in CharacterCreationState.abilityKeys)
              SizedBox(
                width: w,
                child: _Tile(
                  key: _tiles[id],
                  name: abilityName(l, id),
                  base: s.baseScore(id),
                  bonus: s.racialBonus(id),
                  method: method,
                  prime: prime.contains(id),
                  wanted: _pick != null && s.baseScore(id) == null,
                  accent: accent,
                  onTap: () => _tapTile(id),
                ),
              ),
          ]);
        }),
        PrologueHint(method == 'point_buy'
            ? tr.t('27 очков: значение от 8 до 15. Касание характеристики — выбрать значение.',
                '27 points: values from 8 to 15. Tap an ability to choose its value.')
            : tr.t(
                '${method == 'roll' ? 'Каждый бросок — 4к6 без меньшей кости.' : 'Стандартный набор: 15, 14, 13, 12, 10, 8.'} Касание значения, затем характеристики. Звезда — главные для класса.',
                '${method == 'roll' ? 'Each roll is 4d6, dropping the lowest.' : 'The standard set: 15, 14, 13, 12, 10, 8.'} Tap a value, then an ability. The star marks the class\'s main ones.')),
      ]),
    );
  }
}

/// A token in the tray (`.tok`): picked, it lifts and rounds out; placed,
/// it fades to an outline.
class _Token extends StatelessWidget {
  const _Token(
      {super.key,
      required this.value,
      required this.picked,
      required this.used,
      this.onTap});
  final int value;
  final bool picked, used;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return Pressable(
      onTap: onTap,
      scale: .92,
      selected: picked,
      semanticLabel: '$value',
      child: AnimatedSlide(
        duration: dur,
        curve: AppMotion.snappyCurve,
        offset: Offset(0, picked ? -.06 : 0),
        child: AnimatedOpacity(
          duration: AppMotion.of(context, AppMotion.medium),
          opacity: used ? .18 : 1,
          child: AspectRatio(
            aspectRatio: 1,
            child: AnimatedContainer(
              duration: dur,
              curve: AppMotion.snappyCurve,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: picked
                    ? c.secondary
                    : used
                        ? Colors.transparent
                        : c.surfaceContainer,
                borderRadius: BorderRadius.circular(picked ? 26 : 16),
                border: Border.all(
                    color: c.onSurface.withValues(alpha: used ? .2 : .1), width: 1.5),
                boxShadow: [
                  if (picked)
                    BoxShadow(color: c.secondary.withValues(alpha: .25), spreadRadius: 4),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('$value',
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: picked ? c.surface : c.onSurface)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An empty place in the tray before the roll; a landed value fills it.
class _Slot extends StatelessWidget {
  const _Slot({super.key, this.value});
  final int? value;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.medium),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: value == null ? Colors.transparent : c.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: c.onSurface.withValues(alpha: value == null ? .18 : .1),
              width: 1.5),
        ),
        child: value == null
            ? null
            : TweenAnimationBuilder<double>(
                key: ValueKey(value),
                tween: Tween(begin: 1.25, end: 1),
                duration: AppMotion.of(context, AppMotion.snappySettle),
                curve: AppMotion.snappyCurve,
                builder: (context, t, child) => Transform.scale(scale: t, child: child),
                child: Text('$value',
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: c.onSurface)),
              ),
      ),
    );
  }
}

/// An ability tile (`.abx`): its name (a star for the class's main ones),
/// the value with the people's bonus rolling up, the modifier and a line
/// that says what a tap does.
class _Tile extends StatelessWidget {
  const _Tile(
      {super.key,
      required this.name,
      required this.base,
      required this.bonus,
      required this.method,
      required this.prime,
      required this.wanted,
      required this.accent,
      required this.onTap});
  final String name, method;
  final int? base;
  final int bonus;
  final bool prime, wanted;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final tr = Tr(context);
    final value = base == null ? null : base! + bonus;
    final mod = value == null ? null : ((value - 10) / 2).floor();
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    final note = base == null
        ? (wanted ? tr.t('Сюда', 'Here') : tr.t('Пусто', 'Empty'))
        : bonus != 0
            ? tr.t('$base + $bonus народ', '$base + $bonus people')
            : method == 'point_buy'
                ? tr.t('${CharacterCreationState.pointBuyCost[base]} оч.',
                    '${CharacterCreationState.pointBuyCost[base]} pt')
                : tr.t('Касание — вернуть', 'Tap to take back');
    return Pressable(
      onTap: onTap,
      scale: .97,
      semanticLabel: name,
      child: AnimatedContainer(
        duration: dur,
        curve: AppMotion.snappyCurve,
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(wanted ? 16 : 22),
          gradient: base == null
              ? null
              : LinearGradient(
                  begin: const Alignment(-.6, -1),
                  end: const Alignment(.6, 1),
                  colors: [pageMix(accent, .12, c.surfaceContainerLow), c.surfaceContainerLow],
                  stops: const [0, .7]),
          color: base == null ? c.surfaceContainerLow : null,
          border: Border.all(
              color: wanted
                  ? c.secondary.withValues(alpha: .6)
                  : prime
                      ? accent.withValues(alpha: .3)
                      : Colors.transparent,
              width: wanted ? 2 : 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: c.onSurfaceVariant)),
            ),
            if (prime) ...[
              const SizedBox(width: 6),
              LineIcon('star', size: 13, color: accent),
            ],
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            value == null
                ? Text('—',
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 34,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: c.onSurfaceVariant))
                : RollingNumber(value,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 34,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.68,
                        color: c.onSurface)),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: dur,
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: mod == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(mod),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                          color: accent.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(mod >= 0 ? '+$mod' : '−${-mod}',
                          style: TextStyle(
                              fontFamily: AppType.display,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color.lerp(c.onSurface, accent, .8))),
                    ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(note, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// The point-buy budget: a ring that empties as points are spent.
class _Budget extends StatelessWidget {
  const _Budget({required this.left});
  final int left;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final tr = Tr(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: c.onSurface.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        SizedBox.square(
          dimension: 54,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (left / 27).clamp(0, 1)),
            duration: AppMotion.of(context, AppMotion.snappySettle),
            curve: AppMotion.standard,
            builder: (context, t, _) => CustomPaint(
              painter: _Ring(t, c.secondary, c.onSurface.withValues(alpha: .1)),
              child: Center(
                child: RollingNumber(left,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: left < 0 ? c.error : c.onSurface)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr.t('очков осталось из 27', 'points left of 27'),
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.onSurface)),
            const SizedBox(height: 2),
            Text(tr.t('Касание характеристики — выбрать значение от 8 до 15',
                    'Tap an ability to choose a value from 8 to 15'),
                style: TextStyle(fontSize: 13, height: 1.3, color: c.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

class _Ring extends CustomPainter {
  _Ring(this.t, this.color, this.track);
  final double t;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * t, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_Ring old) => old.t != t || old.color != color;
}

/// Three methods in one capsule (`.seg5`): the chosen one fills.
class _Segment extends StatelessWidget {
  const _Segment({required this.value, required this.options, required this.onChanged});
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        for (final (id, label) in options)
          Expanded(
            child: Pressable(
              key: ValueKey('prologue-method-$id'),
              onTap: id == value ? null : () => onChanged(id),
              selected: id == value,
              scale: .96,
              child: AnimatedContainer(
                duration: dur,
                curve: AppMotion.snappyCurve,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: id == value ? c.secondaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(18)),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: id == value ? c.onSecondaryContainer : c.onSurfaceVariant)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// The tray shakes when an empty ability is tapped with nothing picked.
class _Shake extends StatelessWidget {
  const _Shake({super.key, required this.shake, required this.child});
  final bool shake;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!shake || MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (context, t, child) => Transform.translate(
          offset: Offset(math.sin(t * math.pi * 3) * 6 * (1 - t), 0), child: child),
      child: child,
    );
  }
}

/// Six dice rise out of the button in its place and spin down smoothly,
/// each slowing to its own stop; a landed die warms with a small halo and
/// one quiet ring, as on the launch screen. Then each value drifts into
/// its place in the tray.
class _DiceRoller extends StatefulWidget {
  const _DiceRoller(
      {super.key,
      required this.accent,
      required this.slots,
      required this.onSlot,
      required this.onRolled});
  final Color accent;
  final List<GlobalKey> slots;
  final void Function(int index, int value) onSlot;
  final ValueChanged<List<int>> onRolled;
  @override
  State<_DiceRoller> createState() => _DiceRollerState();
}

class _DiceRollerState extends State<_DiceRoller> with TickerProviderStateMixin {
  final _rnd = math.Random();
  final _dice = List.generate(6, (_) => GlobalKey());
  List<int>? _sums;
  late final List<AnimationController> _spin = [
    for (var i = 0; i < 6; i++)
      AnimationController(vsync: this, duration: Duration(milliseconds: 1500 + i * 110))
  ];
  late final List<AnimationController> _land = [
    for (var i = 0; i < 6; i++)
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
  ];
  late final Ticker _flicker = createTicker(_tick);
  final _faces = List<String>.filled(6, '');
  final _last = List<Duration>.filled(6, Duration.zero);
  final _landed = List<bool>.filled(6, false);
  final _sent = List<bool>.filled(6, false);
  final _timers = <Timer>[];
  static const _soft = Cubic(.16, 1, .3, 1);

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _flicker.dispose();
    for (final c in [..._spin, ..._land]) {
      c.dispose();
    }
    super.dispose();
  }

  int _fourDropLowest() {
    final d = List.generate(4, (_) => 1 + _rnd.nextInt(6))..sort();
    return d[1] + d[2] + d[3];
  }

  void _roll() {
    if (_sums != null) return;
    final sums = List.generate(6, (_) => _fourDropLowest());
    HapticFeedback.lightImpact();
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onRolled(sums);
      return;
    }
    setState(() => _sums = sums);
    for (final c in _spin) {
      c.forward();
    }
    _flicker.start();
  }

  void _tick(Duration now) {
    var all = true;
    setState(() {
      for (var i = 0; i < 6; i++) {
        if (_landed[i]) continue;
        all = false;
        final p = _spin[i].value;
        if (p >= .94) {
          _landed[i] = true;
          _faces[i] = '${_sums![i]}';
          _land[i].forward();
          HapticFeedback.selectionClick();
        } else if ((now - _last[i]).inMilliseconds > 60 + p * p * 260) {
          // The face changes ever more slowly as the spin dies down.
          _last[i] = now;
          _faces[i] = '${3 + _rnd.nextInt(16)}';
        }
      }
    });
    if (all) {
      _flicker.stop();
      HapticFeedback.lightImpact();
      _send();
    }
  }

  void _later(int ms, VoidCallback f) =>
      _timers.add(Timer(Duration(milliseconds: ms), () => mounted ? f() : null));

  void _send() {
    final sums = _sums!;
    for (var i = 0; i < 6; i++) {
      _later(650 + i * 150, () {
        setState(() => _sent[i] = true);
        prologueFly(context, _dice[i], widget.slots[i], '${sums[i]}', done: () {
          HapticFeedback.selectionClick();
          widget.onSlot(i, sums[i]);
        });
      });
    }
    _later(650 + 6 * 150 + 600, () {
      HapticFeedback.mediumImpact();
      widget.onRolled(sums);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final tr = Tr(context);
    final started = _sums != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 56,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          return Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: started,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 260),
                  curve: AppMotion.exit,
                  opacity: started ? 0 : 1,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 260),
                    scale: started ? .97 : 1,
                    child: Pressable(
                      key: const ValueKey('prologue-roll'),
                      onTap: _roll,
                      scale: .97,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: c.secondaryContainer,
                            borderRadius: BorderRadius.circular(26)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          LineIcon('dice', size: 20, color: c.onSecondaryContainer),
                          const SizedBox(width: 8),
                          Text(tr.t('Бросить кости', 'Roll the dice'),
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: c.onSecondaryContainer)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (started)
              for (var i = 0; i < 6; i++)
                Positioned(
                  left: w / 6 * i,
                  width: w / 6,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _die(i, w / 2 - w / 6 * (i + .5))),
                ),
          ]);
        }),
      ),
      const SizedBox(height: 12),
      Text(tr.t('Каждый кубик — 4к6 без меньшего', 'Each die is 4d6, dropping the lowest'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: c.onSurfaceVariant)),
    ]);
  }

  Widget _die(int i, double dx) {
    final a = widget.accent;
    final spin = (300 + i * 40) * math.pi / 180;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 700),
      curve: AppMotion.standard,
      opacity: _sent[i] ? .4 : 1,
      child: AnimatedBuilder(
        animation: Listenable.merge([_spin[i], _land[i]]),
        builder: (context, _) {
          final p = _soft.transform(_spin[i].value);
          // Two stretches, as the prototype's keyframes: out of the button
          // to near its place, then the last slow turn into it.
          late double x, scale, turn, fade;
          if (p < .38) {
            final q = p / .38;
            x = dx + (dx * .2 - dx) * q;
            scale = .55 + (.96 - .55) * q;
            turn = -spin + (spin * .75) * q;
            fade = q;
          } else {
            final q = (p - .38) / .62;
            x = dx * .2 * (1 - q);
            scale = .96 + .04 * q;
            turn = -spin * .25 * (1 - q);
            fade = 1;
          }
          final land = _land[i].value;
          final halo = AppMotion.standard.transform((land / (900 / 1100)).clamp(0, 1));
          final ring = AppMotion.standard.transform(land);
          final pulse = 1 + .06 * (1 - AppMotion.standard.transform((land / (520 / 1100)).clamp(0, 1))) *
              (land > 0 ? 1 : 0);
          return Opacity(
            opacity: fade.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(x, 0),
              child: Transform.rotate(
                angle: turn,
                child: Transform.scale(
                  scale: scale * pulse,
                  child: SizedBox.square(
                    key: _dice[i],
                    dimension: 48,
                    child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                      // A small, steady halo; calm mode keeps it closer.
                      Positioned(
                        left: -9,
                        right: -9,
                        top: -9,
                        bottom: -9,
                        child: Opacity(
                          opacity: halo,
                          child: Transform.scale(
                            scale: .7 + .3 * halo,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  a.withValues(alpha: .3 * (1 - .5 * AppCalm.of(context).level)),
                                  a.withValues(alpha: .1),
                                  a.withValues(alpha: 0),
                                ], stops: const [0, .6, 1]),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (land > 0 && land < 1)
                        Opacity(
                          opacity: .32 * (1 - ring),
                          child: Transform.scale(
                            scale: .85 + .7 * ring,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: a.withValues(alpha: .7), width: 1.5)),
                            ),
                          ),
                        ),
                      DieFace(
                          shape: DieShape.d20,
                          label: _faces[i],
                          accent: a,
                          size: 48,
                          glow: .3 * halo),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A value flies from one place to another as a small token on a low arc,
/// then [done] runs (`fly()` of the prototype).
void prologueFly(BuildContext context, GlobalKey from, GlobalKey to, String text,
    {VoidCallback? done}) {
  final overlay = Overlay.maybeOf(context);
  final a = from.currentContext?.findRenderObject() as RenderBox?;
  final b = to.currentContext?.findRenderObject() as RenderBox?;
  if (overlay == null ||
      a == null ||
      b == null ||
      !a.attached ||
      !b.attached ||
      MediaQuery.disableAnimationsOf(context)) {
    done?.call();
    return;
  }
  final box = overlay.context.findRenderObject() as RenderBox;
  final start = a.localToGlobal(Offset.zero, ancestor: box) & a.size;
  final end = b.localToGlobal(Offset.zero, ancestor: box) & b.size;
  late final OverlayEntry entry;
  entry = OverlayEntry(
      builder: (_) => _Flyer(
          start: start,
          end: end,
          text: text,
          theme: Theme.of(context),
          onDone: () {
            entry.remove();
            done?.call();
          }));
  overlay.insert(entry);
}

class _Flyer extends StatefulWidget {
  const _Flyer(
      {required this.start,
      required this.end,
      required this.text,
      required this.theme,
      required this.onDone});
  final Rect start, end;
  final String text;
  final ThemeData theme;
  final VoidCallback onDone;
  @override
  State<_Flyer> createState() => _FlyerState();
}

class _FlyerState extends State<_Flyer> with SingleTickerProviderStateMixin {
  late final _t = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 460))
    ..forward().whenComplete(widget.onDone);
  static const _curve = Cubic(.3, 0, .2, 1);

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.theme.colorScheme;
    final side = math.min(widget.start.shortestSide, 52.0);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final p = _curve.transform(_t.value);
          final center = Offset.lerp(widget.start.center, widget.end.center, p)! +
              Offset(0, -30 * math.sin(math.pi * p));
          final scale = p < .5 ? 1 + .24 * p : 1.12 - .64 * (p - .5);
          return Stack(children: [
            Positioned(
              left: center.dx - side / 2,
              top: center.dy - side / 2,
              width: side,
              height: side,
              child: Opacity(
                opacity: (1 - .8 * math.max(0, p - .5) * 2).clamp(0, 1),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: c.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.onSurface.withValues(alpha: .12), width: 1.5)),
                    child: Text(widget.text,
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                            color: c.onSurface)),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
