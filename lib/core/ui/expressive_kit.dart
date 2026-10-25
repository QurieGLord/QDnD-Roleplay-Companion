import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

/// Living building blocks shared by every screen (redesign wave 0).
/// Each one animates only on a real change and respects reduced motion.

/// A number whose digits roll in place, like a counter drum. Leading digits
/// that appear or disappear slide their width instead of popping.
class RollingNumber extends StatefulWidget {
  const RollingNumber(this.value, {super.key, required this.style, this.from});
  final int value;
  final TextStyle? style;

  /// Rolls up from this value on the first frame (a hero back on their feet
  /// counts up from zero); later changes roll from the shown value.
  final int? from;
  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> {
  late int _slots = _digits(widget.value).length;
  Timer? _prune;

  static String _digits(int v) => v.abs().toString();

  @override
  void didUpdateWidget(covariant RollingNumber old) {
    super.didUpdateWidget(old);
    final next = _digits(widget.value).length;
    if (next == _slots) return;
    // Keep the wider count while the extra column collapses, then prune it.
    _slots = math.max(_slots, next);
    _prune?.cancel();
    _prune = Timer(AppMotion.snappySettle, () {
      if (mounted) setState(() => _slots = _digits(widget.value).length);
    });
  }

  @override
  void dispose() {
    _prune?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context)
        .style
        .merge(widget.style)
        .copyWith(fontFeatures: AppType.tabular);
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
        text: TextSpan(text: '0', style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler)
      ..layout();
    final w = painter.width, h = painter.height;
    final digits = _digits(widget.value).padLeft(_slots, ' ');
    final start =
        widget.from == null ? null : _digits(widget.from!).padLeft(_slots, '0');
    final duration = AppMotion.of(context, AppMotion.snappySettle);
    return Semantics(
      label: '${widget.value}',
      child: ExcludeSemantics(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (widget.value < 0) Text('−', style: style),
          for (var i = 0; i < digits.length; i++)
            AnimatedContainer(
              duration: duration,
              curve: AppMotion.standard,
              width: digits[i] == ' ' ? 0 : w,
              height: h,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minWidth: w,
                  maxWidth: w,
                  maxHeight: h * 10,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: start == null || start.length != digits.length
                            ? null
                            : double.tryParse(start[i]) ?? 0,
                        end: digits[i] == ' ' ? 0 : double.parse(digits[i])),
                    duration: duration,
                    curve: AppMotion.snappyCurve,
                    builder: (context, d, column) => Transform.translate(
                        offset: Offset(0, -d * h), child: column),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (var n = 0; n < 10; n++)
                        SizedBox(
                            height: h,
                            child:
                                Text('$n', style: style, textScaler: scaler)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// A progress bar that leaves a short trail when it drops, so the size of a
/// hit stays readable for a beat. [value] and [extra] are fractions of the
/// track; an [extra] reserve (temporary HP) sits after the value.
class TrailBar extends StatefulWidget {
  const TrailBar(
      {super.key,
      required this.value,
      required this.color,
      required this.background,
      this.extra = 0,
      this.extraColor,
      this.height = 8});
  final double value, extra, height;
  final Color color, background;
  final Color? extraColor;
  @override
  State<TrailBar> createState() => _TrailBarState();
}

class _TrailBarState extends State<TrailBar> {
  late double _trail = widget.value;
  Timer? _hold;

  @override
  void didUpdateWidget(covariant TrailBar old) {
    super.didUpdateWidget(old);
    _hold?.cancel();
    if (widget.value >= _trail) {
      _trail = widget.value;
    } else {
      // The trail waits a moment before following the fill down.
      _hold = Timer(const Duration(milliseconds: 380), () {
        if (mounted) setState(() => _trail = widget.value);
      });
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final total = math.max(1.0, widget.value + widget.extra);
    Widget segment(double width, Color color, Duration d, Curve curve) =>
        TweenAnimationBuilder<double>(
          tween: Tween(end: width / total),
          duration: reduced ? Duration.zero : d,
          curve: curve,
          builder: (context, f, _) => FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: f.clamp(0.0, 1.0),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadii.pill))),
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: SizedBox(
        height: widget.height,
        child: Stack(fit: StackFit.expand, children: [
          ColoredBox(color: widget.background),
          if (widget.extra > 0)
            segment(
                widget.value + widget.extra,
                widget.extraColor ?? widget.color.withValues(alpha: .5),
                AppMotion.snappySettle,
                AppMotion.standard),
          segment(
              math.max(_trail, widget.value),
              Color.lerp(widget.color, widget.background, .45)!,
              AppMotion.gentleSettle,
              AppMotion.standard),
          segment(widget.value, widget.color, AppMotion.snappySettle,
              AppMotion.standard),
        ]),
      ),
    );
  }
}

/// A short, event-driven answer to a value change: a small sideways shake
/// when it drops, a fading outline glow when it rises.
class ImpactPulse extends StatefulWidget {
  const ImpactPulse(
      {super.key,
      required this.value,
      required this.child,
      required this.glowColor,
      this.borderRadius =
          const BorderRadius.all(Radius.circular(AppRadii.xl))});
  final num value;
  final Widget child;
  final Color glowColor;
  final BorderRadius borderRadius;
  @override
  State<ImpactPulse> createState() => _ImpactPulseState();
}

class _ImpactPulseState extends State<ImpactPulse>
    with TickerProviderStateMixin {
  late final _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  late final _glow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(covariant ImpactPulse old) {
    super.didUpdateWidget(old);
    if (MediaQuery.disableAnimationsOf(context) || old.value == widget.value) {
      return;
    }
    if (widget.value < old.value) {
      _shake.forward(from: 0);
    } else {
      _glow.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([_shake, _glow]),
        child: widget.child,
        builder: (context, child) {
          final t = _shake.value;
          // Decaying sway: -5, +4, -2 px.
          final dx =
              t == 0 || t == 1 ? 0.0 : math.sin(t * math.pi * 3) * 5 * (1 - t);
          return Transform.translate(
            offset: Offset(dx, 0),
            child: Stack(children: [
              child!,
              if (_glow.isAnimating)
                Positioned.fill(
                    child: IgnorePointer(
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                borderRadius: widget.borderRadius,
                                border: Border.all(
                                    width: 2,
                                    color: widget.glowColor.withValues(
                                        alpha: 1 -
                                            AppMotion.exit
                                                .transform(_glow.value))))))),
            ]),
          );
        },
      );
}

/// A chip whose shape carries its state: a capsule when off, a firmer
/// rounded square with a check when on.
class ExpressiveStateChip extends StatelessWidget {
  const ExpressiveStateChip(
      {super.key,
      required this.label,
      required this.selected,
      this.onTap,
      this.selectedColor,
      this.leading});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  // A state flip is a discrete step: one light click.
  VoidCallback? get tap => onTap == null
      ? null
      : () {
          HapticFeedback.selectionClick();
          onTap!();
        };
  final Color? selectedColor;
  final Widget? leading;

  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final d = AppMotion.of(context, AppMotion.snappySettle);
    // Stadium and rounded rectangle interpolate smoothly; an oversized
    // radius would be clamped and only snap in the last frames.
    final side = BorderSide(
        color: selected ? Colors.transparent : c.outline, width: 1.2);
    final OutlinedBorder shape = selected
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md), side: side)
        : StadiumBorder(side: side);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: tap,
      child: AnimatedContainer(
        duration: d,
        curve: AppMotion.standard,
        constraints: const BoxConstraints(minHeight: height),
        decoration: ShapeDecoration(
            shape: shape,
            color: selected
                ? selectedColor ?? c.tertiaryContainer
                : Colors.transparent),
        child: Material(
          type: MaterialType.transparency,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: tap,
            child: AnimatedPadding(
              duration: d,
              curve: AppMotion.standard,
              padding: EdgeInsetsDirectional.only(
                  start: selected ? 10 : 14, end: 14, top: 6, bottom: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedSize(
                  // A zero duration breaks AnimatedSize; reduced motion uses 1 ms.
                  duration:
                      d == Duration.zero ? const Duration(milliseconds: 1) : d,
                  curve: AppMotion.standard,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: Icon(Icons.check_rounded,
                              size: 16, color: c.onSurface))
                      : leading ?? const SizedBox.shrink(),
                ),
                // Large text wraps inside the chip instead of overflowing it.
                Flexible(
                  child: Text(label,
                      softWrap: true,
                      style: t.textTheme.labelLarge?.copyWith(
                          color: selected ? c.onSurface : c.onSurfaceVariant)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows or hides a block by animating its real height, so neighbours glide
/// instead of jumping. Hiding is quicker than showing.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.open, required this.child});
  final bool open;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    // AnimatedSize cannot run with a zero duration, so reduced motion skips it.
    if (MediaQuery.disableAnimationsOf(context)) {
      return open ? child : const SizedBox(width: double.infinity);
    }
    return AnimatedSize(
      duration: AppMotion.gentleSettle,
      reverseDuration: AppMotion.exitDuration,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: open ? 1 : 0,
        duration: open ? AppMotion.medium : AppMotion.exitDuration,
        curve: open ? AppMotion.enter : AppMotion.exit,
        child: open ? child : const SizedBox(width: double.infinity),
      ),
    );
  }
}

/// A wrap whose items glide to their new places when the row reflows, and
/// whose new items grow in instead of flashing (FLIP). Items need keys.
class FlipWrap extends StatefulWidget {
  const FlipWrap({
    super.key,
    required this.children,
    this.spacing = 8,
    this.runSpacing = 8,
  });
  final List<Widget> children;
  final double spacing, runSpacing;
  @override
  State<FlipWrap> createState() => _FlipWrapState();
}

class _FlipWrapState extends State<FlipWrap> {
  // Items present on the first frame are already in place.
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _settled = true);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final wrap = Wrap(
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      children: [
        for (final child in widget.children)
          _FlipItem(
              key: child.key == null ? null : ValueKey(('flip', child.key)),
              enter: _settled && !still,
              still: still,
              child: child),
      ],
    );
    if (still) return wrap;
    return AnimatedSize(
      duration: AppMotion.snappySettle,
      curve: AppMotion.snappyCurve,
      alignment: Alignment.topLeft,
      child: wrap,
    );
  }
}

class _FlipItem extends StatefulWidget {
  const _FlipItem(
      {super.key,
      required this.enter,
      required this.still,
      required this.child});
  final bool enter, still;
  final Widget child;
  @override
  State<_FlipItem> createState() => _FlipItemState();
}

class _FlipItemState extends State<_FlipItem> with TickerProviderStateMixin {
  late final _move =
      AnimationController(vsync: this, duration: AppMotion.snappySettle);
  late final _moveCurve =
      CurvedAnimation(parent: _move, curve: AppMotion.snappyCurve);
  late final _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: widget.enter ? 0 : 1);
  late final _enterCurve =
      CurvedAnimation(parent: _enter, curve: AppMotion.snappyCurve);

