import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_palettes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/companion_kit.dart';
import '../../../core/ui/expressive_kit.dart';
import '../../../core/ui/page_kit.dart';
import '../../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';
import 'advancement_layout.dart';

/// Wave 6: the hero grows. The «Восхождение» head of the level-up screen,
/// its island dock, the detail sheet behind a long press or the «i», and
/// the ceremony of a confirmed level, after the accepted prototype
/// (`docs/prototypes/wave6/index.html`).

/// A choice answers its own change: chosen, it swells a little and settles
/// on a spring; let go, it dips. Nothing moves on the first frame.
class SelectPulse extends StatefulWidget {
  const SelectPulse({super.key, required this.on, required this.child});
  final bool on;
  final Widget child;
  @override
  State<SelectPulse> createState() => _SelectPulseState();
}

class _SelectPulseState extends State<SelectPulse>
    with SingleTickerProviderStateMixin {
  late final _t = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420), value: 1);

  @override
  void didUpdateWidget(covariant SelectPulse old) {
    super.didUpdateWidget(old);
    if (old.on != widget.on && !MediaQuery.disableAnimationsOf(context)) {
      _t.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) {
          final wave = math.sin(math.pi * AppMotion.standard.transform(_t.value));
          return Transform.scale(
              scale: 1 + (widget.on ? .03 : -.015) * wave, child: child);
        },
      );
}

/// [AnimatedSize] that steps aside when motion is off: with a zero
/// duration it would re-layout itself while laying out.
class SoftSize extends StatelessWidget {
  const SoftSize(
      {super.key,
      required this.duration,
      required this.child,
      this.curve = Curves.linear,
      this.alignment = Alignment.center});
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;
  final Widget child;
  @override
  Widget build(BuildContext context) => duration == Duration.zero
      ? child
      : AnimatedSize(
          duration: duration, curve: curve, alignment: alignment, child: child);
}

/// The steps under the head (`.pager6`): a strip that slides a whole
/// page width — the step that leaves goes out to one side while the next
/// comes in from the other — and eases its height to the new step. Steps
/// not on screen keep their state offstage.
class AdvancementPager extends StatefulWidget {
  const AdvancementPager(
      {super.key,
      required this.index,
      required this.direction,
      required this.children});
  final int index, direction;
  final List<Widget> children;
  @override
  State<AdvancementPager> createState() => _AdvancementPagerState();
}

class _AdvancementPagerState extends State<AdvancementPager>
    with SingleTickerProviderStateMixin {
  late final _t = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 560), value: 1);
  int? _from;

  @override
  void didUpdateWidget(covariant AdvancementPager old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _from = null;
        return;
      }
      _from = old.index;
      _t.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _from = null);
      });
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SoftSize(
        duration: AppMotion.of(context, const Duration(milliseconds: 460)),
        curve: AppMotion.standard,
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final p = AppMotion.gentleCurve.transform(_t.value);
            final d = widget.direction.toDouble();
            return Stack(children: [
              for (var i = 0; i < widget.children.length; i++)
                Offstage(
                  offstage: i != widget.index && i != _from,
                  child: TickerMode(
                    enabled: i == widget.index,
                    child: FractionalTranslation(
                      translation: Offset(
                          i == widget.index
                              ? d * (1 - p)
                              : i == _from
                                  ? -d * p
                                  : 0,
                          0),
                      child: Opacity(
                        opacity: i == _from
                            ? (1 - p * 1.4).clamp(0.0, 1.0)
                            : (.25 + .75 * p).clamp(0.0, 1.0),
                        child: widget.children[i],
                      ),
                    ),
                  ),
                ),
            ]);
          },
        ),
      ),
    );
  }
}

/// One line of «what will change» under the ladder; [value] stays empty
/// while the step that decides it is still open.
class AdvancementChange {
  const AdvancementChange(this.icon, this.label, [this.value]);
  final String icon, label;
  final String? value;
}

/// The head: the hero's letter, class line and name, the level jump in
/// large numbers, a ladder of twenty rungs and the changes as chips.
///
/// On the way in the rungs rise, the levels the hero already has fill
/// softly from the bottom, and then the new rung follows [progress]:
/// 0 — nothing settled yet, 1 — ready to confirm.
class AdvancementClimb extends StatefulWidget {
  const AdvancementClimb(
      {super.key,
      required this.name,
      required this.accent,
      required this.classLine,
      required this.from,
      required this.to,
      required this.progress,
      required this.changes});
  final String name, classLine;
  final Color accent;
  final int from, to;
  final double progress;
  final List<AdvancementChange> changes;
  @override
  State<AdvancementClimb> createState() => _AdvancementClimbState();
}

