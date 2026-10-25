import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

enum DiceType {
  d4(4, 'd4'),
  d6(6, 'd6'),
  d8(8, 'd8'),
  d10(10, 'd10'),
  d12(12, 'd12'),
  d20(20, 'd20'),
  d100(100, 'd100');

  final int sides;
  final String label;
  const DiceType(this.sides, this.label);
}

enum AdvantageType { none, advantage, disadvantage }

/// Wave 3 dice tray (`docs/prototypes/wave3`, `.dpick`, `.tray`, `.total`):
/// dice of every kind wait above the tray; a tap lays one in, a tap in the
/// tray takes it out. A throw tumbles them all, a natural 20 rings gold and
/// sparks, a 1 cracks; the total rolls up beside its breakdown. A check or
/// attack opens the tray with its d20 and modifier already set.
void showDiceRoller(
  BuildContext context, {
  String? title,
  int modifier = 0,
  DiceType initialDice = DiceType.d20,
}) {
  showCompanionSheet<void>(context,
      builder: (_) => DiceRollerModal(
          title: title, initialModifier: modifier, initialDice: initialDice));
}

class DiceRollerModal extends StatefulWidget {
  final String? title;
  final int initialModifier;
  final DiceType initialDice;

  /// Source of rolls; tests inject a fixed one.
  final Random? random;

  const DiceRollerModal({
    super.key,
    this.title,
    this.initialModifier = 0,
    this.initialDice = DiceType.d20,
    this.random,
  });

  @override
  State<DiceRollerModal> createState() => _DiceRollerModalState();
}

/// The accent of each die, as on the picker and in the tray.
int _accentIndex(DiceType d) => switch (d) {
      DiceType.d4 => 2,
      DiceType.d6 => 1,
      DiceType.d8 => 3,
      DiceType.d10 => 4,
      DiceType.d12 => 5,
      DiceType.d20 => 0,
      DiceType.d100 => -1,
    };

Color _accent(BuildContext context, DiceType d) {
  final i = _accentIndex(d);
  return i < 0
      ? Theme.of(context).colorScheme.secondary
      : AppAccents.of(context).at(i);
}

class _Die {
  _Die(this.type, {this.twin = false});
  final DiceType type;
  final bool twin;
  int? value;
  bool dropped = false;
  int rollKey = 0;
  final key = GlobalKey();
}

class _Result {
  const _Result(this.total, this.kept, this.crit, this.fumble);
  final int total;
  final List<_Die> kept;
  final bool crit, fumble;
}

