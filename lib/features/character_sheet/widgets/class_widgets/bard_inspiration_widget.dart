import '../../../../shared/widgets/subclass_details_sheet.dart';
import '../../../../core/ui/companion_surface.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../session/value_editors.dart';
import 'shared/class_panel_presentation.dart';
import '../session/expressive_hold_surface.dart';
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

class BardInspirationWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature inspirationFeature;
  final VoidCallback? onChanged;

  const BardInspirationWidget({
    super.key,
    required this.character,
    required this.inspirationFeature,
    this.onChanged,
  });

  @override
  State<BardInspirationWidget> createState() => _BardInspirationWidgetState();
}

class _BardInspirationWidgetState extends State<BardInspirationWidget> {
  bool _busy = false;

  String _getInspirationDie(int level, String locale) {
    String die;
    if (level >= 15) {
      die = '1d12';
    } else if (level >= 10) {
      die = '1d10';
    } else if (level >= 5) {
      die = '1d8';
    } else {
      die = '1d6';
    }

    if (locale == 'ru') {
      return die.replaceAll('d', 'к');
    }
    return die;
  }

  Future<void> _giveInspiration([CharacterFeature? action]) async {
    if (_busy ||
        !CharacterClassContext(widget.character, 'bard')
            .canUseFeature(action ?? widget.inspirationFeature)) {
      return;
    }
    setState(() => _busy = true);
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    try {
      final spent = await GameplayActionsService.spendResource(
          widget.character, widget.inspirationFeature);
      if (!mounted) return;
      if (spent) {
        HapticFeedback.mediumImpact();
        widget.onChanged?.call();
        AppSnackBar.success(
            context,
            l.gameStateResourceUsed(
                action?.getName(locale) ?? l.bardicInspiration));
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, l.sheetSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editInspiration() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final changed = await showResourceValueEditor(
          context, widget.character, widget.inspirationFeature);
      if (mounted && changed) widget.onChanged?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showFeatureDetails(CharacterFeature feature, IconData icon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(
        feature: feature,
      ),
    );
  }

  Future<void> _showSubclassLore(BuildContext context) async {
    await showClassSubclassDetails(context, widget.character, 'bard');
    if (mounted) {
      setState(() {});
    }
  }

  void _executeQuickAction(CharacterFeature feature, String locale,
      {bool usesInspiration = false}) {
    if (usesInspiration) {
      _giveInspiration(feature);
    } else {
      _showFeatureDetails(feature, Icons.auto_awesome_rounded);
    }
  }

  Widget _buildActionTile(
      CharacterFeature? feature, IconData icon, String locale, ThemeData theme,
      {bool usesInspiration = false}) {
    if (feature == null) return const SizedBox.shrink();
    final die = RegExp(r'^song-of-rest-d(\d+)$').firstMatch(feature.id);
    final name = feature.getName(locale).replaceAll(RegExp(r'\s*\(.*?\)'), '');
    return CompanionSurface(
        contour: die != null ? CompanionContour.cadence : CompanionContour.soft,
        color: die != null
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerLow,
        padding: const EdgeInsets.all(16),
        onTap: () => _showFeatureDetails(feature, icon),
        child: Row(children: [
          Icon(icon, color: theme.colorScheme.secondary, size: 24),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (die != null) ...[
                  const SizedBox(height: 8),
                  Text('${locale == 'ru' ? '1к' : '1d'}${die[1]}',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(AppLocalizations.of(context)!.shortRest,
                      style: theme.textTheme.bodySmall),
                ],
              ])),
          const SizedBox(width: 8),
          if (usesInspiration)
            IconButton.filledTonal(
                tooltip: feature.getName(locale),
                onPressed: !_busy &&
                        (widget.inspirationFeature.resourcePool?.currentUses ??
                                0) >
                            0
                    ? () => _executeQuickAction(feature, locale,
                        usesInspiration: true)
                    : null,
                icon: const Icon(Icons.chat_bubble_outline_rounded))
          else
            const Icon(Icons.chevron_right_rounded, size: 20),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.inspirationFeature.resourcePool;
    if (pool == null) {
      return ClassPanelFrame(
          character: widget.character,
          classId: 'bard',
          child: ListTile(
              title: Text(widget.inspirationFeature
                  .getName(Localizations.localeOf(context).languageCode)),
              subtitle: Text(
                  Localizations.localeOf(context).languageCode == 'ru'
                      ? 'В источнике не указан запас вдохновения'
                      : 'The source does not define an inspiration reserve'),
              trailing: const Icon(Icons.info_outline_rounded),
              onTap: () => _showFeatureDetails(
                  widget.inspirationFeature, Icons.auto_awesome_rounded)));
    }

    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final declaredDie =
        RegExp(r'bardic[-_]inspiration[-_][dк](\d+)', caseSensitive: false)
            .firstMatch(widget.inspirationFeature.id);
    final dieType = declaredDie == null
        ? _getInspirationDie(widget.character.classLevel('bard'), locale)
        : '1${locale == 'ru' ? 'к' : 'd'}${declaredDie[1]}';

    final maxCharges = pool.maxUses;
    final currentCharges = pool.currentUses;

    // Subclass Info
    final subclassDisplayName =
        CharacterClassContext(widget.character, 'bard').subclassName(locale) ??
            '';

    // Quick Actions
    final cuttingWords = widget.character.features
        .where(CharacterClassContext(widget.character, 'bard').canUseFeature)
        .where((f) =>
            f.id.toLowerCase().contains('cutting_word') ||
            f.id.toLowerCase().contains('cutting-word'))
        .firstOrNull;
    final combatInspiration = widget.character.features
        .where(CharacterClassContext(widget.character, 'bard').canUseFeature)
        .where((f) =>
            f.id.toLowerCase().contains('combat_inspiration') ||
            f.id.toLowerCase().contains('combat-inspiration'))
        .firstOrNull;
    final countercharm = widget.character.features
        .where(CharacterClassContext(widget.character, 'bard').canUseFeature)
        .where((f) => f.id.toLowerCase().contains('countercharm'))
        .firstOrNull;
    final songOfRest = widget.character.features
        .where(CharacterClassContext(widget.character, 'bard').canUseFeature)
        .where((f) =>
            f.id.toLowerCase().contains('song_of_rest') ||
            f.id.toLowerCase().contains('song-of-rest'))
        .firstOrNull;

    return ClassPanelFrame(
        character: widget.character,
        classId: 'bard',
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

            ExpressiveHoldSurface(
                enabled: !_busy,
                onHold: _editInspiration,
                semanticLabel: l10n.bardicInspiration,
                hint: l10n.sheetHoldToEdit,
                child: CompanionSurface(
                    contour: CompanionContour.cadence,
                    color: colorScheme.primaryContainer,
                    raised: true,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CompanionDieFace(
                                    sides: int.parse(dieType.substring(2)),
                                    accent: colorScheme.primary,
                                    size: 86),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(l10n.bardicInspiration,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -.65,
                                                  height: 1.08)),
                                      const SizedBox(height: 12),
                                      CompanionReserve(
                                          current: currentCharges,
                                          maximum: maxCharges),
                                      if (maxCharges > 0 &&
                                          maxCharges <= 10) ...[
                                        const SizedBox(height: 8),
                                        ExcludeSemantics(
                                            child: Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                              for (var n = 0;
                                                  n < maxCharges;
                                                  n++)
                                                Icon(
                                                    n < currentCharges
                                                        ? Icons
                                                            .auto_awesome_rounded
                                                        : Icons
                                                            .auto_awesome_outlined,
                                                    size: 23,
                                                    color: n < currentCharges
                                                        ? colorScheme.secondary
                                                        : colorScheme
                                                            .onSurfaceVariant
                                                            .withValues(
                                                                alpha: .45)),
                                            ])),
                                      ],
                                    ])),
                              ]),
                          const SizedBox(height: 18),
                          FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                  backgroundColor:
                                      colorScheme.surface.withValues(alpha: .8),
                                  foregroundColor: colorScheme.onSurface,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 13),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadii.xl))),
                              onPressed: !_busy && currentCharges > 0
                                  ? _giveInspiration
                                  : null,
                              icon: Icon(Icons.person_add_alt_1_rounded,
                                  color: currentCharges > 0
                                      ? colorScheme.secondary
                                      : null),
                              label: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        locale == 'ru'
                                            ? 'Вдохновить'
                                            : 'Inspire',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800)),
                                    Text(
                                        locale == 'ru'
                                            ? 'Передать кость союзнику'
                                            : 'Give an ally an inspiration die',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ])),
                          Row(children: [
                            Expanded(
                                child: Text(
                                    classRecoveryLabel(l10n, pool.recoveryType),
                                    style:
                                        Theme.of(context).textTheme.bodySmall)),
                            IconButton(
                                tooltip: l10n.advancementDetails,
                                onPressed: () => _showFeatureDetails(
                                    widget.inspirationFeature,
                                    Icons.auto_awesome_rounded),
                                icon: const Icon(Icons.info_outline_rounded,
                                    size: 20)),
                          ]),
                        ]))),

            // Quick Actions Block
            if (cuttingWords != null ||
                combatInspiration != null ||
                countercharm != null ||
                songOfRest != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 18, color: colorScheme.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                          locale == 'ru' ? 'Другие умения' : 'More features',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.secondary,
                          ),
                        )),
                      ],
                    ),
                  ),
                  ...[
                    if (cuttingWords != null)
                      _buildActionTile(cuttingWords, Icons.record_voice_over,
                          locale, Theme.of(context),
                          usesInspiration: true),
                    if (combatInspiration != null)
                      _buildActionTile(combatInspiration, Icons.shield, locale,
                          Theme.of(context)),
                    if (countercharm != null)
                      _buildActionTile(countercharm, Icons.queue_music, locale,
                          Theme.of(context)),
                    if (songOfRest != null)
                      _buildActionTile(
                          songOfRest, Icons.bedtime, locale, Theme.of(context)),
                  ].expand((w) => [w, const SizedBox(height: 8)]).toList()
                    ..removeLast(),
                ],
              ),
          ],
        ));
  }
}
