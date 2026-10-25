import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/combat_turn.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/expressive_kit.dart';
import '../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';

/// Wave 3 "My turn" (`.turn`): Action, Bonus action and Reaction as
/// tokens — a coloured circle while free, an outlined square with a check
/// once spent — and Movement with the feet left and a meter. A new round
/// resets them.
class TurnTokens extends StatelessWidget {
  const TurnTokens({
    super.key,
    required this.turn,
    required this.speed,
    required this.onToggle,
    required this.onMove,
    this.busy = false,
  });
  final CombatTurn turn;
  final int speed;
  final ValueChanged<TurnCost> onToggle;
  final VoidCallback onMove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context);
    final budget = speed * (turn.dash ? 2 : 1);
    final left = math.max(0, budget - turn.moved);
    Widget token(TurnCost cost, String label, String icon, int accent,
            String peek) =>
        Expanded(
          child: _Token(
            key: ValueKey('token-${cost.key}'),
            label: label,
            icon: icon,
            accent: AppAccents.of(context).at(accent),
            spent: turn.used(cost),
            peek: peek,
            onTap: busy ? null : () => onToggle(cost),
          ),
        );
    return Row(children: [
      token(
          TurnCost.action,
          ru ? 'Действие' : 'Action',
          'bolt',
          0,
          ru
              ? 'Атака, заклинание, Рывок, Отход, Уклонение'
              : 'Attack, a spell, Dash, Disengage, Dodge'),
      const SizedBox(width: 8),
      token(
          TurnCost.bonus,
          ru ? 'Бонусное' : 'Bonus',
          'spark',
          1,
          ru
              ? 'Если что-то даёт бонусное действие'
              : 'When something grants a bonus action'),
      const SizedBox(width: 8),
      token(
          TurnCost.reaction,
          ru ? 'Реакция' : 'Reaction',
          'stepback',
          4,
          ru
              ? 'Одна до начала вашего хода: провоцированная атака, Щит'
              : 'One until your next turn: an opportunity attack, Shield'),
      const SizedBox(width: 8),
      Expanded(
        child: _Token(
          key: const ValueKey('token-move'),
          label: ru ? 'фт.' : 'ft.',
          number: left,
          icon: turn.dash ? 'dash' : 'run',
          accent: AppAccents.of(context).at(3),
          spent: left == 0,
          ring: turn.dash,
          meter: budget == 0 ? 0 : left / budget,
          peek: ru
              ? 'Касание — линейка шагов, Рывок и трудная местность'
              : 'Tap for the ruler, Dash and difficult terrain',
          title: ru ? 'Движение' : 'Movement',
          onTap: busy ? null : onMove,
        ),
      ),
    ]);
  }
}

class _Token extends StatefulWidget {
  const _Token({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.spent,
    required this.peek,
    this.onTap,
    this.number,
    this.meter,
    this.ring = false,
    this.title,
  });
  final String label, icon, peek;
  final String? title;
  final Color accent;
  final bool spent, ring;
  final int? number;
  final double? meter;
  final VoidCallback? onTap;
  @override
  State<_Token> createState() => _TokenState();
}

class _TokenState extends State<_Token> {
  int _flash = 0;

