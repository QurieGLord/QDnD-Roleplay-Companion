import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
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
import 'abilities/abilities_empty_state.dart';
import 'abilities/abilities_quick_jump_row.dart';
import 'abilities/abilities_reveal.dart';
import 'abilities/abilities_shell_tokens.dart';
import 'abilities/abilities_tab_logic.dart';
import 'abilities/sections/active_abilities_section.dart';
import 'abilities/sections/magic_section.dart';
import 'abilities/sections/passive_traits_section.dart';
import 'abilities/sections/resources_section.dart';
import 'abilities/sections/spell_level_group.dart';
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
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _resourcesSectionAnchor = GlobalKey();
  final GlobalKey _activeSectionAnchor = GlobalKey();
  final GlobalKey _magicSectionAnchor = GlobalKey();
  final GlobalKey _passiveSectionAnchor = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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

  bool _shouldShowInList(CharacterFeature feature) =>
      AbilitiesTabLogic(widget.character).shouldShowInList(feature);

  CharacterFeature? _findFeatureDeep(
          List<CharacterFeature> list, List<String> keywords) =>
      AbilitiesTabLogic(widget.character).findFeatureDeep(list, keywords);

  CharacterFeature? _findResourceFeature(String id) =>
      AbilitiesTabLogic(widget.character).findResourceFeature(id);

  List<CharacterFeature> _deduplicateAndFilterFeatures(
          List<CharacterFeature> list, String locale) =>
      AbilitiesTabLogic(widget.character)
          .deduplicateAndFilterFeatures(list, locale);

  // --- Actions ---

  void _useFeature(
      CharacterFeature feature, String locale, AppLocalizations l10n) {
    try {
      // 0. Find Linked Resource
      CharacterFeature? resource;

      // NUCLEAR OPTION: Safe access
      final usageCostId = feature.usageCostId;
      final consumption = feature.consumption;
      final featureId = feature.id;

      if (usageCostId != null) {
        try {
          // Deep resource search
          resource = widget.character.features.where((f) {
            if (f.resourcePool == null) return false;
            final fId = (f.id).toLowerCase();
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
                  ((f.id) == 'channel-divinity' ||
                      (f.id).startsWith('channel-divinity-1-rest')))
              .firstOrNull;
        } catch (_) {}
      }

      // 1. Validate Resource
      if (resource == null || resource.resourcePool == null) {
        if ((feature.nameEn).contains('Channel Divinity')) {
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
          AppSnackBar.warning(
            context,
            'No charges left for ${resource.getName(locale)}!',
          );
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
        AppSnackBar.success(
          context,
          '${feature.getName(locale)} used! (-$cost ${resource.getName(locale)})',
          duration: const Duration(milliseconds: 1500),
        );
      } else {
        AppSnackBar.warning(
          context,
          'Not enough ${resource.getName(locale)} (Need $cost)!',
        );
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
          AppSnackBar.success(
            context,
            l10n.useChannelDivinity(pool.currentUses),
            duration: const Duration(milliseconds: 1500),
          );
        } else {
          AppSnackBar.warning(context, l10n.noChannelDivinity);
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
                  AppSnackBar.success(
                    context,
                    '${feature.getName(locale)} used! (-$spendAmount ${resource.getName(locale)})',
                  );
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

    // === WARLOCK PACT MAGIC BYPASS ===
    // Warlocks never see the cast dialog. Their slots auto-resolve.
    if (isPactMagic) {
      if (spell.level >= 6) {
        // --- MYSTIC ARCANUM (6-9 circle) ---
        final arcanumId = 'mystic_arcanum_${spell.level}th';
        final arcanumFeature = widget.character.features
            .where((f) =>
                f.id == arcanumId ||
                ((f.nameEn).contains('Mystic Arcanum') &&
                    (f.nameEn).contains('${spell.level}th')))
            .firstOrNull;

        if (arcanumFeature?.resourcePool != null &&
            arcanumFeature!.resourcePool!.currentUses > 0) {
          setState(() {
            arcanumFeature.resourcePool!.currentUses = 0;
            widget.character.save();
          });
          AppSnackBar.success(
            context,
            locale == 'ru'
                ? '${spell.getName(locale)} — Таинственный Арканум ${spell.level} круга!'
                : '${spell.getName(locale)} — Mystic Arcanum (${spell.level}th level)!',
            duration: const Duration(seconds: 2),
          );
        } else {
          AppSnackBar.warning(
            context,
            locale == 'ru'
                ? 'Арканум ${spell.level} круга уже использован!'
                : 'Arcanum (${spell.level}th level) already used!',
          );
        }
        return;
      }

      // --- PACT MAGIC (1-5 circle) ---
      final pactSlots = SpellSlotsTable.getPactSlots(widget.character.level);
      int pactSlotLevel = 0;
      for (int i = 0; i < pactSlots.length; i++) {
        if (pactSlots[i] > 0) pactSlotLevel = i + 1;
      }

      if (pactSlotLevel <= 0) return;

      // Check available slots
      while (widget.character.spellSlots.length < pactSlotLevel) {
        widget.character.spellSlots.add(0);
      }
      final currentSlots = widget.character.spellSlots[pactSlotLevel - 1];

      if (currentSlots > 0) {
        setState(() {
          widget.character.spellSlots[pactSlotLevel - 1]--;
          widget.character.save();
        });

        String message;
        if (pactSlotLevel > spell.level) {
          // Upcast notification
          message = locale == 'ru'
              ? '${spell.getName(locale)} усилено до $pactSlotLevel круга!'
              : '${spell.getName(locale)} upcast to level $pactSlotLevel!';
        } else {
          message = locale == 'ru'
              ? '${spell.getName(locale)} наложено ($pactSlotLevel круг)'
              : '${spell.getName(locale)} cast (level $pactSlotLevel)';
        }
        AppSnackBar.success(
          context,
          message,
          duration: const Duration(seconds: 2),
        );
      } else {
        AppSnackBar.warning(context, l10n.noSlotsAvailable);
      }
      return;
    }
    // === END WARLOCK BYPASS ===

    final availableSlots = <int>[];
    for (int i = 1; i <= widget.character.maxSpellSlots.length; i++) {
      if (widget.character.spellSlots[i - 1] > 0) {
        if (i >= spell.level) {
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
      AppSnackBar.warning(
        context,
        l10n.noSlotsAvailable,
        duration: const Duration(seconds: 2),
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

      AppSnackBar.success(
        context,
        message,
        duration: const Duration(seconds: 2),
      );
    });
  }

  bool _isRenderableWidget(Widget widget) {
    return widget is! SizedBox ||
        widget.width != null ||
        widget.height != null ||
        widget.child != null;
  }

  Widget _sectionAnchor({
    required GlobalKey anchorKey,
    required Key testKey,
    required Widget child,
  }) {
    return Container(
      key: anchorKey,
      child: KeyedSubtree(
        key: testKey,
        child: child,
      ),
    );
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return;

    HapticFeedback.selectionClick();
    final disableAnimations =
        MediaQuery.maybeOf(this.context)?.disableAnimations ?? false;
    await Scrollable.ensureVisible(
      context,
      duration: disableAnimations
          ? Duration.zero
          : AbilitiesShellTokens.scrollDuration,
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  void _openSpellAlmanac() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                SpellAlmanacScreen(character: widget.character),
          ),
        )
        .then((_) => setState(() {}));
  }

  void _showFeatureSheet(CharacterFeature feature) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => FeatureDetailsSheet(feature: feature),
    );
  }

  void _showSpellSheet(Spell spell, {VoidCallback? onToggleKnown}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SpellDetailsSheet(
        spell: spell,
        character: widget.character,
        onToggleKnown: onToggleKnown,
      ),
    );
  }

  void _useResource(CharacterFeature feature) {
    final pool = feature.resourcePool;
    if (pool == null || pool.isEmpty) return;

    setState(() {
      pool.use(1);
      widget.character.save();
    });
  }

  void _restoreResource(CharacterFeature feature) {
    final pool = feature.resourcePool;
    if (pool == null || pool.isFull) return;

    setState(() {
      pool.restore(1);
      widget.character.save();
    });
  }

  String? _buildResourceCostLabel(CharacterFeature feature, String locale) {
    if (feature.consumption != null) {
      final resource = _findResourceFeature(feature.consumption!.resourceId);
      if (resource != null) {
        return '${feature.consumption!.amount} ${resource.getName(locale)}';
      }
    } else if (feature.usageCostId != null) {
      try {
        final usageCostId = feature.usageCostId!;
        final resource = widget.character.features
            .where(
              (f) =>
                  f.resourcePool != null &&
                  (f.id == usageCostId ||
                      f.id.endsWith('-$usageCostId') ||
                      f.id.startsWith('$usageCostId-') ||
                      (usageCostId == 'ki' && f.id.contains('ki'))),
            )
            .firstOrNull;
        if (resource != null) {
          return '1 ${resource.getName(locale)}';
        }
      } catch (_) {}
    }

    return null;
  }

  bool _shouldShowUseAction(CharacterFeature feature) {
    return feature.consumption != null ||
        feature.usageCostId != null ||
        feature.nameEn.contains('Channel Divinity');
  }

  Widget _buildMagicEmptyState(AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AbilitiesShellTokens.nestedRadius),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_fix_off,
            size: 40,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.noSpellsLearned,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
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
      final paladinDivineSmite =
          _findFeatureDeep(allFeatures, ['divine-smite', 'divine_smite']);
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
              (f.id).toLowerCase().contains('metamagic') ||
              f.nameEn.toLowerCase().contains('metamagic') ||
              f.nameRu.toLowerCase().contains('метамагия'))
          .toList();

      final sorcererAncestry = allFeatures
          .where((f) =>
              (f.id).toLowerCase().contains('dragon-ancestor') ||
              (f.id).toLowerCase().contains('draconic') ||
              (f.id).toLowerCase().contains('dragon') ||
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
              (f.id).toLowerCase().contains('invocation') ||
              f.nameEn.toLowerCase().contains('invocation') ||
              f.nameRu.toLowerCase().contains('воззвание'))
          .toList();

      List<CharacterFeature> paladinChannelSpells = [];
      if (paladinChannelDivinity != null) {
        paladinChannelSpells = allFeatures
            .where((f) {
              final id = (f.id).toLowerCase();
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

      final featuredModules = <Widget>[];

      void addFeaturedModule(Widget widget) {
        if (_isRenderableWidget(widget)) {
          featuredModules.add(widget);
        }
      }

      if (classId.contains('monk')) {
        addFeaturedModule(_safeBuildWidget(() {
          final martialArts =
              _findFeatureDeep(allFeatures, ['martial_arts', 'martial-arts']);
          if (monkKiFeature == null && martialArts == null) {
            return const SizedBox.shrink();
          }
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
                    recoveryType: RecoveryType.shortRest,
                  ),
                ),
            onChanged: () => setState(() {}),
          );
        }));
      }

      if (classId.contains('barbarian') && barbarianRageFeature != null) {
        addFeaturedModule(_safeBuildWidget(() => RageControlWidget(
              character: widget.character,
              rageFeature: barbarianRageFeature,
              onChanged: () => setState(() {}),
            )));
      }

      if (classId.contains('rogue') && rogueSneakAttack != null) {
        addFeaturedModule(_safeBuildWidget(
            () => RogueToolsWidget(character: widget.character)));
      }

      if (classId.contains('fighter') &&
          (fighterSecondWind != null ||
              fighterActionSurge != null ||
              fighterIndomitable != null)) {
        addFeaturedModule(_safeBuildWidget(() => FighterCombatWidget(
              character: widget.character,
              secondWindFeature: fighterSecondWind,
              actionSurgeFeature: fighterActionSurge,
              indomitableFeature: fighterIndomitable,
              onChanged: () => setState(() {}),
            )));
      }

      if (classId.contains('bard') && bardInspiration != null) {
        addFeaturedModule(_safeBuildWidget(() => BardInspirationWidget(
              character: widget.character,
              inspirationFeature: bardInspiration,
              onChanged: () => setState(() {}),
            )));
      }

      if (classId.contains('paladin')) {
        addFeaturedModule(_safeBuildWidget(() {
          if (paladinLayOnHands == null &&
              paladinDivineSense == null &&
              paladinChannelDivinity == null) {
            return const SizedBox.shrink();
          }
          return PaladinDivineWidget(
            character: widget.character,
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
                    recoveryType: RecoveryType.longRest,
                  ),
                ),
            divineSense: paladinDivineSense,
            divineSmite: paladinDivineSmite,
            channelDivinityResource: paladinChannelDivinity,
            channelDivinitySpells: paladinChannelSpells,
            onChanged: () => setState(() {}),
          );
        }));
      }

      if (classId.contains('sorcerer')) {
        addFeaturedModule(_safeBuildWidget(() {
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
        }));
      }

      if (classId.contains('warlock')) {
        addFeaturedModule(_safeBuildWidget(() {
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
        }));
      }

      if (classId.contains('druid')) {
        addFeaturedModule(_safeBuildWidget(() => DruidMagicWidget(
              character: widget.character,
              onStateChanged: () => setState(() {}),
            )));
      }

      if (classId.contains('wizard')) {
        addFeaturedModule(_safeBuildWidget(() => WizardMagicWidget(
              character: widget.character,
              onStateChanged: () => setState(() {}),
            )));
      }

      if (classId.contains('cleric')) {
        addFeaturedModule(_safeBuildWidget(() => ClericMagicWidget(
              character: widget.character,
              onStateChanged: () => setState(() {}),
            )));
      }

      if (classId.contains('ranger') || classId.contains('следопыт')) {
        addFeaturedModule(_safeBuildWidget(() {
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
        }));
      }

      final hasFeaturedModules = featuredModules.isNotEmpty;
      final isEmpty = featuredModules.isEmpty &&
          resourceFeatures.isEmpty &&
          activeFeatures.isEmpty &&
          !showMagicSection &&
          passiveFeatures.isEmpty;

      final quickJumpItems = <AbilitiesQuickJumpItem>[
        if (resourceFeatures.isNotEmpty)
          AbilitiesQuickJumpItem(
            label: l10n.resources,
            icon: Icons.tune,
            onTap: () => _scrollToSection(_resourcesSectionAnchor),
          ),
        if (activeFeatures.isNotEmpty)
          AbilitiesQuickJumpItem(
            label: l10n.activeAbilities,
            icon: Icons.bolt,
            onTap: () => _scrollToSection(_activeSectionAnchor),
          ),
        if (showMagicSection)
          AbilitiesQuickJumpItem(
            label: l10n.magic,
            icon: Icons.auto_awesome,
            onTap: () => _scrollToSection(_magicSectionAnchor),
          ),
        if (passiveFeatures.isNotEmpty)
          AbilitiesQuickJumpItem(
            label: l10n.passiveTraits,
            icon: Icons.auto_stories,
            onTap: () => _scrollToSection(_passiveSectionAnchor),
          ),
      ];

      final magicVipBlocks = <Widget>[
        if (isWizard && widget.character.spellMasterySpells.isNotEmpty)
          _buildSpellMasteryBlock(context, l10n, locale),
        if (isWizard && widget.character.signatureSpells.isNotEmpty)
          _buildSignatureSpellsBlock(context, l10n, locale),
      ];

      final children = <Widget>[];
      final hasQuickJumpRow = hasFeaturedModules && quickJumpItems.length >= 3;
      var hasAddedGenericSection = false;

      if (hasFeaturedModules) {
        children.add(
          KeyedSubtree(
            key: const Key('abilities_featured_modules'),
            child: Column(
              children: [
                for (int index = 0; index < featuredModules.length; index++)
                  AbilitiesReveal(
                    delay: Duration(milliseconds: index * 36),
                    beginOffset: const Offset(0, 0.035),
                    child: featuredModules[index],
                  ),
              ],
            ),
          ),
        );
      }

      if (hasQuickJumpRow) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: 8));
        }
        children.add(
          AbilitiesReveal(
            delay: const Duration(milliseconds: 72),
            child: AbilitiesQuickJumpRow(items: quickJumpItems),
          ),
        );
      }

      if (resourceFeatures.isNotEmpty) {
        if (children.isNotEmpty) {
          children.add(
            SizedBox(
              height: hasFeaturedModules &&
                      !hasQuickJumpRow &&
                      !hasAddedGenericSection
                  ? 0
                  : AbilitiesShellTokens.sectionSpacing,
            ),
          );
        }
        children.add(
          _sectionAnchor(
            anchorKey: _resourcesSectionAnchor,
            testKey: const Key('abilities_section_resources'),
            child: AbilitiesReveal(
              delay: const Duration(milliseconds: 96),
              child: AbilitiesResourcesSection(
                features: resourceFeatures,
                locale: locale,
                onOpenDetails: _showFeatureSheet,
                onIncrement: _restoreResource,
                onDecrement: _useResource,
              ),
            ),
          ),
        );
        hasAddedGenericSection = true;
      }

      if (activeFeatures.isNotEmpty) {
        if (children.isNotEmpty) {
          children.add(
            SizedBox(
              height: hasFeaturedModules &&
                      !hasQuickJumpRow &&
                      !hasAddedGenericSection
                  ? 0
                  : AbilitiesShellTokens.sectionSpacing,
            ),
          );
        }
        children.add(
          _sectionAnchor(
            anchorKey: _activeSectionAnchor,
            testKey: const Key('abilities_section_active'),
            child: AbilitiesReveal(
              delay: const Duration(milliseconds: 128),
              child: AbilitiesActiveAbilitiesSection(
                features: activeFeatures,
                locale: locale,
                actionLabelBuilder: (economy) =>
                    _getLocalizedActionEconomy(l10n, economy),
                resourceCostBuilder: (feature) =>
                    _buildResourceCostLabel(feature, locale),
                shouldShowUseAction: (feature) => _shouldShowUseAction(feature),
                onOpenDetails: _showFeatureSheet,
                onUseFeature: (feature) => _useFeature(feature, locale, l10n),
              ),
            ),
          ),
        );
        hasAddedGenericSection = true;
      }

      if (showMagicSection) {
        if (children.isNotEmpty) {
          children.add(
            SizedBox(
              height: hasFeaturedModules &&
                      !hasQuickJumpRow &&
                      !hasAddedGenericSection
                  ? 0
                  : AbilitiesShellTokens.sectionSpacing,
            ),
          );
        }
        children.add(
          _sectionAnchor(
            anchorKey: _magicSectionAnchor,
            testKey: const Key('abilities_section_magic'),
            child: AbilitiesReveal(
              delay: const Duration(milliseconds: 160),
              child: AbilitiesMagicSection(
                stats: [
                  MagicStatData(
                    label: l10n.spellAbility,
                    value: _getAbilityAbbr(
                      l10n,
                      SpellcastingService.getSpellcastingAbilityName(
                        widget.character.characterClass,
                      ),
                    ),
                  ),
                  MagicStatData(
                    label: l10n.spellSaveDC,
                    value:
                        '${SpellcastingService.getSpellSaveDC(widget.character)}',
                  ),
                  MagicStatData(
                    label: l10n.spellAttack,
                    value:
                        '+${SpellcastingService.getSpellAttackBonus(widget.character)}',
                  ),
                ],
                preparationStatus: _buildPreparationCounter(context, l10n),
                slotsLabel: SpellcastingService.getSpellcastingType(
                            widget.character.characterClass) ==
                        'pact_magic'
                    ? (locale == 'ru'
                        ? 'Магия Договора (Короткий отдых)'
                        : 'Pact Magic (Short Rest)')
                    : null,
                slotsWidget: widget.character.maxSpellSlots.any((s) => s > 0)
                    ? SpellSlotsWidget(
                        character: widget.character,
                        onChanged: () =>
                            setState(() => widget.character.save()),
                      )
                    : null,
                onOpenSpellAlmanac: _openSpellAlmanac,
                vipBlocks: magicVipBlocks,
                spellGroups: _buildSpellList(spellsByLevel, locale, l10n),
                emptySpellState:
                    displaySpells.isEmpty ? _buildMagicEmptyState(l10n) : null,
              ),
            ),
          ),
        );
        hasAddedGenericSection = true;
      }

      if (passiveFeatures.isNotEmpty) {
        if (children.isNotEmpty) {
          children.add(
            SizedBox(
              height: hasFeaturedModules &&
                      !hasQuickJumpRow &&
                      !hasAddedGenericSection
                  ? 0
                  : AbilitiesShellTokens.sectionSpacing,
            ),
          );
        }
        children.add(
          _sectionAnchor(
            anchorKey: _passiveSectionAnchor,
            testKey: const Key('abilities_section_passive'),
            child: AbilitiesReveal(
              delay: const Duration(milliseconds: 192),
              child: AbilitiesPassiveTraitsSection(
                features: passiveFeatures,
                locale: locale,
                onOpenDetails: _showFeatureSheet,
              ),
            ),
          ),
        );
        hasAddedGenericSection = true;
      }

      return ListView(
        controller: _scrollController,
        padding: AbilitiesShellTokens.pagePadding,
        children: isEmpty
            ? const [
                AbilitiesEmptyState(),
              ]
            : children,
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

  List<Widget> _buildSpellList(Map<int, List<Spell>> spellsByLevel,
      String locale, AppLocalizations l10n) {
    final List<Widget> children = [];
    final levels = spellsByLevel.keys.toList()..sort();
    final defaultExpandedLevel =
        AbilitiesTabLogic.defaultExpandedSpellLevel(levels);

    for (final level in levels) {
      try {
        final spells = spellsByLevel[level] ?? [];
        if (spells.isNotEmpty) {
          children.add(
            _buildSpellLevelGroup(
              level,
              spells,
              locale,
              l10n,
              defaultExpandedLevel: defaultExpandedLevel,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error rendering spell level $level: $e');
      }
    }
    return children;
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

  Widget _buildSpellLevelGroup(
      int level, List<Spell> spells, String locale, AppLocalizations l10n,
      {required int? defaultExpandedLevel}) {
    return AbilitiesSpellLevelGroup(
      key: PageStorageKey('spell_level_$level'),
      character: widget.character,
      level: level,
      spells: spells,
      locale: locale,
      initiallyExpanded:
          _expandedLevels[level] ?? level == defaultExpandedLevel,
      onExpandedChanged: (expanded) => _expandedLevels[level] = expanded,
      onOpenDetails: (spell) {
        _showSpellSheet(
          spell,
          onToggleKnown: () => setState(() {
            if (widget.character.knownSpells.contains(spell.id)) {
              widget.character.knownSpells.remove(spell.id);
              widget.character.preparedSpells.remove(spell.id);
            } else {
              widget.character.knownSpells.add(spell.id);
            }
            widget.character.save();
          }),
        );
      },
      onCastSpell: (spell) => _showCastSpellDialog(spell, locale, l10n),
      onTogglePreparation: (spell) {
        setState(() {
          final success = SpellPreparationManager.togglePreparation(
            widget.character,
            spell,
            context,
          );
          if (!success) {
            AppSnackBar.warning(context, l10n.preparedSpellsLimitReached);
          }
        });
      },
    );
  }

  // --- Wizard VIP Block Builders ---

  void _showFeatureLore(String featureId) {
    final feature = FeatureService.getFeatureById(featureId);
    if (feature != null) {
      _showFeatureSheet(feature);
    }
  }

  Widget _buildSpellMasteryBlock(
      BuildContext context, AppLocalizations l10n, String locale) {
    final theme = Theme.of(context);
    final spells = widget.character.spellMasterySpells
        .map((id) => SpellService.getSpellById(id))
        .whereType<Spell>()
        .toList();

    final isHC = theme.dividerTheme.thickness == 2;

    return Card(
      elevation: 4,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color:
                isHC ? theme.colorScheme.primary : theme.colorScheme.tertiary,
            width: 2),
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

    final isHC = theme.dividerTheme.thickness == 2;

    return Card(
      elevation: 4,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color:
                isHC ? theme.colorScheme.primary : theme.colorScheme.tertiary,
            width: 2),
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

    final isHC = colorScheme.outlineVariant == colorScheme.primary &&
        Theme.of(context).dividerTheme.thickness == 2;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: isHC ? colorScheme.primary : colorScheme.outlineVariant,
            width: isHC ? 2 : 1),
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
        onTap: () => _showSpellSheet(spell),
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

      AppSnackBar.success(
        context,
        message,
        duration: const Duration(seconds: 2),
      );
    });
  }
}
