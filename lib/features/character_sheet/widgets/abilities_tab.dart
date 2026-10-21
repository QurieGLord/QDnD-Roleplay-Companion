import 'session/spell_source_summary.dart';
import '../../../shared/widgets/spell_cast_sheet.dart';
import '../../../core/magic/spell_use.dart';
import '../../../core/magic/magic_slots.dart';
import '../../../core/progression/character_class_context.dart';
import 'class_widgets/shared/class_panel_deck.dart';
import '../../../core/services/gameplay_actions_service.dart';
import 'session/resource_counter.dart';
import 'session/value_editors.dart';

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
import 'spell_slots_widget.dart';
import '../../spell_almanac/spell_almanac_screen.dart';
import '../../../shared/widgets/spell_details_sheet.dart';
import '../../../shared/widgets/feature_details_sheet.dart';
import '../../../core/utils/spell_utils.dart';
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
import 'package:qd_and_d/core/theme/app_tokens.dart';

class AbilitiesTab extends StatefulWidget {
  final Character character;
  final bool isActive;

  const AbilitiesTab({
    super.key,
    required this.character,
    this.isActive = true,
  });

  @override
  State<AbilitiesTab> createState() => _AbilitiesTabState();
}

class _AbilitiesTabState extends State<AbilitiesTab>
    with AutomaticKeepAliveClientMixin {
  final Map<int, bool> _expandedLevels = {};
  bool _casting = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _resourcesSectionAnchor = GlobalKey();
  final GlobalKey _activeSectionAnchor = GlobalKey();
  final GlobalKey _magicSectionAnchor = GlobalKey();
  final GlobalKey _passiveSectionAnchor = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant AbilitiesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.isActive || !_scrollController.hasClients) {
          return;
        }
        if (MediaQuery.disableAnimationsOf(context)) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 260),
            curve: AppMotion.standard,
          );
        }
      });
    }
  }

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

  // --- Deep Search & Filtering ---

  bool _shouldShowInList(CharacterFeature feature) =>
      AbilitiesTabLogic(widget.character).shouldShowInList(feature);

  CharacterFeature? _findFeatureDeep(
    List<CharacterFeature> list,
    List<String> keywords,
  ) =>
      AbilitiesTabLogic(widget.character).findFeatureDeep(list, keywords);

  CharacterFeature? _findResourceFeature(String id) =>
      AbilitiesTabLogic(widget.character).findResourceFeature(id);

  List<CharacterFeature> _deduplicateAndFilterFeatures(
    List<CharacterFeature> list,
    String locale,
  ) =>
      AbilitiesTabLogic(widget.character)
          .deduplicateAndFilterFeatures(list, locale);

  // --- Actions ---

  Future<void> _useFeature(
    CharacterFeature feature,
    String locale,
    AppLocalizations l10n,
  ) async {
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
              .where(
                (f) =>
                    f.resourcePool != null &&
                    ((f.id) == 'channel-divinity' ||
                        (f.id).startsWith('channel-divinity-1-rest')),
              )
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
            locale == 'ru'
                ? 'Нет зарядов: ${resource.getName(locale)}.'
                : 'No charges left for ${resource.getName(locale)}.',
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
        final applied = await GameplayActionsService.spendResource(
            widget.character, resource,
            amount: cost);
        if (!mounted || !applied) return;
        setState(() {});
        AppSnackBar.success(
          context,
          locale == 'ru'
              ? '${feature.getName(locale)} · −$cost ${resource.getName(locale)}'
              : '${feature.getName(locale)} used (−$cost ${resource.getName(locale)})',
          duration: const Duration(milliseconds: 1500),
        );
      } else {
        AppSnackBar.warning(
          context,
          locale == 'ru'
              ? 'Нужно $cost ${resource.getName(locale)}.'
              : 'Need $cost ${resource.getName(locale)}.',
        );
      }
    } catch (e) {
      debugPrint('Error using feature: $e');
    }
  }

  Future<void> _useLegacyChannelDivinity(AppLocalizations l10n) async {
    try {
      final applied =
          await GameplayActionsService.spendChannelDivinity(widget.character);
      if (!mounted) return;
      if (applied) {
        setState(() {});
        AppSnackBar.success(
            context,
            l10n.useChannelDivinity(
                widget.character.editableChannelDivinityCharges));
      } else {
        AppSnackBar.warning(context, l10n.noChannelDivinity);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            Localizations.localeOf(context).languageCode == 'ru'
                ? 'Не удалось сохранить действие.'
                : 'Could not save the action.');
      }
    }
  }

  void _showUsageDialog(
    BuildContext context,
    CharacterFeature feature,
    CharacterFeature resource,
    String locale,
  ) {
    int spendAmount = 1;
    final max = resource.resourcePool?.currentUses ?? 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(locale == 'ru'
                  ? '${resource.getName(locale)} · расход'
                  : 'Spend ${resource.getName(locale)}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    locale == 'ru'
                        ? 'Сколько потратить для «${feature.getName(locale)}»?'
                        : 'How much to spend for ${feature.getName(locale)}?',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$spendAmount / $max',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
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
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final applied =
                          await GameplayActionsService.spendResource(
                              widget.character, resource,
                              amount: spendAmount);
                      if (!context.mounted || !mounted || !applied) return;
                      setState(() {});
                      Navigator.pop(context);
                      AppSnackBar.success(
                        context,
                        locale == 'ru'
                            ? '${feature.getName(locale)} · −$spendAmount ${resource.getName(locale)}'
                            : '${feature.getName(locale)} used (−$spendAmount ${resource.getName(locale)})',
                      );
                    } catch (_) {
                      if (context.mounted) {
                        AppSnackBar.error(
                            context,
                            Localizations.localeOf(context).languageCode == 'ru'
                                ? 'Не удалось сохранить действие.'
                                : 'Could not save the action.');
                      }
                    }
                  },
                  child: Text(locale == 'ru' ? 'Потратить' : 'Spend'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCastSpellDialog(
      Spell spell, String locale, AppLocalizations l10n) async {
    if (_casting) return;
    _casting = true;
    try {
      final cast = await showSpellCastSheet(context, widget.character, spell);
      if (mounted && cast) {
        setState(() {});
        AppSnackBar.success(
            context, l10n.spellCastSuccess(spell.getName(locale)));
      }
    } finally {
      _casting = false;
    }
  }

  Future<void> _castSpell(
          Spell spell, int slotLevel, String locale, AppLocalizations l10n) =>
      _showCastSpellDialog(spell, locale, l10n);

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
      child: KeyedSubtree(key: testKey, child: child),
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
      curve: AppMotion.standard,
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

  void _showSpellSheet(Spell spell) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SpellDetailsSheet(
        spell: spell,
        character: widget.character,
        editable: true,
        onChanged: () {
          if (mounted) setState(() {});
        },
      ),
    );
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
      final isWizard = widget.character.classLevel('wizard') > 0;
      bool hasSpellSlots;
      try {
        final slots = MagicSlots.read(widget.character);
        hasSpellSlots = slots.pact != null ||
            slots.current.any((n) => n > 0) ||
            slots.maximum.any((n) => n > 0);
      } catch (_) {
        hasSpellSlots = widget.character.spellSlots.any((n) => n > 0) ||
            widget.character.classLevel('warlock') > 0;
      }
      final hasKnownSpells = widget.character.knownSpells.isNotEmpty;
      final showMagicSection = hasSpellSlots || hasKnownSpells;

      final displaySpells = SpellUse.visible(widget.character);
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
      final allFeatures = widget.character.features.where((f) {
        if (f.associatedClass == null ||
            FeatureService.classKey(f.associatedClass!) == 'optional') {
          return f.minLevel <= widget.character.level;
        }
        final key = FeatureService.classKey(f.associatedClass!);
        final owner = CharacterClassContext(widget.character, key);
        if (owner.entry == null &&
            !{
              'barbarian',
              'bard',
              'cleric',
              'druid',
              'fighter',
              'monk',
              'paladin',
              'ranger',
              'rogue',
              'sorcerer',
              'warlock',
              'wizard'
            }.contains(key)) {
          return f.minLevel <= widget.character.level;
        }
        return owner.canUseFeature(f);
      }).toList();

      // Deep Search for Class Widgets
      final monkKiFeature = _findFeatureDeep(allFeatures, ['ki']);
      final barbarianRageFeature = _findFeatureDeep(allFeatures, [
        'rage',
        'barbarian_rage',
      ]);
      final rogueSneakAttack = _findFeatureDeep(allFeatures, ['sneak_attack']);
      final bardInspiration = _findFeatureDeep(allFeatures, [
        'bardic_inspiration',
        'bardic-inspiration',
      ]);

      final fighterActionSurge = _findFeatureDeep(allFeatures, [
        'action_surge',
        'action surge',
      ]);
      final fighterSecondWind = _findFeatureDeep(allFeatures, [
        'second_wind',
        'second wind',
      ]);
      final fighterIndomitable = _findFeatureDeep(allFeatures, ['indomitable']);

      // Paladin Features
      final paladinLayOnHands = _findFeatureDeep(allFeatures, [
        'lay-on-hands',
        'lay_on_hands',
      ]);
      final paladinDivineSense = _findFeatureDeep(allFeatures, [
        'divine-sense',
        'divine_sense',
      ]);
      final paladinDivineSmite = _findFeatureDeep(allFeatures, [
        'divine-smite',
        'divine_smite',
      ]);
      final paladinChannelDivinity = _findFeatureDeep(allFeatures, [
        'channel-divinity',
        'channel_divinity',
      ]);

      // Ranger Features
      final primevalAwareness = _findFeatureDeep(allFeatures, [
        'primeval-awareness',
        'primeval_awareness',
      ]);

      // Sorcerer Features (Robust Search)
      final sorceryPoints = _findFeatureDeep(allFeatures, [
            'sorcery_points',
            'sorcery-points',
            'sorcery_point',
            'sorcery-point',
            'font_of_magic',
            'font-of-magic',
          ]) ??
          allFeatures
              .where(
                (f) =>
                    f.resourcePool != null &&
                    (f.nameEn.toLowerCase().contains('sorcery point') ||
                        f.nameRu.toLowerCase().contains(
                              'единицы чародейства',
                            ) ||
                        f.nameEn.toLowerCase().contains('font of magic') ||
                        f.nameRu.toLowerCase().contains('источник магии')),
              )
              .firstOrNull;

      final metamagicOptions = allFeatures
          .where(
            (f) =>
                (f.id).toLowerCase().contains('metamagic') ||
                f.nameEn.toLowerCase().contains('metamagic') ||
                f.nameRu.toLowerCase().contains('метамагия'),
          )
          .toList();

      final sorcererAncestry = allFeatures
          .where(
            (f) =>
                (f.id).toLowerCase().contains('dragon-ancestor') ||
                (f.id).toLowerCase().contains('draconic') ||
                (f.id).toLowerCase().contains('dragon') ||
                f.nameEn.toLowerCase().contains('draconic') ||
                f.nameRu.toLowerCase().contains('дракон'),
          )
          .toList();

      // Debug Sorcerer Detection
      if (classId.contains('sorcerer')) {
        debugPrint('--- SORCERER DEBUG ---');
        debugPrint('Sorcery Points Found: ${sorceryPoints?.id ?? "NULL"}');
        debugPrint(
          'Metamagic Options: ${metamagicOptions.map((e) => e.id).join(', ')}',
        );
        debugPrint(
          'Ancestry Features: ${sorcererAncestry.map((e) => e.id).join(', ')}',
        );
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
        'undead',
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
        'pact_of_the_talismam',
      ]);
      final warlockInvocations = allFeatures
          .where(
            (f) =>
                (f.id).toLowerCase().contains('invocation') ||
                f.nameEn.toLowerCase().contains('invocation') ||
                f.nameRu.toLowerCase().contains('воззвание'),
          )
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
          .where(
            (f) =>
                f.resourcePool == null &&
                f.type != FeatureType.passive &&
                _shouldShowInList(f),
          )
          .toList();

      final activeFeatures = _deduplicateAndFilterFeatures(
        rawActiveFeatures,
        locale,
      );

      final rawPassiveFeatures = allFeatures
          .where(
            (f) =>
                f.resourcePool == null &&
                f.type == FeatureType.passive &&
                _shouldShowInList(f),
          )
          .toList();

      final passiveFeatures = _deduplicateAndFilterFeatures(
        rawPassiveFeatures,
        locale,
      );

      final rawResourceFeatures = allFeatures
          .where((f) => f.resourcePool != null && _shouldShowInList(f))
          .toList();

      final resourceFeatures = _deduplicateAndFilterFeatures(
        rawResourceFeatures,
        locale,
      );

      debugPrint(
        'Features Filtered: Res=${resourceFeatures.length}, Active=${activeFeatures.length}, Passive=${passiveFeatures.length}',
      );

      final featuredModules = <ClassPanelEntry>[];

      void addFeaturedModule(String id, Widget panel) {
        if (_isRenderableWidget(panel)) {
          final owner = CharacterClassContext(widget.character, id);
          featuredModules.add(
            ClassPanelEntry(
              id: id,
              name: owner.name(locale),
              level: owner.level,
              child: panel,
            ),
          );
        }
      }

      if (widget.character.classLevel('monk') > 0) {
        addFeaturedModule(
          'monk',
          _safeBuildWidget(() {
            final martialArts = _findFeatureDeep(allFeatures, [
              'martial_arts',
              'martial-arts',
            ]);
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
          }),
        );
      }

      if (widget.character.classLevel('barbarian') > 0 &&
          barbarianRageFeature != null) {
        addFeaturedModule(
          'barbarian',
          _safeBuildWidget(
            () => RageControlWidget(
              character: widget.character,
              rageFeature: barbarianRageFeature,
              onChanged: () => setState(() {}),
            ),
          ),
        );
      }

      if (widget.character.classLevel('rogue') > 0 &&
          rogueSneakAttack != null) {
        addFeaturedModule(
          'rogue',
          _safeBuildWidget(() => RogueToolsWidget(character: widget.character)),
        );
      }

      if (widget.character.classLevel('fighter') > 0 &&
          (fighterSecondWind != null ||
              fighterActionSurge != null ||
              fighterIndomitable != null)) {
        addFeaturedModule(
          'fighter',
          _safeBuildWidget(
            () => FighterCombatWidget(
              character: widget.character,
              secondWindFeature: fighterSecondWind,
              actionSurgeFeature: fighterActionSurge,
              indomitableFeature: fighterIndomitable,
              onChanged: () => setState(() {}),
            ),
          ),
        );
      }

      if (widget.character.classLevel('bard') > 0 && bardInspiration != null) {
        addFeaturedModule(
          'bard',
          _safeBuildWidget(
            () => BardInspirationWidget(
              character: widget.character,
              inspirationFeature: bardInspiration,
              onChanged: () => setState(() {}),
            ),
          ),
        );
      }

      if (widget.character.classLevel('paladin') > 0) {
        addFeaturedModule(
          'paladin',
          _safeBuildWidget(() {
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
          }),
        );
      }

      if (widget.character.classLevel('sorcerer') > 0) {
        addFeaturedModule(
          'sorcerer',
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
        );
      }

      if (widget.character.classLevel('warlock') > 0) {
        addFeaturedModule(
          'warlock',
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
        );
      }

      if (widget.character.classLevel('druid') > 0) {
        addFeaturedModule(
          'druid',
          _safeBuildWidget(
            () => DruidMagicWidget(
              character: widget.character,
              onStateChanged: () => setState(() {}),
            ),
          ),
        );
      }

      if (widget.character.classLevel('wizard') > 0) {
        addFeaturedModule(
          'wizard',
          _safeBuildWidget(
            () => WizardMagicWidget(
              character: widget.character,
              onStateChanged: () => setState(() {}),
            ),
          ),
        );
      }

      if (widget.character.classLevel('cleric') > 0) {
        addFeaturedModule(
          'cleric',
          _safeBuildWidget(
            () => ClericMagicWidget(
              character: widget.character,
              onStateChanged: () => setState(() {}),
            ),
          ),
        );
      }

      if (widget.character.classLevel('ranger') > 0) {
        addFeaturedModule(
          'ranger',
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
        );
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
        if (isWizard &&
            widget.character.classLevel('wizard') >= 18 &&
            widget.character.spellMasterySpells.isNotEmpty)
          _buildSpellMasteryBlock(context, l10n, locale),
        if (isWizard &&
            widget.character.classLevel('wizard') >= 20 &&
            widget.character.signatureSpells.isNotEmpty)
          _buildSignatureSpellsBlock(context, l10n, locale),
      ];

      final children = <Widget>[];
      final hasQuickJumpRow = hasFeaturedModules && quickJumpItems.length >= 3;
      var hasAddedGenericSection = false;

      if (hasFeaturedModules) {
        children.add(
          KeyedSubtree(
            key: const Key('abilities_featured_modules'),
            child: ClassPanelDeck(
              panels: [
                for (final entry in widget.character.classes)
                  ...featuredModules.where(
                    (panel) =>
                        CharacterClassContext(widget.character, panel.id)
                            .entry
                            ?.id ==
                        entry.id,
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
                counterBuilder: (feature) => SheetResourceCounter(
                  name: feature.getName(locale),
                  current: () => GameplayActionsService.resourceCurrent(
                    widget.character,
                    feature,
                  ),
                  maximum: () => feature.resourcePool!.maxUses,
                  onStep: (delta) => GameplayActionsService.changeResource(
                    widget.character,
                    feature,
                    delta,
                  ),
                  onEdit: () => showResourceValueEditor(
                    context,
                    widget.character,
                    feature,
                  ),
                  onChanged: () {
                    if (mounted) setState(() {});
                  },
                ),
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
                stats: const [],
                preparationStatus: SpellSourceSummary(
                    hero: widget.character, onPrepare: _openSpellAlmanac),
                slotsLabel: SpellcastingService.getSpellcastingType(
                          widget.character.characterClass,
                        ) ==
                        'pact_magic'
                    ? (locale == 'ru'
                        ? 'Магия Договора (Короткий отдых)'
                        : 'Pact Magic (Short Rest)')
                    : null,
                slotsWidget: widget.character.classLevel('warlock') > 0 &&
                        widget.character.classes.length == 1
                    ? null
                    : SpellSlotsWidget(
                        character: widget.character,
                        onChanged: () => setState(() {})),
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
        children: isEmpty ? const [AbilitiesEmptyState()] : children,
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
                  fontFamily: 'monospace',
                ),
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

  List<Widget> _buildSpellList(
    Map<int, List<Spell>> spellsByLevel,
    String locale,
    AppLocalizations l10n,
  ) {
    final List<Widget> children = [];
    final levels = spellsByLevel.keys.toList()..sort();
    final defaultExpandedLevel = AbilitiesTabLogic.defaultExpandedSpellLevel(
      levels,
    );

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

  Widget _buildSpellLevelGroup(
    int level,
    List<Spell> spells,
    String locale,
    AppLocalizations l10n, {
    required int? defaultExpandedLevel,
  }) {
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
        _showSpellSheet(spell);
      },
      onCastSpell: (spell) => _showCastSpellDialog(spell, locale, l10n),
      onTogglePreparation: _showSpellSheet,
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
    BuildContext context,
    AppLocalizations l10n,
    String locale,
  ) {
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
          color: isHC ? theme.colorScheme.primary : theme.colorScheme.tertiary,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Giant Clickable Area
          InkWell(
            onTap: () => _showFeatureLore('spell-mastery'),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
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
                  .map(
                    (spell) => _buildVipSpellCard(
                      context,
                      spell,
                      locale,
                      l10n,
                      "Mastery",
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureSpellsBlock(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
  ) {
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
          color: isHC ? theme.colorScheme.primary : theme.colorScheme.tertiary,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Giant Clickable Area
          InkWell(
            onTap: () => _showFeatureLore('signature-spell'),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
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
                  .map(
                    (spell) => _buildVipSpellCard(
                      context,
                      spell,
                      locale,
                      l10n,
                      "Signature",
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipSpellCard(
    BuildContext context,
    Spell spell,
    String locale,
    AppLocalizations l10n,
    String type,
  ) {
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
          width: isHC ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        dense: true,
        title: Text(
          spell.getName(locale),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: isUsed ? TextDecoration.lineThrough : null,
            color: isUsed ? colorScheme.onSurface.withValues(alpha: 0.5) : null,
          ),
        ),
        subtitle: Text(
          SpellUtils.getLocalizedSchool(l10n, spell.school),
          style: TextStyle(color: colorScheme.secondary, fontSize: 11),
        ),
        trailing: IconButton(
          icon: Icon(
            isUsed ? Icons.refresh : Icons.auto_fix_high,
          ), // Changed icon for "Used" state to show it can be upcast
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
    Spell spell,
    String locale,
    AppLocalizations l10n,
    String type,
  ) {
    _castSpell(spell, 0, locale, l10n);
  }
}
