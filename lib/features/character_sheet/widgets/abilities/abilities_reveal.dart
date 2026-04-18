import 'dart:async';

import 'package:flutter/material.dart';

import 'abilities_shell_tokens.dart';

class AbilitiesReveal extends StatefulWidget {
  const AbilitiesReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.05),
  });

  final Widget child;
  final Duration delay;
  final Offset beginOffset;

  @override
  State<AbilitiesReveal> createState() => _AbilitiesRevealState();
}

class _AbilitiesRevealState extends State<AbilitiesReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _hasScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AbilitiesShellTokens.revealDuration,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: AbilitiesShellTokens.revealCurve,
    );
    _slide = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AbilitiesShellTokens.emphasisCurve,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _timer?.cancel();
      _controller.value = 1;
      return;
    }

    if (_hasScheduled || _controller.isCompleted) {
      return;
    }

    _hasScheduled = true;
    _timer = Timer(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
