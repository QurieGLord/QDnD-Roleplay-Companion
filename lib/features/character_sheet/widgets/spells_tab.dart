import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/spell.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/services/spellcasting_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/managers/spell_preparation_manager.dart';
import 'spell_slots_widget.dart';
import '../../spell_almanac/spell_almanac_screen.dart';
import '../../../shared/widgets/spell_details_sheet.dart';
import '../../../shared/widgets/feature_details_sheet.dart';
import '../../../core/utils/spell_utils.dart';

class SpellsTab extends StatefulWidget {
  final Character character;

  const SpellsTab({super.key, required this.character});

  @override
  State<SpellsTab> createState() => _SpellsTabState();
}

class _SpellsTabState extends State<SpellsTab> {
  String _getLocalizedActionEconomy(AppLocalizations l10n, String economy) {
    final lower = economy.toLowerCase();
    if (lower.contains('bonus')) return l10n.actionTypeBonus;
    if (lower.contains('reaction')) return l10n.actionTypeReaction;
    if (lower.contains('action')) return l10n.actionTypeAction;
    if (lower.contains('free')) return l10n.actionTypeFree;
    return economy;
  }

  String _getAbilityAbbr(AppLocalizations l10n, String key) {
    switch (key.toLowerCase()) {
      case 'strength': return l10n.abilityStrAbbr;
      case 'dexterity': return l10n.abilityDexAbbr;
      case 'constitution': return l10n.abilityConAbbr;
      case 'intelligence': return l10n.abilityIntAbbr;
      case 'wisdom': return l10n.abilityWisAbbr;
      case 'charisma': return l10n.abilityChaAbbr;
      default: return key.length >= 3 ? key.substring(0, 3).toUpperCase() : key.toUpperCase();
    }
  }

