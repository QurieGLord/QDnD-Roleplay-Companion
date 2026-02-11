import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/spell.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/services/spellcasting_service.dart';
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

class _SpellsTabState extends State<SpellsTab> with AutomaticKeepAliveClientMixin {
  final Map<int, bool> _expandedLevels = {};

  @override
  bool get wantKeepAlive => true;

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
    // 0. Find Linked Resource
    CharacterFeature? resource;
    if (feature.usageCostId != null) {
      try {
        // Smart Resource Search (Fuzzy Matching)
        resource = widget.character.features.firstWhere(
          (f) {
            final match = f.resourcePool != null && (
              f.id == feature.usageCostId || 
              f.id.endsWith('-${feature.usageCostId}') || 
              f.id.startsWith('${feature.usageCostId}-') ||
              (feature.usageCostId == 'ki' && f.id.contains('ki'))
            );
            return match;
          }
        );
      } catch (_) {}
    } else if (feature.consumption != null) {
       resource = _findResourceFeature(feature.consumption!.resourceId);
    }

    // Fallback for missing usageCostId on Channel Divinity
    if (resource == null && feature.usageCostId == null && feature.id.startsWith('channel-divinity-')) {
       try {
         resource = widget.character.features.firstWhere(
           (f) => f.resourcePool != null && (f.id == 'channel-divinity' || f.id.startsWith('channel-divinity-1-rest'))
         );
       } catch (_) {}
    }

    // 1. Validate Resource
    if (resource == null || resource.resourcePool == null) {
       // Fallback for legacy Channel Divinity
       if (feature.nameEn.contains('Channel Divinity')) {
          _useLegacyChannelDivinity(l10n);
       }
       return;
    }

    final pool = resource.resourcePool!;

