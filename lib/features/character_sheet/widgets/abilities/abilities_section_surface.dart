import '../../../../core/ui/companion_surface.dart';
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
    return CompanionSurface(
        color: background,
        quiet: quiet,
        raised: emphasized,
        padding: padding,
        child: child);
  }
}
