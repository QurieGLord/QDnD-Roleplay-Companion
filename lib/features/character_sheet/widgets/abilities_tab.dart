import 'session/spell_source_summary.dart';
import '../../../shared/widgets/spell_cast_sheet.dart';
import '../../../core/magic/spell_use.dart';
import '../../../core/magic/magic_slots.dart';
import '../../../core/progression/character_class_context.dart';
import 'class_widgets/shared/class_panel_deck.dart';
import 'class_widgets/instrument/instrument_kit.dart';
import '../../../shared/widgets/subclass_details_sheet.dart';
import '../../../core/services/gameplay_actions_service.dart';
import 'session/resource_counter.dart';
import 'session/value_editors.dart';

import 'package:flutter/material.dart';
import 'package:qd_and_d/core/ui/sheet_drag_region.dart' show SheetSafeArea;
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../core/models/character.dart';
import '../../../core/models/spell.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/services/feature_service.dart';
import 'spell_slots_widget.dart';
import '../../spell_almanac/spell_almanac_screen.dart';
import '../../../shared/widgets/spell_details_sheet.dart';
import '../../../shared/widgets/feature_details_sheet.dart';
import '../../../core/utils/spell_utils.dart';
import 'abilities/abilities_empty_state.dart';
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
import 'class_widgets/instrument/universal_kit_panel.dart';
import 'session/value_editor_dialog.dart';
import '../../../core/ui/companion_kit.dart' show Pressable, SheetPageInset;
import '../../../core/magic/spellbook_state.dart';
import '../../../core/progression/class_spellcasting_profile.dart';
import '../../../core/services/magic_resource_actions_service.dart';
import '../../../core/services/spellbook_actions_service.dart';
import 'class_widgets/cleric_magic_widget.dart';
import 'class_widgets/ranger_survival_widget.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

