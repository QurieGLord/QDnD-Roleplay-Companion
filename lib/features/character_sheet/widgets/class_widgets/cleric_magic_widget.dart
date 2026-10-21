import '../../../../core/ui/companion_surface.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/ui/sheet_drag_region.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import 'shared/class_panel_presentation.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/magic/class_action_state.dart';
import '../../../../core/services/class_session_actions_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/character.dart';
import 'shared/class_tools_layout_builder.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class ClericMagicWidget extends StatefulWidget {
  final Character character;
  final VoidCallback onStateChanged;

  const ClericMagicWidget({
    super.key,
    required this.character,
    required this.onStateChanged,
  });

  @override
  State<ClericMagicWidget> createState() => _ClericMagicWidgetState();
}

class _ClericMagicWidgetState extends State<ClericMagicWidget> {
  bool _usingChannel = false;
  bool _usingIntervention = false;
  Future<void> _useChannel({int amount = 1}) async {
    if (_usingChannel) return;
    setState(() => _usingChannel = true);
    final l = AppLocalizations.of(context)!;
    try {
      final changed = await GameplayActionsService.spendChannelDivinity(
          widget.character,
          amount: amount);
      if (mounted && changed) {
        HapticFeedback.mediumImpact();
        widget.onStateChanged();
        AppSnackBar.success(context, l.usedChannelDivinity);
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, l.sheetSaveFailed);
    } finally {
      if (mounted) setState(() => _usingChannel = false);
    }
  }

