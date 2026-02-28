import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/spell.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/services/spellcasting_service.dart';
import '../../../core/services/feature_service.dart';
import '../../../core/managers/spell_preparation_manager.dart';
import 'spell_slots_widget.dart';
import '../../spell_almanac/spell_almanac_screen.dart';
import '../../../shared/widgets/spell_details_sheet.dart';
import '../../../shared/widgets/feature_details_sheet.dart';
import '../../../core/utils/spell_utils.dart';
import '../../../core/models/spell_slots_table.dart';
import 'class_widgets/ki_tracker_widget.dart';
import 'class_widgets/rage_control_widget.dart';
import 'class_widgets/rogue_tools_widget.dart';
import 'class_widgets/fighter_combat_widget.dart';
import 'class_widgets/bard_inspiration_widget.dart';
import 'class_widgets/paladin_divine_widget.dart';
import 'class_widgets/sorcerer_magic_widget.dart';
import 'class_widgets/warlock_magic_widget.dart';
import 'class_widgets/druid_magic_widget.dart';
import 'class_widgets/wizard_magic_widget.dart';
import 'class_widgets/cleric_magic_widget.dart';
import 'class_widgets/ranger_survival_widget.dart';

class AbilitiesTab extends StatefulWidget {
  final Character character;

  const AbilitiesTab({super.key, required this.character});

  @override
  State<AbilitiesTab> createState() => _AbilitiesTabState();
}

