import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import 'abilities_section_surface.dart';
import 'abilities_shell_tokens.dart';

class AbilitiesEmptyState extends StatelessWidget {
  const AbilitiesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return AbilitiesSectionSurface(
      quiet: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(
                AbilitiesShellTokens.sectionRadius,
              ),
            ),
            child: Icon(
              Icons.auto_stories_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noTraits,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.abilitiesEmptyBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