class _Fill {
  _Fill(this.from, this.to, this.start, this.duration, this.curve);
  final double from, to;
  final Duration start, duration;
  final Curve curve;
  double at(Duration now) {
    final t = ((now - start).inMicroseconds / duration.inMicroseconds)
        .clamp(0.0, 1.0);
    return from + (to - from) * curve.transform(t);
  }

  bool over(Duration now) => now >= start + duration;
}

class _AdvancementClimbState extends State<AdvancementClimb>
    with TickerProviderStateMixin {
  static const _rungs = 20;
  late final AnimationController _rise = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 560 + 19 * 18));
  late final Ticker _ticker = createTicker(_tick);
  // The ticker's clock restarts with each run; [_origin] keeps one timeline.
  Duration _now = Duration.zero, _origin = Duration.zero;
  final _fills = List<double>.filled(_rungs, 0);
  final _segments = <int, _Fill>{};
  double _at = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enter());
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  Future<void> _enter() async {
    if (!mounted) return;
    if (_reduced) {
      _rise.value = 1;
      _paint(widget.from + widget.progress.clamp(0, 1), wave: 0);
      _ready = true;
      return;
    }
    _rise.forward();
    // The levels the hero already has fill from the bottom, one by one.
    await _wait(const Duration(milliseconds: 380));
    _paint(widget.from.toDouble(), wave: 90);
    await _wait(Duration(milliseconds: 260 + widget.from * 90));
    _ready = true;
    _paint(widget.from + widget.progress.clamp(0, 1), wave: 0);
  }

  Future<void> _wait(Duration d) => Future<void>.delayed(d);

  @override
  void didUpdateWidget(covariant AdvancementClimb old) {
    super.didUpdateWidget(old);
    if (_ready &&
        (old.progress != widget.progress ||
            old.from != widget.from ||
            old.to != widget.to)) {
      _paint(widget.from + widget.progress.clamp(0, 1), wave: 0);
    }
  }

  /// Sets how many rungs are full; they fill one after another in the
  /// direction of travel, [wave] apart.
  void _paint(double at, {required int wave}) {
    if (!mounted) return;
    final rising = at >= _at;
    for (var i = 0; i < math.min(widget.to, _rungs); i++) {
      final target = (at - i).clamp(0.0, 1.0);
      final current = _segments[i]?.at(_now) ?? _fills[i];
      if ((target - current).abs() < .001) continue;
      final order = rising ? i - _at.floor() : _at.ceil() - i;
      final goal = i == widget.to - 1;
      _segments[i] = _Fill(
          current,
          target,
          _now + Duration(milliseconds: _reduced ? 0 : math.max(0, order) * wave),
          _reduced
              ? Duration.zero
              : Duration(milliseconds: goal ? 760 : 620),
          goal ? AppMotion.snappyCurve : AppMotion.standard);
    }
    _at = at;
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration elapsed) {
    final now = _now = _origin + elapsed;
    setState(() {
      for (final e in _segments.entries.toList()) {
        _fills[e.key] = e.value.at(now);
        if (e.value.over(now)) _segments.remove(e.key);
      }
    });
    if (_segments.isEmpty) {
      _origin = _now;
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final glow = AppCalm.of(context).glow;
    final a = widget.accent;
    final to = widget.to;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
            begin: const Alignment(-.6, -1),
            end: const Alignment(.6, 1),
            colors: [pageMix(a, .16, c.surfaceContainerLow), c.surfaceContainerLow],
            stops: const [0, .7]),
      ),
      child: Stack(children: [
        if (glow > 0)
          Positioned(
            right: -80,
            top: -110,
            width: 260,
            height: 220,
            child: Opacity(
              opacity: glow,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        a.withValues(alpha: .3),
                        a.withValues(alpha: 0)
                      ], stops: const [0, .66]))),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _Letter(name: widget.name, accent: a),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: AppMotion.of(context, AppMotion.medium),
                        child: PageCap(widget.classLine,
                            key: ValueKey(widget.classLine), accent: a),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppType.display,
                              fontSize: 18,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                              color: c.onSurface)),
                    ]),
              ),
              const SizedBox(width: 8),
              // On a very narrow screen the jump shrinks instead of spilling.
              Flexible(
                flex: 0,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${widget.from}',
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 34,
                            height: .9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.7,
                            color: c.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    // The arrow sits at the middle of the small number.
                    Text.rich(
                        TextSpan(children: [
                          WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: LineIcon('forward',
                                  size: 22, color: c.onSurfaceVariant)),
                        ]),
                        style: const TextStyle(fontSize: 34, height: .9)),
                    const SizedBox(width: 6),
                    Text('$to',
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 54,
                            height: .9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -2.7,
                            color: Color.lerp(c.onSurface, a, .8))),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: AnimatedBuilder(
                animation: _rise,
                builder: (context, _) => Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < _rungs; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(child: _rung(i, c)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SoftSize(
              duration: AppMotion.of(context, AppMotion.long),
              curve: AppMotion.standard,
              alignment: Alignment.topLeft,
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final change in widget.changes)
                  _ChangeChip(change: change, accent: a),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _rung(int i, ColorScheme c) {
    final a = widget.accent;
    final track = i < widget.to, goal = i == widget.to - 1;
    // The rungs rise one after another on the way in.
    final start = i * 18 / (560 + 19 * 18), span = 560 / (560 + 19 * 18);
    final rise = AppMotion.gentleCurve
        .transform(((_rise.value - start) / span).clamp(0.0, 1.0));
    final f = track ? _fills[i].clamp(0.0, 1.0) : 0.0;
    final full = goal && _at >= widget.to;
    final going = goal && _at > widget.to - 1 && _at < widget.to;
    final glow = AppCalm.of(context).glow;
    const radius = BorderRadius.vertical(
        top: Radius.circular(4), bottom: Radius.circular(2));
    return Align(
      alignment: Alignment.bottomCenter,
      child: Transform.scale(
        scaleY: .15 + .85 * rise,
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          duration: AppMotion.of(context, const Duration(milliseconds: 400)),
          height: 12 + i * 1.6,
          // The goal's outline lies over its fill, so the fill reaches the edges.
          foregroundDecoration: goal && !full
              ? BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                      color: a.withValues(alpha: going ? 1 : .55), width: 1.5))
              : null,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: track
                ? a.withValues(alpha: .12)
                : c.onSurface.withValues(alpha: .1),
            boxShadow: [
              if (going)
                BoxShadow(color: a.withValues(alpha: .18), spreadRadius: 3),
              if (full) ...[
                BoxShadow(color: a.withValues(alpha: .25), spreadRadius: 3),
                if (glow > 0)
                  BoxShadow(
                      color: a.withValues(alpha: .8 * glow),
                      blurRadius: 14,
                      spreadRadius: -4,
                      offset: const Offset(0, 6)),
              ],
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: f,
                widthFactor: 1,
                child: ColoredBox(
                    color: goal ? a : pageMix(a, .72, c.surfaceContainer)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({required this.name, required this.accent});
  final String name;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first;
    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.long),
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: accent, borderRadius: BorderRadius.circular(22)),
      child: Text(letter.toUpperCase(),
          style: TextStyle(
              fontFamily: AppType.display,
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w600,
              color: pageOnAccent(c))),
    );
  }
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({required this.change, required this.accent});
  final AdvancementChange change;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final wait = change.value == null;
    final dur = AppMotion.of(context, AppMotion.medium);
    return AnimatedContainer(
      duration: dur,
      height: 32,
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: wait ? Colors.transparent : c.onSurface.withValues(alpha: .06),
        border: Border.all(
            color: wait
                ? c.onSurface.withValues(alpha: .16)
                : Colors.transparent,
            width: 1.4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InstrumentGlyph(change.icon,
            size: 15, color: wait ? c.onSurfaceVariant : accent),
        const SizedBox(width: 6),
        Text(change.label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: wait ? c.onSurfaceVariant : c.onSurface)),
        SoftSize(
          duration: dur,
          curve: AppMotion.standard,
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.snappySettle),
            switchInCurve: AppMotion.snappyCurve,
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: wait
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey(change.value),
                    padding: const EdgeInsets.only(left: 5),
                    child: Text(change.value!,
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color.lerp(c.onSurface, accent, .8))),
                  ),
          ),
        ),
      ]),
    );
  }
}

