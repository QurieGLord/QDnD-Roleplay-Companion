import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../../core/models/character_feature.dart';
import '../abilities_expander.dart';
import '../abilities_feature_icon.dart';
import '../abilities_section_header.dart';
import '../abilities_section_surface.dart';
import '../abilities_shell_tokens.dart';
import '../abilities_tap_feedback.dart';

class AbilitiesPassiveTraitsSection extends StatelessWidget {
  const AbilitiesPassiveTraitsSection({
    super.key,
    required this.features,
    required this.locale,
    required this.onOpenDetails,
  });

  final List<CharacterFeature> features;
  final String locale;
  final ValueChanged<CharacterFeature> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final preview =
        features.take(3).map((feature) => feature.getName(locale)).join(' • ');
    final colorScheme = Theme.of(context).colorScheme;

    return AbilitiesSectionSurface(
      quiet: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AbilitiesSectionHeader(
            title: AppLocalizations.of(context)!.passiveTraits,
            icon: Icons.auto_stories,
            subtitle: preview,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(
                  AbilitiesShellTokens.pillRadius,
                ),
              ),
              child: Text(
                '${features.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AbilitiesExpander(
            initiallyExpanded: false,
            borderRadius: BorderRadius.circular(
              AbilitiesShellTokens.nestedRadius,
            ),
            header: Container(
              padding: AbilitiesShellTokens.nestedPadding,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(
                  AbilitiesShellTokens.nestedRadius,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  for (final feature in features) ...[
                    _PassiveFeatureTile(
                      feature: feature,
                      locale: locale,
                      onTap: () => onOpenDetails(feature),
                    ),
                    if (feature != features.last)
                      const SizedBox(
                          height: AbilitiesShellTokens.compactSpacing),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassiveFeatureTile extends StatelessWidget {
  const _PassiveFeatureTile({
    required this.feature,
    required this.locale,
    required this.onTap,
  });

  final CharacterFeature feature;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AbilitiesTapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AbilitiesShellTokens.itemRadius),
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                resolveAbilitiesFeatureIcon(feature.iconName),
                size: 18,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.getName(locale),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.getDescription(locale),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
