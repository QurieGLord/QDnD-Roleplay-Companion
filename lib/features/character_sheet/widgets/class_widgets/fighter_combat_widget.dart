import '../../../../shared/widgets/subclass_details_sheet.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/ui/sheet_drag_region.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import '../session/value_editors.dart';
import 'fighter_tactics_surface.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class FighterCombatWidget extends StatefulWidget {
  const FighterCombatWidget(
      {super.key,
      required this.character,
      this.secondWindFeature,
      this.actionSurgeFeature,
      this.indomitableFeature,
      this.onChanged});
  final Character character;
  final CharacterFeature? secondWindFeature,
      actionSurgeFeature,
      indomitableFeature;
  final VoidCallback? onChanged;
  @override
  State<FighterCombatWidget> createState() => _FighterCombatWidgetState();
}

class _FighterCombatWidgetState extends State<FighterCombatWidget> {
  bool _busy = false;
  int? _lastSecondWindRoll;
  int? _lastSecondWindHealing;
  CharacterClassContext get _fighter =>
      CharacterClassContext(widget.character, 'fighter');
  List<CharacterFeature> get _resources => [
        if (widget.secondWindFeature?.resourcePool != null)
          widget.secondWindFeature!,
        if (widget.actionSurgeFeature?.resourcePool != null)
          widget.actionSurgeFeature!,
        if (widget.indomitableFeature?.resourcePool != null)
          widget.indomitableFeature!,
      ].where(_fighter.canUseFeature).toList();

  List<CharacterFeature> get _styles => widget.character.features.where((f) {
        if (!_fighter.canUseFeature(f)) return false;
        final id = f.id.toLowerCase().replaceAll('_', '-');
        const containers = {
          'fighting-style',
          'additional-fighting-style',
          'fighter-fighting-style'
        };
        if (containers.contains(id) ||
            {'fighting style', 'additional fighting style'}
                .contains(f.nameEn.toLowerCase())) {
          return false;
        }
        // Ranger and Paladin styles are shown by their own panels.
        if (id.startsWith('ranger-') || id.startsWith('paladin-')) return false;
        return id.startsWith('fighter-fighting-style-') ||
            id.startsWith('fighting-style-') ||
            id.startsWith('fs-');
      }).toList();

  CharacterFeature? get _critical => widget.character.features.where((f) {
        if (!_fighter.canUseFeature(f)) return false;
        final id = f.id.toLowerCase().replaceAll('_', '-');
        return id.contains('improved-critical') ||
            id.contains('superior-critical');
      }).firstOrNull;