/// The island dock over the page, as in the journal: a round back button
/// that folds away on the first step, the forward action and a glass hint
/// above it. It shows the button the current step handed over.
class AdvancementIsland extends StatelessWidget {
  const AdvancementIsland(
      {super.key,
      required this.action,
      required this.canGoBack,
      required this.onBack,
      required this.accent,
      this.last = false,
      this.labelOverride,
      this.hintOverride});
  final AdvancementDockAction? action;
  final bool canGoBack, last;
  final VoidCallback onBack;
  final Color accent;
  final String? labelOverride, hintOverride;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final tr = Tr(context);
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    final hint = hintOverride ?? action?.hint ?? '';
    final ready = action?.onPressed != null && !(action?.busy ?? false);
    final label = labelOverride ?? action?.label ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(
          14, 0, 14, 18 + MediaQuery.paddingOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SoftSize(
          duration: AppMotion.of(context, AppMotion.medium),
          curve: AppMotion.standard,
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.medium),
          child: hint.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  key: ValueKey(hint),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      child: Text(hint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: c.onSurface)),
                    ),
                  ),
                ),
        ),
        ),
        GlassSurface(
          borderRadius: BorderRadius.circular(36),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              AnimatedContainer(
                duration: dur,
                curve: AppMotion.standard,
                width: canGoBack ? 60 : 0,
                height: 52,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 60,
                    maxWidth: 60,
                    child: AnimatedOpacity(
                      duration: AppMotion.of(context, AppMotion.medium),
                      opacity: canGoBack ? 1 : 0,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: JournalRoundLike(
                            icon: 'back',
                            label: tr.t('Назад', 'Back'),
                            onTap: canGoBack ? onBack : null),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Pressable(
                  key: const ValueKey('advancement-island-next'),
                  onTap: ready
                      ? () {
                          HapticFeedback.selectionClick();
                          action!.onPressed!();
                        }
                      : null,
                  scale: .97,
                  semanticLabel: label,
                  child: AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.medium),
                    height: 52,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        color: ready
                            ? c.primary
                            : c.onSurface.withValues(alpha: .1)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: ready
                                    ? c.onPrimary
                                    : c.onSurface.withValues(alpha: .45))),
                      ),
                      const SizedBox(width: 8),
                      if (action?.busy ?? false)
                        SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: c.onSurfaceVariant))
                      else
                        LineIcon(last ? 'check' : 'forward',
                            size: 18,
                            color: ready
                                ? c.onPrimary
                                : c.onSurface.withValues(alpha: .45)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// The dock's round button (`.round.dkb`, 52).
class JournalRoundLike extends StatelessWidget {
  const JournalRoundLike(
      {super.key, required this.icon, required this.label, this.onTap});
  final String icon, label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      scale: .92,
      haptic: true,
      semanticLabel: label,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.onSurface.withValues(alpha: .08)),
        child: LineIcon(icon, size: 22, color: c.onSurface),
      ),
    );
  }
}

