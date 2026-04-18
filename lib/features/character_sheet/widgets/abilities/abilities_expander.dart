import 'package:flutter/material.dart';

import 'abilities_shell_tokens.dart';
import 'abilities_tap_feedback.dart';

class AbilitiesExpander extends StatefulWidget {
  const AbilitiesExpander({
    super.key,
    required this.header,
    required this.child,
    this.initiallyExpanded = false,
    this.onExpandedChanged,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AbilitiesShellTokens.itemRadius),
    ),
  });

  final Widget header;
  final Widget child;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpandedChanged;
  final BorderRadius borderRadius;

  @override
  State<AbilitiesExpander> createState() => _AbilitiesExpanderState();
}

class _AbilitiesExpanderState extends State<AbilitiesExpander> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant AbilitiesExpander oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpandedChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration =
        disableAnimations ? Duration.zero : AbilitiesShellTokens.expandDuration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AbilitiesTapFeedback(
          onTap: _toggle,
          borderRadius: widget.borderRadius,
          child: widget.header,
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: widget.child,
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: duration,
          sizeCurve: Curves.easeInOutCubic,
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }
}
