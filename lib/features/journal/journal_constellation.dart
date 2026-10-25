import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../core/journal/journal_graph.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/companion_kit.dart';
import 'journal_kit.dart';
import 'journal_strings.dart';

/// A tie between two names: the number of records they share.
class JournalTie {
  const JournalTie(this.a, this.b, this.shared);
  final String a, b;
  final int shared;
}

class _Star {
  _Star(this.x, this.y, this.heading);
  double x, y, vx = 0, vy = 0, heading;
  bool fixed = false;
}

/// The Atlas as a living constellation: names are stars, shared records
/// pull them together, everyone repels, and each star drifts a little on
/// its own. A star can be pulled and drags its ties along; a tap makes it
/// grow over the rest. Pinch, the wheel or a double tap zoom; dragging the
/// sky pans it.
class JournalConstellation extends StatefulWidget {
  const JournalConstellation(
      {super.key,
      required this.entities,
      required this.ties,
      required this.weight,
      required this.shown,
      required this.selected,
      required this.onSelect,
      this.height = 340});
  final List<JournalEntity> entities;
  final List<JournalTie> ties;
  final Map<String, int> weight;
  final Set<String> shown;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final double height;
  @override
  State<JournalConstellation> createState() => _JournalConstellationState();
}

class _JournalConstellationState extends State<JournalConstellation>
    with TickerProviderStateMixin {
  final _stars = <String, _Star>{};
  final _random = math.Random(7);
  late final Ticker _ticker = createTicker(_tick);
  late final _halo = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300));
  Duration _last = Duration.zero;
  double _acc = 0, _w = 390;
  // Camera: offset and zoom of the world in the view.
  double _cx = 0, _cy = 0, _k = 1;
  (double, double, double)? _camTo;
  final _pointers = <int, Offset>{};
  _Gesture? _g;
  String? _held;
  bool _used = false;
  Offset? _lastTap;
  Duration _lastTapAt = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = MediaQuery.disableAnimationsOf(context);
    if (calm) {
      _halo.stop();
      _halo.value = 0;
    } else if (!_halo.isAnimating) {
      _halo.repeat(reverse: true);
    }
    _wake();
  }

  @override
  void didUpdateWidget(JournalConstellation old) {
    super.didUpdateWidget(old);
    _wake();
  }

  // With less motion the stars do not drift: the sky rests once settled and
  // wakes for a touch or new data.
  void _wake() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _halo.dispose();
    super.dispose();
  }

  void _sync() {
    final ids = {for (final e in widget.entities) e.id};
    _stars.removeWhere((id, _) => !ids.contains(id));
    final fresh = _stars.isEmpty;
    var i = 0;
    for (final e in widget.entities) {
      _stars.putIfAbsent(
          e.id,
          () => _Star(
              _w / 2 + 150 * math.cos(i * 2.399),
              widget.height / 2 + 150 * math.sin(i * 2.399),
              _random.nextDouble() * 6.28));
      i++;
    }
    if (fresh) {
      for (var n = 0; n < 400; n++) {
        _step(false);
      }
    }
  }

  double _radius(String id) => 13 + math.min(4, widget.weight[id] ?? 0) * 3;

  /// One step of the prototype's forces, at sixty steps a second.
  void _step(bool wander) {
    final all = _stars.values.toList();
    for (final a in all) {
      for (final b in all) {
        if (identical(a, b)) continue;
        final dx = a.x - b.x, dy = a.y - b.y;
        final d2 = math.max(120.0, dx * dx + dy * dy), d = math.sqrt(d2);
        final f = 5600 / d2;
        a.vx += dx / d * f;
        a.vy += dy / d * f;
      }
    }
    for (final t in widget.ties) {
      final a = _stars[t.a], b = _stars[t.b];
      if (a == null || b == null) continue;
      final dx = b.x - a.x, dy = b.y - a.y;
      final d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      final f = (d - 100) * .011 * math.min(2, t.shared);
      a.vx += dx / d * f;
      a.vy += dy / d * f;
      b.vx -= dx / d * f;
      b.vy -= dy / d * f;
    }
    for (final n in all) {
      n.vx += (_w / 2 - n.x) * .0028;
      n.vy += (widget.height / 2 - n.y) * .0028;
      // Soft walls keep the stars out of the faded edges and the hint.
      final top = 44.0, bottom = widget.height - 62, side = 58.0;
      if (n.y < top) n.vy += (top - n.y) * .05;
      if (n.y > bottom) n.vy -= (n.y - bottom) * .05;
      if (n.x < side) n.vx += (side - n.x) * .05;
      if (n.x > _w - side) n.vx -= (n.x - (_w - side)) * .05;
      if (wander) {
        n.heading += (_random.nextDouble() - .5) * .12;
        n.vx += math.cos(n.heading) * .045;
        n.vy += math.sin(n.heading) * .045;
      }
      if (n.fixed) {
        n.vx = n.vy = 0;
        continue;
      }
      n.vx *= .8;
      n.vy *= .8;
      final sp = math.sqrt(n.vx * n.vx + n.vy * n.vy);
      if (sp > 14) {
        n.vx *= 14 / sp;
        n.vy *= 14 / sp;
      }
      n.x += n.vx;
      n.y += n.vy;
    }
  }

  void _tick(Duration now) {
    final dt =
        _last == Duration.zero ? 16.7 : (now - _last).inMicroseconds / 1000.0;
    _last = now;
    if (!mounted) return;
    final calm = MediaQuery.disableAnimationsOf(context);
    _acc = math.min(_acc + dt, 70);
    while (_acc >= 16.6) {
      _step(!calm);
      _acc -= 16.6;
    }
    final to = _camTo;
    if (calm &&
        to == null &&
        _g == null &&
        _stars.values.every((n) => n.vx.abs() + n.vy.abs() < .01)) {
      _ticker.stop();
    }
    if (to != null) {
      final t = calm ? 1.0 : .16;
      _cx += (to.$1 - _cx) * t;
      _cy += (to.$2 - _cy) * t;
      _k += (to.$3 - _k) * t;
      if ((_k - to.$3).abs() < .002 && (_cx - to.$1).abs() < .3) {
        _cx = to.$1;
        _cy = to.$2;
        _k = to.$3;
        _camTo = null;
      }
    }
    setState(() {});
  }

  Offset _world(Offset view) =>
      Offset((view.dx - _cx) / _k, (view.dy - _cy) / _k);

  String? _starAt(Offset view) {
    final p = _world(view);
    String? best;
    var bestD = double.infinity;
    for (final e in _stars.entries) {
      final grow = e.key == widget.selected ? 1.5 : 1.0;
      final d = (Offset(e.value.x, e.value.y) - p).distance;
      if (d < _radius(e.key) * grow + 8 && d < bestD) {
        best = e.key;
        bestD = d;
      }
    }
    return best;
  }

  void _zoomAt(Offset p, double k) {
    k = k.clamp(.5, 2.6);
    _cx = p.dx - (p.dx - _cx) * k / _k;
    _cy = p.dy - (p.dy - _cy) * k / _k;
    _k = k;
    _camTo = null;
  }

  void _down(PointerDownEvent e) {
    _wake();
    _pointers[e.pointer] = e.localPosition;
    _used = true;
    if (_pointers.length == 2) {
      // A second finger turns any gesture into a pinch about the midpoint.
      if (_g?.star != null) {
        _stars[_g!.star!]?.fixed = false;
        _held = null;
      }
      final [a, b] = _pointers.values.toList();
      final m = (a + b) / 2;
      _g = _Gesture.pinch((a - b).distance, _k, _world(m));
      return;
    }
    if (_pointers.length > 2) return;
    final id = _starAt(e.localPosition);
    final s = id == null ? null : _stars[id];
    _g = _Gesture.single(id, e.localPosition, _cx, _cy,
        s == null ? Offset.zero : Offset(s.x, s.y) - _world(e.localPosition),
        mouse: e.kind == PointerDeviceKind.mouse);
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    final g = _g;
    if (g == null) return;
    if (g.pinch) {
      if (_pointers.length < 2) return;
      final [a, b] = _pointers.values.toList();
      final m = (a + b) / 2;
      final k = (g.k0 * (a - b).distance / math.max(1, g.d0)).clamp(.5, 2.6);
      _k = k;
      _cx = m.dx - g.w.dx * k;
      _cy = m.dy - g.w.dy * k;
      _camTo = null;
      return;
    }
    if (!g.moved && (e.localPosition - g.p0).distance < 5) return;
    if (!g.moved) {
      g.moved = true;
      if (g.star != null) {
        _stars[g.star!]?.fixed = true;
        _held = g.star;
        HapticFeedback.selectionClick();
      }
    }
    final s = g.star == null ? null : _stars[g.star!];
    if (s != null) {
      final w = _world(e.localPosition) + g.grab;
      s.x = w.dx;
      s.y = w.dy;
    } else if (g.mouse) {
      // One finger on the sky scrolls the page; a mouse pans the sky.
      _cx = g.cx + e.localPosition.dx - g.p0.dx;
      _cy = g.cy + e.localPosition.dy - g.p0.dy;
      _camTo = null;
    }
  }

  bool _onStarAt(Offset global) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    return _starAt(box.globalToLocal(global)) != null;
  }

  void _up(PointerEvent e, {bool cancel = false}) {
    if (_pointers.remove(e.pointer) == null) return;
    final g = _g;
    if (g == null) return;
    if (g.pinch) {
      if (_pointers.isEmpty) _g = null;
      return;
    }
    _g = null;
    if (g.star != null) {
      _stars[g.star!]?.fixed = false;
      if (g.moved) {
        _held = null;
        HapticFeedback.lightImpact();
      }
    }
    if (g.moved || cancel) return;
    if (g.star != null) {
      HapticFeedback.selectionClick();
      widget.onSelect(widget.selected == g.star ? null : g.star);
      return;
    }
    // Two taps on the sky zoom in a step; on a zoomed sky they go back.
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    if (_lastTap != null &&
        (now - _lastTapAt) < const Duration(milliseconds: 320) &&
        (_lastTap! - g.p0).distance < 30) {
      _lastTap = null;
      HapticFeedback.selectionClick();
      if (_k > 1.05) {
        _camTo = (0, 0, 1);
      } else {
        final p = g.p0;
        _camTo = (
          p.dx - (p.dx - _cx) * 1.8 / _k,
          p.dy - (p.dy - _cy) * 1.8 / _k,
          1.8
        );
      }
      return;
    }
    _lastTap = g.p0;
    _lastTapAt = now;
    if (widget.selected != null) widget.onSelect(null);
  }

  void _wheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final s = event as PointerScrollEvent;
      _zoomAt(s.localPosition, _k * math.exp(-s.scrollDelta.dy * .0016));
      _wake();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, box) {
      _w = box.maxWidth;
      _sync();
      final sel = widget.selected;
      final near = sel == null
          ? null
          : {
              sel,
              for (final t in widget.ties)
                if (t.a == sel) t.b else if (t.b == sel) t.a
            };
      final moved = _k != 1 || _cx != 0 || _cy != 0;
      final calm = MediaQuery.disableAnimationsOf(context);
      final dur = AppMotion.of(context, const Duration(milliseconds: 560));
      return SizedBox(
        height: widget.height,
        child: Semantics(
          label: s.t('Созвездие имён', 'Constellation of names'),
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            // The sky has no edge: it fades into the page above and below.
            Positioned.fill(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Color(0x00000000)
                  ],
                  stops: [0, .12, .86, 1],
                ).createShader(r),
                child: Stack(children: [
                  Positioned.fill(
                    child: CustomPaint(
                        painter: _SkyPainter(
                            glow: JournalLook.accent(context, 5),
                            dots: c.onSurface,
                            dx: _cx * .3,
                            dy: _cy * .3)),
                  ),
                  Positioned.fill(
                    child: Listener(
                      onPointerDown: _down,
                      onPointerMove: _move,
                      onPointerUp: _up,
                      onPointerCancel: (e) => _up(e, cancel: true),
                      onPointerSignal: _wheel,
                      // The page keeps its scroll over the sky: only a finger on a
                      // star or a second finger takes the gesture from it.
                      child: RawGestureDetector(
                        behavior: HitTestBehavior.opaque,
                        gestures: {
                          _StarGrab:
                              GestureRecognizerFactoryWithHandlers<_StarGrab>(
                                  () => _StarGrab(_onStarAt), (_) {}),
                          _TwoFingers:
                              GestureRecognizerFactoryWithHandlers<_TwoFingers>(
                                  _TwoFingers.new, (_) {}),
                        },
                        child: ClipRect(
                          child: Transform(
                            transform: Matrix4.identity()
                              ..translateByDouble(_cx, _cy, 0, 1)
                              ..scaleByDouble(_k, _k, 1, 1),
                            child: Stack(clipBehavior: Clip.none, children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _TiePainter(
                                    ties: widget.ties,
                                    stars: _stars,
                                    shown: widget.shown,
                                    hot: {
                                      if (sel != null) sel,
                                      if (_held != null) _held!
                                    },
                                    line: c.onSurface.withValues(alpha: .22),
                                    glow: JournalLook.accent(context, 2),
                                  ),
                                ),
                              ),
                              for (final e in [
                                ...widget.entities.where((e) => e.id != sel),
                                ...widget.entities.where((e) => e.id == sel),
                              ])
                                _starWidget(e, sel, near, calm, dur, c),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            if (moved)
              Positioned(
                right: 18,
                top: 10,
                child: JournalRound(
                    key: const ValueKey('journal-recenter'),
                    icon: 'target',
                    label: s.t('Вернуть вид', 'Reset the view'),
                    size: 36,
                    fill: c.surface.withValues(alpha: .7),
                    onTap: () => setState(() {
                          _camTo = (0, 0, 1);
                          _wake();
                        })),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _used ? 0 : 1,
                  duration:
                      AppMotion.of(context, const Duration(milliseconds: 400)),
                  child: Text(
                      s.t('Тяните звезду · двумя пальцами — двигать и масштаб',
                          'Drag a star · two fingers move and zoom'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.onSurfaceVariant)),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }

  Widget _starWidget(JournalEntity e, String? sel, Set<String>? near, bool calm,
      Duration dur, ColorScheme c) {
    final star = _stars[e.id]!;
    final a = JournalLook.accent(context, JournalLook.kindAccent(e.kind));
    final r = _radius(e.id);
    final on = e.id == sel, held = e.id == _held;
    final dim = !widget.shown.contains(e.id) ||
        (near != null && !near.contains(e.id) && !held);
    const width = 140.0;
    final top = r + 10, height = top * 2 + 26;
    final scale = on
        ? (held ? 1.6 : 1.5)
        : held
            ? 1.18
            : 1.0;
    return Positioned(
      key: ValueKey('journal-star-${e.id}'),
      left: star.x - width / 2,
      top: star.y - top,
      width: width,
      height: height,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: dim ? .25 : 1,
          duration: AppMotion.of(context, const Duration(milliseconds: 320)),
          child: AnimatedScale(
            scale: scale,
            duration: dur,
            curve: AppMotion.snappyCurve,
            alignment: Alignment(0, -1 + 2 * top / height),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: width / 2 - top,
                top: 0,
                child: AnimatedBuilder(
                  animation: _halo,
                  builder: (context, child) {
                    final pulse = on && !calm ? _halo.value : 0.0;
                    return AnimatedOpacity(
                      opacity: on || held ? (on ? 1 - .45 * pulse : .8) : 0,
                      duration: AppMotion.of(
                          context, const Duration(milliseconds: 300)),
                      child:
                          Transform.scale(scale: 1 + .14 * pulse, child: child),
                    );
                  },
                  child: Container(
                    width: top * 2,
                    height: top * 2,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: a.withValues(alpha: .22)),
                  ),
                ),
              ),
              Positioned(
                left: width / 2 - r,
                top: 10,
                child: AnimatedContainer(
                  duration:
                      AppMotion.of(context, const Duration(milliseconds: 260)),
                  width: r * 2,
                  height: r * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? a : JournalLook.mix(a, .26, c.surfaceContainer),
                    border: Border.all(color: a, width: 2),
                  ),
                  child: Center(
                      child: LineIcon(JournalLook.kindIcon(e.kind),
                          size: 18, color: on ? c.surface : a)),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: r * 2 + 10 + 4,
                child: _Label(e.name),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Gesture {
  _Gesture.single(this.star, this.p0, this.cx, this.cy, this.grab,
      {this.mouse = false})
      : pinch = false,
        d0 = 0,
        k0 = 1,
        w = Offset.zero;
  _Gesture.pinch(this.d0, this.k0, this.w)
      : pinch = true,
        mouse = false,
        star = null,
        p0 = Offset.zero,
        cx = 0,
        cy = 0,
        grab = Offset.zero;
  final bool pinch, mouse;
  final String? star;
  final Offset p0, grab, w;
  final double cx, cy, d0, k0;
  bool moved = false;
}

/// A star's name with a ring of the page's colour, so it reads over ties.
class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    const base = TextStyle(
        fontFamily: AppType.body,
        fontSize: 11.5,
        height: 1,
        fontWeight: FontWeight.w600);
    return Stack(alignment: Alignment.topCenter, children: [
      Text(text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4
                ..strokeJoin = StrokeJoin.round
                ..color = c.surface)),
      Text(text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          style: base.copyWith(color: c.onSurface)),
    ]);
  }
}

class _TiePainter extends CustomPainter {
  _TiePainter(
      {required this.ties,
      required this.stars,
      required this.shown,
      required this.hot,
      required this.line,
      required this.glow});
  final List<JournalTie> ties;
  final Map<String, _Star> stars;
  final Set<String> shown, hot;
  final Color line, glow;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (final t in ties) {
      final a = stars[t.a], b = stars[t.b];
      if (a == null || b == null) continue;
      final isHot = hot.contains(t.a) || hot.contains(t.b);
      final dim = !shown.contains(t.a) ||
          !shown.contains(t.b) ||
          (hot.isNotEmpty && !isHot);
      final color = isHot ? glow : line;
      paint
        ..color = color.withValues(alpha: color.a * (dim ? .2 : 1))
        ..strokeWidth = 1 + t.shared * .7;
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), paint);
    }
  }

  @override
  bool shouldRepaint(_TiePainter old) => true;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(
      {required this.glow,
      required this.dots,
      required this.dx,
      required this.dy});
  final Color glow, dots;
  final double dx, dy;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
              center: const Alignment(0, -.1),
              radius: .72,
              colors: [
                glow.withValues(alpha: .1),
                glow.withValues(alpha: 0)
              ]).createShader(Rect.fromCenter(
              center: rect.center,
              width: size.width * 1.4,
              height: size.height * 1.2)));
    final paint = Paint();
    for (var i = 0; i < 52; i++) {
      final x = (math.sin(i * 91.7) * .5 + .5) * 700 - 155 + dx;
      final y = (math.sin(i * 37.3 + 1) * .5 + .5) * 760 - 165 + dy;
      paint.color = dots.withValues(alpha: .12 + (i % 5) * .06);
      canvas.drawCircle(Offset(x, y), .6 + (i % 3) * .4, paint);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.dx != dx || old.dy != dy || old.glow != glow || old.dots != dots;
}

/// Takes the pointer at once when it lands on a star, so dragging a star
/// never scrolls the page.
class _StarGrab extends EagerGestureRecognizer {
  _StarGrab(this.onStar);
  final bool Function(Offset global) onStar;
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      onStar(event.position) && super.isPointerAllowed(event);
}

/// Holds the arena while one finger rests on the sky: a second finger
/// claims both for a pinch; a lone finger that moves lets the page scroll.
class _TwoFingers extends OneSequenceGestureRecognizer {
  final _down = <int, Offset>{};
  bool _won = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _down[event.pointer] = event.position;
    if (_down.length >= 2) {
      _won = true;
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent &&
        !_won &&
        _down.length == 1 &&
        (event.position - _down[event.pointer]!).distance > kTouchSlop) {
      resolve(GestureDisposition.rejected);
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _down.remove(event.pointer);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _down.clear();
    _won = false;
  }

  @override
  String get debugDescription => 'two fingers';
}
