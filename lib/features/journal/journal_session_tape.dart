import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/companion_kit.dart';
import 'journal_kit.dart';
import 'journal_strings.dart';

/// Sessions as a tape of bubbles, like the round tape in combat. The player
/// taps «+» when a new session starts; new records land in the latest one.
/// A bubble filters the journal by its session; the latest, while empty,
/// can be taken back with a hold.
class JournalSessionTape extends StatefulWidget {
  const JournalSessionTape(
      {super.key,
      required this.current,
      required this.countIn,
      required this.picked,
      required this.onPick,
      required this.onAdd,
      required this.onDrop});
  final int current;
  final int Function(int session) countIn;
  final int? picked;
  final ValueChanged<int?> onPick;
  final VoidCallback onAdd, onDrop;
  @override
  State<JournalSessionTape> createState() => _JournalSessionTapeState();
}

class _JournalSessionTapeState extends State<JournalSessionTape> {
  final _scroll = ScrollController();
  int? _fresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toEnd(false));
  }

  @override
  void didUpdateWidget(JournalSessionTape old) {
    super.didUpdateWidget(old);
    if (widget.current > old.current) {
      _fresh = widget.current;
      WidgetsBinding.instance.addPostFrameCallback((_) => _toEnd(true));
    }
  }

  void _toEnd(bool animate) {
    if (!mounted || !_scroll.hasClients) return;
    final end = _scroll.position.maxScrollExtent;
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      _scroll.animateTo(end,
          duration: AppMotion.gentleSettle, curve: AppMotion.gentleCurve);
    } else {
      _scroll.jumpTo(end);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final a = JournalLook.accent(context, 1);
    final picked = widget.picked;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Text(
                journalUpper(picked != null
                    ? s.t('Сессия $picked', 'Session $picked')
                    : s.t('Идёт сессия ${widget.current}',
                        'Session ${widget.current} in play')),
                style: journalCap(context, a)),
          ),
          if (picked != null)
            Pressable(
              key: const ValueKey('journal-session-clear'),
              onTap: () => widget.onPick(null),
              haptic: true,
              semanticLabel: s.t('Все сессии', 'All sessions'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      '${s.records(widget.countIn(picked))} · ${s.t('все сессии', 'all sessions')}',
                      style: TextStyle(
                          fontFamily: AppType.body,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.secondary)),
                  const SizedBox(width: 5),
                  LineIcon('x', size: 14, color: c.secondary),
                ]),
              ),
            )
          else
            Flexible(
              child: Text(s.t('новые записи попадут в неё', 'new entries go here'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5, color: c.onSurfaceVariant)),
            ),
        ]),
      ),
      const SizedBox(height: 4),
      ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => LinearGradient(colors: const [
          Color(0x00000000),
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0x00000000)
        ], stops: [
          0,
          18 / r.width,
          1 - 18 / r.width,
          1
        ]).createShader(r),
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
          child: CustomPaint(
            painter: _RailPainter(
                c.onSurface.withValues(alpha: .06), a.withValues(alpha: .5)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var n = 1; n <= widget.current; n++) ...[
                _Bubble(
                  key: ValueKey('journal-session-$n'),
                  session: n,
                  now: n == widget.current,
                  selected: picked == n,
                  count: widget.countIn(n),
                  fresh: _fresh == n,
                  onTap: () => widget.onPick(picked == n ? null : n),
                  onHold: n == widget.current &&
                          n > 1 &&
                          widget.countIn(n) == 0
                      ? widget.onDrop
                      : null,
                ),
                const SizedBox(width: 12),
              ],
              _AddBubble(onTap: widget.onAdd),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter(this.from, this.to);
  final Color from, to;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 44) return;
    final rect = Rect.fromLTWH(22, 25, size.width - 44, 2);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..shader = LinearGradient(colors: [from, to]).createShader(rect));
  }

  @override
  bool shouldRepaint(_RailPainter old) => old.from != from || old.to != to;
}

