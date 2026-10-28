import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_palettes.dart';
import '../../../core/ui/companion_kit.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

/// What a step's forward button says and does. Inside the level-up screen
/// the step does not draw it: it hands it to the island dock over the page
/// (see [AdvancementDockScope]); a step shown alone keeps its own button.
class AdvancementDockAction {
  const AdvancementDockAction(
      {required this.label, this.hint, this.onPressed, this.busy = false});
  final String label;
  final String? hint;
  final VoidCallback? onPressed;
  final bool busy;

  bool same(AdvancementDockAction? other) =>
      other != null &&
      other.label == label &&
      other.hint == hint &&
      other.busy == busy &&
      (other.onPressed == null) == (onPressed == null);
}

/// Collects the forward buttons of the pages by their index.
class AdvancementDockController extends ChangeNotifier {
  final _actions = <int, AdvancementDockAction>{};
  AdvancementDockAction? operator [](int index) => _actions[index];

  void report(int index, AdvancementDockAction action) {
    final changed = !action.same(_actions[index]);
    // The callback is always the latest; only a visible change repaints.
    _actions[index] = action;
    if (changed) notifyListeners();
  }
}

/// Tells a step which page it is and where its button goes.
class AdvancementDockScope extends InheritedWidget {
  const AdvancementDockScope(
      {super.key,
      required this.controller,
      required this.index,
      required super.child});
  final AdvancementDockController controller;
  final int index;

  /// The room a step leaves at its end so the island never covers it.
  static const double room = 128;

  static AdvancementDockScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdvancementDockScope>();

  /// Bottom padding for a step's list: the island's room inside the
  /// level-up screen, nothing when the step stands alone.
  static double inset(BuildContext context) =>
      maybeOf(context) == null ? 0 : room;

  @override
  bool updateShouldNotify(AdvancementDockScope old) =>
      old.controller != controller || old.index != index;
}

/// A step's blocks. Inside the level-up screen they are a plain column in
/// the screen's one scroll, under the «Восхождение» head; a step shown
/// alone scrolls them itself. Use it as the step's first child of a
/// [Column] followed by its [AdvancementFooter].
class AdvancementStepList extends StatelessWidget {
  const AdvancementStepList(
      {super.key, required this.padding, required this.children});
  final EdgeInsetsGeometry padding;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    if (AdvancementDockScope.maybeOf(context) != null) {
      return Padding(
          padding: padding,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children));
    }
    return Expanded(child: ListView(padding: padding, children: children));
  }
}

class AdvancementFooter extends StatelessWidget {
  const AdvancementFooter(
      {super.key,
      required this.label,
      this.onPressed,
      this.hint,
      this.busy = false});
  final String label;
  final String? hint;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final scope = AdvancementDockScope.maybeOf(context);
    if (scope != null) {
      final action = AdvancementDockAction(
          label: label, hint: hint, onPressed: onPressed, busy: busy);
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => scope.controller.report(scope.index, action));
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hint != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(hint!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant))),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      backgroundColor: colors.secondaryContainer,
                      foregroundColor: colors.onSecondaryContainer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.lgPlus))),
                  onPressed: busy || onPressed == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          onPressed!();
                        },
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.arrow_forward_rounded, size: 20),
                  iconAlignment: IconAlignment.end,
                  label: Text(label, textAlign: TextAlign.center),
                ),
              ]),
        ));
  }
}

/// A step's own heading, as in the prototype: a large display line and a
/// quiet explanation under it.
class AdvancementHeading extends StatelessWidget {
  const AdvancementHeading(
      {super.key, required this.title, required this.subtitle, this.trailing});
  final String title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 28,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.84,
                        color: c.onSurface))),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ]),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 14, height: 1.45, color: c.onSurfaceVariant)),
          ],
        ]));
  }
}

