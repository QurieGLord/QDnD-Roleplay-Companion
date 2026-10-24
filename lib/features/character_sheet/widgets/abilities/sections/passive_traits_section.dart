import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../../core/models/character_feature.dart';
import '../abilities_feature_icon.dart';
import 'feature_row.dart';

/// Passive abilities fold under one title (prototype `#passives`): quiet
/// rows with a muted icon and the first line of each description.
class AbilitiesPassiveTraitsSection extends StatefulWidget {
  const AbilitiesPassiveTraitsSection(
      {super.key,
      required this.features,
      required this.locale,
      required this.onOpenDetails});
  final List<CharacterFeature> features;
  final String locale;
  final ValueChanged<CharacterFeature> onOpenDetails;
  @override
  State<AbilitiesPassiveTraitsSection> createState() => _AbilitiesPassiveTraitsSectionState();
}

class _AbilitiesPassiveTraitsSectionState extends State<AbilitiesPassiveTraitsSection> {
  bool _open = false;

  String _line(CharacterFeature f) {
    final text = f.getDescription(widget.locale).trim().split('\n').first;
    final dot = text.indexOf('. ');
    final first = dot > 0 && dot < 110 ? text.substring(0, dot + 1) : text;
    return first.length > 110 ? '${first.substring(0, 107)}…' : first;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _open = !_open);
        },
        scale: .99,
        semanticLabel: AppLocalizations.of(context)!.passiveTraits,
        child: SectionTitle(
          AppLocalizations.of(context)!.passiveTraits,
          count: '${widget.features.length}',
          trailing: AnimatedRotation(
            turns: _open ? .5 : 0,
            duration: AppMotion.of(context, const Duration(milliseconds: 260)),
            curve: AppMotion.snappyCurve,
            child: Icon(Icons.expand_more, size: 20, color: c.onSurfaceVariant),
          ),
        ),
      ),
      AnimatedSize(
        duration: AppMotion.of(context, const Duration(milliseconds: 380)),
        curve: AppMotion.standard,
        alignment: Alignment.topCenter,
        child: !_open
            ? const SizedBox(width: double.infinity)
            : FeatureList(children: [
                for (final f in widget.features)
                  FeatureRow(
                    icon: resolveAbilitiesFeatureIcon(f.iconName),
                    title: f.getName(widget.locale),
                    subtitle: _line(f),
                    muted: true,
                    trailing: const SizedBox.shrink(),
                    onTap: () => widget.onOpenDetails(f),
                  ),
              ]),
      ),
    ]);
  }
}
