import 'dart:convert';
import '../../../shared/widgets/magic_allocation_sheet.dart';
import '../../../core/ui/app_menu_style.dart';
import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../core/models/character.dart';
import '../../../core/models/condition.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/feature_service.dart';
import '../../../core/services/gameplay_actions_service.dart';
import '../../../core/services/qdnd_bundle_codec.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/ui/app_snack_bar.dart';
import '../../../core/ui/condition_presentation.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import '../../../core/ui/expressive_kit.dart';

Future<bool> showGameplayStateEditor(
  BuildContext context,
  Character character,
) async =>
    await showDialog<bool>(
      context: context,
      useSafeArea: false,
      builder: (_) => GameplayStateEditor(character: character),
    ) ??
    false;

/// Direct edits are drafted locally. Cancel/invalid input cannot change the hero.
class GameplayStateEditor extends StatefulWidget {
  const GameplayStateEditor({super.key, required this.character});
  final Character character;

  @override
  State<GameplayStateEditor> createState() => _GameplayStateEditorState();
}

class _GameplayStateEditorState extends State<GameplayStateEditor> {
  final _formKey = GlobalKey<FormState>();
  final _numbers = <String, TextEditingController>{};
  late Character _draft;
  late bool _manualArmor;
  bool _saving = false;
  bool _channelDivinityEdited = false;
  final _arcanumEdited = <int>{};
  late final Set<String> _initialUsedMarks;

  @override
  void initState() {
    super.initState();
    _draft = _clone(widget.character);
    _manualArmor = !_draft.usesAutomaticArmorClass;
    _initialUsedMarks = {
      if (_draft.arcaneRecoveryUsed) 'arcane-used',
      if (_draft.naturalRecoveryUsed) 'natural-used',
      if (_draft.divineInterventionUsed) 'intervention-used',
    };
  }

  Character _clone(Character character) =>
      QdndBundleCodec.cloneCharacter(character);

