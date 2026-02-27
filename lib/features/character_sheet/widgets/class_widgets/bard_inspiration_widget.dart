import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/bouncing_button.dart';

class BardInspirationWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature inspirationFeature;
  final VoidCallback? onChanged;

  const BardInspirationWidget({
    super.key,
    required this.character,
    required this.inspirationFeature,
    this.onChanged,
  });

  @override
  State<BardInspirationWidget> createState() => _BardInspirationWidgetState();
}

class _BardInspirationWidgetState extends State<BardInspirationWidget>
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

  String _getInspirationDie(int level, String locale) {
    String die;
    if (level >= 15) {
      die = '1d12';
    } else if (level >= 10)
      die = '1d10';
    else if (level >= 5)
      die = '1d8';
    else
      die = '1d6';

    if (locale == 'ru') {
      return die.replaceAll('d', 'к');
    }
    return die;
  }

  void _useCharge(int amount) {
    final pool = widget.inspirationFeature.resourcePool;
    if (pool == null) return;

    if (pool.currentUses >= amount) {
      setState(() {
        pool.use(amount);
        widget.character.save();
        widget.onChanged?.call();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No charges left!'),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 1),
      ));
    }
  }

  void _restoreCharge(int amount) {
    final pool = widget.inspirationFeature.resourcePool;
    if (pool == null) return;

    if (!pool.isFull) {
      setState(() {
        pool.restore(amount);
        widget.character.save();
        widget.onChanged?.call();
      });
      _showFeedback(false, 0);
    }
  }

  void _toggleUsage() {
    final pool = widget.inspirationFeature.resourcePool;
    if (pool == null || pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No charges left!'),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 1),
      ));
      return;
    }

    // Visual Juice
    HapticFeedback.mediumImpact();
    _rotationController.forward(from: 0.0);

    // 1. Determine die sides
    int sides = 6;
    if (widget.character.level >= 15) {
      sides = 12;
    } else if (widget.character.level >= 10)
      sides = 10;
    else if (widget.character.level >= 5) sides = 8;

    // 2. Roll
    final result = Random().nextInt(sides) + 1;

    // 3. Use charge
    _useCharge(1);

    // 4. Show Result
    _showFeedback(true, result);
  }

  void _showFeedback(bool used, int rollResult) {
    final l10n = AppLocalizations.of(context)!;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    String msg;
    if (used) {
      msg = isRu
          ? 'Вдохновение: $rollResult!'
          : 'Inspiration Result: $rollResult!';
    } else {
      msg = isRu ? 'Вдохновение восстановлено!' : 'Inspiration recovered!';
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.inspirationFeature.resourcePool;
    // Safety check
    if (pool == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final dieType = _getInspirationDie(widget.character.level, locale);

    final maxCharges = pool.maxUses > 0 ? pool.maxUses : 1;
    final currentCharges = pool.currentUses;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header: Clean and Bold
            Row(
              children: [
                Icon(Icons.queue_music, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.bardicInspiration.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: 1.2,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '$currentCharges / $maxCharges',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),

            // Element 1: The Notes (Resource) - Centered & Animated
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(maxCharges, (index) {
                final isActive = index < currentCharges;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (isActive) {
                      _useCharge(1);
                      _showFeedback(true, 0);
                    } else {
                      _restoreCharge(1);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    transform: Matrix4.identity()
                      ..scale(isActive ? 1.0 : 0.8), // Pulse effect
                    child: Icon(
                      Icons.music_note,
                      size: 32,
                      color: isActive
                          ? colorScheme.tertiary
                          : colorScheme.surfaceContainerHighest,
                      shadows: isActive
                          ? [
                              Shadow(
                                  color: colorScheme.tertiary
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8)
                            ]
                          : [],
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Element 2: The Die Button (Action) - Centered & Compact with Juice
            Center(
              child: BouncingButton(
                onPressed: pool.isEmpty ? null : _toggleUsage,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20), // Pill/Stadium
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotationTransition(
                        turns: CurvedAnimation(
                            parent: _rotationController,
                            curve: Curves.easeOutBack),
                        child: Icon(Icons.casino_outlined,
                            size: 20, color: colorScheme.onSecondaryContainer),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dieType,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
