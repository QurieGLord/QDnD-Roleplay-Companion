import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

/// Transient presentation only. No state from this scope is written to a sheet.
class CompanionMotionScope extends InheritedWidget {
  const CompanionMotionScope(
      {super.key, required this.amount, required super.child});
  final double amount;
  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<CompanionMotionScope>()
          ?.amount ??
      0;
  @override
  bool updateShouldNotify(CompanionMotionScope old) => old.amount != amount;
}

/// A short arrival, re-armed only when the page actually changes. Scrolling
/// within a page never restarts it; hidden pages don't keep a ticker running.
class CompanionEntrance extends StatefulWidget {
  const CompanionEntrance({super.key, required this.child, this.active = true});
  final Widget child;
  final bool active;
  @override
  State<CompanionEntrance> createState() => _CompanionEntranceState();
}

class _CompanionEntranceState extends State<CompanionEntrance>
    with SingleTickerProviderStateMixin {
  late final _arrival = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420), value: 1);
  Timer? _delay;
  bool _initialized = false;
  void _start() {
    _delay?.cancel();
    if (!widget.active || MediaQuery.disableAnimationsOf(context)) {
      _arrival.value = 1;
      return;
    }
    _arrival.value = 0;
    _delay = Timer(const Duration(milliseconds: 100), () {
      if (mounted && widget.active) _arrival.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _delay?.cancel();
      _arrival.value = 1;
    } else if (!_initialized) {
      _initialized = true;
      _start();
    }
  }

  @override
  void didUpdateWidget(covariant CompanionEntrance old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _start();
  }

  @override
  void dispose() {
    _delay?.cancel();
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final inherited = CompanionMotionScope.of(context);
    return AnimatedBuilder(
        animation: _arrival,
        child: widget.child,
        builder: (context, child) {
          final remaining = reduced || !widget.active
              ? 0.0
              : 1 - AppMotion.standard.transform(_arrival.value);
          return CompanionMotionScope(
              amount: reduced ? 0 : math.max(inherited, remaining * .8),
              child: Transform.translate(
                  offset: Offset(0, remaining * 6),
                  child: Transform.scale(
                      scale: 1 - remaining * .008,
                      alignment: Alignment.topCenter,
                      child: child)));
        });
  }
}
