import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/models/combat_turn.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/expressive_kit.dart';
import '../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';

/// Wave 3 round tape (`.tape`): beads of rounds on a rail that a finger
/// pulls to the left for the next round, the current bead large and light;
/// below it the effects as ribbons that run down a segment each round,
/// a dot under the bead where an effect will end.
class RoundTape extends StatefulWidget {
  const RoundTape({
    super.key,
    required this.round,
    required this.initiative,
    required this.effects,
    required this.onNext,
    required this.onEndEffect,
    this.busy = false,
  });
  final int round, initiative;
  final List<CombatEffect> effects;
  final VoidCallback onNext;
  final ValueChanged<CombatEffect> onEndEffect;
  final bool busy;
  @override
  State<RoundTape> createState() => _RoundTapeState();
}

class _RoundTapeState extends State<RoundTape>
    with SingleTickerProviderStateMixin {
  static const _step = 44.0; // a bead and its gap
  late final _rail =
      AnimationController.unbounded(vsync: this, value: _x(widget.round));
  double? _drag0;
  double _dx = 0;
  bool _armed = false;

  /// The rail's offset that centres round [r]: beads before it are 34 wide,
  /// the current one 52.
  double _x(int r) => -((r - 1) * _step + 26);

  @override
  void didUpdateWidget(covariant RoundTape old) {
    super.didUpdateWidget(old);
    if (old.round != widget.round) {
      // A new round slides in from where the tape was, at the finger's
      // speed if a drag sent it.
      _rail.animateWith(SpringSimulation(
          AppMotion.gentle, _rail.value, _x(widget.round), _rail.velocity));
    }
  }

  @override
  void dispose() {
    _rail.dispose();
    super.dispose();
  }

  void _start(DragStartDetails d) {
    if (widget.busy) return;
    _rail.stop();
    _drag0 = _rail.value;
    _dx = 0;
    _armed = false;
  }

  void _update(DragUpdateDetails d) {
    if (_drag0 == null) return;
    _dx += d.delta.dx;
    // Rubber band: easy one bead to the left, stiff beyond, stiffer back.
    var dx = _dx;
    if (dx > 0) {
      dx *= .3;
    } else if (dx < -_step) {
      dx = -_step + (dx + _step) * .3;
    }
    final armed = dx < -30;
    if (armed != _armed) {
      _armed = armed;
      HapticFeedback.selectionClick();
    }
    _rail.value = _drag0! + dx;
  }

  void _end(DragEndDetails d) {
    if (_drag0 == null) return;
    _drag0 = null;
    final v = d.primaryVelocity ?? 0;
    if (_armed || v < -500) {
      widget.onNext();
    } else {
      _rail.animateWith(
          SpringSimulation(AppMotion.bouncy, _rail.value, _x(widget.round), v));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final round = widget.round;
    final n = math.max(round + 7, 12);
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 16),
      decoration: BoxDecoration(
          color: c.surfaceContainer, borderRadius: BorderRadius.circular(30)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 14, 0),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((ru ? 'Раунд' : 'Round').toUpperCase(),
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: c.onSurfaceVariant)),
              const SizedBox(height: 2),
              RollingNumber(round,
                  key: const ValueKey('tape-round'),
                  style: const TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 40,
                      height: .95,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.2)),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                        TextSpan(children: [
                          TextSpan(text: ru ? 'Инициатива ' : 'Initiative '),
                          TextSpan(
                              text: '${widget.initiative}',
                              style: TextStyle(
                                  fontFamily: AppType.display,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppAccents.of(context).at(1))),
                        ]),
                        style: TextStyle(
                            fontFamily: AppType.body,
                            fontSize: 13,
                            color: c.onSurfaceVariant)),
                    const SizedBox(height: 3),
                    Text(
                        ru
                            ? 'Листайте влево — новый раунд'
                            : 'Pull left for the next round',
                        style: TextStyle(
                            fontFamily: AppType.body,
                            fontSize: 11.5,
                            color: c.onSurfaceVariant)),
                  ]),
            ),
            Semantics(
              button: true,
              label: ru ? 'Новый раунд' : 'Next round',
              child: GestureDetector(
                key: const ValueKey('tape-next'),
                onTap: widget.busy ? null : widget.onNext,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: c.onSurface,
                      borderRadius: BorderRadius.circular(18)),
                  child: LineIcon('forward', size: 22, color: c.surface),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          key: const ValueKey('tape-beads'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _start,
          onHorizontalDragUpdate: _update,
          onHorizontalDragEnd: _end,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(colors: [
              Color(0x00000000),
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0x00000000)
            ], stops: [
              0,
              .18,
              .82,
              1
            ]).createShader(r),
            child: SizedBox(
              height: 66,
              child: LayoutBuilder(
                builder: (context, box) => AnimatedBuilder(
                  animation: _rail,
                  builder: (context, _) =>
                      Stack(clipBehavior: Clip.none, children: [
                    Positioned(
                      left: box.maxWidth / 2 + _rail.value,
                      top: 0,
                      bottom: 0,
                      child: Row(children: [
                        for (var i = 1; i <= n; i++) ...[
                          if (i > 1) const SizedBox(width: 10),
                          _Bead(
                            number: i,
                            state: i < round
                                ? 0
                                : i == round
                                    ? 1
                                    : 2,
                            ends: [
                              for (final e in widget.effects)
                                if (round + e.left == i)
                                  AppAccents.of(context).at(e.accent)
                            ],
                          ),
                        ],
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: widget.effects.isEmpty
              ? Text(ru ? 'Активных эффектов нет' : 'No active effects',
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 12.5,
                      color: c.onSurfaceVariant))
              : Column(children: [
                  for (final e in widget.effects)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _Ribbon(
                          key: ValueKey('ribbon-${e.key}'),
                          effect: e,
                          onEnd:
                              widget.busy ? null : () => widget.onEndEffect(e)),
                    ),
                ]),
        ),
      ]),
    );
  }
}

class _Bead extends StatelessWidget {
  const _Bead({required this.number, required this.state, required this.ends});
  final int number;

  /// 0 done, 1 now, 2 ahead.
  final int state;
  final List<Color> ends;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final d = AppMotion.of(context, const Duration(milliseconds: 520));
    final now = state == 1;
    return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: d,
            curve: AppMotion.snappyCurve,
            width: now ? 52 : 34,
            height: now ? 52 : 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: now
                  ? c.onSurface
                  : state == 0
                      ? c.tertiary.withValues(alpha: .30)
                      : c.onSurface.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(now ? 18 : 17),
            ),
            child: AnimatedDefaultTextStyle(
              duration: d,
              style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: now ? 22 : 13,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: now
                      ? c.surface
                      : state == 0
                          ? c.onSurface
                          : c.onSurfaceVariant),
              child: Text('$number'),
            ),
          ),
          if (ends.isNotEmpty)
            Positioned(
              bottom: now ? -11 : -11,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final e in ends)
                  Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration:
                          BoxDecoration(shape: BoxShape.circle, color: e)),
              ]),
            ),
        ]);
  }
}

