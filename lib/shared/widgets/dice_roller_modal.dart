import 'dart:math';
import 'package:flutter/material.dart';

enum DiceType {
  d4(4, '▲'),      // Тетраэдр (треугольник)
  d6(6, '■'),      // Куб (квадрат)
  d8(8, '◆'),      // Октаэдр (ромб)
  d10(10, '⬖'),    // Десятигранник (треугольник с точкой)
  d12(12, '⬟'),    // Додекаэдр (двенадцатиугольник)
  d20(20, '⬢'),    // Икосаэдр (двадцатигранник)
  d100(100, '%');  // Процент

  final int sides;
  final String icon;
  const DiceType(this.sides, this.icon);
}

enum AdvantageType {
  none('Normal', Icons.check),
  advantage('Advantage', Icons.arrow_upward),
  disadvantage('Disadvantage', Icons.arrow_downward);

  final String label;
  final IconData icon;
  const AdvantageType(this.label, this.icon);
}

class DiceRoll {
  final int result;
  final DiceType diceType;
  final int modifier;
  final AdvantageType advantage;
  final List<int> rolls;
  final DateTime timestamp;

  DiceRoll({
    required this.result,
    required this.diceType,
    required this.modifier,
    required this.advantage,
    required this.rolls,
    required this.timestamp,
  });

  int get total => result + modifier;
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
      title: title ?? 'Roll Dice',
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

class _DiceRollerModalState extends State<DiceRollerModal>
    with SingleTickerProviderStateMixin {
  late DiceType _selectedDice;
  late int _modifier;
  AdvantageType _advantage = AdvantageType.none;
  final List<DiceRoll> _rollHistory = [];
  late AnimationController _rollAnimationController;
  bool _isRolling = false;

  @override
  void initState() {
    super.initState();
    _selectedDice = widget.initialDice;
    _modifier = widget.initialModifier;
    _rollAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rollAnimationController.dispose();
    super.dispose();
  }

  void _roll() async {
    if (_isRolling) return;

    setState(() => _isRolling = true);
    _rollAnimationController.forward(from: 0);

    // Simulate dice rolling animation
    await Future.delayed(const Duration(milliseconds: 800));

    final random = Random();
    final rolls = <int>[];

    if (_advantage == AdvantageType.none) {
      // Single roll
      rolls.add(random.nextInt(_selectedDice.sides) + 1);
    } else {
      // Roll twice for advantage/disadvantage
      rolls.add(random.nextInt(_selectedDice.sides) + 1);
      rolls.add(random.nextInt(_selectedDice.sides) + 1);
    }

    int result;
    if (_advantage == AdvantageType.advantage) {
      result = rolls.reduce(max);
    } else if (_advantage == AdvantageType.disadvantage) {
      result = rolls.reduce(min);
    } else {
      result = rolls.first;
    }

    final roll = DiceRoll(
      result: result,
      diceType: _selectedDice,
      modifier: _modifier,
      advantage: _advantage,
      rolls: rolls,
      timestamp: DateTime.now(),
    );

    setState(() {
      _rollHistory.insert(0, roll);
      _isRolling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Animated dice - main focus
                  AnimatedBuilder(
                    animation: _rollAnimationController,
                    builder: (context, child) {
                      final rotation = _rollAnimationController.value * 6 * pi;
                      final diceScale =
                          1.0 + (sin(_rollAnimationController.value * pi * 2) * 0.2);
                      final glowIntensity =
                          0.3 + (sin(_rollAnimationController.value * pi * 4) * 0.3);

                      return Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(
                                _isRolling ? glowIntensity : 0.2
                              ),
                              blurRadius: _isRolling ? 30 : 15,
                              spreadRadius: _isRolling ? 8 : 3,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: rotation,
                            child: Transform.scale(
                              scale: diceScale,
                              child: Text(
                                _selectedDice.icon,
                                style: TextStyle(
                                  fontSize: _selectedDice == DiceType.d100 ? 64 : 72,
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Result display - always visible with placeholder
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _rollHistory.isNotEmpty
                          ? theme.colorScheme.secondaryContainer
                          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _rollHistory.isNotEmpty
                        ? Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  if (_rollHistory.first.rolls.length > 1) ...[
                                    Text(
                                      '[${_rollHistory.first.rolls.join(', ')}]',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: theme.colorScheme.onSecondaryContainer
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      _rollHistory.first.advantage ==
                                              AdvantageType.advantage
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      size: 20,
                                      color: theme.colorScheme.onSecondaryContainer
                                          .withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    _rollHistory.first.result.toString(),
                                    style: theme.textTheme.displayLarge?.copyWith(
                                      color: theme.colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_rollHistory.first.modifier != 0) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_rollHistory.first.modifier >= 0 ? '+' : ''}${_rollHistory.first.modifier}',
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        color: theme.colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '= ${_rollHistory.first.total}',
                                      style: theme.textTheme.displayMedium?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Icon(
                                Icons.casino,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Roll to see result',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Dice type selector
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dice Type',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: DiceType.values.map((dice) {
                              final isSelected = dice == _selectedDice;
                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      dice.icon,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(width: 4),
                                    Text('d${dice.sides}'),
                                  ],
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedDice = dice);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Advantage/Disadvantage selector
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Roll Type',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<AdvantageType>(
                            segments: AdvantageType.values.map((type) {
                              return ButtonSegment(
                                value: type,
                                label: Text(type.label),
                                icon: Icon(type.icon, size: 18),
                              );
                            }).toList(),
                            selected: {_advantage},
                            onSelectionChanged: (Set<AdvantageType> selected) {
                              setState(() => _advantage = selected.first);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Modifier
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modifier',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              IconButton.filled(
                                onPressed: () {
                                  setState(() => _modifier--);
                                },
                                icon: const Icon(Icons.remove),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '${_modifier >= 0 ? '+' : ''}$_modifier',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton.filled(
                                onPressed: () {
                                  setState(() => _modifier++);
                                },
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Roll history
                  if (_rollHistory.length > 1) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Roll History',
                                  style: theme.textTheme.titleMedium,
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _rollHistory.clear());
                                  },
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(
                              (_rollHistory.length - 1).clamp(0, 5),
                              (index) {
                                final roll = _rollHistory[index + 1];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Text(
                                        roll.diceType.icon,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      if (roll.rolls.length > 1)
                                        Text(
                                          '[${roll.rolls.join(', ')}]',
                                          style: theme.textTheme.bodySmall,
                                        )
                                      else
                                        Text(
                                          roll.result.toString(),
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      if (roll.modifier != 0) ...[
                                        Text(
                                          ' ${roll.modifier >= 0 ? '+' : ''}${roll.modifier}',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        Text(
                                          ' = ${roll.total}',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      Text(
                                        '${roll.timestamp.hour.toString().padLeft(2, '0')}:'
                                        '${roll.timestamp.minute.toString().padLeft(2, '0')}:'
                                        '${roll.timestamp.second.toString().padLeft(2, '0')}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),

          // Roll button
          Padding(
            padding: const EdgeInsets.all(20),
            child: FilledButton.icon(
              onPressed: _isRolling ? null : _roll,
              icon: Icon(_isRolling ? Icons.hourglass_empty : Icons.casino),
              label: Text(_isRolling ? 'Rolling...' : 'Roll'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
