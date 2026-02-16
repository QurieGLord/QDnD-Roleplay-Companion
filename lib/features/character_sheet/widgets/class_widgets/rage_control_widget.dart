import 'package:flutter/material.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../l10n/app_localizations.dart';

class RageControlWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature rageFeature;
  final VoidCallback? onChanged;

  const RageControlWidget({
    super.key,
    required this.character,
    required this.rageFeature,
    this.onChanged,
  });

  @override
  State<RageControlWidget> createState() => _RageControlWidgetState();
}

class _RageControlWidgetState extends State<RageControlWidget> {
  bool _isRaging = false;

  int _getRageDamage(int level) {
    if (level >= 16) return 4;
    if (level >= 9) return 3;
    return 2;
  }

  int _getMaxRage(int level) {
    if (level >= 20) return 99; // Unlimited
    if (level >= 17) return 6;
    if (level >= 12) return 5;
    if (level >= 6) return 4;
    if (level >= 3) return 3;
    return 2;
  }

  @override
  void initState() {
    super.initState();
    final pool = widget.rageFeature.resourcePool;
    if (pool != null && pool.currentUses == 0) {
      final correctMax = _getMaxRage(widget.character.level);
      if (pool.maxUses != correctMax && correctMax < 99) {
         pool.maxUses = correctMax;
      }
      pool.restoreFull();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.character.save();
      });
    }
  }

  void _toggleRage(bool value) {
    final l10n = AppLocalizations.of(context)!;
    final pool = widget.rageFeature.resourcePool!;
    final level = widget.character.level;
    final maxRage = _getMaxRage(level);
    final isUnlimited = maxRage >= 99;

    if (value) {
      // Trying to enter rage
      if (pool.currentUses > 0 || isUnlimited) {
        setState(() {
          _isRaging = true;
          if (!isUnlimited) {
            pool.use(1);
          }
          widget.character.save();
          widget.onChanged?.call();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUnlimited 
              ? '${l10n.rage} used! (Unlimited)' 
              : '${l10n.rage} used! (-1)'), 
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No Rage charges left!'), // Fallback if key missing, or add to arb
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Ending rage
      setState(() {
        _isRaging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.rageFeature.resourcePool!;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    
    final level = widget.character.level;
    final rageDamage = _getRageDamage(level);
    final maxRage = _getMaxRage(level);
    final isUnlimited = maxRage >= 99;
    
    final activeColor = colorScheme.error; 
    final cardColor = _isRaging ? activeColor.withOpacity(0.05) : colorScheme.surface;
    final borderColor = _isRaging ? activeColor.withOpacity(0.5) : colorScheme.outlineVariant;
    final textColor = _isRaging ? activeColor : colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: _isRaging ? 2 : 1),
        boxShadow: _isRaging
            ? [
                BoxShadow(
                  color: activeColor.withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header Row: Icon, Title, Switch
            Row(
              children: [
                 AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isRaging ? activeColor : colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.whatshot,
                      color: _isRaging ? colorScheme.onError : colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.rage.toUpperCase(),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                letterSpacing: 1.0,
                              ),
                        ),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                color: _isRaging ? activeColor : colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                          child: Text(_isRaging ? l10n.raging.toUpperCase() : l10n.rageInactive.toUpperCase()),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isRaging,
                    onChanged: _toggleRage,
                    activeColor: activeColor,
                    activeTrackColor: activeColor.withOpacity(0.4),
                    inactiveThumbColor: colorScheme.outline,
                    inactiveTrackColor: colorScheme.surfaceContainerHighest,
                    trackOutlineColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected) 
                        ? Colors.transparent 
                        : colorScheme.outlineVariant
                    ),
                    thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                      (states) => states.contains(WidgetState.selected) 
                          ? const Icon(Icons.whatshot, size: 16, color: Colors.white) 
                          : null
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            Divider(height: 1, color: borderColor.withOpacity(0.5)),
            const SizedBox(height: 16),

            // Stats Row: Usages & Damage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Rage Charges
                Expanded(
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.resources, 
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isUnlimited ? '∞' : '${pool.currentUses}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: pool.isEmpty ? colorScheme.error : colorScheme.onSurface,
                                  height: 1.0,
                                ),
                              ),
                              if (!isUnlimited)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
                                child: Text(
                                  '/ $maxRage',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Quick buttons for correcting count manually
                      if (!isUnlimited)
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: (pool.currentUses >= maxRage) ? null : () => setState(() { 
                              pool.restore(1); 
                              widget.character.save(); 
                            }),
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            iconSize: 20,
                            color: colorScheme.secondary,
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: pool.isEmpty ? null : () => setState(() { pool.use(1); widget.character.save(); }),
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            iconSize: 20,
                            color: colorScheme.secondary,
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                
                // Rage Damage Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isRaging ? activeColor : colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isRaging ? [
                      BoxShadow(color: activeColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))
                    ] : [],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.rageDamage.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isRaging ? colorScheme.onError : colorScheme.onSecondaryContainer,
                            ),
                          ),
                          if (_isRaging) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.check_circle, size: 10, color: colorScheme.onError),
                          ]
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+$rageDamage',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _isRaging ? colorScheme.onError : colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
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