class _DiceRollerModalState extends State<DiceRollerModal>
    with TickerProviderStateMixin {
  late final List<_Die> _tray = [
    if (widget.title != null) _Die(widget.initialDice)
  ];
  late int _modifier = widget.initialModifier;
  AdvantageType _advantage = AdvantageType.none;
  final _history = <(String, int)>[];
  bool _rolling = false;
  _Result? _result;
  int _resultKey = 0;
  final _timers = <Timer>[];
  late final _gold = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
  late final _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 480));
  final _trayKey = GlobalKey();
  Offset? _sparkAt;

  Random get _random => widget.random ?? Random();

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _gold.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _after(int ms, VoidCallback f) =>
      _timers.add(Timer(Duration(milliseconds: ms), () {
        if (mounted) f();
      }));

  void _add(DiceType type) {
    if (_rolling) return;
    final ru = instrumentRu(context);
    if (_tray.length >= 8) {
      showToast(ru ? 'Не больше восьми костей' : 'Eight dice at most');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _tray.removeWhere((d) => d.twin);
      for (final d in _tray) {
        d.value = null;
        d.dropped = false;
      }
      _tray.add(_Die(type));
    });
  }

  void showToast(String text) => ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(text)));

  void _remove(_Die die) {
    if (_rolling) return;
    HapticFeedback.selectionClick();
    setState(() => _tray.remove(die));
  }

  void _roll() {
    if (_rolling) return;
    final reduced = MediaQuery.disableAnimationsOf(context);
    setState(() {
      if (_tray.isEmpty) _tray.add(_Die(DiceType.d20));
      _tray.removeWhere((d) => d.twin);
      if (_advantage != AdvantageType.none) {
        final i = _tray.indexWhere((d) => d.type == DiceType.d20);
        if (i >= 0) {
          _tray.insert(i + 1, _Die(DiceType.d20, twin: true));
        } else {
          _tray.insertAll(
              0, [_Die(DiceType.d20), _Die(DiceType.d20, twin: true)]);
        }
      }
      for (final d in _tray) {
        d.value = _random.nextInt(d.type.sides) + 1;
        d.dropped = false;
      }
      _rolling = true;
      _sparkAt = null;
    });
    HapticFeedback.selectionClick();
    if (reduced) return _land();
    // The dice leave the hand one after another.
    for (var i = 0; i < _tray.length; i++) {
      final die = _tray[i];
      _after(i * 70, () => setState(() => die.rollKey++));
    }
    _after(560 + _tray.length * 70 + 260, _land);
  }

  void _land() {
    final d20s = [
      for (final d in _tray)
        if (d.type == DiceType.d20) d
    ];
    if (_advantage != AdvantageType.none && d20s.length >= 2) {
      final a = d20s[0], b = d20s[1];
      final keepA = _advantage == AdvantageType.advantage
          ? a.value! >= b.value!
          : a.value! <= b.value!;
      (keepA ? b : a).dropped = true;
    }
    final kept = [
      for (final d in _tray)
        if (!d.dropped) d
    ];
    final crit = kept.any((d) => d.type == DiceType.d20 && d.value == 20);
    final fumble = kept.any((d) => d.type == DiceType.d20 && d.value == 1);
    final total = kept.fold<int>(0, (s, d) => s + d.value!) + _modifier;
    final formula = [for (final d in kept) 'к${d.type.sides}'].join('+') +
        (_modifier == 0
            ? ''
            : (_modifier > 0 ? '+$_modifier' : '−${-_modifier}'));
    setState(() {
      _rolling = false;
      _result = _Result(total, kept, crit, fumble);
      _resultKey++;
      _history.insert(0, (formula, total));
      if (_history.length > 10) _history.removeLast();
    });
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (crit) {
      HapticFeedback.mediumImpact();
      _after(140, HapticFeedback.mediumImpact);
      _gold.forward(from: 0);
      final die =
          kept.firstWhere((d) => d.type == DiceType.d20 && d.value == 20);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final box = die.key.currentContext?.findRenderObject() as RenderBox?;
        final tray = _trayKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && tray != null && mounted) {
          setState(() => _sparkAt = tray
              .globalToLocal(box.localToGlobal(box.size.center(Offset.zero))));
        }
      });
    } else if (fumble) {
      HapticFeedback.mediumImpact();
      _shake.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final ru = instrumentRu(context);
    final counts = <DiceType, int>{
      for (final d in _tray)
        if (!d.twin) d.type: 0
    };
    for (final d in _tray) {
      if (!d.twin) counts[d.type] = counts[d.type]! + 1;
    }
    final size = _tray.length <= 2
        ? 104.0
        : _tray.length <= 4
            ? 76.0
            : 58.0;
    final r = _result;

    final tray = AnimatedBuilder(
      animation: Listenable.merge([_gold, _shake]),
      builder: (context, child) {
        final s = _shake.value;
        final x = !_shake.isAnimating
            ? 0.0
            : s < .2
                ? -7 * s / .2
                : s < .4
                    ? -7 + 13 * (s - .2) / .2
                    : s < .6
                        ? 6 - 9 * (s - .4) / .2
                        : -3 + 3 * (s - .6) / .4;
        final g = _gold.isAnimating ? 1 - _gold.value : 0.0;
        final red = _shake.isAnimating ? 1 - _shake.value : 0.0;
        return Transform.translate(
          offset: Offset(x, 0),
          child: Container(
            key: _trayKey,
            constraints: const BoxConstraints(minHeight: 168),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.4,
                  colors: [
                    Color.alphaBlend(
                        AppAccents.of(context).at(5).withValues(alpha: .10),
                        c.surfaceContainerLow),
                    c.surfaceContainerLow
                  ]),
              border: g > 0
                  ? Border.all(
                      color: AppAccents.of(context).at(2).withValues(alpha: g),
                      width: 2)
                  : null,
              boxShadow: [
                if (g > 0)
                  BoxShadow(
                      color: AppAccents.of(context)
                          .at(2)
                          .withValues(alpha: .35 * g),
                      blurRadius: 30,
                      blurStyle: BlurStyle.inner),
                if (red > 0)
                  BoxShadow(
                      color: c.primary.withValues(alpha: .3 * red),
                      blurRadius: 40,
                      blurStyle: BlurStyle.inner),
              ],
            ),
            child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  child!,
                  if (_sparkAt != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _Sparks(
                            key: ValueKey(_resultKey),
                            at: _sparkAt!,
                            color: AppAccents.of(context).at(2)),
                      ),
                    ),
                ]),
          ),
        );
      },
      child: _tray.isEmpty
          ? Center(
              child: SizedBox(
                width: 240,
                child: Text(
                    ru
                        ? 'Коснитесь кости выше — она ляжет в лоток. Касание кости в лотке убирает её'
                        : 'Tap a die above to lay it in the tray. Tap a die in the tray to take it out',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: AppType.body,
                        fontSize: 13,
                        color: c.onSurfaceVariant)),
              ),
            )
          : Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final d in _tray)
                  _TrayDie(
                    key: ObjectKey(d),
                    die: d,
                    size: size,
                    accent: _accent(context, d.type),
                    crit: !_rolling &&
                        r != null &&
                        r.crit &&
                        !d.dropped &&
                        d.type == DiceType.d20 &&
                        d.value == 20,
                    fumble: !_rolling &&
                        r != null &&
                        !d.dropped &&
                        d.type == DiceType.d20 &&
                        d.value == 1,
                    onTap: () => _remove(d),
                  ),
              ],
            ),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.title != null) ...[
        Text(widget.title!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: AppType.body,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.secondary)),
        const SizedBox(height: 8),
      ],
      SheetHeading(ru ? 'Лоток костей' : 'Dice tray'),
      const SizedBox(height: 14),
      Row(children: [
        for (final t in DiceType.values) ...[
          if (t != DiceType.d4) const SizedBox(width: 6),
          Expanded(
            child: _PickDie(
              key: ValueKey('dice-pick-${t.sides}'),
              type: t,
              accent: _accent(context, t),
              count: counts[t] ?? 0,
              onTap: () => _add(t),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 14),
      tray,
      const SizedBox(height: 14),
      FlowSegment<AdvantageType>(
        keyPrefix: 'dice-adv',
        values: const [
          AdvantageType.disadvantage,
          AdvantageType.none,
          AdvantageType.advantage
        ],
        labels: ru
            ? const ['Помеха', 'Обычно', 'Преимущество']
            : const ['Disadvantage', 'Normal', 'Advantage'],
        selected: _advantage,
        onChanged: (v) => setState(() => _advantage = v),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Expanded(
            child: Text(l10n.modifier,
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.onSurfaceVariant)),
          ),
          _Repeat(
              key: const ValueKey('dice-mod-minus'),
              icon: 'minus',
              label: ru ? 'Меньше' : 'Less',
              onStep: () =>
                  setState(() => _modifier = (_modifier - 1).clamp(-20, 30))),
          SizedBox(
            width: 64,
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_modifier >= 0 ? '+' : '−',
                    style: const TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 26,
                        height: 1,
                        fontWeight: FontWeight.w600)),
                RollingNumber(_modifier.abs(),
                    style: const TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 26,
                        height: 1,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          _Repeat(
              key: const ValueKey('dice-mod-plus'),
              icon: 'plus',
              label: ru ? 'Больше' : 'More',
              onStep: () =>
                  setState(() => _modifier = (_modifier + 1).clamp(-20, 30))),
        ]),
      ),
      CalmSize(
        duration: AppMotion.of(context, const Duration(milliseconds: 420)),
        curve: AppMotion.snappyCurve,
        alignment: Alignment.topCenter,
        child: r == null
            ? const SizedBox(width: double.infinity)
            : AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _rolling ? .3 : 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _Total(
                      key: ValueKey(_resultKey),
                      result: r,
                      modifier: _modifier),
                ),
              ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 56,
        child: FilledButton.icon(
          key: const ValueKey('dice-roll'),
          style: FilledButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
              shape: const StadiumBorder()),
          onPressed: _rolling ? null : _roll,
          icon: const LineIcon('dice', size: 20),
          label: Text(_rolling ? l10n.rolling : (ru ? 'Бросить' : 'Roll'),
              style: const TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ),
      ),
      if (_history.isNotEmpty) ...[
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(children: [
            for (final h in _history) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                    color: c.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12)),
                child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${h.$1} = '),
                      TextSpan(
                          text: '${h.$2}',
                          style: TextStyle(
                              fontFamily: AppType.display, color: c.onSurface)),
                    ]),
                    style: TextStyle(
                        fontFamily: AppType.body,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.onSurfaceVariant)),
              ),
              const SizedBox(width: 6),
            ]
          ]),
        ),
      ],
    ]);
  }
}

