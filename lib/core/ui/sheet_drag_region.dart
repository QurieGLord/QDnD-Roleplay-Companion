import 'package:flutter/material.dart';

/// A broad header target. Closing never commits a draft, and is blocked during saves.
class SheetDragRegion extends StatefulWidget {
  const SheetDragRegion({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<SheetDragRegion> createState() => _SheetDragRegionState();
}

class _SheetDragRegionState extends State<SheetDragRegion> {
  double _distance = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: widget.enabled ? (_) => _distance = 0 : null,
        onVerticalDragUpdate:
            widget.enabled ? (event) => _distance += event.delta.dy : null,
        onVerticalDragEnd: widget.enabled
            ? (event) {
                if (_distance > 32 ||
                    (_distance > 8 && (event.primaryVelocity ?? 0) > 160)) {
                  Navigator.maybePop(context);
                }
              }
            : null,
        child: widget.child,
      );
}

/// Pulling down at the top dismisses; scrolling within a long form stays scrollable.
class SheetScrollDismiss extends StatefulWidget {
  const SheetScrollDismiss(
      {super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<SheetScrollDismiss> createState() => _SheetScrollDismissState();
}

class _SheetScrollDismissState extends State<SheetScrollDismiss> {
  double _pull = 0;
  bool _closing = false;
  bool _notification(ScrollNotification event) {
    if (!widget.enabled ||
        _closing ||
        event.depth != 0 ||
        event.metrics.axis != Axis.vertical) {
      return false;
    }
    if (event is ScrollStartNotification) _pull = 0;
    if (event is OverscrollNotification &&
        event.dragDetails != null &&
        event.overscroll < 0) {
      _pull -= event.overscroll;
    }
    if (event is ScrollUpdateNotification && event.dragDetails != null) {
      final beyond = event.metrics.minScrollExtent - event.metrics.pixels;
      if (beyond > _pull) {
        _pull = beyond;
      } else if (event.metrics.pixels > event.metrics.minScrollExtent + 1) {
        _pull = 0;
      }
    }
    if (_pull > 48) {
      _closing = true;
      Navigator.maybePop(context).then((closed) {
        if (mounted && !closed) _closing = false;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
          onNotification: _notification, child: widget.child);
}

/// Shared chrome for ordinary pickers/action forms. Editing/saving sheets can use
/// the same regions with an enabled flag to protect an in-flight write.
Future<T?> showResponsiveSheet<T>(
        {required BuildContext context,
        required WidgetBuilder builder,
        bool isScrollControlled = false,
        bool showDragHandle = true,
        bool useSafeArea = false,
        AnimationStyle? sheetAnimationStyle}) =>
    showModalBottomSheet<T>(
        context: context,
        requestFocus: false,
        isScrollControlled: isScrollControlled,
        showDragHandle: showDragHandle,
        useSafeArea: useSafeArea,
        sheetAnimationStyle: sheetAnimationStyle,
        builder: (context) =>
            SheetScrollDismiss(child: SheetSafeArea(child: builder(context))));

/// A modal sheet keeps its last buttons above the gesture bar (Flutter's
/// sheets only guard the top) and rises with the keyboard, so a text field
/// at the bottom stays in view while typing.
class SheetSafeArea extends StatelessWidget {
  const SheetSafeArea({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboard),
      // The keyboard is consumed here, so content that lifts itself above
      // it does not rise twice.
      child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: SafeArea(top: false, left: false, right: false, child: child)),
    );
  }
}

/// Lifts its child by the keyboard. Only this small widget depends on the
/// keyboard's height, so while the keyboard slides the content inside is
/// laid out again but never rebuilt.
class KeyboardPadding extends StatelessWidget {
  const KeyboardPadding({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child);
}