/// What a choice really is: shown by the «i» and by a long press.
class AdvancementInfo {
  const AdvancementInfo(
      {required this.kicker,
      required this.title,
      required this.icon,
      required this.accent,
      this.text = '',
      this.facts = const [],
      this.rows = const [],
      this.feats = const [],
      this.featsTitle});
  final String kicker, title, icon, text;
  final Color accent;
  final List<String> facts;

  /// (heading, value, glyph).
  final List<(String, String, String)> rows;

  /// (name, text, glyph).
  final List<(String, String, String)> feats;
  final String? featsTitle;
}

Future<void> showAdvancementInfo(BuildContext context, AdvancementInfo info) {
  return showCompanionSheet<void>(context, builder: (context) {
    final c = Theme.of(context).colorScheme;
    final a = info.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          PageSeal(info.icon, accent: a, size: PageSealSize.lg),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageCap(info.kicker, accent: a),
                  const SizedBox(height: 6),
                  Text(info.title,
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 26,
                          height: 1.12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.52,
                          color: c.onSurface)),
                ]),
          ),
        ]),
        if (info.text.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(info.text,
              style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: c.onSurface.withValues(alpha: .88))),
        ],
        if (info.facts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in info.facts) AdvancementFact(f, accent: a),
          ]),
        ],
        if (info.rows.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final (head, value, icon) in info.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: c.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: InstrumentGlyph(icon,
                            size: 18, color: c.secondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(head.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: .66,
                                      color: c.onSurfaceVariant)),
                              const SizedBox(height: 4),
                              Text(value,
                                  style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                      color: c.onSurface)),
                            ]),
                      ),
                    ]),
              ),
            ),
        ],
        if (info.feats.isNotEmpty) ...[
          if (info.featsTitle != null) ...[
            const SizedBox(height: 18),
            Text(info.featsTitle!,
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: c.onSurface)),
          ],
          const SizedBox(height: 10),
          for (final (name, text, icon) in info.feats)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AdvancementGain(
                  icon: icon, title: name, text: text, accent: a),
            ),
        ],
      ]),
    );
  });
}