/// A die on the picker: its silhouette in its colour, the name, and how
/// many of it lie in the tray.
class _PickDie extends StatefulWidget {
  const _PickDie(
      {super.key,
      required this.type,
      required this.accent,
      required this.count,
      required this.onTap});
  final DiceType type;
  final Color accent;
  final int count;
  final VoidCallback onTap;
  @override
  State<_PickDie> createState() => _PickDieState();
}

class _PickDieState extends State<_PickDie> {
  int _hop = 0;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final name = '${ru ? 'к' : 'd'}${widget.type.sides}';
    return Pressable(
      onTap: () {
        setState(() => _hop++);
        widget.onTap();
      },
      scale: .88,
      semanticLabel: ru ? 'Положить $name' : 'Add $name',
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 7),
          decoration: BoxDecoration(
              color: Color.alphaBlend(
                  widget.accent.withValues(alpha: .10), c.surfaceContainerLow),
              borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            TweenAnimationBuilder<double>(
              key: ValueKey(_hop),
              tween: Tween(begin: _hop == 0 ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 420),
              builder: (context, p, child) {
                final lift = p < .4 ? p / .4 : 1 - (p - .4) / .6;
                return Transform.translate(
                    offset: Offset(0, -6 * lift),
                    child: Transform.rotate(
                        angle: -.24 * lift,
                        child: Transform.scale(
                            scale: 1 + .12 * lift, child: child)));
              },
              child: IgnorePointer(
                child: TumbleDie(
                    shape: dieShapeFor(widget.type.sides),
                    label: '',
                    accent: widget.accent,
                    size: 32),
              ),
            ),
            const SizedBox(height: 5),
            Text(name,
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 11.5,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: c.onSurfaceVariant)),
          ]),
        ),
        if (widget.count > 0)
          Positioned(
            top: -5,
            right: -3,
            child: Container(
              height: 18,
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: widget.accent, borderRadius: BorderRadius.circular(9)),
              child: Text('×${widget.count}',
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.surface)),
            ),
          ),
      ]),
    );
  }
}

