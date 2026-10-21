import '../../../../core/services/class_session_actions_service.dart';
import '../../../../shared/widgets/subclass_details_sheet.dart';
import '../../../../core/ui/companion_surface.dart';
import '../session/value_editors.dart';
import 'shared/class_panel_presentation.dart';
import '../../../../core/progression/character_class_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import 'shared/class_tools_layout_builder.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class RageControlWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature rageFeature;
  final VoidCallback? onChanged;

  const RageControlWidget({
    super.key,
    required this.character,
    required this.rageFeature,
    this.onChanged,
  });

  @override
  State<RageControlWidget> createState() => _RageControlWidgetState();
}

class _RageControlWidgetState extends State<RageControlWidget>
    with TickerProviderStateMixin {
  bool get _isRaging => widget.character.isRaging;
  set _isRaging(bool value) => widget.character.isRaging = value;
  bool get _isReckless => widget.character.isReckless;

  bool get _isFrenzied => widget.character.isFrenzied;

  bool _rageBusy = false;
  late AnimationController _frenzyPulseController;

  void _showFeatureDetails(CharacterFeature feature, IconData icon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(
        feature: feature,
        // no backgroundColor here, just let it use theme surface
      ),
    );
  }

  Future<void> _showSubclassLore(BuildContext context) async {
    await showClassSubclassDetails(context, widget.character, 'barbarian');
    if (mounted) {
      setState(() {});
    }
  }

  int _getRageDamage(int level) {
    if (level >= 16) return 4;
    if (level >= 9) return 3;
    return 2;
  }

  @override
  void initState() {
    super.initState();
    _isRaging = widget.character.isRaging;

    _frenzyPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _frenzyPulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleRage(bool value) async {
    if (_rageBusy) return;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final concentration = widget.character.concentratingOn;
    if (value && concentration != null) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text(ru ? 'Начать ярость?' : 'Enter rage?'),
                  content: Text(ru
                      ? 'Ярость завершит текущую концентрацию.'
                      : 'Rage will end your current concentration.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(ru ? 'Назад' : 'Back')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(ru ? 'Начать ярость' : 'Enter rage'))
                  ]));
      if (confirmed != true || !mounted) return;
    }
    setState(() => _rageBusy = true);
    final frenzied = widget.character.isFrenzied;
    try {
      final changed = await ClassSessionActionsService.rage(
          widget.character, widget.rageFeature.id, value,
          expectedConcentration: concentration);
      if (!mounted || !changed) return;
      if (!value) {
        _frenzyPulseController.stop();
        _frenzyPulseController.reverse();
      }
      HapticFeedback.mediumImpact();
      widget.onChanged?.call();
      AppSnackBar.success(
          context,
          value
              ? (ru ? 'Ярость началась' : 'Rage started')
              : frenzied
                  ? (ru
                      ? 'Ярость завершилась · истощение +1'
                      : 'Rage ended · exhaustion +1')
                  : (ru ? 'Ярость завершилась' : 'Rage ended'));
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            ru
                ? 'Не удалось изменить ярость. Проверь состояние и остаток использований.'
                : 'Could not change rage. Check your conditions and remaining uses.');
      }
    } finally {
      if (mounted) setState(() => _rageBusy = false);
    }
  }

  Future<void> _setHelper({bool? reckless, bool? frenzied}) async {
    if (_rageBusy) return;
    setState(() => _rageBusy = true);
    try {
      await ClassSessionActionsService.helpers(widget.character,
          reckless: reckless, frenzied: frenzied);
      if (mounted) {
        HapticFeedback.mediumImpact();
        widget.onChanged?.call();
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            Localizations.localeOf(context).languageCode == 'ru'
                ? 'Не удалось сохранить умение.'
                : 'Could not save the feature.');
      }
    } finally {
      if (mounted) setState(() => _rageBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.rageFeature.resourcePool;
    // NUCLEAR OPTION: Crash Prevention
    if (pool == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final level = widget.character.classLevel('barbarian');
    final rageDamage = _getRageDamage(level);
    final isUnlimited =
        ClassSessionActionsService.unlimitedRage(widget.character);

    final String locale = Localizations.localeOf(context).languageCode;

    // Localize subclass name
    String subclassDisplayName =
        CharacterClassContext(widget.character, 'barbarian').subclass ?? '';
    final classData =
        CharacterClassContext(widget.character, 'barbarian').definition;
    if (classData != null && subclassDisplayName.isNotEmpty) {
      final nid = subclassDisplayName.toLowerCase().trim();
      final targetSubclass = classData.subclasses
          .where(
            (s) =>
                s.id == nid || s.name.values.any((v) => v.toLowerCase() == nid),
          )
          .firstOrNull;
      if (targetSubclass != null) {
        subclassDisplayName = targetSubclass.getName(locale);
      }
    }

    // Find Reckless Attack
    final recklessFeature = widget.character.features
        .where((f) =>
            (f.id).toLowerCase().contains('reckless') &&
            CharacterClassContext(widget.character, 'barbarian')
                .canUseFeature(f) &&
            f.minLevel <= level)
        .firstOrNull;

    // Find Frenzy
    final frenzyFeature = widget.character.features
        .where((f) =>
            (f.id).toLowerCase().contains('frenzy') &&
            CharacterClassContext(widget.character, 'barbarian')
                .canUseFeature(f) &&
            f.minLevel <= level)
        .firstOrNull;

    final recklessHelperText = _isReckless
        ? (locale == 'ru'
            ? 'Преимущество на атаки Силой до конца хода; враги атакуют вас с преимуществом до следующего хода.'
            : 'Advantage on Strength-based attacks until end of turn; enemies have advantage against you until your next turn.')
        : (locale == 'ru'
            ? 'Не требует Ярости. Используйте для первой рукопашной атаки Силой в свой ход.'
            : 'Does not require Rage. Use it for your first Strength-based melee attack on your turn.');

    return ClassPanelFrame(
        character: widget.character,
        classId: 'barbarian',
        child: ClassToolsLayoutBuilder(
          padding: EdgeInsets.zero,
          children: [
            if (subclassDisplayName.isNotEmpty)
              ListTile(
                  dense: true,
                  minTileHeight: 40,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(subclassDisplayName,
                      style: TextStyle(color: colorScheme.secondary)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showSubclassLore(context)),

            ClassPrimaryControl(
                classId: 'barbarian',
                title: l10n.rage,
                trailing: isUnlimited
                    ? const Icon(Icons.all_inclusive_rounded, size: 28)
                    : null,
                current: isUnlimited ? null : pool.currentUses,
                maximum: isUnlimited ? null : pool.maxUses,
                marks: !isUnlimited,
                active: _isRaging,
                tone: _isRaging
                    ? colorScheme.primaryContainer
                    : colorScheme.tertiaryContainer,
                footer: classRecoveryLabel(l10n, pool.recoveryType),
                onEdit: () async {
                  final changed = await showResourceValueEditor(
                      context, widget.character, widget.rageFeature);
                  if (mounted && changed) {
                    setState(() => widget.onChanged?.call());
                  }
                },
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('+$rageDamage',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1.1)),
                              Text(locale == 'ru' ? 'к урону' : 'damage bonus',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ])),
                        Flexible(
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                    color: colorScheme.surface
                                        .withValues(alpha: .75),
                                    borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
                                child: Text(
                                    _isRaging ? l10n.raging : l10n.rageInactive,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)))),
                      ]),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                          onPressed:
                              _isRaging || isUnlimited || pool.currentUses > 0
                                  ? (_rageBusy
                                      ? null
                                      : () => _toggleRage(!_isRaging))
                                  : null,
                          icon: Icon(_isRaging
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded),
                          label: Text(_isRaging
                              ? (locale == 'ru'
                                  ? 'Завершить ярость'
                                  : 'End rage')
                              : (locale == 'ru'
                                  ? 'Впасть в ярость'
                                  : 'Enter rage'))),
                      if (frenzyFeature != null && _isRaging) ...[
                        const SizedBox(height: 12),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(frenzyFeature.getName(locale)),
                            subtitle: Text(locale == 'ru'
                                ? 'После ярости — степень истощения'
                                : 'Exhaustion when rage ends'),
                            onLongPress: () => _showFeatureDetails(
                                frenzyFeature, Icons.bolt_rounded),
                            trailing: IconButton(
                                tooltip: frenzyFeature.getName(locale),
                                icon: Icon(_isFrenzied
                                    ? Icons.check_rounded
                                    : Icons.bolt_rounded),
                                onPressed: _isFrenzied
                                    ? null
                                    : (_rageBusy
                                        ? null
                                        : () => _setHelper(frenzied: true)))),
                      ],
                    ])),

            // Reckless Attack
            if (recklessFeature != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: companionDecoration(context,
                    quiet: true,
                    color: _isReckless
                        ? colorScheme.errorContainer
                        : colorScheme.surfaceContainerLow,
                    shape: const CompanionShape()),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.lgPlus),
                    onLongPress: () => _showFeatureDetails(
                        recklessFeature, Icons.warning_amber),
                    onTap: _rageBusy
                        ? null
                        : () => _setHelper(reckless: !_isReckless),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: _isReckless
                                ? colorScheme.onErrorContainer
                                : colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recklessFeature.getName(locale),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isReckless
                                        ? colorScheme.onErrorContainer
                                        : colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  recklessHelperText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _isReckless
                                        ? colorScheme.onErrorContainer
                                            .withValues(alpha: 0.8)
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isReckless,
                            onChanged: _rageBusy
                                ? null
                                : (v) => _setHelper(reckless: v),
                            activeThumbColor: colorScheme.onErrorContainer,
                            activeTrackColor: colorScheme.onErrorContainer
                                .withValues(alpha: 0.3),
                            inactiveThumbColor: colorScheme.outline,
                            inactiveTrackColor:
                                colorScheme.surfaceContainerHighest,
                            trackOutlineColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.transparent;
                              }
                              return colorScheme.outline;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ));
  }
}
