import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/dice_utils.dart';

class FighterCombatWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature? secondWindFeature;
  final CharacterFeature? actionSurgeFeature;
  final CharacterFeature? indomitableFeature;
  final VoidCallback? onChanged;

  const FighterCombatWidget({
    super.key,
    required this.character,
    this.secondWindFeature,
    this.actionSurgeFeature,
    this.indomitableFeature,
    this.onChanged,
  });

  @override
  State<FighterCombatWidget> createState() => _FighterCombatWidgetState();
}

class _FighterCombatWidgetState extends State<FighterCombatWidget> {
  
  void _useResource(CharacterFeature feature, {String? customMessage}) {
    final pool = feature.resourcePool!;
    if (pool.currentUses > 0) {
      HapticFeedback.mediumImpact();
      setState(() {
        pool.use(1);
        widget.character.save();
        widget.onChanged?.call();
      });
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(customMessage ?? '${feature.getName(Localizations.localeOf(context).languageCode)} used!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        ),
      );
    }
  }

  void _restoreResource(CharacterFeature feature) {
     final pool = feature.resourcePool!;
     if (!pool.isFull) {
       HapticFeedback.selectionClick();
       setState(() {
         pool.restore(1);
         widget.character.save();
         widget.onChanged?.call();
       });
     }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final level = widget.character.level;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: colorScheme.secondaryContainer.withOpacity(0.4),
            child: Row(
              children: [
                Icon(Icons.shield, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.fighterTactics.toUpperCase(), 
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (widget.secondWindFeature != null) 
                  _buildSecondWindRow(context, l10n, colorScheme, level),
                
                if (widget.secondWindFeature != null && widget.actionSurgeFeature != null)
                  const Divider(height: 24),

                if (widget.actionSurgeFeature != null)
                  _buildActionSurgeRow(context, l10n, colorScheme),

                if (widget.indomitableFeature != null && (widget.secondWindFeature != null || widget.actionSurgeFeature != null))
                  const Divider(height: 24),

                if (widget.indomitableFeature != null)
                  _buildIndomitableRow(context, l10n, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondWindRow(BuildContext context, AppLocalizations l10n, ColorScheme colorScheme, int level) {
    final feature = widget.secondWindFeature!;
    final pool = feature.resourcePool;
    if (pool == null) return const SizedBox.shrink();

    final isAvailable = pool.currentUses > 0;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.tertiaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.favorite, size: 24, color: colorScheme.onTertiaryContainer),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.secondWind,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${l10n.healing}: ${DiceUtils.formatDice('1d10', context)} + $level',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        
        // Dynamic control
        if (isAvailable)
          Expanded(
            flex: 1,
            child: FilledButton.icon(
              onPressed: () => _useResource(feature),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.flash_on, size: 16),
              label: Text(l10n.healShort),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _restoreResource(feature),
            tooltip: 'Restore',
            color: colorScheme.secondary,
          ),
      ],
    );
  }

  Widget _buildActionSurgeRow(BuildContext context, AppLocalizations l10n, ColorScheme colorScheme) {
    final feature = widget.actionSurgeFeature!;
    final pool = feature.resourcePool;
    if (pool == null) return const SizedBox.shrink();
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade100, 
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.bolt, size: 24, color: Colors.amber.shade900),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.actionSurge,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.actionTypeAction,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        
        // Interactive Tokens
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(pool.maxUses, (index) {
             final isAvailable = index < pool.currentUses;
             return Padding(
               padding: const EdgeInsets.only(left: 8.0),
               child: GestureDetector(
                 onTap: () {
                   if (isAvailable) {
                     _useResource(feature, customMessage: l10n.actionSurge);
                   } else {
                     _restoreResource(feature);
                   }
                 },
                 child: AnimatedContainer(
                   duration: const Duration(milliseconds: 300),
                   width: 36,
                   height: 36,
                   decoration: BoxDecoration(
                     color: isAvailable ? Colors.amber.shade600 : Colors.transparent,
                     shape: BoxShape.circle,
                     border: Border.all(
                       color: isAvailable ? Colors.amber.shade600 : colorScheme.outline.withOpacity(0.5),
                       width: 2,
                     ),
                     boxShadow: isAvailable ? [
                       BoxShadow(color: Colors.amber.shade600.withOpacity(0.4), blurRadius: 6, spreadRadius: 1)
                     ] : [],
                   ),
                   child: Icon(
                     isAvailable ? Icons.bolt : Icons.bolt_outlined,
                     size: 20,
                     color: isAvailable ? Colors.white : colorScheme.outline,
                   ),
                 ),
               ),
             );
          }),
        ),
      ],
    );
  }

  Widget _buildIndomitableRow(BuildContext context, AppLocalizations l10n, ColorScheme colorScheme) {
    final feature = widget.indomitableFeature!;
    final pool = feature.resourcePool;
    if (pool == null) return const SizedBox.shrink();
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.indigo.shade100, 
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.replay, size: 24, color: Colors.indigo.shade900),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.indomitable,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.rerollSave,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        
        // Interactive Tokens
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(pool.maxUses, (index) {
             final isAvailable = index < pool.currentUses;
             return Padding(
               padding: const EdgeInsets.only(left: 8.0),
               child: GestureDetector(
                 onTap: () {
                   if (isAvailable) {
                     _useResource(feature, customMessage: l10n.rerollSave);
                   } else {
                     _restoreResource(feature);
                   }
                 },
                 child: AnimatedContainer(
                   duration: const Duration(milliseconds: 300),
                   width: 36,
                   height: 36,
                   decoration: BoxDecoration(
                     color: isAvailable ? Colors.indigo : Colors.transparent,
                     shape: BoxShape.circle,
                     border: Border.all(
                       color: isAvailable ? Colors.indigo : colorScheme.outline.withOpacity(0.5),
                       width: 2,
                     ),
                     boxShadow: isAvailable ? [
                       BoxShadow(color: Colors.indigo.withOpacity(0.4), blurRadius: 4)
                     ] : [],
                   ),
                   child: Icon(
                     isAvailable ? Icons.shield : Icons.shield_outlined,
                     size: 18,
                     color: isAvailable ? Colors.white : colorScheme.outline,
                   ),
                 ),
               ),
             );
          }),
        ),
      ],
    );
  }
}
