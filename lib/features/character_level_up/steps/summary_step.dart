import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/character_feature.dart';

class SummaryStep extends StatelessWidget {
  final Character character;
  final int nextLevel;
  final int hpIncrease;
  final List<CharacterFeature> newFeatures;
  final VoidCallback onConfirm;

  const SummaryStep({
    super.key,
    required this.character,
    required this.nextLevel,
    required this.hpIncrease,
    required this.newFeatures,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            l10n.levelUpReady,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.confirmLevelUp,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildRow(context, l10n.levelShort, '${character.level}',
                      '$nextLevel'),
                  const Divider(),
                  _buildRow(context, l10n.hitPoints, '${character.maxHp}',
                      '${character.maxHp + hpIncrease} (+$hpIncrease)'),
                  const Divider(),
                  _buildRow(
                      context,
                      l10n.proficiencyPROF,
                      _formatBonus(character.proficiencyBonus),
                      _formatBonus(_calculateProficiency(nextLevel))),
                  if (newFeatures.isNotEmpty) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.newFeaturesLabel),
                          Text('${newFeatures.length}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              child: Text(l10n.applyChanges),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
      BuildContext context, String label, String oldVal, String newVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Row(
            children: [
              Text(oldVal, style: const TextStyle(color: Colors.grey)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
              ),
              Text(newVal,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBonus(int bonus) {
    return bonus >= 0 ? '+$bonus' : '$bonus';
  }

  int _calculateProficiency(int level) {
    return ((level - 1) / 4).ceil() + 2;
  }
}
