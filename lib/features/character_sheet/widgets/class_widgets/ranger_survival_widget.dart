import '../../../../core/ui/companion_surface.dart';
import 'shared/class_panel_presentation.dart';
import '../../../../core/progression/character_class_context.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/models/class_data.dart';
import '../../../../core/constants/ranger_options.dart';
import '../../../../core/services/feature_service.dart';
import '../../../../core/services/spell_service.dart';
import '../../../../core/magic/class_spell_grants.dart';
import '../../../../core/magic/companion_state.dart';
import '../../../../shared/widgets/companion_editor.dart';
import '../session/value_editor_dialog.dart';
import '../../../../core/magic/spell_use.dart';
import '../../../../core/services/class_session_actions_service.dart';
import '../../../../core/services/feature_slot_actions_service.dart';
import '../../../../shared/widgets/spell_cast_sheet.dart';
import '../../../../shared/widgets/feature_slot_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import '../../../../shared/widgets/spell_details_sheet.dart';
import 'shared/class_tools_layout_builder.dart';

class RangerSurvivalWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature? primevalAwareness;
  final VoidCallback? onChanged;

  const RangerSurvivalWidget({
    super.key,
    required this.character,
    this.primevalAwareness,
    this.onChanged,
  });

  @override
  State<RangerSurvivalWidget> createState() => _RangerSurvivalWidgetState();
}

class _RangerSurvivalWidgetState extends State<RangerSurvivalWidget> {
  late TextEditingController _targetController;
  bool _sessionBusy = false;
  Timer? _targetSaveTimer;
  String? _pendingTarget;
  void _queueTarget(String value) {
    _pendingTarget = value;
    _targetSaveTimer?.cancel();
    _targetSaveTimer = Timer(const Duration(milliseconds: 400), _flushTarget);
  }

