import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';
import 'dart:async';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/character.dart';
import '../../core/models/combat_state.dart';
import '../../core/models/condition.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/spellcasting_service.dart';
import 'widgets/combat_log_view.dart';
import 'widgets/combat_spellcaster_sheet.dart';

class CombatTrackerScreen extends StatefulWidget {
  final Character character;

  const CombatTrackerScreen({
    super.key,
    required this.character,
  });

  @override
  State<CombatTrackerScreen> createState() => _CombatTrackerScreenState();
}

class _CombatTrackerScreenState extends State<CombatTrackerScreen>
    with TickerProviderStateMixin {
  late Character _character;

  // Animations
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _pulseController;

  Timer? _deathSaveRollTimer;
  bool _isDeathSaveRolling = false;
  int? _deathSavePreviewRoll;
  int? _lastDeathSaveRoll;
  bool? _lastDeathSaveWasSuccess;
  String? _lastDeathSaveMessage;

  @override
  void initState() {
    super.initState();
    _character = widget.character;

    _shakeController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _pulseController =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)
          ..repeat(reverse: true);
    // pulse animation drives the controller; value accessed via _pulseController
  }

  @override
  void dispose() {
    _deathSaveRollTimer?.cancel();
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  Future<void> _save([Character? character]) async {
    _character = character ?? _character;
    await StorageService.saveCharacter(_character);
    if (mounted) {
      setState(() {});
    }
  }

  void _resetDeathSaveRollState() {
    _deathSaveRollTimer?.cancel();
    _deathSaveRollTimer = null;
    _isDeathSaveRolling = false;
    _deathSavePreviewRoll = null;
  }

  Future<int> _animateDeathSaveRoll() async {
    final completer = Completer<int>();
    final random = Random();
    int ticks = 0;

    _deathSaveRollTimer?.cancel();
    setState(() {
      _isDeathSaveRolling = true;
      _deathSavePreviewRoll = random.nextInt(20) + 1;
      _lastDeathSaveRoll = null;
      _lastDeathSaveWasSuccess = null;
      _lastDeathSaveMessage = null;
    });

    _deathSaveRollTimer = Timer.periodic(const Duration(milliseconds: 80), (
      timer,
    ) {
      ticks++;

      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _deathSavePreviewRoll = random.nextInt(20) + 1;
      });

      if (ticks >= 12) {
        timer.cancel();
        _deathSaveRollTimer = null;
        completer.complete(random.nextInt(20) + 1);
      }
    });

    return completer.future;
  }

  Future<void> _maybeHandleRelentlessRage(
    Character character,
    AppLocalizations l10n,
  ) async {
    if (character.currentHp > 0 ||
        !character.hasRelentlessRage ||
        !character.isRaging) {
      return;
    }

    final locale = Localizations.localeOf(context).languageCode;
    final feature = character.features.firstWhere(
      (candidate) => candidate.id.toLowerCase() == 'relentless-rage',
    );
    final dc = character.relentlessRageSaveDc;
    final conSaveBonus = character.constitutionSavingThrowBonus;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(feature.getName(locale)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DC $dc'),
            const SizedBox(height: 8),
            Text(
              '${l10n.modifier}: ${character.formatModifier(conSaveBonus)}',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              final roll = Random().nextInt(20) + 1;
              final total = roll + conSaveBonus;
              final succeeded = total >= dc;

              if (succeeded) {
                character.currentHp = 1;
              } else {
                character.isRaging = false;
              }

              character.increaseRelentlessRageSaveDc();
              Navigator.pop(context);

              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    succeeded
                        ? '${feature.getName(locale)}: $roll + $conSaveBonus = $total, 1 HP'
                        : '${feature.getName(locale)}: $roll + $conSaveBonus = $total, 0 HP',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(l10n.roll),
          ),
        ],
      ),
    );

    await _save(character);
  }

  String _getConditionName(AppLocalizations l10n, ConditionType type) {
    switch (type) {
      case ConditionType.blinded:
        return l10n.conditionBlinded;
      case ConditionType.charmed:
        return l10n.conditionCharmed;
      case ConditionType.deafened:
        return l10n.conditionDeafened;
      case ConditionType.frightened:
        return l10n.conditionFrightened;
      case ConditionType.grappled:
        return l10n.conditionGrappled;
      case ConditionType.incapacitated:
        return l10n.conditionIncapacitated;
      case ConditionType.invisible:
        return l10n.conditionInvisible;
      case ConditionType.paralyzed:
        return l10n.conditionParalyzed;
      case ConditionType.petrified:
        return l10n.conditionPetrified;
      case ConditionType.poisoned:
        return l10n.conditionPoisoned;
      case ConditionType.prone:
        return l10n.conditionProne;
      case ConditionType.restrained:
        return l10n.conditionRestrained;
      case ConditionType.stunned:
        return l10n.conditionStunned;
      case ConditionType.unconscious:
        return l10n.conditionUnconscious;
    }
  }

  void _startCombat(Character character, AppLocalizations l10n) {
    final locale = Localizations.localeOf(context).languageCode;
    final feralInstinct = character.hasFeralInstinct
        ? character.features
            .where((feature) => feature.id.toLowerCase() == 'feral-instinct')
            .firstOrNull
        : null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.rollInitiative),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_martial_arts, size: 48),
            const SizedBox(height: 16),
            Text(
              '${l10n.modifier}: ${character.formatModifier(character.initiativeBonus)}',
            ),
            if (feralInstinct != null) ...[
              const SizedBox(height: 8),
              Text('${l10n.advantage}: ${feralInstinct.getName(locale)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () async {
              final d20 = Random().nextInt(20) + 1;
              final initiativeRoll = character.hasFeralInstinct
                  ? [d20, Random().nextInt(20) + 1].reduce(max)
                  : d20;
              final init = initiativeRoll + character.initiativeBonus;
              Navigator.pop(context);
              character.combatState.startCombat(init);
              await _save(character);
            },
            child: Text(l10n.roll),
          ),
        ],
      ),
    );
  }

  void _endCombat(Character character, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.endCombat),
        content: Text(l10n.endCombatConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              character.combatState.endCombat();
              _resetDeathSaveRollState();
              await _save(character);
            },
            child: Text(l10n.finish),
          ),
        ],
      ),
    );
  }

  void _modifyHP(Character character, bool heal, AppLocalizations l10n) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(heal ? l10n.heal : l10n.takeDamage,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: heal ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '0',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon:
                    heal ? const Icon(Icons.add) : const Icon(Icons.remove),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (!heal)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final amount = int.tryParse(controller.text) ?? 0;
                        if (amount > 0) {
                          Navigator.pop(context);
                          await character
                              .takeDamage(amount); // Handle temp HP internally
                          await _maybeHandleRelentlessRage(character, l10n);
                          _triggerShake();
                          await _save(character);
                        }
                      },
                      child: Text(l10n.tempHp),
                    ),
                  ),
                if (!heal) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: heal ? Colors.green : Colors.red,
                        minimumSize: const Size(0, 56)),
                    onPressed: () async {
                      final amount = int.tryParse(controller.text) ?? 0;
                      if (amount > 0) {
                        Navigator.pop(context);
                        if (heal) {
                          await character.heal(amount);
                          _resetDeathSaveRollState();
                        } else {
                          await character.takeDamage(amount);
                          await _maybeHandleRelentlessRage(character, l10n);
                          _triggerShake();
                        }
                        await _save(character);
                      }
                    },
                    child: Text(heal
                        ? l10n.heal.toUpperCase()
                        : l10n.takeDamage.toUpperCase()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleCondition(Character character, ConditionType condition) {
    if (character.activeConditions.contains(condition)) {
      character.removeCondition(condition);
    } else {
      character.addCondition(condition);
    }
    _save(character);
  }

  void _showConditionsDialog(Character character, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: ConditionType.values.map((c) {
          final isActive = character.activeConditions.contains(c);
          return ListTile(
            title: Text(_getConditionName(l10n, c)),
            trailing: isActive
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
            onTap: () {
              _toggleCondition(character, c);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  Future<void> _rollDeathSave(
    Character character,
    AppLocalizations l10n,
  ) async {
    if (character.currentHp > 0 ||
        character.deathSaves.isDead ||
        character.deathSaves.isStabilized) {
      return;
    }

    if (!character.combatState.canRollDeathSaveThisRound) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deathSaveAlreadyRolled),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final roll = await _animateDeathSaveRoll();
    final round = character.combatState.currentRound;
    String message;
    bool wasSuccess;

    if (character.combatState.isInCombat) {
      character.combatState.markDeathSaveRolledThisRound();
    }

    if (roll == 20) {
      wasSuccess = true;
      message = l10n.deathSaveNat20;
      character.combatState.addLogEntry(
        CombatLogEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          type: CombatLogType.deathSave,
          amount: roll,
          description: message,
          round: round,
        ),
      );
      await character.heal(1, source: 'Death save (nat 20)');
    } else if (roll == 1) {
      wasSuccess = false;
      message = l10n.deathSaveNat1;
      character.deathSaves.addFailure();
      character.deathSaves.addFailure();
      if (character.combatState.isInCombat) {
        character.combatState.addLogEntry(
          CombatLogEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            timestamp: DateTime.now(),
            type: CombatLogType.deathSave,
            amount: roll,
            description: message,
            round: round,
          ),
        );
      }
      await _save(character);
    } else if (roll >= 10) {
      wasSuccess = true;
      message = l10n.deathSaveSuccessResult(roll);
      character.deathSaves.addSuccess();
      if (character.combatState.isInCombat) {
        character.combatState.addLogEntry(
          CombatLogEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            timestamp: DateTime.now(),
            type: CombatLogType.deathSave,
            amount: roll,
            description: message,
            round: round,
          ),
        );
      }
      await _save(character);
    } else {
      wasSuccess = false;
      message = l10n.deathSaveFailureResult(roll);
      character.deathSaves.addFailure();
      if (character.combatState.isInCombat) {
        character.combatState.addLogEntry(
          CombatLogEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            timestamp: DateTime.now(),
            type: CombatLogType.deathSave,
            amount: roll,
            description: message,
            round: round,
          ),
        );
      }
      await _save(character);
    }

    if (!mounted) return;

    setState(() {
      _isDeathSaveRolling = false;
      _deathSavePreviewRoll = roll;
      _lastDeathSaveRoll = roll;
      _lastDeathSaveWasSuccess = wasSuccess;
      _lastDeathSaveMessage = message;
    });

    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: wasSuccess ? Colors.green : colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Character>('characters').listenable(),
      builder: (context, Box<Character> box, _) {
        final character = box.get(widget.character.key) ?? widget.character;
        return _buildUI(context, character);
      },
    );
  }

  Widget _buildUI(BuildContext context, Character character) {
    _character = character;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isInCombat = character.combatState.isInCombat;
    final hpPercent = (character.currentHp / character.maxHp).clamp(0.0, 1.0);
    final isDying = character.currentHp <= 0;
    final showActiveDeathSaves = isDying && character.deathSaves.isActive;
    final showDeathSaveStatus = isDying && !character.deathSaves.isActive;
    final isSpellcaster =
        SpellcastingService.isSpellcaster(character.characterClass);

    return Scaffold(
      backgroundColor: isInCombat
          ? colorScheme.surfaceContainerLow
          : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(character.name),
        centerTitle: true,
        actions: [
          if (isInCombat)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              color: colorScheme.error,
              tooltip: l10n.endCombat,
              onPressed: () => _endCombat(character, l10n),
            ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) =>
                    CombatLogView(combatLog: character.combatState.combatLog)),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
                sin(_shakeController.value * pi * 10) * _shakeAnimation.value,
                0),
            child: child,
          );
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ScrollConfiguration(
              behavior: const _CombatTrackerScrollBehavior(),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // --- HEADER: ROUND & INIT ---
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildHeaderStat(
                                  l10n.initiativeINIT,
                                  '${character.combatState.initiative}',
                                  Icons.flash_on,
                                  colorScheme.tertiary),
                              if (isInCombat)
                                _buildHeaderStat(
                                    'ROUND',
                                    '${character.combatState.currentRound}',
                                    Icons.refresh,
                                    colorScheme.primary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- MAIN VISUAL: HP RING (Smaller) ---
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.surface,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isDying
                                              ? colorScheme.error
                                              : colorScheme.primary)
                                          .withValues(alpha: 0.15),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    )
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 180,
                                height: 180,
                                child: CircularProgressIndicator(
                                  value: hpPercent,
                                  strokeWidth: 12,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                  color: isDying
                                      ? colorScheme.error
                                      : (hpPercent > 0.5
                                          ? Colors.green
                                          : Colors.amber),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isDying) ...[
                                    const Icon(
                                      Icons.dangerous,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.conditionUnconscious.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.error,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ] else ...[
                                    Icon(
                                      Icons.favorite,
                                      size: 24,
                                      color: colorScheme.error.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                    Text(
                                      '${character.currentHp}',
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                        color: colorScheme.onSurface,
                                        height: 1,
                                      ),
                                    ),
                                    Text(
                                      '/${character.maxHp}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- STATS DASHBOARD (Indicators) ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              if (character.temporaryHp > 0)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: colorScheme.secondary,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.shield,
                                        size: 16,
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${character.temporaryHp} ${l10n.tempHp}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              colorScheme.onSecondaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (character.activeConditions.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: character.activeConditions
                                      .map((c) => Chip(
                                            label: Text(
                                              _getConditionName(l10n, c),
                                            ),
                                            backgroundColor:
                                                colorScheme.errorContainer,
                                            labelStyle: TextStyle(
                                              color:
                                                  colorScheme.onErrorContainer,
                                              fontSize: 12,
                                            ),
                                            padding: EdgeInsets.zero,
                                            visualDensity:
                                                VisualDensity.compact,
                                            onDeleted: () =>
                                                _toggleCondition(character, c),
                                          ))
                                      .toList(),
                                ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeInOutCubicEmphasized,
                                alignment: Alignment.topCenter,
                                child: showActiveDeathSaves
                                    ? _buildActiveDeathSavesCard(
                                        character,
                                        theme,
                                        l10n,
                                        colorScheme,
                                        isInCombat,
                                      )
                                    : showDeathSaveStatus
                                        ? _buildDeathSaveStatusCard(
                                            character,
                                            theme,
                                            l10n,
                                            colorScheme,
                                          )
                                        : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isSpellcaster)
                          _buildMagicButton(
                            context,
                            character,
                            l10n,
                            colorScheme,
                          ),
                        const Spacer(),

                        // --- CONTROLS ---
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 24,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                        context,
                                        l10n.takeDamage.toUpperCase(),
                                        Icons.broken_image,
                                        colorScheme.error,
                                        () =>
                                            _modifyHP(character, false, l10n)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildActionButton(
                                        context,
                                        l10n.heal.toUpperCase(),
                                        Icons.healing,
                                        Colors.green,
                                        () => _modifyHP(character, true, l10n)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showConditionsDialog(
                                        character,
                                        l10n,
                                      ),
                                      icon: const Icon(Icons.sick_outlined),
                                      label: Text(l10n.condition),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 56),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: isInCombat
                                        ? FilledButton.tonalIcon(
                                            onPressed: () {
                                              setState(() {
                                                character
                                                    .combatState.currentRound++;
                                                _save(character);
                                              });
                                            },
                                            icon: const Icon(Icons.skip_next),
                                            label: Text(l10n.nextRound),
                                            style: FilledButton.styleFrom(
                                              minimumSize: const Size(0, 56),
                                            ),
                                          )
                                        : FilledButton.icon(
                                            onPressed: () =>
                                                _startCombat(character, l10n),
                                            icon: const Icon(Icons.play_arrow),
                                            label: Text(l10n.startCombat),
                                            style: FilledButton.styleFrom(
                                              minimumSize: const Size(0, 56),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveDeathSavesCard(
    Character character,
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    bool isInCombat,
  ) {
    final deathSaveRollPanel = _buildDeathSaveRollPanel(
      theme,
      l10n,
      colorScheme,
    );

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.deathSaves.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (isInCombat &&
                  !character.combatState.canRollDeathSaveThisRound)
                _buildStatusPill(
                  theme,
                  l10n.deathSaveRolledThisRound,
                  colorScheme.secondaryContainer,
                  colorScheme.onSecondaryContainer,
                ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubicEmphasized,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  ),
                  child: deathSaveRollPanel ??
                      const SizedBox(
                        key: ValueKey('death-save-empty'),
                      ),
                ),
                if (deathSaveRollPanel != null) const SizedBox(height: 12),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDeathSaveRow(
                label: l10n.successes,
                count: character.deathSaves.successes,
                icon: Icons.check_circle,
                color: Colors.green,
                onToggle: (index, isFilled) async {
                  if (isFilled && character.deathSaves.successes > index) {
                    character.deathSaves.successes--;
                  } else if (!isFilled && character.deathSaves.successes < 3) {
                    character.deathSaves.addSuccess();
                  }
                  await _save(character);
                },
              ),
              Container(
                width: 1,
                height: 30,
                color: colorScheme.outlineVariant,
              ),
              _buildDeathSaveRow(
                label: l10n.failures,
                count: character.deathSaves.failures,
                icon: Icons.cancel,
                color: colorScheme.error,
                onToggle: (index, isFilled) async {
                  if (isFilled && character.deathSaves.failures > index) {
                    character.deathSaves.failures--;
                  } else if (!isFilled && character.deathSaves.failures < 3) {
                    character.deathSaves.addFailure();
                  }
                  await _save(character);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isDeathSaveRolling ||
                      !character.combatState.canRollDeathSaveThisRound
                  ? null
                  : () => _rollDeathSave(character, l10n),
              icon: Icon(
                _isDeathSaveRolling ? Icons.hourglass_top : Icons.casino,
              ),
              label: Text(
                _isDeathSaveRolling ? l10n.rolling : l10n.rollDeathSave,
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.deathSaveOnePerRound}. ${l10n.deathSaveManualAdjustHint}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeathSaveStatusCard(
    Character character,
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final isStabilized = character.deathSaves.isStabilized;
    final accent = isStabilized ? Colors.green : colorScheme.error;
    final label = isStabilized ? l10n.stabilized : l10n.deadLabel;
    final icon =
        isStabilized ? Icons.health_and_safety_outlined : Icons.dangerous;
    final hint =
        isStabilized ? l10n.deathSaveStabilizedHint : l10n.deathSaveDeadHint;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusPill(
                  theme,
                  label,
                  accent,
                  Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.resetDeathSaves,
            onPressed: () => _resetDeathSaves(character),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
    );
  }

  Widget _buildMagicButton(BuildContext context, Character character,
      AppLocalizations l10n, ColorScheme colorScheme) {
    // Count total remaining slots
    for (int i = 0; i < character.maxSpellSlots.length; i++) {
      if (i < character.spellSlots.length) {
        // spellSlots stores REMAINING
      }
    }
    // Correct logic: spellSlots stores remaining. So used = max - remaining.
    // Wait, spellSlots list stores REMAINING slots.
    // Example: Max [4, 2]. Current [3, 2].
    // Total Max = 6. Total Remaining = 5.

    int remaining = 0;
    for (int i = 0; i < character.spellSlots.length; i++) {
      remaining += character.spellSlots[i];
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => CombatSpellcasterSheet(
              character: character,
              onStateChange: () => _save(character),
            ),
          );
        },
        icon: const Icon(Icons.auto_fix_high),
        label: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.castSpell.toUpperCase(),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.onPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.slotsRemaining(remaining),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetDeathSaves(Character character) async {
    _deathSaveRollTimer?.cancel();
    setState(() {
      character.deathSaves.reset();
      character.combatState.resetDeathSaveTracking();
      _resetDeathSaveRollState();
      _lastDeathSaveRoll = null;
      _lastDeathSaveWasSuccess = null;
      _lastDeathSaveMessage = null;
    });
    await _save(character);
  }

  Widget _buildStatusPill(
    ThemeData theme,
    String label,
    Color backgroundColor,
    Color foregroundColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget? _buildDeathSaveRollPanel(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    if (_isDeathSaveRolling) {
      return Container(
        key: const ValueKey('death-save-rolling'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(Icons.casino, color: colorScheme.error),
            const SizedBox(height: 8),
            Text(
              l10n.rolling,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              (_deathSavePreviewRoll ?? 0).toString(),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: colorScheme.error,
              ),
            ),
          ],
        ),
      );
    }

    if (_lastDeathSaveRoll == null || _lastDeathSaveMessage == null) {
      return null;
    }

    final isSuccess = _lastDeathSaveWasSuccess ?? false;
    final accent = isSuccess ? Colors.green : colorScheme.error;

    return Container(
      key: ValueKey(
          'death-save-result-$_lastDeathSaveRoll-$_lastDeathSaveMessage'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _lastDeathSaveRoll.toString(),
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _lastDeathSaveMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        Text(value,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon,
      Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 80,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeathSaveRow({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required Future<void> Function(int index, bool isFilled) onToggle,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          children: List.generate(3, (i) {
            final isFilled = i < count;
            return IconButton(
              onPressed: () => onToggle(i, isFilled),
              icon: Icon(
                isFilled ? icon : Icons.check_box_outline_blank,
                color: isFilled ? color : Colors.grey,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            );
          }),
        ),
      ],
    );
  }
}

class _CombatTrackerScrollBehavior extends MaterialScrollBehavior {
  const _CombatTrackerScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
