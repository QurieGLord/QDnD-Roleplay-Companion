import 'dart:async';
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
    // The arrival moves the page as one layer. It does not feed the shared
    // motion scope: that would rebuild and reshape every surface on the page
    // on each frame of the entrance.
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
        animation: _arrival,
        child: RepaintBoundary(child: widget.child),
        builder: (context, child) {
          final remaining = reduced || !widget.active
              ? 0.0
              : 1 - AppMotion.standard.transform(_arrival.value);
          // Same wrappers at rest: changing the tree shape would remount
          // the page and lose its state.
          return Transform.translate(
              offset: Offset(0, remaining * 6),
              child: Transform.scale(
                  scale: 1 - remaining * .008,
                  alignment: Alignment.topCenter,
                  child: child));
        });
  }
}

/// A page in a horizontal strip whose content rises into place as the page
/// slides in. It is driven by the strip's position, never by a timer, so it
/// stays in step with a drag, reverses with it and is settled on landing.
class PageArrival extends StatelessWidget {
  const PageArrival(
      {super.key,
      required this.controller,
      required this.index,
      required this.child});
  final PageController controller;
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
        animation: controller,
        child: RepaintBoundary(child: child),
        builder: (context, child) {
          final page =
              controller.hasClients && controller.position.hasContentDimensions
                  ? controller.page ?? index.toDouble()
                  : index.toDouble();
          final d = AppMotion.standard
              .transform((page - index).abs().clamp(0.0, 1.0));
          // A pure offset moves the cached layer; scaling would make the GPU
          // re-rasterize all text on every frame of the slide.
          return Transform.translate(offset: Offset(0, 16 * d), child: child);
        });
  }
}
