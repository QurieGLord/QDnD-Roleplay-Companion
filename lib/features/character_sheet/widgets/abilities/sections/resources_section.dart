import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../../core/models/character_feature.dart';
import '../abilities_feature_icon.dart';
import 'feature_row.dart';

/// Limited resources outside the class panels: a list of rows (name and
/// recovery, the full description behind a tap) each with its counter.
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
    final l10n = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(l10n.resources, count: '${features.length}'),
      FeatureList(children: [
        for (final f in features)
          if (f.resourcePool case final pool?)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FeatureRow(
                key: ValueKey('resource-row-${f.id}'),
                icon: resolveAbilitiesFeatureIcon(f.iconName),
                title: f.getName(locale),
                subtitle: _recovery(l10n, pool),
                accent: pool.isEmpty ? c.error : c.primary,
                onTap: () => onOpenDetails(f),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: counterBuilder(f),
              ),
            ]),
      ]),
    ]);
  }

  String _recovery(AppLocalizations l10n, ResourcePool pool) => switch (pool.recoveryType) {
        RecoveryType.shortRest => l10n.shortRest,
        RecoveryType.longRest => l10n.longRest,
        RecoveryType.dawn => l10n.recoveryDawn,
        RecoveryType.perTurn => l10n.recoveryEachTurn,
        RecoveryType.recharge => l10n.recoveryRecharge,
        RecoveryType.manual => l10n.recoveryManual,
      };
}
