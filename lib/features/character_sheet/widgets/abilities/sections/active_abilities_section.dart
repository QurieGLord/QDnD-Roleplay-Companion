import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../../core/models/character_feature.dart';
import '../abilities_feature_icon.dart';
import 'feature_row.dart';

/// Active abilities outside the class panels (prototype «Умения»): a list
/// of rows with the action economy and cost; a usable one carries its own
/// use button, every row opens the full description.
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
    final c = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(l10n.activeAbilities, count: '${features.length}'),
      FeatureList(children: [
        for (final f in features)
          Builder(builder: (context) {
            final action = actionLabelBuilder(f.actionEconomy);
            final cost = resourceCostBuilder(f);
            final usable = shouldShowUseAction(f);
            return FeatureRow(
              key: ValueKey('ability-row-${f.id}'),
              icon: resolveAbilitiesFeatureIcon(f.iconName),
              title: f.getName(locale),
              subtitle: [if (action.isNotEmpty) action, if (cost != null) cost].join(' · '),
              accent: c.primary,
              onTap: () => onOpenDetails(f),
              trailing: usable
                  ? Pressable(
                      key: ValueKey('ability-use-${f.id}'),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onUseFeature(f);
                      },
                      scale: .92,
                      semanticLabel: cost != null ? l10n.useActionCost(cost) : l10n.useAction,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.primary.withValues(alpha: .16), borderRadius: BorderRadius.circular(999)),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(l10n.useAction,
                              style: TextStyle(fontFamily: AppType.body, fontSize: 13, fontWeight: FontWeight.w600, color: c.primary)),
                        ),
                      ),
                    )
                  : null,
            );
          }),
      ]),
    ]);
  }
}
