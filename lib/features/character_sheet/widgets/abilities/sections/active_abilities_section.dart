import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../../core/models/character_feature.dart';
import '../abilities_feature_icon.dart';
import '../abilities_section_header.dart';
import '../abilities_section_surface.dart';
import '../abilities_shell_tokens.dart';
import '../abilities_tap_feedback.dart';

class AbilitiesActiveAbilitiesSection extends StatelessWidget {
  const AbilitiesActiveAbilitiesSection({
    super.key,
    required this.features,
    required this.locale,
    required this.actionLabelBuilder,
    required this.resourceCostBuilder,
    required this.shouldShowUseAction,
    required this.onOpenDetails,
    required this.onUseFeature,
  });

  final List<CharacterFeature> features;
  final String locale;
  final String Function(String? actionEconomy) actionLabelBuilder;
  final String? Function(CharacterFeature feature) resourceCostBuilder;
  final bool Function(CharacterFeature feature) shouldShowUseAction;
  final ValueChanged<CharacterFeature> onOpenDetails;
  final ValueChanged<CharacterFeature> onUseFeature;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AbilitiesSectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AbilitiesSectionHeader(
            title: AppLocalizations.of(context)!.activeAbilities,
            icon: Icons.bolt,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(
                  AbilitiesShellTokens.pillRadius,
                ),
              ),
              child: Text(
                '${features.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final feature in features) ...[
            _ActiveFeatureCard(
              feature: feature,
              locale: locale,
              actionLabel: actionLabelBuilder(feature.actionEconomy),
              resourceCost: resourceCostBuilder(feature),
              shouldShowUseAction: shouldShowUseAction(feature),
              onOpenDetails: () => onOpenDetails(feature),
              onUseFeature: () => onUseFeature(feature),
            ),
            if (feature != features.last)
              const SizedBox(height: AbilitiesShellTokens.itemSpacing),
          ],
        ],
      ),
    );
  }
}

class _ActiveFeatureCard extends StatelessWidget {
  const _ActiveFeatureCard({
    required this.feature,
    required this.locale,
    required this.actionLabel,
    required this.resourceCost,
    required this.shouldShowUseAction,
    required this.onOpenDetails,
    required this.onUseFeature,
  });

  final CharacterFeature feature;
  final String locale;
  final String actionLabel;
  final String? resourceCost;
  final bool shouldShowUseAction;
  final VoidCallback onOpenDetails;
  final VoidCallback onUseFeature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return AbilitiesTapFeedback(
      onTap: onOpenDetails,
      borderRadius: BorderRadius.circular(AbilitiesShellTokens.nestedRadius),
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: AbilitiesShellTokens.nestedPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    resolveAbilitiesFeatureIcon(feature.iconName),
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (actionLabel.isNotEmpty)
                            _InfoPill(
                              label: actionLabel,
                              background: colorScheme.primaryContainer,
                              foreground: colorScheme.onPrimaryContainer,
                            ),
                          if (resourceCost != null)
                            _InfoPill(
                              label: resourceCost!,
                              background: colorScheme.surfaceContainerHighest,
                              foreground: colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              feature.getDescription(locale),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (shouldShowUseAction) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    onUseFeature();
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    resourceCost != null
                        ? l10n.useActionCost(resourceCost!)
                        : l10n.useAction,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AbilitiesShellTokens.pillRadius),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
