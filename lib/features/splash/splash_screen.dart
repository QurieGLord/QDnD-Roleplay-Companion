import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_info.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../character_list/character_list_screen.dart';
import '../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';

/// The launch: a d20 is thrown onto the table. It flies in on an arc while
/// it spins, bounces twice with a squash and its shadow tightening, its
/// faces flicker ever slower, it lands on a natural 20 with a ring of light
/// and then turns into the app's mark. The name rises letter by letter and
/// the lobby comes up from below.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.next});

  /// Where the launch leads; the lobby by default.
  final WidgetBuilder? next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// The throw's timeline in milliseconds.
abstract final class _T {
  static const total = 2700;
  static const hit1 = 560; // first touch of the table
  static const hit2 = 820; // after the first bounce
  static const rest = 960; // after the second, small bounce: a 20
  static const morph = 1250; // the die gives way to the mark
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _t = AnimationController(
      vsync: this, duration: const Duration(milliseconds: _T.total))
    ..addListener(_haptics);
  final _timers = <Timer>[];
  var _reduced = false;
  var _felt = 0;

  /// Faces shown in flight, each a little longer than the last.
  static final List<(int, String)> _flicker = () {
    final rnd = math.Random(7);
    final out = <(int, String)>[];
    var at = 0.0, wait = 40.0, last = 0;
    while (at < _T.rest) {
      var n = 1 + rnd.nextInt(19);
      if (n == last) n = n % 19 + 1;
      last = n;
      out.add((at.round(), '$n'));
      at += wait;
      wait *= 1.17;
    }
    return out;
  }();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_t.isAnimating || _t.value > 0 || _timers.isNotEmpty) return;
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _t.value = 1;
      _later(700, _done);
      return;
    }
    _t.forward();
    _later(_T.total, _done);
  }

  double get _ms => _t.value * _T.total;

  /// A tap on each touch of the table, a firm one when the 20 settles.
  void _haptics() {
    const marks = [_T.hit1, _T.hit2, _T.rest];
    while (_felt < marks.length && _ms >= marks[_felt]) {
      switch (_felt) {
        case 0:
          HapticFeedback.lightImpact();
        case 1:
          HapticFeedback.selectionClick();
        default:
          HapticFeedback.mediumImpact();
      }
      _felt++;
    }
  }

  void _later(int ms, VoidCallback f) =>
      _timers.add(Timer(Duration(milliseconds: ms), () {
        if (mounted) f();
      }));

  void _done() {
    final next = widget.next ?? (_) => const CharacterListScreen();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: AppMotion.of(context, AppMotion.gentleSettle),
      pageBuilder: (context, _, __) => next(context),
      transitionsBuilder: (context, animation, _, child) {
        final move = AppMotion.gentleCurve.transform(animation.value);
        return Opacity(
          opacity: AppMotion.standard.transform(animation.value),
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - move)),
            child:
                Transform.scale(scale: lerpDouble(.98, 1, move), child: child),
          ),
        );
      },
    ));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _t.dispose();
    super.dispose();
  }

  /// Progress of a stretch of the timeline, [start] and [length] in ms.
  double _seg(int start, int length, [Curve curve = Curves.linear]) {
    final v = ((_ms - start) / length).clamp(0.0, 1.0);
    return curve.transform(v);
  }

  /// Where the die is: its offset from the resting spot, its turn, and how
  /// much it is squashed against the table (0 — not at all).
  ({double x, double y, double turn, double squash}) _throw() {
    final t = _ms;
    double x, y;
    if (t < _T.hit1) {
      // In from high on the left, falling ever faster.
      final p = t / _T.hit1;
      x = lerpDouble(-176, -24, Curves.easeOut.transform(p))!;
      y = lerpDouble(-430, 0, p * p)!;
    } else if (t < _T.hit2) {
      final q = (t - _T.hit1) / (_T.hit2 - _T.hit1);
      x = lerpDouble(-24, -6, q)!;
      y = -54 * 4 * q * (1 - q);
    } else if (t < _T.rest) {
      final q = (t - _T.hit2) / (_T.rest - _T.hit2);
      x = lerpDouble(-6, 0, q)!;
      y = -12 * 4 * q * (1 - q);
    } else {
      x = 0;
      y = 0;
    }
    // Two and a half turns, slowing to rest upright.
    final p = (t / _T.rest).clamp(0.0, 1.0);
    final turn = -5 * math.pi * math.pow(1 - p, 2.2);
    // A short squash after each touch, the first the strongest.
    double hit(int at, double depth) {
      if (t < at || t > at + 140) return 0;
      final k = (t - at) / 140;
      return depth * math.sin(math.pi * k) * (1 - k * .4);
    }

    final squash = hit(_T.hit1, 1) + hit(_T.hit2, .45) + hit(_T.rest, .2);
    return (x: x, y: y, turn: turn.toDouble(), squash: squash);
  }

  String _face() {
    if (_ms >= _T.rest) return '20';
    var face = _flicker.first.$2;
    for (final (at, n) in _flicker) {
      if (at > _ms) break;
      face = n;
    }
    return face;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final calm = AppCalm.of(context);
    const word = AppInfo.name;
    const die = 84.0;
    return Scaffold(
      backgroundColor: c.surface,
      body: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          double after(int at, int length, [Curve curve = Curves.linear]) =>
              _reduced ? 1 : _seg(at, length, curve);
          final pose = _throw();
          final height = (-pose.y / 430).clamp(0.0, 1.0);
          final landed = after(_T.rest, 300);
          final gone = after(_T.morph, 360, AppMotion.standard);
          final ring = after(_T.rest, 620, Curves.easeOut);
          return SizedBox.expand(
            child: Stack(alignment: Alignment.center, children: [
              // A soft light of the palette's primary that wakes with the 20.
              IgnorePointer(
                child: Opacity(
                  opacity: after(_T.rest, 900) * calm.glow,
                  child: Transform.scale(
                    scale: lerpDouble(
                        .6, 1, after(_T.rest, 1200, AppMotion.gentleCurve)),
                    child: Container(
                      width: 420,
                      height: 420,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(stops: const [
                          0,
                          .65
                        ], colors: [
                          c.primary.withValues(alpha: .26),
                          c.primary.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Opacity(
                  opacity: after(_T.morph + 60, 420),
                  child: Transform.scale(
                    scale: lerpDouble(.62, 1,
                        after(_T.morph + 60, 900, AppMotion.snappyCurve)),
                    child: SvgPicture.asset('assets/images/icon.svg',
                        width: 168,
                        height: 168,
                        colorFilter:
                            ColorFilter.mode(c.primary, BlendMode.srcIn)),
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  label: word,
                  child: ExcludeSemantics(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < word.length; i++)
                        Opacity(
                          opacity: after(_T.morph + 200 + i * 28, 400),
                          child: Transform.translate(
                            offset: Offset(
                                0,
                                14 *
                                    (1 -
                                        after(_T.morph + 200 + i * 28, 620,
                                            AppMotion.snappyCurve))),
                            child: Text(word[i],
                                style: TextStyle(
                                    fontFamily: AppType.display,
                                    fontSize: 23,
                                    height: 1,
                                    letterSpacing: .46,
                                    fontWeight: FontWeight.w600,
                                    color: c.onSurface.withValues(alpha: .86))),
                          ),
                        ),
                    ]),
                  ),
                ),
              ]),
              if (!_reduced && gone < 1) ...[
                // The table under the die: the shadow tightens as it nears.
                Transform.translate(
                  offset: Offset(pose.x * .9, -20 + die * .5 + 4),
                  child: Opacity(
                    opacity: (1 - gone) * (.25 + .65 * (1 - height)),
                    child: Container(
                      width: die * (1.05 - .45 * height),
                      height: 14,
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.elliptical(60, 7)),
                        gradient: RadialGradient(colors: [
                          Colors.black.withValues(alpha: .4),
                          Colors.black.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                ),
                // The ring of a natural 20.
                if (ring > 0 && ring < 1)
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: IgnorePointer(
                      child: Container(
                        width: lerpDouble(die, 300, ring),
                        height: lerpDouble(die, 300, ring),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color:
                                  c.primary.withValues(alpha: .7 * (1 - ring)),
                              width: lerpDouble(5, 1, ring)!),
                        ),
                      ),
                    ),
                  ),
                Transform.translate(
                  offset: Offset(pose.x, -20 + pose.y),
                  child: Opacity(
                    opacity: (1 - gone) * after(0, 140),
                    child: Transform.rotate(
                      angle: pose.turn + gone * math.pi / 5,
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.diagonal3Values(
                            (1 + .12 * pose.squash) * (1 - .4 * gone),
                            (1 - .16 * pose.squash) * (1 - .4 * gone),
                            1),
                        child: DieFace(
                          shape: DieShape.d20,
                          label: _face(),
                          accent: c.primary,
                          size: die,
                          glow: landed,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Positioned(
                bottom: 40 + MediaQuery.paddingOf(context).bottom,
                child: Opacity(
                  opacity: after(_T.morph + 500, 600),
                  child: Text(AppInfo.line,
                      style: TextStyle(
                          fontSize: 12,
                          fontFeatures: AppType.tabular,
                          color: c.onSurfaceVariant)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}
