import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

/// A card that can grow into a sheet. While its sheet is open the card hides,
/// so the travelling surface is the only copy on screen.
class CardSheetOrigin extends StatefulWidget {
  const CardSheetOrigin({super.key, required this.child});
  final Widget child;
  @override
  State<CardSheetOrigin> createState() => CardSheetOriginState();
}

class CardSheetOriginState extends State<CardSheetOrigin> {
  final _box = GlobalKey();
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Object?>(
      valueListenable: CardSheetRoute.hiddenOrigin,
      builder: (context, hidden, child) =>
          Opacity(opacity: identical(hidden, this) ? 0 : 1, child: child),
      child: KeyedSubtree(key: _box, child: widget.child));

  Rect? get _rect {
    final box = _box.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// Opens [builder] as a sheet that grows out of the card wrapped by [origin].
/// [faceBuilder] redraws the card's face so it can fade into the content.
/// Without a laid-out origin it falls back to a regular modal sheet.
Future<T?> showCardSheet<T>(
  BuildContext context, {
  required GlobalKey<CardSheetOriginState> origin,
  required WidgetBuilder builder,
  required WidgetBuilder faceBuilder,
  Color? originColor,
  double originRadius = AppRadii.xl,
  BorderRadius? originBorderRadius,
}) {
  final state = origin.currentState, rect = state?._rect;
  final colors = Theme.of(context).colorScheme;
  if (state == null || rect == null) {
    return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: builder);
  }
  HapticFeedback.selectionClick();
  return Navigator.of(context).push(CardSheetRoute<T>(
    owner: state,
    origin: rect,
    builder: builder,
    faceBuilder: faceBuilder,
    originColor: originColor ?? colors.surface,
    sheetColor: colors.surfaceContainerLow,
    originRadius:
        originBorderRadius ?? BorderRadius.circular(originRadius),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  ));
}

class CardSheetRoute<T> extends PopupRoute<T> {
  CardSheetRoute({
    required this.owner,
    required this.origin,
    required this.builder,
    required this.faceBuilder,
    required this.originColor,
    required this.sheetColor,
    required this.originRadius,
    required this.barrierLabel,
  });

  /// The origin hidden while its sheet is on screen.
  static final hiddenOrigin = ValueNotifier<Object?>(null);

  final Object owner;
  final Rect origin;
  final WidgetBuilder builder, faceBuilder;
  final Color originColor, sheetColor;

  /// The card's own corners; the sheet leaves and lands in exactly this
  /// shape, so the card never changes form once it is back in place.
  final BorderRadius originRadius;
  @override
  final String barrierLabel;

  /// Vertical drag offset in pixels; it decays together with a close.
  late final AnimationController drag =
      AnimationController.unbounded(vsync: navigator!);
  double _closeVelocity = 0;

  bool get _reduced {
    final context = navigator?.context;
    return context != null && MediaQuery.disableAnimationsOf(context);
  }

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: .45);
  @override
  bool get barrierDismissible => true;
  @override
  Duration get transitionDuration => AppMotion.gentleSettle;
  @override
  Duration get reverseTransitionDuration => AppMotion.gentleSettle;

  @override
  TickerFuture didPush() {
    hiddenOrigin.value = owner;
    final future = super.didPush();
    if (_reduced) return future;
    // The card grows on a critically damped spring: it arrives without a hop.
    return controller!.animateWith(SpringSimulation(AppMotion.gentle, 0, 1, 0));
  }

  @override
  bool didPop(T? result) {
    final popped = super.didPop(result);
    if (!_reduced) {
      // A throw keeps the finger's speed on the way back into the card.
      controller!.animateBackWith(SpringSimulation(
          AppMotion.gentle, controller!.value, 0, _closeVelocity));
      drag.animateWith(SpringSimulation(AppMotion.gentle, drag.value, 0, 0));
    }
    return popped;
  }

  @override
  void dispose() {
    if (identical(hiddenOrigin.value, owner)) hiddenOrigin.value = null;
    drag.dispose();
    super.dispose();
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      _CardSheetBody(route: this, animation: animation);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      child;

  void _release(double velocity, double height) {
    if (velocity > 700 || drag.value > height * .33) {
      _closeVelocity = -math.max(velocity, 0) / height;
      navigator?.pop();
    } else {
      drag.animateWith(
          SpringSimulation(AppMotion.bouncy, drag.value, 0, velocity));
    }
  }
}

class _CardSheetBody extends StatelessWidget {
  const _CardSheetBody({required this.route, required this.animation});
  final CardSheetRoute route;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final target =
        Rect.fromLTWH(0, size.height * .2, size.width, size.height * .8);
    return AnimatedBuilder(
      animation: Listenable.merge([animation, route.drag]),
      builder: (context, _) {
        final p = animation.value, q = p.clamp(0.0, 1.0);
        final rect = Rect.lerp(route.origin, target, p)!
            .shift(Offset(0, route.drag.value));
        final radius = BorderRadius.lerp(
            route.originRadius,
            const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
            q)!;
        // Fade through: the card's face holds until the content takes over.
        final face = 1 - (q / .4).clamp(0.0, 1.0);
        final content = ((q - .3) / .5).clamp(0.0, 1.0);
        return Stack(children: [
          Positioned.fromRect(
            rect: rect,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(route.originColor, route.sheetColor, q),
                borderRadius: radius,
                // The card casts no shadow; the sheet's shadow grows with it.
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: .5 * q),
                      blurRadius: 30,
                      spreadRadius: -10,
                      offset: const Offset(0, -10))
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(children: [
                  if (face > 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      width: route.origin.width,
                      height: route.origin.height,
                      child: IgnorePointer(
                          child: Opacity(
                              opacity: face,
                              child: route.faceBuilder(context))),
                    ),
                  Positioned(
                    left: 0,
                    top: 0,
                    width: target.width,
                    height: target.height,
                    child: IgnorePointer(
                      ignoring: content < 1,
                      child: Opacity(
                        opacity: content,
                        child: Material(
                          type: MaterialType.transparency,
                          child: Column(children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: (d) {
                                final dy = d.primaryDelta ?? 0;
                                // Resistance above the resting position.
                                route.drag.value +=
                                    route.drag.value + dy < 0 ? dy * .3 : dy;
                              },
                              onVerticalDragEnd: (d) => route._release(
                                  d.primaryVelocity ?? 0, target.height),
                              child: Semantics(
                                button: true,
                                label: route.barrierLabel,
                                onTap: () => Navigator.of(context).pop(),
                                child: SizedBox(
                                  height: 30,
                                  width: double.infinity,
                                  child: Center(
                                      child: Container(
                                          width: 36,
                                          height: 4,
                                          decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadii.pill)))),
                                ),
                              ),
                            ),
                            Expanded(
                                child: MediaQuery.removePadding(
                                    context: context,
                                    removeTop: true,
                                    child: route.builder(context))),
                            SizedBox(height: media.padding.bottom),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]);
      },
    );
  }
}