  void _showCDRules() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadii.xs),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.auto_awesome,
                      color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.channelDivinity.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.channelDivinityRules,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTurnUndeadRules() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final level = widget.character.classLevel('cleric');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadii.xs),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.security, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (level >= 5 ? l10n.destroyUndead : l10n.turnUndead)
                          .toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                l10n.turnUndeadRules,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              if (level >= 5) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.destroyUndeadRules,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDIRules() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadii.xs),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.brightness_high,
                      color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.divineIntervention.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.divineInterventionRules,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final clericColor = theme.colorScheme.primary;
    final maxCharges =
        widget.character.channelDivinityResource?.resourcePool?.maxUses ??
            widget.character.getMaxChannelDivinityCharges();

    return ClassPanelFrame(
        character: widget.character,
        classId: 'cleric',
        child: ClassToolsLayoutBuilder(
          padding: EdgeInsets.zero,
          children: [
            // 1. Divine Domain Block
            if (CharacterClassContext(widget.character, 'cleric').subclass !=
                null)
              _buildDomainBlock(context, theme, l10n, clericColor),

            // 2. Channel Divinity Block (Includes Turn Undead)
            if (widget.character.classLevel('cleric') >= 2 &&
                (maxCharges > 0 || widget.character.channelDivinityCharges > 0))
              _buildChannelDivinityBlock(
                  context, theme, l10n, clericColor, maxCharges),

            // 3. Divine Intervention Block
            if (widget.character.classLevel('cleric') >= 10 &&
                widget.character.features.any((f) =>
                    f.id.replaceAll('_', '-') == 'divine-intervention' &&
                    CharacterClassContext(widget.character, 'cleric')
                        .acceptsFeature(f)))
              _buildDivineInterventionBlock(context, theme, l10n, clericColor),
          ],
        ));
  }

  Widget _buildDomainBlock(BuildContext context, ThemeData theme,
          AppLocalizations l10n, Color accentColor) =>
      ClassSubclassLink(character: widget.character, classId: 'cleric');

  Widget _buildChannelDivinityBlock(BuildContext context, ThemeData theme,
      AppLocalizations l10n, Color accentColor, int maxCharges) {
    return ClassPrimaryControl(
        classId: 'cleric',
        title: l10n.channelDivinity,
        onDetails: _showCDRules,
        current: widget.character.channelDivinityCharges,
        maximum: maxCharges,
        marks: true,
        tone: theme.colorScheme.tertiaryContainer,
        footer: classRecoveryLabel(
            l10n,
            widget.character.channelDivinityResource?.resourcePool
                    ?.recoveryType ??
                RecoveryType.shortRest),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.character.classLevel('cleric') >= 2)
            _buildTurnUndeadTile(context, theme, l10n, accentColor),
          for (final feature in widget.character.features.where((f) =>
              CharacterClassContext(widget.character, 'cleric')
                  .acceptsFeature(f) &&
              f.usageCostId == 'channel-divinity' &&
              f.isAction &&
              !f.id.toLowerCase().replaceAll('_', '-').contains('turn-undead')))
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _channelOption(feature, theme, l10n)),
        ]));
  }

  Widget _buildTurnUndeadTile(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    Color accentColor,
  ) {
    final colorScheme = theme.colorScheme;
    final level = widget.character.classLevel('cleric');
    final currentCharges = widget.character.channelDivinityCharges;

    String name = l10n.turnUndead;
    String? crText;

    if (level >= 5) {
      name = l10n.destroyUndead;
      String cr = "1/2";
      if (level >= 17) {
        cr = "4";
      } else if (level >= 14) {
        cr = "3";
      } else if (level >= 11) {
        cr = "2";
      } else if (level >= 8) {
        cr = "1";
      }
      crText = "${l10n.maxCR}: $cr";
    }

    return CompanionSurface(
        color: colorScheme.surface.withValues(alpha: .8),
        quiet: true,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: _showTurnUndeadRules,
        child: Row(children: [
          Icon(Icons.shield_outlined, size: 25, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (crText != null)
                  Text(crText, style: theme.textTheme.bodySmall),
              ])),
          const SizedBox(width: 8),
          IconButton.filledTonal(
              tooltip: l10n.useAction,
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: !_usingChannel && currentCharges > 0
                  ? () => _useChannel()
                  : null),
        ]));
  }

  Widget _channelOption(
      CharacterFeature feature, ThemeData theme, AppLocalizations l) {
    final locale = Localizations.localeOf(context).languageCode;
    final cost = feature.consumption?.amount ?? 1;
    return CompanionSurface(
        color: theme.colorScheme.surface.withValues(alpha: .8),
        quiet: true,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: () => showResponsiveSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => FeatureDetailsSheet(feature: feature)),
        child: Row(children: [
          Icon(Icons.auto_awesome_rounded,
              size: 25, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    feature
                        .getName(locale)
                        .replaceFirst(RegExp(r'^Божественный канал:\s*'), '')
                        .replaceFirst(RegExp(r'^Channel Divinity:\s*'), ''),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    locale == 'ru'
                        ? 'Из общего запаса: $cost'
                        : 'Shared reserve: $cost',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ])),
          const SizedBox(width: 8),
          IconButton.filledTonal(
              tooltip: '${l.useAction}: ${feature.getName(locale)}',
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: !_usingChannel &&
                      cost > 0 &&
                      widget.character.channelDivinityCharges >= cost
                  ? () => _useChannel(amount: cost)
                  : null),
        ]));
  }

  Widget _buildDivineInterventionBlock(BuildContext context, ThemeData theme,
      AppLocalizations l10n, Color accentColor) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final used = widget.character.divineInterventionUsed;
    bool attempted = false, supported = true;
    try {
      attempted = ClassActionState.interventionAttempted(widget.character);
    } catch (_) {
      supported = false;
    }
    final level = widget.character.classLevel('cleric');
    final ready = supported && !used && !attempted;
    final status = !supported
        ? (ru ? 'Нужна более новая версия' : 'A newer version is needed')
        : used
            ? (ru ? 'Ожидание · 7 дней' : 'Waiting · 7 days')
            : attempted
                ? (ru ? 'После продолжительного отдыха' : 'After a long rest')
                : (ru ? 'Можно воззвать' : 'Ready to call');
    return ClassPrimaryControl(
        classId: 'cleric',
        title: l10n.divineIntervention,
        active: ready,
        busy: _usingIntervention,
        onDetails: _showDIRules,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClassFacts(facts: [
            (
              label: ru ? 'Ответ божества' : 'Divine response',
              value: level >= 20 ? (ru ? 'Без броска' : 'No roll') : '$level%'
            ),
            (label: ru ? 'Состояние' : 'Availability', value: status),
          ]),
          const SizedBox(height: 16),
          Text(
              ru
                  ? 'Опиши мастеру, о какой помощи просишь. Он определит, каким будет вмешательство.'
                  : 'Describe the aid you seek to your GM. They decide how the intervention takes effect.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 18),
          if (ready)
            FilledButton.tonalIcon(
                onPressed:
                    _usingIntervention ? null : () => _handleInterventionRoll(),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(l10n.callUponDeity))
          else if (supported)
            TextButton.icon(
                onPressed:
                    _usingIntervention ? null : () => _resetIntervention(),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(ru ? 'Отметить готовность' : 'Mark as ready')),
        ]));
  }

  Future<void> _resetIntervention() async {
    if (_usingIntervention) return;
    setState(() => _usingIntervention = true);
    try {
      await ClassSessionActionsService.resetDivineIntervention(
          widget.character);
      if (mounted) {
        HapticFeedback.selectionClick();
        widget.onStateChanged();
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _usingIntervention = false);
    }
  }

  Future<void> _handleInterventionRoll() async {
    if (_usingIntervention) return;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    setState(() => _usingIntervention = true);
    try {
      final result = await ClassSessionActionsService.divineIntervention(
          widget.character,
          locale: ru ? 'ru' : 'en');
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      widget.onStateChanged();
      await showResponsiveSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) {
            final t = Theme.of(context), c = t.colorScheme;
            return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          ru
                              ? 'Божественное вмешательство'
                              : 'Divine Intervention',
                          style: t.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 20),
                      CompanionSurface(
                          contour: CompanionContour.focus,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    result.success
                                        ? (ru
                                            ? 'Мольба услышана'
                                            : 'Your prayer is heard')
                                        : (ru
                                            ? 'Пока без ответа'
                                            : 'No answer this time'),
                                    style: t.textTheme.titleLarge),
                                const SizedBox(height: 12),
                                Text(
                                    result.roll == null
                                        ? (ru ? 'Без броска' : 'No roll')
                                        : '${result.roll}',
                                    style: t.textTheme.displayMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: c.secondary)),
                                if (result.roll != null)
                                  Text('d100', style: t.textTheme.labelLarge),
                                const SizedBox(height: 16),
                                Text(
                                    result.success
                                        ? (ru
                                            ? 'Мастер определяет помощь. Повторное обращение — через 7 дней.'
                                            : 'Your GM determines the aid. You can call again in 7 days.')
                                        : (ru
                                            ? 'Повтори попытку после продолжительного отдыха.'
                                            : 'Try again after a long rest.'),
                                    style: t.textTheme.bodyLarge),
                              ])),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(ru ? 'Продолжить' : 'Continue')),
                    ]));
          });
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _usingIntervention = false);
    }
  }
}
