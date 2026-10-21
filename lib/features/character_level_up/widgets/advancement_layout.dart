import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/ui/companion_surface.dart';

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
                          borderRadius: BorderRadius.circular(22))),
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

class AdvancementHeading extends StatelessWidget {
  const AdvancementHeading(
      {super.key, required this.title, required this.subtitle, this.trailing});
  final String title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.7,
                      height: 1.15))),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]),
        const SizedBox(height: 6),
        Text(subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]));
}

/// An adaptive route: all labels remain readable at large text sizes. Only
/// earlier steps can be revisited; unavailable future choices cannot be skipped.
class AdvancementRoute extends StatefulWidget {
  const AdvancementRoute(
      {super.key,
      required this.labels,
      required this.current,
      required this.onBackTo,
      this.enabled = true});
  final List<String> labels;
  final int current;
  final ValueChanged<int> onBackTo;
  final bool enabled;
  @override
  State<AdvancementRoute> createState() => _AdvancementRouteState();
}

class _AdvancementRouteState extends State<AdvancementRoute> {
  final List<GlobalKey> _keys = [];
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.current >= _keys.length) return;
      final target = _keys[widget.current].currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target,
            alignment: .5,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic);
      }
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
    if (oldWidget.current != widget.current) _reveal();
  }

  @override
  Widget build(BuildContext context) {
    while (_keys.length < widget.labels.length) {
      _keys.add(GlobalKey());
    }
    final colors = Theme.of(context).colorScheme;
    return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent
            ], stops: [
              0,
              .05,
              .95,
              1
            ]).createShader(bounds),
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Row(children: [
              for (var i = 0; i < widget.labels.length; i++) ...[
                if (i > 0)
                  Container(
                      width: 10,
                      height: 2,
                      color: i <= widget.current
                          ? colors.primary.withValues(alpha: .45)
                          : colors.outlineVariant),
                Semantics(
                    selected: i == widget.current,
                    excludeSemantics: true,
                    onTap: widget.enabled && i < widget.current
                        ? () => widget.onBackTo(i)
                        : null,
                    label: '${i + 1}. ${widget.labels[i]}',
                    child: Material(
                      key: _keys[i],
                      color: i == widget.current
                          ? colors.secondaryContainer
                          : colors.surfaceContainerLow,
                      shape: CompanionShape(
                          contour: i == widget.current
                              ? CompanionContour.facet
                              : CompanionContour.soft),
                      animationDuration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      child: InkWell(
                        key: ValueKey('advancement-route-$i'),
                        borderRadius: BorderRadius.circular(24),
                        onTap: widget.enabled && i < widget.current
                            ? () => widget.onBackTo(i)
                            : null,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: Center(
                                      child: i < widget.current
                                          ? Icon(Icons.check_rounded,
                                              size: 16, color: colors.primary)
                                          : Text('${i + 1}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
                                                      color: colors
                                                          .onSurfaceVariant)))),
                              const SizedBox(width: 6),
                              Text(widget.labels[i],
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                            ])),
                      ),
                    )),
              ],
            ])));
  }
}