/// The route tape of the prototype: a capsule per step; the current one
/// squares its corners and fills its number with the class accent, settled
/// ones carry a tick. Only earlier steps can be revisited.
class AdvancementRoute extends StatefulWidget {
  const AdvancementRoute(
      {super.key,
      required this.labels,
      required this.current,
      required this.onBackTo,
      this.enabled = true,
      this.accent,
      this.firstNumber = 1,
      this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 6)});
  final List<String> labels;

  /// The number of the first capsule: 0 when it is the class step that
  /// stands before the level's own steps.
  final int firstNumber;
  final int current;
  final ValueChanged<int> onBackTo;
  final bool enabled;
  final Color? accent;
  final EdgeInsets padding;
  @override
  State<AdvancementRoute> createState() => _AdvancementRouteState();
}

class _AdvancementRouteState extends State<AdvancementRoute> {
  final List<GlobalKey> _keys = [];
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.current >= _keys.length) return;
      final target = _keys[widget.current].currentContext;
      final box = target?.findRenderObject();
      if (target == null || box == null) return;
      // Only the tape moves, never the page around it.
      Scrollable.of(target).position.ensureVisible(box,
          alignment: .5,
          duration: AppMotion.of(context, const Duration(milliseconds: 320)),
          curve: AppMotion.standard);
    });
  }

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(covariant AdvancementRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current ||
        oldWidget.labels.length != widget.labels.length) {
      _reveal();
    }
  }

  @override
  Widget build(BuildContext context) {
    while (_keys.length < widget.labels.length) {
      _keys.add(GlobalKey());
    }
    final c = Theme.of(context).colorScheme;
    final accent = widget.accent ?? c.primary;
    final done = AppAccents.of(context).at(3);
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        child: Row(children: [
          for (var i = 0; i < widget.labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Builder(builder: (context) {
              final now = i == widget.current, past = i < widget.current;
              final open = widget.enabled && past;
              return Semantics(
                  key: _keys[i],
                  selected: now,
                  button: open,
                  excludeSemantics: true,
                  onTap: open ? () => widget.onBackTo(i) : null,
                  label: '${i + widget.firstNumber}. ${widget.labels[i]}',
                  child: Pressable(
                    key: ValueKey('advancement-route-$i'),
                    onTap: open
                        ? () {
                            HapticFeedback.selectionClick();
                            widget.onBackTo(i);
                          }
                        : null,
                    scale: .95,
                    child: AnimatedContainer(
                      duration: dur,
                      curve: AppMotion.snappyCurve,
                      height: 38,
                      padding: const EdgeInsets.fromLTRB(6, 0, 14, 0),
                      decoration: BoxDecoration(
                          color: now
                              ? Color.alphaBlend(accent.withValues(alpha: .16),
                                  c.surfaceContainerLow)
                              : c.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(now ? 12 : 19)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        AnimatedContainer(
                          duration: dur,
                          curve: AppMotion.snappyCurve,
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: now
                                  ? accent
                                  : past
                                      ? Color.alphaBlend(
                                          done.withValues(alpha: .26),
                                          c.surfaceContainer)
                                      : c.onSurface.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(now ? 8 : 13)),
                          child: AnimatedSwitcher(
                            duration: AppMotion.of(context, AppMotion.medium),
                            transitionBuilder: (child, a) =>
                                ScaleTransition(scale: a, child: child),
                            child: past
                                ? Icon(Icons.check_rounded,
                                    key: const ValueKey('done'),
                                    size: 16,
                                    color: done)
                                : Text('${i + widget.firstNumber}',
                                    key: const ValueKey('n'),
                                    style: TextStyle(
                                        fontFamily: AppType.display,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: now
                                            ? Color.alphaBlend(
                                                Colors.black
                                                    .withValues(alpha: .12),
                                                c.surface)
                                            : c.onSurfaceVariant)),
                          ),
                        ),
                        const SizedBox(width: 7),
                        AnimatedDefaultTextStyle(
                          duration: AppMotion.of(context, AppMotion.medium),
                          style: TextStyle(
                              fontFamily: AppType.body,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: now || past
                                  ? c.onSurface
                                  : c.onSurfaceVariant),
                          child: Text(widget.labels[i]),
                        ),
                      ]),
                    ),
                  ));
            }),
          ],
        ]));
  }
}
