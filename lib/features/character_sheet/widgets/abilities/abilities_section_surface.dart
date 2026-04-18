import 'package:flutter/material.dart';

import 'abilities_shell_tokens.dart';

class AbilitiesSectionSurface extends StatelessWidget {
  const AbilitiesSectionSurface({
    super.key,
    required this.child,
    this.padding = AbilitiesShellTokens.sectionPadding,
    this.emphasized = false,
    this.quiet = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool emphasized;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final background = emphasized
        ? colorScheme.surfaceContainer
        : (quiet
            ? colorScheme.surfaceContainerLow
            : colorScheme.surfaceContainerLow);
    final borderColor = quiet
        ? colorScheme.outlineVariant.withValues(alpha: 0.45)
        : colorScheme.outlineVariant.withValues(alpha: 0.65);

    return Material(
      color: background,
      elevation: quiet ? 0 : 1,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
      surfaceTintColor: emphasized ? colorScheme.primary : colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(AbilitiesShellTokens.sectionRadius),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
