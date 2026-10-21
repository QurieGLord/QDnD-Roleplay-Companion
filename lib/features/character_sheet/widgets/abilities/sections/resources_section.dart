import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../../core/models/character_feature.dart';
import '../abilities_feature_icon.dart';
import '../abilities_section_header.dart';
import '../abilities_section_surface.dart';
import '../abilities_shell_tokens.dart';
import '../abilities_tap_feedback.dart';

class AbilitiesResourcesSection extends StatelessWidget {
  const AbilitiesResourcesSection({
    super.key,
    required this.features,
    required this.locale,
    required this.onOpenDetails,
    required this.counterBuilder,
  });

  final List<CharacterFeature> features;
  final String locale;
  final ValueChanged<CharacterFeature> onOpenDetails;
  final Widget Function(CharacterFeature) counterBuilder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AbilitiesSectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AbilitiesSectionHeader(
            title: AppLocalizations.of(context)!.resources,
            icon: Icons.tune,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(
                  AbilitiesShellTokens.pillRadius,
                ),
              ),
              child: Text(
                '${features.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final feature in features) ...[
            _ResourceFeatureCard(
              feature: feature,
              locale: locale,
              onOpenDetails: () => onOpenDetails(feature),
              counter: counterBuilder(feature),
            ),
            if (feature != features.last)
              const SizedBox(height: AbilitiesShellTokens.itemSpacing),
          ],
        ],
      ),
    );
  }
}

class _ResourceFeatureCard extends StatelessWidget {
  const _ResourceFeatureCard({
    required this.feature,
    required this.locale,
    required this.onOpenDetails,
    required this.counter,
  });

  final CharacterFeature feature;
  final String locale;
  final VoidCallback onOpenDetails;
  final Widget counter;

  @override
  Widget build(BuildContext context) {
    final pool = feature.resourcePool;
    if (pool == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final accent = pool.isEmpty ? colorScheme.error : colorScheme.primary;
    final usePips = pool.maxUses > 0 && pool.maxUses <= 6;

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
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    resolveAbilitiesFeatureIcon(feature.iconName),
                    color: colorScheme.onPrimaryContainer,
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
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _RecoveryChip(label: _recoveryLabel(l10n, pool)),
                          _CountChip(
                            currentUses: pool.currentUses,
                            maxUses: pool.maxUses,
                            accent: accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            usePips
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(pool.maxUses, (index) {
                      final isFilled = index < pool.currentUses;
                      return AnimatedContainer(
                        duration: AbilitiesShellTokens.expandDuration,
                        curve: Curves.easeOutCubic,
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isFilled
                              ? accent
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color:
                                isFilled ? accent : colorScheme.outlineVariant,
                          ),
                        ),
                      );
                    }),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: pool.maxUses == 0
                                ? 0
                                : (pool.currentUses / pool.maxUses).clamp(
                                    0.0,
                                    1.0,
                                  ),
                          ),
                          duration: AbilitiesShellTokens.expandDuration,
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 12,
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              color: accent,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${pool.currentUses}/${pool.maxUses}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 14),
            Text(
              feature.getDescription(locale),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            counter,
          ],
        ),
      ),
    );
  }

  String _recoveryLabel(AppLocalizations l10n, ResourcePool pool) {
    switch (pool.recoveryType) {
      case RecoveryType.shortRest:
        return l10n.shortRest;
      case RecoveryType.longRest:
        return l10n.longRest;
      case RecoveryType.dawn:
        return l10n.recoveryDawn;
      case RecoveryType.perTurn:
        return l10n.recoveryEachTurn;
      case RecoveryType.recharge:
        return l10n.recoveryRecharge;
      case RecoveryType.manual:
        return l10n.recoveryManual;
    }
  }
}

class _RecoveryChip extends StatelessWidget {
  const _RecoveryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AbilitiesShellTokens.pillRadius),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.currentUses,
    required this.maxUses,
    required this.accent,
  });

  final int currentUses;
  final int maxUses;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AbilitiesShellTokens.pillRadius),
      ),
      child: AnimatedSwitcher(
        duration: AbilitiesShellTokens.expandDuration,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: Text(
          '$currentUses/$maxUses',
          key: ValueKey<String>('$currentUses/$maxUses'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
