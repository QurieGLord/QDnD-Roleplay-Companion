import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
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

  @override
  void initState() {
    super.initState();
    _selectedDice = widget.initialDice;
    _modifier = widget.initialModifier;

    _rollController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _rotationAnimation = CurvedAnimation(
      parent: _rollController,
      curve: Curves.fastOutSlowIn,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 20), // Pull back
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.2), weight: 40), // Throw forward
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 40), // Settle
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

    setState(() => _isRolling = true);
    HapticFeedback.selectionClick();
    _rollController.forward(from: 0);

    final random = Random();
    int cycles = 0;
    
    // Fast number cycling
    _rollTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      setState(() {
        _displayedNumber = random.nextInt(_selectedDice.sides) + 1;
      });
      cycles++;
      if (cycles > 12) timer.cancel();
    });

    // Wait for animation
    await Future.delayed(const Duration(milliseconds: 1000));

    // Calculate actual result
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

    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title & Close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Tap the dice to roll', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.secondary)),
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
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // --- THE DIE ---
                  GestureDetector(
                    onTap: _rollDice,
                    child: AnimatedBuilder(
                      animation: _rollController,
                      builder: (context, child) {
                        // 3D-ish rotation effect
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..rotateZ(_rotationAnimation.value * pi * 2)
                            ..scale(_scaleAnimation.value),
                          child: CustomPaint(
                            size: const Size(200, 200),
                            painter: DiceShapePainter(
                              type: _selectedDice,
                              color: _isRolling ? colorScheme.primary : colorScheme.primaryContainer,
                              outlineColor: colorScheme.primary,
                            ),
                            child: SizedBox(
                              width: 200,
                              height: 200,
                              child: Center(
                                child: Transform.rotate(
                                  // Counter-rotate text so it stays readable
                                  angle: -_rotationAnimation.value * pi * 2,
                                  child: Text(
                                    '$_displayedNumber',
                                    style: TextStyle(
                                      fontSize: 64,
                                      fontWeight: FontWeight.w900,
                                      color: _isRolling ? colorScheme.onPrimary : colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Result display
                  if (!_isRolling && _history.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total: ',
                              style: TextStyle(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_history.first.total}',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.onSecondaryContainer),
                            ),
                            if (_modifier != 0)
                              Text(
                                ' (${_history.first.result} ${_modifier >= 0 ? '+' : ''} $_modifier)',
                                style: TextStyle(color: colorScheme.onSecondaryContainer.withOpacity(0.7), fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 80), // Spacer placeholder

                  const SizedBox(height: 40),

                  // --- CONTROLS ---
                  
                  // Dice Type Selector (Grid/Wrap)
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
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.3),
                                  width: isSelected ? 0 : 1,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                                ] : [],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Mini icon representation
                                    CustomPaint(
                                      size: const Size(20, 20),
                                      painter: DiceShapePainter(
                                        type: dice,
                                        color: isSelected ? colorScheme.onPrimary.withOpacity(0.2) : colorScheme.onSurface.withOpacity(0.1),
                                        outlineColor: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                                        strokeWidth: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
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

                  // Modifier & Advantage Row
                  Row(
                    children: [
                      // Modifier
                      Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: () => setState(() => _modifier--),
                                icon: const Icon(Icons.remove),
                                visualDensity: VisualDensity.compact,
                              ),
                              Column(
                                children: [
                                  Text('MOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.outline)),
                                  Text('${_modifier >= 0 ? '+' : ''}$_modifier', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              IconButton(
                                onPressed: () => setState(() => _modifier++),
                                icon: const Icon(Icons.add),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Advantage
                      Expanded(
                        flex: 6,
                        child: SegmentedButton<AdvantageType>(
                          segments: const [
                            ButtonSegment(value: AdvantageType.disadvantage, icon: Icon(Icons.keyboard_double_arrow_down)),
                            ButtonSegment(value: AdvantageType.none, label: Text(' - ')),
                            ButtonSegment(value: AdvantageType.advantage, icon: Icon(Icons.keyboard_double_arrow_up)),
                          ],
                          selected: {_advantage},
                          onSelectionChanged: (val) => setState(() => _advantage = val.first),
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- CUSTOM PAINTER FOR DICE SHAPES ---

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
    final radius = min(size.width, size.height) / 2 * 0.9; // Padding

    final path = Path();

    switch (type) {
      case DiceType.d4:
        // Triangle
        final angle = -pi / 2; // Point up
        for (int i = 0; i < 3; i++) {
          final theta = angle + (i * 2 * pi / 3);
          final x = center.dx + radius * cos(theta);
          final y = center.dy + radius * sin(theta) * 1.1; // Adjust aspect
          if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        path.close();
        break;

      case DiceType.d6:
        // Rounded Square
        final rect = Rect.fromCircle(center: center, radius: radius * 0.85);
        path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
        break;

      case DiceType.d8:
        // Diamond (2 triangles)
        path.moveTo(center.dx, center.dy - radius); // Top
        path.lineTo(center.dx + radius * 0.8, center.dy); // Right
        path.lineTo(center.dx, center.dy + radius); // Bottom
        path.lineTo(center.dx - radius * 0.8, center.dy); // Left
        path.close();
        // Inner lines for 3D effect
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        canvas.drawLine(center, Offset(center.dx, center.dy - radius), outlinePaint..strokeWidth = 1);
        canvas.drawLine(center, Offset(center.dx, center.dy + radius), outlinePaint..strokeWidth = 1);
        canvas.drawLine(Offset(center.dx - radius * 0.8, center.dy), Offset(center.dx + radius * 0.8, center.dy), outlinePaint..strokeWidth = 1);
        return; // Special handling for inner lines

      case DiceType.d10:
      case DiceType.d100: // Same shape
        // Kite / Deltoid
        path.moveTo(center.dx, center.dy - radius); // Top
        path.lineTo(center.dx + radius * 0.8, center.dy - radius * 0.2); // Upper Right
        path.lineTo(center.dx, center.dy + radius); // Bottom
        path.lineTo(center.dx - radius * 0.8, center.dy - radius * 0.2); // Upper Left
        path.close();
        // Inner lines
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
        final angle = pi / 6; // Flat top? No, pointy top usually
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