/// A small fact capsule (`.fact6`).
class AdvancementFact extends StatelessWidget {
  const AdvancementFact(this.text, {super.key, this.accent, this.icon});
  final String text;
  final Color? accent;
  final String? icon;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: c.onSurface.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          InstrumentGlyph(icon!, size: 14, color: accent ?? c.secondary),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: c.onSurface)),
        ),
      ]),
    );
  }
}

/// A gained thing (`.gainc`): a seal, the name and what it does; with
/// [onTap] it opens and shows a chevron.
class AdvancementGain extends StatelessWidget {
  const AdvancementGain(
      {super.key,
      required this.icon,
      required this.title,
      required this.text,
      required this.accent,
      this.onTap,
      this.trailing,
      this.small = false});
  final String icon, title, text;
  final Color accent;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final body = Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
            begin: const Alignment(-.6, -1),
            end: const Alignment(.6, 1),
            colors: [pageMix(accent, .1, c.surfaceContainerLow), c.surfaceContainerLow],
            stops: const [0, .7]),
      ),
      child: Row(children: [
        PageSeal(icon,
            accent: accent, size: small ? PageSealSize.sm : PageSealSize.md),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: c.onSurface)),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(text,
                  maxLines: onTap == null ? null : 3,
                  overflow: onTap == null ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, height: 1.4, color: c.onSurfaceVariant)),
            ],
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!]
        else if (onTap != null) ...[
          const SizedBox(width: 8),
          LineIcon('forward', size: 18, color: c.onSurfaceVariant),
        ],
      ]),
    );
    if (onTap == null) return body;
    return Pressable(onTap: onTap, scale: .985, haptic: true, child: body);
  }
}

/// A long press opens a choice: an accent ring fills under the finger, then
/// [onHold] runs and the tap that would have followed is swallowed.
class AdvancementHold extends StatefulWidget {
  const AdvancementHold(
      {super.key,
      required this.child,
      required this.onHold,
      required this.accent,
      this.radius = 26});
  final Widget child;
  final VoidCallback onHold;
  final Color accent;
  final double radius;
  @override
  State<AdvancementHold> createState() => _AdvancementHoldState();
}

