import '../../../../core/magic/magic_slots.dart';
import '../../../../core/services/magic_resource_actions_service.dart';
import '../../../../core/ui/companion_surface.dart';
import '../../../../core/ui/sheet_drag_region.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../session/value_editors.dart';
import '../session/value_editor_dialog.dart';
import 'shared/class_panel_presentation.dart';
import '../../../../core/progression/character_class_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import 'shared/class_tools_layout_builder.dart';

class PaladinDivineWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature layOnHands;
  final CharacterFeature? divineSense;
  final CharacterFeature? divineSmite;
  final CharacterFeature? channelDivinityResource;
  final List<CharacterFeature> channelDivinitySpells;
  final VoidCallback? onChanged;

  const PaladinDivineWidget({
    super.key,
    required this.character,
    required this.layOnHands,
    this.divineSense,
    this.divineSmite,
    this.channelDivinityResource,
    this.channelDivinitySpells = const [],
    this.onChanged,
  });

  @override
  State<PaladinDivineWidget> createState() => _PaladinDivineWidgetState();
}

class _PaladinDivineWidgetState extends State<PaladinDivineWidget> {
  bool _isChannelActive = false;
  bool _resourceBusy = false;
  bool get _isSacredWeaponActive => widget.character.isSacredWeaponActive;

  @override
  void initState() {
    super.initState();
    if (widget.channelDivinityResource?.resourcePool != null) {
      _isChannelActive =
          widget.channelDivinityResource!.resourcePool!.currentUses > 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // --- PALETTE MAPPING ---
    final orangeAccent = colorScheme.primary;
    final beigeAccent = colorScheme.secondary;
    final onBeige = colorScheme.onSecondary;

    // Explicit background for inner blocks to visually separate them
    final blockBg = colorScheme.surfaceContainerLow;

    return ClassPanelFrame(
        character: widget.character,
        classId: 'paladin',
        child: ClassToolsLayoutBuilder(
          padding: EdgeInsets.zero,
          spacing: 12,
          children: [
            // --- BLOCK 0: SUBCLASS (OATH) ---
            if (CharacterClassContext(widget.character, 'paladin').subclass !=
                null)
              _buildSubclassBlock(context, colorScheme, orangeAccent),

            _buildLayOnHandsContent(
                context, colorScheme, orangeAccent, beigeAccent, onBeige),

            if (widget.divineSense != null || widget.divineSmite != null)
              LayoutBuilder(builder: (context, constraints) {
                final controls = <Widget>[
                  if (widget.divineSense != null)
                    _buildBlockContainer(
                        color: colorScheme.secondaryContainer,
                        padding: const EdgeInsets.all(16),
                        onTap: () => _showDetails(widget.divineSense!),
                        child: _buildDivineSenseContent(context, colorScheme,
                            orangeAccent, beigeAccent, onBeige)),
                  if (widget.divineSmite != null &&
                      CharacterClassContext(widget.character, 'paladin')
                          .canUseFeature(widget.divineSmite!))
                    _buildBlockContainer(
                        color: colorScheme.primaryContainer,
                        padding: const EdgeInsets.all(16),
                        onTap: () => _showDetails(widget.divineSmite!),
                        child: _buildDivineSmiteContent(context, colorScheme,
                            orangeAccent, beigeAccent, onBeige)),
                ];
                if (controls.length == 2 &&
                    constraints.maxWidth >= 330 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.2) {
                  return IntrinsicHeight(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Expanded(child: controls[0]),
                        const SizedBox(width: 8),
                        Expanded(child: controls[1])
                      ]));
                }
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final control in controls) ...[
                        control,
                        const SizedBox(height: 8)
                      ]
                    ]);
              }),

