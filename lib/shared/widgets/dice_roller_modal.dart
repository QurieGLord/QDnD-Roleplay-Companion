import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback

enum DiceType {
  d4(4, '▲'),
  d6(6, '■'),
  d8(8, '◆'),
  d10(10, '⬖'),
  d12(12, '⬟'),
  d20(20, '⬢'),
  d100(100, '%');

  final int sides;
  final String icon;
  const DiceType(this.sides, this.icon);
}

enum AdvantageType {
  none('Normal', Icons.remove),
  advantage('Advantage', Icons.keyboard_double_arrow_up),
  disadvantage('Disadvantage', Icons.keyboard_double_arrow_down);

  final String label;
  final IconData icon;
  const AdvantageType(this.label, this.icon);
}

class DiceRoll {
  final int result;
  final int total;
  final DiceType type;
  final int modifier;
  final List<int> rawRolls;
  final AdvantageType advantage;
  final DateTime timestamp;

  DiceRoll({
    required this.result,
    required this.total,
    required this.type,
    required this.modifier,
    required this.rawRolls,
    required this.advantage,
    required this.timestamp,
  });
}

void showDiceRoller(
  BuildContext context, {
  String? title,
  int modifier = 0,
  DiceType initialDice = DiceType.d20,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DiceRollerModal(
      title: title ?? 'Dice Roller',
      initialModifier: modifier,
      initialDice: initialDice,
    ),
  );
}

class DiceRollerModal extends StatefulWidget {
  final String title;
  final int initialModifier;
  final DiceType initialDice;

  const DiceRollerModal({
    super.key,
    required this.title,
    this.initialModifier = 0,
    this.initialDice = DiceType.d20,
  });

  @override
  State<DiceRollerModal> createState() => _DiceRollerModalState();
}

class _DiceRollerModalState extends State<DiceRollerModal> with TickerProviderStateMixin {
  late DiceType _selectedDice;
  late int _modifier;
  AdvantageType _advantage = AdvantageType.none;
  final List<DiceRoll> _history = [];

  // Animation Controllers
  late AnimationController _shakeController;
  late AnimationController _scaleController;
  
  // State for rolling visual
  bool _isRolling = false;
  int _displayedNumber = 1;
  Timer? _rollTimer;

  @override
  void initState() {
    super.initState();
    _selectedDice = widget.initialDice;
    _modifier = widget.initialModifier;

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _scaleController.dispose();
    _rollTimer?.cancel();
    super.dispose();
  }

