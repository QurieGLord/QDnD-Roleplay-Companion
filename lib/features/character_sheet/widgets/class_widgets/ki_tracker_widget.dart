import '../../../../core/ui/companion_surface.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../session/value_editors.dart';
import 'shared/class_panel_presentation.dart';
import '../../../../core/progression/character_class_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/dice_utils.dart';
import 'shared/class_tools_layout_builder.dart';

class KiTrackerWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature kiFeature;
  final VoidCallback? onChanged;

  const KiTrackerWidget({
    super.key,
    required this.character,
    required this.kiFeature,
    this.onChanged,
  });

  @override
  State<KiTrackerWidget> createState() => _KiTrackerWidgetState();
}

class _KiTrackerWidgetState extends State<KiTrackerWidget> {
  int _calculateMaxKi() =>
      widget.kiFeature.resourcePool?.maxUses ??
      widget.character.classLevel('monk');
  int _getMartialArtsDie(int level) {
    if (level >= 17) return 10;
    if (level >= 11) return 8;
    if (level >= 5) return 6;
    return 4;
  }

  CharacterFeature? _findFeature(List<String> keywords) {
    for (final k in keywords) {
      final match = widget.character.features.where((f) {
        if (!CharacterClassContext(widget.character, 'monk').canUseFeature(f)) {
          return false;
        }
        final id = f.id.toLowerCase();
        final name = f.nameEn.toLowerCase();
        return id.contains(k) || name.contains(k);
      }).firstOrNull;
      if (match != null) return match;
    }
    return null;
  }

