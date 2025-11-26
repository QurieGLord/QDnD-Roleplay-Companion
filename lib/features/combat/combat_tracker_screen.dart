import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';
import 'dart:async';
import '../../core/models/character.dart';
import '../../core/models/condition.dart';
import '../../core/services/storage_service.dart';
import 'widgets/combat_log_view.dart';

class CombatTrackerScreen extends StatefulWidget {
  final Character character;

  const CombatTrackerScreen({
    super.key,
    required this.character,
  });

  @override
  State<CombatTrackerScreen> createState() => _CombatTrackerScreenState();
}

class _CombatTrackerScreenState extends State<CombatTrackerScreen> with TickerProviderStateMixin {
  late Character _character;
  
  // Animations
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _character = widget.character;
    
    _shakeController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _shakeAnimation = Tween<double>(begin: 0, end: 10).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);
    
    _pulseController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  Future<void> _save() async {
    await StorageService.saveCharacter(_character);
    setState(() {});
  }

  void _startCombat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Roll Initiative'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_martial_arts, size: 48),
            const SizedBox(height: 16),
            Text('Bonus: ${_character.formatModifier(_character.initiativeBonus)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final d20 = Random().nextInt(20) + 1;
              final init = d20 + _character.initiativeBonus;
              Navigator.pop(context);
              _character.combatState.startCombat(init);
              await _save();
            },
            child: const Text('ROLL'),
          ),
        ],
      ),
    );
  }

  void _endCombat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Combat?'),
        content: const Text('This will reset the round counter.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              _character.combatState.endCombat();
              await _save();
            },
            child: const Text('End'),
          ),
        ],
      ),
    );
  }

  void _modifyHP(bool heal) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(heal ? 'Heal' : 'Take Damage', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: heal ? Colors.green : Colors.red, fontWeight: FontWeight.bold
            )),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: heal ? const Icon(Icons.add) : const Icon(Icons.remove),
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
                          await _character.takeDamage(amount); // Handle temp HP internally
                          _triggerShake();
                          _save();
                        }
                      },
                      child: const Text('Temp HP'), // Actually this logic is complex, let's keep it simple: Just damage/heal
                    ),
                  ),
                if (!heal) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: heal ? Colors.green : Colors.red, minimumSize: const Size(0, 56)),
                    onPressed: () async {
                      final amount = int.tryParse(controller.text) ?? 0;
                      if (amount > 0) {
                        Navigator.pop(context);
                        if (heal) {
                          await _character.heal(amount);
                        } else {
                          await _character.takeDamage(amount);
                          _triggerShake();
                        }
                        _save();
                      }
                    },
                    child: Text(heal ? 'HEAL' : 'DAMAGE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleCondition(ConditionType condition) {
    if (_character.activeConditions.contains(condition)) {
      _character.removeCondition(condition);
    } else {
      _character.addCondition(condition);
    }
    _save();
  }

  void _showConditionsDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: ConditionType.values.map((c) {
          final isActive = _character.activeConditions.contains(c);
          return ListTile(
            title: Text(c.displayName),
            trailing: isActive ? const Icon(Icons.check_circle, color: Colors.green) : null,
            onTap: () {
              _toggleCondition(c);
              Navigator.pop(context);
            },
          );
        }).toList(),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isInCombat = character.combatState.isInCombat;
    final hpPercent = character.currentHp / character.maxHp;
    final isDying = character.currentHp <= 0;

    return Scaffold(
      backgroundColor: isInCombat ? colorScheme.surfaceContainerLow : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(character.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => showModalBottomSheet(
              context: context, 
              builder: (_) => CombatLogView(combatLog: character.combatState.combatLog)
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(sin(_shakeController.value * pi * 10) * _shakeAnimation.value, 0),
            child: child,
          );
        },
        child: Column(
          children: [
            // --- HEADER: ROUND & INIT ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHeaderStat('INITIATIVE', '${character.combatState.initiative}', Icons.flash_on, colorScheme.tertiary),
                  if (isInCombat)
                    _buildHeaderStat('ROUND', '${character.combatState.currentRound}', Icons.refresh, colorScheme.primary),
                ],
              ),
            ),

            const Spacer(),

            // --- MAIN VISUAL: HP RING ---
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background Circle
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: (isDying ? colorScheme.error : colorScheme.primary).withOpacity(0.15),
                          blurRadius: 40,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                  ),
                  // Progress Indicator
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CircularProgressIndicator(
                      value: hpPercent,
                      strokeWidth: 16,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      color: isDying ? colorScheme.error : (hpPercent > 0.5 ? Colors.green : Colors.amber),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  // Text Content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDying) ...[
                        const Icon(Icons.dangerous, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('UNCONSCIOUS', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.error, letterSpacing: 1.5)),
                      ] else ...[
                        Icon(Icons.favorite, size: 32, color: colorScheme.error.withOpacity(0.8)),
                        const SizedBox(height: 4),
                        Text(
                          '${character.currentHp}',
                          style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: colorScheme.onSurface, height: 1),
                        ),
                        Text(
                          '/${character.maxHp}',
                          style: TextStyle(fontSize: 24, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                        ),
                        if (character.temporaryHp > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                            child: Text('+${character.temporaryHp} TEMP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSecondaryContainer)),
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // --- DEATH SAVES (IF DYING) ---
            if (isDying)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.error.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Text('DEATH SAVES', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.error, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDeathSaveRow('Successes', character.deathSaves.successes, Icons.check_circle, Colors.green, () async {
                          character.deathSaves.addSuccess(); await _save();
                        }),
                        Container(width: 1, height: 40, color: colorScheme.outlineVariant),
                        _buildDeathSaveRow('Failures', character.deathSaves.failures, Icons.cancel, colorScheme.error, () async {
                          character.deathSaves.addFailure(); await _save();
                        }),
                      ],
                    ),
                  ],
                ),
              ),

            // --- CONDITIONS ROW ---
            if (character.activeConditions.isNotEmpty)
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: character.activeConditions.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(c.displayName),
                      backgroundColor: colorScheme.errorContainer,
                      labelStyle: TextStyle(color: colorScheme.onErrorContainer),
                      onDeleted: () => _toggleCondition(c),
                    ),
                  )).toList(),
                ),
              ),

            const SizedBox(height: 24),

            // --- CONTROLS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  // Damage / Heal Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          context, 
                          'DAMAGE', 
                          Icons.broken_image, 
                          colorScheme.error, 
                          () => _modifyHP(false)
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          context, 
                          'HEAL', 
                          Icons.healing, 
                          Colors.green, 
                          () => _modifyHP(true)
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Condition / Round
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showConditionsDialog,
                          icon: const Icon(Icons.sick_outlined),
                          label: const Text('Condition'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: isInCombat
                          ? FilledButton.tonalIcon(
                              onPressed: () {
                                setState(() { character.combatState.currentRound++; _save(); });
                              },
                              icon: const Icon(Icons.skip_next),
                              label: const Text('Next Round'),
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                            )
                          : FilledButton.icon(
                              onPressed: _startCombat,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start Combat'),
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
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
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.15),
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
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeathSaveRow(String label, int count, IconData icon, Color color, VoidCallback onAdd) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          children: List.generate(3, (i) => IconButton(
            onPressed: onAdd,
            icon: Icon(
              i < count ? icon : Icons.check_box_outline_blank,
              color: i < count ? color : Colors.grey,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          )),
        ),
      ],
    );
  }
}