  CharacterFeature? _findResourceFeature(String id) {
    try {
      return widget.character.features.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  void _useFeature(CharacterFeature feature, String locale, AppLocalizations l10n) {
    // 1. Consumption Logic
    if (feature.consumption != null) {
      final resource = _findResourceFeature(feature.consumption!.resourceId);
      if (resource != null && resource.resourcePool != null) {
        if (resource.resourcePool!.currentUses >= feature.consumption!.amount) {
          setState(() {
            resource.resourcePool!.use(feature.consumption!.amount);
            widget.character.save();
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${feature.getName(locale)} used!'),
            duration: const Duration(milliseconds: 1000),
          ));
        } else {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text('Not enough ${resource.getName(locale)}!'), 
             backgroundColor: Theme.of(context).colorScheme.error
           ));
        }
        return;
      }
    }

    // 2. Legacy Channel Divinity Logic
    if (feature.nameEn.contains('Channel Divinity') || feature.descriptionEn.contains('Channel Divinity')) {
      try {
        final cdPoolFeature = widget.character.features.firstWhere((f) => f.id == 'channel_divinity');
        if (cdPoolFeature.resourcePool != null) {
           if (cdPoolFeature.resourcePool!.currentUses > 0) {
             setState(() {
               cdPoolFeature.resourcePool!.use(1);
               widget.character.save();
             });
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
               content: Text(l10n.useChannelDivinity(cdPoolFeature.resourcePool!.currentUses)),
               duration: const Duration(milliseconds: 1000),
             ));
           } else {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
               content: Text(l10n.noChannelDivinity), 
               backgroundColor: Theme.of(context).colorScheme.error
             ));
           }
        }
      } catch (_) {}
    }
  }

  void _showCastSpellDialog(Spell spell, String locale, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;

    if (spell.level == 0) {
      _castSpell(spell, 0, locale, l10n);
      return;
    }

    final availableSlots = <int>[];
    for (int i = spell.level; i <= widget.character.maxSpellSlots.length; i++) {
      if (i <= widget.character.spellSlots.length && widget.character.spellSlots[i - 1] > 0) {
        availableSlots.add(i);
      }
    }

    if (availableSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noSlotsAvailable),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.castAction(spell.getName(locale))),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.chooseSpellSlot, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableSlots.length,
                  itemBuilder: (context, index) {
                    final level = availableSlots[index];
                    final slotsRemaining = widget.character.spellSlots[level - 1];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text('$level', style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(l10n.levelSlot(level), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(l10n.slotsRemaining(slotsRemaining)),
                      trailing: level > spell.level
                        ? Chip(
                            label: Text(l10n.upcast, style: const TextStyle(fontSize: 10)), 
                            backgroundColor: colorScheme.tertiaryContainer,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          )
                        : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        _castSpell(spell, level, locale, l10n);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  void _castSpell(Spell spell, int slotLevel, String locale, AppLocalizations l10n) {
    setState(() {
      if (slotLevel > 0) {
        widget.character.useSpellSlot(slotLevel);
      }
      final message = slotLevel > spell.level
        ? l10n.spellCastLevelSuccess(spell.getName(locale), slotLevel)
        : l10n.spellCastSuccess(spell.getName(locale));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;

    final knownSpells = widget.character.knownSpells
        .map((id) => SpellService.getSpellById(id))
        .whereType<Spell>()
        .toList();

    final spellsByLevel = <int, List<Spell>>{};
    for (var spell in knownSpells) {
      spellsByLevel.putIfAbsent(spell.level, () => []).add(spell);
    }

    final features = widget.character.features.toList();
    final hasSpecificFightingStyle = features.any((f) => f.nameEn.startsWith('Fighting Style:'));
    if (hasSpecificFightingStyle) {
      features.removeWhere((f) => f.id == 'fighting_style');
    }

    final resourceFeatures = features.where((f) => f.resourcePool != null).toList();
    final passiveFeatures = features.where((f) => f.resourcePool == null && f.type == FeatureType.passive).toList();
    final activeFeatures = features.where((f) => f.resourcePool == null && f.type != FeatureType.passive).toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (resourceFeatures.isNotEmpty) ...[
              _buildSectionHeader(l10n.resources.toUpperCase()),
              ...resourceFeatures.map((feature) => _buildResourceFeature(feature, locale)).toList(),
              const SizedBox(height: 16),
            ],

            if (activeFeatures.isNotEmpty) ...[
              _buildSectionHeader(l10n.activeAbilities.toUpperCase()),
              ...activeFeatures.map((feature) => _buildActiveFeature(feature, locale, l10n)).toList(),
              const SizedBox(height: 16),
            ],

            _buildSectionHeader(l10n.magic.toUpperCase()),
            _buildMagicSection(context, l10n),
            const SizedBox(height: 16),

            if (knownSpells.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.auto_fix_off, size: 48, color: colorScheme.onSurface.withOpacity(0.3)),
                    const SizedBox(height: 8),
                    Text(l10n.noSpellsLearned, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5))),
                  ],
                ),
              ))
            else
              ...(spellsByLevel.keys.toList()..sort()).map((level) => _buildSpellLevelGroup(level, spellsByLevel[level]!, locale, l10n)).toList(),

            const SizedBox(height: 16),

            if (passiveFeatures.isNotEmpty) ...[
              _buildSectionHeader(l10n.passiveTraits.toUpperCase()),
              Card(
                elevation: 1,
                child: ExpansionTile(
                  title: Text('${passiveFeatures.length} ${l10n.passiveTraits}'),
                  subtitle: Text(
                    passiveFeatures.map((f) => f.getName(locale)).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  leading: Icon(Icons.psychology, color: colorScheme.secondary),
                  children: passiveFeatures.map((feature) => ListTile(
                    title: Text(feature.getName(locale), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(feature.getDescription(locale), style: const TextStyle(fontSize: 12)),
                    dense: true,
                    leading: Icon(_getFeatureIcon(feature.iconName), size: 18, color: colorScheme.secondary.withOpacity(0.7)),
                  )).toList(),
                ),
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
        
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SpellAlmanacScreen(character: widget.character),
                ),
              ).then((_) => setState(() {}));
            },
            icon: const Icon(Icons.library_books),
            label: Text(l10n.spellAlmanac),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildResourceFeature(CharacterFeature feature, String locale) {
    final pool = feature.resourcePool!;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => FeatureDetailsSheet(feature: feature),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(_getFeatureIcon(feature.iconName), size: 20, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(feature.getName(locale), style: const TextStyle(fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  Text('${pool.currentUses}/${pool.maxUses}', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: pool.isEmpty ? colorScheme.error : colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pool.maxUses > 0 ? pool.currentUses / pool.maxUses : 0,
                        color: pool.isEmpty ? colorScheme.error : colorScheme.primary,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: pool.isEmpty ? null : () => setState(() { pool.use(1); widget.character.save(); }),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    iconSize: 24,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: pool.isFull ? null : () => setState(() { pool.restore(1); widget.character.save(); }),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    iconSize: 24,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFeature(CharacterFeature feature, String locale, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Find linked resource for display
    String? resourceCost;
    if (feature.consumption != null) {
      final res = _findResourceFeature(feature.consumption!.resourceId);
      if (res != null) {
        resourceCost = '${feature.consumption!.amount} ${res.getName(locale)}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: InkWell(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => FeatureDetailsSheet(feature: feature),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_getFeatureIcon(feature.iconName), size: 20, color: colorScheme.onSecondaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(feature.getName(locale), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (feature.actionEconomy != null)
                          Text(
                            _getLocalizedActionEconomy(l10n, feature.actionEconomy!).toUpperCase(),
                            style: TextStyle(fontSize: 10, color: colorScheme.secondary, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                feature.getDescription(locale), 
                maxLines: 2, 
                overflow: TextOverflow.ellipsis, 
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)
              ),
              
              if (resourceCost != null || (feature.nameEn.contains('Channel Divinity'))) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _useFeature(feature, locale, l10n),
                    icon: const Icon(Icons.bolt, size: 16),
                    label: Text(
                      resourceCost != null 
                        ? 'Use ($resourceCost)' 
                        : 'Use', // Fallback
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMagicSection(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPactMagic = SpellcastingService.getSpellcastingType(widget.character.characterClass) == 'pact_magic';
    final isPreparedCaster = SpellcastingService.getSpellcastingType(widget.character.characterClass) == 'prepared';
    final maxPrepared = SpellcastingService.getMaxPreparedSpells(widget.character);
    final currentPrepared = widget.character.preparedSpells.length;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isPreparedCaster) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: currentPrepared > maxPrepared 
                      ? colorScheme.errorContainer 
                      : colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, 
                      size: 16, 
                      color: currentPrepared > maxPrepared 
                          ? colorScheme.onErrorContainer 
                          : colorScheme.onSecondaryContainer
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.preparedSpellsCount(currentPrepared, maxPrepared),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: currentPrepared > maxPrepared 
                            ? colorScheme.onErrorContainer 
                            : colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMagicStat(l10n.spellAbility, _getAbilityAbbr(l10n, SpellcastingService.getSpellcastingAbilityName(widget.character.characterClass))),
                Container(width: 1, height: 30, color: colorScheme.outlineVariant),
                _buildMagicStat(l10n.spellSaveDC, '${SpellcastingService.getSpellSaveDC(widget.character)}'),
                Container(width: 1, height: 30, color: colorScheme.outlineVariant),
                _buildMagicStat(l10n.spellAttack, '+${SpellcastingService.getSpellAttackBonus(widget.character)}'),
              ],
            ),
            
            if (widget.character.maxSpellSlots.any((s) => s > 0)) ...[
              const Divider(height: 32),
              if (isPactMagic)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text('Pact Magic (Short Rest)', style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              SpellSlotsWidget(
                character: widget.character,
                onChanged: () => setState(() => widget.character.save()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMagicStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
      ],
    );
  }

  Widget _buildSpellLevelGroup(int level, List<Spell> spells, String locale, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(level == 0 ? l10n.cantrips.toUpperCase() : l10n.levelLabel(level).toUpperCase(), style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        ),
        ...spells.map((spell) {
           final isPrepared = widget.character.preparedSpells.contains(spell.id);
           final canCast = spell.level == 0 || (spell.level <= widget.character.spellSlots.length && widget.character.spellSlots[spell.level - 1] > 0);
           
           return Card(
             margin: const EdgeInsets.only(bottom: 6),
             elevation: 0,
             shape: RoundedRectangleBorder(
               side: BorderSide(color: colorScheme.outlineVariant),
               borderRadius: BorderRadius.circular(12),
             ),
             child: ListTile(
               contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
               dense: true,
               leading: GestureDetector(
                 onTap: () {
                   setState(() {
                      SpellPreparationManager.togglePreparation(widget.character, spell, context);
                   });
                 },
                 child: Icon(
                   isPrepared ? Icons.star : Icons.star_border, 
                   color: isPrepared ? Colors.amber : colorScheme.outline, 
                   size: 24
                 ),
               ),
               title: Text(spell.getName(locale), style: const TextStyle(fontWeight: FontWeight.w600)),
               subtitle: Text(SpellUtils.getLocalizedSchool(l10n, spell.school), style: TextStyle(color: colorScheme.secondary, fontSize: 11)),
               trailing: IconButton(
                 icon: const Icon(Icons.auto_fix_high),
                 onPressed: canCast ? () => _showCastSpellDialog(spell, locale, l10n) : null,
                 color: canCast ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.2),
                 tooltip: l10n.castSpell,
               ),
               onTap: () => showModalBottomSheet(
                 context: context,
                 isScrollControlled: true,
                 builder: (context) => SpellDetailsSheet(
                   spell: spell,
                   character: widget.character,
                   onToggleKnown: () => setState(() {
                      if (widget.character.knownSpells.contains(spell.id)) {
                        widget.character.knownSpells.remove(spell.id);
                        widget.character.preparedSpells.remove(spell.id);
                      } else {
                        widget.character.knownSpells.add(spell.id);
                      }
                      widget.character.save();
                   }),
                 ),
               ),
             ),
           );
        }).toList(),
        const SizedBox(height: 8),
      ],
    );
  }

  IconData _getFeatureIcon(String? iconName) {
    switch (iconName) {
      case 'healing': return Icons.favorite;
      case 'visibility': return Icons.visibility;
      case 'flash_on': return Icons.flash_on;
      case 'swords': return Icons.shield;
      case 'auto_fix_high': return Icons.auto_fix_high;
      case 'health_and_safety': return Icons.health_and_safety;
      case 'auto_awesome': return Icons.auto_awesome;
      case 'filter_2': return Icons.filter_2;
      case 'security': return Icons.security;
      case 'back_hand': return Icons.back_hand;
      case 'wifi_tethering': return Icons.wifi_tethering;
      default: return Icons.star;
    }
  }
}