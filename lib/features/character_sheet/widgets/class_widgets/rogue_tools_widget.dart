import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../../../../core/models/character.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/dice_utils.dart';
import '../../../../shared/widgets/bouncing_button.dart';

class RogueToolsWidget extends StatefulWidget {
  final Character character;

  const RogueToolsWidget({
    super.key,
    required this.character,
  });

  @override
  State<RogueToolsWidget> createState() => _RogueToolsWidgetState();
}

class _RogueToolsWidgetState extends State<RogueToolsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  int _getSneakAttackDice(int level) {
    return (level + 1) ~/ 2;
  }

  void _rollSneakAttack(BuildContext context, int diceCount) {
    HapticFeedback.mediumImpact();
    _rotationController.forward(from: 0.0);

    final random = Random();
    int total = 0;
    for (int i = 0; i < diceCount; i++) {
      total += random.nextInt(6) + 1;
    }

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.flash_on, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.sneakAttackRoll(
                    total, DiceUtils.formatDice('${diceCount}d6', context)),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context)
            .colorScheme
            .tertiary, // Keeping tertiary for snackbar identity
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final diceCount = _getSneakAttackDice(widget.character.level);
    final diceText = DiceUtils.formatDice('${diceCount}d6', context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      color: colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.visibility, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.sneakAttack.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: 1.2,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 24),

            // Action Button - Center Stage with Juice
            Center(
              child: BouncingButton(
                onPressed: () => _rollSneakAttack(context, diceCount),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: colorScheme
                        .primaryContainer, // Changed to standard beige/primaryContainer
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotationTransition(
                        turns: CurvedAnimation(
                            parent: _rotationController,
                            curve: Curves.easeOutBack),
                        child: Icon(Icons.casino,
                            size: 20, color: colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        diceText,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            Center(
              child: Text(
                l10n.tapToRoll,
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
