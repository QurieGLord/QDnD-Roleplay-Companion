import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DiceType {
  d4(4, 'd4'),
  d6(6, 'd6'),
  d8(8, 'd8'),
  d10(10, 'd10'),
  d12(12, 'd12'),
  d20(20, 'd20'),
  d100(100, 'd100');

  final int sides;
  final String label;
  const DiceType(this.sides, this.label);
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

  // Animation
  late AnimationController _rollController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _isRolling = false;
  int _displayedNumber = 1;
  Timer? _rollTimer;

  // UI Colors state
  bool _resultReady = false;

  @override
  void initState() {
    super.initState();
    _selectedDice = widget.initialDice;
    _modifier = widget.initialModifier;
    _displayedNumber = widget.initialDice.sides; // Show max value initially

    _rollController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _rotationAnimation = CurvedAnimation(
      parent: _rollController,
      curve: Curves.easeInOutBack, // Smoother rotation
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 40), 
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 30),
    ]).animate(_rollController);
  }

  @override
  void dispose() {
    _rollController.dispose();
    _rollTimer?.cancel();
    super.dispose();
  }

  void _rollDice() async {
    if (_isRolling) return;

    setState(() {
      _isRolling = true;
      _resultReady = false;
    });
    
    HapticFeedback.selectionClick();
    _rollController.forward(from: 0);

    final random = Random();
    int cycles = 0;
    
    // Cycle numbers logic
    _rollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _displayedNumber = random.nextInt(_selectedDice.sides) + 1;
        });
      }
      cycles++;
      // Slow down towards the end
      if (cycles > 10) {
         timer.cancel();
         // Final manual ticks for "slowing down" feel
         _slowDownTicks(random);
      }
    });
  }

  void _slowDownTicks(Random random) async {
    // Tick 1
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _displayedNumber = random.nextInt(_selectedDice.sides) + 1);
    
    // Tick 2
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) setState(() => _displayedNumber = random.nextInt(_selectedDice.sides) + 1);

    // Final Result
    await Future.delayed(const Duration(milliseconds: 200));
    _finalizeRoll(random);
  }

  void _finalizeRoll(Random random) {
    final rolls = <int>[];
    int resultVal = 0;

    if (_advantage == AdvantageType.none) {
      rolls.add(random.nextInt(_selectedDice.sides) + 1);
      resultVal = rolls.first;
    } else {
      rolls.add(random.nextInt(_selectedDice.sides) + 1);
      rolls.add(random.nextInt(_selectedDice.sides) + 1);
      resultVal = _advantage == AdvantageType.advantage 
          ? rolls.reduce(max) 
          : rolls.reduce(min);
    }

    if (mounted) {
      setState(() {
        _displayedNumber = resultVal;
        _isRolling = false;
        _resultReady = true; // Trigger color change
        
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
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Dynamic Colors based on state
    final dieColor = _isRolling 
        ? colorScheme.primaryContainer 
        : (_resultReady ? colorScheme.tertiaryContainer : colorScheme.surfaceContainerHighest);
    
    final dieOutlineColor = _isRolling 
        ? colorScheme.primary 
        : (_resultReady ? colorScheme.tertiary : colorScheme.outline);

    final textColor = _isRolling 
        ? colorScheme.onPrimaryContainer
        : (_resultReady ? colorScheme.onTertiaryContainer : colorScheme.onSurfaceVariant);

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
              margin: const EdgeInsets.only(top: 12, bottom: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      if (!_resultReady)
                        Text('Tap dice to roll', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.secondary))
                      else
                        Text('Roll complete!', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.tertiary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // --- THE DIE ---
                  GestureDetector(
                    onTap: _rollDice,
                    child: AnimatedBuilder(
                      animation: _rollController,
                      builder: (context, child) {
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..rotateZ(_rotationAnimation.value * pi * 2)
                            ..scale(_scaleAnimation.value),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Animated Color Shape
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: CustomPaint(
                                  size: const Size(220, 220),
                                  painter: DiceShapePainter(
                                    type: _selectedDice,
                                    color: dieColor,
                                    outlineColor: dieOutlineColor,
                                    strokeWidth: _resultReady ? 4.0 : 2.0,
                                  ),
                                ),
                              ),
                              
                              // Animated Text
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 100),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(scale: animation, child: child);
                                },
                                child: Text(
                                  '$_displayedNumber',
                                  key: ValueKey<int>(_displayedNumber),
                                  style: TextStyle(
                                    fontSize: 80,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                    shadows: _resultReady ? [
                                      Shadow(color: dieOutlineColor.withOpacity(0.5), blurRadius: 10)
                                    ] : [],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Result Modifiers Badge (Overlay style)
                  if (_resultReady && (_modifier != 0 || _history.first.rawRolls.length > 1))
                    Transform.translate(
                      offset: const Offset(0, -20), // Overlap slightly bottom
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colorScheme.outlineVariant),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_history.first.rawRolls.length > 1) ...[
                              Text('[${_history.first.rawRolls.join(', ')}]', style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 8),
                              const Text('→', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                            ],
                            if (_modifier != 0)
                              Text(
                                '${_modifier >= 0 ? '+' : ''}$_modifier',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            if (_modifier != 0) ...[
                              const SizedBox(width: 8),
                              const Text('='),
                              const SizedBox(width: 8),
                              Text(
                                '${_history.first.total}',
                                style: TextStyle(
                                  fontSize: 20, 
                                  fontWeight: FontWeight.w900,
                                  color: colorScheme.primary
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // --- CONTROLS ---
                  
                  // Dice Type Selector (Wrap for full visibility)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DICE TYPE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.outline, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: DiceType.values.map((dice) {
                          final isSelected = _selectedDice == dice;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedDice = dice),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.3),
                                  width: isSelected ? 0 : 1,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Mini shape
                                    CustomPaint(
                                      size: const Size(16, 16),
                                      painter: DiceShapePainter(
                                        type: dice,
                                        color: isSelected ? colorScheme.onPrimary.withOpacity(0.3) : colorScheme.onSurface.withOpacity(0.2),
                                        outlineColor: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                                        strokeWidth: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dice.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Modifier & Advantage
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modifier
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MODIFIER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.outline, letterSpacing: 1.2)),
                            const SizedBox(height: 8),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                border: Border.all(color: colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    onPressed: () => setState(() => _modifier--),
                                    icon: const Icon(Icons.remove, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32),
                                  ),
                                  Text(
                                    '${_modifier >= 0 ? '+' : ''}$_modifier',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  IconButton(
                                    onPressed: () => setState(() => _modifier++),
                                    icon: const Icon(Icons.add, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Advantage
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ROLL TYPE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.outline, letterSpacing: 1.2)),
                            const SizedBox(height: 8),
                            SegmentedButton<AdvantageType>(
                              segments: const [
                                ButtonSegment(value: AdvantageType.disadvantage, label: Text('Dis')),
                                ButtonSegment(value: AdvantageType.none, label: Text(' - ')),
                                ButtonSegment(value: AdvantageType.advantage, label: Text('Adv')),
                              ],
                              selected: {_advantage},
                              onSelectionChanged: (val) => setState(() => _advantage = val.first),
                              showSelectedIcon: false,
                              style: ButtonStyle(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                textStyle: MaterialStateProperty.all(const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // History
                  if (_history.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.history, size: 16),
                        const SizedBox(width: 8),
                        Text('HISTORY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.outline, letterSpacing: 1.2)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: min(_history.length, 3),
                      itemBuilder: (context, index) {
                        final roll = _history[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text('d${roll.type.sides}', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                              const SizedBox(width: 12),
                              if (roll.rawRolls.length > 1)
                                Text('[${roll.rawRolls.join(', ')}]', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                              const Spacer(),
                              Text('${roll.total}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
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

class DiceShapePainter extends CustomPainter {
  final DiceType type;
  final Color color;
  final Color outlineColor;
  final double strokeWidth;

  DiceShapePainter({
    required this.type,
    required this.color,
    required this.outlineColor,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 0.9;

    final path = Path();

    switch (type) {
      case DiceType.d4:
        // Triangle
        final angle = -pi / 2;
        for (int i = 0; i < 3; i++) {
          final theta = angle + (i * 2 * pi / 3);
          final x = center.dx + radius * cos(theta);
          final y = center.dy + radius * sin(theta) * 1.1 + (radius * 0.2); // Centering adj
          if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        path.close();
        break;

      case DiceType.d6:
        // Rounded Square
        final rect = Rect.fromCircle(center: center, radius: radius * 0.8);
        path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
        break;

      case DiceType.d8:
        // Diamond
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx + radius * 0.8, center.dy);
        path.lineTo(center.dx, center.dy + radius);
        path.lineTo(center.dx - radius * 0.8, center.dy);
        path.close();
        // Inner
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        canvas.drawLine(center, Offset(center.dx, center.dy - radius), outlinePaint..strokeWidth = 1);
        canvas.drawLine(center, Offset(center.dx, center.dy + radius), outlinePaint..strokeWidth = 1);
        canvas.drawLine(Offset(center.dx - radius * 0.8, center.dy), Offset(center.dx + radius * 0.8, center.dy), outlinePaint..strokeWidth = 1);
        return;

      case DiceType.d10:
      case DiceType.d100:
        // Kite
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx + radius * 0.8, center.dy - radius * 0.2);
        path.lineTo(center.dx, center.dy + radius);
        path.lineTo(center.dx - radius * 0.8, center.dy - radius * 0.2);
        path.close();
        // Inner
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        canvas.drawLine(center, Offset(center.dx, center.dy - radius), outlinePaint..strokeWidth = 1);
        canvas.drawLine(center, Offset(center.dx, center.dy + radius), outlinePaint..strokeWidth = 1);
        canvas.drawLine(Offset(center.dx - radius * 0.8, center.dy - radius * 0.2), center, outlinePaint..strokeWidth = 1);
        canvas.drawLine(Offset(center.dx + radius * 0.8, center.dy - radius * 0.2), center, outlinePaint..strokeWidth = 1);
        return;

      case DiceType.d12:
        // Pentagon
        final angle = -pi / 2;
        for (int i = 0; i < 5; i++) {
          final theta = angle + (i * 2 * pi / 5);
          final x = center.dx + radius * cos(theta);
          final y = center.dy + radius * sin(theta);
          if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        path.close();
        break;

      case DiceType.d20:
        // Hexagon
        final angle = pi / 6; 
        for (int i = 0; i < 6; i++) {
          final theta = angle + (i * 2 * pi / 6);
          final x = center.dx + radius * cos(theta);
          final y = center.dy + radius * sin(theta);
          if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        path.close();
        break;
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}