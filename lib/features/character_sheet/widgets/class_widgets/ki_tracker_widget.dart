import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/dice_utils.dart';

class KiTrackerWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature kiFeature;
  final VoidCallback? onChanged;

  const KiTrackerWidget({
    super.key,
    required this.character,
    required this.kiFeature,
    this.onChanged,
  });

  @override
  State<KiTrackerWidget> createState() => _KiTrackerWidgetState();
}

class _KiTrackerWidgetState extends State<KiTrackerWidget> {
  int _getMartialArtsDie(int level) {
    if (level >= 17) return 10;
    if (level >= 11) return 8;
    if (level >= 5) return 6;
    return 4;
  }

  void _rollMartialArtsDie() {
    HapticFeedback.mediumImpact();
    final dieSize = _getMartialArtsDie(widget.character.level);
    final result = Random().nextInt(dieSize) + 1;
    final l10n = AppLocalizations.of(context)!;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.sports_mma, color: Colors.white), // Martial arts icon
            const SizedBox(width: 12),
            Text(
              l10n.kiStrikeRoll(result, DiceUtils.formatDice('1d$dieSize', context)),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _modifyKi(int index) {
    final pool = widget.kiFeature.resourcePool!;
    final isRecovering = index >= pool.currentUses;

    setState(() {
      if (isRecovering) {
        // Recover up to this index (1-based count)
        final target = index + 1;
        final diff = target - pool.currentUses;
        if (diff > 0) pool.restore(diff);
      } else {
        // Consume logic
        if (pool.currentUses == index + 1) {
          pool.use(1); // Toggle off the top one
        } else {
          // Set to this level
          final diff = pool.currentUses - (index + 1);
          if (diff > 0) pool.use(diff);
        }
      }
      widget.character.save();
      widget.onChanged?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.kiFeature.resourcePool!;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final dieSize = _getMartialArtsDie(widget.character.level);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.auto_awesome, color: colorScheme.onPrimaryContainer, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.kiPoints,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          '${l10n.levelShort} ${widget.character.level} ${l10n.classLabel}', 
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                InkWell(
                  onTap: _rollMartialArtsDie,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.casino, size: 16, color: colorScheme.onSecondaryContainer),
                        const SizedBox(width: 6),
                        Text(
                          DiceUtils.formatDice('1d$dieSize', context),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: List.generate(pool.maxUses, (index) {
                  final isActive = index < pool.currentUses;
                  return GestureDetector(
                    onTap: () => _modifyKi(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? colorScheme.primary : Colors.transparent,
                        border: Border.all(
                          color: isActive ? colorScheme.primary : colorScheme.outline,
                          width: 2,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ]
                            : [],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                             return ScaleTransition(scale: animation, child: child);
                          },
                          child: isActive
                              ? Icon(Icons.bolt, key: const ValueKey('active'), size: 18, color: colorScheme.onPrimary)
                              : const SizedBox(key: ValueKey('inactive')),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Align(
               alignment: Alignment.centerRight,
               child: Text(
                 '${pool.currentUses} / ${pool.maxUses}',
                 style: TextStyle(
                   color: colorScheme.onSurfaceVariant,
                   fontWeight: FontWeight.bold,
                   fontSize: 12,
                 ),
               ),
             ),
          ],
        ),
      ),
    );
  }
}