class _AbilitiesTabState extends State<AbilitiesTab>
    with AutomaticKeepAliveClientMixin {
  final Map<int, bool> _expandedLevels = {};

  @override
  bool get wantKeepAlive => true;

  // --- Safe Helpers ---

  String _getLocalizedActionEconomy(AppLocalizations l10n, String? economy) {
    if (economy == null) return '';
    try {
      final lower = economy.toLowerCase();
      if (lower.contains('bonus')) return l10n.actionTypeBonus;
      if (lower.contains('reaction')) return l10n.actionTypeReaction;
      if (lower.contains('action')) return l10n.actionTypeAction;
      if (lower.contains('free')) return l10n.actionTypeFree;
      return economy;
    } catch (e) {
      debugPrint('Error localizing action economy: $e');
      return economy;
    }
  }

  String _getAbilityAbbr(AppLocalizations l10n, String key) {
    switch (key.toLowerCase()) {
      case 'strength':
        return l10n.abilityStrAbbr;
      case 'dexterity':
        return l10n.abilityDexAbbr;
      case 'constitution':
        return l10n.abilityConAbbr;
      case 'intelligence':
        return l10n.abilityIntAbbr;
      case 'wisdom':
        return l10n.abilityWisAbbr;
      case 'charisma':
        return l10n.abilityChaAbbr;
      default:
        return key.length >= 3
            ? key.substring(0, 3).toUpperCase()
            : key.toUpperCase();
    }
  }

  // --- Deep Search & Filtering ---

  bool _shouldShowInList(CharacterFeature feature) {
    try {
      // NUCLEAR OPTION: Safe access to properties
      final id = (feature.id ?? '').toLowerCase();
      final name = (feature.nameEn ?? '').toLowerCase();
      final usageCost = (feature.usageCostId ?? '').toLowerCase();

      // Dedicated Widget Handling (Deduplication)
      if (id.contains('action_surge') || name.contains('action surge')) {
        return false;
      }
      if (id.contains('second_wind') || name.contains('second wind')) {
        return false;
      }
      if (id.contains('indomitable')) return false;
      if (id.contains('rage') || name == 'rage') return false;
      if (id.contains('ki') || name.startsWith('ki')) return false;
      if (id.contains('sneak_attack') || name.contains('sneak attack')) {
        return false;
      }

      // Monk Martial Arts Deduplication
      if (id.contains('martial_arts') ||
          id.contains('martial-arts') ||
          name.contains('martial arts')) {
        return false;
      }
      final monkTactics = [
        'flurry_of_blows',
        'flurry-of-blows',
        'patient_defense',
        'patient-defense',
        'step_of_the_wind',
        'step-of-the-wind',
        'stunning_strike',
        'stunning-strike',
        'unarmored_movement',
        'unarmored-movement',
        'шквал ударов',
        'терпеливая оборона',
        'поступь ветра',
        'оглушающий удар',
        'движение без доспехов'
      ];
      if (monkTactics.any((t) => id.contains(t) || name.contains(t)))
        return false;

      // Bard Deduplication
      if (id.contains('bardic_inspiration') ||
          id.contains('bardic-inspiration') ||
          name.contains('bardic inspiration') ||
          name.contains('бардовское вдохновение')) {
        return false; // Handled by widget
      }
      final bardTactics = [
        'cutting_words',
        'cutting-words',
        'cutting words',
        'острые слова',
        'combat_inspiration',
        'combat-inspiration',
        'combat inspiration',
        'боевое вдохновение',
        'countercharm',
        'контрочарование',
        'song_of_rest',
        'song-of-rest',
        'song of rest',
        'песнь отдыха',
      ];
      if (bardTactics.any((t) => id.contains(t) || name.contains(t)))
        return false;

      // Rogue Deduplication
      final rogueTactics = [
        'sneak_attack',
        'sneak-attack',
        'sneak attack',
        'скрытая атака',
        'cunning_action',
        'cunning-action',
        'cunning action',
        'хитрое действие',
        'uncanny_dodge',
        'uncanny-dodge',
        'uncanny dodge',
        'невероятное уклонение',
        'evasion',
        'увертливость',
      ];
      if (rogueTactics.any((t) => id.contains(t) || name.contains(t)))
        return false;

      // Paladin Deduplication
      if (id.contains('lay-on-hands') || id.contains('lay_on_hands')) {
        return false;
      }
      if (id.contains('divine-sense') || id.contains('divine_sense')) {
        return false;
      }
      if (id == 'channel-divinity' || id == 'channel_divinity') return false;
      if (id.startsWith('channel-divinity-') ||
          id.startsWith('channel_divinity_')) {
        return false;
      }
      if (usageCost.contains('channel-divinity') ||
          usageCost.contains('channel_divinity')) {
        return false;
      }

      // Ranger Deduplication
      if (id == 'primeval-awareness' || id == 'primeval_awareness')
        return false;
      if (id == 'favored-enemy' || id == 'favored_enemy') return false;
      if (id == 'natural-explorer' || id == 'natural_explorer') return false;
      if (id == 'hunters-mark' ||
          id == 'hunters_mark' ||
          name.contains("hunter's mark") ||
          name.contains("метка охотника")) return false;
      if (id == 'hide-in-plain-sight' ||
          id == 'hide_in_plain_sight' ||
          name.contains("hide in plain sight") ||
          name.contains("маскировка")) return false;

      final rangerTactics = [
        'colossus',
        'horde breaker',
        'giant killer',
        'volley',
        'whirlwind',
        'evasion',
        'uncanny dodge',
        'multiattack defense',
        'steel will',
        'stand against',
        'escape the horde'
      ];
      if (rangerTactics.any((t) =>
          id.contains(t.replaceAll(' ', '-')) ||
          id.contains(t.replaceAll(' ', '_')) ||
          name.contains(t))) return false;

      // Barbarian Deduplication
      if (id.contains('reckless-attack') ||
          id.contains('reckless_attack') ||
          name.contains('reckless attack') ||
          name.contains('безрассудная атака')) {
        return false;
      }
      if (id.contains('frenzy') ||
          name.contains('frenzy') ||
          name.contains('бешенство')) {
        return false;
      }
      if (id.contains('primal_path') ||
          id.contains('primal-path') ||
          name.contains('primal path') ||
          name.contains('путь дикости')) {
        return false;
      }

      // Sorcerer Deduplication

      if (id.contains('sorcery_point') ||
          id.contains('sorcery-point') ||
          name.contains('sorcery point') ||
          name.contains('единицы чародейства')) return false;

      if (id.contains('font_of_magic') ||
          id.contains('font-of-magic') ||
          name.contains('font of magic') ||
          name.contains('источник магии')) return false;

      if (id.contains('flexible_casting') ||
          id.contains('flexible-casting') ||
          name.contains('flexible casting') ||
          name.contains('гибкое накладывание') ||
          name.contains('гибкая магия')) return false;

      if (id.contains('metamagic') ||
          name.contains('metamagic') ||
          name.contains('метамагия')) return false;

      if (id.contains('dragon-ancestor') ||
          id.contains('draconic') ||
          id.contains('dragon') ||
          name.contains('dragon') ||
          name.contains('дракон')) return false;

      // Warlock Deduplication
      if (id.contains('eldritch-invocation') ||
          id.contains('eldritch_invocation') ||
          id.contains('invocation') ||
          name.contains('invocation') ||
          name.contains('воззвание')) return false;

      if (id.contains('pact-boon') ||
          id.contains('pact_boon') ||
          id.contains('pact-of-the-') ||
          id.contains('pact_of_the_') ||
          name.contains('pact boon') ||
          name.contains('предмет договора') ||
          name.contains('договор пакта')) return false;

      if (id.contains('mystic-arcanum') ||
          id.contains('mystic_arcanum') ||
          name.contains('mystic arcanum') ||
          name.contains('таинственный арканум')) return false;

      // Druid Deduplication
      if (name.contains('wild shape') ||
          name.contains('дикий облик') ||
          id.contains('wild_shape') ||
          id.contains('wild-shape')) {
        return false;
      }

      if (name.contains('natural recovery') ||
          name.contains('естественное восстановление') ||
          id.contains('natural_recovery') ||
          id.contains('natural-recovery')) {
        return false;
      }

      // Wizard Deduplication
      if (name.contains('arcane recovery') ||
          name.contains('арканное восстановление') ||
          id.contains('arcane_recovery') ||
          id.contains('arcane-recovery')) {
        return false;
      }

      if (id.contains('arcane-tradition') ||
          id.contains('arcane_tradition') ||
          name.contains('arcane tradition') ||
          name.contains('магическая традиция')) {
        return false;
      }

      // Cleric Deduplication
      if (id.contains('divine-domain') ||
          id.contains('divine_domain') ||
          name.contains('divine domain') ||
          name.contains('божественный домен')) {
        return false;
      }

      if (id == 'channel_divinity' ||
          id == 'channel-divinity' ||
          name.contains('channel divinity') ||
          name.contains('божественный канал')) {
        // Only hide the base feature, not subclass specific ones if they are actions
        // But for Cleric, we handle the pool in the widget.
        return false;
      }

      // Hide "Fighting Style" grouping feature if it exists (usually just a header)

      if (id == 'fighting_style') return false;

      return true;
    } catch (e) {
      debugPrint('Error in _shouldShowInList: $e');
      return false; // Fail safe: don't show potentially broken features
    }
  }

  CharacterFeature? _findFeatureDeep(
      List<CharacterFeature> list, List<String> keywords) {
    try {
      // 1. Exact ID Match first
      for (final keyword in keywords) {
        try {
          final match = list.where((f) => (f.id ?? '') == keyword).firstOrNull;
          if (match != null) return match;
        } catch (_) {}
      }

      // 2. Contains ID
      for (final keyword in keywords) {
        try {
          // Sort by level descending to get the best version
          final candidates =
              list.where((f) => (f.id ?? '').contains(keyword)).toList();
          candidates
              .sort((a, b) => (b.minLevel ?? 0).compareTo(a.minLevel ?? 0));
          if (candidates.isNotEmpty) return candidates.first;
        } catch (_) {}
      }

      // 3. Name Match
      for (final keyword in keywords) {
        try {
          final cleanKeyword = keyword.replaceAll('_', ' ');
          final candidates = list
              .where(
                  (f) => (f.nameEn ?? '').toLowerCase().contains(cleanKeyword))
              .toList();
          candidates
              .sort((a, b) => (b.minLevel ?? 0).compareTo(a.minLevel ?? 0));
          if (candidates.isNotEmpty) return candidates.first;
        } catch (_) {}
      }

      return null;
    } catch (e) {
      debugPrint('Deep search failed: $e');
      return null;
    }
  }

  CharacterFeature? _findResourceFeature(String id) {
    try {
      return widget.character.features.where((f) => f.id == id).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  List<CharacterFeature> _deduplicateAndFilterFeatures(
      List<CharacterFeature> list, String locale) {
    debugPrint('--- Smart Deduplicating ${list.length} features ---');
    try {
      final Map<String, CharacterFeature> bestFeatures = {};

      for (final feature in list) {
        // ignore: unnecessary_null_comparison
        if (feature == null) continue;

        // Group by Localized Name to catch duplicates with different IDs
        final String groupKey = feature.getName(locale).toLowerCase().trim();

        // Special handling for upgradable features (scaling values)
        // e.g., "Destroy Undead (CR 1/2)" vs "Destroy Undead (CR 1)"
        // We look for common prefixes
        String baseName = groupKey;
        final upgradeRegex =
            RegExp(r'^(.*?)\s*\(.*?\)$'); // Matches "Name (Detail)"
        if (upgradeRegex.hasMatch(groupKey)) {
          baseName = upgradeRegex.firstMatch(groupKey)!.group(1)!.trim();
        }

        if (!bestFeatures.containsKey(baseName)) {
          bestFeatures[baseName] = feature;
        } else {
          final existing = bestFeatures[baseName]!;
          final currentLevel = feature.minLevel ?? 0;
          final existingLevel = existing.minLevel ?? 0;

          // Rule: Keep the one with higher level requirement (The "Upgrade")
          if (currentLevel > existingLevel) {
            bestFeatures[baseName] = feature;
          } else if (currentLevel == existingLevel) {
            // If levels are same, prefer the one with a more specific ID or longer description
            if ((feature.id ?? '').length > (existing.id ?? '').length) {
              bestFeatures[baseName] = feature;
            }
          }
        }
      }

      // Standard ID-based fallback deduplication (for things without names or specific IDs)
      final List<CharacterFeature> result = bestFeatures.values.toList();
      final Map<String, CharacterFeature> finalMap = {};

      for (var f in result) {
        String baseId = f.id ?? '';
        final versionRegex = RegExp(r'(_|-)\d+$');
        if (versionRegex.hasMatch(baseId)) {
          baseId = baseId.replaceAll(versionRegex, '');
        }

        if (!finalMap.containsKey(baseId)) {
          finalMap[baseId] = f;
        } else {
          if ((f.minLevel ?? 0) > (finalMap[baseId]!.minLevel ?? 0)) {
            finalMap[baseId] = f;
          }
        }
      }

      return finalMap.values.toList();
    } catch (e) {
      debugPrint('Error in smart deduplication: $e');
      return list;
    }
  }

  // --- Actions ---

  void _useFeature(
      CharacterFeature feature, String locale, AppLocalizations l10n) {
    try {
      // 0. Find Linked Resource
      CharacterFeature? resource;

      // NUCLEAR OPTION: Safe access
      final usageCostId = feature.usageCostId;
      final consumption = feature.consumption;
      final featureId = feature.id ?? '';

      if (usageCostId != null) {
        try {
          // Deep resource search
          resource = widget.character.features.where((f) {
            if (f.resourcePool == null) return false;
            final fId = (f.id ?? '').toLowerCase();
            final costId = usageCostId.toLowerCase();
            return fId == costId ||
                fId.endsWith('-$costId') ||
                fId.startsWith('$costId-') ||
                (costId == 'ki' && fId.contains('ki'));
          }).firstOrNull;
        } catch (_) {}
      } else if (consumption != null) {
        resource = _findResourceFeature(consumption.resourceId);
      }

      // Special Case: Channel Divinity
      if (resource == null && featureId.startsWith('channel-divinity-')) {
        try {
          resource = widget.character.features
              .where((f) =>
                  f.resourcePool != null &&
                  ((f.id ?? '') == 'channel-divinity' ||
                      (f.id ?? '').startsWith('channel-divinity-1-rest')))
              .firstOrNull;
        } catch (_) {}
      }

      // 1. Validate Resource
      if (resource == null || resource.resourcePool == null) {
        if ((feature.nameEn ?? '').contains('Channel Divinity')) {
          _useLegacyChannelDivinity(l10n);
        }
        return;
      }

      // NUCLEAR OPTION: Bang removal
      final pool = resource.resourcePool;
      if (pool == null) return;

      // 2. Granular Spending (Slider)
      if (feature.usageInputMode == 'slider') {
        if (pool.currentUses <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('No charges left for ${resource.getName(locale)}!'),
              backgroundColor: Theme.of(context).colorScheme.error));
          return;
        }
        _showUsageDialog(context, feature, resource, locale);
        return;
      }

      // 3. Simple Spending
      int cost = 1;
      if (consumption != null) {
        cost = consumption.amount;
      }

      if (pool.currentUses >= cost) {
        setState(() {
          pool.use(cost);
          widget.character.save();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${feature.getName(locale)} used! (-$cost ${resource.getName(locale)})'),
          duration: const Duration(milliseconds: 1000),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Not enough ${resource.getName(locale)} (Need $cost)!'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    } catch (e) {
      debugPrint('Error using feature: $e');
    }
  }

  void _useLegacyChannelDivinity(AppLocalizations l10n) {
    try {
      final cdPoolFeature = widget.character.features
          .where((f) => f.id == 'channel_divinity')
          .firstOrNull;
      // NUCLEAR OPTION: Safe access
      if (cdPoolFeature?.resourcePool != null) {
        final pool = cdPoolFeature?.resourcePool;
        if (pool == null) return;

        if (pool.currentUses > 0) {
          setState(() {
            pool.use(1);
            widget.character.save();
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.useChannelDivinity(pool.currentUses)),
            duration: const Duration(milliseconds: 1000),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.noChannelDivinity),
              backgroundColor: Theme.of(context).colorScheme.error));
        }
      }
    } catch (_) {}
  }

  void _showUsageDialog(BuildContext context, CharacterFeature feature,
      CharacterFeature resource, String locale) {
    int spendAmount = 1;
    final max = resource.resourcePool?.currentUses ?? 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Spend ${resource.getName(locale)}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How many points to use for ${feature.getName(locale)}?'),
                const SizedBox(height: 16),
                Text('$spendAmount / $max',
                    style: Theme.of(context).textTheme.headlineMedium),
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
                    resource.resourcePool?.use(spendAmount);
                    widget.character.save();
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '${feature.getName(locale)} used! (-$spendAmount ${resource.getName(locale)})'),
                  ));
                },
                child: const Text('Spend'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showCastSpellDialog(Spell spell, String locale, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;

    if (spell.level == 0) {
      _castSpell(spell, 0, locale, l10n);
      return;
    }

    // --- Wizard VIP Logic (Stage 3) ---
    final isSpellMastery =
        widget.character.spellMasterySpells.contains(spell.id);
    final isSignatureSpell =
        widget.character.signatureSpells.contains(spell.id);
    final signatureUsed =
        widget.character.signatureSpellsUsed[spell.id] ?? false;

    final isPactMagic = SpellcastingService.getSpellcastingType(
            widget.character.characterClass) ==
        'pact_magic';

    final availableSlots = <int>[];
    for (int i = 1; i <= widget.character.maxSpellSlots.length; i++) {
      if (widget.character.spellSlots[i - 1] > 0) {
        if (isPactMagic) {
          availableSlots.add(i);
        } else if (i >= spell.level) {
          availableSlots.add(i);
        }
      }
    }

    // Determine primary action
    Widget? primaryAction;
    if (isSpellMastery) {
      primaryAction = Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _castSpell(spell, 0, locale, l10n, isVipCast: true);
          },
          icon: const Icon(Icons.auto_awesome),
          label: Text(locale == 'ru'
              ? "Скастовать бесплатно (Мастерство)"
              : "Cast freely (Spell Mastery)"),
          style: FilledButton.styleFrom(
              backgroundColor: colorScheme.tertiary,
              foregroundColor: colorScheme.onTertiary),
        ),
      );
    } else if (isSignatureSpell && !signatureUsed) {
      primaryAction = Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: FilledButton.icon(
          onPressed: () {
            setState(() {
              widget.character.signatureSpellsUsed[spell.id] = true;
              widget.character.save();
            });
            Navigator.pop(context);
            _castSpell(spell, 0, locale, l10n, isVipCast: true);
          },
          icon: const Icon(Icons.auto_fix_high),
          label: Text(locale == 'ru'
              ? "Скастовать бесплатно (Фирменное)"
              : "Cast freely (Signature)"),
          style: FilledButton.styleFrom(
              backgroundColor: colorScheme.tertiary,
              foregroundColor: colorScheme.onTertiary),
        ),
      );
    }

    if (availableSlots.isEmpty && primaryAction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noSlotsAvailable),
          backgroundColor: colorScheme.error,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (primaryAction != null) primaryAction,
              if (availableSlots.isNotEmpty) ...[
                Text(l10n.chooseSpellSlot,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableSlots.length,
                    itemBuilder: (context, index) {
                      final level = availableSlots[index];
                      final slotsRemaining =
                          widget.character.spellSlots[level - 1];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text('$level',
                              style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(l10n.levelSlot(level),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(l10n.slotsRemaining(slotsRemaining)),
                        trailing: level > spell.level
                            ? Chip(
                                label: Text(l10n.upcast,
                                    style: const TextStyle(fontSize: 10)),
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

  void _castSpell(
      Spell spell, int slotLevel, String locale, AppLocalizations l10n,
      {bool isVipCast = false}) {
    setState(() {
      if (slotLevel > 0) {
        widget.character.useSpellSlot(slotLevel);
      }
      String message;
      if (isVipCast) {
        message = locale == 'ru'
            ? '${spell.getName(locale)} наложено бесплатно'
            : '${spell.getName(locale)} cast for free';
      } else if (slotLevel > spell.level) {
        // Fix for interpolation issue: manually build string if needed or ensure correct params
        // User reported "9 наложено на [Name] уровне".
        // Assuming l10n key is: "{count} cast at {name} level" (wrong) or "{name} cast at {level} level" (correct).
        // If the output was weird, let's just force a correct string for now.
        if (locale == 'ru') {
          message = '${spell.getName(locale)} наложено на $slotLevel уровне';
        } else {
          message = '${spell.getName(locale)} cast at level $slotLevel';
        }
      } else {
        message = l10n.spellCastSuccess(spell.getName(locale));
      }

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

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // DEBUG: Start Build Trace
    debugPrint('=== START BUILDING ABILITIES TAB ===');
    debugPrint('Character Class: ${widget.character.characterClass}');
    debugPrint('Features count: ${widget.character.features.length}');

    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);

    if (l10n == null) return const SizedBox.shrink();

    // NUCLEAR SAFE MODE: Wrap entire build logic in try-catch to prevent grey screen
    try {
      // 1. Setup Spells
      final classId = widget.character.characterClass.toLowerCase();
      final isWizard = classId == 'wizard';
      final isPreparedCaster =
          SpellcastingService.getSpellcastingType(classId) == 'prepared';
      final hasSpellSlots = widget.character.maxSpellSlots.any((s) => s > 0);
      final hasKnownSpells = widget.character.knownSpells.isNotEmpty;
      final showMagicSection = hasSpellSlots || hasKnownSpells;

      int maxSpellLevel = 0;
      for (int i = 0; i < widget.character.maxSpellSlots.length; i++) {
        if (widget.character.maxSpellSlots[i] > 0) {
          maxSpellLevel = i + 1;
        }
      }

      List<Spell> displaySpells = [];
      if (showMagicSection) {
        if (isPreparedCaster && !isWizard) {
          displaySpells = SpellService.getSpellsForClass(classId)
              .where((s) => s.level == 0 || s.level <= maxSpellLevel)
              .toList();
        } else {
          displaySpells = widget.character.knownSpells
              .map((id) => SpellService.getSpellById(id))
              .whereType<Spell>()
              .toList();
        }
      }

      final spellsByLevel = <int, List<Spell>>{};
      final vipSpellIds = {
        ...widget.character.spellMasterySpells,
        ...widget.character.signatureSpells,
      };

      for (var spell in displaySpells) {
        if (vipSpellIds.contains(spell.id)) continue;
        spellsByLevel.putIfAbsent(spell.level, () => []).add(spell);
      }

      // 2. Setup Features
      final allFeatures = widget.character.features;

      // Deep Search for Class Widgets
      final monkKiFeature = _findFeatureDeep(allFeatures, ['ki']);
      final barbarianRageFeature =
          _findFeatureDeep(allFeatures, ['rage', 'barbarian_rage']);
      final rogueSneakAttack = _findFeatureDeep(allFeatures, ['sneak_attack']);
      final bardInspiration = _findFeatureDeep(
          allFeatures, ['bardic_inspiration', 'bardic-inspiration']);

      final fighterActionSurge =
          _findFeatureDeep(allFeatures, ['action_surge', 'action surge']);
      final fighterSecondWind =
          _findFeatureDeep(allFeatures, ['second_wind', 'second wind']);
      final fighterIndomitable = _findFeatureDeep(allFeatures, ['indomitable']);

      // Paladin Features
      final paladinLayOnHands =
          _findFeatureDeep(allFeatures, ['lay-on-hands', 'lay_on_hands']);
      final paladinDivineSense =
          _findFeatureDeep(allFeatures, ['divine-sense', 'divine_sense']);
      final paladinChannelDivinity = _findFeatureDeep(
          allFeatures, ['channel-divinity', 'channel_divinity']);

      // Ranger Features
      final primevalAwareness = _findFeatureDeep(
          allFeatures, ['primeval-awareness', 'primeval_awareness']);

      // Sorcerer Features (Robust Search)
      final sorceryPoints = _findFeatureDeep(allFeatures, [
            'sorcery_points',
            'sorcery-points',
            'sorcery_point',
            'sorcery-point',
            'font_of_magic',
            'font-of-magic'
          ]) ??
          allFeatures
              .where((f) =>
                  f.resourcePool != null &&
                  (f.nameEn.toLowerCase().contains('sorcery point') ||
                      f.nameRu.toLowerCase().contains('единицы чародейства') ||
                      f.nameEn.toLowerCase().contains('font of magic') ||
                      f.nameRu.toLowerCase().contains('источник магии')))
              .firstOrNull;

      final metamagicOptions = allFeatures
          .where((f) =>
              (f.id ?? '').toLowerCase().contains('metamagic') ||
              f.nameEn.toLowerCase().contains('metamagic') ||
              f.nameRu.toLowerCase().contains('метамагия'))
          .toList();

      final sorcererAncestry = allFeatures
          .where((f) =>
              (f.id ?? '').toLowerCase().contains('dragon-ancestor') ||
              (f.id ?? '').toLowerCase().contains('draconic') ||
              (f.id ?? '').toLowerCase().contains('dragon') ||
              f.nameEn.toLowerCase().contains('draconic') ||
              f.nameRu.toLowerCase().contains('дракон'))
          .toList();

      // Debug Sorcerer Detection
      if (classId.contains('sorcerer')) {
        debugPrint('--- SORCERER DEBUG ---');
        debugPrint('Sorcery Points Found: ${sorceryPoints?.id ?? "NULL"}');
        debugPrint(
            'Metamagic Options: ${metamagicOptions.map((e) => e.id).join(', ')}');
        debugPrint(
            'Ancestry Features: ${sorcererAncestry.map((e) => e.id).join(', ')}');
      }

      // Warlock Features
      final warlockPatron = _findFeatureDeep(allFeatures, [
        'patron',
        'fiend',
        'archfey',
        'great_old_one',
        'celestial',
        'hexblade',
        'fathomless',
        'genie',
        'undead'
      ]);
      final warlockPactBoon = _findFeatureDeep(allFeatures, [
        'pact-boon',
        'pact_boon',
        'pact-of-the-chain',
        'pact_of_the_chain',
        'pact-of-the-blade',
        'pact_of_the_blade',
        'pact-of-the-tome',
        'pact_of_the_tome',
        'pact-of-the-talismam',
        'pact_of_the_talismam'
      ]);
      final warlockInvocations = allFeatures
          .where((f) =>
              (f.id ?? '').toLowerCase().contains('invocation') ||
              f.nameEn.toLowerCase().contains('invocation') ||
              f.nameRu.toLowerCase().contains('воззвание'))
          .toList();

      List<CharacterFeature> paladinChannelSpells = [];
      if (paladinChannelDivinity != null) {
        paladinChannelSpells = allFeatures
            .where((f) {
              final id = (f.id ?? '').toLowerCase();
              final usageCost = (f.usageCostId ?? '').toLowerCase();
              return (id.startsWith('channel-divinity-') ||
                      id.startsWith('channel_divinity_')) ||
                  (usageCost.contains('channel-divinity') ||
                      usageCost.contains('channel_divinity'));
            })
            .where((f) => f.id != paladinChannelDivinity.id)
            .toList();
      }

      final rawActiveFeatures = allFeatures
          .where((f) =>
              f.resourcePool == null &&
              f.type != FeatureType.passive &&
              _shouldShowInList(f))
          .toList();

      final activeFeatures =
          _deduplicateAndFilterFeatures(rawActiveFeatures, locale);

      final rawPassiveFeatures = allFeatures
          .where((f) =>
              f.resourcePool == null &&
              f.type == FeatureType.passive &&
              _shouldShowInList(f))
          .toList();

      final passiveFeatures =
          _deduplicateAndFilterFeatures(rawPassiveFeatures, locale);

      final rawResourceFeatures = allFeatures
          .where((f) => f.resourcePool != null && _shouldShowInList(f))
          .toList();

      final resourceFeatures =
          _deduplicateAndFilterFeatures(rawResourceFeatures, locale);

      debugPrint(
          'Features Filtered: Res=${resourceFeatures.length}, Active=${activeFeatures.length}, Passive=${passiveFeatures.length}');

      // Check for empty state
      final isEmpty = resourceFeatures.isEmpty &&
          activeFeatures.isEmpty &&
          !showMagicSection &&
          passiveFeatures.isEmpty &&
          monkKiFeature == null &&
          barbarianRageFeature == null &&
          rogueSneakAttack == null &&
          fighterSecondWind == null &&
          fighterActionSurge == null &&
          bardInspiration == null &&
          !classId.contains('sorcerer') &&
          paladinLayOnHands == null;

      return Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.library_books_outlined,
                                size: 64, color: colorScheme.outlineVariant),
                            const SizedBox(height: 16),
                            Text(locale == 'ru' ? 'Нет умений' : 'No traits',
                                style: TextStyle(
                                    color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // --- Class Specific Dashboards (with Render Guards) ---

                          // MONK GUARD
                          if (classId.contains('monk'))
                            _safeBuildWidget(() {
                              final martialArts = _findFeatureDeep(allFeatures,
                                  ['martial_arts', 'martial-arts']);
                              if (monkKiFeature == null && martialArts == null)
                                return const SizedBox.shrink();
                              return KiTrackerWidget(
                                character: widget.character,
                                kiFeature: monkKiFeature ??
                                    CharacterFeature(
                                      id: 'ki_fallback',
                                      nameEn: 'Ki',
                                      nameRu: 'Энергия Ци',
                                      descriptionEn: '',
                                      descriptionRu: '',
                                      type: FeatureType.resourcePool,
                                      minLevel: 2,
                                      resourcePool: ResourcePool(
                                          currentUses: 0,
                                          maxUses: 0,
                                          recoveryType: RecoveryType.shortRest),
                                    ),
                                onChanged: () => setState(() {}),
                              );
                            }),

                          // BARBARIAN GUARD
                          if (classId.contains('barbarian') &&
                              barbarianRageFeature != null)
                            _safeBuildWidget(() => RageControlWidget(
                                  character: widget.character,
                                  rageFeature: barbarianRageFeature,
                                  onChanged: () => setState(() {}),
                                )),

                          // ROGUE GUARD
                          if (classId.contains('rogue') &&
                              rogueSneakAttack != null)
                            _safeBuildWidget(() =>
                                RogueToolsWidget(character: widget.character)),

                          // FIGHTER GUARD
                          if (classId.contains('fighter') &&
                              (fighterSecondWind != null ||
                                  fighterActionSurge != null ||
                                  fighterIndomitable != null))
                            _safeBuildWidget(() => FighterCombatWidget(
                                  character: widget.character,
                                  secondWindFeature: fighterSecondWind,
                                  actionSurgeFeature: fighterActionSurge,
                                  indomitableFeature: fighterIndomitable,
                                  onChanged: () => setState(() {}),
                                )),

                          // BARD GUARD
                          if (classId.contains('bard') &&
                              bardInspiration != null)
                            _safeBuildWidget(() => BardInspirationWidget(
                                  character: widget.character,
                                  inspirationFeature: bardInspiration,
                                  onChanged: () => setState(() {}),
                                )),

                          // PALADIN GUARD
                          if (classId.contains('paladin'))
                            _safeBuildWidget(() {
                              if (paladinLayOnHands == null &&
                                  paladinDivineSense == null &&
                                  paladinChannelDivinity == null) {
                                return const SizedBox.shrink();
                              }
                              return PaladinDivineWidget(
                                character: widget.character,
                                // Provide fallback if LoH is missing but other Paladin features exist
                                layOnHands: paladinLayOnHands ??
                                    CharacterFeature(
                                      id: 'lay_on_hands_fallback',
                                      nameEn: 'Lay on Hands',
                                      nameRu: 'Наложение рук',
                                      descriptionEn: '',
                                      descriptionRu: '',
                                      type: FeatureType.resourcePool,
                                      minLevel: 1,
                                      resourcePool: ResourcePool(
                                          currentUses: 0,
                                          maxUses: 0,
                                          recoveryType: RecoveryType.longRest),
                                    ),
                                divineSense: paladinDivineSense,
                                channelDivinityResource: paladinChannelDivinity,
                                channelDivinitySpells: paladinChannelSpells,
                                onChanged: () => setState(() {}),
                              );
                            }),

                          // SORCERER GUARD
                          if (classId.contains('sorcerer'))
                            _safeBuildWidget(() {
                              if (sorceryPoints == null &&
                                  metamagicOptions.isEmpty &&
                                  sorcererAncestry.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return SorcererMagicWidget(
                                character: widget.character,
                                sorceryPoints: sorceryPoints,
                                metamagic: metamagicOptions,
                                ancestryFeatures: sorcererAncestry,
                                onChanged: () => setState(() {}),
                              );
                            }),

                          // WARLOCK GUARD
                          if (classId.contains('warlock'))
                            _safeBuildWidget(() {
                              if (warlockPatron == null &&
                                  warlockPactBoon == null &&
                                  warlockInvocations.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return WarlockMagicWidget(
                                character: widget.character,
                                patron: warlockPatron,
                                pactBoon: warlockPactBoon,
                                invocations: warlockInvocations,
                                onChanged: () => setState(() {}),
                              );
                            }),

                          // DRUID GUARD
                          if (classId.contains('druid'))
                            _safeBuildWidget(() => DruidMagicWidget(
                                  character: widget.character,
                                  onStateChanged: () => setState(() {}),
                                )),

                          // WIZARD GUARD
                          if (classId.contains('wizard'))
                            _safeBuildWidget(() => WizardMagicWidget(
                                  character: widget.character,
                                  onStateChanged: () => setState(() {}),
                                )),

                          // CLERIC GUARD
                          if (classId.contains('cleric'))
                            _safeBuildWidget(() => ClericMagicWidget(
                                  character: widget.character,
                                  onStateChanged: () => setState(() {}),
                                )),

                          // RANGER GUARD
                          if (classId.contains('ranger') ||
                              classId.contains('следопыт'))
                            _safeBuildWidget(() {
                              if (primevalAwareness == null &&
                                  widget.character.favoredEnemies.isEmpty &&
                                  widget.character.naturalExplorers.isEmpty &&
                                  widget.character.beastName == null) {
                                return const SizedBox.shrink();
                              }
                              return RangerSurvivalWidget(
                                character: widget.character,
                                primevalAwareness: primevalAwareness,
                                onChanged: () => setState(() {}),
                              );
                            }),

                          // --- General Lists ---
                          if (resourceFeatures.isNotEmpty) ...[
                            _buildSectionHeader(l10n.resources.toUpperCase()),
                            ..._buildResourceSection(resourceFeatures, locale),
                            const SizedBox(height: 16),
                          ],

                          if (activeFeatures.isNotEmpty) ...[
                            _buildSectionHeader(
                                l10n.activeAbilities.toUpperCase()),
                            ..._buildActiveSection(
                                activeFeatures, locale, l10n),
                            const SizedBox(height: 16),
                          ],

                          if (showMagicSection) ...[
                            _buildSectionHeader(
                              l10n.magic.toUpperCase(),
                              trailing: _buildPreparationCounter(context, l10n),
                            ),
                            _buildMagicSection(context, l10n,
                                showCounter: false),
                            const SizedBox(height: 16),

                            // --- Wizard VIP Spells ---
                            if (isWizard &&
                                widget.character.spellMasterySpells
                                    .isNotEmpty) ...[
                              _buildSpellMasteryBlock(context, l10n, locale),
                              const SizedBox(height: 16),
                            ],
                            if (isWizard &&
                                widget
                                    .character.signatureSpells.isNotEmpty) ...[
                              _buildSignatureSpellsBlock(context, l10n, locale),
                              const SizedBox(height: 16),
                            ],

                            if (displaySpells.isEmpty)
                              Center(
                                  child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.auto_fix_off,
                                        size: 48,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.3)),
                                    const SizedBox(height: 8),
                                    Text(l10n.noSpellsLearned,
                                        style: TextStyle(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.5))),
                                  ],
                                ),
                              ))
                            else
                              ..._buildSpellList(spellsByLevel, locale, l10n),
                            const SizedBox(height: 16),
                          ],

                          if (passiveFeatures.isNotEmpty) ...[
                            _buildSectionHeader(
                                l10n.passiveTraits.toUpperCase()),
                            _buildPassiveSection(
                                passiveFeatures, locale, l10n, colorScheme),
                          ],

                          const SizedBox(height: 80),
                        ],
                      ),
              ),
            ],
          ),
          if (showMagicSection)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (context) =>
                              SpellAlmanacScreen(character: widget.character),
                        ),
                      )
                      .then((_) => setState(() {}));
                },
                icon: const Icon(Icons.library_books),
                label: Text(l10n.spellAlmanac),
              ),
            ),
        ],
      );
    } catch (e, stack) {
      debugPrint('CRITICAL ERROR in AbilitiesTab.build: $e');
      debugPrint(stack.toString());
      // RED SCREEN OF DEATH
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              SelectableText(
                'CRITICAL ERROR:\n$e\n\nSTACK:\n$stack',
                style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Wraps a widget builder in try-catch to prevent one bad item from crashing the whole list
  Widget _safeBuildWidget(Widget Function() builder) {
    try {
      return builder();
    } catch (e) {
      debugPrint('Error building widget item: $e');
      return const SizedBox.shrink();
    }
  }

  // --- Imperative List Builders (Fault Tolerant) ---

  List<Widget> _buildResourceSection(
      List<CharacterFeature> features, String locale) {
    final List<Widget> children = [];
    for (final feature in features) {
      // PROMPT: Isolate the Crash (True Try-Catch)
      try {
        final id = feature.id ?? 'NULL_ID';
        final name = feature.nameEn ?? 'No Name';
        debugPrint('Processing resource feature: $id ($name)');

        children.add(_buildResourceFeature(feature, locale));
      } catch (e, stack) {
        debugPrint('🔥 CRITICAL FAIL on feature: ${feature.id} -> $e');
        debugPrint('Stack: $stack');
        // Add a red placeholder so user knows something broke
        children.add(Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Error loading resource: ${feature.nameEn ?? "Unknown"}',
              style: const TextStyle(color: Colors.red)),
        ));
      }
    }
    return children;
  }

  List<Widget> _buildActiveSection(
      List<CharacterFeature> features, String locale, AppLocalizations l10n) {
    final List<Widget> children = [];
    for (final feature in features) {
      // PROMPT: Isolate the Crash (True Try-Catch)
      try {
        final id = feature.id ?? 'NULL_ID';
        final name = feature.nameEn ?? 'No Name';
        debugPrint('Processing active feature: $id ($name)');

        children.add(_buildActiveFeature(feature, locale, l10n));
      } catch (e, stack) {
        debugPrint('🔥 CRITICAL FAIL on feature: ${feature.id} -> $e');
        debugPrint('Stack: $stack');
        children.add(Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
              'Error loading active feature: ${feature.nameEn ?? "Unknown"}',
              style: const TextStyle(color: Colors.red)),
        ));
      }
    }
    return children;
  }

  Widget _buildPassiveSection(List<CharacterFeature> features, String locale,
      AppLocalizations l10n, ColorScheme colorScheme) {
    debugPrint('--- Building Passive Section (${features.length} items) ---');
    try {
      // Safely build subtitle string
      final List<String> featureNames = [];
      for (final f in features) {
        try {
          featureNames.add(f.getName(locale));
        } catch (_) {}
      }
      final subtitle = featureNames.join(', ');

      // Safely build children list
      final List<Widget> children = [];
      for (final feature in features) {
        // PROMPT: Isolate the Crash (True Try-Catch)
        try {
          final id = feature.id ?? 'NULL_ID';
          final name = feature.nameEn ?? 'No Name';
          debugPrint('Processing passive item: $name (ID: $id)');

          // PROMPT: Sanitize Text() widgets
          children.add(ListTile(
            title: Text(feature.getName(locale) ?? 'Unknown Feature',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(feature.getDescription(locale) ?? '',
                style: const TextStyle(fontSize: 12)),
            dense: true,
            leading: Icon(_getFeatureIcon(feature.iconName),
                size: 18, color: colorScheme.secondary.withValues(alpha: 0.7)),
          ));
        } catch (e, stack) {
          debugPrint('🔥 CRITICAL FAIL on feature: ${feature.id} -> $e');
          debugPrint('Stack: $stack');
          children.add(ListTile(
            title: Text('Error loading: ${feature.nameEn ?? "Unknown"}',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: const Text('Details in logs',
                style: TextStyle(color: Colors.red)),
            leading: const Icon(Icons.error, color: Colors.red),
          ));
        }
      }

      return Card(
        elevation: 1,
        child: ExpansionTile(
          title: Text('${features.length} ${l10n.passiveTraits}'),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          leading: Icon(Icons.psychology, color: colorScheme.secondary),
          children: children,
        ),
      );
    } catch (e) {
      debugPrint('Error building passive section: $e');
      return const SizedBox.shrink();
    }
  }

  List<Widget> _buildSpellList(Map<int, List<Spell>> spellsByLevel,
      String locale, AppLocalizations l10n) {
    final List<Widget> children = [];
    final levels = spellsByLevel.keys.toList()..sort();

    for (final level in levels) {
      try {
        final spells = spellsByLevel[level] ?? [];
        if (spells.isNotEmpty) {
          children.add(_buildSpellLevelGroup(level, spells, locale, l10n));
        }
      } catch (e) {
        debugPrint('Error rendering spell level $level: $e');
      }
    }
    return children;
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

  Widget? _buildPreparationCounter(
      BuildContext context, AppLocalizations l10n) {
    try {
      final classId = widget.character.characterClass.toLowerCase();
      final isPreparedCaster =
          SpellcastingService.getSpellcastingType(classId) == 'prepared';
      if (!isPreparedCaster) return null;

      final colorScheme = Theme.of(context).colorScheme;
      final maxPrepared =
          SpellcastingService.getMaxPreparedSpells(widget.character);

      int currentPrepared = 0;
      for (final id in widget.character.preparedSpells) {
        final s = SpellService.getSpellById(id);
        if (s != null && s.level > 0) currentPrepared++;
      }

      final isOverLimit = currentPrepared > maxPrepared;
      final isFull = currentPrepared == maxPrepared;
      final color = isOverLimit
          ? colorScheme.error
          : (isFull ? colorScheme.primary : colorScheme.onSurfaceVariant);

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
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 0.8)),
            ),
            Text(
              '$currentPrepared/$maxPrepared',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      );
    } catch (e) {
      return null;
    }
  }

  Widget _buildResourceFeature(CharacterFeature feature, String locale) {
    // NUCLEAR OPTION: Paranoia
    final pool = feature.resourcePool;
    if (pool == null) return const SizedBox.shrink();

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
                        Icon(_getFeatureIcon(feature.iconName),
                            size: 20, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(feature.getName(locale) ?? 'Unknown',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  Text('${pool.currentUses}/${pool.maxUses}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: pool.isEmpty
                              ? colorScheme.error
                              : colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pool.maxUses > 0
                            ? pool.currentUses / pool.maxUses
                            : 0,
                        color: pool.isEmpty
                            ? colorScheme.error
                            : colorScheme.primary,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: pool.isEmpty
                        ? null
                        : () => setState(() {
                              pool.use(1);
                              widget.character.save();
                            }),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    iconSize: 24,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: pool.isFull
                        ? null
                        : () => setState(() {
                              pool.restore(1);
                              widget.character.save();
                            }),
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

  Widget _buildActiveFeature(
      CharacterFeature feature, String locale, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;

    // Find linked resource for display
    String? resourceCost;
    if (feature.consumption != null) {
      final res = _findResourceFeature(feature.consumption!.resourceId);
      if (res != null) {
        resourceCost =
            '${feature.consumption!.amount} ${res.getName(locale) ?? "Resource"}';
      }
    } else if (feature.usageCostId != null) {
      try {
        final usageCostId = feature.usageCostId!;
        final res = widget.character.features
            .where(
              (f) =>
                  f.resourcePool != null &&
                  ((f.id ?? '') == usageCostId ||
                      (f.id ?? '').endsWith('-$usageCostId') ||
                      (f.id ?? '').startsWith('$usageCostId-') ||
                      (usageCostId == 'ki' && (f.id ?? '').contains('ki'))),
            )
            .firstOrNull;
        if (res != null) {
          resourceCost = '1 ${res.getName(locale) ?? "Resource"}';
        }
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
                    child: Icon(_getFeatureIcon(feature.iconName),
                        size: 20, color: colorScheme.onSecondaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(feature.getName(locale) ?? 'Unknown',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        if (feature.actionEconomy != null)
                          Text(
                            _getLocalizedActionEconomy(
                                    l10n, feature.actionEconomy ?? '')
                                .toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(feature.getDescription(locale) ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colorScheme.onSurfaceVariant, fontSize: 13)),
              if (resourceCost != null ||
                  feature.usageCostId != null ||
                  ((feature.nameEn ?? '').contains('Channel Divinity'))) ...[
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

  Widget _buildMagicSection(BuildContext context, AppLocalizations l10n,
      {bool showCounter = true}) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final isPactMagic = SpellcastingService.getSpellcastingType(
            widget.character.characterClass) ==
        'pact_magic';
    final maxPrepared =
        SpellcastingService.getMaxPreparedSpells(widget.character);
    final currentPrepared = widget.character.preparedSpells.length;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (showCounter) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            : colorScheme.onSecondaryContainer),
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
                _buildMagicStat(
                    l10n.spellAbility,
                    _getAbilityAbbr(
                        l10n,
                        SpellcastingService.getSpellcastingAbilityName(
                            widget.character.characterClass))),
                Container(
                    width: 1, height: 30, color: colorScheme.outlineVariant),
                _buildMagicStat(l10n.spellSaveDC,
                    '${SpellcastingService.getSpellSaveDC(widget.character)}'),
                Container(
                    width: 1, height: 30, color: colorScheme.outlineVariant),
                _buildMagicStat(l10n.spellAttack,
                    '+${SpellcastingService.getSpellAttackBonus(widget.character)}'),
              ],
            ),
            if (widget.character.maxSpellSlots.any((s) => s > 0)) ...[
              const Divider(height: 32),
              if (isPactMagic)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                      locale == 'ru'
                          ? 'Магия Договора (Короткий отдых)'
                          : 'Pact Magic (Short Rest)',
                      style: TextStyle(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
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
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
      ],
    );
  }

  Widget _buildSpellLevelGroup(
      int level, List<Spell> spells, String locale, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = level == 0
        ? l10n.cantrips.toUpperCase()
        : l10n.levelLabel(level).toUpperCase();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('spell_level_$level'),
        initiallyExpanded: _expandedLevels[level] ?? true,
        onExpansionChanged: (expanded) => _expandedLevels[level] = expanded,
        tilePadding: EdgeInsets.zero,
        title: Text(title,
            style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                fontSize: 14)),
        children: spells.map((spell) {
          // Basic validation to prevent crashes if spell data is weird
          try {
            final characterClassId =
                widget.character.characterClass.toLowerCase();
            final isSpontaneous = [
              'sorcerer',
              'bard',
              'warlock',
              'ranger',
              'чародей',
              'бард',
              'колдун',
              'следопыт'
            ].contains(characterClassId);
            final isPactMagic =
                SpellcastingService.getSpellcastingType(characterClassId) ==
                    'pact_magic';

            final isPrepared = isSpontaneous ||
                widget.character.preparedSpells.contains(spell.id);

            // Allow casting if level 0 (cantrip) OR standard slots available
            // OR if Warlock Arcanum level (>=6) - handled by specific logic inside _showCastSpellDialog
            bool canCast = spell.level == 0;
            if (!canCast) {
              // Pact Magic override for Arcanum levels
              if (isPactMagic) {
                if (spell.level >= 6) {
                  canCast = true;
                } else {
                  // Check if ANY pact slots remain. They are all same level.
                  final pactSlots =
                      SpellSlotsTable.getPactSlots(widget.character.level);
                  final pactSlotLevel = pactSlots
                      .length; // Length corresponds to max level (e.g. 5)

                  if (pactSlotLevel > 0 &&
                      pactSlotLevel <= widget.character.spellSlots.length) {
                    canCast =
                        widget.character.spellSlots[pactSlotLevel - 1] > 0;
                  }
                }
              } else {
                canCast = (spell.level <= widget.character.spellSlots.length &&
                    widget.character.spellSlots[spell.level - 1] > 0);
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
                leading: isSpontaneous
                    ? null
                    : GestureDetector(
                        onTap: () {
                          setState(() {
                            final success =
                                SpellPreparationManager.togglePreparation(
                                    widget.character, spell, context);
                            if (!success) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: const Text(
                                    'Cannot prepare more spells! Limit reached.'), // Using hardcoded English as fallback or use a suitable l10n key if found
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ));
                            }
                          });
                        },
                        child: Icon(isPrepared ? Icons.star : Icons.star_border,
                            color:
                                isPrepared ? Colors.amber : colorScheme.outline,
                            size: 24),
                      ),
                title: Text(spell.getName(locale),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    SpellUtils.getLocalizedSchool(l10n, spell.school),
                    style:
                        TextStyle(color: colorScheme.secondary, fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.auto_fix_high),
                  onPressed: canCast
                      ? () => _showCastSpellDialog(spell, locale, l10n)
                      : null,
                  color: canCast
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.2),
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
          } catch (e) {
            debugPrint('Error building spell tile for ${spell.id}: $e');
            return const SizedBox.shrink();
          }
        }).toList(),
      ),
    );
  }

  IconData _getFeatureIcon(String? iconName) {
    switch (iconName) {
      case 'healing':
        return Icons.favorite;
      case 'visibility':
        return Icons.visibility;
      case 'flash_on':
        return Icons.flash_on;
      case 'swords':
        return Icons.shield;
      case 'auto_fix_high':
        return Icons.auto_fix_high;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'filter_2':
        return Icons.filter_2;
      case 'security':
        return Icons.security;
      case 'back_hand':
        return Icons.back_hand;
      case 'wifi_tethering':
        return Icons.wifi_tethering;
      default:
        return Icons.star;
    }
  }

  // --- Wizard VIP Block Builders ---

  void _showFeatureLore(String featureId) {
    final feature = FeatureService.getFeatureById(featureId);
    if (feature != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => FeatureDetailsSheet(feature: feature),
      );
    }
  }

  Widget _buildSpellMasteryBlock(
      BuildContext context, AppLocalizations l10n, String locale) {
    final theme = Theme.of(context);
    final spells = widget.character.spellMasterySpells
        .map((id) => SpellService.getSpellById(id))
        .whereType<Spell>()
        .toList();

    return Card(
      elevation: 4,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.tertiary, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Giant Clickable Area
          InkWell(
            onTap: () => _showFeatureLore('spell-mastery'),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0), // Generous padding
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      locale == 'ru'
                          ? "Мастерство заклинаний"
                          : "Spell Mastery",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ),
                  Icon(Icons.auto_awesome, color: theme.colorScheme.tertiary),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: spells
                  .map((spell) => _buildVipSpellCard(
                      context, spell, locale, l10n, "Mastery"))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureSpellsBlock(
      BuildContext context, AppLocalizations l10n, String locale) {
    final theme = Theme.of(context);
    final spells = widget.character.signatureSpells
        .map((id) => SpellService.getSpellById(id))
        .whereType<Spell>()
        .toList();

    return Card(
      elevation: 4,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.tertiary, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Giant Clickable Area
          InkWell(
            onTap: () => _showFeatureLore('signature-spell'),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0), // Generous padding
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      locale == 'ru'
                          ? "Фирменные заклинания"
                          : "Signature Spells",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ),
                  Icon(Icons.auto_fix_high, color: theme.colorScheme.tertiary),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: spells
                  .map((spell) => _buildVipSpellCard(
                      context, spell, locale, l10n, "Signature"))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipSpellCard(BuildContext context, Spell spell, String locale,
      AppLocalizations l10n, String type) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSignature = type == "Signature";
    final isUsed = isSignature &&
        (widget.character.signatureSpellsUsed[spell.id] ?? false);

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
        title: Text(spell.getName(locale),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: isUsed ? TextDecoration.lineThrough : null,
              color:
                  isUsed ? colorScheme.onSurface.withValues(alpha: 0.5) : null,
            )),
        subtitle: Text(SpellUtils.getLocalizedSchool(l10n, spell.school),
            style: TextStyle(color: colorScheme.secondary, fontSize: 11)),
        trailing: IconButton(
          icon: Icon(isUsed
              ? Icons.refresh
              : Icons
                  .auto_fix_high), // Changed icon for "Used" state to show it can be upcast
          onPressed: () {
            // --- Instant Cast Logic (UX Fix) ---
            if (type == "Mastery") {
              // Mastery is always instant free
              _handleInstantVipCast(spell, locale, l10n, "Mastery");
            } else if (isSignature && !isUsed) {
              // Signature first use is instant free
              _handleInstantVipCast(spell, locale, l10n, "Signature");
            } else {
              // Signature subsequent use shows normal dialog
              _showCastSpellDialog(spell, locale, l10n);
            }
          },
          color: isUsed ? colorScheme.primary : colorScheme.primary,
          tooltip: l10n.castSpell,
        ),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => SpellDetailsSheet(
            spell: spell,
            character: widget.character,
            onToggleKnown: null, // VIP spells are permanent
          ),
        ),
      ),
    );
  }

  void _handleInstantVipCast(
      Spell spell, String locale, AppLocalizations l10n, String type) {
    setState(() {
      if (type == "Signature") {
        widget.character.signatureSpellsUsed[spell.id] = true;
        widget.character.save();
      }

      final message = locale == 'ru'
          ? '${spell.getName(locale)} наложено (${type == "Mastery" ? "Мастерство заклинаний" : "Фирменное заклинание"})'
          : '${spell.getName(locale)} cast (${type == "Mastery" ? "Spell Mastery" : "Signature Spell"})';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              Theme.of(context).colorScheme.tertiary, // Golden color for VIP
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }
}
