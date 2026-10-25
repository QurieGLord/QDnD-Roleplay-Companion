import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_tokens.dart';
import '../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';

/// Wave 3 initiative ceremony (`.ceremony`): the screen dims to a red
/// glow, a large d20 is thrown, the sum rises below it — roll, modifier,
/// total — and the fight begins. Returns the total, or null when closed
/// before the die lands.
Future<int?> showInitiativeCeremony(BuildContext context,
    {required int bonus, bool advantage = false, math.Random? random}) {
  final rnd = random ?? math.Random();
  final a = rnd.nextInt(20) + 1, b = advantage ? rnd.nextInt(20) + 1 : 0;
  final roll = math.max(a, b);
  return Navigator.of(context).push<int>(PageRouteBuilder<int>(
    opaque: false,
    barrierDismissible: false,
    transitionDuration:
        AppMotion.of(context, const Duration(milliseconds: 420)),
    reverseTransitionDuration:
        AppMotion.of(context, const Duration(milliseconds: 420)),
    pageBuilder: (context, animation, _) => _Ceremony(
        animation: animation,
        roll: roll,
        other: advantage ? math.min(a, b) : null,
        bonus: bonus),
  ));
}

class _Ceremony extends StatefulWidget {
  const _Ceremony(
      {required this.animation,
      required this.roll,
      required this.bonus,
      this.other});
  final Animation<double> animation;
  final int roll, bonus;
  final int? other;
  @override
  State<_Ceremony> createState() => _CeremonyState();
}

class _CeremonyState extends State<_Ceremony> {
  int _key = 0;
  bool _landed = false;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final still = MediaQuery.disableAnimationsOf(context);
      _later(still ? 0 : 380, () => setState(() => _key++));
      _later(still ? 0 : 380 + 820, () {
        HapticFeedback.mediumImpact();
        setState(() => _landed = true);
      });
      _later(still ? 200 : 380 + 820 + 1100,
          () => Navigator.of(context).pop(widget.roll + widget.bonus));
    });
  }

  void _later(int ms, VoidCallback f) =>
      _timers.add(Timer(Duration(milliseconds: ms), () {
        if (mounted) f();
      }));

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final total = widget.roll + widget.bonus;
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final p = widget.animation.value;
        return Stack(children: [
          Positioned.fill(
            child: Opacity(
              opacity: p,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                      center: const Alignment(0, -.1),
                      radius: .9,
                      colors: [
                        c.primary.withValues(alpha: .35),
                        const Color(0xDB0C0A08)
                      ],
                      stops: const [
                        0,
                        .7
                      ]),
                ),
              ),
            ),
          ),
          Center(
            child: Opacity(
              opacity: p,
              child: Transform.scale(
                  scale: .9 + .1 * AppMotion.snappyCurve.transform(p),
                  child: child),
            ),
          ),
        ]);
      },
      child: Material(
        type: MaterialType.transparency,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text((ru ? 'Бросок инициативы' : 'Initiative roll').toUpperCase(),
              style: TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: c.onSurface.withValues(alpha: .8))),
          const SizedBox(height: 14),
          TumbleDie(
            key: const ValueKey('ceremony-die'),
            shape: DieShape.d20,
            label: _key == 0 ? (ru ? 'к20' : 'd20') : '${widget.roll}',
            accent: c.primary,
            rollKey: _key,
            natural: _landed ? widget.roll : null,
            size: 150,
          ),
          const SizedBox(height: 14),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _landed ? 1 : 0,
            child: Column(children: [
              Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('${widget.roll}',
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: c.onSurfaceVariant)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: accentOf(context, 1).withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                          '${widget.bonus >= 0 ? '+' : '−'}${widget.bonus.abs()} ${ru ? 'ЛОВ' : 'DEX'}',
                          style: TextStyle(
                              fontFamily: AppType.display,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: accentOf(context, 1))),
                    ),
                    const SizedBox(width: 10),
                    Text('=',
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: c.onSurfaceVariant)),
                    const SizedBox(width: 10),
                    Text('$total',
                        key: const ValueKey('ceremony-total'),
                        style: const TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 60,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.8)),
                  ]),
              if (widget.other != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      ru
                          ? 'Звериное чутьё: лучший из двух (${widget.other} и ${widget.roll})'
                          : 'Feral Instinct: the better of two (${widget.other} and ${widget.roll})',
                      style: TextStyle(
                          fontFamily: AppType.body,
                          fontSize: 12.5,
                          color: c.onSurfaceVariant)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