/// An effect as a ribbon: its glyph, its name, a segmented bar of the
/// rounds it has left, the count. A tap ends it; a hold reads it.
class _Ribbon extends StatelessWidget {
  const _Ribbon({super.key, required this.effect, this.onEnd});
  final CombatEffect effect;
  final VoidCallback? onEnd;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final accent = AppAccents.of(context).at(effect.accent);
    final share = (effect.left / math.min(effect.max, 10)).clamp(0.0, 1.0);
    final left = effect.left;
    return Peek(
      title: effect.name,
      text:
          '${effect.concentration ? (ru ? 'Концентрация. ' : 'Concentration. ') : ''}'
          '${ru ? 'Ещё $left ${ruPlural(left, 'раунд', 'раунда', 'раундов')}. Касание — завершить' : '$left more rounds. Tap to end'}',
      accent: accent,
      child: Pressable(
        onTap: onEnd,
        scale: .97,
        semanticLabel: effect.name,
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: accent, borderRadius: BorderRadius.circular(9)),
            child: InstrumentGlyph(effect.icon, size: 15, color: c.surface),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 118,
            child: Text(effect.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: SizedBox(
              height: 10,
              child: CustomPaint(
                painter: _Segments(c.onSurface.withValues(alpha: .09)),
                foregroundPainter: null,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: share),
                  duration:
                      AppMotion.of(context, const Duration(milliseconds: 700)),
                  curve: AppMotion.snappyCurve,
                  builder: (context, w, _) =>
                      CustomPaint(painter: _Segments(accent, fill: w)),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(left > 99 ? '99+' : '$left',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: accent)),
          ),
        ]),
      ),
    );
  }
}

/// Ten segments of a ribbon; [fill] of them painted.
class _Segments extends CustomPainter {
  _Segments(this.color, {this.fill = 1});
  final Color color;
  final double fill;
  @override
  void paint(Canvas canvas, Size size) {
    const n = 10, gap = 3.0;
    final w = (size.width - gap * (n - 1)) / n;
    final paint = Paint()..color = color;
    final limit = size.width * fill;
    for (var i = 0; i < n; i++) {
      final x = i * (w + gap);
      if (x >= limit) break;
      final right = math.min(x + w, limit);
      canvas.drawRRect(
          RRect.fromLTRBR(x, 0, right, size.height, const Radius.circular(2)),
          paint);
    }
  }

  @override
  bool shouldRepaint(_Segments old) => old.color != color || old.fill != fill;
}