class _AdvancementHoldState extends State<AdvancementHold>
    with SingleTickerProviderStateMixin {
  // The outline follows the finger itself, not the gesture arena: it waits
  // until the finger has clearly stayed, and any movement, lift or cancel
  // puts it out. A touch that starts a scroll never lights the card.
  static const _quiet = Duration(milliseconds: 200);
  late final _ring = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  Timer? _wait;
  Offset? _down;

  void _start(PointerDownEvent e) {
    _down = e.position;
    _wait?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) return;
    _wait = Timer(_quiet, () {
      if (mounted && _down != null) _ring.forward(from: 0);
    });
  }

  void _move(PointerMoveEvent e) {
    if (_down != null && (e.position - _down!).distance > kTouchSlop / 2) {
      _out();
    }
  }

  void _out() {
    _down = null;
    _wait?.cancel();
    _wait = null;
    if (_ring.value > 0 || _ring.isAnimating) {
      _ring.animateBack(0,
          duration: const Duration(milliseconds: 140), curve: AppMotion.exit);
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: _start,
      onPointerMove: _move,
      onPointerUp: (_) => _out(),
      onPointerCancel: (_) => _out(),
      child: RawGestureDetector(
        gestures: {
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
                duration: Duration(milliseconds: reduced ? 380 : 480)),
            (r) => r
              ..onLongPress = () {
                _out();
                _ring.value = 0;
                HapticFeedback.mediumImpact();
                widget.onHold();
              },
          ),
        },
        child: AnimatedBuilder(
          animation: _ring,
          child: widget.child,
          builder: (context, child) => CustomPaint(
            foregroundPainter: _ring.value == 0
                ? null
                : _HoldRing(widget.accent, _ring.value, widget.radius),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _HoldRing extends CustomPainter {
  _HoldRing(this.accent, this.t, this.radius);
  final Color accent;
  final double t, radius;
  @override
  void paint(Canvas canvas, Size size) {
    final w = 3 * t;
    final r = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(w / 2), Radius.circular(radius));
    canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = accent.withValues(alpha: .55));
  }

  @override
  bool shouldRepaint(_HoldRing old) => old.t != t || old.accent != accent;
}

/// A choice card (`.pick6.card6`): a seal, the name and a short line, the
/// «i» and a tick. Chosen, it squares its corners, takes a thin accent
/// ring, fills its seal and tilts it a little. A long press or the «i»
/// opens the whole description.
class AdvancementPick extends StatelessWidget {
  const AdvancementPick(
      {super.key,
      required this.selected,
      required this.title,
      required this.icon,
      required this.accent,
      this.subtitle,
      this.chips = const [],
      this.source,
      this.onTap,
      this.onInfo,
      this.blocked = false,
      this.multi = false});
  final bool selected, blocked, multi;
  final String title, icon;
  final String? subtitle, source;
  final Color accent;
  final List<String> chips;
  final VoidCallback? onTap, onInfo;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    final card = AnimatedContainer(
      duration: dur,
      curve: AppMotion.snappyCurve,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(selected ? 18 : 26),
        color: selected
            ? pageMix(accent, .1, c.surfaceContainerLow)
            : c.surfaceContainerLow,
        border: Border.all(
            color: selected ? accent.withValues(alpha: .55) : Colors.transparent,
            width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AnimatedRotation(
            duration: dur,
            curve: AppMotion.snappyCurve,
            turns: selected ? -6 / 360 : 0,
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.medium),
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: selected
                      ? accent
                      : pageMix(accent, .2, c.surfaceContainer),
                  borderRadius: BorderRadius.circular(18)),
              child: InstrumentGlyph(icon,
                  size: 26, color: selected ? pageOnAccent(c) : accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 17,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: c.onSurface)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: c.onSurfaceVariant)),
                  ],
                ]),
          ),
          if (onInfo != null) ...[
            const SizedBox(width: 8),
            AdvancementInfoButton(onTap: onInfo!),
          ],
          const SizedBox(width: 8),
          AnimatedOpacity(
            duration: AppMotion.of(context, AppMotion.medium),
            opacity: blocked ? 0 : 1,
            child: AnimatedContainer(
              duration: dur,
              curve: AppMotion.snappyCurve,
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? accent : Colors.transparent,
                borderRadius:
                    BorderRadius.circular(selected || multi ? 9 : 14),
                border: Border.all(
                    color: selected ? Colors.transparent : c.outline,
                    width: 2),
              ),
              child: AnimatedScale(
                duration: dur,
                curve: AppMotion.snappyCurve,
                scale: selected ? 1 : 0,
                child: Icon(Icons.check_rounded,
                    size: 17, color: pageOnAccent(c)),
              ),
            ),
          ),
        ]),
        if (chips.isNotEmpty || source != null) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final chip in chips) AdvancementFact(chip, accent: accent),
            if (source != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                    color: c.onSurface.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(99)),
                child: Text(source!,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: c.onSurfaceVariant)),
              ),
          ]),
        ],
      ]),
    );
    final body = Semantics(
      selected: selected,
      button: true,
      // A blocked card still answers a tap when it is given one (to say
      // why, or to ask the GM); it only looks set aside.
      child: Pressable(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        scale: .985,
        child: AnimatedOpacity(
            duration: AppMotion.of(context, AppMotion.medium),
            opacity: blocked ? .5 : 1,
            child: SelectPulse(on: selected, child: card)),
      ),
    );
    if (onInfo == null) return body;
    return AdvancementHold(
        accent: accent,
        radius: selected ? 18 : 26,
        onHold: onInfo!,
        child: body);
  }
}

/// The glyph of a class feature from its saved icon name.
String advancementFeatureGlyph(String? iconName) => switch (iconName) {
      'healing' => 'heart',
      'visibility' => 'eye',
      'flash_on' => 'bolt',
      'swords' => 'sword',
      'auto_fix_high' => 'magic',
      'health_and_safety' => 'shield',
      'auto_awesome' => 'spark',
      _ => 'star',
    };