  void _rollDice() async {
    if (_isRolling) return;

    setState(() => _isRolling = true);
    HapticFeedback.selectionClick();

    // 1. Start Shaking and Cycling Numbers
    _shakeController.repeat(reverse: true);
    
    int cycles = 0;
    final random = Random();
    
    _rollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _displayedNumber = random.nextInt(_selectedDice.sides) + 1;
      });
      cycles++;
      // Add haptic feedback on ticks for tactile feel
      if (cycles % 2 == 0) HapticFeedback.lightImpact();
    });

    // 2. Wait for animation duration
    await Future.delayed(const Duration(milliseconds: 800));

    // 3. Stop animations and Calculate Result
    _rollTimer?.cancel();
    _shakeController.stop();
    _shakeController.value = 0;

    final rolls = <int>[];
    int resultVal = 0;

    if (_advantage == AdvantageType.none) {
      final r = random.nextInt(_selectedDice.sides) + 1;
      rolls.add(r);
      resultVal = r;
    } else {
      final r1 = random.nextInt(_selectedDice.sides) + 1;
      final r2 = random.nextInt(_selectedDice.sides) + 1;
      rolls.add(r1);
      rolls.add(r2);
      resultVal = _advantage == AdvantageType.advantage ? max(r1, r2) : min(r1, r2);
    }

    setState(() {
      _displayedNumber = resultVal;
      _isRolling = false;
      
      _history.insert(0, DiceRoll(
        result: resultVal,
        total: resultVal + _modifier,
        type: _selectedDice,
        modifier: _modifier,
        rawRolls: rolls,
        advantage: _advantage,
        timestamp: DateTime.now(),
      ));
    });

    // 4. Success Animation (Pop)
    HapticFeedback.heavyImpact();
    _scaleController.forward(from: 0).then((_) => _scaleController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Tap to roll', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- MAIN ROLLING AREA ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // The Big Die
                  GestureDetector(
                    onTap: _rollDice,
                    child: AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        // Shake effect using translation
                        final dx = sin(_shakeController.value * pi * 4) * 8;
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        );
                      },
                      child: AnimatedBuilder(
                        animation: _scaleController,
                        builder: (context, child) {
                          // Pop effect using scale
                          final scale = 1.0 + (sin(_scaleController.value * pi) * 0.2);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: _isRolling 
                                    ? colorScheme.primary 
                                    : colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  )
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Dice Icon Background
                                  Text(
                                    _selectedDice.icon,
                                    style: TextStyle(
                                      fontSize: 140,
                                      color: _isRolling 
                                          ? Colors.white.withOpacity(0.2)
                                          : colorScheme.primary.withOpacity(0.1),
                                    ),
                                  ),
                                  // The Number
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$_displayedNumber',
                                        style: TextStyle(
                                          fontSize: 80,
                                          fontWeight: FontWeight.w900,
                                          color: _isRolling 
                                              ? Colors.white 
                                              : colorScheme.primary,
                                          height: 1,
                                        ),
                                      ),
                                      if (!_isRolling && _history.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: colorScheme.surface,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Total: ${_history.first.total}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Controls Row (Dice Type & Modifier)
                  Row(
                    children: [
                      // Dice Selector
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: DiceType.values.map((dice) {
                              final isSelected = _selectedDice == dice;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                child: ChoiceChip(
                                  label: Text('d${dice.sides}'),
                                  selected: isSelected,
                                  showCheckmark: false,
                                  onSelected: (val) => setState(() => _selectedDice = dice),
                                  labelStyle: TextStyle(
                                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  backgroundColor: Colors.transparent,
                                  selectedColor: colorScheme.primary,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Modifier Stepper
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => setState(() => _modifier--),
                              icon: const Icon(Icons.remove, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 40),
                            ),
                            Text(
                              '${_modifier >= 0 ? '+' : ''}$_modifier',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _modifier++),
                              icon: const Icon(Icons.add, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 40),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Advantage Selector
                  SegmentedButton<AdvantageType>(
                    segments: const [
                      ButtonSegment(value: AdvantageType.disadvantage, label: Text('Disadv'), icon: Icon(Icons.arrow_downward, size: 16)),
                      ButtonSegment(value: AdvantageType.none, label: Text('Normal')),
                      ButtonSegment(value: AdvantageType.advantage, label: Text('Adv'), icon: Icon(Icons.arrow_upward, size: 16)),
                    ],
                    selected: {_advantage},
                    onSelectionChanged: (val) => setState(() => _advantage = val.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // History Log
                  if (_history.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Recent Rolls', style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.secondary)),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: min(_history.length, 3),
                      itemBuilder: (context, index) {
                        final roll = _history[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: colorScheme.surfaceContainerLow,
                          child: ListTile(
                            dense: true,
                            leading: Text(roll.type.icon, style: const TextStyle(fontSize: 24)),
                            title: Row(
                              children: [
                                Text('${roll.result}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (roll.modifier != 0)
                                  Text(' ${roll.modifier >= 0 ? '+' : ''}${roll.modifier}', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                                Text(' = ${roll.total}', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 16)),
                              ],
                            ),
                            subtitle: roll.advantage != AdvantageType.none
                                ? Text('${roll.advantage.label} [${roll.rawRolls.join(', ')}]')
                                : null,
                            trailing: Text(
                              '${roll.timestamp.minute}:${roll.timestamp.second.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 10, color: colorScheme.outline),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}