  @override
  void dispose() {
    for (final controller in _numbers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _number(String id, String label, int initial,
      {String? hint, int? limit, bool enabled = true}) {
    final controller =
        _numbers.putIfAbsent(id, () => TextEditingController(text: '$initial'));
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 34),
        child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(label, style: theme.textTheme.labelLarge)),
      ),
      const SizedBox(height: 8),
      Semantics(
          label: label,
          child: TextFormField(
            key: ValueKey('game-state-$id'),
            controller: controller,
            enabled: enabled && !_saving,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
            onChanged: (_) {
              if (id == 'channel-divinity') _channelDivinityEdited = true;
              if (id.startsWith('arcanum-')) {
                _arcanumEdited.add(int.parse(id.substring('arcanum-'.length)));
              }
            },
            decoration: _inputDecoration(),
            validator: (text) {
              if (!enabled) return null;
              final value = int.tryParse(text ?? '');
              if (value == null ||
                  value < 0 ||
                  (limit != null && value > limit)) {
                return AppLocalizations.of(context)!.gameStateNumbersOnly;
              }
              return null;
            },
          )),
      if (hint != null) ...[
        const SizedBox(height: 8),
        Text(hint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    ]);
  }

  InputDecoration _inputDecoration({String? label}) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.lgPlus),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.lgPlus),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.lgPlus),
            borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 2)),
      );

  Widget _mark(
    String id,
    String label,
    bool value,
    ValueChanged<bool> change,
  ) =>
      SwitchListTile(
        key: ValueKey('game-state-$id'),
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: _saving ? null : (next) => setState(() => change(next)),
      );

  int _value(String id, int previous) =>
      int.tryParse(_numbers[id]?.text ?? '') ?? previous;

  void _readValues() {
    final oldScores = _draft.abilityScores.toJson();
    _draft.abilityScores = _draft.abilityScores.copyWith(
      strength: _value('strength', _draft.abilityScores.strength),
      dexterity: _value('dexterity', _draft.abilityScores.dexterity),
      constitution: _value('constitution', _draft.abilityScores.constitution),
      intelligence: _value('intelligence', _draft.abilityScores.intelligence),
      wisdom: _value('wisdom', _draft.abilityScores.wisdom),
      charisma: _value('charisma', _draft.abilityScores.charisma),
    );
    if (oldScores.entries.any(
      (entry) => _draft.abilityScores.toJson()[entry.key] != entry.value,
    )) {
      FeatureService.updateFeatureMaxUses(_draft);
    }
    _draft.currentHp = _value('hp', _draft.currentHp);
    _draft.maxHp = _value('max-hp', _draft.maxHp);
    _draft.temporaryHp = _value('temp-hp', _draft.temporaryHp);
    _draft.speed = _value('speed', _draft.speed);
    _draft.exhaustionLevel = _value('exhaustion', _draft.exhaustionLevel);
    _draft.relentlessRageSaveDc = _value(
      'relentless-dc',
      _draft.relentlessRageSaveDc,
    );
    _draft.deathSaves.successes = _value(
      'death-success',
      _draft.deathSaves.successes,
    );
    _draft.deathSaves.failures = _value(
      'death-failure',
      _draft.deathSaves.failures,
    );
    for (int i = 0; i < _draft.hitDice.length; i++) {
      _draft.hitDice[i] = _value('hit-die-$i', _draft.hitDice[i]);
    }
    if (_manualArmor) {
      _draft.armorClass = _value('armor', _draft.armorClass);
    } else {
      _draft.clearArmorClassOverride();
    }
    for (int i = 1; i <= 9; i++) {
      final previous =
          i <= _draft.spellSlots.length ? _draft.spellSlots[i - 1] : 0;
      // Do not expand an untouched absent slot level or mutate its normal limit.
      final value = _value('slot-$i', previous);
      if (value != previous) _draft.setSpellSlotCount(i, value);
    }
    for (int i = 0; i < _draft.features.length; i++) {
      final pool = _draft.features[i].resourcePool;
      if (pool != null &&
          !Character.isChannelDivinityResource(_draft.features[i])) {
        pool.setCurrentUses(_value('pool-$i', pool.currentUses));
      }
    }
    // Missing arcanum metadata stays absent until the player edits its value.
    for (final level in _arcanumEdited) {
      final existing = GameplayActionsService.arcanumFeature(_draft, level);
      final feature = existing ??
          FeatureService.getFeatureById('mystic-arcanum-${level}th-level')
              ?.copyForCharacter();
      if (feature == null) continue;
      if (existing == null) _draft.features.add(feature);
      feature.resourcePool ??= ResourcePool(
          currentUses: 0, maxUses: 1, recoveryType: RecoveryType.longRest);
      feature.resourcePool!.setCurrentUses(
          _value('arcanum-$level', feature.resourcePool!.currentUses));
    }
    if (_channelDivinityEdited) {
      _draft.setChannelDivinityCharges(
          _value('channel-divinity', _draft.editableChannelDivinityCharges));
    }
    _draft.wildShapeCharges = _value(
      'wild-shape-uses',
      _draft.wildShapeCharges,
    );
    if (_draft.beastCurrentHp != null) {
      _draft.beastCurrentHp = _value('beast-hp', _draft.beastCurrentHp!);
    }
    if (_draft.beastMaxHp != null) {
      _draft.beastMaxHp = _value('beast-max-hp', _draft.beastMaxHp!);
    }
  }

  void _copyState(Character from, Character to) {
    to.currentHp = from.currentHp;
    to.maxHp = from.maxHp;
    to.abilityScores = from.abilityScores.copyWith();
    to.temporaryHp = from.temporaryHp;
    to.speed = from.speed;
    to.armorClass = from.armorClass;
    to.armorClassOverride = from.armorClassOverride;
    to.usesAutomaticArmorClass = from.usesAutomaticArmorClass;
    to.exhaustionLevel = from.exhaustionLevel;
    to.deathSaves.successes = from.deathSaves.successes;
    to.deathSaves.failures = from.deathSaves.failures;
    to.hitDice = List<int>.from(from.hitDice);
    to.spellSlots = List<int>.from(from.spellSlots);
    to.maxSpellSlots = List<int>.from(from.maxSpellSlots);
    to.magicData = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(from.magicData)) as Map);
    to.features = from.features.map((f) => f.copyForCharacter()).toList();
    to.channelDivinityCharges = from.channelDivinityCharges;
    to.wildShapeCharges = from.wildShapeCharges;
    to.beastCurrentHp = from.beastCurrentHp;
    to.beastMaxHp = from.beastMaxHp;
    to.activeConditions = List<ConditionType>.from(from.activeConditions);
    to.concentratingOn = from.concentratingOn;
    to.isWildShaped = from.isWildShaped;
    to.isRaging = from.isRaging;
    to.isFrenzied = from.isFrenzied;
    to.isReckless = from.isReckless;
    to.isHidden = from.isHidden;
    to.isSacredWeaponActive = from.isSacredWeaponActive;
    to.isHuntersMarkActive = from.isHuntersMarkActive;
    to.isHiddenInPlainSight = from.isHiddenInPlainSight;
    to.arcaneRecoveryUsed = from.arcaneRecoveryUsed;
    to.naturalRecoveryUsed = from.naturalRecoveryUsed;
    to.divineInterventionUsed = from.divineInterventionUsed;
    to.signatureSpellsUsed = Map<String, bool>.from(from.signatureSpellsUsed);
    to.relentlessRageSaveDc = from.relentlessRageSaveDc;
    to.updatedAt = from.updatedAt;
  }

  Future<void> _save() async {
    if (_saving) return;
    final fieldsValid = _formKey.currentState!.validate();
    // Collapsed sections still own their drafts, even when form fields unmount.
    final draftsValid = _numbers.entries.every((entry) {
      if (entry.key == 'armor' && !_manualArmor) return true;
      final value = int.tryParse(entry.value.text);
      final limit = entry.key == 'exhaustion'
          ? 6
          : entry.key.startsWith('death-')
              ? 3
              : null;
      return value != null && value >= 0 && (limit == null || value <= limit);
    });
    if (!fieldsValid || !draftsValid) {
      AppSnackBar.warning(
        context,
        AppLocalizations.of(context)!.gameStateNumbersOnly,
      );
      return;
    }
    _readValues();
    setState(() => _saving = true);
    try {
      // In the hero's write queue, after any action still being written.
      await GameplayActionsService.serializeCharacter(widget.character,
          () async {
        final before = _clone(widget.character);
        _copyState(_draft, widget.character);
        try {
          await StorageService.saveCharacter(widget.character);
        } catch (_) {
          _copyState(before, widget.character);
          rethrow;
        }
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.error(
          context,
          AppLocalizations.of(context)!.sheetSaveFailed,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final showTabLabels = !largeText && MediaQuery.sizeOf(context).width >= 360;
    Tab tab(String id, String label, IconData icon) => Tab(
          key: ValueKey('editor-tab-$id'),
          height: showTabLabels ? 64 : 48,
          child: Tooltip(
              message: label,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22),
                  if (showTabLabels) ...[
                    const SizedBox(height: 4),
                    Text(label,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]
                ],
              )),
        );
    return PopScope(
        canPop: !_saving,
        child: DefaultTabController(
          length: 4,
          child: Dialog.fullscreen(
              child: Scaffold(
            backgroundColor: theme.colorScheme.surface,
            appBar: AppBar(
              toolbarHeight: largeText ? 112 : 72,
              titleSpacing: 0,
              title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.sheetEditCharacter,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(widget.character.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ]),
              leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.cancel,
                  onPressed:
                      _saving ? null : () => Navigator.pop(context, false)),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(showTabLabels ? 84 : 68),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadii.xl)),
                    child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: TabBar(
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
                          labelColor: theme.colorScheme.onSecondaryContainer,
                          unselectedLabelColor:
                              theme.colorScheme.onSurfaceVariant,
                          labelPadding: EdgeInsets.zero,
                          onTap: (_) => FocusScope.of(context).unfocus(),
                          tabs: [
                            tab('core', l10n.sheetEditorCore,
                                Icons.person_outline),
                            tab('magic', l10n.magic,
                                Icons.auto_awesome_outlined),
                            tab('resources', l10n.resources,
                                Icons.tune_rounded),
                            tab('conditions', l10n.conditions,
                                Icons.spa_outlined),
                          ],
                        )),
                  ),
                ),
              ),
            ),
            body: Form(
                key: _formKey,
                child: Column(children: [
                  Expanded(
                      child: TabBarView(children: [
                    _editorPage('core', l10n.sheetEditorCore, [
                      _group(l10n.hpShort, Icons.favorite_outline, [
                        _grid([
                          _number(
                              'hp', l10n.gameStateCurrentHp, _draft.currentHp),
                          _number(
                              'max-hp', l10n.gameStateMaximumHp, _draft.maxHp),
                        ]),
                        _number('temp-hp', l10n.tempHp, _draft.temporaryHp),
                      ]),
                      _group(l10n.sheetEditorDefense, Icons.shield_outlined, [
                        _mark('manual-armor', l10n.gameStateManualArmor,
                            _manualArmor, (value) => _manualArmor = value),
                        _grid([
                          _number('armor', l10n.armorClass, _draft.armorClass,
                              enabled: _manualArmor,
                              hint: l10n.gameStateArmorCalculated(
                                  _draft.calculatedArmorClass)),
                          _number('speed', l10n.gameStateSpeed, _draft.speed),
                        ]),
                      ]),
                      _group(l10n.abilities, Icons.bar_chart_rounded, [
                        _grid([
                          _number('strength', l10n.abilityStr,
                              _draft.abilityScores.strength),
                          _number('dexterity', l10n.abilityDex,
                              _draft.abilityScores.dexterity),
                          _number('constitution', l10n.abilityCon,
                              _draft.abilityScores.constitution),
                          _number('intelligence', l10n.abilityInt,
                              _draft.abilityScores.intelligence),
                          _number('wisdom', l10n.abilityWis,
                              _draft.abilityScores.wisdom),
                          _number('charisma', l10n.abilityCha,
                              _draft.abilityScores.charisma),
                        ], maxColumns: 3)
                      ]),
                    ]),
                    _editorPage('magic', l10n.magic, [
                      Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: FilledButton.tonalIcon(
                              icon: const Icon(Icons.auto_awesome_outlined),
                              label: Text(locale == 'ru'
                                  ? 'Общие ячейки и Магия договора'
                                  : 'Shared slots and Pact Magic'),
                              onPressed: () async {
                                final changed = await showMagicAllocationSheet(
                                    context, _draft, apply: (allocation) async {
                                  allocation.applyTo(_draft);
                                  for (var i = 1; i <= 9; i++) {
                                    _numbers['slot-$i']?.text =
                                        '${i <= _draft.spellSlots.length ? _draft.spellSlots[i - 1] : 0}';
                                  }
                                });
                                if (mounted && changed) setState(() {});
                              })),
                      _group(
                          l10n.gameStateSpellSlots,
                          Icons.auto_awesome_outlined,
                          [
                            _grid([
                              for (int i = 1; i <= 9; i++)
                                _number(
                                    'slot-$i',
                                    l10n.levelSlot(i),
                                    i <= _draft.spellSlots.length
                                        ? _draft.spellSlots[i - 1]
                                        : 0,
                                    hint: l10n.sheetNormalMaximum(
                                        i <= _draft.maxSpellSlots.length
                                            ? _draft.maxSpellSlots[i - 1]
                                            : 0)),
                            ], maxColumns: 3),
                          ],
                          description: l10n.gameStateResourcesHint),
                    ]),
                    _editorPage('resources', l10n.resources,
                        _resourceGroups(l10n, locale)),
                    _editorPage('conditions', l10n.conditions,
                        _conditionGroups(l10n, locale)),
                  ])),
                  Container(
                    decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border(
                            top: BorderSide(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: .4)))),
                    child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const ValueKey('game-state-save'),
                                onPressed: _saving ? null : _save,
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 52),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(AppRadii.lgPlus))),
                                icon: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.check_rounded),
                                label: Text(l10n.save),
                              )),
                        )),
                  ),
                ])),
          )),
        ));
  }

  List<Widget> _resourceGroups(AppLocalizations l10n, String locale) => [
        for (int i = 0; i < _draft.features.length; i++)
          if (_draft.features[i].resourcePool != null &&
              !Character.isChannelDivinityResource(_draft.features[i]))
            _group(_draft.features[i].getName(locale), Icons.bolt_outlined, [
              _number('pool-$i', l10n.sheetRemainder,
                  _draft.features[i].resourcePool!.currentUses,
                  hint: l10n.gameStateNormalMaximum(
                      _draft.features[i].resourcePool!.maxUses)),
              _recoveryInput(
                  'pool-recovery-$i',
                  _draft.features[i].resourcePool!.recoveryType,
                  (type) =>
                      _draft.features[i].resourcePool!.recoveryType = type),
            ]),
        for (int level = 6; level <= 9; level++)
          if ((GameplayActionsService.arcanumFeature(_draft, level) != null ||
                  _draft.classLevel('warlock') >= (level - 1) * 2 + 1) &&
              GameplayActionsService.arcanumFeature(_draft, level)
                      ?.resourcePool ==
                  null)
            _group('${l10n.sheetArcanum} · ${l10n.levelSlot(level)}',
                Icons.auto_awesome_outlined, [
              _number('arcanum-$level', l10n.sheetRemainder, 0,
                  hint: l10n.gameStateNormalMaximum(1)),
            ]),
        if (_draft.getMaxChannelDivinityCharges() > 0 ||
            _draft.channelDivinityCharges > 0)
          _group(l10n.channelDivinity, Icons.light_mode_outlined, [
            _number('channel-divinity', l10n.sheetRemainder,
                _draft.editableChannelDivinityCharges,
                hint: l10n.gameStateNormalMaximum(
                    _draft.getMaxChannelDivinityCharges())),
            if (_draft.channelDivinityResource != null)
              _recoveryInput('channel-divinity-recovery',
                  _draft.channelDivinityResource!.resourcePool!.recoveryType,
                  (type) {
                for (final feature in _draft.channelDivinityResources) {
                  feature.resourcePool!.recoveryType = type;
                }
              }),
          ]),
        if (_draft.classLevel('druid') >= 2 || _draft.isWildShaped)
          _group(l10n.wildShape, Icons.pets_outlined, [
            _number('wild-shape-uses', l10n.gameStateWildShapeUses,
                _draft.wildShapeCharges,
                hint: l10n.gameStateNormalMaximum(2)),
          ]),
        if (_draft.hitDice.isNotEmpty)
          _group(l10n.gameStateHitDice, Icons.casino_outlined, [
            _grid([
              for (int i = 0; i < _draft.hitDice.length; i++)
                _number(
                    'hit-die-$i',
                    _draft.hitDice.length == 1
                        ? l10n.sheetRemainder
                        : '${l10n.sheetRemainder} ${i + 1}',
                    _draft.hitDice[i]),
            ]),
          ]),
        _group(l10n.sheetEditorResourceMarks, Icons.checklist_rounded,
            _resourceMarks(l10n, locale)),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton.icon(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        FeatureService.repairBuiltInResourceRecovery(_draft);
                      }),
              icon: const Icon(Icons.settings_backup_restore, size: 20),
              label: Text(l10n.gameStateUseBuiltInRecovery),
            )),
      ];

  List<Widget> _resourceMarks(AppLocalizations l10n, String locale) {
    final visible = <Widget>[], other = <Widget>[];
    void mark(bool relevant, String id, String name, bool value,
        ValueChanged<bool> change) {
      (relevant || _initialUsedMarks.contains(id) ? visible : other)
          .add(_mark(id, l10n.gameStateResourceUsed(name), value, change));
    }

    mark(
        _draft.classLevel('wizard') > 0 ||
            _draft.hasFeatureId('arcane-recovery'),
        'arcane-used',
        l10n.arcaneRecovery,
        _draft.arcaneRecoveryUsed,
        (value) => _draft.arcaneRecoveryUsed = value);
    mark(
        _draft.hasFeatureId('natural-recovery'),
        'natural-used',
        l10n.naturalRecovery,
        _draft.naturalRecoveryUsed,
        (value) => _draft.naturalRecoveryUsed = value);
    mark(
        _draft.classLevel('cleric') >= 10 ||
            _draft.hasFeatureId('divine-intervention'),
        'intervention-used',
        l10n.divineIntervention,
        _draft.divineInterventionUsed,
        (value) => _draft.divineInterventionUsed = value);
    for (final id in _draft.signatureSpells) {
      visible.add(_mark(
          'signature-$id',
          l10n.gameStateResourceUsed(
              SpellService.getSpellById(id)?.getName(locale) ?? id),
          _draft.signatureSpellsUsed[id] ?? false,
          (value) => _draft.signatureSpellsUsed[id] = value));
    }
    if (other.isNotEmpty) {
      visible.add(ExpansionTile(
        key: const PageStorageKey('editor-other-resource-marks'),
        tilePadding: EdgeInsets.zero,
        title: Text(l10n.sheetEditorOtherMarks),
        shape: const Border(),
        collapsedShape: const Border(),
        children: other,
      ));
    }
    return visible;
  }

  List<Widget> _conditionGroups(AppLocalizations l10n, String locale) => [
        _group(
            l10n.conditions,
            Icons.spa_outlined,
            [
              FlipWrap(spacing: 8, runSpacing: 8, children: [
                for (final condition in ConditionType.values)
                  ExpressiveStateChip(
                    key: ValueKey('game-state-condition-${condition.name}'),
                    label: ConditionPresentation.label(l10n, condition),
                    selected: _draft.activeConditions.contains(condition),
                    selectedColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    leading: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: Icon(ConditionPresentation.icon(condition),
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    onTap: _saving
                        ? null
                        : () => setState(() {
                              if (!_draft.activeConditions
                                  .remove(condition)) {
                                _draft.activeConditions.add(condition);
                              }
                            }),
                  ),
              ]),
            ],
            description: l10n.gameStateEffectsHint),
        _group(l10n.gameStateExhaustion, Icons.battery_alert_outlined, [
          _number(
              'exhaustion', l10n.gameStateCurrentValue, _draft.exhaustionLevel,
              limit: 6),
        ]),
        _group(l10n.deathSaves, Icons.favorite_outline, [
          _grid([
            _number('death-success', l10n.sheetDeathSuccesses,
                _draft.deathSaves.successes,
                limit: 3),
            _number('death-failure', l10n.sheetDeathFailures,
                _draft.deathSaves.failures,
                limit: 3),
          ])
        ]),
        _group(l10n.sheetEditorActiveEffects, Icons.auto_awesome_outlined, [
          _mark('rage', l10n.gameStateRaging, _draft.isRaging,
              (value) => _draft.isRaging = value),
          _mark('frenzy', l10n.gameStateFrenzied, _draft.isFrenzied,
              (value) => _draft.isFrenzied = value),
          _mark('reckless', l10n.gameStateReckless, _draft.isReckless,
              (value) => _draft.isReckless = value),
          if (_draft.hasRelentlessRage)
            _number('relentless-dc', l10n.gameStateRelentlessDc,
                _draft.relentlessRageSaveDc),
          _mark('hidden', l10n.gameStateHidden, _draft.isHidden,
              (value) => _draft.isHidden = value),
          _mark(
              'sacred',
              l10n.gameStateSacredWeapon,
              _draft.isSacredWeaponActive,
              (value) => _draft.isSacredWeaponActive = value),
          _mark('shape', l10n.gameStateWildShape, _draft.isWildShaped,
              (value) => _draft.isWildShaped = value),
          if (_draft.beastCurrentHp != null)
            _number('beast-hp', l10n.gameStateBeastCurrentHp,
                _draft.beastCurrentHp!),
          if (_draft.beastMaxHp != null)
            _number('beast-max-hp', l10n.gameStateBeastMaximumHp,
                _draft.beastMaxHp!),
          _mark(
              'hunter-mark',
              l10n.gameStateHuntersMark,
              _draft.isHuntersMarkActive,
              (value) => _draft.isHuntersMarkActive = value),
          _mark(
              'hidden-plain',
              l10n.gameStateHiddenPlain,
              _draft.isHiddenInPlainSight,
              (value) => _draft.isHiddenInPlainSight = value),
          DropdownButtonFormField<String>(
            borderRadius: AppMenuStyle.radius,
            dropdownColor: AppMenuStyle.background(context),
            elevation: 4,
            initialValue: _draft.concentratingOn ?? '',
            isExpanded: true,
            decoration: _inputDecoration(label: l10n.concentration),
            items: [
              DropdownMenuItem(
                  value: '', child: Text(l10n.gameStateNoConcentration)),
              for (final id in {
                if (_draft.concentratingOn != null) _draft.concentratingOn!,
                ...SpellService.getAllSpells().map((s) => s.id)
              })
                DropdownMenuItem(
                    value: id,
                    child: Text(
                        SpellService.getSpellById(id)?.getName(locale) ?? id,
                        overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    _draft.concentratingOn =
                        value == null || value.isEmpty ? null : value;
                  },
          ),
        ]),
      ];

  Widget _recoveryInput(
          String id, RecoveryType value, ValueChanged<RecoveryType> change) =>
      DropdownButtonFormField<RecoveryType>(
        borderRadius: AppMenuStyle.radius,
        dropdownColor: AppMenuStyle.background(context),
        elevation: 4,
        key: ValueKey('$id-${value.name}'),
        initialValue: value,
        isExpanded: true,
        decoration: _inputDecoration(
            label: AppLocalizations.of(context)!.gameStateRecovery),
        items: [
          for (final type in RecoveryType.values)
            DropdownMenuItem(
                value: type,
                child:
                    Text(_recoveryName(AppLocalizations.of(context)!, type))),
        ],
        onChanged: _saving
            ? null
            : (type) {
                if (type != null) change(type);
              },
      );

  Widget _editorPage(String id, String title, List<Widget> children) =>
      Semantics(
        label: title,
        container: true,
        child: ListView(
          key: PageStorageKey('editor-$id'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            for (final child in children) ...[
              child,
              const SizedBox(height: 16)
            ],
          ],
        ),
      );

  Widget _group(String title, IconData icon, List<Widget> children,
      {String? description}) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppRadii.md)),
                child: Icon(icon,
                    size: 20, color: theme.colorScheme.onSecondaryContainer)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700))),
          ]),
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(description,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          ],
          const SizedBox(height: 12),
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ],
        ]),
      ),
    );
  }

  Widget _grid(List<Widget> fields, {int maxColumns = 2}) =>
      LayoutBuilder(builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
        final columns = largeText
            ? 1
            : (constraints.maxWidth / 150).floor().clamp(
                1, fields.length < maxColumns ? fields.length : maxColumns);
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 16,
          children: [
            for (final field in fields) SizedBox(width: width, child: field)
          ],
        );
      });

  String _recoveryName(AppLocalizations l, RecoveryType type) => switch (type) {
        RecoveryType.shortRest => l.shortRest,
        RecoveryType.longRest => l.longRest,
        RecoveryType.dawn => l.recoveryDawn,
        RecoveryType.perTurn => l.recoveryEachTurn,
        RecoveryType.recharge => l.recoveryRecharge,
        RecoveryType.manual => l.recoveryManual,
      };
}
