import 'dart:math' as math;
import 'companion_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 180));
  Offset? _origin;
  bool get _reduced => MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  double get _shapeProgress => _reduced
      ? 0
      : const Interval(.24, 1, curve: Curves.easeInOutCubic)
          .transform(_press.value);
  void _release() {
    _origin = null;
    if (_press.isAnimating || _press.value != 0) _press.reverse();
  }

  void _tap() {
    if (!widget.enabled || widget.onTap == null) return;
    if (!_reduced) {
      _press
          .animateTo(.85,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutCubic)
          .then((_) {
        if (mounted) _press.reverse();
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
                animation: _press,
                child: widget.child,
                builder: (context, child) => Transform.scale(
                    scale: _reduced ? 1 : 1 - .035 * _shapeProgress,
                    child: CompanionMotionScope(
                        amount: math.max(CompanionMotionScope.of(context),
                            _reduced ? 0 : _shapeProgress),
                        child: child!))),
          ),
        ),
      );
}
