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
  int _calculateMaxKi() {
    int monkLevel = 0;

    // 1. Search in classes list
    if (widget.character.classes.isNotEmpty) {
      for (var cls in widget.character.classes) {
        if (cls.id.toLowerCase().contains('monk') ||
            cls.name.toLowerCase().contains('monk')) {
          monkLevel = cls.level;
          break;
        }
      }
    }

    // 2. Fallback logic
    if (monkLevel == 0) {
      if (widget.character.characterClass.toLowerCase().contains('monk')) {
        monkLevel = widget.character.level;
      } else if (widget.character.classes.length == 1) {
        monkLevel = widget.character.level;
      }
    }

    // 3. NUCLEAR OPTION
    if (monkLevel <= 1 && widget.character.level > 1) {
      monkLevel = widget.character.level;
    }

    // Safety: Ensure at least 1
    if (monkLevel == 0) monkLevel = 1;

    return monkLevel;
  }

  int _getMartialArtsDie(int level) {
    if (level >= 17) return 10;
    if (level >= 11) return 8;
    if (level >= 5) return 6;
    return 4;
  }

  void _rollMartialArtsDie() {
    HapticFeedback.mediumImpact();
    int monkLevel = _calculateMaxKi();
    final dieSize = _getMartialArtsDie(monkLevel);
    final result = Random().nextInt(dieSize) + 1;
    final l10n = AppLocalizations.of(context);

    if (l10n == null) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.sports_mma, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              l10n.kiStrikeRoll(
                  result, DiceUtils.formatDice('1d$dieSize', context)),
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

  void _restoreKi(int maxKi) {
    final pool = widget.kiFeature.resourcePool;
    if (pool == null) return;

    if (pool.maxUses != maxKi) pool.maxUses = maxKi;

    if (!pool.isFull) {
      HapticFeedback.selectionClick();
      setState(() {
        pool.restore(1);
        widget.character.save();
        widget.onChanged?.call();
      });
    }
  }

  void _spendKi(int maxKi) {
    final pool = widget.kiFeature.resourcePool;
    if (pool == null) return;

    if (pool.maxUses != maxKi) pool.maxUses = maxKi;

    if (pool.currentUses > 0) {
      HapticFeedback.lightImpact();
      setState(() {
        pool.use(1);
        widget.character.save();
        widget.onChanged?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.kiFeature.resourcePool;
    if (pool == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final colorScheme = Theme.of(context).colorScheme;

    final maxKi = _calculateMaxKi();
    final dieSize = _getMartialArtsDie(maxKi);
    final progress = maxKi > 0 ? pool.currentUses / maxKi : 0.0;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // LEFT ZONE: Ki Source
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return CircularProgressIndicator(
                            value: value,
                            strokeWidth: 10,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary),
                            strokeCap: StrokeCap.round,
                          );
                        },
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${pool.currentUses}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: colorScheme.onSurface,
                                height: 1.0,
                              ),
                        ),
                        Text(
                          locale == 'ru' ? 'ЦИ' : 'KI',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: pool.isEmpty ? null : () => _spendKi(maxKi),
                        icon: const Icon(Icons.remove, size: 20),
                        visualDensity: VisualDensity.compact,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surface,
                          foregroundColor: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: pool.isFull ? null : () => _restoreKi(maxKi),
                        icon: const Icon(Icons.add, size: 20),
                        visualDensity: VisualDensity.compact,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surface,
                          foregroundColor: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // RIGHT ZONE: The Strike
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _rollMartialArtsDie,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                colorScheme.secondary.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.secondary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.casino_outlined,
                              size: 24,
                              color: colorScheme.onSecondaryContainer),
                          const SizedBox(width: 12),
                          Text(
                            DiceUtils.formatDice('1d$dieSize', context),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n?.martialArts.toUpperCase() ?? 'MARTIAL ARTS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
