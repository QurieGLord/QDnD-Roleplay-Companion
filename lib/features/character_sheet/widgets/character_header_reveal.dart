import 'package:flutter/material.dart';

/// The card's halo may continue below its layout bounds into the transparent
/// top of the navigation. A normal SizeTransition clips that blur to a line.
class CharacterHeaderReveal extends AnimatedWidget {
  const CharacterHeaderReveal({
    super.key,
    required Animation<double> sizeFactor,
    required this.child,
  }) : super(listenable: sizeFactor);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final factor = (listenable as Animation<double>).value.clamp(0.0, 1.0);
    return ClipRect(
      clipper: _HaloClipper(40 * factor),
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: factor,
        child: child,
      ),
    );
  }
}

class _HaloClipper extends CustomClipper<Rect> {
  const _HaloClipper(this.halo);
  final double halo;

  @override
  Rect getClip(Size size) => size.height == 0
      ? Rect.zero
      : Rect.fromLTRB(-halo, -halo, size.width + halo, size.height + halo);

  @override
  bool shouldReclip(_HaloClipper oldClipper) => halo != oldClipper.halo;
}