class _Bubble extends StatefulWidget {
  const _Bubble(
      {super.key,
      required this.session,
      required this.now,
      required this.selected,
      required this.count,
      required this.fresh,
      required this.onTap,
      this.onHold});
  final int session, count;
  final bool now, selected, fresh;
  final VoidCallback onTap;
  final VoidCallback? onHold;
  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with TickerProviderStateMixin {
  // A new session arrives with a small give, like a dropped token.
  late final _pop = AnimationController.unbounded(
      vsync: this, value: widget.fresh ? .4 : 1);
  late final _hold = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  Timer? _timer;
  bool _held = false;

  @override
  void initState() {
    super.initState();
    if (widget.fresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          _pop.value = 1;
        } else {
          _pop.animateWith(SpringSimulation(AppMotion.bouncy, .4, 1, 0));
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pop.dispose();
    _hold.dispose();
    super.dispose();
  }

  void _down() {
    if (widget.onHold == null) return;
    _held = false;
    _hold.forward(from: 0);
    _timer = Timer(const Duration(milliseconds: 600), () {
      _held = true;
      HapticFeedback.mediumImpact();
      widget.onHold!();
    });
  }

  void _up() {
    _timer?.cancel();
    if (_hold.value > 0) _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final a = JournalLook.accent(context, 1);
    final side = widget.now ? 52.0 : 44.0;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    final ring = widget.selected
        ? [
            BoxShadow(color: c.surface, spreadRadius: 3),
            BoxShadow(color: c.secondary, spreadRadius: 5.5),
          ]
        : [BoxShadow(color: c.surface, spreadRadius: 4)];
    return Semantics(
      button: true,
      selected: widget.selected,
      label: s.t('Сессия ${widget.session}: ${s.records(widget.count)}',
          'Session ${widget.session}: ${s.records(widget.count)}'),
      hint: widget.onHold == null
          ? null
          : s.t('Удерживайте, чтобы убрать пустую сессию',
              'Hold to remove the empty session'),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _down(),
          onTapCancel: _up,
          onTapUp: (_) => _up(),
          onTap: () {
            if (_held) return;
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          child: SizedBox(
            width: side,
            height: 68,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pop, _hold]),
              builder: (context, child) => Transform.scale(
                  scale: _pop.value * (1 - .18 * _hold.value),
                  child: Opacity(
                      opacity: 1 - .3 * _hold.value, child: child)),
              child: Column(children: [
                // Shadows cannot overshoot: this shape settles on a plain
                // curve.
                AnimatedContainer(
                  duration: dur,
                  curve: AppMotion.standard,
                  margin: EdgeInsets.only(top: widget.now ? 0 : 4),
                  width: side,
                  height: side,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.now ? a : c.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(widget.now ? 18 : side / 2),
                    border: widget.now
                        ? null
                        : Border.all(
                            color: c.onSurface.withValues(alpha: .14),
                            width: 1.5),
                    boxShadow: [
                      ...ring,
                      if (widget.now)
                        BoxShadow(
                            color: a.withValues(alpha: .55),
                            blurRadius: 24,
                            spreadRadius: -10,
                            offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Text('${widget.session}',
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: widget.now ? 20 : 16,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppType.tabular,
                          color: widget.now
                              ? c.surface
                              : widget.count == 0
                                  ? c.onSurfaceVariant
                                  : c.onSurface)),
                ),
                const SizedBox(height: 6),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < widget.count.clamp(0, 3); i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.now
                                ? a
                                : c.onSurface.withValues(alpha: .4))),
                  ]
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddBubble extends StatelessWidget {
  const _AddBubble({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    return Pressable(
      key: const ValueKey('journal-session-add'),
      onTap: onTap,
      scale: .9,
      semanticLabel: s.t('Новая сессия', 'New session'),
      child: SizedBox(
        width: 44,
        height: 68,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surface,
                boxShadow: [BoxShadow(color: c.surface, spreadRadius: 4)]),
            child: JournalDashed(
              circle: true,
              width: 1.6,
              color: c.onSurface.withValues(alpha: .3),
              child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                      child: LineIcon('plus',
                          size: 20, color: c.onSurfaceVariant))),
            ),
          ),
        ),
      ),
    );
  }
}