/// The first sentence of a long description, for a card's short line.
String advancementGist(String text, {int max = 150}) {
  final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  final end = RegExp(r'[.!?…](\s|$)').firstMatch(t);
  final first = end == null ? t : t.substring(0, end.start + 1);
  return first.length <= max ? first : '${first.substring(0, max).trimRight()}…';
}

/// The «i» of a choice card (`.info6`).
class AdvancementInfoButton extends StatelessWidget {
  const AdvancementInfoButton({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Tooltip(
     message: Tr(context).t('Подробнее', 'Details'),
     child: Pressable(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      scale: .9,
      semanticLabel: Tr(context).t('Подробнее', 'Details'),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: c.onSurface.withValues(alpha: .07)),
        child: LineIcon('info', size: 17, color: c.onSurfaceVariant),
      ),
     ),
    );
  }
}

/// The confirmation: the new level is drawn around the hero — a ring
/// closes, the number rolls to the new level, a ring of light bursts —
/// then [onDone] runs. Driven by one controller, so it can be settled.
class AdvancementCeremony extends StatefulWidget {
  const AdvancementCeremony(
      {super.key,
      required this.accent,
      required this.from,
      required this.to,
      required this.title,
      required this.subtitle,
      required this.onDone});
  final Color accent;
  final int from, to;
  final String title, subtitle;
  final VoidCallback onDone;
  @override
  State<AdvancementCeremony> createState() => _AdvancementCeremonyState();
}

class _AdvancementCeremonyState extends State<AdvancementCeremony>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;
  bool _rolled = false, _struck = false;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduced = MediaQuery.disableAnimationsOf(context);
      _t.duration = Duration(milliseconds: reduced ? 600 : 2600);
      HapticFeedback.mediumImpact();
      _t.addListener(_beats);
      _t.forward().whenComplete(() {
        if (mounted) widget.onDone();
      });
    });
  }

  double get _ms => _t.value * (_t.duration?.inMilliseconds ?? 0);

  void _beats() {
    if (!_rolled && _ms >= 420) {
      _rolled = true;
      HapticFeedback.lightImpact();
      setState(() {});
    }
    if (!_struck && _ms >= 1000) {
      _struck = true;
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  double _span(double from, double length) =>
      ((_ms - from) / length).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = widget.accent;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final total = _t.duration?.inMilliseconds ?? 2600;
        final fadeIn = _span(0, 300);
        final fadeOut = 1 - ((_ms - (total - 320)) / 320).clamp(0.0, 1.0);
        final ring = AppMotion.standard.transform(_span(0, 1100));
        final burst = AppMotion.standard.transform(_span(900, 900));
        return Opacity(
          opacity: math.min(fadeIn, fadeOut),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ColoredBox(
              color: c.surface.withValues(alpha: .86),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox.square(
                    dimension: 260,
                    child: Stack(alignment: Alignment.center, children: [
                      if (burst > 0 && burst < 1)
                        Transform.scale(
                          scale: .8 + .7 * burst,
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: a.withValues(alpha: .8 * (1 - burst)),
                                    width: 2)),
                          ),
                        ),
                      SizedBox.square(
                        dimension: 200,
                        child: CustomPaint(painter: _CeremonyRing(a, c, ring)),
                      ),
                      RollingNumber(_rolled ? widget.to : widget.from,
                          style: TextStyle(
                              fontFamily: AppType.display,
                              fontSize: 84,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -4.2,
                              color: c.onSurface)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 16,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: c.onSurface)),
                  Text(widget.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, height: 1.3, color: c.onSurfaceVariant)),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CeremonyRing extends CustomPainter {
  _CeremonyRing(this.accent, this.c, this.t);
  final Color accent;
  final ColorScheme c;
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(5);
    canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = c.onSurface.withValues(alpha: .08));
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * t,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = accent);
  }

  @override
  bool shouldRepaint(_CeremonyRing old) => old.t != t || old.accent != accent;
}

/// The prototype's class accent for a class id, through the app's own map.
Color advancementAccent(BuildContext context, String classId) =>
    classAccent(context, classId);

/// The prototype's accents by index (a0…a5).
Color advancementTone(BuildContext context, int index) =>
    AppAccents.of(context).at(index);