  void _flushTarget() {
    final value = _pendingTarget;
    _pendingTarget = null;
    _targetSaveTimer?.cancel();
    if (value == null) return;
    ClassSessionActionsService.huntersMark(widget.character, target: value)
        .catchError((Object _) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
      return false;
    });
  }

  Future<void> _sessionChange(Future<void> Function() action) async {
    if (_sessionBusy) return;
    setState(() => _sessionBusy = true);
    try {
      await action();
      if (mounted) {
        HapticFeedback.selectionClick();
        widget.onChanged?.call();
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _sessionBusy = false);
    }
  }

  Future<void> _markTarget({bool drop = false, bool move = false}) =>
      _sessionChange(() async {
        _targetSaveTimer?.cancel();
        _pendingTarget = null;
        await ClassSessionActionsService.huntersMark(widget.character,
            target: move ? '' : _targetController.text, drop: drop);
        if (mounted && (drop || move)) _targetController.clear();
      });

  @override
  void initState() {
    super.initState();
    _targetController =
        TextEditingController(text: widget.character.huntersMarkTarget ?? '');
  }

  @override
  void dispose() {
    _flushTarget();
    _targetController.dispose();
    super.dispose();
  }

  List<CharacterFeature> _getHunterTactics() {
    final keywords = [
      'colossus',
      'horde',
      'giant',
      'escape the horde',
      'multiattack defense',
      'steel will',
      'volley',
      'whirlwind',
      'evasion',
      'stand against',
      'uncanny dodge',
      'колосс',
      'орд',
      'великанов',
      'побег',
      'защита от мульти',
      'стальная',
      'залп',
      'вихрев',
      'увертлив',
      'стойкость против',
      'невероятное уклонение'
    ];

    return widget.character.features.where((f) {
      if (!CharacterClassContext(widget.character, 'ranger').canUseFeature(f)) {
        return false;
      }
      final id = f.id.toLowerCase();

      // Exclude main container feature
      if (id == 'hunters-prey' ||
          id == 'hunter-s-prey' ||
          id == 'defensive-tactics' ||
          id == 'superior-hunters-defense' ||
          id == 'multiattack') {
        return false;
      }

      final name = f.nameEn.toLowerCase();
      final nameRu = f.nameRu.toLowerCase();
      return keywords.any((k) =>
          id.contains(k.replaceAll(' ', '-')) ||
          id.contains(k.replaceAll(' ', '_')) ||
          name.contains(k) ||
          nameRu.contains(k));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;
    final blockBg = colorScheme.surfaceContainerLow;
    final greenAccent = colorScheme.primary;

    final List<Widget> blocks = [];

    // --- БЛОК А: АРХЕТИП ОХОТНИКА (Hunter's Identity) ---
    final isHunter = CharacterClassContext(widget.character, 'ranger')
                .subclass
                ?.toLowerCase() ==
            'hunter' ||
        CharacterClassContext(widget.character, 'ranger')
                .subclass
                ?.toLowerCase() ==
            'охотник';
    if (isHunter) {
      blocks
          .add(_buildHunterArchetypeBlock(context, colorScheme, locale, l10n));
    }

    if (!isHunter &&
        CharacterClassContext(widget.character, 'ranger').subclass != null) {
      blocks.add(
          ClassSubclassLink(character: widget.character, classId: 'ranger'));
    }

    // --- БЛОК Б: ТРЕКЕР "МЕТКИ ОХОТНИКА" ---
    final mark = ClassSpellGrants.spell('hunters-mark');
    var knowsHuntersMark = widget.character.isHuntersMarkActive;
    try {
      knowsHuntersMark = knowsHuntersMark ||
          mark != null &&
              SpellUse.visible(widget.character).any((s) => s.id == mark.id);
    } on FormatException {
      // A future personal spellbook must not break unrelated class controls.
    }
    if (knowsHuntersMark) {
      blocks.add(_buildHuntersMarkBlock(context, colorScheme, locale, l10n));
    }

    // --- БЛОК В: ТУМБЛЕР "МАСКИРОВКА" (Hide in Plain Sight) ---
    final hasHideInPlainSight = widget.character.classLevel('ranger') >= 10 &&
        widget.character.features.any((f) =>
            f.id == 'hide-in-plain-sight' ||
            f.id == 'hide_in_plain_sight' ||
            (f.nameEn).toLowerCase().contains('hide in plain sight') ||
            (f.nameRu).toLowerCase().contains('маскировка'));
    if (hasHideInPlainSight) {
      blocks
          .add(_buildHideInPlainSightBlock(context, colorScheme, locale, l10n));
    }

    // --- СТАРЫЕ БЛОКИ ---
    if (widget.character.favoredEnemies.isNotEmpty ||
        widget.character.naturalExplorers.isNotEmpty) {
      blocks
          .add(_buildCoreFeaturesBlock(context, colorScheme, blockBg, locale));
    }

    if (widget.primevalAwareness != null) {
      blocks.add(_buildBlockContainer(
        color: blockBg,
        onTap: () => _showDetails(widget.primevalAwareness!),
        padding: const EdgeInsets.all(12),
        child: _buildPrimevalAwarenessContent(
            context, colorScheme, greenAccent, locale),
      ));
    }

    final owner = CharacterClassContext(widget.character, 'ranger');
    final beastMaster =
        FeatureService.matchesSubclass('beast master', owner.subclass);
    bool hasCompanion = false;
    try {
      hasCompanion = CompanionState.read(widget.character) != null;
    } catch (_) {
      hasCompanion = true;
    }
    if (hasCompanion || beastMaster) {
      blocks.add(AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        child: _buildBeastCompanionBlock(
            context, colorScheme, blockBg, greenAccent),
      ));
    }

    if (blocks.isEmpty) return const SizedBox.shrink();

    return ClassPanelFrame(
        character: widget.character,
        classId: 'ranger',
        child: ClassToolsLayoutBuilder(
          padding: EdgeInsets.zero,
          children: blocks,
        ));
  }

  // ===========================================================================
  // БЛОК А: АРХЕТИП ОХОТНИКА
  // ===========================================================================
  Widget _buildHunterArchetypeBlock(BuildContext context,
      ColorScheme colorScheme, String locale, AppLocalizations l10n) {
    final tactics = _getHunterTactics();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(
              CharacterClassContext(widget.character, 'ranger')
                      .subclassName(locale) ??
                  '',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: colorScheme.secondary)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _showSubclassLore(context, colorScheme, locale, l10n)),
      if (tactics.isNotEmpty)
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final tactic in tactics)
            ActionChip(
                side: BorderSide.none,
                backgroundColor: colorScheme.surfaceContainerLow,
                shape: const StadiumBorder(),
                label: Text(tactic.getName(locale)),
                onPressed: () => _showDetails(tactic)),
        ]),
    ]);
  }

  void _showSubclassLore(BuildContext context, ColorScheme colorScheme,
      String locale, AppLocalizations l10n) {
    HapticFeedback.lightImpact();

    final classData =
        CharacterClassContext(widget.character, 'ranger').definition;
    SubclassData? subclassData;

    if (classData != null &&
        CharacterClassContext(widget.character, 'ranger').subclass != null) {
      try {
        subclassData = classData.subclasses.firstWhere((s) {
          return s.name.values.any((val) =>
                  val ==
                  CharacterClassContext(widget.character, 'ranger').subclass) ||
              s.id ==
                  CharacterClassContext(widget.character, 'ranger')
                      .subclass!
                      .toLowerCase()
                      .replaceAll(' ', '_');
        });
      } catch (_) {}
    }

    final description =
        subclassData?.getDescription(locale) ?? l10n.noFeaturesAtLevel1;
    final subclassDisplay = locale == 'ru' ? 'Охотник' : 'Hunter';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.forest, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subclassDisplay,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                description,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // БЛОК Б: МЕТКА ОХОТНИКА (Hunter's Mark)
  // ===========================================================================
  Widget _buildHuntersMarkBlock(BuildContext context, ColorScheme colorScheme,
      String locale, AppLocalizations l10n) {
    final active = widget.character.isHuntersMarkActive;
    return ClassPrimaryControl(
        classId: 'ranger',
        title: l10n.huntersMarkTracker,
        onDetails: () {
          final spell = SpellService.getSpellById('hunters_mark') ??
              SpellService.getSpellById('hunters-mark');
          if (spell != null) {
            showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => SpellDetailsSheet(
                    spell: spell, character: widget.character));
          }
        },
        active: active,
        tone: active
            ? colorScheme.primaryContainer
            : colorScheme.secondaryContainer,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l10n.markBonusDesc,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (active)
            _buildHuntersMarkActiveState(context, colorScheme, locale, l10n)
          else
            _buildHuntersMarkInactiveState(context, colorScheme, locale, l10n),
        ]));
  }

  Widget _buildHuntersMarkInactiveState(BuildContext context,
      ColorScheme colorScheme, String locale, AppLocalizations l10n) {
    return FilledButton.tonalIcon(
      onPressed: () =>
          _showActivateMarkDialog(context, colorScheme, locale, l10n),
      icon: const Icon(Icons.play_arrow),
      label: Text(l10n.markActivate),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
      ),
    );
  }

  Widget _buildHuntersMarkActiveState(BuildContext context,
      ColorScheme colorScheme, String locale, AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _targetController,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: l10n.markTargetName,
              hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              icon:
                  Icon(Icons.person_pin, color: colorScheme.primary, size: 20),
            ),
            enabled: !_sessionBusy,
            textInputAction: TextInputAction.done,
            onChanged: _queueTarget,
            onSubmitted: (_) => _flushTarget(),
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
              _flushTarget();
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sessionBusy ? null : () => _markTarget(move: true),
                icon: const Icon(Icons.arrow_forward),
                label: Text(l10n.moveMark),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _sessionBusy ? null : () => _markTarget(drop: true),
                icon: const Icon(Icons.close),
                label: Text(l10n.markDrop),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showActivateMarkDialog(BuildContext context,
      ColorScheme colorScheme, String locale, AppLocalizations l10n) async {
    final spell = ClassSpellGrants.spell('hunters-mark');
    if (spell == null) return;
    final cast = await showSpellCastSheet(context, widget.character, spell);
    if (mounted && cast) {
      _targetController.text = widget.character.huntersMarkTarget ?? '';
      setState(() {});
      widget.onChanged?.call();
    }
  }

  // ===========================================================================
  // БЛОК В: МАСКИРОВКА (Hide in Plain Sight)
  // ===========================================================================
  Widget _buildHideInPlainSightBlock(BuildContext context,
      ColorScheme colorScheme, String locale, AppLocalizations l10n) {
    final isActive = widget.character.isHiddenInPlainSight;

    final feature = widget.character.features
            .where((f) =>
                f.id == 'hide-in-plain-sight' || f.id == 'hide_in_plain_sight')
            .firstOrNull ??
        FeatureService.getFeatureById('hide-in-plain-sight') ??
        CharacterFeature(
            id: 'hide-in-plain-sight',
            nameEn: 'Hide in Plain Sight',
            nameRu: 'Маскировка',
            descriptionEn: '',
            descriptionRu: '',
            type: FeatureType.action,
            minLevel: 10);

    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      decoration: companionDecoration(context,
          quiet: true,
          color: isActive
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          shape: const CompanionShape(contour: CompanionContour.focus)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDetails(feature),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.visibility_off : Icons.visibility,
                  color: isActive
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.hideInPlainSight,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      if (isActive)
                        Text(
                          l10n.hideInPlainSightDesc,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  onChanged: _sessionBusy
                      ? null
                      : (val) => _sessionChange(() async {
                            await ClassSessionActionsService.hidden(
                                widget.character, val,
                                rangerCamouflage: true);
                            if (context.mounted && val) {
                              AppSnackBar.info(context, l10n.hideSpentMinute);
                            }
                          }),
                  activeThumbColor: colorScheme.onPrimary,
                  activeTrackColor: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // СТАРЫЕ МЕТОДЫ (Оставлены для совместимости)
  // ===========================================================================

  Widget _buildBlockContainer({
    required Color color,
    required Widget child,
    required EdgeInsetsGeometry padding,
    VoidCallback? onTap,
  }) {
    return CompanionSurface(
        quiet: true,
        color: color,
        padding: padding,
        onTap: onTap,
        child: child);
  }

  Widget _buildCoreFeaturesBlock(BuildContext context, ColorScheme colorScheme,
      Color blockBg, String locale) {
    final controls = <Widget>[
      if (widget.character.favoredEnemies.isNotEmpty)
        _buildIdentityCard(context, colorScheme, blockBg, locale,
            title: locale == 'ru' ? 'Избранный враг' : 'Favored Enemy',
            icon: Icons.gps_fixed,
            items: widget.character.favoredEnemies
                .map((e) => RangerOptions.favoredEnemies[e]?[locale] ?? e)
                .toList(),
            featureId: 'favored-enemy'),
      if (widget.character.naturalExplorers.isNotEmpty)
        _buildIdentityCard(context, colorScheme, blockBg, locale,
            title: locale == 'ru' ? 'Исследователь' : 'Explorer',
            icon: Icons.terrain,
            items: widget.character.naturalExplorers
                .map((e) => RangerOptions.naturalExplorers[e]?[locale] ?? e)
                .toList(),
            featureId: 'natural-explorer'),
    ];
    return LayoutBuilder(builder: (context, bounds) {
      if (controls.length == 2 &&
          bounds.maxWidth >= 330 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.25) {
        return IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: controls[0]),
          const SizedBox(width: 12),
          Expanded(child: controls[1])
        ]));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final control in controls) ...[control, const SizedBox(height: 8)]
      ]);
    });
  }

  Widget _buildIdentityCard(BuildContext context, ColorScheme colorScheme,
      Color blockBg, String locale,
      {required String title,
      required IconData icon,
      required List<String> items,
      required String featureId}) {
    return CompanionSurface(
        quiet: true,
        color: colorScheme.secondaryContainer,
        padding: const EdgeInsets.all(14),
        onTap: () {
          final found = widget.character.features
              .where((f) => f.id.contains(featureId.split('-').first))
              .firstOrNull;
          final feature = found ??
              FeatureService.getFeatureById(featureId) ??
              CharacterFeature(
                  id: featureId,
                  nameEn: title,
                  nameRu: title,
                  descriptionEn: '',
                  descriptionRu: '',
                  type: FeatureType.passive,
                  minLevel: 1);
          _showDetails(feature);
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 23, color: colorScheme.secondary),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  for (final item in items)
                    Text(item,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w700, height: 1.4))
                ])),
          ]),
        ]));
  }

  Widget _buildPrimevalAwarenessContent(BuildContext context,
      ColorScheme colorScheme, Color accentColor, String locale) {
    final featureName =
        widget.primevalAwareness?.getName(locale) ?? 'Primeval Awareness';
    final supported = widget.primevalAwareness != null &&
        FeatureSlotActionsService.supportsPrimeval(
            widget.character, widget.primevalAwareness!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.radar, color: accentColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                featureName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(Icons.info_outline,
                size: 16, color: colorScheme.outline.withValues(alpha: 0.5)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: supported
                ? () => _launchRadar(context, locale, colorScheme)
                : () => _showDetails(widget.primevalAwareness!),
            icon: const Icon(Icons.radar, size: 18),
            label: Text(supported
                ? (locale == 'ru' ? 'Ощутить присутствие' : 'Sense presence')
                : (locale == 'ru' ? 'Подробнее об умении' : 'Read ability')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchRadar(
      BuildContext context, String locale, ColorScheme colorScheme) async {
    final feature = widget.primevalAwareness;
    if (feature == null) return;
    final changed =
        await showPrimevalAwarenessSheet(context, widget.character, feature);
    if (mounted && changed == true) {
      setState(() {});
      widget.onChanged?.call();
    }
  }

  Future<void> _editCompanion() async {
    final changed = await showCompanionEditor(context, widget.character);
    if (mounted && changed == true) {
      setState(() {});
      widget.onChanged?.call();
    }
  }

  Future<void> _companionHealth(bool healing) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final changed = await showSheetValueEditor(context,
        title: healing
            ? (ru ? 'Лечение спутника' : 'Heal companion')
            : (ru ? 'Урон спутнику' : 'Damage companion'),
        icon: healing ? Icons.favorite_rounded : Icons.flash_on_rounded,
        fields: [
          SheetNumberField('amount', ru ? 'Количество ОЗ' : 'HP amount', 1,
              minimum: 1)
        ],
        onSave: (values, _) => ClassSessionActionsService.changeCompanionHealth(
            widget.character, values['amount']!,
            healing: healing));
    if (mounted && changed) {
      setState(() {});
      widget.onChanged?.call();
    }
  }

  Widget _buildBeastCompanionBlock(BuildContext context,
      ColorScheme colorScheme, Color blockBg, Color accentColor) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    CompanionState? companion;
    try {
      companion = CompanionState.read(widget.character);
    } catch (_) {
      return CompanionSurface(
          quiet: true,
          child: Text(ru
              ? 'Данные спутника требуют более новой версии приложения.'
              : 'This companion needs a newer app version.'));
    }
    return ClassPrimaryControl(
        classId: 'ranger',
        title: companion?.name ?? (ru ? 'Зверь-спутник' : 'Beast companion'),
        onEdit: _editCompanion,
        trailing: IconButton(
            onPressed: _editCompanion,
            tooltip: ru ? 'Данные спутника' : 'Companion details',
            icon: const Icon(Icons.tune_rounded)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (companion == null) ...[
            Text(
                ru
                    ? 'Запиши имя и ОЗ спутника. Его запас будет учитываться отдельно от Дикого облика.'
                    : 'Record your companion’s name and HP. Its reserve is tracked separately from Wild Shape.',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
                onPressed: _editCompanion,
                icon: const Icon(Icons.add_rounded),
                label: Text(ru ? 'Записать спутника' : 'Record companion')),
          ] else ...[
            ClassFacts(facts: [
              (
                label: ru ? 'ОЗ спутника' : 'Companion HP',
                value: '${companion.current} / ${companion.maximum}'
              )
            ]),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton.tonalIcon(
                  onPressed: companion.current > 0
                      ? () => _companionHealth(false)
                      : null,
                  icon: const Icon(Icons.flash_on_rounded),
                  label: Text(ru ? 'Урон' : 'Damage')),
              FilledButton.tonalIcon(
                  onPressed: companion.current < companion.maximum
                      ? () => _companionHealth(true)
                      : null,
                  icon: const Icon(Icons.favorite_rounded),
                  label: Text(ru ? 'Лечение' : 'Heal')),
            ]),
          ],
        ]));
  }

  void _showDetails(CharacterFeature feature) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(feature: feature),
    );
  }
}
