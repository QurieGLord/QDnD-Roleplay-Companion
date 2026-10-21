import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A short reveal when an entry actually reaches its viewport, once per visit.
/// Geometry is unchanged; the scroll position is never part of the animation.
class JournalAppear extends StatefulWidget {
  const JournalAppear(
      {super.key,
      required this.child,
      required this.seen,
      required this.onSeen});
  final Widget child;
  final bool seen;
  final VoidCallback onSeen;
  @override
  State<JournalAppear> createState() => _JournalAppearState();
}

class _JournalAppearState extends State<JournalAppear>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.seen ? 1 : 0);
  late final _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  ScrollPosition? _position;
  bool _scheduled = false;
  late bool _revealed = widget.seen;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_revealed) return;
    final position = Scrollable.maybeOf(context)?.position;
    if (_position != position) {
      _position?.removeListener(_schedule);
      _position = position;
      _position?.addListener(_schedule);
    }
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _revealed || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _revealed) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      final viewportBox = viewport is RenderBox ? viewport as RenderBox : null;
      final bounds = box.localToGlobal(Offset.zero) & box.size;
      final visible = viewportBox != null && viewportBox.hasSize
          ? viewportBox.localToGlobal(Offset.zero) & viewportBox.size
          : Offset.zero & MediaQuery.sizeOf(context);
      if (!bounds.overlaps(visible)) return;
      _revealed = true;
      _position?.removeListener(_schedule);
      _position = null;
      widget.onSeen();
      if (widget.seen || MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _position?.removeListener(_schedule);
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _curve,
      child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, .025), end: Offset.zero)
                  .animate(_curve),
          child: widget.child));
}