  void _showFeatureDetails(CharacterFeature feature, [IconData? overrideIcon]) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(
        feature: feature,
        overrideIcon: overrideIcon,
      ),
    );
  }

  Future<void> _showKiInputDialog(int maxKi, int currentKi) async {
    final changed = await showResourceValueEditor(
        context, widget.character, widget.kiFeature);
    if (mounted && changed) setState(() => widget.onChanged?.call());
  }

  bool _spending = false;
  Future<void> _executeQuickAction(
      CharacterFeature feature, int maxKi, String locale) async {
    if (_spending ||
        !CharacterClassContext(widget.character, 'monk').canUseFeature(feature)) {
      return;
    }
    setState(() => _spending = true);
    final l = AppLocalizations.of(context)!;
    try {
      final spent = await GameplayActionsService.spendResource(
          widget.character, widget.kiFeature,
          amount: feature.consumption?.amount ?? 1);
      if (!mounted) return;
      if (spent) {
        HapticFeedback.mediumImpact();
        widget.onChanged?.call();
        AppSnackBar.success(
            context, l.gameStateResourceUsed(feature.getName(locale)));
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, l.sheetSaveFailed);
    } finally {
      if (mounted) setState(() => _spending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;

    final pool = widget.kiFeature.resourcePool;
    if (pool == null) return const SizedBox.shrink();

    final maxKi = _calculateMaxKi();
    final dieSize = _getMartialArtsDie(widget.character.classLevel('monk'));

    return ClassPanelFrame(
        character: widget.character,
        classId: 'monk',
        child: ClassToolsLayoutBuilder(
          padding: EdgeInsets.zero,
          children: [
            if (CharacterClassContext(widget.character, 'monk').subclass !=
                    null &&
                CharacterClassContext(widget.character, 'monk')
                    .subclass!
                    .isNotEmpty)
              _buildArchetypeBlock(context, colorScheme, locale, l10n),
            if (widget.kiFeature.id != 'ki_fallback' &&
                widget.character.classLevel('monk') >= 2)
              _buildKiDashboard(
                  context, colorScheme, locale, pool.currentUses, maxKi),
            _buildBasicStatsPanel(context, colorScheme, locale, l10n, dieSize),
            if (widget.kiFeature.id != 'ki_fallback' &&
                widget.character.classLevel('monk') >= 2)
              _buildQuickActions(context, colorScheme, locale, maxKi),
          ],
        ));
  }

  Widget _buildArchetypeBlock(BuildContext context, ColorScheme colorScheme,
          String locale, AppLocalizations l10n) =>
      ClassSubclassLink(character: widget.character, classId: 'monk');

  Widget _buildBasicStatsPanel(BuildContext context, ColorScheme colorScheme,
      String locale, AppLocalizations l10n, int dieSize) {
    final martial =
        _findFeature(['martial_arts', 'martial-arts', 'боевые искусства']);
    final movement = _findFeature(
        ['unarmored_movement', 'unarmored-movement', 'движение без доспехов']);
    return LayoutBuilder(builder: (context, constraints) {
      final paired = constraints.maxWidth >= 330 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.2;
      final width =
          paired ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth;
      Widget stat(String title, String value, CharacterFeature? feature) =>
          SizedBox(
              width: width,
              child: CompanionSurface(
                  padding: const EdgeInsets.all(16),
                  onTap: feature == null
                      ? null
                      : () => _showFeatureDetails(feature),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Text(value,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ])));
      return Wrap(spacing: 8, runSpacing: 8, children: [
        stat(locale == 'ru' ? 'Боевые искусства' : 'Martial Arts',
            DiceUtils.formatDice('1d$dieSize', context), martial),
        stat(
            locale == 'ru' ? 'Скорость' : 'Speed',
            '${widget.character.speed} ${locale == 'ru' ? 'фт.' : 'ft.'}',
            movement),
      ]);
    });
  }

  Widget _buildKiDashboard(BuildContext context, ColorScheme colorScheme,
      String locale, int currentKi, int maxKi) {
    final t = Theme.of(context);
    return ClassPrimaryControl(
        classId: 'monk',
        title: locale == 'ru' ? 'Ци' : 'Ki',
        current: currentKi,
        maximum: maxKi,
        marks: true,
        onEdit: () => _showKiInputDialog(maxKi, currentKi),
        footer: classRecoveryLabel(AppLocalizations.of(context)!,
            widget.kiFeature.resourcePool!.recoveryType),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Padding(
              padding: const EdgeInsets.only(right: 18),
              child: SizedBox(
                  width: 94,
                  height: 94,
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                            tween: Tween(
                                end: maxKi > 0
                                    ? (currentKi / maxKi).clamp(0.0, 1.0)
                                    : currentKi > 0
                                        ? 1
                                        : 0),
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 240),
                            builder: (context, value, _) =>
                                CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 7,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: colorScheme.surface,
                                    color: colorScheme.secondary))),
                    Padding(
                        padding: const EdgeInsets.all(14),
                        child: FittedBox(
                            child: Text('$currentKi',
                                style: t.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.2)))),
                  ]))),
          Expanded(
              child: Text(
                  locale == 'ru'
                      ? 'Один запас для твоих приёмов'
                      : 'One reserve for your techniques',
                  style: t.textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant))),
        ]));
  }

  Widget _buildQuickActions(
      BuildContext context, ColorScheme colorScheme, String locale, int maxKi) {
    final actions = <(CharacterFeature?, IconData)>[
      (
        _findFeature(['flurry_of_blows', 'flurry-of-blows', 'шквал ударов']),
        Icons.sports_martial_arts_rounded
      ),
      (
        _findFeature(
            ['patient_defense', 'patient-defense', 'терпеливая оборона']),
        Icons.shield_outlined
      ),
      (
        _findFeature(['step_of_the_wind', 'step-of-the-wind', 'поступь ветра']),
        Icons.air_rounded
      ),
      (
        _findFeature(['stunning_strike', 'stunning-strike', 'оглушающий удар']),
        Icons.bolt_rounded
      ),
    ].where((entry) => entry.$1 != null).toList();
    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(locale == 'ru' ? 'Приёмы' : 'Techniques',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700))),
      for (final entry in actions) ...[
        Builder(builder: (context) {
          final f = entry.$1!;
          final cost = f.consumption?.amount ?? 1;
          final available = !_spending &&
              (widget.kiFeature.resourcePool?.currentUses ?? 0) >= cost;
          return CompanionSurface(
              contour: CompanionContour.cadence,
              padding: const EdgeInsets.all(16),
              onTap: available
                  ? () => _executeQuickAction(f, maxKi, locale)
                  : null,
              onLongPress: () => _showFeatureDetails(f, entry.$2),
              child: Row(children: [
                Icon(entry.$2,
                    size: 24,
                    color: available
                        ? colorScheme.secondary
                        : colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        f.getName(locale).replaceAll(RegExp(r'\s*\(.*?\)'), ''),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600))),
                const SizedBox(width: 12),
                Text('$cost ${locale == 'ru' ? 'Ци' : 'Ki'}',
                    style: Theme.of(context).textTheme.labelLarge),
              ]));
        }),
        const SizedBox(height: 8),
      ],
    ]);
  }
}