  Future<void> _activate(CharacterFeature feature) async {
    if (_busy || !_fighter.canUseFeature(feature)) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    try {
      final secondWind = identical(feature, widget.secondWindFeature);
      final roll = secondWind ? Random().nextInt(10) + 1 : 0;
      final healing = secondWind ? roll + _fighter.level : 0;
      final result = await GameplayActionsService.activateResource(
          widget.character, feature,
          healing: healing);
      if (!mounted) return;
      if (result.spent) {
        if (secondWind) {
          setState(() {
            _lastSecondWindRoll = roll;
            _lastSecondWindHealing = result.healed;
          });
        }
        HapticFeedback.mediumImpact();
        widget.onChanged?.call();
        AppSnackBar.success(
            context,
            secondWind
                ? l10n.secondWindHeal(result.healed)
                : l10n.gameStateResourceUsed(feature.getName(locale)));
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, l10n.sheetSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(CharacterFeature feature) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final changed =
          await showResourceValueEditor(context, widget.character, feature);
      if (mounted && changed) widget.onChanged?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _details(CharacterFeature feature, IconData icon) =>
      showResponsiveSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) =>
              FeatureDetailsSheet(feature: feature, overrideIcon: icon));

  Future<void> _subclassDetails() async {
    await showClassSubclassDetails(context, widget.character, 'fighter');
    if (mounted) {
      setState(() {});
    }
  }

  Widget _tactic(CharacterFeature feature, FighterTactic tactic,
          AppLocalizations l10n, String locale,
          {bool compact = false, bool joined = false}) =>
      FighterTacticsSurface(
          key: ValueKey('fighter-action-${feature.id}'),
          tactic: tactic,
          name: feature.getName(locale).replaceAll(RegExp(r'\s*\(.*?\)'), ''),
          current: feature.resourcePool!.currentUses,
          maximum: feature.resourcePool!.maxUses,
          bonus: _fighter.level,
          lastRoll:
              tactic == FighterTactic.secondWind ? _lastSecondWindRoll : null,
          lastHealing: tactic == FighterTactic.secondWind
              ? _lastSecondWindHealing
              : null,
          recovery: _recovery(feature.resourcePool!.recoveryType, l10n),
          busy: _busy,
          compact: compact,
          joined: joined,
          onActivate: feature.resourcePool!.currentUses > 0
              ? () => _activate(feature)
              : null,
          onEdit: () => _edit(feature));

  String _recovery(RecoveryType type, AppLocalizations l10n) => switch (type) {
        RecoveryType.shortRest => l10n.shortRest,
        RecoveryType.longRest => l10n.longRest,
        RecoveryType.dawn => l10n.recoveryDawn,
        RecoveryType.perTurn => l10n.recoveryEachTurn,
        RecoveryType.recharge => l10n.recoveryRecharge,
        RecoveryType.manual => l10n.recoveryManual,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final resources = _resources, styles = _styles;
    if (_fighter.level == 0 || (resources.isEmpty && styles.isEmpty)) {
      return const SizedBox.shrink();
    }
    final subclass = _fighter.subclassName(locale);
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(_fighter.name(locale),
                              style: theme.textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.1,
                                  height: 1.05,
                                  color: colors.onSurface))),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                              color: colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
                          child: Text('${l10n.level} ${_fighter.level}',
                              style: theme.textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w600))),
                      _resourceMenu(resources, l10n, locale),
                    ]),
                    if (subclass != null && subclass.isNotEmpty)
                      InkWell(
                          onTap: _subclassDetails,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                        child: Text(subclass,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                    color: colors.secondary,
                                                    fontWeight:
                                                        FontWeight.w500))),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right_rounded,
                                        size: 20, color: colors.secondary),
                                  ]))),
                  ])),
          LayoutBuilder(builder: (context, constraints) {
            final secondary = resources
                .where((f) => !identical(f, widget.secondWindFeature))
                .toList();
            final primary = widget.secondWindFeature;
            final joined = primary?.resourcePool != null &&
                secondary.length == 2 &&
                constraints.maxWidth >= 330 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.25;
            Widget action(CharacterFeature f) => _tactic(
                f,
                identical(f, widget.actionSurgeFeature)
                    ? FighterTactic.actionSurge
                    : FighterTactic.indomitable,
                l10n,
                locale,
                compact: true,
                joined: joined);
            final paired = secondary.length == 2 &&
                constraints.maxWidth >= 330 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.25;
            final lower = paired
                ? IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        Expanded(child: action(secondary[0])),
                        const SizedBox(width: 6),
                        Expanded(child: action(secondary[1])),
                      ]))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        for (final f in secondary) ...[
                          action(f),
                          const SizedBox(height: 8),
                        ]
                      ]);
            if (joined) {
              return AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  curve: Curves.easeInOutCubic,
                  child: FighterTacticsCluster(
                      overlap: 30,
                      primary: _tactic(
                          primary!, FighterTactic.secondWind, l10n, locale,
                          joined: true),
                      secondary: lower));
            }
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (primary?.resourcePool != null) ...[
                    _tactic(primary!, FighterTactic.secondWind, l10n, locale),
                    const SizedBox(height: 8),
                  ],
                  lower,
                ]);
          }),
          if (styles.isNotEmpty || _critical != null) ...[
            const SizedBox(height: 10),
            for (final style in styles) ...[
              _featureLink(style, Icons.shield_rounded, colors.primary, locale),
              const SizedBox(height: 6),
            ],
            if (_critical != null)
              _featureLink(_critical!, Icons.auto_awesome_rounded,
                  colors.primary, locale),
          ],
        ]));
  }

  Widget _resourceMenu(List<CharacterFeature> resources, AppLocalizations l10n,
          String locale) =>
      MenuAnchor(
          builder: (context, controller, child) => IconButton(
              key: const ValueKey('fighter-panel-menu'),
              tooltip: l10n.edit,
              onPressed: _busy
                  ? null
                  : () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
              icon: const Icon(Icons.more_horiz_rounded)),
          menuChildren: [
            for (final f in resources)
              SubmenuButton(menuChildren: [
                MenuItemButton(
                    onPressed: () => _details(f, Icons.military_tech_rounded),
                    leadingIcon: const Icon(Icons.info_rounded),
                    child: Text(l10n.advancementDetails)),
                MenuItemButton(
                    onPressed: () => _edit(f),
                    leadingIcon: const Icon(Icons.tune_rounded),
                    child: Text(l10n.edit)),
              ], child: Text(f.getName(locale))),
          ]);

  Widget _featureLink(
      CharacterFeature feature, IconData icon, Color accent, String locale) {
    final t = Theme.of(context);
    return Material(
        color: t.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.lgPlus),
        child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.lgPlus),
            onTap: () => _details(feature, icon),
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(icon, size: 24, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(feature.getName(locale),
                          style: t.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: t.colorScheme.onSurface))),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, size: 22),
                ]))));
  }
}