            // --- BLOCK 3: CHANNEL DIVINITY ---
            if (widget.channelDivinityResource != null &&
                CharacterClassContext(widget.character, 'paladin')
                    .canUseFeature(widget.channelDivinityResource!))
              // Special container logic for the "Full Width Header"
              CompanionSurface(
                  color: blockBg,
                  quiet: true,
                  padding: EdgeInsets.zero,
                  child: _buildChannelDivinityContent(context, colorScheme,
                      beigeAccent, onBeige, orangeAccent)),
          ],
        ));
  }

  /// Helper to create the visual "tiles"
  Widget _buildBlockContainer({
    required Color color,
    required Widget child,
    required EdgeInsetsGeometry padding,
    VoidCallback? onTap,
  }) {
    return CompanionSurface(
        color: color,
        contour: CompanionContour.focus,
        padding: padding,
        onTap: onTap,
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 154), child: child));
  }

  // ===========================================================================
  // 1. LAY ON HANDS CONTENT
  // ===========================================================================
  Widget _buildLayOnHandsContent(BuildContext context, ColorScheme colorScheme,
      Color barColor, Color btnColor, Color onBtnColor) {
    final pool = widget.layOnHands.resourcePool;
    if (pool == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    return ClassPrimaryControl(
        classId: 'paladin',
        title: widget.layOnHands.getName(locale),
        current: pool.currentUses,
        maximum: pool.maxUses,
        tone: colorScheme.tertiaryContainer,
        footer: classRecoveryLabel(l, pool.recoveryType),
        onEdit: () async {
          final changed = await showResourceValueEditor(
              context, widget.character, widget.layOnHands);
          if (mounted && changed) setState(() => widget.onChanged?.call());
        },
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${pool.currentUses} ${l.hpShort}',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
              onPressed: pool.currentUses > 0
                  ? () => _showCustomHealDialog(context, pool, pool.maxUses)
                  : null,
              icon: const Icon(Icons.favorite_outline_rounded),
              label: Text(locale == 'ru' ? 'Выбрать объём' : 'Choose amount')),
        ]));
  }

  Future<void> _usePaladinResource(CharacterFeature feature,
      {bool sacredWeapon = false}) async {
    if (_resourceBusy) return;
    setState(() => _resourceBusy = true);
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    try {
      final spent = sacredWeapon && _isSacredWeaponActive
          ? await GameplayActionsService.endSacredWeapon(widget.character)
          : (await GameplayActionsService.activateResource(
                  widget.character, feature,
                  activateSacredWeapon: sacredWeapon))
              .spent;
      if (mounted && spent) {
        HapticFeedback.mediumImpact();
        widget.onChanged?.call();
        if (!sacredWeapon || _isSacredWeaponActive) {
          AppSnackBar.success(
              context, l.gameStateResourceUsed(feature.getName(locale)));
        }
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, l.sheetSaveFailed);
    } finally {
      if (mounted) setState(() => _resourceBusy = false);
    }
  }

  Widget _buildDivineSenseContent(BuildContext context, ColorScheme colorScheme,
      Color dotColor, Color buttonColor, Color onButtonColor) {
    final f = widget.divineSense!;
    final pool = f.resourcePool;
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(f.getName(locale),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (pool != null)
            Align(
                alignment: Alignment.centerLeft,
                child: CompanionReserve(
                    current: pool.currentUses,
                    maximum: pool.maxUses,
                    large: true)),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 64),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  textStyle: Theme.of(context).textTheme.labelLarge),
              onPressed: !_resourceBusy && (pool?.currentUses ?? 0) > 0
                  ? () => _usePaladinResource(f)
                  : null,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: Text(AppLocalizations.of(context)!.useAction)),
        ]);
  }

  Widget _buildDivineSmiteContent(BuildContext context, ColorScheme colorScheme,
      Color dotColor, Color buttonColor, Color onButtonColor) {
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.divineSmite!.getName(locale),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(locale == 'ru' ? '2к8' : '2d8',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 64),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  textStyle: Theme.of(context).textTheme.labelLarge),
              onPressed:
                  !_resourceBusy ? () => _showSmiteDialog(context) : null,
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: Text(locale == 'ru' ? 'Выбрать ячейку' : 'Choose slot')),
        ]);
  }

  void _showSmiteDialog(BuildContext context) {
    MagicSlots slots;
    try {
      slots = MagicSlots.read(widget.character);
    } catch (_) {
      AppSnackBar.warning(
          context,
          Localizations.localeOf(context).languageCode == 'ru'
              ? 'Сначала уточни запасы магии.'
              : 'Resolve spell pools first.');
      return;
    }
    final choices = [
      for (final circle in slots.availableCircles(1))
        (MagicPool.shared, circle),
      if ((slots.pact?.current ?? 0) > 0) (MagicPool.pact, slots.pact!.circle)
    ];
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    showResponsiveSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SheetDragRegion(
                      child: Text(ru ? 'Божественная кара' : 'Divine Smite',
                          style: Theme.of(context).textTheme.headlineSmall)),
                  const SizedBox(height: 12),
                  Text(ru
                      ? 'Применяется после попадания рукопашным оружием. По нежити или исчадию добавляется ещё 1к8.'
                      : 'Use after a melee weapon hit. Add 1d8 against an undead or a fiend.'),
                  const SizedBox(height: 16),
                  if (choices.isEmpty)
                    Text(AppLocalizations.of(context)!.noSlotsAvailable),
                  for (final choice in choices)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CompanionSurface(
                            quiet: true,
                            onTap: () {
                              Navigator.pop(context);
                              _executeSmite(choice.$1, choice.$2, ru);
                            },
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      choice.$1 == MagicPool.pact
                                          ? (ru
                                              ? 'Магия договора'
                                              : 'Pact Magic')
                                          : (ru
                                              ? 'Общая ячейка'
                                              : 'Shared slot'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge),
                                  const SizedBox(height: 6),
                                  Text(
                                      '${ru ? 'Круг' : 'Circle'} ${choice.$2} · ${choice.$2 >= 4 ? 5 : choice.$2 + 1}${ru ? 'к8' : 'd8'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ]))),
                ])));
  }

  Future<void> _executeSmite(MagicPool pool, int circle, bool ru) async {
    if (_resourceBusy) return;
    setState(() => _resourceBusy = true);
    try {
      await MagicResourceActionsService.spendSlot(
          widget.character, pool, circle);
      if (!mounted) return;
      widget.onChanged?.call();
      AppSnackBar.success(
          context,
          ru
              ? 'Божественная кара · ${circle >= 4 ? 5 : circle + 1}к8'
              : 'Divine Smite · ${circle >= 4 ? 5 : circle + 1}d8');
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context,
            ru ? 'Не удалось применить кару.' : 'Could not apply Smite.');
      }
    } finally {
      if (mounted) setState(() => _resourceBusy = false);
    }
  }

  // ===========================================================================
  // 3. CHANNEL DIVINITY CONTENT (Fixed Header Width)
  // ===========================================================================
  Widget _buildChannelDivinityContent(
      BuildContext context,
      ColorScheme colorScheme,
      Color activeBg,
      Color activeContent,
      Color iconColor) {
    final resource = widget.channelDivinityResource;
    if (resource?.resourcePool == null) return const SizedBox.shrink();
    return ExpansionTile(
        initiallyExpanded: _isChannelActive,
        onExpansionChanged: (value) => setState(() => _isChannelActive = value),
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        title: Text(AppLocalizations.of(context)!.channelDivinity,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: CompanionReserve(
            current: GameplayActionsService.resourceCurrent(
                widget.character, resource!),
            maximum: resource.resourcePool!.maxUses),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final f in widget.channelDivinitySpells)
            _buildSpellGridTile(
                context,
                f,
                colorScheme,
                activeBg,
                activeContent,
                Localizations.localeOf(context).languageCode,
                resource.resourcePool!),
        ]);
  }

  Widget _buildSpellGridTile(
      BuildContext context,
      CharacterFeature feature,
      ColorScheme colorScheme,
      Color buttonBg,
      Color buttonContent,
      String locale,
      ResourcePool pool) {
    final name = feature
        .getName(locale)
        .replaceAll('Божественный Канал: ', '')
        .replaceAll('Channel Divinity: ', '')
        .trim();
    final sacred = feature.id == 'channel-divinity-sacred-weapon';
    final active = sacred && _isSacredWeaponActive;
    final current = GameplayActionsService.resourceCurrent(
        widget.character, widget.channelDivinityResource!);
    return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: CompanionSurface(
            key: ValueKey('paladin-channel-${feature.id}'),
            contour: CompanionContour.focus,
            color: active ? colorScheme.primaryContainer : colorScheme.surface,
            padding: const EdgeInsets.all(14),
            onTap: () => _showDetails(feature),
            child: Row(children: [
              Icon(_getSmartIcon(name, feature.iconName),
                  size: 24, color: colorScheme.secondary),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                  tooltip: active
                      ? (locale == 'ru' ? 'Завершить' : 'End')
                      : AppLocalizations.of(context)!.useAction,
                  onPressed: !_resourceBusy && (current > 0 || active)
                      ? () => _usePaladinResource(
                          widget.channelDivinityResource!,
                          sacredWeapon: sacred)
                      : null,
                  icon: Icon(
                      active ? Icons.stop_rounded : Icons.play_arrow_rounded)),
            ])));
  }

  void _showDetails(CharacterFeature feature) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(feature: feature),
    );
  }

  Future<void> _showCustomHealDialog(
      BuildContext context, ResourcePool pool, int max) async {
    if (pool.currentUses <= 0) return;
    final l = AppLocalizations.of(context)!;
    final changed = await showSheetValueEditor(context,
        title: l.customHealAmount,
        icon: Icons.favorite_outline_rounded,
        actionLabel: l.heal,
        fields: [
          SheetNumberField('amount', l.hpToSpend, 1,
              minimum: 1, maximum: pool.currentUses)
        ], onSave: (values, _) async {
      final spent = await GameplayActionsService.spendResource(
          widget.character, widget.layOnHands,
          amount: values['amount']!);
      if (!spent) throw StateError('insufficient-resource');
    });
    if (mounted && changed) setState(() => widget.onChanged?.call());
  }

  IconData _getSmartIcon(String name, String? iconName) {
    final lower = name.toLowerCase();
    if (lower.contains('weapon') || lower.contains('оружие')) {
      return Icons.colorize;
    }
    if (lower.contains('turn') || lower.contains('изгнание')) {
      return Icons.security;
    }
    if (lower.contains('heal') || lower.contains('исцел')) {
      return Icons.local_hospital;
    }
    if (lower.contains('hammer') || lower.contains('молот')) return Icons.gavel;
    return Icons.auto_awesome;
  }

  Widget _buildSubclassBlock(
          BuildContext context, ColorScheme colorScheme, Color accentColor) =>
      ClassSubclassLink(character: widget.character, classId: 'paladin');
}

// --- Internal Widget: Divine Sense Pulse Button ---
