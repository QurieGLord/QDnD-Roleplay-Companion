import 'dart:math' as math;
import 'companion_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

/// A quiet shortcut: a gradual squeeze previews the hold, then a haptic
/// confirms it. A drag or cancelled hold never performs an edit or a spend.
class ExpressiveHoldSurface extends StatefulWidget {
  const ExpressiveHoldSurface(
      {super.key,
      required this.child,
      this.onHold,
      this.onTap,
      this.semanticLabel,
      this.hint,
      this.enabled = true,
      this.excludeChildSemantics = false});
  final Widget child;
  final VoidCallback? onHold;
  final VoidCallback? onTap;
  final String? semanticLabel, hint;
  final bool enabled, excludeChildSemantics;
  @override
  State<ExpressiveHoldSurface> createState() => _ExpressiveHoldSurfaceState();
}

class _ExpressiveHoldSurfaceState extends State<ExpressiveHoldSurface>
    with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 180));
  // Release travel. Unbounded so the spring may overshoot past rest.
  late final AnimationController _settle =
      AnimationController.unbounded(vsync: this);
  Offset? _origin;
  bool get _reduced => MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  double get _shapeProgress => _reduced
      ? 0
      : const Interval(.24, 1, curve: Curves.easeInOutCubic)
          .transform(_press.value);
  double get _squeeze => _shapeProgress + _settle.value;

  void _release() {
    _origin = null;
    // A hold may replace this surface before the finger lifts.
    if (!mounted) return;
    final from = _squeeze;
    _press.stop();
    _press.value = 0;
    if (_reduced || from <= 0) {
      _settle.value = 0;
      return;
    }
    // The surface settles back from wherever the finger left it, no hop.
    _settle.value = from;
    _settle.animateWith(SpringSimulation(AppMotion.snappy, from, 0, 0));
  }

  void _tap() {
    if (!widget.enabled || widget.onTap == null) return;
    if (!_reduced) {
      _press
          .animateTo(.6,
              duration: const Duration(milliseconds: 140),
              curve: AppMotion.standard)
          .then((_) {
        if (mounted) _release();
      });
    }
    widget.onTap!();
  }

  void _hold() {
    if (!widget.enabled || widget.onHold == null) return;
    _release();
    HapticFeedback.mediumImpact();
    widget.onHold!();
  }

  @override
  void dispose() {
    _press.dispose();
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        excludeSemantics: widget.excludeChildSemantics,
        label: widget.semanticLabel,
        hint: widget.hint,
        button: widget.onTap != null || widget.onHold != null,
        onTap: widget.enabled && widget.onTap != null ? _tap : null,
        onLongPress: widget.enabled && widget.onHold != null ? _hold : null,
        child: Listener(
          onPointerDown: widget.enabled
              ? (event) {
                  _origin = event.position;
                  if (!_reduced &&
                      (widget.onHold != null || widget.onTap != null)) {
                    _settle.stop();
                    _settle.value = 0;
                    _press.forward(from: 0);
                  }
                }
              : null,
          onPointerMove: (event) {
            if (_origin != null && (event.position - _origin!).distance > 8) {
              _release();
            }
          },
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapCancel:
                widget.enabled && widget.onTap != null ? _release : null,
            onTapUp: widget.enabled && widget.onTap != null
                ? (_) => _release()
                : null,
            onTap: widget.enabled && widget.onTap != null ? _tap : null,
            onLongPressStart:
                widget.enabled && widget.onHold != null ? (_) => _hold() : null,
            onLongPressCancel:
                widget.enabled && widget.onHold != null ? _release : null,
            onLongPressEnd: widget.enabled && widget.onHold != null
                ? (_) => _release()
                : null,
            child: AnimatedBuilder(
                animation: Listenable.merge([_press, _settle]),
                child: widget.child,
                builder: (context, child) => Transform.scale(
                    scale: _reduced ? 1 : 1 - .035 * _squeeze,
                    child: CompanionMotionScope(
                        amount: math.max(CompanionMotionScope.of(context),
                            _reduced ? 0 : _squeeze.clamp(0.0, 1.0)),
                        child: child!))),
          ),
        ),
      );
}