  @override
  void initState() {
    super.initState();
    _move.value = 1;
    if (widget.enter) _enter.forward();
  }

  @override
  void dispose() {
    _moveCurve.dispose();
    _enterCurve.dispose();
    _move.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Flip(
        progress: _moveCurve,
        restart: () {
          if (mounted) _move.forward(from: 0);
        },
        still: widget.still,
        child: FadeTransition(
          opacity: _enterCurve,
          child: ScaleTransition(
              scale: Tween<double>(begin: .82, end: 1).animate(_enterCurve),
              child: widget.child),
        ),
      );
}

class _Flip extends SingleChildRenderObjectWidget {
  const _Flip(
      {required this.progress,
      required this.restart,
      required this.still,
      super.child});
  final Animation<double> progress;
  final VoidCallback restart;
  final bool still;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFlip(progress, restart, still);
  @override
  void updateRenderObject(BuildContext context, _RenderFlip renderObject) {
    renderObject
      ..restart = restart
      ..still = still;
  }
}

/// Paints the item shifted from where it was towards where the wrap has
/// just placed it; the shift is decided in paint, so no frame shows the
/// item jumping first.
class _RenderFlip extends RenderProxyBox {
  _RenderFlip(this._progress, this.restart, this.still);
  final Animation<double> _progress;
  VoidCallback restart;
  bool still;
  Offset? _last;
  Offset _from = Offset.zero;
  bool _pending = false;

  Offset get _shift => _pending ? _from : _from * (1 - _progress.value);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final data = parentData;
    final place = data is BoxParentData ? data.offset : Offset.zero;
    if (!still && _last != null && (place - _last!).distanceSquared > .25) {
      _from = _last! - place + _shift;
      _pending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pending = false;
        restart();
      });
    }
    _last = place;
    final shift = still ? Offset.zero : _shift;
    super.paint(context, offset + shift);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final shift = still ? Offset.zero : _shift;
    return result.addWithPaintOffset(
        offset: shift,
        position: position,
        hitTest: (result, transformed) =>
            super.hitTestChildren(result, position: transformed));
  }
}

/// [AnimatedSize] that steps aside under reduced motion: a zero duration
/// would make it re-dirty its own layout.
class CalmSize extends StatelessWidget {
  const CalmSize({
    super.key,
    required this.duration,
    required this.child,
    this.curve = Curves.linear,
    this.alignment = Alignment.center,
  });
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) || duration == Duration.zero
          ? child
          : AnimatedSize(
              duration: duration, curve: curve, alignment: alignment, child: child);
}