  @override
  void didUpdateWidget(covariant _Token old) {
    super.didUpdateWidget(old);
    if (old.spent != widget.spent) _flash++;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final d = AppMotion.of(context, const Duration(milliseconds: 420));
    final spent = widget.spent;
    return Peek(
      title: widget.title ?? widget.label,
      text: widget.peek,
      accent: widget.accent,
      child: Pressable(
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        scale: .94,
        semanticLabel: widget.title ?? widget.label,
        child: AnimatedContainer(
          duration: d,
          curve: AppMotion.snappyCurve,
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
          decoration: BoxDecoration(
              color: spent
                  ? c.onSurface.withValues(alpha: .03)
                  : c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22)),
          child: Column(children: [
            TweenAnimationBuilder<double>(
              key: ValueKey(_flash),
              tween: Tween(
                  begin: _flash == 0 || MediaQuery.disableAnimationsOf(context)
                      ? 1
                      : 0,
                  end: 1),
              duration: const Duration(milliseconds: 520),
              curve: AppMotion.snappyCurve,
              builder: (context, p, child) => Transform.scale(
                  scale: 1 + .18 * math.sin(p * math.pi), child: child),
              child: AnimatedContainer(
                duration: d,
                curve: AppMotion.snappyCurve,
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: spent ? Colors.transparent : widget.accent,
                  borderRadius: BorderRadius.circular(spent ? 13 : 19),
                  border: spent
                      ? Border.all(
                          color: c.onSurface.withValues(alpha: .2), width: 2)
                      : widget.ring
                          ? Border.all(
                              color: AppAccents.of(context)
                                  .at(1)
                                  .withValues(alpha: .6),
                              width: 3)
                          : null,
                ),
                child: InstrumentGlyph(
                    spent && widget.number == null ? 'check' : widget.icon,
                    size: 20,
                    color: spent ? c.onSurfaceVariant : c.surface),
              ),
            ),
            const SizedBox(height: 7),
            if (widget.number != null)
              Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RollingNumber(widget.number!,
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 12.5,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: c.onSurfaceVariant)),
                    Text(' ${widget.label}',
                        style: TextStyle(
                            fontFamily: AppType.body,
                            fontSize: 11.5,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: c.onSurfaceVariant)),
                  ])
            else
              Text(widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: c.onSurfaceVariant)),
            if (widget.meter != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  width: 44,
                  height: 6,
                  child: Stack(children: [
                    Positioned.fill(
                        child: ColoredBox(
                            color: c.onSurface.withValues(alpha: .10))),
                    AnimatedFractionallySizedBox(
                      duration: d,
                      curve: AppMotion.snappyCurve,
                      widthFactor: widget.meter!.clamp(0.0, 1.0),
                      heightFactor: 1,
                      alignment: Alignment.centerLeft,
                      child: ColoredBox(color: widget.accent),
                    ),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// The movement sheet's answer: feet moved and the Dash.
class MovementResult {
  MovementResult(this.moved, this.dash);
  int moved;
  bool dash;
}

/// Movement on a ruler (`.ruler`): the feet left large; a finger drags the
/// marker along a track ticked every 5 feet; quick steps, Dash (doubles
/// the speed, spends the action) and difficult terrain (each step costs
/// double). The sheet reports what it ends with.
Future<MovementResult> showMovementSheet(BuildContext context,
    {required String kicker,
    required int speed,
    required int moved,
    required bool dash}) async {
  final result = MovementResult(moved, dash);
  await showCompanionSheet<void>(context,
      builder: (_) =>
          _MovementSheet(kicker: kicker, speed: speed, result: result));
  return result;
}

class _MovementSheet extends StatefulWidget {
  const _MovementSheet(
      {required this.kicker, required this.speed, required this.result});
  final String kicker;
  final int speed;
  final MovementResult result;
  @override
  State<_MovementSheet> createState() => _MovementSheetState();
}

class _MovementSheetState extends State<_MovementSheet> {
  bool _rough = false, _dragging = false;
  int _nudge = 0;
  MovementResult get _r => widget.result;
  int get _budget => widget.speed * (_r.dash ? 2 : 1);

  void _set(int value) {
    final v = ((value / 5).round() * 5).clamp(0, _budget);
    if (v == _r.moved) return;
    if (v ~/ 5 != _r.moved ~/ 5) HapticFeedback.selectionClick();
    if (v == _budget) HapticFeedback.lightImpact();
    setState(() => _r.moved = v);
  }

  void _at(Offset local, double width) =>
      _set((local.dx / width * _budget).round());

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final a3 = AppAccents.of(context).at(3), a1 = AppAccents.of(context).at(1);
    final budget = _budget, left = math.max(0, budget - _r.moved);
    final p = budget == 0 ? 0.0 : _r.moved / budget;
    final labelEvery = budget > 60 ? 20 : 10;
    final d = _dragging
        ? Duration.zero
        : AppMotion.of(context, const Duration(milliseconds: 360));
    Widget option(String key, String icon, Color accent, String title,
            String note, bool on, VoidCallback tap) =>
        Expanded(
          child: Pressable(
            key: ValueKey('move-$key'),
            onTap: tap,
            selected: on,
            scale: .96,
            semanticLabel: title,
            child: AnimatedContainer(
              duration:
                  AppMotion.of(context, const Duration(milliseconds: 420)),
              curve: AppMotion.snappyCurve,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: on
                    ? Color.alphaBlend(
                        accent.withValues(alpha: .20), c.surfaceContainerLow)
                    : c.surfaceContainerLow,
                borderRadius: on
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(24),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14))
                    : BorderRadius.circular(20),
                border: Border.all(
                    color: on ? accent : Colors.transparent, width: 1.6),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.of(
                          context, const Duration(milliseconds: 360)),
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: on ? accent : accent.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(12)),
                      child: InstrumentGlyph(icon,
                          size: 19, color: on ? c.surface : accent),
                    ),
                    const SizedBox(height: 8),
                    Text(title,
                        style: const TextStyle(
                            fontFamily: AppType.body,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(note,
                        style: TextStyle(
                            fontFamily: AppType.body,
                            fontSize: 11.5,
                            height: 1.3,
                            color: c.onSurfaceVariant)),
                  ]),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.kicker,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontFamily: AppType.body,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.secondary)),
      const SizedBox(height: 8),
      SheetHeading(ru ? 'Движение' : 'Movement'),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        RollingNumber(left,
            key: const ValueKey('move-left'),
            style: TextStyle(
                fontFamily: AppType.display,
                fontSize: 64,
                height: .9,
                fontWeight: FontWeight.w600,
                letterSpacing: -2.5,
                color: a3)),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(ru ? ' фт.' : ' ft.',
              style: TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.onSurfaceVariant)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
                ru
                    ? 'осталось из $budget${_r.dash ? ' · с Рывком' : ''}'
                    : 'left of $budget${_r.dash ? ' · with Dash' : ''}',
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 13,
                    color: c.onSurfaceVariant)),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Container(
        height: 84,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
        decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22)),
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          return GestureDetector(
            key: const ValueKey('move-ruler'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (e) => _at(e.localPosition, w),
            onHorizontalDragStart: (e) {
              setState(() => _dragging = true);
              _at(e.localPosition, w);
            },
            onHorizontalDragUpdate: (e) => _at(e.localPosition, w),
            onHorizontalDragEnd: (_) => setState(() => _dragging = false),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 22,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(children: [
                    Positioned.fill(
                        child: ColoredBox(color: a3.withValues(alpha: .22))),
                    AnimatedPositioned(
                      duration: AppMotion.of(
                          context, const Duration(milliseconds: 520)),
                      curve: AppMotion.snappyCurve,
                      left: _r.dash ? w / 2 : w,
                      top: 0,
                      bottom: 0,
                      right: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: a1.withValues(alpha: .28),
                            border:
                                Border(left: BorderSide(color: a1, width: 2))),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: d,
                      curve: AppMotion.snappyCurve,
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: w * p,
                      child: CustomPaint(painter: _Hatch(c.onSurface)),
                    ),
                  ]),
                ),
              ),
              for (var f = 0; f <= budget; f += 5)
                Positioned(
                  left: w * (budget == 0 ? 0 : f / budget) - 1,
                  top: 28,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 2,
                      height: f % labelEvery == 0 ? 10 : 6,
                      decoration: BoxDecoration(
                          color: f <= _r.moved
                              ? c.onSurface
                              : c.onSurface.withValues(alpha: .22),
                          borderRadius: BorderRadius.circular(1)),
                    ),
                  ]),
                ),
              for (var f = 0; f <= budget; f += labelEvery)
                Positioned(
                  left: w * (budget == 0 ? 0 : f / budget) - 20,
                  width: 40,
                  top: 41,
                  child: Text('$f',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: c.onSurfaceVariant)),
                ),
              AnimatedPositioned(
                duration: d,
                curve: AppMotion.snappyCurve,
                left: w * p - 3,
                top: -8,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_nudge),
                  tween: Tween(begin: _nudge == 0 ? 1 : 0, end: 1),
                  duration: const Duration(milliseconds: 420),
                  builder: (context, q, child) => Transform.scale(
                      scale: 1 + .18 * math.sin(q * math.pi), child: child),
                  child: Container(
                    width: 6,
                    height: 38,
                    decoration: BoxDecoration(
                        color: c.onSurface,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  c.surfaceContainerLow.withValues(alpha: .7),
                              spreadRadius: 4)
                        ]),
                  ),
                ),
              ),
              if (_dragging)
                Positioned(
                  left: w * p - 30,
                  width: 60,
                  top: -36,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: c.onSurface,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${_r.moved}',
                          style: TextStyle(
                              fontFamily: AppType.display,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.surface)),
                    ),
                  ),
                ),
            ]),
          );
        }),
      ),
      const SizedBox(height: 12),
      Row(children: [
        for (final q in const [5, 10, 15, 30, -5]) ...[
          if (q != 5) const SizedBox(width: 6),
          Expanded(
            child: Pressable(
              key: ValueKey('move-step-$q'),
              onTap: () {
                setState(() => _nudge++);
                _set(_r.moved + q * (_rough && q > 0 ? 2 : 1));
              },
              scale: .92,
              semanticLabel:
                  q > 0 ? '+$q' : (ru ? 'Вернуть 5 футов' : 'Give back 5 feet'),
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: c.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16)),
                child: q > 0
                    ? Text('+$q',
                        style: const TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 15,
                            fontWeight: FontWeight.w600))
                    : LineIcon('back', size: 18, color: c.onSurface),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          option(
              'dash',
              'dash',
              a1,
              ru ? 'Рывок' : 'Dash',
              ru
                  ? 'Скорость ×2 · тратит действие'
                  : 'Speed ×2 · spends the action',
              _r.dash, () {
            HapticFeedback.lightImpact();
            setState(() {
              _r.dash = !_r.dash;
              _r.moved = math.min(_r.moved, _budget);
            });
          }),
          const SizedBox(width: 8),
          option(
              'rough',
              'peaks',
              AppAccents.of(context).at(2),
              ru ? 'Трудная местность' : 'Difficult terrain',
              ru ? 'Каждый шаг стоит вдвое' : 'Every step costs double',
              _rough, () {
            HapticFeedback.selectionClick();
            setState(() => _rough = !_rough);
          }),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        ToneButton(
          key: const ValueKey('move-reset'),
          height: 52,
          icon: LineIcon('back', size: 18, color: c.onSurface),
          label: ru ? 'Сначала' : 'Reset',
          onPressed: () {
            HapticFeedback.lightImpact();
            _set(0);
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ToneButton(
            key: const ValueKey('move-done'),
            kind: ToneKind.primary,
            height: 52,
            expand: true,
            label: ru ? 'Готово' : 'Done',
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ]),
    ]);
  }
}

/// The feet already walked: a hatch over the track.
class _Hatch extends CustomPainter {
  _Hatch(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = color.withValues(alpha: .10));
    final paint = Paint()
      ..color = color.withValues(alpha: .22)
      ..strokeWidth = 5;
    for (var x = -size.height; x < size.width + size.height; x += 10) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_Hatch old) => old.color != color;
}