const _builtInClasses = {
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
  'wizard',
};

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

  bool _slotsReadable() {
    try {
      MagicSlots.read(widget.character);
      return true;
    } catch (_) {
      return false;
    }
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
      builder: (context) => SheetSafeArea(child: FeatureDetailsSheet(feature: feature)),
    );
  }

  void _showSpellSheet(Spell spell) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SheetSafeArea(child: SpellDetailsSheet(
        spell: spell,
        character: widget.character,
        editable: true,
        onChanged: () {
          if (mounted) setState(() {});
        },
      )),
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

      // Mystic Arcanum spells live on their seals in the warlock panel.
      final arcanumIds = {
        for (var circle = 6; circle <= 9; circle++)
          SpellUse.arcanumSpell(widget.character, circle),
      }.whereType<String>().toSet();
      for (var spell in displaySpells) {
        if (vipSpellIds.contains(spell.id)) continue;
        if (arcanumIds.contains(spell.id)) continue;
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
        if (owner.entry == null && !_builtInClasses.contains(key)) {
          return f.minLevel <= widget.character.level;
        }
        return owner.canUseFeature(f);
      }).toList();

      // A class outside the built-in twelve (third-party, homebrew, an
      // import) is drawn by the universal kit from its own features.
      final kitClasses = <String, List<CharacterFeature>>{
        for (final entry in widget.character.classes)
          if (!_builtInClasses.contains(FeatureService.classKey(entry.id)))
            FeatureService.classKey(entry.id): widget.character.features
                .where((f) =>
                    f.associatedClass != null &&
                    CharacterClassContext(
                            widget.character, FeatureService.classKey(entry.id))
                        .acceptsFeature(f) &&
                    FeatureService.classKey(f.associatedClass!) != 'optional')
                .toList(),
      }..removeWhere((_, features) => features.isEmpty);
      final kitFeatureIds = {
        for (final list in kitClasses.values) ...list.map((f) => f.id)
      };

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
                !kitFeatureIds.contains(f.id) &&
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
                !kitFeatureIds.contains(f.id) &&
                _shouldShowInList(f),
          )
          .toList();

      final passiveFeatures = _deduplicateAndFilterFeatures(
        rawPassiveFeatures,
        locale,
      );

      final rawResourceFeatures = allFeatures
          .where((f) =>
              f.resourcePool != null &&
              !kitFeatureIds.contains(f.id) &&
              _shouldShowInList(f))
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
              subclass: subclassDisplayName(widget.character, id, locale),
              onSubclass: () async {
                await showClassSubclassDetails(context, widget.character, id);
                if (mounted) setState(() {});
              },
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

      for (final MapEntry(key: id, value: features) in kitClasses.entries) {
        final level = CharacterClassContext(widget.character, id).level;
        addFeaturedModule(
          id,
          _safeBuildWidget(
            () => UniversalKitPanel(
              hero: widget.character,
              classId: id,
              features: features
                  .where(
                      CharacterClassContext(widget.character, id).canUseFeature)
                  .toList(),
              locked: features.where((f) => f.minLevel > level).toList(),
              onChanged: () => setState(() {}),
            ),
          ),
        );
      }

      final hasFeaturedModules = featuredModules.isNotEmpty;
      final isEmpty = featuredModules.isEmpty &&
          resourceFeatures.isEmpty &&
          activeFeatures.isEmpty &&
          !showMagicSection &&
          passiveFeatures.isEmpty;

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

      if (resourceFeatures.isNotEmpty) {
        if (children.isNotEmpty) {
          children.add(
            SizedBox(
              height: hasFeaturedModules && !hasAddedGenericSection
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
              height: hasFeaturedModules && !hasAddedGenericSection
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
              height: hasFeaturedModules && !hasAddedGenericSection
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
                concentration: _concentrationBanner(locale),
                // Slots live in the circle headers; only an older mixed
                // sheet whose pools are not separated keeps the old panel.
                slotsWidget: _slotsReadable()
                    ? null
                    : SpellSlotsWidget(
                        character: widget.character,
                        onChanged: () => setState(() {})),
                footer: hasSpellSlots
                    ? Text(
                        locale == 'ru'
                            ? 'Касание отметки — потратить ячейку · удержание — изменить вручную'
                            : 'Tap a mark to spend a slot · hold to edit',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: AppType.body,
                            fontSize: 12.5,
                            color: colorScheme.onSurfaceVariant))
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
              height: hasFeaturedModules && !hasAddedGenericSection
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

      // The page scrolls on under the floating island, like Overview.
      return ListView(
        controller: _scrollController,
        clipBehavior: Clip.none,
        padding: AbilitiesShellTokens.pagePadding
            .add(EdgeInsets.only(top: SheetPageInset.of(context))),
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
    final hero = widget.character;
    final ru = locale == 'ru';
    final children = <Widget>[];
    MagicSlots? slots;
    try {
      slots = MagicSlots.read(hero);
    } catch (_) {}
    CircleSlots? sharedAt(int level) {
      if (slots == null || level < 1 || level > slots.maximum.length) {
        return null;
      }
      final maximum = slots.maximum[level - 1];
      if (maximum <= 0) return null;
      return (
        current: slots.remaining(MagicPool.shared, level),
        maximum: maximum
      );
    }

    final levels = spellsByLevel.keys.toList()..sort();
    final defaultExpandedLevel =
        AbilitiesTabLogic.defaultExpandedSpellLevel(levels);
    final casters = hero.classes.where((entry) {
      try {
        return ClassSpellcastingProfile.resolve(hero, entry.id) != null;
      } catch (_) {
        return false;
      }
    }).length;

    final pact = slots?.pact;
    if (pact != null && pact.maximum > 0) {
      children.add(AbilitiesSpellLevelGroup(
        key: const ValueKey('spell-circle-pact'),
        character: hero,
        level: pact.circle,
        spells: const [],
        locale: locale,
        initiallyExpanded: false,
        onExpandedChanged: (_) {},
        onOpenDetails: _showSpellSheet,
        onCastSpell: (_) {},
        onTogglePreparation: (_) {},
        title: ru ? 'Договор' : 'Pact',
        subtitle: ru
            ? 'все ячейки ${pact.circle} круга'
            : 'all slots level ${pact.circle}',
        tint: accentOf(context, 5),
        slots: (current: pact.current, maximum: pact.maximum),
        onSpendSlot: () => _spendSlot(MagicPool.pact, pact.circle),
        onEditSlot: () => _editSlot(MagicPool.pact, pact.circle),
      ));
    }

    for (final level in levels) {
      try {
        final spells = spellsByLevel[level] ?? [];
        if (spells.isEmpty) continue;
        final circle = sharedAt(level);
        children.add(AbilitiesSpellLevelGroup(
          key: PageStorageKey('spell_level_$level'),
          character: hero,
          level: level,
          spells: spells,
          locale: locale,
          initiallyExpanded:
              _expandedLevels[level] ?? level == defaultExpandedLevel,
          onExpandedChanged: (expanded) => _expandedLevels[level] = expanded,
          onOpenDetails: _showSpellSheet,
          onCastSpell: (spell) => _showCastSpellDialog(spell, locale, l10n),
          onTogglePreparation: _togglePrepared,
          showOwner: casters > 1,
          slots: circle,
          onSpendSlot:
              circle == null ? null : () => _spendSlot(MagicPool.shared, level),
          onEditSlot:
              circle == null ? null : () => _editSlot(MagicPool.shared, level),
        ));
      } catch (e) {
        debugPrint('Error rendering spell level $level: $e');
      }
    }

    // Circles above the known spells (multiclass upcasting) keep their row.
    if (slots != null) {
      for (var level = 1; level <= slots.maximum.length; level++) {
        if (levels.contains(level)) continue;
        final circle = sharedAt(level);
        if (circle == null) continue;
        children.add(AbilitiesSpellLevelGroup(
          key: ValueKey('spell-circle-slots-$level'),
          character: hero,
          level: level,
          spells: const [],
          locale: locale,
          initiallyExpanded: false,
          onExpandedChanged: (_) {},
          onOpenDetails: _showSpellSheet,
          onCastSpell: (_) {},
          onTogglePreparation: (_) {},
          subtitle: ru ? 'для усиления' : 'for upcasting',
          slots: circle,
          onSpendSlot: () => _spendSlot(MagicPool.shared, level),
          onEditSlot: () => _editSlot(MagicPool.shared, level),
        ));
      }
    }
    return children;
  }

  Future<void> _spendSlot(MagicPool pool, int circle) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final hero = widget.character;
    if (MagicSlots.read(hero).remaining(pool, circle) <= 0) {
      AppSnackBar.info(
          context,
          pool == MagicPool.pact
              ? (ru
                  ? 'Ячейки договора восстановит короткий отдых'
                  : 'A short rest restores Pact slots')
              : (ru
                  ? 'Ячеек $circle круга не осталось'
                  : 'No level $circle slots left'));
      return;
    }
    HapticFeedback.lightImpact();
    try {
      await MagicResourceActionsService.spendSlot(hero, pool, circle);
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _editSlot(MagicPool pool, int circle) async {
    final l10n = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final hero = widget.character;
    final state = MagicSlots.read(hero);
    final current = state.remaining(pool, circle);
    final maximum = pool == MagicPool.pact
        ? state.pact?.maximum ?? 0
        : state.maximum[circle - 1];
    HapticFeedback.mediumImpact();
    await showSheetValueEditor(context,
        title: pool == MagicPool.pact
            ? (ru ? 'Магия договора' : 'Pact Magic')
            : l10n.levelSlot(circle),
        icon: Icons.auto_awesome,
        fields: [
          SheetNumberField('value', l10n.sheetRemainder, current,
              hint: l10n.gameStateNormalMaximum(maximum))
        ],
        onSave: (values, _) => GameplayActionsService.editMagicSlot(
            hero, pool, circle, values['value']!));
    if (mounted) setState(() {});
  }

  /// The star of a spell row: toggles preparation in place when one class
  /// owns the spell, otherwise opens the spell to choose.
  Future<void> _togglePrepared(Spell spell) async {
    final hero = widget.character;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final state = SpellbookState.read(hero.spellbookData);
    final owners = state
        .ownersOf(spell.id)
        .where((o) =>
            o.startsWith('class:') &&
            SpellbookActionsService.preparationLimit(hero, o) != null)
        .toList();
    if (owners.length != 1) return _showSpellSheet(spell);
    final source = owners.single;
    final on = state.ids(source, 'prepared').contains(spell.id) ||
        (hero.classes.length == 1 &&
            state.unassignedPrepared(hero).contains(spell.id));
    final limit = SpellbookActionsService.preparationLimit(hero, source)!;
    final count = SpellbookActionsService.preparedCount(hero, source);
    if (!on && count >= limit) {
      HapticFeedback.heavyImpact();
      AppSnackBar.info(
          context,
          ru
              ? 'Подготовлено $count из $limit — сначала уберите другое'
              : '$count of $limit prepared — remove one first');
      return;
    }
    HapticFeedback.selectionClick();
    try {
      await SpellbookActionsService.setPrepared(hero, spell.id, !on,
          source: source);
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
      return;
    }
    if (mounted) setState(() {});
  }

  Widget? _concentrationBanner(String locale) {
    final id = widget.character.concentratingOn;
    if (id == null) return null;
    final spell = SpellService.getSpellById(id);
    final ru = locale == 'ru';
    final l10n = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    final a5 = accentOf(context, 5);
    return Container(
      key: const ValueKey('magic-concentration'),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
          color: mixColor(a5, .18, c.surfaceContainerLow),
          borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        InstrumentGlyph('timer', size: 20, color: a5),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${ru ? 'Концентрация' : 'Concentration'}: ${spell?.getName(locale) ?? id}',
                style: const TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.25)),
            if (spell != null)
              Text(SpellUtils.getLocalizedValue(l10n, spell.duration),
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 12,
                      color: c.onSurfaceVariant)),
          ]),
        ),
        TextButton(
          onPressed: () async {
            HapticFeedback.lightImpact();
            try {
              await MagicResourceActionsService.endConcentration(
                  widget.character);
            } catch (_) {
              if (mounted) AppSnackBar.error(context, l10n.sheetSaveFailed);
              return;
            }
            if (!mounted) return;
            setState(() {});
            AppSnackBar.info(
                context, ru ? 'Концентрация прервана' : 'Concentration ended');
          },
          child: Text(ru ? 'Прервать' : 'End'),
        ),
      ]),
    );
  }

  // --- Wizard VIP Block Builders ---
  Widget _buildSpellMasteryBlock(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
  ) =>
      _vipBlock(
        key: const ValueKey('wizard-spell-mastery'),
        title: locale == 'ru' ? 'Мастерство заклинаний' : 'Spell Mastery',
        featureId: 'spell-mastery',
        chip: locale == 'ru' ? 'без ячейки' : 'no slot',
        ids: widget.character.spellMasterySpells,
        signature: false,
        locale: locale,
        l10n: l10n,
      );

  Widget _buildSignatureSpellsBlock(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
  ) =>
      _vipBlock(
        key: const ValueKey('wizard-signature-spells'),
        title: locale == 'ru' ? 'Фирменные заклинания' : 'Signature Spells',
        featureId: 'signature-spell',
        chip: locale == 'ru' ? 'раз в отдых' : 'once a rest',
        ids: widget.character.signatureSpells,
        signature: true,
        locale: locale,
        l10n: l10n,
      );

  /// Spell Mastery and Signature Spells: a lite block of the wizard accent
  /// whose rows cast without a slot (a signature spell once per rest).
  Widget _vipBlock({
    required Key key,
    required String title,
    required String featureId,
    required String chip,
    required List<String> ids,
    required bool signature,
    required String locale,
    required AppLocalizations l10n,
  }) {
    final c = Theme.of(context).colorScheme;
    final a4 = accentOf(context, 4);
    final spells =
        ids.map(SpellService.getSpellById).whereType<Spell>().toList();
    final feature = FeatureService.getFeatureById(featureId);
    return LiteBlock(
      key: key,
      accent: a4,
      title: title,
      about: feature == null
          ? null
          : InstrumentAbout(
              title: feature.getName(locale),
              paragraphs:
                  feature.getDescription(locale).split(RegExp(r'\n\s*\n'))),
      trailing: InstrumentChip(chip),
      child: Column(children: [
        for (final spell in spells)
          Builder(builder: (context) {
            final used = signature &&
                (widget.character.signatureSpellsUsed[spell.id] ?? false);
            return Pressable(
              onTap: () => _showSpellSheet(spell),
              scale: .99,
              semanticLabel: spell.getName(locale),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  SizedBox.square(
                    dimension: 30,
                    child: Center(
                      child: InstrumentGlyph(signature ? 'wand' : 'spark',
                          size: 18, color: used ? c.outline : a4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(spell.getName(locale),
                              style: TextStyle(
                                  fontFamily: AppType.body,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                  color: used ? c.onSurfaceVariant : null)),
                          Text(
                              used
                                  ? (locale == 'ru'
                                      ? 'использовано · дальше ячейкой'
                                      : 'used · now with a slot')
                                  : '${SpellUtils.getLocalizedSchool(l10n, spell.school)} · ${locale == 'ru' ? '${spell.level} круг' : 'level ${spell.level}'}',
                              style: TextStyle(
                                  fontFamily: AppType.body,
                                  fontSize: 12,
                                  color: c.onSurfaceVariant)),
                        ]),
                  ),
                  const SizedBox(width: 10),
                  Pressable(
                    onTap: () => _showCastSpellDialog(spell, locale, l10n),
                    scale: .92,
                    semanticLabel: l10n.castSpell,
                    child: Container(
                      width: 44,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: a4.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(14)),
                      child: InstrumentGlyph('wand', size: 20, color: a4),
                    ),
                  ),
                ]),
              ),
            );
          }),
      ]),
    );
  }
}
