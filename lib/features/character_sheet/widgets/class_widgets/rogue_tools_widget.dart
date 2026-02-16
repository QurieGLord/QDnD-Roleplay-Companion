import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../../../../core/models/character.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/dice_utils.dart';

class RogueToolsWidget extends StatelessWidget {
  final Character character;

  const RogueToolsWidget({
    super.key,
    required this.character,
  });

  int _getSneakAttackDice(int level) {
    return (level + 1) ~/ 2;
  }

  void _rollSneakAttack(BuildContext context, int diceCount) {
    HapticFeedback.mediumImpact();
    final random = Random();
    int total = 0;
    // Simple roll logic
    for (int i = 0; i < diceCount; i++) {
      total += random.nextInt(6) + 1;
    }

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.casino, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              l10n.sneakAttackRoll(total, DiceUtils.formatDice('${diceCount}d6', context)),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final diceCount = _getSneakAttackDice(character.level);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _rollSneakAttack(context, diceCount),
        child: Container(
          color: colorScheme.tertiaryContainer, // Themed background
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.onTertiaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.visibility_off,
                  color: colorScheme.tertiaryContainer, // Inverse for icon
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.sneakAttack.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onTertiaryContainer,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.touch_app, size: 14, color: colorScheme.onTertiaryContainer.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l10n.tapToRoll, // Localized
                            style: TextStyle(
                              color: colorScheme.onTertiaryContainer.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.onTertiaryContainer.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      l10n.sneakAttackDamage.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onTertiaryContainer.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DiceUtils.formatDice('${diceCount}d6', context),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
