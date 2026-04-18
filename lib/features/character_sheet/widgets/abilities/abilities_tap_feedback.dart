import 'package:flutter/material.dart';

import 'abilities_shell_tokens.dart';

class AbilitiesTapFeedback extends StatefulWidget {
  const AbilitiesTapFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AbilitiesShellTokens.itemRadius),
    ),
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? color;

  @override
  State<AbilitiesTapFeedback> createState() => _AbilitiesTapFeedbackState();
}

class _AbilitiesTapFeedbackState extends State<AbilitiesTapFeedback> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return AnimatedScale(
      scale: disableAnimations || widget.onTap == null
          ? 1
          : (_pressed ? 0.985 : 1),
      duration: disableAnimations
          ? Duration.zero
          : AbilitiesShellTokens.pressDuration,
      curve: Curves.easeOutCubic,
      child: Material(
        color: widget.color ?? Colors.transparent,
        borderRadius: widget.borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: widget.borderRadius,
          onHighlightChanged: (value) {
            if (_pressed != value) {
              setState(() => _pressed = value);
            }
          },
          child: widget.child,
        ),
      ),
    );
  }
}