/// A die in the tray: it drops in when laid, tumbles when thrown; a kept
/// natural 20 wears a gold ring, a 1 cracks.
class _TrayDie extends StatelessWidget {
  const _TrayDie({
    super.key,
    required this.die,
    required this.size,
    required this.accent,
    required this.crit,
    required this.fumble,
    required this.onTap,
  });
  final _Die die;
  final double size;
  final Color accent;
  final bool crit, fumble;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context);
    final gold = AppAccents.of(context).at(2);
    final still = MediaQuery.disableAnimationsOf(context);
    final label = die.value == null
        ? '${ru ? 'к' : 'd'}${die.type.sides}'
        : '${die.value}';
    Widget body = AnimatedContainer(
      duration: AppMotion.of(context, const Duration(milliseconds: 420)),
      curve: AppMotion.snappyCurve,
      width: size,
      height: size,
      child: Opacity(
        opacity: die.dropped ? .32 : 1,
        child: TumbleDie(
          key: die.key,
          shape: dieShapeFor(die.type.sides),
          label: label,
          accent: crit ? gold : accent,
          rollKey: die.rollKey,
          size: size,
          sides: die.type.sides,
          natural: die.value,
          dim: die.dropped,
        ),
      ),
    );
    if (crit && !still) {
      body = Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: AppMotion.enter,
              builder: (context, p, _) => IgnorePointer(
                child: Container(
                  width: size * (.8 + .9 * p),
                  height: size * (.8 + .9 * p),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: gold.withValues(alpha: 1 - p), width: 3)),
                ),
              ),
            ),
            body,
          ]);
    }
    if (fumble) {
      body = Stack(alignment: Alignment.center, children: [
        body,
        IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: still ? 1 : 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: AppMotion.snappyCurve,
            builder: (context, p, _) => Opacity(
              opacity: .8 * p,
              child: Transform.scale(
                scale: .4 + .6 * p,
                child: CustomPaint(
                    size: Size.square(size),
                    painter:
                        _CrackPainter(Theme.of(context).colorScheme.primary)),
              ),
            ),
          ),
        ),
      ]);
    }
    if (die.rollKey == 0 && die.value == null && !still) {
      // Laid in the tray: it drops in with a little turn.
      body = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 560),
        curve: AppMotion.snappyCurve,
        builder: (context, p, child) => Opacity(
          opacity: p.clamp(0.0, 1.0),
          child: Transform.translate(
              offset: Offset(0, -40 * (1 - p)),
              child: Transform.rotate(
                  angle: -.5 * (1 - p),
                  child: Transform.scale(scale: .6 + .4 * p, child: child))),
        ),
        child: body,
      );
    }
    return Semantics(
      button: true,
      label: ru ? 'Убрать кость' : 'Take the die out',
      child: GestureDetector(onTap: onTap, child: body),
    );
  }
}