    // 2. Granular Spending (Slider)
    if (feature.usageInputMode == 'slider') {
      if (pool.currentUses <= 0) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text('No charges left for ${resource.getName(locale)}!'),
             backgroundColor: Theme.of(context).colorScheme.error
         ));
         return;
      }
      _showUsageDialog(context, feature, resource, locale);
      return;
    }

    // 3. Simple Spending (Fixed Cost)
    int cost = 1;
    if (feature.consumption != null) {
      cost = feature.consumption!.amount;
    }

    if (pool.currentUses >= cost) {
      setState(() {
        pool.use(cost);
        widget.character.save();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${feature.getName(locale)} used! (-$cost ${resource.getName(locale)})'),
        duration: const Duration(milliseconds: 1000),
      ));
    } else {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
         content: Text('Not enough ${resource.getName(locale)} (Need $cost)!'), 
         backgroundColor: Theme.of(context).colorScheme.error
       ));
    }
  }

  void _useLegacyChannelDivinity(AppLocalizations l10n) {
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

  void _showUsageDialog(BuildContext context, CharacterFeature feature, CharacterFeature resource, String locale) {
    int spendAmount = 1;
    final max = resource.resourcePool!.currentUses;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Spend ${resource.getName(locale)}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('How many points to use for ${feature.getName(locale)}?'),
                  const SizedBox(height: 16),
                  Text('$spendAmount / $max', style: Theme.of(context).textTheme.headlineMedium),
                  Slider(
                    value: spendAmount.toDouble(),
                    min: 1,
                    max: max.toDouble(),
                    divisions: max > 1 ? max - 1 : 1,
                    label: spendAmount.toString(),
                    onChanged: (value) {
                      setDialogState(() => spendAmount = value.round());
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      resource.resourcePool!.use(spendAmount);
                      widget.character.save();
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${feature.getName(locale)} used! (-$spendAmount ${resource.getName(locale)})'),
                    ));
                  },
                  child: const Text('Spend'),
                ),
              ],
            );
          }
        );
      },
    );
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
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;
    
    // 1. Determine which spells to display
    final classId = widget.character.characterClass.toLowerCase();
    final isWizard = classId == 'wizard';
    final isPreparedCaster = SpellcastingService.getSpellcastingType(classId) == 'prepared';

    // Calculate max spell level available
    int maxSpellLevel = 0;
    // For Pact Magic (Warlock), slots are all same level, but maxSpellSlots usually has length = max level?
    // Actually standard slots: index 0 = Level 1.
    for (int i = 0; i < widget.character.maxSpellSlots.length; i++) {
       if (widget.character.maxSpellSlots[i] > 0) {
         maxSpellLevel = i + 1;
       }
    }

    List<Spell> displaySpells;
    if (isPreparedCaster && !isWizard) {
      // Cleric, Druid, Paladin: Show ALL class spells, but filtered by slot level
      // Also always include Cantrips (Level 0)
      displaySpells = SpellService.getSpellsForClass(classId)
          .where((s) => s.level == 0 || s.level <= maxSpellLevel)
          .toList();
    } else {
      // Wizard, Bard, Sorcerer, etc: Show KNOWN spells (Spellbook)
      displaySpells = widget.character.knownSpells
          .map((id) => SpellService.getSpellById(id))
          .whereType<Spell>()
          .toList();
    }

    final spellsByLevel = <int, List<Spell>>{};
    for (var spell in displaySpells) {
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
        Column(
          children: [
            Expanded(
              child: ListView(
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

                  _buildSectionHeader(
                    l10n.magic.toUpperCase(),
                    trailing: _buildPreparationCounter(context, l10n),
                  ),
                  _buildMagicSection(context, l10n, showCounter: false), // Disable old counter
                  const SizedBox(height: 16),

                  if (displaySpells.isEmpty)
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
            ),
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

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, right: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.5,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget? _buildPreparationCounter(BuildContext context, AppLocalizations l10n) {
    final classId = widget.character.characterClass.toLowerCase();
    final isPreparedCaster = SpellcastingService.getSpellcastingType(classId) == 'prepared';
    if (!isPreparedCaster) return null;

    final colorScheme = Theme.of(context).colorScheme;
    final maxPrepared = SpellcastingService.getMaxPreparedSpells(widget.character);
    
    int currentPrepared = 0;
    for (final id in widget.character.preparedSpells) {
       final s = SpellService.getSpellById(id);
       if (s != null && s.level > 0) currentPrepared++;
    }

    final isOverLimit = currentPrepared > maxPrepared;
    final isFull = currentPrepared == maxPrepared;
    final color = isOverLimit ? colorScheme.error : (isFull ? colorScheme.primary : colorScheme.onSurfaceVariant);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            '${l10n.preparedSpells.toUpperCase()}: ',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8)),
          ),
          Text(
            '$currentPrepared/$maxPrepared',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }


  Widget _buildResourceFeature(CharacterFeature feature, String locale) {
    // ... (unchanged)
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
    } else if (feature.usageCostId != null) {
       try {
        final res = widget.character.features.firstWhere(
          (f) => f.resourcePool != null && (
            f.id == feature.usageCostId || 
            f.id.endsWith('-${feature.usageCostId}') || 
            f.id.startsWith('${feature.usageCostId}-') ||
            (feature.usageCostId == 'ki' && f.id.contains('ki'))
          ),
        );
        resourceCost = '1 ${res.getName(locale)}';
      } catch (_) {}
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
              
              if (resourceCost != null || feature.isAction || feature.usageCostId != null || (feature.nameEn.contains('Channel Divinity'))) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _useFeature(feature, locale, l10n),
                    icon: const Icon(Icons.bolt, size: 16),
                    label: Text(
                      resourceCost != null 
                        ? l10n.useActionCost(resourceCost) 
                        : l10n.useAction, 
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

  Widget _buildMagicSection(BuildContext context, AppLocalizations l10n, {bool showCounter = true}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPactMagic = SpellcastingService.getSpellcastingType(widget.character.characterClass) == 'pact_magic';
    // isPreparedCaster check removed as we handle it via showCounter or header
    final maxPrepared = SpellcastingService.getMaxPreparedSpells(widget.character);
    final currentPrepared = widget.character.preparedSpells.length;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (showCounter) ...[
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
    final title = level == 0 ? l10n.cantrips.toUpperCase() : l10n.levelLabel(level).toUpperCase();
    
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('spell_level_$level'),
        initiallyExpanded: _expandedLevels[level] ?? true,
        onExpansionChanged: (expanded) => _expandedLevels[level] = expanded,
        tilePadding: EdgeInsets.zero,
        title: Text(
          title, 
          style: TextStyle(
            color: colorScheme.primary, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 1.0,
            fontSize: 14
          )
        ),
        children: spells.map((spell) {
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
                      final success = SpellPreparationManager.togglePreparation(widget.character, spell, context);
                      if (!success) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                             content: Text('Cannot prepare more spells! Limit reached.'), // Using hardcoded English as fallback or use a suitable l10n key if found
                             backgroundColor: Theme.of(context).colorScheme.error,
                           )
                         );
                      }
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
                 color: canCast ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.2),
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
      ),
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