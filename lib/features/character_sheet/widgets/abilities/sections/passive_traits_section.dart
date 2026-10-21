import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../../core/models/character_feature.dart';
import '../../../../../core/ui/companion_surface.dart';
import '../abilities_expander.dart';
import '../abilities_feature_icon.dart';

class AbilitiesPassiveTraitsSection extends StatelessWidget {
  const AbilitiesPassiveTraitsSection(
      {super.key,
      required this.features,
      required this.locale,
      required this.onOpenDetails});
  final List<CharacterFeature> features;
  final String locale;
  final ValueChanged<CharacterFeature> onOpenDetails;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Divider(height: 24, color: c.outlineVariant.withValues(alpha: .4)),
      AbilitiesExpander(
        header: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(AppLocalizations.of(context)!.passiveTraits,
                        style: t.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800, letterSpacing: -.5)),
                    const SizedBox(height: 5),
                    Text(
                        features
                            .take(2)
                            .map((f) => f.getName(locale))
                            .join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodySmall
                            ?.copyWith(color: c.onSurfaceVariant)),
                  ])),
              const SizedBox(width: 12),
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: c.surfaceContainerLow, shape: BoxShape.circle),
                  child: Text('${features.length}',
                      style: t.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more),
            ])),
        child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(children: [
              for (final feature in features) ...[
                CompanionSurface(
                    quiet: true,
                    padding: const EdgeInsets.all(14),
                    onTap: () => onOpenDetails(feature),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(resolveAbilitiesFeatureIcon(feature.iconName),
                              color: c.secondary, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(feature.getName(locale),
                                    style: t.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700)),
                              ])),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ])),
                const SizedBox(height: 8),
              ]
            ])),
      ),
    ]);
  }
}