class _CrackPainter extends CustomPainter {
  _CrackPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
        Path()
          ..moveTo(30 * s, 22 * s)
          ..lineTo(46 * s, 44 * s)
          ..lineTo(40 * s, 56 * s)
          ..lineTo(58 * s, 78 * s)
          ..moveTo(46 * s, 44 * s)
          ..lineTo(64 * s, 38 * s),
        paint);
  }

  @override
  bool shouldRepaint(_CrackPainter old) => old.color != color;
}

/// Fourteen sparks fly from a natural 20 and fade.
class _Sparks extends StatelessWidget {
  const _Sparks({super.key, required this.at, required this.color});
  final Offset at;
  final Color color;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 950),
        curve: const Cubic(.1, .7, .2, 1),
        builder: (context, p, _) =>
            CustomPaint(painter: _SparkPainter(at, color, p)),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.at, this.color, this.p);
  final Offset at;
  final Color color;
  final double p;
  @override
  void paint(Canvas canvas, Size size) {
    if (p >= 1) return;
    final paint = Paint()..color = color.withValues(alpha: 1 - p);
    for (var k = 0; k < 14; k++) {
      final a = k / 14 * pi * 2 + (k.isEven ? .15 : -.1);
      final d = (60 + (k * 37 % 50)) * p;
      canvas.drawCircle(
          at + Offset(cos(a) * d, sin(a) * d), 3.5 * (1 - .8 * p), paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.p != p;
}

/// The total: a large number that rolls up from zero, beside it the dice
/// that made it and, for a d20 of note, a quiet outlined flag.
class _Total extends StatelessWidget {
  const _Total({super.key, required this.result, required this.modifier});
  final _Result result;
  final int modifier;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final gold = AppAccents.of(context).at(2);
    final still = MediaQuery.disableAnimationsOf(context);
    final color = result.crit
        ? gold
        : result.fumble
            ? c.primary
            : c.onSurface;
    Widget chip(String label, String value, Color dot) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
              color: c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .4,
                    color: c.onSurfaceVariant)),
            const SizedBox(width: 5),
            Text(value,
                style: const TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w600)),
          ]),
        );
    Widget plus(String s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Text(s,
            style: TextStyle(
                fontFamily: AppType.display,
                fontSize: 13,
                color: c.onSurfaceVariant)));
    final breakdown = <Widget>[];
    for (final d in result.kept) {
      if (breakdown.isNotEmpty) breakdown.add(plus('+'));
      breakdown.add(chip('${ru ? 'к' : 'd'}${d.type.sides}', '${d.value}',
          _accent(context, d.type)));
    }
    if (modifier != 0) {
      breakdown
        ..add(plus(modifier > 0 ? '+' : '−'))
        ..add(
            chip(ru ? 'мод' : 'mod', '${modifier.abs()}', c.onSurfaceVariant));
    }
    Widget flag(String icon, String text, Color accent) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: ShapeDecoration(
              shape: StadiumBorder(
                  side: BorderSide(
                      color: accent.withValues(alpha: .7), width: 1.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            InstrumentGlyph(icon, size: 14, color: accent),
            const SizedBox(width: 6),
            Text(text,
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: accent)),
          ]),
        );
    final side = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 5,
              runSpacing: 5,
              children: breakdown),
          if (result.crit) ...[
            const SizedBox(height: 8),
            flag('star', ru ? 'Критический успех' : 'Critical success', gold),
          ] else if (result.fumble) ...[
            const SizedBox(height: 8),
            flag('skull', ru ? 'Критический провал' : 'Critical failure',
                c.primary),
          ],
        ]);
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 620),
        curve: AppMotion.snappyCurve,
        builder: (context, p, child) => Opacity(
            opacity: p.clamp(0.0, 1.0),
            child: Transform.translate(
                offset: Offset(0, 16 * (1 - p)),
                child: Transform.scale(scale: .8 + .2 * p, child: child))),
        child: RollingNumber(result.total,
            key: const ValueKey('dice-total'),
            from: still ? null : 0,
            style: TextStyle(
                fontFamily: AppType.display,
                fontSize: 68,
                height: .9,
                fontWeight: FontWeight.w600,
                letterSpacing: -2.7,
                color: color)),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: still ? 1 : 0, end: 1),
          duration: const Duration(milliseconds: 640),
          curve: const Interval(.2, 1, curve: Cubic(.2, 0, 0, 1)),
          builder: (context, p, child) => Opacity(
              opacity: p,
              child: Transform.translate(
                  offset: Offset(-10 * (1 - p), 0), child: child)),
          child: side,
        ),
      ),
    ]);
  }
}

/// A stepper button that repeats while held, faster the longer it is held.
class _Repeat extends StatefulWidget {
  const _Repeat(
      {super.key,
      required this.icon,
      required this.label,
      required this.onStep});
  final String icon, label;
  final VoidCallback onStep;
  @override
  State<_Repeat> createState() => _RepeatState();
}

class _RepeatState extends State<_Repeat> {
  Timer? _timer;
  int _n = 0;
  void _go() {
    widget.onStep();
    HapticFeedback.selectionClick();
    _timer = Timer(Duration(milliseconds: _n++ < 4 ? 260 : 70), _go);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onStep,
      child: GestureDetector(
        onTapDown: (_) {
          _n = 0;
          _go();
        },
        onTapUp: (_) => _stop(),
        onTapCancel: _stop,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: c.onSurface.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(15)),
          child: InstrumentGlyph(widget.icon, size: 20, color: c.onSurface),
        ),
      ),
    );
  }
}
